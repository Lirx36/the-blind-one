--!strict
-- Noise meter, stamina, rock count, objective text, and a dread vignette that closes
-- in as the monster gets near.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local csModule = ReplicatedStorage:WaitForChild("ClientState", 5)
local ClientState = (csModule and require(csModule)) or { stamina = 1 }

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "BlindHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- hide the backpack UI (the flashlight is a built-in viewmodel) and mouse cursor
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)
UserInputService.MouseIconEnabled = false
local dot = Instance.new("Frame")
dot.Name = "Crosshair"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(5, 5)
dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dot.BackgroundTransparency = 0.1
dot.BorderSizePixel = 0
dot.ZIndex = 10
dot.Parent = gui
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

-- dread overlay: darkens the screen as the monster closes in
local vignette = Instance.new("Frame")
vignette.Name = "Dread"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.ZIndex = 5
vignette.Parent = gui

-- Survivor objective: a restrained analog-horror title card that reads cleanly
-- against both fog and darkness without feeling like a modern quest tracker.
local objectiveBanner = Instance.new("CanvasGroup")
objectiveBanner.Name = "ObjectiveBanner"
objectiveBanner.AnchorPoint = Vector2.new(0.5, 0)
objectiveBanner.Position = UDim2.new(0.5, 0, 0, 16)
objectiveBanner.Size = UDim2.fromOffset(560, 104)
objectiveBanner.BackgroundColor3 = Color3.fromRGB(6, 9, 11)
objectiveBanner.BackgroundTransparency = 0.72
objectiveBanner.BorderSizePixel = 0
objectiveBanner.GroupTransparency = 0
objectiveBanner.Parent = gui

local bannerGradient = Instance.new("UIGradient")
bannerGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.22),
	NumberSequenceKeypoint.new(0.5, 0.05),
	NumberSequenceKeypoint.new(0.8, 0.22),
	NumberSequenceKeypoint.new(1, 1),
})
bannerGradient.Parent = objectiveBanner

local objectiveEyebrow = Instance.new("TextLabel")
objectiveEyebrow.Position = UDim2.fromOffset(0, 7)
objectiveEyebrow.Size = UDim2.new(1, 0, 0, 15)
objectiveEyebrow.BackgroundTransparency = 1
objectiveEyebrow.Font = Enum.Font.GothamMedium
objectiveEyebrow.Text = "THE HOLLOW  /  SURVIVOR DIRECTIVE"
objectiveEyebrow.TextSize = 9
objectiveEyebrow.TextColor3 = Color3.fromRGB(145, 163, 169)
objectiveEyebrow.TextTransparency = 0.13
objectiveEyebrow.Parent = objectiveBanner

local objectiveTitle = Instance.new("TextLabel")
objectiveTitle.Position = UDim2.fromOffset(0, 18)
objectiveTitle.Size = UDim2.new(1, 0, 0, 39)
objectiveTitle.BackgroundTransparency = 1
objectiveTitle.Font = Enum.Font.Garamond
objectiveTitle.Text = "OBJECTIVE"
objectiveTitle.TextSize = 31
objectiveTitle.TextColor3 = Color3.fromRGB(235, 238, 235)
objectiveTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
objectiveTitle.TextStrokeTransparency = 0.25
objectiveTitle.Parent = objectiveBanner

local objectiveRule = Instance.new("Frame")
objectiveRule.AnchorPoint = Vector2.new(0.5, 0)
objectiveRule.Position = UDim2.new(0.5, 0, 0, 56)
objectiveRule.Size = UDim2.fromOffset(390, 2)
objectiveRule.BackgroundColor3 = Color3.fromRGB(211, 221, 220)
objectiveRule.BackgroundTransparency = 0.18
objectiveRule.BorderSizePixel = 0
objectiveRule.Parent = objectiveBanner
local ruleGradient = Instance.new("UIGradient")
ruleGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.18, 0.35),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.82, 0.35),
	NumberSequenceKeypoint.new(1, 1),
})
ruleGradient.Parent = objectiveRule

local objectiveMark = Instance.new("Frame")
objectiveMark.AnchorPoint = Vector2.new(0.5, 0.5)
objectiveMark.Position = UDim2.fromScale(0.5, 0.5)
objectiveMark.Size = UDim2.fromOffset(7, 7)
objectiveMark.Rotation = 45
objectiveMark.BackgroundColor3 = Color3.fromRGB(226, 232, 230)
objectiveMark.BorderSizePixel = 0
objectiveMark.Parent = objectiveRule

