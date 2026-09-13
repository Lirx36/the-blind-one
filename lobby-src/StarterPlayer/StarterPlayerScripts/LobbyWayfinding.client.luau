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

local baseBackground: { [Instance]: number } = {}
local baseText: { [Instance]: number } = {}
local baseTextStroke: { [Instance]: number } = {}
local baseImage: { [Instance]: number } = {}
local baseStroke: { [Instance]: number } = {}
local fadeStates: { [BasePart]: number } = {}

local function faded(base: number, amount: number): number
	return base + (1 - base) * amount
end

local function setFade(anchor: BasePart, fade: number)
	local gui = anchor:FindFirstChild("DistanceSign")
	if not gui or not gui:IsA("BillboardGui") then return end
	local panel = gui:FindFirstChild("Panel")
	if not panel or not panel:IsA("GuiObject") then return end
	gui.Enabled = fade < 0.998
	local items = panel:GetDescendants()
	table.insert(items, panel)
	for _, item in items do
		if item:IsA("TextLabel") then
			if baseText[item] == nil then baseText[item] = item.TextTransparency end
			if baseTextStroke[item] == nil then baseTextStroke[item] = item.TextStrokeTransparency end
			item.TextTransparency = faded(baseText[item], fade)
			item.TextStrokeTransparency = faded(baseTextStroke[item], fade)
			if baseBackground[item] == nil then baseBackground[item] = item.BackgroundTransparency end
			item.BackgroundTransparency = faded(baseBackground[item], fade)
		elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
			if baseImage[item] == nil then baseImage[item] = item.ImageTransparency end
			item.ImageTransparency = faded(baseImage[item], fade)
			if baseBackground[item] == nil then baseBackground[item] = item.BackgroundTransparency end
			item.BackgroundTransparency = faded(baseBackground[item], fade)
		elseif item:IsA("Frame") then
			if baseBackground[item] == nil then baseBackground[item] = item.BackgroundTransparency end
			item.BackgroundTransparency = faded(baseBackground[item], fade)
		elseif item:IsA("UIStroke") then
			if baseStroke[item] == nil then baseStroke[item] = item.Transparency end
			item.Transparency = faded(baseStroke[item], fade)
		end
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
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
		local offset = root.Position - targetPosition
		local distance = Vector2.new(offset.X, offset.Z).Magnitude
		local proximity = 1 - math.clamp((distance - nearDistance) / math.max(farDistance - nearDistance, 1), 0, 1)
		local desiredFade = proximity * proximity * (3 - 2 * proximity)
		local currentFade = fadeStates[anchor]
		if currentFade == nil then currentFade = desiredFade end
		currentFade += (desiredFade - currentFade) * (1 - math.exp(-deltaTime * 7))
		fadeStates[anchor] = currentFade
		setFade(anchor, currentFade)
	end
end)
