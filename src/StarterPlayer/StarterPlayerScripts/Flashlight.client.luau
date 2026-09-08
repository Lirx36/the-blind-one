--!strict
-- A flashlight that follows the camera. The monster is blind, so light costs you
-- nothing -- it just lets you see. Toggle with F.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local emitter = Instance.new("Part")
emitter.Name = "FlashlightEmitter"
emitter.Size = Vector3.new(0.2, 0.2, 0.2)
emitter.Anchored = true
emitter.CanCollide = false
emitter.CanQuery = false
emitter.Transparency = 1
emitter.Parent = Workspace

local spot = Instance.new("SpotLight")
spot.Angle = 46
spot.Range = 60
spot.Brightness = 3
spot.Shadows = true
spot.Color = Color3.fromRGB(245, 245, 230)
spot.Face = Enum.NormalId.Front
spot.Parent = emitter

local on = true

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY then
		on = not on
		spot.Enabled = on
	end
end)

RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if cam then
		emitter.CFrame = cam.CFrame
	end
end)
