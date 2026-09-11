--!strict
-- The Hollow: a rain-soaked abandoned settlement with readable streets,
-- layered silhouettes, and looping routes for survivors and the monster.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local MAP_VERSION = "HollowSettlement_4"
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
	for key, value in props do (object :: any)[key] = value end
	object.Parent = parent or map
	return object
end

local function model(name: string): Model
	local object = Instance.new("Model")
	object.Name = name
	object.Parent = map
	return object
end

local function cylinderBetween(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material, parent: Instance): Part
	local delta = b - a
	return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(delta.Magnitude, thickness, thickness), CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(-90), 0), Color = color, Material = material }, parent)
end

local function pointLight(parent: Instance, color: Color3, brightness: number, range: number, shadows: boolean?)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, range, shadows == true
	light.Parent = parent
	return light
end

local function surfaceText(parent: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 46
	gui.LightInfluence = 0.35
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(3, 4, 5)
	label.TextStrokeTransparency = 0.18
	label.Parent = gui
end

--------------------------------------------------------------------- cinematic overcast
pcall(function() (Lighting :: any).Technology = Enum.Technology.Future end)
Lighting.ClockTime = 4.65
Lighting.Brightness = 2.05
Lighting.Ambient = Color3.fromRGB(48, 54, 58)
Lighting.OutdoorAmbient = Color3.fromRGB(60, 68, 72)
Lighting.EnvironmentDiffuseScale = 0.38
Lighting.EnvironmentSpecularScale = 0.82
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.62
Lighting.ExposureCompensation = 0.12
Lighting.FogColor = Color3.fromRGB(91, 99, 103)
Lighting.FogStart = 24
Lighting.FogEnd = 158

for _, effect in Lighting:GetChildren() do
	if effect.Name == "TheHollowGrade" or effect.Name == "TheHollowAtmosphere" or effect.Name == "TheHollowBloom" or effect.Name == "TheHollowDepth" then
		effect:Destroy()
	elseif effect:IsA("SunRaysEffect") then
		effect.Enabled = false
	elseif effect:IsA("Atmosphere") then
		effect.Density = 0
	end
end

local grade = Instance.new("ColorCorrectionEffect")
grade.Name, grade.Brightness, grade.Contrast, grade.Saturation = "TheHollowGrade", 0.025, 0.16, -0.58
grade.TintColor = Color3.fromRGB(204, 214, 216)
grade.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "TheHollowAtmosphere"
atmosphere.Color, atmosphere.Decay = Color3.fromRGB(134, 142, 145), Color3.fromRGB(53, 61, 65)
-- Keep the distance grade restrained; visible low fog is supplied by the
-- survivor-only rolling fog banks instead of flattening the whole world grey.
atmosphere.Density, atmosphere.Haze, atmosphere.Glare, atmosphere.Offset = 0.22, 1.35, 0, -0.16
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name, bloom.Intensity, bloom.Size, bloom.Threshold = "TheHollowBloom", 0.19, 34, 0.94
bloom.Parent = Lighting

local depth = Instance.new("DepthOfFieldEffect")
depth.Name, depth.FarIntensity, depth.FocusDistance, depth.InFocusRadius, depth.NearIntensity = "TheHollowDepth", 0.065, 70, 55, 0.015
depth.Parent = Lighting

local terrain = Workspace:FindFirstChildOfClass("Terrain")
if terrain then
	local oldClouds = terrain:FindFirstChild("TheHollowClouds")
	if oldClouds then oldClouds:Destroy() end
	local clouds = Instance.new("Clouds")
	clouds.Name, clouds.Cover, clouds.Density = "TheHollowClouds", 0.92, 0.72
	clouds.Color = Color3.fromRGB(69, 74, 77)
	clouds.Parent = terrain
end

--------------------------------------------------------------------- wet streets
part({ Name = "TownGround", Size = Vector3.new(760, 2, 760), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(23, 27, 25), Material = Enum.Material.Ground })
local roadColor = Color3.fromRGB(28, 32, 34)
part({ Name = "MainStreet", Size = Vector3.new(34, 0.35, 740), Position = Vector3.new(0, 0.08, 0), Color = roadColor, Material = Enum.Material.Asphalt, Reflectance = 0.08 })
part({ Name = "CrossStreet", Size = Vector3.new(740, 0.35, 34), Position = Vector3.new(0, 0.09, 25), Color = roadColor, Material = Enum.Material.Asphalt, Reflectance = 0.08 })
part({ Name = "SouthStreet", Size = Vector3.new(600, 0.35, 30), Position = Vector3.new(0, 0.1, -145), Color = roadColor, Material = Enum.Material.Asphalt, Reflectance = 0.08 })
part({ Name = "NorthStreet", Size = Vector3.new(600, 0.35, 30), Position = Vector3.new(0, 0.1, 195), Color = roadColor, Material = Enum.Material.Asphalt, Reflectance = 0.08 })
part({ Name = "WestAvenue", Size = Vector3.new(30, 0.35, 500), Position = Vector3.new(-170, 0.1, 25), Color = roadColor, Material = Enum.Material.Asphalt, Reflectance = 0.08 })
part({ Name = "EastAvenue", Size = Vector3.new(30, 0.35, 500), Position = Vector3.new(170, 0.1, 25), Color = roadColor, Material = Enum.Material.Asphalt, Reflectance = 0.08 })

local concrete = Color3.fromRGB(74, 77, 75)
for _, x in { -22, 22 } do
	part({ Name = "MainSidewalk", Size = Vector3.new(9, 0.55, 740), Position = Vector3.new(x, 0.27, 0), Color = concrete, Material = Enum.Material.Concrete })
	part({ Name = "MainCurb", Size = Vector3.new(0.65, 0.75, 740), Position = Vector3.new(if x < 0 then -17.3 else 17.3, 0.38, 0), Color = Color3.fromRGB(91, 93, 89), Material = Enum.Material.Concrete })
end
for _, z in { 3, 47 } do
	part({ Name = "CrossSidewalk", Size = Vector3.new(740, 0.55, 9), Position = Vector3.new(0, 0.28, z), Color = concrete, Material = Enum.Material.Concrete })
	part({ Name = "CrossCurb", Size = Vector3.new(740, 0.75, 0.65), Position = Vector3.new(0, 0.39, if z < 25 then 7.7 else 42.3), Color = Color3.fromRGB(91, 93, 89), Material = Enum.Material.Concrete })
end
for _, roadZ in { -145, 195 } do
	for _, sideZ in { roadZ - 20, roadZ + 20 } do
		part({ Name = "DistrictSidewalk", Size = Vector3.new(600, 0.55, 9), Position = Vector3.new(0, 0.28, sideZ), Color = concrete, Material = Enum.Material.Concrete })
	end
end
for _, roadX in { -170, 170 } do
	for _, sideX in { roadX - 20, roadX + 20 } do
		part({ Name = "AvenueSidewalk", Size = Vector3.new(9, 0.55, 500), Position = Vector3.new(sideX, 0.28, 25), Color = concrete, Material = Enum.Material.Concrete })
	end
end
for z = -330, 330, 18 do
	part({ Name = "FadedCenterLine", Size = Vector3.new(0.28, 0.025, 8), Position = Vector3.new(0, 0.3, z), Color = Color3.fromRGB(143, 139, 120), Material = Enum.Material.SmoothPlastic, Transparency = 0.32, CanCollide = false, CastShadow = false })
end
for x = -330, 330, 22 do
	part({ Name = "FadedCrossLine", Size = Vector3.new(10, 0.025, 0.25), Position = Vector3.new(x, 0.31, 25), Color = Color3.fromRGB(143, 139, 120), Material = Enum.Material.SmoothPlastic, Transparency = 0.4, CanCollide = false, CastShadow = false })
end
for _, districtZ in { -145, 195 } do
	for x = -270, 270, 22 do
		part({ Name = "DistrictCenterLine", Size = Vector3.new(10, 0.025, 0.25), Position = Vector3.new(x, 0.31, districtZ), Color = Color3.fromRGB(143, 139, 120), Material = Enum.Material.SmoothPlastic, Transparency = 0.42, CanCollide = false, CastShadow = false })
	end
end
for _, avenueX in { -170, 170 } do
	for z = -205, 255, 20 do
		part({ Name = "AvenueCenterLine", Size = Vector3.new(0.25, 0.025, 9), Position = Vector3.new(avenueX, 0.31, z), Color = Color3.fromRGB(143, 139, 120), Material = Enum.Material.SmoothPlastic, Transparency = 0.42, CanCollide = false, CastShadow = false })
	end
end
for stripe = -4, 4 do
	part({ Name = "Crosswalk", Size = Vector3.new(2.2, 0.03, 10), Position = Vector3.new(stripe * 3.6, 0.32, -1), Color = Color3.fromRGB(166, 169, 166), Material = Enum.Material.SmoothPlastic, Transparency = 0.25, CanCollide = false, CastShadow = false })
end
for _, data in {
	{ Vector3.new(-7, 0.34, 134), Vector3.new(7, 0.035, 15), 0.42 }, { Vector3.new(8, 0.34, 82), Vector3.new(6, 0.035, 20), 0.36 },
	{ Vector3.new(-5, 0.34, 10), Vector3.new(9, 0.035, 12), 0.45 }, { Vector3.new(6, 0.34, -66), Vector3.new(8, 0.035, 19), 0.4 },
	{ Vector3.new(-7, 0.34, -139), Vector3.new(6, 0.035, 13), 0.38 }, { Vector3.new(79, 0.35, 24), Vector3.new(17, 0.035, 7), 0.45 },
	{ Vector3.new(-86, 0.35, 28), Vector3.new(21, 0.035, 6), 0.43 },
} do
	part({ Name = "RoadSheen", Size = data[2], Position = data[1], Color = Color3.fromRGB(90, 105, 110), Material = Enum.Material.Glass, Transparency = data[3], Reflectance = 0.32, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
end
local wetAnchors = {
	Vector3.new(0, 0.34, 300), Vector3.new(0, 0.34, 245), Vector3.new(-120, 0.34, 195), Vector3.new(132, 0.34, 195),
	Vector3.new(-170, 0.34, 145), Vector3.new(170, 0.34, 80), Vector3.new(-255, 0.34, 25), Vector3.new(245, 0.34, 25),
	Vector3.new(-170, 0.34, -72), Vector3.new(170, 0.34, -55), Vector3.new(-126, 0.34, -145), Vector3.new(118, 0.34, -145),
	Vector3.new(0, 0.34, -205), Vector3.new(0, 0.34, -285),
}
for _, anchor in wetAnchors do
	part({ Name = "RoadPuddle", Size = Vector3.new(rng:NextNumber(5, 13), 0.028, rng:NextNumber(4, 10)), Position = anchor + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), Color = Color3.fromRGB(76, 91, 96), Material = Enum.Material.Glass, Transparency = rng:NextNumber(0.42, 0.58), Reflectance = 0.36, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
end
for _, wall in {
	{ Vector3.new(-380, 18, 0), Vector3.new(2, 36, 760) }, { Vector3.new(380, 18, 0), Vector3.new(2, 36, 760) },
	{ Vector3.new(0, 18, -380), Vector3.new(760, 36, 2) }, { Vector3.new(0, 18, 380), Vector3.new(760, 36, 2) },
} do
	part({ Name = "TownBoundary", Position = wall[1], Size = wall[2], Transparency = 1, CanQuery = false, CastShadow = false })
end

--------------------------------------------------------------------- architecture
type Facing = "North" | "South" | "East" | "West"
local function makeBuilding(name: string, center: Vector3, footprint: Vector2, floors: number, facing: Facing, wallColor: Color3, signText: string?): Model
	local building = model(name)
	local height = floors * 9 + 3
	part({ Name = "Foundation", Size = Vector3.new(footprint.X + 2, 1.2, footprint.Y + 2), Position = center + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(45, 47, 45), Material = Enum.Material.Concrete }, building)
	part({ Name = "BuildingShell", Size = Vector3.new(footprint.X, height, footprint.Y), Position = center + Vector3.new(0, height / 2 + 1.2, 0), Color = wallColor, Material = Enum.Material.Brick }, building)
	part({ Name = "Roof", Size = Vector3.new(footprint.X + 3, 1, footprint.Y + 3), Position = center + Vector3.new(0, height + 1.7, 0), Color = Color3.fromRGB(30, 32, 32), Material = Enum.Material.Slate }, building)
	for _, zSide in { -1, 1 } do
		part({ Name = "RoofParapet", Size = Vector3.new(footprint.X + 3, 2.2, 0.8), Position = center + Vector3.new(0, height + 2.6, zSide * (footprint.Y / 2 + 1.1)), Color = wallColor, Material = Enum.Material.Brick }, building)
	end
	local axisX = facing == "North" or facing == "South"
	local outward = if facing == "North" then Vector3.new(0, 0, -1) elseif facing == "South" then Vector3.new(0, 0, 1) elseif facing == "East" then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
	local frontage = if axisX then footprint.X else footprint.Y
	local columns = math.max(2, math.floor(frontage / 9))
	for floor = 1, floors do
		for column = 1, columns do
			local across = -frontage / 2 + column * (frontage / (columns + 1))
			local y = 5.5 + (floor - 1) * 9
			local position = center + outward * ((if axisX then footprint.Y else footprint.X) / 2 + 0.08)
			position += if axisX then Vector3.new(across, y, 0) else Vector3.new(0, y, across)
			local lit = ((floor * 5 + column * 3 + math.floor(math.abs(center.X))) % 7 == 0)
			local window = part({ Name = "Window", Size = if axisX then Vector3.new(4.4, 5, 0.18) else Vector3.new(0.18, 5, 4.4), Position = position, Color = if lit then Color3.fromRGB(181, 164, 118) else Color3.fromRGB(38, 48, 51), Material = if lit then Enum.Material.Neon else Enum.Material.Glass, Transparency = if lit then 0.27 else 0.2, Reflectance = 0.18, CanCollide = false }, building)
			part({ Name = "WindowLintel", Size = if axisX then Vector3.new(5.1, 0.35, 0.42) else Vector3.new(0.42, 0.35, 5.1), Position = position + Vector3.new(0, 2.7, 0) + outward * 0.05, Color = Color3.fromRGB(92, 93, 88), Material = Enum.Material.Concrete, CanCollide = false }, building)
			part({ Name = "WindowSill", Size = if axisX then Vector3.new(5.1, 0.28, 0.5) else Vector3.new(0.5, 0.28, 5.1), Position = position - Vector3.new(0, 2.65, 0) + outward * 0.08, Color = Color3.fromRGB(82, 85, 82), Material = Enum.Material.Concrete, CanCollide = false }, building)
			part({ Name = "WindowMullionV", Size = if axisX then Vector3.new(0.16, 4.85, 0.3) else Vector3.new(0.3, 4.85, 0.16), Position = position + outward * 0.13, Color = Color3.fromRGB(30, 35, 36), Material = Enum.Material.Metal, CanCollide = false }, building)
			part({ Name = "WindowMullionH", Size = if axisX then Vector3.new(4.35, 0.16, 0.3) else Vector3.new(0.3, 0.16, 4.35), Position = position + outward * 0.13, Color = Color3.fromRGB(30, 35, 36), Material = Enum.Material.Metal, CanCollide = false }, building)
			if lit and floor == 1 then pointLight(window, Color3.fromRGB(214, 190, 140), 0.22, 11, false) end
		end
	end
	local facadeDistance = (if axisX then footprint.Y else footprint.X) / 2
	local doorPosition = center + outward * (facadeDistance + 0.14) + Vector3.new(0, 4.2, 0)
	part({ Name = "LockedDoor", Size = if axisX then Vector3.new(5, 7.4, 0.32) else Vector3.new(0.32, 7.4, 5), Position = doorPosition, Color = Color3.fromRGB(33, 36, 36), Material = Enum.Material.Metal }, building)
	local awningPosition = center + outward * (facadeDistance + 2.4) + Vector3.new(0, 7.7, 0)
	local awningWidth = math.min(18, frontage - 3)
	part({ Name = "RainAwning", Size = if axisX then Vector3.new(awningWidth, 0.3, 4.8) else Vector3.new(4.8, 0.3, awningWidth), Position = awningPosition, Color = Color3.fromRGB(42, 51, 53), Material = Enum.Material.Metal }, building)
	if signText then
		for stripe = 1, 9 do
			local across = -awningWidth / 2 + (stripe - 0.5) * (awningWidth / 9)
			local stripePosition = awningPosition + (if axisX then Vector3.new(across, 0.18, 0) else Vector3.new(0, 0.18, across))
			part({ Name = "AwningStripe", Size = if axisX then Vector3.new(awningWidth / 9 - 0.05, 0.08, 4.45) else Vector3.new(4.45, 0.08, awningWidth / 9 - 0.05), Position = stripePosition, Color = if stripe % 2 == 0 then Color3.fromRGB(119, 108, 69) else Color3.fromRGB(57, 66, 67), Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false }, building)
		end
	end
	if signText then
		local signPosition = center + outward * (facadeDistance + 0.26) + Vector3.new(0, 10.2, 0)
		local sign = part({ Name = "StoreSign", Size = if axisX then Vector3.new(math.min(20, frontage - 4), 3.2, 0.35) else Vector3.new(0.35, 3.2, math.min(20, frontage - 4)), Position = signPosition, Color = Color3.fromRGB(28, 34, 35), Material = Enum.Material.Metal }, building)
		local signFace = if facing == "North" then Enum.NormalId.Front
			elseif facing == "South" then Enum.NormalId.Back
			elseif facing == "East" then Enum.NormalId.Right
			else Enum.NormalId.Left
		surfaceText(sign, signText, Color3.fromRGB(192, 199, 194), signFace)
	end
	local pipeX = center.X + (if axisX then footprint.X / 2 - 2 else outward.X * (footprint.X / 2 + 0.35))
	local pipeZ = center.Z + (if axisX then outward.Z * (footprint.Y / 2 + 0.35) else footprint.Y / 2 - 2)
	part({ Name = "DrainPipe", Size = Vector3.new(0.45, height, 0.45), Position = Vector3.new(pipeX, height / 2 + 1.2, pipeZ), Color = Color3.fromRGB(50, 54, 54), Material = Enum.Material.CorrodedMetal }, building)
	part({ Name = "RoofVent", Size = Vector3.new(3.4, 2.4, 3.4), Position = center + Vector3.new(footprint.X * 0.23, height + 2.6, -footprint.Y * 0.16), Color = Color3.fromRGB(46, 49, 49), Material = Enum.Material.CorrodedMetal }, building)
	return building
end

local clinic = makeBuilding("MorrowClinic", Vector3.new(60, 0, -72), Vector2.new(50, 45), 3, "West", Color3.fromRGB(69, 75, 73), "MORROW CLINIC")
local market = makeBuilding("HollowMarket", Vector3.new(-61, 0, 71), Vector2.new(52, 42), 2, "East", Color3.fromRGB(77, 72, 65), "HOLLOW MARKET")
local laundry = makeBuilding("Laundry", Vector3.new(58, 0, 116), Vector2.new(47, 39), 2, "West", Color3.fromRGB(64, 71, 72), "24 HOUR LAUNDRY")
makeBuilding("AshdownApartments", Vector3.new(-67, 0, -65), Vector2.new(58, 50), 4, "East", Color3.fromRGB(63, 61, 58), "ASHDOWN")
makeBuilding("TownHall", Vector3.new(72, 0, 67), Vector2.new(62, 42), 3, "South", Color3.fromRGB(72, 74, 70), "MUNICIPAL HALL")
makeBuilding("ClosedPharmacy", Vector3.new(-116, 0, 67), Vector2.new(42, 40), 2, "South", Color3.fromRGB(63, 72, 68), "PHARMACY")
makeBuilding("BoardedHotel", Vector3.new(106, 0, -150), Vector2.new(62, 48), 4, "North", Color3.fromRGB(66, 62, 59), "THE HOLLOW HOTEL")
makeBuilding("OldSchool", Vector3.new(-106, 0, -151), Vector2.new(68, 46), 3, "North", Color3.fromRGB(71, 65, 60), "HOLLOW SCHOOL")
local northPower = makeBuilding("NorthPowerStation", Vector3.new(74, 0, 275), Vector2.new(70, 54), 3, "North", Color3.fromRGB(61, 67, 66), "NORTH POWER")
local southWorks = makeBuilding("SouthWaterWorks", Vector3.new(78, 0, -270), Vector2.new(72, 58), 3, "South", Color3.fromRGB(65, 66, 62), "WATER WORKS")
local westRelay = makeBuilding("WestTelephoneExchange", Vector3.new(-267, 0, 91), Vector2.new(62, 56), 3, "East", Color3.fromRGB(64, 69, 68), "TELEPHONE EXCHANGE")
local grocery = makeBuilding("NorthGrocery", Vector3.new(-75, 0, 275), Vector2.new(67, 52), 2, "North", Color3.fromRGB(77, 72, 64), "HOLLOW FOODS")
makeBuilding("StarlightCinema", Vector3.new(-270, 0, -34), Vector2.new(62, 58), 3, "East", Color3.fromRGB(66, 61, 59), "STARLIGHT CINEMA")
makeBuilding("EastFireStation", Vector3.new(266, 0, 99), Vector2.new(65, 60), 2, "West", Color3.fromRGB(76, 66, 61), "FIRE STATION 04")
makeBuilding("NorthWestResidences", Vector3.new(-270, 0, 273), Vector2.new(70, 64), 4, "East", Color3.fromRGB(65, 62, 58), "WESTGATE HOMES")
makeBuilding("NorthEastResidences", Vector3.new(267, 0, 276), Vector2.new(68, 62), 4, "West", Color3.fromRGB(62, 66, 64), "NORTH COURT")
makeBuilding("WestFoundry", Vector3.new(-270, 0, -265), Vector2.new(76, 66), 3, "East", Color3.fromRGB(61, 58, 55), "FOUNDRY")
makeBuilding("EastBusDepot", Vector3.new(266, 0, -262), Vector2.new(74, 64), 2, "West", Color3.fromRGB(66, 68, 65), "BUS DEPOT")
makeBuilding("SaintMorrowChurch", Vector3.new(-76, 0, -271), Vector2.new(68, 58), 4, "South", Color3.fromRGB(67, 64, 59), "ST. MORROW")

local function addStorefront(parent: Model, center: Vector3, footprint: Vector2, facing: Facing, accent: Color3)
	local axisX = facing == "North" or facing == "South"
	local outward = if facing == "North" then Vector3.new(0, 0, -1) elseif facing == "South" then Vector3.new(0, 0, 1) elseif facing == "East" then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
	local distance = (if axisX then footprint.Y else footprint.X) / 2 + 0.24
	local glassWidth = math.min(26, (if axisX then footprint.X else footprint.Y) - 8)
	for panelIndex = -2, 2 do
		local across = panelIndex * (glassWidth / 5)
		local position = center + outward * distance + Vector3.new(0, 4.25, 0)
		position += if axisX then Vector3.new(across, 0, 0) else Vector3.new(0, 0, across)
		part({ Name = "StorefrontGlass", Size = if axisX then Vector3.new(glassWidth / 5 - 0.22, 6.6, 0.2) else Vector3.new(0.2, 6.6, glassWidth / 5 - 0.22), Position = position, Color = Color3.fromRGB(92, 111, 113), Material = Enum.Material.Glass, Transparency = 0.24, Reflectance = 0.2, CanCollide = false }, parent)
		part({ Name = "StorefrontPost", Size = if axisX then Vector3.new(0.18, 7.1, 0.36) else Vector3.new(0.36, 7.1, 0.18), Position = position + (if axisX then Vector3.new(glassWidth / 10, 0, 0) else Vector3.new(0, 0, glassWidth / 10)), Color = Color3.fromRGB(35, 40, 41), Material = Enum.Material.Metal, CanCollide = false }, parent)
	end
	local interior = part({ Name = "InteriorGlow", Size = if axisX then Vector3.new(glassWidth - 1, 0.16, 2.4) else Vector3.new(2.4, 0.16, glassWidth - 1), Position = center + outward * (distance - 2.1) + Vector3.new(0, 7.1, 0), Color = Color3.fromRGB(187, 181, 145), Material = Enum.Material.Neon, Transparency = 0.18, CanCollide = false }, parent)
	pointLight(interior, Color3.fromRGB(201, 193, 158), 0.34, 18, false)
	for shelf = -1, 1 do
		local shelfPosition = center + outward * (distance - 2.8) + Vector3.new(0, 2.3 + shelf * 1.6, 0)
		part({ Name = "StoreShelf", Size = if axisX then Vector3.new(glassWidth - 3, 0.16, 1.2) else Vector3.new(1.2, 0.16, glassWidth - 3), Position = shelfPosition, Color = Color3.fromRGB(45, 43, 38), Material = Enum.Material.WoodPlanks, CanCollide = false }, parent)
	end
	local posterPosition = center + outward * (distance + 0.12) + Vector3.new(if axisX then glassWidth * 0.32 else 0, 4.5, if axisX then 0 else glassWidth * 0.32)
	local poster = part({ Name = "WindowPoster", Size = if axisX then Vector3.new(3.6, 4.8, 0.08) else Vector3.new(0.08, 4.8, 3.6), Position = posterPosition, Color = accent, Material = Enum.Material.SmoothPlastic, CanCollide = false }, parent)
	local posterFace = if facing == "North" then Enum.NormalId.Front elseif facing == "South" then Enum.NormalId.Back elseif facing == "East" then Enum.NormalId.Right else Enum.NormalId.Left
	surfaceText(poster, "OPEN\nALL NIGHT", Color3.fromRGB(235, 230, 204), posterFace)
end

addStorefront(market, Vector3.new(-61, 0, 71), Vector2.new(52, 42), "East", Color3.fromRGB(98, 113, 103))
addStorefront(grocery, Vector3.new(-75, 0, 275), Vector2.new(67, 52), "North", Color3.fromRGB(142, 116, 62))

-- Exterior layers that make the façades read as occupied structures rather
-- than solid boxes: fire escape, loading clutter, grates, and street fixtures.
local fireEscape = model("AshdownFireEscape")
for level = 1, 3 do
	local y = 7 + (level - 1) * 8.5
	part({ Name = "Platform", Size = Vector3.new(4.8, 0.3, 10), Position = Vector3.new(-36.7, y, -65), Color = Color3.fromRGB(38, 41, 41), Material = Enum.Material.DiamondPlate }, fireEscape)
	for zOffset = -4.6, 4.6, 9.2 do
		part({ Name = "RailPost", Size = Vector3.new(0.22, 2.5, 0.22), Position = Vector3.new(-34.4, y + 1.25, -65 + zOffset), Color = Color3.fromRGB(40, 43, 43), Material = Enum.Material.Metal }, fireEscape)
	end
	part({ Name = "OuterRail", Size = Vector3.new(0.22, 0.22, 10), Position = Vector3.new(-34.4, y + 2.45, -65), Color = Color3.fromRGB(40, 43, 43), Material = Enum.Material.Metal }, fireEscape)
	if level < 3 then
		for rung = 0, 7 do
			part({ Name = "LadderRung", Size = Vector3.new(0.18, 0.18, 2.2), CFrame = CFrame.new(-34.3, y + 0.7 + rung, -61.5) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(44, 46, 46), Material = Enum.Material.Metal }, fireEscape)
		end
	end
end

for _, position in { Vector3.new(-10, 0.36, 61), Vector3.new(10, 0.36, -84), Vector3.new(-72, 0.36, 25), Vector3.new(113, 0.36, 25) } do
	part({ Name = "StormDrain", Size = Vector3.new(3.2, 0.05, 1.3), Position = position, Color = Color3.fromRGB(25, 28, 28), Material = Enum.Material.DiamondPlate, CanCollide = false })
end

for _, position in { Vector3.new(25, 0.55, 58), Vector3.new(-25, 0.55, -26) } do
	local hydrant = model("FireHydrant")
	part({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.3, 1.05, 1.05), CFrame = CFrame.new(position + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(105, 42, 35), Material = Enum.Material.Metal }, hydrant)
	part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.25, 0.7, 1.25), Position = position + Vector3.new(0, 2.25, 0), Color = Color3.fromRGB(91, 37, 32), Material = Enum.Material.Metal }, hydrant)
end

local vending = model("DeadVendingMachine")
local vendingBody = part({ Name = "Cabinet", Size = Vector3.new(4.2, 7.4, 2.2), Position = Vector3.new(-31.5, 4.25, 64), Color = Color3.fromRGB(33, 48, 55), Material = Enum.Material.Metal }, vending)
local vendingFace = part({ Name = "Display", Size = Vector3.new(3.45, 5.6, 0.16), Position = vendingBody.Position + Vector3.new(0, 0.35, -1.16), Color = Color3.fromRGB(48, 70, 77), Material = Enum.Material.Glass, Transparency = 0.15 }, vending)
surfaceText(vendingFace, "COLD DRINKS", Color3.fromRGB(145, 176, 181), Enum.NormalId.Front)

for stack = 1, 12 do
	local position = Vector3.new(34 + (stack % 3) * 2.7, 1.1 + math.floor((stack - 1) / 3) * 2.15, 92 + (stack % 2) * 2.4)
	part({ Name = "RainSoakedCrate", Size = Vector3.new(2.5, 2, 2.3), Position = position, Color = Color3.fromRGB(58, 45, 34), Material = Enum.Material.WoodPlanks }, laundry)
end

--------------------------------------------------------------------- street furniture
local function streetLamp(position: Vector3, side: number)
	local lamp = model("StreetLamp")
	part({ Name = "Post", Size = Vector3.new(0.55, 12.5, 0.55), Position = position + Vector3.new(0, 6.25, 0), Color = Color3.fromRGB(35, 39, 39), Material = Enum.Material.Metal }, lamp)
	part({ Name = "Arm", Size = Vector3.new(4.2, 0.38, 0.38), Position = position + Vector3.new(-side * 1.85, 12.1, 0), Color = Color3.fromRGB(35, 39, 39), Material = Enum.Material.Metal }, lamp)
	local bulb = part({ Name = "LampGlass", Size = Vector3.new(1.2, 0.55, 1.2), Position = position + Vector3.new(-side * 3.7, 11.65, 0), Color = Color3.fromRGB(193, 183, 148), Material = Enum.Material.Neon, Transparency = 0.2 }, lamp)
	pointLight(bulb, Color3.fromRGB(205, 193, 158), 0.75, 26, true)
end
for z = -315, 315, 52 do
	streetLamp(Vector3.new(-27, 0.55, z), -1)
	streetLamp(Vector3.new(27, 0.55, z + 24), 1)
end
for x = -270, 270, 68 do
	streetLamp(Vector3.new(x, 0.55, 170), -1)
	streetLamp(Vector3.new(x + 28, 0.55, -170), 1)
end

local polePositions = { -335, -285, -235, -185, -135, -85, -35, 15, 65, 115, 165, 215, 265, 315, 350 }
local utility = model("UtilityNetwork")
for _, z in polePositions do
	local base = Vector3.new(-31.5, 0.55, z)
	part({ Name = "UtilityPole", Size = Vector3.new(0.75, 18, 0.75), Position = base + Vector3.new(0, 9, 0), Color = Color3.fromRGB(43, 35, 29), Material = Enum.Material.Wood }, utility)
	part({ Name = "CrossArm", Size = Vector3.new(5.5, 0.42, 0.42), Position = base + Vector3.new(0, 16.2, 0), Color = Color3.fromRGB(43, 35, 29), Material = Enum.Material.Wood }, utility)
end
for index = 1, #polePositions - 1 do
	for xOffset = -1.8, 1.8, 1.8 do
		local a, b = Vector3.new(-31.5 + xOffset, 16.6, polePositions[index]), Vector3.new(-31.5 + xOffset, 16.6, polePositions[index + 1])
		local middle = (a + b) / 2 - Vector3.new(0, 1.25, 0)
		local first = cylinderBetween("PowerLine", a, middle, 0.08, Color3.fromRGB(12, 14, 14), Enum.Material.SmoothPlastic, utility)
		local second = cylinderBetween("PowerLine", middle, b, 0.08, Color3.fromRGB(12, 14, 14), Enum.Material.SmoothPlastic, utility)
		first.CanCollide, second.CanCollide = false, false
	end
end

local function abandonedCar(position: Vector3, yaw: number, bodyColor: Color3)
	local car = model("AbandonedCar")
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	part({ Name = "Body", Size = Vector3.new(7.5, 1.7, 13.5), CFrame = cf * CFrame.new(0, 1.5, 0), Color = bodyColor, Material = Enum.Material.Metal }, car)
	part({ Name = "Cabin", Size = Vector3.new(6.8, 2.8, 6.3), CFrame = cf * CFrame.new(0, 3.35, 0.6), Color = Color3.fromRGB(35, 41, 42), Material = Enum.Material.Glass, Transparency = 0.18, Reflectance = 0.2 }, car)
	for _, offset in { Vector3.new(-4, 0.9, -4.3), Vector3.new(4, 0.9, -4.3), Vector3.new(-4, 0.9, 4.3), Vector3.new(4, 0.9, 4.3) } do
		part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.2, 2.2), CFrame = cf * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(18, 19, 19), Material = Enum.Material.Rubber }, car)
	end