local objective = Instance.new("TextLabel")
objective.Position = UDim2.fromOffset(34, 64)
objective.Size = UDim2.new(1, -68, 0, 30)
objective.BackgroundTransparency = 1
objective.Font = Enum.Font.Garamond
objective.TextSize = 17
objective.TextColor3 = Color3.fromRGB(220, 225, 222)
objective.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
objective.TextStrokeTransparency = 0.52
objective.TextWrapped = true
objective.Text = "Awaiting directive..."
objective.Parent = objectiveBanner

-- bottom stack: noise meter + stamina
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 52)
panel.Position = UDim2.new(0.5, -150, 1, -84)
panel.BackgroundTransparency = 1
panel.Parent = gui

-- Compact horror-styled control card. It stays out of the center of the screen
-- and uses keycaps so new players can understand the game at a glance.
local controlsPanel = Instance.new("Frame")
controlsPanel.Name = "Controls"
controlsPanel.AnchorPoint = Vector2.new(0, 1)
controlsPanel.Position = UDim2.new(0, 22, 1, -24)
controlsPanel.Size = UDim2.fromOffset(218, 220)
controlsPanel.BackgroundColor3 = Color3.fromRGB(7, 10, 13)
controlsPanel.BackgroundTransparency = 0.16
controlsPanel.BorderSizePixel = 0
controlsPanel.Parent = gui
local controlsCorner = Instance.new("UICorner")
controlsCorner.CornerRadius = UDim.new(0, 10)
controlsCorner.Parent = controlsPanel
local controlsStroke = Instance.new("UIStroke")
controlsStroke.Color = Color3.fromRGB(115, 145, 157)
controlsStroke.Transparency = 0.45
controlsStroke.Thickness = 1
controlsStroke.Parent = controlsPanel
local controlsGradient = Instance.new("UIGradient")
controlsGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 24, 29)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 7, 9)),
})
controlsGradient.Rotation = 90
controlsGradient.Parent = controlsPanel

local controlsTitle = Instance.new("TextLabel")
controlsTitle.Position = UDim2.fromOffset(14, 9)
controlsTitle.Size = UDim2.fromOffset(190, 22)
controlsTitle.BackgroundTransparency = 1
controlsTitle.Font = Enum.Font.GothamBold
controlsTitle.Text = "CONTROLS"
controlsTitle.TextSize = 13
controlsTitle.TextXAlignment = Enum.TextXAlignment.Left
controlsTitle.TextColor3 = Color3.fromRGB(205, 224, 232)
controlsTitle.Parent = controlsPanel

local controls = {
	{ "WASD", "MOVE" },
	{ "SHIFT", "SPRINT" },
	{ "CTRL", "CROUCH" },
	{ "F", "FLASHLIGHT" },
	{ "E", "INTERACT / PICK UP" },
	{ "LMB", "THROW BALL" },
}
for index, control in controls do
	local rowY = 38 + (index - 1) * 28
	local key = Instance.new("TextLabel")
	key.Position = UDim2.fromOffset(14, rowY)
	key.Size = UDim2.fromOffset(54, 22)
	key.BackgroundColor3 = Color3.fromRGB(28, 38, 44)
	key.BackgroundTransparency = 0.08
	key.BorderSizePixel = 0
	key.Font = Enum.Font.GothamBold
	key.Text = control[1]
	key.TextSize = 10
	key.TextColor3 = Color3.fromRGB(241, 247, 250)
	key.Parent = controlsPanel
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 5)
	keyCorner.Parent = key
	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = Color3.fromRGB(135, 170, 184)
	keyStroke.Transparency = 0.52
	keyStroke.Parent = key

	local action = Instance.new("TextLabel")
	action.Position = UDim2.fromOffset(80, rowY)
	action.Size = UDim2.fromOffset(124, 22)
	action.BackgroundTransparency = 1
	action.Font = Enum.Font.GothamMedium
	action.Text = control[2]
	action.TextSize = 11
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextColor3 = Color3.fromRGB(160, 177, 184)
	action.Parent = controlsPanel
end

local function bar(y: number, labelText: string): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(300, 20)
	holder.Position = UDim2.fromOffset(0, y)
	holder.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	holder.BackgroundTransparency = 0.25
	holder.BorderSizePixel = 0
	holder.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = holder
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	fill.BorderSizePixel = 0
	fill.Parent = holder
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 4)
	fc.Parent = fill
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 12
	text.TextColor3 = Color3.fromRGB(240, 240, 240)
	text.Text = labelText
	text.Parent = holder
	return fill, text
end

