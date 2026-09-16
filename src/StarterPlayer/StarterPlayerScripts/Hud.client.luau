--!strict
local Responsive = require(game:GetService("ReplicatedStorage"):WaitForChild("ResponsiveUI"))
-- Noise meter, stamina, rock count, objective text, and a dread vignette that closes
-- in as the monster gets near.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local csModule = ReplicatedStorage:WaitForChild("ClientState", 5)
local ClientState = (csModule and require(csModule)) or { stamina = 1 }

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "BlindHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local hunterStatus = Instance.new("TextLabel")
hunterStatus.Name = "BlindOneStatus"
hunterStatus.AnchorPoint = Vector2.new(1, 0)
hunterStatus.BackgroundColor3 = Color3.fromRGB(8, 12, 14)
hunterStatus.BackgroundTransparency = 0.45
hunterStatus.BorderSizePixel = 0
hunterStatus.Font = Enum.Font.GothamBold
hunterStatus.TextColor3 = Color3.fromRGB(226, 232, 231)
hunterStatus.TextXAlignment = Enum.TextXAlignment.Center
hunterStatus.TextScaled = true
hunterStatus.TextWrapped = true
hunterStatus.ZIndex = 12
hunterStatus.Parent = gui
local hunterStatusCorner = Instance.new("UICorner")
hunterStatusCorner.CornerRadius = UDim.new(0, 7)
hunterStatusCorner.Parent = hunterStatus
local hunterStatusConstraint = Instance.new("UITextSizeConstraint")
hunterStatusConstraint.MinTextSize = 11
hunterStatusConstraint.MaxTextSize = 19
hunterStatusConstraint.Parent = hunterStatus
local hunterStatusStroke = Instance.new("UIStroke")
hunterStatusStroke.Color = Color3.fromRGB(99, 38, 35)
hunterStatusStroke.Transparency = 0.2
hunterStatusStroke.Parent = hunterStatus

local takeoverNotice = Instance.new("TextLabel")
takeoverNotice.Name = "BotTakeoverNotice"
takeoverNotice.AnchorPoint = Vector2.new(0.5, 0)
takeoverNotice.BackgroundColor3 = Color3.fromRGB(32, 10, 10)
takeoverNotice.BackgroundTransparency = 0.1
takeoverNotice.BorderSizePixel = 0
takeoverNotice.Font = Enum.Font.GothamBold
takeoverNotice.TextColor3 = Color3.fromRGB(255, 190, 176)
takeoverNotice.TextScaled = true
takeoverNotice.TextWrapped = true
takeoverNotice.Text = "The Blind One has left the game. Switching to BOT."
takeoverNotice.Visible = false
takeoverNotice.ZIndex = 14
takeoverNotice.Parent = gui
local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 7)
noticeCorner.Parent = takeoverNotice
local noticeConstraint = Instance.new("UITextSizeConstraint")
noticeConstraint.MinTextSize = 12
noticeConstraint.MaxTextSize = 19
noticeConstraint.Parent = takeoverNotice
local noticeUntil = 0
local function updateHunterName()
	local username = workspace:GetAttribute("BlindOneUsername")
	hunterStatus.Text = "The Blind One: " .. (if typeof(username) == "string" and username ~= "" and username ~= "BOT" then username else "Bot")
end
updateHunterName()
workspace:GetAttributeChangedSignal("BlindOneUsername"):Connect(updateHunterName)
local function updateTakeoverNotice()
	local takeoverAt = workspace:GetAttribute("BlindOneBotTakeoverAt")
	if typeof(takeoverAt) == "number" then
		local remaining = math.clamp(6 - (workspace:GetServerTimeNow() - takeoverAt), 0, 6)
		noticeUntil = os.clock() + remaining
	end
