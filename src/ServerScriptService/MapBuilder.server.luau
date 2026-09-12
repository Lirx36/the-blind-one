--!strict
-- The Hollow Labyrinth: a roofed institution maze with five landmarks.
-- City checkpoint: backups/city-2026-09-11 (source + standalone Studio place).
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local Layout = require(ReplicatedStorage:WaitForChild("MazeLayout"))
local MAP_VERSION = "HollowLabyrinth_3_Detailed"
local oldMap = Workspace:FindFirstChild("GeneratedMap")
if oldMap and oldMap:GetAttribute("MapVersion") == MAP_VERSION then return end
if oldMap then oldMap:Destroy() end
local loopCount = Layout.Validate()

local map = Instance.new("Folder")
map.Name = "GeneratedMap"
map:SetAttribute("MapVersion", MAP_VERSION)
map:SetAttribute("MapKind", "Maze")
map:SetAttribute("MechanismsActive", 0)
map:SetAttribute("MechanismsTotal", 3)
map:SetAttribute("GateOpen", false)
map:SetAttribute("Ready", false)
map.Parent = Workspace
local rng = Random.new(11926)
local C, N, W = Layout.Cell, Layout.Size, Layout.Wall
local HALF, HEIGHT = N * C / 2, 18

local function part(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material, parent: Instance?, decorative: boolean?): Part
	local object = Instance.new("Part")
	object.Name, object.Size, object.Position = name, size, position
	object.Color, object.Material, object.Anchored = color, material, true
	object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	object.CanCollide = decorative ~= true
	object.CanQuery = decorative ~= true
	object.CanTouch = false
	object.Parent = parent or map
	return object
end
local function folder(name: string): Folder
	local result = Instance.new("Folder")
	result.Name, result.Parent = name, map
	return result
end
local function lamp(parent: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, range, true
	light.Parent = parent
end
local function label(on: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.LightInfluence = "WayfindingText", face or Enum.NormalId.Front, 0.12
	gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 48
	gui.Parent = on
	local textLabel = Instance.new("TextLabel")
	textLabel.Size, textLabel.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	textLabel.Font, textLabel.Text, textLabel.TextColor3 = Enum.Font.GothamBold, text, color
	textLabel.TextStrokeColor3, textLabel.TextStrokeTransparency = Color3.fromRGB(4,8,9), 0.72
	textLabel.TextWrapped = true
	textLabel.TextScaled, textLabel.Parent = true, gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.045,0), UDim.new(0.045,0)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.1,0), UDim.new(0.1,0)
	padding.Parent = textLabel
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Transparency = Color3.fromRGB(224,235,233), 1, 0.78
	stroke.Parent = textLabel
end
local function tube(name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, parent: Instance): Part
	local p = part(name, Vector3.new((b-a).Magnitude, diameter, diameter), (a+b)/2, color, Enum.Material.CorrodedMetal, parent, true)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.lookAt((a+b)/2,b) * CFrame.Angles(0, math.rad(90), 0)
	return p
end

-- Cleaned Creator Store models live in ServerStorage. They provide the visible
-- detail while the simple generated parts remain the reliable collision shell.
local assetTemplates = ServerStorage:FindFirstChild("MazeAssetTemplates")
local function prop(templateName: string, parent: Instance, name: string, groundPosition: Vector3, yaw: number, scale: number, collidable: boolean?): Model?
	if not assetTemplates then return nil end
	local template = assetTemplates:FindFirstChild(templateName)
	if not template or not template:IsA("Model") then return nil end
	local model = template:Clone()
	model.Name = name
	model.Parent = parent
	model:ScaleTo(scale)
	local pivot = model:GetPivot()
	local boxCFrame, boxSize = model:GetBoundingBox()
	local pivotToBox = pivot:ToObjectSpace(boxCFrame)
	local desiredBox = CFrame.new(groundPosition + Vector3.new(0, boxSize.Y / 2, 0)) * CFrame.Angles(0, math.rad(yaw), 0)
	model:PivotTo(desiredBox * pivotToBox:Inverse())
	if collidable == true then
		local collider = Instance.new("Part")
		collider.Name = "PropCollider"
		collider.Size = Vector3.new(math.max(0.6,boxSize.X*0.86),math.max(0.8,boxSize.Y*0.88),math.max(0.6,boxSize.Z*0.86))
		collider.CFrame = desiredBox
		collider.Transparency = 1
		collider.Anchored, collider.CanCollide, collider.CanQuery, collider.CanTouch = true, true, true, false
		collider.Parent = model
	end
	return model
