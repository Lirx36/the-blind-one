--!strict
-- Noise meter, stamina, rock count, objective text, and a dread vignette that closes
-- in as the monster gets near.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local csModule = ReplicatedStorage:WaitForChild("ClientState", 5)
local ClientState = (csModule and require(csModule)) or { stamina = 1 }

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "BlindHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- hide the backpack UI (the lantern is a forced tool) and the mouse cursor
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

-- objective
local objective = Instance.new("TextLabel")
objective.Size = UDim2.new(1, 0, 0, 30)
objective.Position = UDim2.new(0, 0, 0, 24)
objective.BackgroundTransparency = 1
objective.Font = Enum.Font.GothamMedium
objective.TextSize = 18
objective.TextColor3 = Color3.fromRGB(230, 230, 235)
objective.TextStrokeTransparency = 0.5
objective.Text = ""
objective.Parent = gui

-- bottom stack: noise meter + stamina + rocks
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
	{ "F", "LANTERN" },
	{ "E", "PICK UP BALL" },
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
end)

Remotes.HeldCount.OnClientEvent:Connect(function(n: number)
	noiseText.Text = if n < 0 then "NOISE      balls: ∞" else ("NOISE      balls: %d"):format(n)
end)

RunService.RenderStepped:Connect(function()
	local isBlindOne = player:GetAttribute("Role") == "BlindOne"
	panel.Visible = not isBlindOne
	controlsPanel.Visible = not isBlindOne
	local heldValue = player:GetAttribute("HeldBalls")
	if typeof(heldValue) == "number" then
		noiseText.Text = if heldValue < 0 then "NOISE      balls: ∞" else ("NOISE      balls: %d"):format(heldValue)
	end
	local nr = math.clamp(noise / 100, 0, 1)
	noiseFill.Size = UDim2.fromScale(nr, 1)
	noiseFill.BackgroundColor3 = Color3.fromRGB(120, 200, 140):Lerp(Color3.fromRGB(230, 70, 70), nr)

	local sr = math.clamp(ClientState.stamina, 0, 1)
	stamFill.Size = UDim2.fromScale(sr, 1)
	stamFill.BackgroundColor3 = sr < 0.25 and Color3.fromRGB(230, 120, 90) or Color3.fromRGB(90, 150, 230)

	-- dread overlay: base darkness + pulse
	local pulse = dread > 0.15 and (math.sin(os.clock() * (6 + dread * 10)) * 0.5 + 0.5) * dread * 0.3 or 0
	vignette.BackgroundTransparency = if isBlindOne
		then 1
		else math.clamp(1 - (dread * 0.6 + pulse), 0.3, 1)
end)