end
workspace:GetAttributeChangedSignal("BlindOneBotTakeoverAt"):Connect(updateTakeoverNotice)
updateTakeoverNotice()

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
objectiveBanner.Position = UDim2.new(0.5, 0, 0, -112)
objectiveBanner.Size = UDim2.fromOffset(560, 104)
objectiveBanner.BackgroundColor3 = Color3.fromRGB(6, 9, 11)
objectiveBanner.BackgroundTransparency = 0.72
objectiveBanner.BorderSizePixel = 0
objectiveBanner.GroupTransparency = 1
objectiveBanner.Visible = false
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
	{ "1", "EQUIP ROCK" },
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
rockKey.Text = if UserInputService.TouchEnabled then "TAP" else "1"
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

local maxLabel = Instance.new("TextLabel")
maxLabel.AnchorPoint = Vector2.new(0.5, 1)
maxLabel.Position = UDim2.new(0.5, 0, 0, -5)
maxLabel.Size = UDim2.fromOffset(86, 23)
maxLabel.BackgroundTransparency = 1
maxLabel.Font = Enum.Font.GothamBlack
maxLabel.Text = "MAX"
maxLabel.TextColor3 = Color3.fromRGB(239, 57, 43)
maxLabel.TextSize = 17
maxLabel.TextStrokeColor3 = Color3.fromRGB(15, 0, 0)
maxLabel.TextStrokeTransparency = 0.18
maxLabel.Visible = false
maxLabel.Parent = rockSlot

local equipButton = Instance.new("TextButton")
equipButton.Name = "EquipRockButton"
equipButton.Size = UDim2.fromScale(1, 1)
equipButton.BackgroundTransparency = 1
equipButton.TextTransparency = 1
equipButton.ZIndex = 8
equipButton.Parent = rockSlot

if player:GetAttribute("BallEquipped") == nil then
	player:SetAttribute("BallEquipped", false)
end

equipButton.Activated:Connect(function()
	local heldValue = player:GetAttribute("HeldBalls")
	local held = if typeof(heldValue) == "number" then heldValue else 0
	if held <= 0 or player:GetAttribute("Role") == "BlindOne"
		or player:GetAttribute("PhotoModeActive") == true or player:GetAttribute("RepairMinigameActive") == true then
		player:SetAttribute("BallEquipped", false)
		return
	end
	player:SetAttribute("BallEquipped", player:GetAttribute("BallEquipped") ~= true)
end)

local function setRockCount(value: number)
	local count = math.max(0, math.floor(value))
	rockCount.Text = ("x%d"):format(count)
	rockIcon.BackgroundTransparency = if count > 0 then 0 else 0.65
	rockCount.TextTransparency = if count > 0 then 0 else 0.5
	maxLabel.Visible = count >= Config.MaxThrowables
	if count <= 0 and player:GetAttribute("BallEquipped") == true then
		player:SetAttribute("BallEquipped", false)
	end
end

-- Three compact power indicators make the survivor agenda readable without
-- turning the horror HUD into a quest log.
local progressPanel = Instance.new("Frame")
progressPanel.Name = "GateProgress"
progressPanel.AnchorPoint = Vector2.new(0.5, 0)
progressPanel.Position = UDim2.new(0.5, 0, 0, 126)
progressPanel.Size = UDim2.fromOffset(238, 30)
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
for index = 1, 5 do
	local pip = Instance.new("Frame")
	pip.Name = "Mechanism" .. index
	pip.Position = UDim2.fromOffset(96 + (index - 1) * 27, 8)
	pip.Size = UDim2.fromOffset(19, 14)
	pip.BackgroundColor3 = Color3.fromRGB(105, 35, 27)
	pip.BorderSizePixel = 0
	pip.Parent = progressPanel
	local pipCorner = Instance.new("UICorner")
	pipCorner.CornerRadius = UDim.new(0, 4)
	pipCorner.Parent = pip
	table.insert(progressPips, pip)
end

local generatedMap: Folder
while true do
	local candidate = workspace:FindFirstChild("GeneratedMap")
	if candidate and candidate:IsA("Folder")
		and candidate:GetAttribute("MapVersion") == "HollowLabyrinth_4_RandomGenerators"
		and candidate:GetAttribute("Ready") == true then
		generatedMap = candidate
		break
	end
	task.wait(0.1)