end
abandonedCar(Vector3.new(7, 0.3, 91), 5, Color3.fromRGB(63, 70, 69))
abandonedCar(Vector3.new(-7, 0.3, -35), -8, Color3.fromRGB(67, 55, 49))
abandonedCar(Vector3.new(88, 0.3, 30), 88, Color3.fromRGB(51, 61, 65))
abandonedCar(Vector3.new(-122, 0.3, 197), 92, Color3.fromRGB(60, 56, 52))
abandonedCar(Vector3.new(138, 0.3, -145), 88, Color3.fromRGB(48, 58, 60))
abandonedCar(Vector3.new(-171, 0.3, -69), -3, Color3.fromRGB(65, 63, 55))
abandonedCar(Vector3.new(171, 0.3, 136), 4, Color3.fromRGB(51, 56, 61))

for _, position in { Vector3.new(-27, 0.7, 101), Vector3.new(27, 0.7, -93), Vector3.new(-74, 0.7, 0), Vector3.new(117, 0.7, 48) } do
	local bin = part({ Name = "Dumpster", Size = Vector3.new(5, 3.6, 3.4), Position = position + Vector3.new(0, 1.8, 0), Color = Color3.fromRGB(36, 48, 45), Material = Enum.Material.CorrodedMetal })
	part({ Name = "DumpsterLid", Size = Vector3.new(5.3, 0.3, 3.7), Position = bin.Position + Vector3.new(0, 1.95, 0), Color = Color3.fromRGB(30, 38, 37), Material = Enum.Material.Metal })
