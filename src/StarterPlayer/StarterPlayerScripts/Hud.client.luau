--!strict
-- Noise meter, stamina, rock count, objective text, and a dread vignette that closes
-- in as the monster gets near.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "BlindHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- replace the mouse cursor with a small centre dot
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
	noiseText.Text = ("NOISE      rocks: %d"):format(n)
end)

RunService.RenderStepped:Connect(function()
	local nr = math.clamp(noise / 100, 0, 1)
	noiseFill.Size = UDim2.fromScale(nr, 1)
	noiseFill.BackgroundColor3 = Color3.fromRGB(120, 200, 140):Lerp(Color3.fromRGB(230, 70, 70), nr)

	local stam = player:GetAttribute("Stamina")
	local sr = typeof(stam) == "number" and math.clamp(stam / Config.StaminaMax, 0, 1) or 1
	stamFill.Size = UDim2.fromScale(sr, 1)
	stamFill.BackgroundColor3 = Color3.fromRGB(90, 150, 230)

	-- dread overlay: base darkness + pulse
	local pulse = dread > 0.15 and (math.sin(os.clock() * (6 + dread * 10)) * 0.5 + 0.5) * dread * 0.3 or 0
	vignette.BackgroundTransparency = math.clamp(1 - (dread * 0.6 + pulse), 0.3, 1)
end)
