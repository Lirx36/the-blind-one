--!strict
-- Runtime greybox for The Hollow: a cursed forest settlement built around
-- readable landmarks and looping paths instead of a room maze.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local MAP_VERSION = "TheHollow_3"
local oldMap = Workspace:FindFirstChild("GeneratedMap")
if oldMap and oldMap:GetAttribute("MapVersion") == MAP_VERSION then
	return
elseif oldMap then
	oldMap:Destroy()
end

local map = Instance.new("Folder")
map.Name = "GeneratedMap"
map:SetAttribute("MapVersion", MAP_VERSION)
map:SetAttribute("MechanismsActive", 0)
map:SetAttribute("MechanismsTotal", 3)
map:SetAttribute("GateOpen", false)
map.Parent = Workspace

local rng = Random.new(4815)

local function part(props: { [string]: any }, parent: Instance?): Part
	local object = Instance.new("Part")
	object.Anchored = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent or map
	return object
end

local function cylinderBetween(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, parent: Instance): Part
	local delta = b - a
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(delta.Magnitude, thickness, thickness),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(-90), 0),
		Color = color,
		Material = Enum.Material.Wood,
	}, parent)
end

local function pointLight(parent: Instance, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = parent
end

local function addSign(parent: Instance, text: string, position: Vector3, yaw: number)
	part({
		Name = text .. " Signpost",
		Size = Vector3.new(0.45, 5, 0.45),
		Position = position + Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(38, 25, 17),
		Material = Enum.Material.Wood,
	}, parent)
	local board = part({
		Name = "Sign",
		Size = Vector3.new(7, 2.1, 0.38),
		CFrame = CFrame.new(position + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(yaw), 0),
		Color = Color3.fromRGB(48, 31, 21),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(184, 169, 140)
	label.TextStrokeTransparency = 0.45
	label.Parent = gui
end

--------------------------------------------------------------------- atmosphere
pcall(function()
	(Lighting :: any).Technology = Enum.Technology.Future
end)
Lighting.ClockTime = 2.15
Lighting.Brightness = 1.15
Lighting.Ambient = Color3.fromRGB(24, 28, 31)
Lighting.OutdoorAmbient = Color3.fromRGB(15, 20, 23)
Lighting.EnvironmentDiffuseScale = 0.22
Lighting.EnvironmentSpecularScale = 0.72
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.48
Lighting.ExposureCompensation = -0.28
Lighting.FogColor = Color3.fromRGB(32, 39, 43)
Lighting.FogStart = 22
Lighting.FogEnd = 142

for _, effect in Lighting:GetChildren() do
	if effect.Name == "TheHollowGrade"
		or effect.Name == "TheHollowAtmosphere"
		or effect.Name == "TheHollowBloom"
		or effect.Name == "TheHollowDepth" then
		effect:Destroy()
	elseif effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") then
		effect.Enabled = false
	elseif effect:IsA("Atmosphere") then
		effect.Density = 0
	end
end

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "TheHollowGrade"
grade.Brightness = -0.025
grade.Contrast = 0.24
grade.Saturation = -0.48
grade.TintColor = Color3.fromRGB(190, 207, 211)
grade.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "TheHollowAtmosphere"
atmosphere.Color = Color3.fromRGB(86, 99, 103)
atmosphere.Decay = Color3.fromRGB(17, 24, 28)
atmosphere.Density = 0.36
atmosphere.Haze = 2.15
atmosphere.Glare = 0
atmosphere.Offset = -0.22
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "TheHollowBloom"
bloom.Intensity = 0.24
bloom.Size = 38
bloom.Threshold = 1.12
bloom.Parent = Lighting

local depth = Instance.new("DepthOfFieldEffect")
depth.Name = "TheHollowDepth"
depth.FarIntensity = 0.13
depth.FocusDistance = 52
depth.InFocusRadius = 38
depth.NearIntensity = 0.025
depth.Parent = Lighting

--------------------------------------------------------------------- ground and routes
part({
	Name = "ForestFloor",
	Size = Vector3.new(360, 2, 360),
	Position = Vector3.new(0, -1, 0),
	Color = Color3.fromRGB(24, 28, 22),
	Material = Enum.Material.Ground,
})

local routes: { { Vector3 } } = {
	{ Vector3.new(66, 0, -68), Vector3.new(5, 0, 20) },
	{ Vector3.new(5, 0, 20), Vector3.new(98, 0, 72) },
	{ Vector3.new(5, 0, 20), Vector3.new(-104, 0, 65) },
	{ Vector3.new(-104, 0, 65), Vector3.new(-78, 0, -86) },
	{ Vector3.new(-78, 0, -86), Vector3.new(0, 0, -166) },
	{ Vector3.new(66, 0, -68), Vector3.new(0, 0, -166) },
	{ Vector3.new(98, 0, 72), Vector3.new(66, 0, -68) },
	{ Vector3.new(-78, 0, -86), Vector3.new(5, 0, 20) },
}

local function pathStrip(a: Vector3, b: Vector3, width: number)
	local midpoint = (a + b) / 2
	part({
		Name = "MuddyPath",
		Size = Vector3.new(width, 0.18, (b - a).Magnitude),
		CFrame = CFrame.lookAt(midpoint + Vector3.new(0, 0.05, 0), b),
		Color = Color3.fromRGB(39, 32, 24),
		Material = Enum.Material.Mud,
		Reflectance = 0.08,
		CanCollide = false,
	})
end

for _, route in routes do
	pathStrip(route[1], route[2], 10)
end

-- Thin, irregular wet patches catch the moon and lantern without changing
-- collision or pathfinding. Their low opacity keeps them grounded in the mud.
for index = 1, 34 do
	local route = routes[((index - 1) % #routes) + 1]
	local alpha = rng:NextNumber(0.08, 0.92)
	local center = route[1]:Lerp(route[2], alpha)
	local direction = route[2] - route[1]
	local yaw = math.atan2(-direction.X, -direction.Z)
	part({
		Name = "RainPuddle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.035, rng:NextNumber(1.3, 3.8), rng:NextNumber(2.2, 6.0)),
		CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-3.4, 3.4), 0.17, rng:NextNumber(-3.4, 3.4)))
			* CFrame.Angles(0, yaw + rng:NextNumber(-0.35, 0.35), math.rad(90)),
		Color = Color3.fromRGB(61, 73, 78),
		Material = Enum.Material.Glass,
		Transparency = rng:NextNumber(0.34, 0.53),
		Reflectance = 0.28,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
	})
end

for _, wall in {
	{ Vector3.new(-180, 18, 0), Vector3.new(2, 36, 360) },
	{ Vector3.new(180, 18, 0), Vector3.new(2, 36, 360) },
	{ Vector3.new(0, 18, -180), Vector3.new(360, 36, 2) },
	{ Vector3.new(0, 18, 180), Vector3.new(360, 36, 2) },
} do
	part({ Name = "ForestBoundary", Position = wall[1], Size = wall[2], Transparency = 1, CanQuery = false, CastShadow = false })
end

--------------------------------------------------------------------- forest dressing
local clearZones = {
	{ Vector3.new(5, 0, 20), 35 },
	{ Vector3.new(98, 0, 72), 29 },
	{ Vector3.new(-104, 0, 65), 31 },
	{ Vector3.new(-78, 0, -86), 31 },
	{ Vector3.new(66, 0, -68), 25 },
	{ Vector3.new(0, 0, -166), 24 },
}

local function distanceToRoute(position: Vector3, a: Vector3, b: Vector3): number
	local p = Vector2.new(position.X, position.Z)
	local start = Vector2.new(a.X, a.Z)
	local finish = Vector2.new(b.X, b.Z)
	local segment = finish - start
	local alpha = math.clamp((p - start):Dot(segment) / math.max(segment:Dot(segment), 0.001), 0, 1)
	return (p - (start + segment * alpha)).Magnitude
end

local function treeAllowed(position: Vector3): boolean
	for _, zone in clearZones do
		if (Vector2.new(position.X, position.Z) - Vector2.new(zone[1].X, zone[1].Z)).Magnitude < zone[2] then
			return false
		end
	end
	for _, route in routes do
		if distanceToRoute(position, route[1], route[2]) < 8.5 then
			return false
		end
	end
	return true
end

local function deadTree(position: Vector3, height: number, yaw: number, withNeedles: boolean)
	local model = Instance.new("Model")
	model.Name = "DeadPine"
	model.Parent = map
	local bark = Color3.fromRGB(rng:NextInteger(24, 34), rng:NextInteger(19, 27), rng:NextInteger(15, 21))
	local base = position + Vector3.new(0, 0.35, 0)
	local top = position + Vector3.new(0, height, 0)
	cylinderBetween("Trunk", base, top, math.max(1.1, height * 0.075), bark, model)
	for branchIndex = 1, 3 do
		local branchY = height * (0.46 + branchIndex * 0.13)
		local angle = yaw + branchIndex * 2.0
		local start = position + Vector3.new(0, branchY, 0)
		local length = height * (0.20 - branchIndex * 0.02)
		local finish = start + Vector3.new(math.cos(angle) * length, length * 0.44, math.sin(angle) * length)
		cylinderBetween("CrookedBranch", start, finish, math.max(0.35, height * 0.028), bark, model)
		local fork = finish + Vector3.new(math.cos(angle + 0.8) * length * 0.38, length * 0.32, math.sin(angle + 0.8) * length * 0.38)
		cylinderBetween("Fork", finish, fork, math.max(0.23, height * 0.019), bark, model)
	end
	if withNeedles then
		for index = 1, 2 do
			part({
				Name = "BlackNeedles", Shape = Enum.PartType.Ball, Size = Vector3.new(7 - index, 5, 7 - index),
				Position = position + Vector3.new(0, height * (0.67 + index * 0.10), 0), Color = Color3.fromRGB(8, 18, 14),
				Material = Enum.Material.LeafyGrass, CanCollide = false,
			}, model)
		end
	end
end

local madeTrees = 0
for _ = 1, 500 do
	if madeTrees >= 72 then break end
	local position = Vector3.new(rng:NextNumber(-172, 172), 0, rng:NextNumber(-172, 172))
	if treeAllowed(position) then
		madeTrees += 1
		deadTree(position, rng:NextNumber(17, 29), rng:NextNumber(0, math.pi * 2), madeTrees % 4 == 0)
	end
end

for _ = 1, 34 do
	local position = Vector3.new(rng:NextNumber(-168, 168), 0.65, rng:NextNumber(-168, 168))
	if treeAllowed(position) then
		part({
			Name = "MossyBoulder", Shape = Enum.PartType.Ball,
			Size = Vector3.new(rng:NextNumber(2.0, 5.0), rng:NextNumber(1.3, 3.0), rng:NextNumber(2.0, 5.0)),
			CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
			Color = Color3.fromRGB(38, 43, 37), Material = Enum.Material.Rock,
		})
	end
end

--------------------------------------------------------------------- chapel
local chapel = Instance.new("Model")
chapel.Name = "RuinedChapel"
chapel.Parent = map
local chapelCenter = Vector3.new(5, 0, 20)
part({ Name = "StoneFloor", Size = Vector3.new(32, 1, 44), Position = chapelCenter + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(43, 43, 40), Material = Enum.Material.Slate }, chapel)
part({ Name = "BackWall", Size = Vector3.new(32, 15, 2), Position = chapelCenter + Vector3.new(0, 7.5, 21), Color = Color3.fromRGB(38, 39, 38), Material = Enum.Material.Cobblestone }, chapel)
part({ Name = "LeftWall", Size = Vector3.new(2, 15, 44), Position = chapelCenter + Vector3.new(-15, 7.5, 0), Color = Color3.fromRGB(38, 39, 38), Material = Enum.Material.Cobblestone }, chapel)
part({ Name = "RightWallBroken", Size = Vector3.new(2, 10, 23), Position = chapelCenter + Vector3.new(15, 5, 9), Color = Color3.fromRGB(38, 39, 38), Material = Enum.Material.Cobblestone }, chapel)
part({ Name = "FrontLeft", Size = Vector3.new(11, 15, 2), Position = chapelCenter + Vector3.new(-10.5, 7.5, -21), Color = Color3.fromRGB(38, 39, 38), Material = Enum.Material.Cobblestone }, chapel)
part({ Name = "FrontRight", Size = Vector3.new(11, 15, 2), Position = chapelCenter + Vector3.new(10.5, 7.5, -21), Color = Color3.fromRGB(38, 39, 38), Material = Enum.Material.Cobblestone }, chapel)
part({ Name = "BrokenRoof", Size = Vector3.new(34, 1, 24), CFrame = CFrame.new(chapelCenter + Vector3.new(-0.5, 15.2, 9)) * CFrame.Angles(0, 0, math.rad(4)), Color = Color3.fromRGB(27, 24, 22), Material = Enum.Material.WoodPlanks }, chapel)
for row = 1, 3 do
	local z = chapelCenter.Z - 8 + row * 8
	for side = -1, 1, 2 do
		part({ Name = "Pew", Size = Vector3.new(10, 1.1, 2), Position = Vector3.new(chapelCenter.X + side * 7, 1.6, z), Color = Color3.fromRGB(48, 31, 20), Material = Enum.Material.WoodPlanks }, chapel)
	end
end
local altar = part({ Name = "AltarEmber", Size = Vector3.new(7, 3, 3), Position = chapelCenter + Vector3.new(0, 2, 16), Color = Color3.fromRGB(29, 21, 18), Material = Enum.Material.Slate }, chapel)
pointLight(altar, Color3.fromRGB(130, 45, 22), 0.35, 17)
addSign(chapel, "THE HOLLOW", chapelCenter + Vector3.new(-22, 0, -25), 18)

--------------------------------------------------------------------- ranger cabin
local cabin = Instance.new("Model")
cabin.Name = "RangerCabin"
cabin.Parent = map
local cabinCenter = Vector3.new(98, 0, 72)
part({ Name = "Floor", Size = Vector3.new(28, 1, 22), Position = cabinCenter + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(46, 30, 20), Material = Enum.Material.WoodPlanks }, cabin)
part({ Name = "BackWall", Size = Vector3.new(28, 11, 1), Position = cabinCenter + Vector3.new(0, 6, 10.5), Color = Color3.fromRGB(42, 27, 18), Material = Enum.Material.WoodPlanks }, cabin)
part({ Name = "LeftWall", Size = Vector3.new(1, 11, 22), Position = cabinCenter + Vector3.new(-13.5, 6, 0), Color = Color3.fromRGB(42, 27, 18), Material = Enum.Material.WoodPlanks }, cabin)
part({ Name = "RightWall", Size = Vector3.new(1, 11, 22), Position = cabinCenter + Vector3.new(13.5, 6, 0), Color = Color3.fromRGB(42, 27, 18), Material = Enum.Material.WoodPlanks }, cabin)
part({ Name = "FrontLeft", Size = Vector3.new(10, 11, 1), Position = cabinCenter + Vector3.new(-9, 6, -10.5), Color = Color3.fromRGB(42, 27, 18), Material = Enum.Material.WoodPlanks }, cabin)
part({ Name = "FrontRight", Size = Vector3.new(10, 11, 1), Position = cabinCenter + Vector3.new(9, 6, -10.5), Color = Color3.fromRGB(42, 27, 18), Material = Enum.Material.WoodPlanks }, cabin)
part({ Name = "Roof", Size = Vector3.new(31, 1.2, 25), Position = cabinCenter + Vector3.new(0, 12, 0), Color = Color3.fromRGB(22, 20, 18), Material = Enum.Material.Slate }, cabin)
local cabinLamp = part({ Name = "DeadLamp", Size = Vector3.new(0.6, 0.6, 0.6), Position = cabinCenter + Vector3.new(0, 9, -8), Color = Color3.fromRGB(168, 92, 36), Material = Enum.Material.Neon }, cabin)
pointLight(cabinLamp, Color3.fromRGB(190, 110, 53), 0.45, 16)
addSign(cabin, "RANGER CABIN", cabinCenter + Vector3.new(-17, 0, -16), 10)

--------------------------------------------------------------------- sawmill
local sawmill = Instance.new("Model")
sawmill.Name = "OldSawmill"
sawmill.Parent = map
local sawCenter = Vector3.new(-104, 0, 65)
part({ Name = "MillFloor", Size = Vector3.new(38, 1, 28), Position = sawCenter + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(41, 29, 20), Material = Enum.Material.WoodPlanks }, sawmill)
for x = -17, 17, 34 do
	for z = -12, 12, 24 do
		part({ Name = "MillPost", Size = Vector3.new(1.2, 13, 1.2), Position = sawCenter + Vector3.new(x, 7, z), Color = Color3.fromRGB(41, 27, 18), Material = Enum.Material.Wood }, sawmill)
	end
end
part({ Name = "MillRoof", Size = Vector3.new(42, 1, 31), Position = sawCenter + Vector3.new(0, 14, 0), Color = Color3.fromRGB(25, 23, 20), Material = Enum.Material.Metal }, sawmill)
part({ Name = "SawTable", Size = Vector3.new(16, 3, 5), Position = sawCenter + Vector3.new(0, 2, 1), Color = Color3.fromRGB(45, 33, 22), Material = Enum.Material.WoodPlanks }, sawmill)
local blade = part({ Name = "RustSaw", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 6, 6), CFrame = CFrame.new(sawCenter + Vector3.new(0, 5, 1)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(68, 59, 51), Material = Enum.Material.CorrodedMetal }, sawmill)
blade.CanCollide = false
for stack = 1, 6 do
	local z = -8 + (stack % 3) * 3.1
	cylinderBetween("CutLog", sawCenter + Vector3.new(-14, 1 + math.floor((stack - 1) / 3) * 2, z), sawCenter + Vector3.new(-5, 1 + math.floor((stack - 1) / 3) * 2, z), 1.7, Color3.fromRGB(52, 34, 21), sawmill)
end
addSign(sawmill, "OLD SAWMILL", sawCenter + Vector3.new(22, 0, -18), -15)

--------------------------------------------------------------------- graveyard
local graveyard = Instance.new("Model")
graveyard.Name = "SunkenGraveyard"
graveyard.Parent = map
local graveCenter = Vector3.new(-78, 0, -86)
for row = 0, 3 do
	for column = 0, 4 do
		local x = graveCenter.X - 15 + column * 7.5 + rng:NextNumber(-0.8, 0.8)
		local z = graveCenter.Z - 10 + row * 8 + rng:NextNumber(-0.7, 0.7)
		part({ Name = "Headstone", Size = Vector3.new(2.6, rng:NextNumber(3.2, 5.0), 0.75), CFrame = CFrame.new(x, 2.1, z) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.10, 0.10)), Color = Color3.fromRGB(53, 57, 52), Material = Enum.Material.Slate }, graveyard)
	end