end

local function illuminate(model: Model?, color: Color3, brightness: number, range: number)
	if not model then return end
	local existing = model:FindFirstChildWhichIsA("Light", true)
	if existing and existing:IsA("Light") then
		existing.Color, existing.Brightness, existing.Range = color, brightness, range
		return
	end
	local holder = model:FindFirstChildWhichIsA("BasePart", true)
	if not holder then return end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, range, true
	light.Parent = holder
end

-- Atmosphere overrides legacy fog even at zero density. Use one distance-fog
-- renderer, so nearby walls stay crisp and the next corridor vanishes in mist.
for _, effect in Lighting:GetChildren() do
	if effect:IsA("Atmosphere") or effect.Name == "TheHollowGrade"
		or effect.Name == "TheHollowBloom" or effect.Name == "TheHollowDepth" then
		effect:Destroy()
	elseif effect:IsA("SunRaysEffect") then effect.Enabled = false end
end
Lighting.ClockTime, Lighting.Brightness = 5.1, 1.8
Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(48,52,54), Color3.fromRGB(67,72,74)
Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.4, 0.86
Lighting.GlobalShadows, Lighting.ShadowSoftness, Lighting.ExposureCompensation = true, 0.6, 0.12
Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(92,100,103), 12, 92
local grade = Instance.new("ColorCorrectionEffect")
grade.Name, grade.Brightness, grade.Contrast, grade.Saturation = "TheHollowGrade", 0.015, 0.12, -0.3
grade.TintColor, grade.Parent = Color3.fromRGB(222,231,233), Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name, bloom.Intensity, bloom.Size, bloom.Threshold = "TheHollowBloom", 0.16, 22, 1.1
bloom.Parent = Lighting
local depth = Instance.new("DepthOfFieldEffect")
depth.Name, depth.FarIntensity, depth.NearIntensity = "TheHollowDepth", 0.08, 0
depth.FocusDistance, depth.InFocusRadius, depth.Parent = 30, 28, Lighting
local sky = Lighting:FindFirstChildOfClass("Sky")
if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
sky.StarCount, sky.CelestialBodiesShown = 0, false
local terrain = Workspace.Terrain
local clouds = terrain:FindFirstChildOfClass("Clouds")
if not clouds then clouds = Instance.new("Clouds"); clouds.Parent = terrain end
clouds.Cover, clouds.Density, clouds.Color = 0.94, 0.75, Color3.fromRGB(87,94,98)

local walls, decor, landmarks, navigation = folder("MazeWalls"), folder("WeatheredDetails"), folder("Landmarks"), folder("Navigation")
local roof = folder("MazeRoof")
-- A solid, queryable ceiling covers every cell, including all five rooms.
-- Free-camera flight may pass through it; characters and rain cannot.
part("ContinuousRoof", Vector3.new(N*C+W+2,2,N*C+W+2), Vector3.new(0,20,0), Color3.fromRGB(48,51,48), Enum.Material.Concrete, roof)
for strip=-3,3 do
	part("CeilingGirder", Vector3.new(N*C,0.65,1), Vector3.new(0,18.65,strip*54), Color3.fromRGB(46,48,43), Enum.Material.CorrodedMetal, roof, true)
