--!strict
-- Three-stage analog signal calibration for the five labyrinth generators.
-- The player must stop a moving needle inside progressively narrower windows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local gui = Instance.new("ScreenGui")
gui.Name = "GeneratorCalibration"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 8500
gui.Enabled = false
gui.Parent = playerGui

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(0, 2, 3)
shade.BackgroundTransparency = 0.3
shade.BorderSizePixel = 0
shade.Active = true
shade.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(610, 370)
panel.BackgroundColor3 = Color3.fromRGB(7, 12, 13)
panel.BorderSizePixel = 0
panel.Parent = shade
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(146, 76, 48)
panelStroke.Thickness = 2
panelStroke.Transparency = 0.1
panelStroke.Parent = panel
local scale = Instance.new("UIScale")
scale.Parent = panel

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 5)
topBar.BackgroundColor3 = Color3.fromRGB(188, 72, 41)
topBar.BorderSizePixel = 0
topBar.Parent = panel

local eyebrow = Instance.new("TextLabel")
eyebrow.Position = UDim2.fromOffset(28, 24)
eyebrow.Size = UDim2.new(1, -112, 0, 20)
eyebrow.BackgroundTransparency = 1
eyebrow.Font = Enum.Font.GothamBold
eyebrow.Text = "AUXILIARY POWER  //  MANUAL FREQUENCY LINK"
eyebrow.TextColor3 = Color3.fromRGB(137, 158, 157)
eyebrow.TextSize = 11
eyebrow.TextXAlignment = Enum.TextXAlignment.Left
eyebrow.Parent = panel

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(28, 48)
title.Size = UDim2.new(1, -56, 0, 42)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "CALIBRATE GENERATOR"
title.TextColor3 = Color3.fromRGB(225, 230, 224)
title.TextSize = 27
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(28, 96)
divider.Size = UDim2.new(1, -56, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(65, 78, 77)
divider.BorderSizePixel = 0
divider.Parent = panel

local roundLabel = Instance.new("TextLabel")
roundLabel.Position = UDim2.fromOffset(28, 112)
roundLabel.Size = UDim2.fromOffset(250, 24)
roundLabel.BackgroundTransparency = 1
roundLabel.Font = Enum.Font.GothamBold
roundLabel.TextColor3 = Color3.fromRGB(185, 197, 191)
roundLabel.TextSize = 13
roundLabel.TextXAlignment = Enum.TextXAlignment.Left
roundLabel.Parent = panel

local strikesLabel = Instance.new("TextLabel")
strikesLabel.AnchorPoint = Vector2.new(1, 0)
strikesLabel.Position = UDim2.new(1, -28, 0, 112)
strikesLabel.Size = UDim2.fromOffset(190, 24)
strikesLabel.BackgroundTransparency = 1
strikesLabel.Font = Enum.Font.GothamBold
strikesLabel.TextColor3 = Color3.fromRGB(188, 80, 57)
strikesLabel.TextSize = 12
strikesLabel.TextXAlignment = Enum.TextXAlignment.Right
strikesLabel.Parent = panel

local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(34, 156)
track.Size = UDim2.new(1, -68, 0, 54)
track.BackgroundColor3 = Color3.fromRGB(17, 25, 25)
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.Parent = panel
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 7)
trackCorner.Parent = track
local trackStroke = Instance.new("UIStroke")
trackStroke.Color = Color3.fromRGB(69, 88, 86)
trackStroke.Transparency = 0.25
trackStroke.Parent = track

for index = 1, 12 do
	local tick = Instance.new("Frame")
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(index / 13, 0.5)
	tick.Size = UDim2.fromOffset(1, if index % 3 == 0 then 30 else 18)
	tick.BackgroundColor3 = Color3.fromRGB(68, 83, 81)
	tick.BorderSizePixel = 0
	tick.Parent = track
end

local targetZone = Instance.new("Frame")
targetZone.AnchorPoint = Vector2.new(0.5, 0)
targetZone.Position = UDim2.fromScale(0.5, 0)
targetZone.Size = UDim2.fromScale(0.2, 1)
targetZone.BackgroundColor3 = Color3.fromRGB(67, 174, 111)
targetZone.BackgroundTransparency = 0.48
targetZone.BorderSizePixel = 0
targetZone.Parent = track

local needle = Instance.new("Frame")
needle.AnchorPoint = Vector2.new(0.5, 0)
needle.Position = UDim2.fromScale(0, 0)
needle.Size = UDim2.fromOffset(5, 54)
needle.BackgroundColor3 = Color3.fromRGB(239, 225, 181)
needle.BorderSizePixel = 0
needle.ZIndex = 3
needle.Parent = track
local needleGlow = Instance.new("UIStroke")
needleGlow.Color = Color3.fromRGB(255, 151, 69)
needleGlow.Thickness = 3
needleGlow.Transparency = 0.2
needleGlow.Parent = needle

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(28, 222)
status.Size = UDim2.new(1, -56, 0, 28)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.Text = "STOP THE NEEDLE INSIDE THE SIGNAL WINDOW"
status.TextColor3 = Color3.fromRGB(145, 161, 158)
status.TextSize = 12
status.Parent = panel

