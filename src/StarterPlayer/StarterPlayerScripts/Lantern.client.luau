--!strict
-- A client-side lantern that hangs from the player's posed right hand. The blind
-- monster does not react to light, so F only changes what the player can see.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Clear placeholders left by an older live-synced version.
for _, oldName in { "LanternView", "LanternGlow", "HeldLanternView" } do
	local old = Workspace:FindFirstChild(oldName)
	if old then
		old:Destroy()
	end
end

local lantern = Instance.new("Model")
lantern.Name = "HeldLanternView"
lantern.Parent = Workspace

local root = Instance.new("Part")
root.Name = "ViewRoot"
root.Size = Vector3.new(0.05, 0.05, 0.05)
root.Transparency = 1
root.Anchored = true
root.CanCollide = false
root.CanTouch = false
root.CanQuery = false
root.CastShadow = false
root.CFrame = CFrame.identity
root.Parent = lantern
lantern.PrimaryPart = root

local function makePart(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	localCFrame: CFrame,
	shape: Enum.PartType?,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = localCFrame
	part.Parent = lantern
	return part
end

local darkMetal = Color3.fromRGB(24, 25, 27)
local edgeMetal = Color3.fromRGB(106, 68, 36)
local warmGlass = Color3.fromRGB(255, 184, 92)
local cylinderRotation = CFrame.Angles(0, 0, math.rad(90))

local glass = makePart(
	"GlassChamber",
	Vector3.new(0.72, 0.54, 0.54),
	warmGlass,
	Enum.Material.Glass,
	CFrame.new(0, 0, 0) * cylinderRotation,
	Enum.PartType.Cylinder,
	0.34
)
local glow = makePart(
	"WarmCore",
	Vector3.new(0.24, 0.24, 0.24),
	Color3.fromRGB(255, 225, 150),
	Enum.Material.Neon,
	CFrame.new(0, -0.02, 0),
	Enum.PartType.Ball,
	0.04
)

makePart("Base", Vector3.new(0.18, 0.68, 0.68), darkMetal, Enum.Material.Metal,
	CFrame.new(0, -0.48, 0) * cylinderRotation, Enum.PartType.Cylinder)
makePart("BaseTrim", Vector3.new(0.08, 0.75, 0.75), edgeMetal, Enum.Material.Metal,
	CFrame.new(0, -0.37, 0) * cylinderRotation, Enum.PartType.Cylinder)
makePart("Top", Vector3.new(0.16, 0.65, 0.65), darkMetal, Enum.Material.Metal,
	CFrame.new(0, 0.46, 0) * cylinderRotation, Enum.PartType.Cylinder)
makePart("TopTrim", Vector3.new(0.07, 0.72, 0.72), edgeMetal, Enum.Material.Metal,
	CFrame.new(0, 0.36, 0) * cylinderRotation, Enum.PartType.Cylinder)
makePart("Chimney", Vector3.new(0.2, 0.34, 0.34), darkMetal, Enum.Material.Metal,
	CFrame.new(0, 0.63, 0) * cylinderRotation, Enum.PartType.Cylinder)

for _, x in { -0.29, 0.29 } do
	for _, z in { -0.29, 0.29 } do
		makePart("CageBar", Vector3.new(0.055, 0.76, 0.055), darkMetal, Enum.Material.Metal,
			CFrame.new(x, 0, z), Enum.PartType.Block)
	end
end

makePart("HandleLeft", Vector3.new(0.06, 0.55, 0.06), edgeMetal, Enum.Material.Metal,
	CFrame.new(-0.37, 0.79, 0), Enum.PartType.Block)
makePart("HandleRight", Vector3.new(0.06, 0.55, 0.06), edgeMetal, Enum.Material.Metal,
	CFrame.new(0.37, 0.79, 0), Enum.PartType.Block)
makePart("HandleGrip", Vector3.new(0.8, 0.075, 0.09), darkMetal, Enum.Material.Metal,
	CFrame.new(0, 1.05, 0), Enum.PartType.Block)

local pointLight = Instance.new("PointLight")
pointLight.Name = "WarmFill"
pointLight.Color = Color3.fromRGB(255, 194, 118)
pointLight.Brightness = 3.2
pointLight.Range = 24
pointLight.Shadows = false
pointLight.Parent = glow

local beam = Instance.new("SpotLight")
beam.Name = "ForwardBeam"
beam.Color = Color3.fromRGB(255, 220, 170)
beam.Brightness = 5.5
beam.Range = 45
beam.Angle = 96
beam.Face = Enum.NormalId.Front
beam.Shadows = false
beam.Parent = glass

local rightHand: BasePart? = nil
local currentCFrame: CFrame? = nil
local lightEnabled = true

local function findRightHand(character: Model)
	local candidate = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	rightHand = if candidate and candidate:IsA("BasePart") then candidate else nil
	if not rightHand then
		task.spawn(function()
			local later = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
			if later and later:IsA("BasePart") and player.Character == character then
				rightHand = later
			end
		end)
	end
end

if player.Character then
	findRightHand(player.Character)
end
player.CharacterAdded:Connect(function(character)
	rightHand = nil
	currentCFrame = nil
	findRightHand(character)
end)

local function applyLightState()
	pointLight.Enabled = lightEnabled
	beam.Enabled = lightEnabled
	glow.Transparency = if lightEnabled then 0.04 else 0.72
	glass.Transparency = if lightEnabled then 0.34 else 0.56
	glow.Color = if lightEnabled then Color3.fromRGB(255, 225, 150) else Color3.fromRGB(65, 48, 34)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.F then
		lightEnabled = not lightEnabled
		applyLightState()
	end
end)

applyLightState()

RunService:BindToRenderStep("HeldLanternView", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if player:GetAttribute("Role") == "BlindOne" then
		if lantern.Parent then
			lantern.Parent = nil
		end
		return
	elseif not lantern.Parent then
		lantern.Parent = Workspace
		currentCFrame = nil
	end
	local camera = Workspace.CurrentCamera
	local hand = rightHand
	if not camera or not hand or not hand.Parent then
		return
	end

	local horizontalLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if horizontalLook.Magnitude < 0.001 then
		horizontalLook = Vector3.new(0, 0, -1)
	else
		horizontalLook = horizontalLook.Unit
	end

	local handCenter = hand.Position - Vector3.new(0, 0.7, 0)
	local cameraCenter = (camera.CFrame * CFrame.new(0.72, -0.58, -1.55)).Position
	local handDepth = (hand.Position - camera.CFrame.Position):Dot(camera.CFrame.LookVector)
	-- Normally the lantern hangs directly from the hand. If an unusual avatar or
	-- animation leaves that hand behind the camera, pull it into the expected FPS
	-- carrying position instead of letting the prop disappear completely.
	local center = if handDepth > 0.2 then handCenter:Lerp(cameraCenter, 0.45) else cameraCenter
	local movement = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		movement = math.clamp(humanoid.MoveDirection.Magnitude, 0, 1)
	end
	local sway = math.rad(math.sin(os.clock() * 7) * 1.5 * movement)
	local target = CFrame.lookAt(center, center + horizontalLook, Vector3.yAxis) * CFrame.Angles(0, 0, sway)

	if not currentCFrame then
		currentCFrame = target
	else
		currentCFrame = currentCFrame:Lerp(target, 1 - math.exp(-18 * dt))
	end
	lantern:PivotTo(currentCFrame :: CFrame)
end)