end
for z=2,N,3 do
	for x=2,N,3 do
		local position = Layout.Position(x,z) + Vector3.new(0,18.35,0)
		local fixture = prop("MazeIndustrialLight", roof, "IndustrialCeilingLight", position-Vector3.new(0,3.2,0), 0, 0.72)
		if fixture then
			illuminate(fixture, Color3.fromRGB(168,180,164), 0.82, 28)
		else
			part("CeilingHousing", Vector3.new(4.5,0.4,1.3), position, Color3.fromRGB(32,38,34), Enum.Material.Metal, roof, true)
			local diffuser = part("CeilingDiffuser", Vector3.new(3.8,0.1,0.8), position-Vector3.new(0,0.25,0), Color3.fromRGB(155,168,152), Enum.Material.Neon, roof, true)
			lamp(diffuser, Color3.fromRGB(168,180,164), 0.75, 28)
		end
	end
end
local palettes = {
	{Color3.fromRGB(79,83,70), Enum.Material.Brick, Color3.fromRGB(165,144,94), "01 / POWER"},
	{Color3.fromRGB(68,83,85), Enum.Material.Concrete, Color3.fromRGB(114,153,167), "02 / WATER"},
	{Color3.fromRGB(82,77,74), Enum.Material.Cobblestone, Color3.fromRGB(148,133,151), "03 / CHAPEL"},
	{Color3.fromRGB(89,77,62), Enum.Material.Brick, Color3.fromRGB(166,123,76), "04 / RECORDS"},
}
local function zone(x: number, z: number): number
	return (if z <= 10 then 0 else 2) + (if x <= 10 then 1 else 2)
end
local function roomAt(x: number, z: number): any
	for _, room in Layout.Rooms do
		if math.abs(x-room.X)<=1 and math.abs(z-room.Z)<=1 then return room end
	end
	return nil
end
part("Foundation", Vector3.new(350,2,350), Vector3.new(0,-1,0), Color3.fromRGB(35,39,35), Enum.Material.Ground)
local function wall(position: Vector3, horizontal: boolean, zoneIndex: number)
	local pal = palettes[zoneIndex]
	local size = if horizontal then Vector3.new(C+W,HEIGHT,W) else Vector3.new(W,HEIGHT,C+W)
	local body = part("MazeWall",size,position+Vector3.new(0,HEIGHT/2,0),pal[1],pal[2],walls)
	if MaterialService:FindFirstChild("HollowWallPBR3") then
		body.Material = Enum.Material.Concrete
		body.MaterialVariant = "HollowWallPBR3"
	end
	part("StoneCoping", Vector3.new(size.X+0.3,0.7,size.Z+0.3),position+Vector3.new(0,HEIGHT+0.2,0),Color3.fromRGB(54,60,57),Enum.Material.Concrete,decor,true)
	part("DampFooting",Vector3.new(size.X+0.12,2.4,size.Z+0.12),position+Vector3.new(0,1.2,0),Color3.fromRGB(37,47,39),Enum.Material.Slate,decor,true)
	-- Rain streaks and masonry joints are geometry, with no uploaded textures.
	local tangent = if horizontal then Vector3.new(1,0,0) else Vector3.new(0,0,1)
	local normal = if horizontal then Vector3.new(0,0,1) else Vector3.new(1,0,0)
	for _, side in {-1,1} do
		local stainSize = if horizontal then Vector3.new(rng:NextNumber(0.2,0.6),rng:NextNumber(4,10),0.025) else Vector3.new(0.025,rng:NextNumber(4,10),rng:NextNumber(0.2,0.6))
		local stain = part("RainStain",stainSize,position+tangent*rng:NextNumber(-6,6)+normal*side*(W/2+0.025)+Vector3.new(0,HEIGHT-stainSize.Y/2,0),Color3.fromRGB(30,38,32),Enum.Material.SmoothPlastic,decor,true)
		stain.Transparency = 0.65
	end
	if rng:NextNumber()<0.13 then
		local pipePos = position + normal*(W/2+0.4)
		local detailedPipe = prop("MazeRustedPipe", decor, "RustedWallPipe", pipePos, if horizontal then 0 else 90, 2.25)
		if not detailedPipe then tube("OldConduit",pipePos+Vector3.new(0,1,0),pipePos+Vector3.new(0,16,0),0.23,Color3.fromRGB(69,65,50),decor) end
	end
end

