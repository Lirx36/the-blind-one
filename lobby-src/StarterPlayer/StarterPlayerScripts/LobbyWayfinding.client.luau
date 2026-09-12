--!strict
-- Large private-elevator wayfinding stays readable from the atrium, then
-- yields to the physical elevator displays as the player approaches.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local bunker = workspace:WaitForChild("BunkerLobby", 30)
if not bunker then return end
local signs = bunker:WaitForChild("WayfindingSigns", 10)
if not signs then return end

local function setFade(anchor: BasePart, fade: number)
	local gui = anchor:FindFirstChild("DistanceSign")
	if not gui or not gui:IsA("BillboardGui") then return end
	gui.Enabled = fade < 0.995
	local panel = gui:FindFirstChild("Panel")
	if not panel or not panel:IsA("Frame") then return end
	panel.BackgroundTransparency = 0.1 + 0.9 * fade
	for _, item in panel:GetDescendants() do
		if item:IsA("TextLabel") then
			item.TextTransparency = fade
		elseif item:IsA("Frame") then
			item.BackgroundTransparency = fade
		elseif item:IsA("UIStroke") then
			item.Transparency = 0.12 + 0.88 * fade
		end
	end
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	for _, anchor in signs:GetChildren() do
		if not anchor:IsA("BasePart") then continue end
		local nearDistance = anchor:GetAttribute("FadeNear")
		local farDistance = anchor:GetAttribute("FadeFar")
		if typeof(nearDistance) ~= "number" or typeof(farDistance) ~= "number" then continue end
		local targetX = anchor:GetAttribute("TargetX")
		local targetY = anchor:GetAttribute("TargetY")
		local targetZ = anchor:GetAttribute("TargetZ")
		local targetPosition = if typeof(targetX) == "number" and typeof(targetY) == "number" and typeof(targetZ) == "number"
			then Vector3.new(targetX, targetY, targetZ)
			else anchor.Position
		local distance = (root.Position - targetPosition).Magnitude
		local visible = math.clamp((distance - nearDistance) / (farDistance - nearDistance), 0, 1)
		local fade = 1 - (visible * visible * (3 - 2 * visible))
		setFade(anchor, fade)
	end
end)