local noiseFill, noiseText = bar(0, "NOISE")
local stamFill = bar(26, "STAMINA")

-- A separate hotbar-style rock slot keeps inventory information out of the
-- noise meter and leaves room for the equipped-rock behavior on key 1.
local rockSlot = Instance.new("Frame")
rockSlot.Name = "RockInventorySlot"
rockSlot.AnchorPoint = Vector2.new(0, 1)
rockSlot.Position = UDim2.new(0.5, 164, 1, -32)
rockSlot.Size = UDim2.fromOffset(96, 52)
rockSlot.BackgroundColor3 = Color3.fromRGB(8, 11, 14)
rockSlot.BackgroundTransparency = 0.12
rockSlot.BorderSizePixel = 0
rockSlot.Parent = gui
local rockSlotCorner = Instance.new("UICorner")
rockSlotCorner.CornerRadius = UDim.new(0, 8)
rockSlotCorner.Parent = rockSlot
local rockSlotStroke = Instance.new("UIStroke")
rockSlotStroke.Color = Color3.fromRGB(132, 151, 157)
rockSlotStroke.Transparency = 0.35
rockSlotStroke.Thickness = 1
rockSlotStroke.Parent = rockSlot

local rockKey = Instance.new("TextLabel")
rockKey.Position = UDim2.fromOffset(6, 6)
rockKey.Size = UDim2.fromOffset(19, 19)
rockKey.BackgroundColor3 = Color3.fromRGB(31, 40, 44)
rockKey.BorderSizePixel = 0
rockKey.Font = Enum.Font.GothamBold
rockKey.Text = "1"
rockKey.TextSize = 11
rockKey.TextColor3 = Color3.fromRGB(238, 244, 246)
rockKey.Parent = rockSlot
local rockKeyCorner = Instance.new("UICorner")
rockKeyCorner.CornerRadius = UDim.new(0, 4)
rockKeyCorner.Parent = rockKey

local rockIcon = Instance.new("Frame")
rockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
rockIcon.Position = UDim2.fromOffset(49, 27)
rockIcon.Size = UDim2.fromOffset(25, 25)
rockIcon.BackgroundColor3 = Color3.fromRGB(76, 72, 63)
rockIcon.BorderSizePixel = 0
rockIcon.Rotation = -12
rockIcon.Parent = rockSlot
local rockIconCorner = Instance.new("UICorner")
rockIconCorner.CornerRadius = UDim.new(0.38, 0)
rockIconCorner.Parent = rockIcon
local rockIconStroke = Instance.new("UIStroke")
rockIconStroke.Color = Color3.fromRGB(121, 113, 96)
rockIconStroke.Transparency = 0.3
rockIconStroke.Parent = rockIcon

local rockCount = Instance.new("TextLabel")
rockCount.AnchorPoint = Vector2.new(1, 1)
rockCount.Position = UDim2.new(1, -7, 1, -5)
rockCount.Size = UDim2.fromOffset(35, 20)
rockCount.BackgroundTransparency = 1
rockCount.Font = Enum.Font.GothamBold
rockCount.Text = "x0"
rockCount.TextSize = 14
rockCount.TextXAlignment = Enum.TextXAlignment.Right
rockCount.TextColor3 = Color3.fromRGB(237, 241, 239)
rockCount.Parent = rockSlot

local function setRockCount(value: number)
	local count = math.max(0, math.floor(value))
	rockCount.Text = ("x%d"):format(count)
	rockIcon.BackgroundTransparency = if count > 0 then 0 else 0.65
	rockCount.TextTransparency = if count > 0 then 0 else 0.5
end

-- Three compact power indicators make the survivor agenda readable without
-- turning the horror HUD into a quest log.
local progressPanel = Instance.new("Frame")
progressPanel.Name = "GateProgress"
progressPanel.AnchorPoint = Vector2.new(0.5, 0)
progressPanel.Position = UDim2.new(0.5, 0, 0, 126)
progressPanel.Size = UDim2.fromOffset(196, 30)
progressPanel.BackgroundColor3 = Color3.fromRGB(7, 10, 10)
progressPanel.BackgroundTransparency = 0.30
progressPanel.BorderSizePixel = 0
progressPanel.Parent = gui
local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(0, 8)
progressCorner.Parent = progressPanel
local progressLabel = Instance.new("TextLabel")
progressLabel.Position = UDim2.fromOffset(10, 0)
progressLabel.Size = UDim2.fromOffset(86, 30)
progressLabel.BackgroundTransparency = 1
progressLabel.Font = Enum.Font.GothamBold
progressLabel.Text = "GATE POWER"
progressLabel.TextSize = 10
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.TextColor3 = Color3.fromRGB(161, 176, 171)
progressLabel.Parent = progressPanel
local progressPips: { Frame } = {}
for index = 1, 3 do
	local pip = Instance.new("Frame")
	pip.Name = "Mechanism" .. index
	pip.Position = UDim2.fromOffset(98 + (index - 1) * 29, 8)
	pip.Size = UDim2.fromOffset(20, 14)
	pip.BackgroundColor3 = Color3.fromRGB(105, 35, 27)
	pip.BorderSizePixel = 0
	pip.Parent = progressPanel
	local pipCorner = Instance.new("UICorner")
	pipCorner.CornerRadius = UDim.new(0, 4)
	pipCorner.Parent = pip
	table.insert(progressPips, pip)