for z=1,N do
	for x=1,N do
		local center, pal = Layout.Position(x,z), palettes[zone(x,z)]
		local room = roomAt(x,z)
		local floor = part("WetFlagstones",Vector3.new(C-0.08,0.2,C-0.08),center+Vector3.new(0,-0.01,0),Color3.fromRGB(47,51,49),Enum.Material.Slate,decor)
		if MaterialService:FindFirstChild("HollowFloorPBR") then floor.MaterialVariant = "HollowFloorPBR" end
		floor.Reflectance = 0.05
		if x<N and bit32.band(Layout.Masks[z][x],2)==0 then wall(center+Vector3.new(C/2,0,0),false,zone(x,z)) end
		if z<N and bit32.band(Layout.Masks[z][x],4)==0 then wall(center+Vector3.new(0,0,C/2),true,zone(x,z)) end
		if x==1 then wall(center-Vector3.new(C/2,0,0),false,zone(x,z)) end
		if x==N then wall(center+Vector3.new(C/2,0,0),false,zone(x,z)) end
		if z==1 and x~=10 then wall(center-Vector3.new(0,0,C/2),true,zone(x,z)) end
		if z==N then wall(center+Vector3.new(0,0,C/2),true,zone(x,z)) end
		if not room and (x+z*3)%9==0 then
			local wet = part("ShallowPuddle",Vector3.new(5+rng:NextNumber(0,4),0.025,3+rng:NextNumber(0,4)),center+Vector3.new(2,0.12,-2),Color3.fromRGB(82,97,101),Enum.Material.Glass,decor,true)
			wet.Transparency,wet.Reflectance = 0.62,0.2
		end
		local node = part("PatrolNode",Vector3.new(1,1,1),center+Vector3.new(0,2,0),Color3.new(),Enum.Material.SmoothPlastic,navigation,true)
		node.Transparency=1
		CollectionService:AddTag(node,"PatrolNode")
		-- Recessed lamps and zone bands at some corners; leave a 12+ stud route.
		if (x*7+z*3)%11==0 and not room then
			local mask=Layout.Masks[z][x]
			local closed = if bit32.band(mask,1)==0 then Vector3.new(0,0,-1) elseif bit32.band(mask,8)==0 then Vector3.new(-1,0,0) else nil
			if closed then
				local lampPos=center+closed*(C/2-W/2-0.55)+Vector3.new(0,9,0)
				local fixture = prop("MazeCagedWallLight", decor, "CagedWallLamp", lampPos-Vector3.new(0,0.85,0), if closed.X~=0 then 90 else 0, 0.8)
				if fixture then
					illuminate(fixture, pal[3],0.9,24)
				else
					local fitting=part("CagedWallLamp",Vector3.new(1.3,0.5,1.3),lampPos,Color3.fromRGB(175,190,177),Enum.Material.Neon,decor,true)
					lamp(fitting, pal[3],0.9,24)
				end
				local band=part("SectorStripe",Vector3.new(if closed.X==0 then 5 else 0.04,0.3,if closed.X==0 then 0.04 else 5),center+closed*(C/2-W/2-0.08)+Vector3.new(0,4.8,0),pal[3],Enum.Material.SmoothPlastic,decor,true)
			end
		end
		if not room then
			local detailCode = (x*17 + z*29) % 89
			if detailCode == 7 then
				prop("MazeWheelchair", decor, "AbandonedWheelchair", center+Vector3.new(5,0,5), rng:NextInteger(0,3)*90, 1.05, true)
			elseif detailCode == 19 then
				prop("MazeGurney", decor, "AbandonedGurney", center+Vector3.new(-4,0,4), rng:NextInteger(0,3)*90, 0.9, true)
			elseif detailCode == 31 then
				prop("MazeCrateSet", decor, "SupplyCrate", center+Vector3.new(5,0,-5), rng:NextInteger(0,3)*90, 1.8, true)
			elseif detailCode == 43 then
				prop("MazeBarrelSet", decor, "CorrodedBarrels", center+Vector3.new(-5,0,-5), rng:NextInteger(0,3)*90, 0.75, true)
			end
		end
		if (x*13+z*7)%23==0 and not room then
			local rock=part("Rock",Vector3.one*0.9,center+Vector3.new(-3,0.6,2),Color3.fromRGB(61,58,51),Enum.Material.Rock,map)
			rock.Shape,rock.Anchored,rock.CanTouch=Enum.PartType.Ball,false,true
			CollectionService:AddTag(rock,"Throwable")
		end
	end