end

local function townTree(position: Vector3, height: number)
	local tree = model("RainTree")
	cylinderBetween("Trunk", position, position + Vector3.new(0, height, 0), 1.2, Color3.fromRGB(38, 31, 26), Enum.Material.Wood, tree)
	for branch = 1, 5 do
		local angle = branch * 1.43 + position.X * 0.03
		local start = position + Vector3.new(0, height * (0.42 + branch * 0.075), 0)
		local finish = start + Vector3.new(math.cos(angle) * height * 0.25, height * 0.17, math.sin(angle) * height * 0.25)
		local limb = cylinderBetween("Branch", start, finish, 0.48, Color3.fromRGB(38, 31, 26), Enum.Material.Wood, tree)
		limb.CanCollide = false
	end
	for _ = 1, 4 do
		part({ Name = "WetLeaves", Shape = Enum.PartType.Ball, Size = Vector3.new(rng:NextNumber(7, 10), rng:NextNumber(5, 8), rng:NextNumber(7, 10)), Position = position + Vector3.new(rng:NextNumber(-3, 3), height - rng:NextNumber(0, 4), rng:NextNumber(-3, 3)), Color = Color3.fromRGB(17, 30, 26), Material = Enum.Material.LeafyGrass, CanCollide = false }, tree)
	end