end
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

local survivorDirective = "Restore the generators. Stay quiet."
local objectiveReceived = false
local objectiveShown = false
local OBJECTIVE_HIDDEN_POSITION = UDim2.new(0.5, 0, 0, -112)
local OBJECTIVE_SHOWN_POSITION = UDim2.new(0.5, 0, 0, 16)
local OBJECTIVE_TWEEN = TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function revealObjective()
	if objectiveShown then return end
	if not objectiveReceived and player:GetAttribute("Role") ~= "BlindOne" then return end
	if player:GetAttribute("RoleIntroComplete") ~= true then return end
	objectiveShown = true
	objectiveBanner.Visible = true
	objectiveBanner.Position = OBJECTIVE_HIDDEN_POSITION
	objectiveBanner.GroupTransparency = 1
	objectiveRule.Size = UDim2.fromOffset(16, 2)
	local bannerTween = TweenService:Create(objectiveBanner, OBJECTIVE_TWEEN, {
		Position = OBJECTIVE_SHOWN_POSITION,
		GroupTransparency = 0,
	})
	bannerTween.Completed:Once(function()
		objectiveBanner.Position = OBJECTIVE_SHOWN_POSITION
	end)
	bannerTween:Play()
	TweenService:Create(objectiveRule, OBJECTIVE_TWEEN, {
		Size = UDim2.fromOffset(390, 2),
	}):Play()
end

Remotes.Objective.OnClientEvent:Connect(function(text: string)
	if player:GetAttribute("Role") ~= "BlindOne" then survivorDirective = text end
	objectiveReceived = true
	revealObjective()
end)

player:GetAttributeChangedSignal("RoleIntroComplete"):Connect(revealObjective)

Remotes.HeldCount.OnClientEvent:Connect(function(n: number)
	setRockCount(n)
end)