end

local function roomSign(center: Vector3, text: string, color: Color3)
	local signCenter = center+Vector3.new(0,13,-20)
	local frame=part("WayfindingFrame",Vector3.new(20,4.5,0.72),signCenter,Color3.fromRGB(91,101,101),Enum.Material.Metal,landmarks,true)
	local beam=part("WayfindingPanel",Vector3.new(19.1,3.65,0.82),signCenter,Color3.fromRGB(20,29,31),Enum.Material.Metal,landmarks,true)
	beam.Reflectance = 0.06
	local displayText = string.gsub(text," / ","  •  ")
	label(beam,displayText,color,Enum.NormalId.Back)
	label(beam,displayText,color,Enum.NormalId.Front)
	local accent=part("WayfindingAccent",Vector3.new(17.8,0.18,0.94),signCenter-Vector3.new(0,1.78,0),color,Enum.Material.Neon,landmarks,true)
	lamp(accent,color,0.16,7)
	for _, x in {-7.4,7.4} do
		part("SignHanger",Vector3.new(0.22,7.4,0.22),center+Vector3.new(x,16.7,-20),Color3.fromRGB(61,69,69),Enum.Material.CorrodedMetal,landmarks,true)
		for _, y in {-1.45,1.45} do
			local bolt=part("FrameBolt",Vector3.new(0.32,0.32,0.32),signCenter+Vector3.new(x,y,-0.48),Color3.fromRGB(168,174,168),Enum.Material.Metal,landmarks,true)
			bolt.Shape = Enum.PartType.Ball
		end
	end
