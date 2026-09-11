--!strict
-- Low rolling survivor fog. Atmosphere alone reads as a flat grey grade, so a
-- small fixed emitter pool supplies visible moving fog banks around the camera.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local oldFog = workspace:FindFirstChild("ClientGroundFog")
if oldFog then
	oldFog:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "ClientGroundFog"
folder.Parent = workspace

local OFFSETS = {
	Vector2.new(-36, 22), Vector2.new(-12, 26), Vector2.new(14, 24), Vector2.new(38, 30),
	Vector2.new(-45, 58), Vector2.new(-18, 62), Vector2.new(10, 66), Vector2.new(39, 60),
	Vector2.new(-34, 98), Vector2.new(0, 92), Vector2.new(34, 102), Vector2.new(0, 132),
}

local patches: { { part: Part, emitter: ParticleEmitter } } = {}
for index, offset in OFFSETS do
	local anchor = Instance.new("Part")
	anchor.Name = "FogBank" .. index
	anchor.Size = Vector3.one * 0.1
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Parent = folder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RollingFog"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(
		Color3.fromRGB(133, 143, 147),
		Color3.fromRGB(92, 103, 107)
	)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.16, 0.77),
		NumberSequenceKeypoint.new(0.68, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 14),
		NumberSequenceKeypoint.new(0.55, 24),
		NumberSequenceKeypoint.new(1, 31),
	})
	emitter.Lifetime = NumberRange.new(10, 15)
	emitter.Rate = 1.65
	emitter.Speed = NumberRange.new(0.35, 0.8)
	emitter.Drag = 0.18
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-2.5, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 12)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightInfluence = 0.72
	emitter.LightEmission = 0
	emitter.LockedToPart = false
	emitter.Enabled = false
	emitter.Parent = anchor
	patches[index] = { part = anchor, emitter = emitter }

	anchor:SetAttribute("Side", offset.X)
	anchor:SetAttribute("Forward", offset.Y)
end

local lastVisible = false
local function setVisible(visible: boolean)
	if visible == lastVisible then
		return
	end
	lastVisible = visible
	for _, patch in patches do
		patch.emitter.Enabled = visible
		if not visible then
			patch.emitter:Clear()
		else
			patch.emitter:Emit(3)
		end
	end
end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		setVisible(false)
		return
	end
	local visible = player:GetAttribute("Role") ~= "BlindOne"
		and player:GetAttribute("PhotoModeActive") ~= true
	if not visible then
		setVisible(false)
		return
	end

	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.01 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local cameraPosition = camera.CFrame.Position
	for _, patch in patches do
		local sideValue = patch.part:GetAttribute("Side")
		local forwardValue = patch.part:GetAttribute("Forward")
		local side = if typeof(sideValue) == "number" then sideValue else 0
		local distance = if typeof(forwardValue) == "number" then forwardValue else 40
		patch.part.Position = cameraPosition + right * side + forward * distance + Vector3.new(0, -4.8, 0)
	end
	-- Emit only after all anchors are in front of the active camera, preventing
	-- the first fog burst from appearing at the world origin.
	setVisible(true)
end)