end
for x = -22, 22, 7.3 do
	part({ Name = "FencePost", Size = Vector3.new(0.45, 4, 0.45), Position = graveCenter + Vector3.new(x, 2, -16), Color = Color3.fromRGB(38, 36, 31), Material = Enum.Material.Metal }, graveyard)
	part({ Name = "FencePost", Size = Vector3.new(0.45, 4, 0.45), Position = graveCenter + Vector3.new(x, 2, 18), Color = Color3.fromRGB(38, 36, 31), Material = Enum.Material.Metal }, graveyard)
end
local crypt = part({ Name = "Crypt", Size = Vector3.new(11, 7, 8), Position = graveCenter + Vector3.new(-18, 3.5, 10), Color = Color3.fromRGB(43, 46, 43), Material = Enum.Material.Cobblestone }, graveyard)
pointLight(crypt, Color3.fromRGB(73, 107, 87), 0.18, 12)
addSign(graveyard, "SUNKEN GRAVES", graveCenter + Vector3.new(22, 0, -19), 12)

--------------------------------------------------------------------- survivor camp and spawn
local camp = Instance.new("Model")
camp.Name = "AbandonedCamp"
camp.Parent = map
local campCenter = Vector3.new(66, 0, -68)
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "Spawn"
spawnPad.Anchored = true
spawnPad.Size = Vector3.new(9, 1, 9)
spawnPad.Position = campCenter + Vector3.new(0, 0.5, 0)
spawnPad.Transparency = 1
spawnPad.CastShadow = false
spawnPad.CanQuery = false
spawnPad.Duration = 0
spawnPad.Parent = map
for side = -1, 1, 2 do
	local tent = part({ Name = "CollapsedTent", Size = Vector3.new(8, 0.4, 7), CFrame = CFrame.new(campCenter + Vector3.new(side * 10, 2.2, 4)) * CFrame.Angles(math.rad(25), 0, math.rad(side * 8)), Color = Color3.fromRGB(46, 48, 39), Material = Enum.Material.Fabric }, camp)
	tent.CanCollide = false