end
for _, room in Layout.Rooms do
	local center=Layout.Position(room.X,room.Z)
	roomSign(center,string.upper(room.Name),palettes[zone(room.X,room.Z)][3])
	for _, offset in {Vector3.new(-21,0,-21),Vector3.new(21,0,21)} do
		local post=part("CourtPillar",Vector3.new(2,13,2),center+offset+Vector3.new(0,6.5,0),Color3.fromRGB(77,82,76),Enum.Material.Concrete,landmarks)
		local head=part("CourtLight",Vector3.new(1.5,0.6,1.5),post.Position+Vector3.new(0,6.8,0),Color3.fromRGB(163,183,173),Enum.Material.Neon,landmarks,true)
		lamp(head,head.Color,1.2,34)
	end
	if room.Id=="COURT" then
		local base=part("DryFountainBase",Vector3.new(11,1,11),center+Vector3.new(0,0.5,0),Color3.fromRGB(76,82,76),Enum.Material.Concrete,landmarks)
		local column=part("ListeningMonument",Vector3.new(2.8,12,2.8),center+Vector3.new(0,6.5,0),Color3.fromRGB(66,75,69),Enum.Material.Slate,landmarks)
		part("MonumentCap",Vector3.new(4.3,1,4.3),center+Vector3.new(0,13,0),Color3.fromRGB(100,105,98),Enum.Material.Concrete,landmarks)
		for _, x in {-16,16} do
			part("StoneBench",Vector3.new(3,2,10),center+Vector3.new(x,1,0),Color3.fromRGB(61,68,60),Enum.Material.Slate,landmarks)
		end
		prop("MazeWheelchair",landmarks,"CourtWheelchair",center+Vector3.new(-12,0,12),-28,1.05,true)
		prop("MazeCrateSet",landmarks,"CourtOfferings",center+Vector3.new(12,0,-12),18,1.7,true)
	elseif room.Id=="POWER" then
		local detailedGenerator = prop("MazeIndustrialGenerator",landmarks,"IndustrialGenerator",center+Vector3.new(-12,0,4),180,0.36,true)
		if not detailedGenerator then
			local machine=part("Generator",Vector3.new(11,6,7),center+Vector3.new(-12,3,4),Color3.fromRGB(71,78,62),Enum.Material.CorrodedMetal,landmarks)
			for x=-4,4,1.1 do part("CoolingFin",Vector3.new(0.18,4,0.3),machine.Position+Vector3.new(x,0,-3.7),Color3.fromRGB(32,36,31),Enum.Material.Metal,landmarks,true) end
		end
		tube("Exhaust",center+Vector3.new(-12,6,5),center+Vector3.new(-12,19,5),1.2,Color3.fromRGB(52,51,45),landmarks)
	elseif room.Id=="WATER" then
		local water=part("FloodedTiles",Vector3.new(32,0.025,31),center+Vector3.new(0,0.13,0),Color3.fromRGB(66,99,105),Enum.Material.Glass,landmarks,true)
		water.Transparency,water.Reflectance=0.52,0.24
		for _, x in {-17,17} do tube("WaterMain",center+Vector3.new(x,2,-17),center+Vector3.new(x,2,17),1.7,Color3.fromRGB(57,90,88),landmarks) end
		prop("MazeBarrelSet",landmarks,"PumpRoomBarrels",center+Vector3.new(-11,0,10),16,0.9,true)
		prop("MazeGurney",landmarks,"FloodedGurney",center+Vector3.new(9,0,-8),-22,0.95,true)
	elseif room.Id=="CHAPEL" then
		for _, x in {-12,12} do
			for _, z in {-8,3,14} do
				if not prop("MazeChurchPews",landmarks,"WeatheredPew",center+Vector3.new(x,0,z),90,0.55,true) then
					part("PewSeat",Vector3.new(9,0.5,2.5),center+Vector3.new(x,1.7,z),Color3.fromRGB(68,51,36),Enum.Material.WoodPlanks,landmarks)
					part("PewBack",Vector3.new(9,2,0.5),center+Vector3.new(x,2.7,z+1.1),Color3.fromRGB(52,42,32),Enum.Material.WoodPlanks,landmarks)
				end
			end
		end
		part("Altar",Vector3.new(9,3,4),center+Vector3.new(0,1.5,-17),Color3.fromRGB(83,79,71),Enum.Material.Marble,landmarks)
		part("BrokenRoof",Vector3.new(48,1,16),center+Vector3.new(0,19,-17),Color3.fromRGB(48,43,40),Enum.Material.Slate,landmarks)
		for _, x in {-20,20} do part("ChapelColumn",Vector3.new(1.5,19,1.5),center+Vector3.new(x,9.5,-17),Color3.fromRGB(66,63,57),Enum.Material.Concrete,landmarks) end
	elseif room.Id=="RECORDS" then
		for _, x in {-18,18} do
			for _, z in {-13,0,13} do
				if not prop("MazeRustyLocker",landmarks,"RustyArchiveLocker",center+Vector3.new(x,0,z),if x<0 then 90 else -90,0.052,true) then
					local cabinet=part("ArchiveCabinet",Vector3.new(4,6,5),center+Vector3.new(x,3,z),Color3.fromRGB(75,75,62),Enum.Material.CorrodedMetal,landmarks)
					for y=-1.8,1.8,1.8 do part("DrawerHandle",Vector3.new(1.7,0.16,0.2),cabinet.Position+Vector3.new(0,y,-2.65),Color3.fromRGB(127,120,102),Enum.Material.Metal,landmarks,true) end
				end
			end
		end
	end
end

local function mechanism(id: string, displayName: string, center: Vector3)
	local station=Instance.new("Model")
	station.Name,station.Parent="GateMechanism_"..id,map
	station:SetAttribute("MechanismId",id)
	station:SetAttribute("DisplayName",displayName)
	station:SetAttribute("Activated",false)
	local base=part("Base",Vector3.new(4,4.5,2.6),center+Vector3.new(0,2.25,0),Color3.fromRGB(63,72,64),Enum.Material.CorrodedMetal,station)
	station.PrimaryPart=base
	local core=part("Core",Vector3.new(1.4,0.55,0.2),center+Vector3.new(0,3.5,-1.4),Color3.fromRGB(150,62,38),Enum.Material.Neon,station,true)
	lamp(core,core.Color,0.35,8)
	for x=-1,1 do part("Breaker",Vector3.new(0.3,1,0.2),center+Vector3.new(x,2,-1.4),Color3.fromRGB(156,149,112),Enum.Material.Metal,station,true) end
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name,prompt.ActionText,prompt.ObjectText="RestorePrompt","Restore mechanism",displayName
	prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
	prompt.HoldDuration,prompt.MaxActivationDistance,prompt.RequiresLineOfSight=3.2,9,true
	prompt.Parent=base
	CollectionService:AddTag(station,"GateMechanism")
