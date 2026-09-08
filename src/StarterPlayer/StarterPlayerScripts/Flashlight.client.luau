--!strict
-- Lantern: a warm pool of light that follows you everywhere, so you can always see
-- your immediate surroundings. Plus a focused flashlight beam toggled with F.
-- The monster is blind, so none of this costs you anything.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

------------------------------------------------------------------- lantern (always on)
local function attachLantern(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart")
	local existing = hrp:FindFirstChild("Lantern")
	if existing then
		existing:Destroy()
	end
	local lantern = Instance.new("PointLight")
	lantern.Name = "Lantern"
	lantern.Range = 30
	lantern.Brightness = 2.4
	lantern.Color = Color3.fromRGB(255, 224, 188)
	lantern.Shadows = true
	lantern.Parent = hrp
end
if player.Character then
	attachLantern(player.Character)
end
player.CharacterAdded:Connect(attachLantern)

------------------------------------------------------------------- flashlight beam (toggle F)
local emitter = Instance.new("Part")
emitter.Name = "FlashlightEmitter"
emitter.Size = Vector3.new(0.2, 0.2, 0.2)
emitter.Anchored = true
emitter.CanCollide = false
emitter.CanQuery = false
emitter.Transparency = 1
emitter.Parent = Workspace

local beam = Instance.new("SpotLight")
beam.Angle = 55
beam.Range = 75
beam.Brightness = 2.6
beam.Shadows = true
beam.Color = Color3.fromRGB(245, 245, 225)
beam.Face = Enum.NormalId.Front
beam.Parent = emitter

local beamOn = true
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY then
		beamOn = not beamOn
		beam.Enabled = beamOn
	end
end)

RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if cam then
		emitter.CFrame = cam.CFrame
	end
end)