end
for _, position in {
	Vector3.new(-42, 0, 155), Vector3.new(44, 0, 153), Vector3.new(-43, 0, 10), Vector3.new(44, 0, -10),
	Vector3.new(-44, 0, -125), Vector3.new(43, 0, -138), Vector3.new(-177, 0, 10), Vector3.new(178, 0, 4),
	Vector3.new(-185, 0, 158), Vector3.new(183, 0, 145), Vector3.new(-180, 0, -170), Vector3.new(177, 0, -177),
} do townTree(position, rng:NextNumber(20, 28)) end
for index = 1, 58 do
	local side = if index % 2 == 0 then -1 else 1
	townTree(Vector3.new(side * rng:NextNumber(310, 365), 0, rng:NextNumber(-365, 365)), rng:NextNumber(18, 27))
end

--------------------------------------------------------------------- gameplay anchors
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name, spawnPad.Anchored, spawnPad.Size, spawnPad.Position = "Spawn", true, Vector3.new(9, 1, 9), Vector3.new(0, 0.8, 340)
spawnPad.Transparency, spawnPad.CastShadow, spawnPad.CanQuery, spawnPad.Duration = 1, false, false, 0
spawnPad.Parent = map

local function makeMechanism(id: string, displayName: string, position: Vector3, parent: Instance)
	local station = Instance.new("Model")
	station.Name = "GateMechanism_" .. id
	station:SetAttribute("MechanismId", id)
	station:SetAttribute("DisplayName", displayName)
	station:SetAttribute("Activated", false)
	station.Parent = parent
	local base = part({ Name = "Base", Size = Vector3.new(5.8, 4.2, 3.8), Position = position + Vector3.new(0, 2.1, 0), Color = Color3.fromRGB(42, 46, 45), Material = Enum.Material.CorrodedMetal }, station)
	station.PrimaryPart = base
	part({ Name = "Panel", Size = Vector3.new(4.6, 2.8, 0.3), Position = position + Vector3.new(0, 2.4, -2.02), Color = Color3.fromRGB(24, 28, 28), Material = Enum.Material.Metal }, station)
	for offset = -1.45, 1.45, 0.72 do
		part({ Name = "Fuse", Size = Vector3.new(0.32, 1.1, 0.35), Position = position + Vector3.new(offset, 2.7, -2.24), Color = Color3.fromRGB(84, 76, 62), Material = Enum.Material.Metal, CanCollide = false }, station)
	end
	local core = part({ Name = "Core", Size = Vector3.new(1.35, 0.65, 0.22), Position = position + Vector3.new(0, 3.65, -2.22), Color = Color3.fromRGB(131, 45, 35), Material = Enum.Material.Neon, CanCollide = false }, station)
	pointLight(core, core.Color, 0.38, 9, false)
	local lever = cylinderBetween("Lever", position + Vector3.new(1.8, 2.5, -2.3), position + Vector3.new(2.5, 4.5, -2.3), 0.28, Color3.fromRGB(86, 80, 67), Enum.Material.Metal, station)
	lever.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "RestorePrompt", "Restore mechanism", displayName
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 3.2, 10, false
	prompt.Parent = base
	CollectionService:AddTag(station, "GateMechanism")
