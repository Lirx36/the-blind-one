--!strict
-- Hand-tracked survivor flashlight. It uses the old lantern's proven hand-first
-- positioning, but aims both the prop and its light at the camera crosshair.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

local obsoleteGrade = Lighting:FindFirstChild("LanternMonsterDreadGrade")
if obsoleteGrade then obsoleteGrade:Destroy() end
for _, oldName in { "LanternView", "LanternGlow", "HeldLanternView", "HeldFlashlightView" } do
	local old = Workspace:FindFirstChild(oldName)
	if old then old:Destroy() end
end

local flashlight = Instance.new("Model")
flashlight.Name = "HeldFlashlightView"
flashlight.Parent = Workspace

local root = Instance.new("Part")
root.Name = "ViewRoot"
root.Size = Vector3.new(0.04, 0.04, 0.04)
root.Transparency = 1
root.Anchored = true
root.CanCollide, root.CanTouch, root.CanQuery, root.CastShadow = false, false, false, false
root.CFrame = CFrame.identity
root.Parent = flashlight
flashlight.PrimaryPart = root

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material, localCFrame: CFrame, shape: Enum.PartType?, transparency: number?): Part
	local object = Instance.new("Part")
	object.Name, object.Size, object.Color, object.Material = name, size, color, material
	object.Shape, object.Transparency = shape or Enum.PartType.Block, transparency or 0
	object.Anchored = true
	object.CanCollide, object.CanTouch, object.CanQuery, object.CastShadow = false, false, false, false
	object.CFrame = localCFrame
	object.Parent = flashlight
	return object
end

local blackMetal = Color3.fromRGB(20, 23, 25)
local edgeMetal = Color3.fromRGB(55, 62, 65)
local rubber = Color3.fromRGB(13, 15, 16)
local axisForward = CFrame.Angles(0, math.rad(90), 0)

-- Pivot sits inside the player's palm. The body extends forward along local -Z.
makePart("RubberGrip", Vector3.new(0.9, 0.34, 0.34), rubber, Enum.Material.Rubber, CFrame.new(0, 0, 0.08) * axisForward, Enum.PartType.Cylinder)
makePart("MainBarrel", Vector3.new(0.92, 0.3, 0.3), blackMetal, Enum.Material.Metal, CFrame.new(0, 0, -0.48) * axisForward, Enum.PartType.Cylinder)
makePart("TailCap", Vector3.new(0.13, 0.4, 0.4), edgeMetal, Enum.Material.Metal, CFrame.new(0, 0, 0.56) * axisForward, Enum.PartType.Cylinder)
makePart("Head", Vector3.new(0.32, 0.58, 0.58), blackMetal, Enum.Material.Metal, CFrame.new(0, 0, -1.08) * axisForward, Enum.PartType.Cylinder)
makePart("Bezel", Vector3.new(0.12, 0.67, 0.67), edgeMetal, Enum.Material.Metal, CFrame.new(0, 0, -1.29) * axisForward, Enum.PartType.Cylinder)
local lens = makePart("Lens", Vector3.new(0.045, 0.55, 0.55), Color3.fromRGB(172, 189, 193), Enum.Material.Glass, CFrame.new(0, 0, -1.38) * axisForward, Enum.PartType.Cylinder, 0.24)
makePart("Switch", Vector3.new(0.2, 0.09, 0.18), Color3.fromRGB(91, 99, 101), Enum.Material.Metal, CFrame.new(0, 0.2, -0.38))

-- Cylinder geometry needs a 90-degree rotation to point forward, which also
-- rotates its Front face sideways. Keep lighting on an unrotated invisible
-- emitter so both SpotLights always follow the model's true -Z/look direction.
local beamEmitter = makePart("BeamEmitter", Vector3.new(0.03, 0.03, 0.03), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, CFrame.new(0, 0, -1.41), nil, 1)

for index = 1, 6 do
	makePart("GripRib", Vector3.new(0.045, 0.38, 0.38), edgeMetal, Enum.Material.Metal, CFrame.new(0, 0, 0.42 - index * 0.13) * axisForward, Enum.PartType.Cylinder)