end
local fire = part({ Name = "ColdCampfire", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 0.7, 2.2), Position = campCenter + Vector3.new(0, 0.55, -6), Color = Color3.fromRGB(116, 45, 20), Material = Enum.Material.Neon }, camp)
pointLight(fire, Color3.fromRGB(190, 78, 35), 0.65, 17)
addSign(camp, "ABANDONED CAMP", campCenter + Vector3.new(18, 0, -14), -18)

--------------------------------------------------------------------- objective mechanisms
local function makeMechanism(id: string, displayName: string, position: Vector3, parent: Instance)
	local station = Instance.new("Model")
	station.Name = "GateMechanism_" .. id
	station:SetAttribute("MechanismId", id)
	station:SetAttribute("DisplayName", displayName)
	station:SetAttribute("Activated", false)
	station.Parent = parent
	local base = part({ Name = "Base", Size = Vector3.new(5.6, 3.4, 3.5), Position = position + Vector3.new(0, 1.7, 0), Color = Color3.fromRGB(36, 39, 38), Material = Enum.Material.CorrodedMetal }, station)
	station.PrimaryPart = base
	part({ Name = "CoilLeft", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 2.0, 2.0), CFrame = CFrame.new(position + Vector3.new(-2.1, 3.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 48, 37), Material = Enum.Material.Metal }, station)
	part({ Name = "CoilRight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 2.0, 2.0), CFrame = CFrame.new(position + Vector3.new(2.1, 3.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 48, 37), Material = Enum.Material.Metal }, station)
	local core = part({ Name = "Core", Size = Vector3.new(2.0, 1.2, 0.45), Position = position + Vector3.new(0, 3.8, -1.78), Color = Color3.fromRGB(145, 38, 24), Material = Enum.Material.Neon, CanCollide = false }, station)
	pointLight(core, Color3.fromRGB(154, 39, 24), 0.35, 8)
	local lever = cylinderBetween("Lever", position + Vector3.new(0, 3.2, -2.1), position + Vector3.new(1.0, 5.0, -2.1), 0.3, Color3.fromRGB(75, 67, 55), station)
	lever.Material = Enum.Material.Metal
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RestorePrompt"
	prompt.ActionText = "Restore mechanism"
	prompt.ObjectText = displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 3.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	CollectionService:AddTag(station, "GateMechanism")
end

makeMechanism("CABIN", "Ranger relay", cabinCenter + Vector3.new(0, 0, 3), cabin)
makeMechanism("MILL", "Sawmill dynamo", sawCenter + Vector3.new(10, 0, -5), sawmill)
makeMechanism("GRAVES", "Graveyard ward", graveCenter + Vector3.new(13, 0, 12), graveyard)

--------------------------------------------------------------------- escape gate
local gate = Instance.new("Model")
gate.Name = "ForestEscapeGate"
gate.Parent = map
local gateCenter = Vector3.new(0, 0, -166)
for side = -1, 1, 2 do
	part({ Name = "GatePillar", Size = Vector3.new(5, 17, 6), Position = gateCenter + Vector3.new(side * 13, 8.5, 0), Color = Color3.fromRGB(44, 46, 43), Material = Enum.Material.Cobblestone }, gate)
end
part({ Name = "GateArch", Size = Vector3.new(31, 4, 5.5), Position = gateCenter + Vector3.new(0, 16, 0), Color = Color3.fromRGB(39, 41, 38), Material = Enum.Material.Cobblestone }, gate)
local leftDoor = part({ Name = "LeftGateDoor", Size = Vector3.new(10.5, 13, 1.4), Position = gateCenter + Vector3.new(-5.25, 6.5, 0), Color = Color3.fromRGB(45, 39, 32), Material = Enum.Material.Metal }, gate)
local rightDoor = part({ Name = "RightGateDoor", Size = Vector3.new(10.5, 13, 1.4), Position = gateCenter + Vector3.new(5.25, 6.5, 0), Color = Color3.fromRGB(45, 39, 32), Material = Enum.Material.Metal }, gate)
CollectionService:AddTag(leftDoor, "EscapeGateDoor")
CollectionService:AddTag(rightDoor, "EscapeGateDoor")
local crank = part({ Name = "GateCrank", Size = Vector3.new(3.5, 4.5, 2), Position = gateCenter + Vector3.new(18, 2.25, 5), Color = Color3.fromRGB(48, 44, 38), Material = Enum.Material.CorrodedMetal }, gate)
local crankPrompt = Instance.new("ProximityPrompt")
crankPrompt.Name = "GatePrompt"
crankPrompt.ActionText = "Gate locked (0/3)"
crankPrompt.ObjectText = "Forest escape gate"
crankPrompt.KeyboardKeyCode = Enum.KeyCode.E
crankPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
crankPrompt.HoldDuration = 0.35
crankPrompt.MaxActivationDistance = 11
crankPrompt.RequiresLineOfSight = false
crankPrompt.Parent = crank
CollectionService:AddTag(crank, "GateCrank")
local escapeZone = part({ Name = "EscapeZone", Size = Vector3.new(25, 10, 8), Position = gateCenter + Vector3.new(0, 5, -10), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false }, gate)
CollectionService:AddTag(escapeZone, "EscapeZone")
addSign(gate, "FOREST ROAD", gateCenter + Vector3.new(-22, 0, 9), 0)

--------------------------------------------------------------------- patrol network and throwable rocks
local patrolPositions = {
	Vector3.new(66, 2, -68), Vector3.new(42, 2, -35), Vector3.new(5, 2, 20),
	Vector3.new(47, 2, 43), Vector3.new(98, 2, 72), Vector3.new(82, 2, 5),
	Vector3.new(70, 2, -78), Vector3.new(40, 2, -118), Vector3.new(0, 2, -158),
	Vector3.new(-38, 2, -125), Vector3.new(-78, 2, -86), Vector3.new(-58, 2, -43),
	Vector3.new(-25, 2, -12), Vector3.new(-58, 2, 4), Vector3.new(-104, 2, 65),
	Vector3.new(-54, 2, 43), Vector3.new(18, 2, 69), Vector3.new(61, 2, 76),
}
for _, position in patrolPositions do
	local node = part({ Name = "PatrolNode", Size = Vector3.new(2, 2, 2), Position = position, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	CollectionService:AddTag(node, "PatrolNode")
end

for index = 1, 11 do
	local anchor = patrolPositions[((index - 1) % #patrolPositions) + 1]
	local size = rng:NextNumber(0.82, 1.08)
	local rock = part({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = anchor + Vector3.new(rng:NextNumber(-5, 5), 1, rng:NextNumber(-5, 5)), Color = Color3.fromRGB(rng:NextInteger(50, 63), rng:NextInteger(48, 58), rng:NextInteger(43, 52)), Material = Enum.Material.Rock, Anchored = false })
	CollectionService:AddTag(rock, "Throwable")
end

print(("MapBuilder: The Hollow ready — %d trees, %d total instances"):format(madeTrees, #map:GetDescendants()))