RunService.RenderStepped:Connect(function()
	local isBlindOne = player:GetAttribute("Role") == "BlindOne"
	local isSurvivor = player:GetAttribute("InMatch") == true and player:GetAttribute("Role") == "Survivor"
	hunterStatus.Visible = isSurvivor and (workspace:GetAttribute("BlindOneMode") ~= "Player"
		or workspace:GetAttribute("BlindOneUsername") ~= nil)
	takeoverNotice.Visible = isSurvivor and os.clock() < noticeUntil
	local isPhotoMode = player:GetAttribute("PhotoModeActive") == true
	revealObjective()
	objectiveBanner.Visible = (isSurvivor or (isBlindOne and player:GetAttribute("InMatch") == true)) and objectiveShown
	objectiveTitle.Text = if isBlindOne then "You are the blind one" else "OBJECTIVE"
	objectiveTitle.TextColor3 = if isBlindOne then Color3.fromRGB(235, 68, 65) else Color3.fromRGB(235, 238, 235)
	objectiveEyebrow.Text = if isBlindOne then "THE HOLLOW  /  HUNTER DIRECTIVE" else "THE HOLLOW  /  SURVIVOR DIRECTIVE"
	objectiveRule.BackgroundColor3 = if isBlindOne then Color3.fromRGB(210, 65, 62) else Color3.fromRGB(211, 221, 220)
	objectiveMark.BackgroundColor3 = if isBlindOne then Color3.fromRGB(235, 90, 85) else Color3.fromRGB(226, 232, 230)
	objective.Text = if isBlindOne then "Follow sound silhouettes. Catch every survivor." else survivorDirective
	objective.TextColor3 = if isBlindOne then Color3.fromRGB(230, 165, 160) else Color3.fromRGB(220, 225, 222)
	progressPanel.Visible = isSurvivor and objectiveShown
	panel.Visible = isSurvivor
	controlsPanel.Visible = isSurvivor and not Responsive.IsTouch() and gui.AbsoluteSize.X >= 1000 and gui.AbsoluteSize.Y >= 650
	rockSlot.Visible = isSurvivor
	local ballEquipped = isSurvivor and player:GetAttribute("BallEquipped") == true
	rockSlotStroke.Color = if ballEquipped then Color3.fromRGB(231, 91, 50) else Color3.fromRGB(132, 151, 157)
	rockSlotStroke.Transparency = if ballEquipped then 0 else 0.35
	rockSlotStroke.Thickness = if ballEquipped then 3 else 1
	rockSlot.BackgroundColor3 = if ballEquipped then Color3.fromRGB(37, 16, 12) else Color3.fromRGB(8, 11, 14)
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

Responsive.Watch(gui, function(size, touch)
	local compact = touch or size.X < 1000 or size.Y < 650
	local short = size.Y < 400
	-- Scale these notices by the usable screen's shorter edge, so desktop
	-- text grows without making a wide landscape phone use desktop sizing.
	local noticeScale = math.clamp(math.min(size.X, size.Y) / 900, 0.6, 1.4)
	hunterStatus.Size = UDim2.fromOffset(math.min(size.X - 12, math.floor(320 * noticeScale)), math.floor(40 * noticeScale))
	hunterStatus.Position = UDim2.new(1, -6, 0, 4)
	hunterStatusConstraint.MaxTextSize = math.floor(24 * noticeScale)
	takeoverNotice.Size = UDim2.fromOffset(math.min(size.X - 32, math.floor(780 * noticeScale)), math.floor(60 * noticeScale))
	noticeConstraint.MaxTextSize = math.floor(24 * noticeScale)
	takeoverNotice.Position = UDim2.new(0.5, 0, 0, if compact then (if short then 143 else 177) else 139)
	-- Touch stays inside the physical device safe area. Desktop deliberately
	-- ignores the Core UI top inset because the centered banner does not overlap
	-- Roblox's top-left controls and looked too low when that inset was applied.
	gui.ScreenInsets = if touch then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.None
	local top = if touch then 2 else 8
	OBJECTIVE_SHOWN_POSITION = UDim2.new(0.5,0,0,top)
	if objectiveShown then objectiveBanner.Position = OBJECTIVE_SHOWN_POSITION end
	local width = math.min(560, size.X - 24)
	objectiveBanner.Size = UDim2.fromOffset(width, if short then 60 elseif compact then 72 else 104)
	objectiveEyebrow.Visible = not compact
	objectiveTitle.Visible = true
	objectiveRule.Visible = true
	objectiveTitle.Position = UDim2.fromOffset(0, if compact then 0 else 18)
	objectiveTitle.Size = UDim2.new(1, 0, 0, if short then 23 elseif compact then 30 else 39)
	objectiveTitle.TextSize = if short then 19 elseif compact then 23 else 32
	objectiveRule.Position = UDim2.new(0.5, 0, 0, if short then 24 elseif compact then 31 else 56)
	Responsive.Scale(objectiveRule).Scale = math.min(1, (width-36)/390)
	objective.Position = UDim2.fromOffset(12, if short then 27 elseif compact then 35 else 64)
	objective.Size = UDim2.new(1, -24, 0, 32)
	objective.TextSize = if compact then 13 else 16
	objective.TextWrapped = true
	progressPanel.Position = UDim2.new(0.5, 0, 0, top + (if short then 63 elseif compact then 75 else 110))
	Responsive.Scale(progressPanel).Scale = if compact then 0.8 else 1
	local barScale = if compact then math.min(0.8, (size.X-104)/300) else 1
	Responsive.Scale(panel).Scale = barScale
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, if compact then -36 else 0, 1, -12)
	rockSlot.AnchorPoint = Vector2.new(0, 1)
	rockSlot.Position = UDim2.new(0.5, if compact then 300*barScale/2-26 else 164, 1, -12)
	Responsive.Scale(rockSlot).Scale = if compact then 0.85 else 1
	rockSlot.Size = UDim2.fromOffset(if compact then 76 else 96, 52)
	rockKey.Text = if touch then "TAP" else "1"
	rockKey.TextSize = if touch then 10 else 12
end)