end

local hotspot = Instance.new("SpotLight")
hotspot.Name = "FocusedHotspot"
hotspot.Face = Enum.NormalId.Front
hotspot.Color = Color3.fromRGB(222, 230, 231)
hotspot.Brightness = 1.9
hotspot.Range = 44
hotspot.Angle = 34
hotspot.Shadows = true
hotspot.Parent = beamEmitter

local spill = Instance.new("SpotLight")
spill.Name = "SoftSpill"
spill.Face = Enum.NormalId.Front
spill.Color = Color3.fromRGB(188, 202, 205)
spill.Brightness = 0.28
spill.Range = 25
spill.Angle = 54
spill.Shadows = false
spill.Parent = beamEmitter

local nearFill = Instance.new("PointLight")
nearFill.Name = "NearFill"
nearFill.Color = Color3.fromRGB(184, 197, 200)
nearFill.Brightness = 0.04
nearFill.Range = 3.5
nearFill.Shadows = false
nearFill.Parent = beamEmitter

local rightHand: BasePart? = nil
local lightEnabled = true

local function findRightHand(character: Model)
	local candidate = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	rightHand = if candidate and candidate:IsA("BasePart") then candidate else nil
	if not rightHand then
		task.spawn(function()
			local later = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
			if later and later:IsA("BasePart") and player.Character == character then rightHand = later end
		end)
	end
end

if player.Character then findRightHand(player.Character) end
player.CharacterAdded:Connect(function(character)
	rightHand = nil
	findRightHand(character)
end)

local function applyLightState()
	hotspot.Enabled, spill.Enabled, nearFill.Enabled = lightEnabled, lightEnabled, lightEnabled
	lens.Material = Enum.Material.Glass
	lens.Transparency = if lightEnabled then 0.18 else 0.46
	lens.Color = if lightEnabled then Color3.fromRGB(185, 201, 204) else Color3.fromRGB(45, 53, 55)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F and player:GetAttribute("Role") ~= "BlindOne" then
		lightEnabled = not lightEnabled
		applyLightState()
	end
end)
applyLightState()

RunService:BindToRenderStep("HeldFlashlightView", Enum.RenderPriority.Camera.Value + 2, function()
	if player:GetAttribute("InMatch") ~= true or player:GetAttribute("Role") == "BlindOne" or player:GetAttribute("PhotoModeActive") == true then
		if flashlight.Parent then flashlight.Parent = nil end
		return
	elseif not flashlight.Parent then
		flashlight.Parent = Workspace
	end

	local camera = Workspace.CurrentCamera
	local hand = rightHand
	if not camera or not hand or not hand.Parent then return end

	local lookDown = math.clamp(-camera.CFrame.LookVector.Y, 0, 1)
	local handDepth = (hand.Position - camera.CFrame.Position):Dot(camera.CFrame.LookVector)
	local handCenter = hand.Position + camera.CFrame.LookVector * 0.22 - camera.CFrame.UpVector * (0.05 + 0.08 * lookDown)
	local cameraCenter = (camera.CFrame * CFrame.new(0.7, -0.54 - 0.2 * lookDown, -1.35)).Position
	-- Normal avatars use the real hand. The fallback prevents unusual rigs from
	-- putting the prop behind the camera while keeping it on the right-hand side.
	local center = if handDepth > 0.18 then handCenter:Lerp(cameraCenter, 0.2) else cameraCenter

	local movement = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then movement = math.clamp(humanoid.MoveDirection.Magnitude, 0, 1) end
	local walkClock = os.clock() * 8.2
	local bob = camera.CFrame.UpVector * (math.sin(walkClock * 2) * 0.018 * movement)
		+ camera.CFrame.RightVector * (math.sin(walkClock) * 0.025 * movement)
	local roll = math.rad(math.sin(walkClock) * 1.4 * movement)
	local target = CFrame.lookAt(center + bob, center + bob + camera.CFrame.LookVector, camera.CFrame.UpVector) * CFrame.Angles(0, 0, roll)
	-- Direct hand tracking prevents the sideways trailing seen with extra easing.
	flashlight:PivotTo(target)
end)