local calibrate = Instance.new("TextButton")
calibrate.Position = UDim2.fromOffset(28, 264)
calibrate.Size = UDim2.new(1, -56, 0, 58)
calibrate.BackgroundColor3 = Color3.fromRGB(53, 27, 21)
calibrate.BorderSizePixel = 0
calibrate.AutoButtonColor = false
calibrate.Font = Enum.Font.GothamBlack
calibrate.Text = if UserInputService.TouchEnabled then "TAP TO CALIBRATE" else "SPACE / E / CLICK  //  CALIBRATE"
calibrate.TextColor3 = Color3.fromRGB(229, 215, 199)
calibrate.TextSize = 16
calibrate.Parent = panel
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = calibrate
local buttonStroke = Instance.new("UIStroke")
buttonStroke.Color = Color3.fromRGB(174, 76, 45)
buttonStroke.Transparency = 0.2
buttonStroke.Parent = calibrate

local cancel = Instance.new("TextButton")
cancel.Name = "Leave"
cancel.AnchorPoint = Vector2.new(1, 0)
cancel.Position = UDim2.new(1, -18, 0, 17)
cancel.Size = UDim2.fromOffset(38, 34)
cancel.BackgroundColor3 = Color3.fromRGB(35, 13, 11)
cancel.BorderSizePixel = 0
cancel.AutoButtonColor = false
cancel.Font = Enum.Font.GothamBlack
cancel.Text = "×"
cancel.TextColor3 = Color3.fromRGB(224, 151, 133)
cancel.TextSize = 25
cancel.Parent = panel
local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 7)
cancelCorner.Parent = cancel
local cancelStroke = Instance.new("UIStroke")
cancelStroke.Color = Color3.fromRGB(146, 76, 48)
cancelStroke.Transparency = 0.25
cancelStroke.Parent = cancel

local leaveHint = Instance.new("TextLabel")
leaveHint.AnchorPoint = Vector2.new(0.5, 0)
leaveHint.Position = UDim2.new(0.5, 0, 0, 333)
leaveHint.Size = UDim2.fromOffset(180, 20)
leaveHint.BackgroundTransparency = 1
leaveHint.Font = Enum.Font.GothamMedium
leaveHint.Text = "Q  ·  DISCONNECT"
leaveHint.TextColor3 = Color3.fromRGB(105, 120, 118)
leaveHint.TextSize = 10
leaveHint.Parent = panel

local active = false
local accepting = false
local awaitingServer = false
local token = ""
local round = 1
local strikes = 0
local phase = 0
local needlePosition = 0
local targetCenter = 0.5
local targetWidth = 0.2
local rng = Random.new()

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	scale.Scale = math.min(1, viewport.X / 680, viewport.Y / 450)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
RunService.RenderStepped:Connect(updateScale)

