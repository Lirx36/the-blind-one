--!strict
-- The lantern: a small light held in view, down and to the right, like an FPS item.
-- The monster is blind, so this costs you nothing -- it's purely so you can see.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local body = Instance.new("Part")
body.Name = "LanternView"
body.Size = Vector3.new(0.4, 0.6, 0.4)
body.Color = Color3.fromRGB(34, 27, 19)
body.Material = Enum.Material.Metal
body.Anchored = true
body.CanCollide = false
body.CanQuery = false
body.CastShadow = false
body.Parent = Workspace

local glow = Instance.new("Part")
glow.Name = "LanternGlow"
glow.Shape = Enum.PartType.Ball
glow.Size = Vector3.new(0.3, 0.3, 0.3)
glow.Color = Color3.fromRGB(255, 218, 150)
glow.Material = Enum.Material.Neon
glow.Anchored = true
glow.CanCollide = false
glow.CanQuery = false
glow.CastShadow = false
glow.Parent = Workspace

local light = Instance.new("PointLight")
light.Name = "LanternLight"
light.Range = 15 -- small, tight pool
light.Brightness = 2.6
light.Color = Color3.fromRGB(255, 220, 182)
light.Shadows = false
light.Parent = glow

local OFFSET = CFrame.new(1.1, -1.1, -1.4) -- down / right / slightly forward of the camera

RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local cf = cam.CFrame * OFFSET
	body.CFrame = cf
	glow.CFrame = cf * CFrame.new(0, 0.35, 0)
end)