end
makeMechanism("NORTH", "North power substation", Vector3.new(74, 0.55, 240), northPower)
makeMechanism("SOUTH", "Water works generator", Vector3.new(78, 0.55, -232), southWorks)
makeMechanism("WEST", "Telephone exchange relay", Vector3.new(-230, 0.55, 91), westRelay)

local gate = model("TownEscapeGate")
local gateCenter = Vector3.new(0, 0, -352)
for side = -1, 1, 2 do
	part({ Name = "GatePillar", Size = Vector3.new(5.5, 18, 6), Position = gateCenter + Vector3.new(side * 14, 9, 0), Color = Color3.fromRGB(55, 59, 57), Material = Enum.Material.Brick }, gate)
end
part({ Name = "GateArch", Size = Vector3.new(33, 4, 5.5), Position = gateCenter + Vector3.new(0, 17, 0), Color = Color3.fromRGB(49, 53, 51), Material = Enum.Material.Brick }, gate)
local leftDoor = part({ Name = "LeftGateDoor", Size = Vector3.new(11.5, 14, 1.3), Position = gateCenter + Vector3.new(-5.75, 7, 0), Color = Color3.fromRGB(37, 40, 39), Material = Enum.Material.CorrodedMetal }, gate)
local rightDoor = part({ Name = "RightGateDoor", Size = Vector3.new(11.5, 14, 1.3), Position = gateCenter + Vector3.new(5.75, 7, 0), Color = Color3.fromRGB(37, 40, 39), Material = Enum.Material.CorrodedMetal }, gate)
CollectionService:AddTag(leftDoor, "EscapeGateDoor")
CollectionService:AddTag(rightDoor, "EscapeGateDoor")
for x = -10, 10, 2.4 do
	part({ Name = "GateBars", Size = Vector3.new(0.3, 12, 1.7), Position = gateCenter + Vector3.new(x, 7, -0.25), Color = Color3.fromRGB(28, 30, 30), Material = Enum.Material.Metal }, gate)
