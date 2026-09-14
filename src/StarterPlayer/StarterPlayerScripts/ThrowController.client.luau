--!strict
-- E picks up a nearby rock. Slot 1 toggles equip; only an equipped rock can be
-- thrown. Touch players get a dedicated button so looking around never throws.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local PICKUP_RANGE = 12

if player:GetAttribute("BallEquipped") == nil then
	player:SetAttribute("BallEquipped", false)
end

local touchGui = Instance.new("ScreenGui")
touchGui.Name = "TouchRockThrow"
touchGui.IgnoreGuiInset = true
touchGui.ResetOnSpawn = false
touchGui.DisplayOrder = 120
touchGui.Parent = player:WaitForChild("PlayerGui")
local throwButton = Instance.new("TextButton")
throwButton.Name = "ThrowButton"
throwButton.AnchorPoint = Vector2.new(1, 1)
throwButton.Position = UDim2.new(1, -32, 1, -132)
throwButton.Size = UDim2.fromOffset(112, 64)
throwButton.BackgroundColor3 = Color3.fromRGB(49, 20, 15)
throwButton.BackgroundTransparency = 0.08
throwButton.BorderSizePixel = 0
throwButton.AutoButtonColor = false
throwButton.Font = Enum.Font.GothamBlack
throwButton.Text = "THROW"
throwButton.TextColor3 = Color3.fromRGB(241, 218, 198)
throwButton.TextSize = 16
throwButton.Visible = false
throwButton.Parent = touchGui
local throwCorner = Instance.new("UICorner")
throwCorner.CornerRadius = UDim.new(0, 11)
throwCorner.Parent = throwButton
local throwStroke = Instance.new("UIStroke")
throwStroke.Color = Color3.fromRGB(229, 79, 44)
throwStroke.Thickness = 2
throwStroke.Transparency = 0.1
throwStroke.Parent = throwButton

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

local function lookedAtRock(): BasePart?
	local hrp = root()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local held = player:GetAttribute("HeldBalls")
	if not hrp or not camera or not character or (typeof(held) == "number" and held >= Config.MaxThrowables) then
		return nil
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.IgnoreWater = true
	local origin = camera.CFrame.Position
	local result = Workspace:Raycast(origin, camera.CFrame.LookVector * (PICKUP_RANGE + 4), rayParams)
	local rock = result and result.Instance
	if rock and rock:IsA("BasePart") and rock:HasTag("Throwable") and (rock.Position - hrp.Position).Magnitude <= PICKUP_RANGE then
		return rock
	end
	return nil
end

local function heldCount(): number
	local value = player:GetAttribute("HeldBalls")
	return if typeof(value) == "number" then value else 0
end

local function canUseRock(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("InMatch") == true
		and player:GetAttribute("Role") ~= "BlindOne"
		and player:GetAttribute("PhotoModeActive") ~= true
		and player:GetAttribute("RepairMinigameActive") ~= true
		and humanoid ~= nil and humanoid.Health > 0
		and heldCount() > 0
end

local function toggleEquipped()
	if not canUseRock() then
		player:SetAttribute("BallEquipped", false)
		return
	end
	player:SetAttribute("BallEquipped", player:GetAttribute("BallEquipped") ~= true)
end

local function throwEquipped()
	if not canUseRock() or player:GetAttribute("BallEquipped") ~= true then return end
	local camera = Workspace.CurrentCamera
	if camera then Remotes.Throw:FireServer(camera.CFrame.LookVector) end
end

RunService.RenderStepped:Connect(function()
	local target = if player:GetAttribute("Role") ~= "BlindOne" and player:GetAttribute("PhotoModeActive") ~= true then lookedAtRock() else nil
	pickupOutline.Adornee = target
	pickupOutline.Enabled = target ~= nil
	pickupBillboard.Adornee = target
	pickupBillboard.Enabled = target ~= nil
	if not canUseRock() and player:GetAttribute("BallEquipped") == true then
		player:SetAttribute("BallEquipped", false)
	end
	throwButton.Visible = UserInputService.TouchEnabled and canUseRock() and player:GetAttribute("BallEquipped") == true
end)

throwButton.Activated:Connect(throwEquipped)
player.CharacterAdded:Connect(function()
	player:SetAttribute("BallEquipped", false)
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or player:GetAttribute("Role") == "BlindOne" or player:GetAttribute("PhotoModeActive") == true
		or player:GetAttribute("RepairMinigameActive") == true then
		return
	end
	if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.ButtonL1 then
		toggleEquipped()
	elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		local rock = lookedAtRock()
		local camera = Workspace.CurrentCamera
		if rock and camera then
			Remotes.Pickup:FireServer(rock, camera.CFrame.Position, camera.CFrame.LookVector)
		end
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		throwEquipped()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not UserInputService.TouchEnabled then
		throwEquipped()
	end
end)