end
mechanism("POWER","Generator House / Power",Layout.Position(4,5)+Vector3.new(14,0,12))
mechanism("WATER","Drowned Gallery / Pump",Layout.Position(16,5)+Vector3.new(11,0,-12))
mechanism("RECORDS","Records Yard / Relay",Layout.Position(16,15)+Vector3.new(0,0,-14))
local spawnPad=Instance.new("SpawnLocation")
spawnPad.Name,spawnPad.Size,spawnPad.Position="Spawn",Vector3.new(6,0.4,6),Layout.Position(10,19)+Vector3.new(0,0.4,0)
spawnPad.Anchored,spawnPad.Transparency,spawnPad.CanCollide,spawnPad.Duration=true,1,false,0
spawnPad.Parent=map
roomSign(Layout.Position(10,19)+Vector3.new(0,0,5),"THE HOLLOW / KEEP QUIET",Color3.fromRGB(185,188,165))

-- Only the locked northern opening leads outside. The gate leaves carry all
-- detail with them; no stationary bars remain across the exit after opening.
local gateCenter=Vector3.new(0,0,-HALF)
part("ExitCanopy",Vector3.new(24,2,30),gateCenter+Vector3.new(0,21,-13),Color3.fromRGB(48,51,48),Enum.Material.Concrete,roof)
part("ExitApron",Vector3.new(28,1,30),gateCenter+Vector3.new(0,-0.5,-10),Color3.fromRGB(50,57,51),Enum.Material.Slate)
for _, x in {-1,1} do
	local door=part("EscapeGateLeaf",Vector3.new(9,18,1.5),gateCenter+Vector3.new(x*4.5,9,0),Color3.fromRGB(56,64,59),Enum.Material.CorrodedMetal)
	CollectionService:AddTag(door,"EscapeGateDoor")
	part("ExitSidewall",Vector3.new(2.8,20,29),gateCenter+Vector3.new(x*10.4,10,-13),Color3.fromRGB(68,73,66),Enum.Material.Brick,walls)
end
local header=part("ExitHeader",Vector3.new(22,3,3),gateCenter+Vector3.new(0,19,0),Color3.fromRGB(73,79,69),Enum.Material.Concrete)
label(header,"PERIMETER / EXIT",Color3.fromRGB(179,189,162),Enum.NormalId.Back)
local crank=part("GateCrank",Vector3.new(2,3.5,2),gateCenter+Vector3.new(6,1.75,7),Color3.fromRGB(74,78,63),Enum.Material.CorrodedMetal)
local prompt=Instance.new("ProximityPrompt")
prompt.Name,prompt.ActionText,prompt.ObjectText="GatePrompt","Gate locked (0/3)","Labyrinth perimeter"
prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
prompt.HoldDuration,prompt.MaxActivationDistance,prompt.RequiresLineOfSight=0.35,9,true
prompt.Parent=crank
CollectionService:AddTag(crank,"GateCrank")
local escape=part("EscapeZone",Vector3.new(17,10,5),gateCenter+Vector3.new(0,5,-14),Color3.new(),Enum.Material.SmoothPlastic,map,true)
escape.Transparency,escape.CanTouch=1,true
CollectionService:AddTag(escape,"EscapeZone")
map:SetAttribute("Ready",true)
print(("MapBuilder: Hollow Labyrinth ready — 342x342 studs, %d loops, %d instances"):format(loopCount,#map:GetDescendants()))