end
local crank = part({ Name = "GateCrank", Size = Vector3.new(3.5, 4.5, 2), Position = gateCenter + Vector3.new(20, 2.25, 5), Color = Color3.fromRGB(48, 51, 49), Material = Enum.Material.CorrodedMetal }, gate)
local crankPrompt = Instance.new("ProximityPrompt")
crankPrompt.Name, crankPrompt.ActionText, crankPrompt.ObjectText = "GatePrompt", "Gate locked (0/3)", "Town perimeter gate"
crankPrompt.KeyboardKeyCode, crankPrompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
crankPrompt.HoldDuration, crankPrompt.MaxActivationDistance, crankPrompt.RequiresLineOfSight = 0.35, 11, false
crankPrompt.Parent = crank
CollectionService:AddTag(crank, "GateCrank")
local escapeZone = part({ Name = "EscapeZone", Size = Vector3.new(26, 10, 8), Position = gateCenter + Vector3.new(0, 5, -10), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false }, gate)
CollectionService:AddTag(escapeZone, "EscapeZone")

local patrolPositions = {
	Vector3.new(0, 2, 340), Vector3.new(0, 2, 290), Vector3.new(0, 2, 240), Vector3.new(0, 2, 195), Vector3.new(74, 2, 195),
	Vector3.new(170, 2, 195), Vector3.new(260, 2, 195), Vector3.new(170, 2, 120), Vector3.new(170, 2, 25), Vector3.new(260, 2, 25),
	Vector3.new(170, 2, -60), Vector3.new(170, 2, -145), Vector3.new(78, 2, -145), Vector3.new(78, 2, -232), Vector3.new(0, 2, -145),
	Vector3.new(0, 2, -230), Vector3.new(0, 2, -300), Vector3.new(0, 2, -344), Vector3.new(-80, 2, -145), Vector3.new(-170, 2, -145),
	Vector3.new(-265, 2, -145), Vector3.new(-170, 2, -55), Vector3.new(-170, 2, 25), Vector3.new(-265, 2, 25), Vector3.new(-230, 2, 91),
	Vector3.new(-170, 2, 195), Vector3.new(-75, 2, 195), Vector3.new(-75, 2, 275), Vector3.new(0, 2, 120), Vector3.new(0, 2, 25),
	Vector3.new(80, 2, 25), Vector3.new(0, 2, -60),
}
for _, position in patrolPositions do
	local node = part({ Name = "PatrolNode", Size = Vector3.new(2, 2, 2), Position = position, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	CollectionService:AddTag(node, "PatrolNode")
end
for index = 1, 20 do
	local anchor = patrolPositions[((index - 1) % #patrolPositions) + 1]
	local size = rng:NextNumber(0.82, 1.08)
	local rock = part({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = anchor + Vector3.new(rng:NextNumber(-5, 5), 1, rng:NextNumber(-5, 5)), Color = Color3.fromRGB(rng:NextInteger(50, 63), rng:NextInteger(48, 58), rng:NextInteger(43, 52)), Material = Enum.Material.Rock, Anchored = false })
	CollectionService:AddTag(rock, "Throwable")
end

print(("MapBuilder: Hollow Settlement ready — %d total instances"):format(#map:GetDescendants()))
