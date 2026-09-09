--!strict
-- Studio-only convenience for photographing the solo AI monster.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "PhotoModeHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -84)
label.Size = UDim2.fromOffset(390, 36)
label.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
label.BackgroundTransparency = 0.22
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(225, 235, 238)
label.TextSize = 15
label.Text = "Press P to freeze The Blind One for photos"
label.Parent = gui

UserInputService.InputBegan:Connect(function(input)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if input.KeyCode == Enum.KeyCode.P and not shiftHeld then
		Remotes.PhotoMode:FireServer()
	end
end)

Remotes.PhotoMode.OnClientEvent:Connect(function(frozen: boolean)
	label.Text = if frozen
		then "PHOTO MODE — THE BLIND ONE IS FROZEN  •  P TO RESUME"
		else "PHOTO MODE OFF — THE BLIND ONE IS MOVING  •  P TO FREEZE"
	label.TextColor3 = if frozen then Color3.fromRGB(190, 235, 245) else Color3.fromRGB(225, 235, 238)
end)
