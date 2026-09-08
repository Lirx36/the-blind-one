--!strict
-- Lantern: a warm pool of light that follows you everywhere, so you can always see
-- your immediate surroundings. Plus a focused flashlight beam toggled with F.
-- The monster is blind, so none of this costs you anything.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

------------------------------------------------------------------- lantern (held, always on)
local function attachLantern(char: Model)
	local existing = char:FindFirstChild("HeldLantern")
	if existing then
		existing:Destroy()
	end
	local hand = char:FindFirstChild("RightHand")
		or char:FindFirstChild("Right Arm")
		or char:WaitForChild("HumanoidRootPart")

	-- lantern body you can see in first person
	local body = Instance.new("Part")
	body.Name = "HeldLantern"
	body.Size = Vector3.new(0.45, 0.7, 0.45)
	body.Color = Color3.fromRGB(35, 28, 20)
	body.Material = Enum.Material.Metal
	body.CanCollide = false
	body.Massless = true
	body.CastShadow = false
	body.Parent = char
	body.CFrame = hand.CFrame * CFrame.new(0.1, -0.35, -0.25)
	local w1 = Instance.new("WeldConstraint")
	w1.Part0, w1.Part1 = hand, body
	w1.Parent = body

	-- glowing core + the actual light
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new(0.3, 0.3, 0.3)
	glow.Color = Color3.fromRGB(255, 218, 150)
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	glow.Massless = true
	glow.CastShadow = false
	glow.Parent = body
	glow.CFrame = body.CFrame
	local w2 = Instance.new("WeldConstraint")
	w2.Part0, w2.Part1 = body, glow
	w2.Parent = glow

	local lantern = Instance.new("PointLight")
	lantern.Name = "Lantern"
	lantern.Range = 15 -- small, tight pool around the lantern
	lantern.Brightness = 2.6
	lantern.Color = Color3.fromRGB(255, 220, 182)
	lantern.Shadows = false
	lantern.Parent = glow
end
if player.Character then
	attachLantern(player.Character)
end
player.CharacterAdded:Connect(function(char)
	task.wait(0.2) -- let limbs load
	attachLantern(char)
end)

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
beam.Angle = 48
beam.Range = 55
beam.Brightness = 1.6
beam.Shadows = false -- SpotLight shadows are the flickery kind; keep the beam clean
beam.Color = Color3.fromRGB(240, 240, 220)
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
