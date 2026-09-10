--!strict
-- Camera-aimed survivor flashlight. The narrow hotspot and wide spill light the
-- exact point the player looks at while the viewmodel retains a little hand sway.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local obsoleteGrade = game:GetService("Lighting"):FindFirstChild("LanternMonsterDreadGrade")
if obsoleteGrade then obsoleteGrade:Destroy() end

for _, oldName in { "LanternView", "LanternGlow", "HeldLanternView", "HeldFlashlightView" } do
	local old = Workspace:FindFirstChild(oldName)
	if old then old:Destroy() end
end

local flashlight = Instance.new("Model")
flashlight.Name = "HeldFlashlightView"
flashlight.Parent = Workspace

type ViewPart = { part: Part, localCFrame: CFrame }
local viewParts: { ViewPart } = {}

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material, localCFrame: CFrame, shape: Enum.PartType?, transparency: number?): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.Color = color
	object.Material = material
	object.Shape = shape or Enum.PartType.Block
	object.Transparency = transparency or 0
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = false
	object.Parent = flashlight
	table.insert(viewParts, { part = object, localCFrame = localCFrame })
	return object
end

local root = makePart("ViewRoot", Vector3.new(0.05, 0.05, 0.05), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, CFrame.identity, nil, 1)
flashlight.PrimaryPart = root

-- Dark, compact metal flashlight matching the reference silhouette.
makePart("Grip", Vector3.new(1.05, 0.34, 0.34), Color3.fromRGB(23, 27, 29), Enum.Material.Metal, CFrame.new(0.67, -0.63, -1.05) * CFrame.Angles(0, math.rad(90), math.rad(-8)), Enum.PartType.Cylinder)
makePart("GripBandsA", Vector3.new(0.12, 0.39, 0.39), Color3.fromRGB(49, 54, 56), Enum.Material.Metal, CFrame.new(0.42, -0.59, -1.0) * CFrame.Angles(0, math.rad(90), math.rad(-8)), Enum.PartType.Cylinder)
makePart("GripBandsB", Vector3.new(0.12, 0.39, 0.39), Color3.fromRGB(49, 54, 56), Enum.Material.Metal, CFrame.new(0.82, -0.69, -1.11) * CFrame.Angles(0, math.rad(90), math.rad(-8)), Enum.PartType.Cylinder)
makePart("Head", Vector3.new(0.43, 0.62, 0.62), Color3.fromRGB(31, 36, 38), Enum.Material.Metal, CFrame.new(0.2, -0.53, -0.94) * CFrame.Angles(0, math.rad(90), math.rad(-8)), Enum.PartType.Cylinder)
local lens = makePart("Lens", Vector3.new(0.08, 0.52, 0.52), Color3.fromRGB(205, 220, 223), Enum.Material.Glass, CFrame.new(-0.015, -0.475, -0.885) * CFrame.Angles(0, math.rad(90), math.rad(-8)), Enum.PartType.Cylinder, 0.18)
makePart("Switch", Vector3.new(0.22, 0.09, 0.18), Color3.fromRGB(67, 72, 72), Enum.Material.Metal, CFrame.new(0.56, -0.44, -0.96) * CFrame.Angles(0, 0, math.rad(-8)))

-- Lights are parented to an invisible camera-facing emitter rather than the
-- angled viewmodel, making the illumination land exactly on the crosshair.
local emitter = makePart("BeamEmitter", Vector3.new(0.06, 0.06, 0.06), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, CFrame.new(0.16, -0.18, -0.45), nil, 1)

local hotspot = Instance.new("SpotLight")
hotspot.Name = "Hotspot"
hotspot.Face = Enum.NormalId.Front
hotspot.Color = Color3.fromRGB(222, 231, 232)
hotspot.Brightness = 7.2
hotspot.Range = 76
hotspot.Angle = 54
hotspot.Shadows = true
hotspot.Parent = emitter

local spill = Instance.new("SpotLight")
spill.Name = "WideSpill"
spill.Face = Enum.NormalId.Front
spill.Color = Color3.fromRGB(194, 209, 212)
spill.Brightness = 2.4
spill.Range = 49
spill.Angle = 104
spill.Shadows = false
spill.Parent = emitter

local nearFill = Instance.new("PointLight")
nearFill.Name = "NearFill"
nearFill.Color = Color3.fromRGB(188, 204, 207)
nearFill.Brightness = 0.52
nearFill.Range = 12
nearFill.Shadows = false
nearFill.Parent = emitter

local lightEnabled = true
local sway = Vector2.zero
local lastCameraCFrame: CFrame? = nil

local function setEnabled(enabled: boolean)
	lightEnabled = enabled
	hotspot.Enabled = enabled
	spill.Enabled = enabled
	nearFill.Enabled = enabled
	lens.Material = if enabled then Enum.Material.Neon else Enum.Material.Glass
	lens.Color = if enabled then Color3.fromRGB(221, 233, 235) else Color3.fromRGB(56, 65, 67)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.F and player:GetAttribute("Role") ~= "BlindOne" then
		setEnabled(not lightEnabled)
	end
end)

RunService:BindToRenderStep("TheHollowFlashlight", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local isBlindOne = player:GetAttribute("Role") == "BlindOne"
	flashlight.Parent = if isBlindOne then nil else Workspace
	if isBlindOne then return end

	local cameraCFrame = camera.CFrame
	if lastCameraCFrame then
		local relative = lastCameraCFrame:ToObjectSpace(cameraCFrame)
		local x, y = relative:ToOrientation()
		local target = Vector2.new(math.clamp(-y * 2.8, -0.08, 0.08), math.clamp(-x * 2.3, -0.07, 0.07))
		sway = sway:Lerp(target, math.clamp(deltaTime * 8, 0, 1))
	end
	lastCameraCFrame = cameraCFrame
	local breathing = math.sin(os.clock() * 1.55) * 0.008
	local viewCFrame = cameraCFrame * CFrame.Angles(sway.Y + breathing, sway.X, sway.X * 0.25)
	for _, entry in viewParts do
		entry.part.CFrame = viewCFrame * entry.localCFrame
	end
end)

setEnabled(true)
