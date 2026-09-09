--!strict
-- E: pick up a nearby rock.  Left click / R2: throw one where you're looking.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local PICKUP_RANGE = 12

local pickupOutline = Instance.new("Highlight")
pickupOutline.Name = "LocalBallPickupOutline"
pickupOutline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
pickupOutline.FillTransparency = 1
pickupOutline.OutlineColor = Color3.fromRGB(245, 250, 255)
pickupOutline.OutlineTransparency = 0.02
pickupOutline.Enabled = false
pickupOutline.Parent = Workspace

local pickupBillboard = Instance.new("BillboardGui")
pickupBillboard.Name = "LocalBallPickupPrompt"
pickupBillboard.AlwaysOnTop = true
pickupBillboard.LightInfluence = 0
pickupBillboard.MaxDistance = PICKUP_RANGE + 3
pickupBillboard.Size = UDim2.fromOffset(112, 34)
pickupBillboard.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
pickupBillboard.Enabled = false
pickupBillboard.Parent = player:WaitForChild("PlayerGui")

local prompt = Instance.new("TextLabel")
prompt.Size = UDim2.fromScale(1, 1)
prompt.BackgroundColor3 = Color3.fromRGB(8, 11, 14)
prompt.BackgroundTransparency = 0.15
prompt.BorderSizePixel = 0
prompt.Font = Enum.Font.GothamBold
prompt.Text = "E  ·  PICK UP"
prompt.TextSize = 13
prompt.TextColor3 = Color3.fromRGB(245, 250, 255)
prompt.TextStrokeTransparency = 0.7
prompt.Parent = pickupBillboard
local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 7)
promptCorner.Parent = prompt
local promptStroke = Instance.new("UIStroke")
promptStroke.Color = Color3.fromRGB(185, 215, 230)
promptStroke.Thickness = 1
promptStroke.Transparency = 0.28
promptStroke.Parent = prompt

local function root(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart? or nil
end

local function nearestRock(): BasePart?
	local hrp = root()
	if not hrp then
		return nil
	end
	local best: BasePart? = nil
	local bestD = PICKUP_RANGE
	for _, rock in CollectionService:GetTagged("Throwable") do
		if rock:IsA("BasePart") and rock:IsDescendantOf(Workspace) then
			local d = (rock.Position - hrp.Position).Magnitude
			if d < bestD then
				best, bestD = rock, d
			end
		end
	end
	return best
end

RunService.RenderStepped:Connect(function()
	local target = if player:GetAttribute("Role") ~= "BlindOne" then nearestRock() else nil
	pickupOutline.Adornee = target
	pickupOutline.Enabled = target ~= nil
	pickupBillboard.Adornee = target
	pickupBillboard.Enabled = target ~= nil
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or player:GetAttribute("Role") == "BlindOne" then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		local rock = nearestRock()
		if rock then
			Remotes.Pickup:FireServer(rock)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		local cam = Workspace.CurrentCamera
		if cam then
			Remotes.Throw:FireServer(cam.CFrame.LookVector)
		end
	end
end)