end

local generatedMap = workspace:WaitForChild("GeneratedMap")
local function refreshGateProgress()
	local activeValue = generatedMap:GetAttribute("MechanismsActive")
	local active = if typeof(activeValue) == "number" then activeValue else 0
	progressPanel.Visible = player:GetAttribute("Role") ~= "BlindOne"
	for index, pip in progressPips do
		pip.BackgroundColor3 = if index <= active then Color3.fromRGB(80, 188, 123) else Color3.fromRGB(105, 35, 27)
	end
	if generatedMap:GetAttribute("GateOpen") == true then
		progressLabel.Text = "GATE OPEN"
		progressLabel.TextColor3 = Color3.fromRGB(117, 220, 155)
	else
		progressLabel.Text = "GATE POWER"
		progressLabel.TextColor3 = Color3.fromRGB(161, 176, 171)
	end
end
generatedMap:GetAttributeChangedSignal("MechanismsActive"):Connect(refreshGateProgress)
generatedMap:GetAttributeChangedSignal("GateOpen"):Connect(refreshGateProgress)
player:GetAttributeChangedSignal("Role"):Connect(refreshGateProgress)
refreshGateProgress()

-- remote wiring
local noise = 0
Remotes.NoiseMeter.OnClientEvent:Connect(function(v: number)
	noise = v
end)

local dread = 0
Remotes.Dread.OnClientEvent:Connect(function(v: number)
	dread = v
end)

Remotes.Objective.OnClientEvent:Connect(function(text: string)
	objective.Text = text
	if player:GetAttribute("Role") ~= "BlindOne" then
		objectiveBanner.Position = UDim2.new(0.5, 0, 0, 5)
		objectiveBanner.GroupTransparency = 1
		TweenService:Create(
			objectiveBanner,
			TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, 16), GroupTransparency = 0 }
		):Play()
		objectiveRule.Size = UDim2.fromOffset(16, 2)
		TweenService:Create(
			objectiveRule,
			TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(390, 2) }
		):Play()
	end
end)

Remotes.HeldCount.OnClientEvent:Connect(function(n: number)
	setRockCount(n)
end)

RunService.RenderStepped:Connect(function()
	local isBlindOne = player:GetAttribute("Role") == "BlindOne"
	local isPhotoMode = player:GetAttribute("PhotoModeActive") == true
	objectiveBanner.Visible = not isBlindOne
	panel.Visible = not isBlindOne
	controlsPanel.Visible = not isBlindOne
	rockSlot.Visible = not isBlindOne
	local heldValue = player:GetAttribute("HeldBalls")
	if typeof(heldValue) == "number" then
		setRockCount(heldValue)
	end
	local nr = math.clamp(noise / 100, 0, 1)
	noiseFill.Size = UDim2.fromScale(nr, 1)
	noiseFill.BackgroundColor3 = Color3.fromRGB(120, 200, 140):Lerp(Color3.fromRGB(230, 70, 70), nr)

	local sr = math.clamp(ClientState.stamina, 0, 1)
	stamFill.Size = UDim2.fromScale(sr, 1)
	stamFill.BackgroundColor3 = sr < 0.25 and Color3.fromRGB(230, 120, 90) or Color3.fromRGB(90, 150, 230)

	-- Proximity is communicated as a restrained pulse; never crush the whole
	-- scene into black, because the storm lens already shapes the frame edges.
	local pulse = dread > 0.15 and (math.sin(os.clock() * (6 + dread * 10)) * 0.5 + 0.5) * dread * 0.035 or 0
	vignette.BackgroundTransparency = if isBlindOne or isPhotoMode
		then 1
		else math.clamp(1 - (dread * 0.12 + pulse), 0.82, 1)
end)