local function blockMovement(_name: string, _state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function setRound(nextRound: number)
	round = nextRound
	targetWidth = ({ 0.22, 0.17, 0.125 })[round]
	targetCenter = rng:NextNumber(0.16 + targetWidth / 2, 0.84 - targetWidth / 2)
	targetZone.Position = UDim2.fromScale(targetCenter, 0)
	targetZone.Size = UDim2.fromScale(targetWidth, 1)
	roundLabel.Text = string.format("CALIBRATION STAGE  %02d / 03", round)
	strikesLabel.Text = string.format("FAULTS  %d / 2", strikes)
	status.Text = "STOP THE NEEDLE INSIDE THE SIGNAL WINDOW"
	status.TextColor3 = Color3.fromRGB(145, 161, 158)
	calibrate.BackgroundColor3 = Color3.fromRGB(53, 27, 21)
	accepting = true
end

local function closeMinigame(sendCancel: boolean)
	if not active then return end
	local oldToken = token
	active, accepting, awaitingServer = false, false, false
	token = ""
	gui.Enabled = false
	player:SetAttribute("RepairMinigameActive", false)
	ContextActionService:UnbindAction("GeneratorCalibrationMovement")
	if sendCancel then Remotes.GeneratorMinigame:FireServer("Cancel", oldToken) end
end

local function failCalibration()
	if not active then return end
	accepting = false
	status.Text = "TWO FAULTS  //  SAFETY LOCKOUT ENGAGED"
	status.TextColor3 = Color3.fromRGB(230, 83, 58)
	calibrate.BackgroundColor3 = Color3.fromRGB(91, 24, 18)
	local oldToken = token
	Remotes.GeneratorMinigame:FireServer("Fail", oldToken)
	task.delay(0.8, function()
		if active and token == oldToken then closeMinigame(false) end
	end)
end

local function calibratePulse()
	if not active or not accepting or awaitingServer then return end
	accepting = false
	local hit = math.abs(needlePosition - targetCenter) <= targetWidth / 2
	if not hit then
		strikes += 1
		strikesLabel.Text = string.format("FAULTS  %d / 2", strikes)
		status.Text = "SIGNAL MISSED"
		status.TextColor3 = Color3.fromRGB(230, 83, 58)
		calibrate.BackgroundColor3 = Color3.fromRGB(91, 24, 18)
		if strikes >= 2 then
			failCalibration()
		else
			task.delay(0.45, function()
				if active then setRound(round) end
			end)
		end
		return
	end

	status.Text = "FREQUENCY LOCKED"
	status.TextColor3 = Color3.fromRGB(93, 220, 139)
	calibrate.BackgroundColor3 = Color3.fromRGB(24, 72, 47)
	if round >= 3 then
		awaitingServer = true
		status.Text = "ALL CHANNELS LOCKED  //  STARTING GENERATOR"
		Remotes.GeneratorMinigame:FireServer("Complete", token)
	else
		local nextRound = round + 1
		task.delay(0.42, function()
			if active then setRound(nextRound) end
		end)
	end
end

calibrate.Activated:Connect(calibratePulse)
cancel.Activated:Connect(function() closeMinigame(true) end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not active then return end
	if input.KeyCode == Enum.KeyCode.Q then
		closeMinigame(true)
	elseif not gameProcessed and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX) then
		calibratePulse()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		local overLeave = false
		for _, object in playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
			if object == cancel or object:IsDescendantOf(cancel) then
				overLeave = true
				break
			end
		end
		if not overLeave then calibratePulse() end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not active or not accepting then return end
	local speed = ({ 0.72, 0.92, 1.16 })[round]
	phase = (phase + dt * speed) % 2
	needlePosition = if phase <= 1 then phase else 2 - phase
	needle.Position = UDim2.fromScale(needlePosition, 0)
end)

Remotes.GeneratorMinigame.OnClientEvent:Connect(function(action: any, first: any, second: any)
	if action == "Begin" and typeof(first) == "Instance" and typeof(second) == "string" then
		if active then closeMinigame(true) end
		active, accepting, awaitingServer = true, true, false
		token, phase, needlePosition, strikes = second, 0, 0, 0
		gui.Enabled = true
		player:SetAttribute("RepairMinigameActive", true)
		ContextActionService:BindActionAtPriority(
			"GeneratorCalibrationMovement",
			blockMovement,
			false,
			3000,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
			Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.LeftControl,
			Enum.KeyCode.Thumbstick1
		)
		setRound(1)
	elseif action == "Result" and active and typeof(first) == "boolean" then
		accepting, awaitingServer = false, false
		status.Text = if first then tostring(second or "GENERATOR ONLINE") else tostring(second or "SIGNAL LOST")
		status.TextColor3 = if first then Color3.fromRGB(93, 220, 139) else Color3.fromRGB(230, 83, 58)
		calibrate.BackgroundColor3 = if first then Color3.fromRGB(24, 72, 47) else Color3.fromRGB(91, 24, 18)
		local oldToken = token
		task.delay(0.9, function()
		if active and token == oldToken then closeMinigame(false) end
		end)
	elseif action == "Locked" and active then
		accepting, awaitingServer = false, false
		local remaining = math.max(0, tonumber(first) or 90)
		status.Text = ("GENERATOR LOCKED  //  %02d:%02d"):format(math.floor(remaining / 60), remaining % 60)
		status.TextColor3 = Color3.fromRGB(230, 83, 58)
		calibrate.BackgroundColor3 = Color3.fromRGB(91, 24, 18)
		local oldToken = token
		task.delay(0.9, function()
			if active and token == oldToken then closeMinigame(false) end
		end)
	end
end)

local function bindCharacter(character: Model)
	-- A death can replace the character on the same frame that the calibration
	-- UI is closing. Always release its high-priority movement sink before the
	-- replacement Humanoid starts accepting player input.
	if active then
		closeMinigame(true)
	else
		ContextActionService:UnbindAction("GeneratorCalibrationMovement")
		gui.Enabled = false
		player:SetAttribute("RepairMinigameActive", false)
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		if active then closeMinigame(true) end
	end)
end
if player.Character then task.spawn(bindCharacter, player.Character) end
player.CharacterAdded:Connect(bindCharacter)
