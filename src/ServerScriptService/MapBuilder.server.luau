--!strict
-- Builds a dark maze-building at runtime so the place is playable immediately.
-- Delete this once you build a real map in Studio.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

if Workspace:FindFirstChild("GeneratedMap") then
	return
end

local PART_MAX = 2048 -- Roblox clamps any Part axis to this; keep every Size below it

local ROOM = 48
local GRID = 4 -- GRID x GRID rooms
local WALL_H = 18
local WALL_T = 2
local DOOR_W = 12
local SPAN = ROOM * GRID -- 192
local HALF = SPAN / 2

local map = Instance.new("Folder")
map.Name = "GeneratedMap"
map.Parent = Workspace

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	local s = p.Size
	if s.X > PART_MAX or s.Y > PART_MAX or s.Z > PART_MAX then
		warn(("MapBuilder: '%s' size %s exceeds the %d-stud part limit"):format(p.Name, tostring(s), PART_MAX))
	end
	p.Parent = map
	return p
end

local function roomCenter(i: number, j: number): Vector3
	return Vector3.new(-HALF + (i + 0.5) * ROOM, 0, -HALF + (j + 0.5) * ROOM)
end

------------------------------------------------------------------- dark lighting
-- Lighting.Technology can't be set from a script -- set it once in Studio:
-- Explorer > Lighting > Properties > Technology = Future  (persists in the place file).
pcall(function()
	(Lighting :: any).Technology = Enum.Technology.Future
end)
Lighting.ClockTime = 0
Lighting.Brightness = 0.6
Lighting.Ambient = Color3.fromRGB(9, 9, 12) -- very dark; you rely on your lantern
Lighting.OutdoorAmbient = Color3.fromRGB(5, 5, 8)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.GlobalShadows = true
Lighting.FogColor = Color3.fromRGB(0, 0, 0)
Lighting.FogStart = 12
Lighting.FogEnd = 70

-- kill the view-dependent post effects that make the whole scene brighten/darken
-- as you turn the camera (atmospheric scattering, god-rays, bloom, DoF)
for _, fx in Lighting:GetChildren() do
	if fx:IsA("Atmosphere") then
		fx.Density = 0
		fx.Haze = 0
		fx.Glare = 0
	elseif fx:IsA("SunRaysEffect") or fx:IsA("BloomEffect") or fx:IsA("DepthOfFieldEffect") then
		fx.Enabled = false
	end
end

------------------------------------------------------------------- floor + ceiling
for i = 0, GRID - 1 do
	for j = 0, GRID - 1 do
		local c = roomCenter(i, j)
		part({
			Name = "FloorTile",
			Size = Vector3.new(ROOM, 1, ROOM),
			Position = c + Vector3.new(0, -0.5, 0),
			Color = Color3.fromRGB(34, 34, 40),
			Material = Enum.Material.Concrete,
		})
		part({
			Name = "CeilTile",
			Size = Vector3.new(ROOM, 1, ROOM),
			Position = c + Vector3.new(0, WALL_H + 0.5, 0),
			Color = Color3.fromRGB(22, 22, 26),
			Material = Enum.Material.Concrete,
		})
	end
end

------------------------------------------------------------------- perimeter walls
local EXIT_ROW = GRID - 1 -- exit sits on the +X wall of this row
for _, spec in
	{
		{ pos = Vector3.new(-HALF, WALL_H / 2, 0), size = Vector3.new(WALL_T, WALL_H, SPAN + WALL_T), axis = "x-" },
		{ pos = Vector3.new(HALF, WALL_H / 2, 0), size = Vector3.new(WALL_T, WALL_H, SPAN + WALL_T), axis = "x+" },
		{ pos = Vector3.new(0, WALL_H / 2, -HALF), size = Vector3.new(SPAN + WALL_T, WALL_H, WALL_T), axis = "z-" },
		{ pos = Vector3.new(0, WALL_H / 2, HALF), size = Vector3.new(SPAN + WALL_T, WALL_H, WALL_T), axis = "z+" },
	}
do
	if spec.axis == "x+" then
		-- leave a doorway for the exit in this wall
		local doorZ = (-HALF + (EXIT_ROW + 0.5) * ROOM)
		local halfGap = DOOR_W / 2
		local zA0, zA1 = -HALF - WALL_T / 2, doorZ - halfGap
		local zB0, zB1 = doorZ + halfGap, HALF + WALL_T / 2
		part({
			Name = "PerimWall",
			Position = Vector3.new(HALF, WALL_H / 2, (zA0 + zA1) / 2),
			Size = Vector3.new(WALL_T, WALL_H, zA1 - zA0),
			Color = Color3.fromRGB(28, 28, 32),
			Material = Enum.Material.Concrete,
		})
		part({
			Name = "PerimWall",
			Position = Vector3.new(HALF, WALL_H / 2, (zB0 + zB1) / 2),
			Size = Vector3.new(WALL_T, WALL_H, zB1 - zB0),
			Color = Color3.fromRGB(28, 28, 32),
			Material = Enum.Material.Concrete,
		})
		local exit = part({
			Name = "ExitDoor",
			Position = Vector3.new(HALF + 0.6, WALL_H / 2 - 3, doorZ),
			Size = Vector3.new(1, WALL_H - 6, DOOR_W - 1),
			Color = Color3.fromRGB(80, 200, 120),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		})
		CollectionService:AddTag(exit, "ExitDoor")
	else
		part({
			Name = "PerimWall",
			Position = spec.pos,
			Size = spec.size,
			Color = Color3.fromRGB(28, 28, 32),
			Material = Enum.Material.Concrete,
		})
	end
end

------------------------------------------------------------------- inner walls (with doorways)
local function wallSegment(cx: number, cz: number, sx: number, sz: number)
	part({
		Name = "Wall",
		Position = Vector3.new(cx, WALL_H / 2, cz),
		Size = Vector3.new(sx, WALL_H, sz),
		Color = Color3.fromRGB(30, 30, 35),
		Material = Enum.Material.Concrete,
	})
end

-- vertical inner lines (constant x), one doorway per room they border
for i = 1, GRID - 1 do
	local x = -HALF + i * ROOM
	for j = 0, GRID - 1 do
		local zc = -HALF + (j + 0.5) * ROOM
		local segLen = (ROOM - DOOR_W) / 2
		wallSegment(x, zc - (DOOR_W / 2 + segLen / 2), WALL_T, segLen)
		wallSegment(x, zc + (DOOR_W / 2 + segLen / 2), WALL_T, segLen)
	end
end
-- horizontal inner lines (constant z)
for j = 1, GRID - 1 do
	local z = -HALF + j * ROOM
	for i = 0, GRID - 1 do
		local xc = -HALF + (i + 0.5) * ROOM
		local segLen = (ROOM - DOOR_W) / 2
		wallSegment(xc - (DOOR_W / 2 + segLen / 2), z, segLen, WALL_T)
		wallSegment(xc + (DOOR_W / 2 + segLen / 2), z, segLen, WALL_T)
	end
end

------------------------------------------------------------------- spawn, key, nodes
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "Spawn"
spawnPad.Anchored = true
spawnPad.Size = Vector3.new(10, 1, 10)
spawnPad.Position = roomCenter(0, 0) + Vector3.new(0, 0.5, 0)
spawnPad.Color = Color3.fromRGB(60, 90, 150)
spawnPad.Material = Enum.Material.Neon
spawnPad.Transparency = 0.5
spawnPad.Parent = map

local key = part({
	Name = "KeyPickup",
	Size = Vector3.new(1, 2, 1),
	Position = roomCenter(GRID - 1, 0) + Vector3.new(0, 3, 0),
	Color = Color3.fromRGB(240, 210, 90),
	Material = Enum.Material.Neon,
})
CollectionService:AddTag(key, "KeyPickup")
task.spawn(function()
	while key.Parent do
		key.CFrame = CFrame.new(key.Position) * CFrame.Angles(0, os.clock() * 2, 0)
		task.wait()
	end
end)

for i = 0, GRID - 1 do
	for j = 0, GRID - 1 do
		local node = part({
			Name = "PatrolNode",
			Size = Vector3.new(2, 2, 2),
			Position = roomCenter(i, j) + Vector3.new(0, 3, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		CollectionService:AddTag(node, "PatrolNode")
	end
end

------------------------------------------------------------------- dim lights + flicker
math.randomseed(7)
local bulbs: { PointLight } = {}
for i = 0, GRID - 1 do
	for j = 0, GRID - 1 do
		if (i + j) % 2 == 0 then
			local fixture = part({
				Name = "Light",
				Size = Vector3.new(6, 0.6, 6),
				Position = roomCenter(i, j) + Vector3.new(0, WALL_H - 1, 0),
				Color = Color3.fromRGB(20, 18, 14),
				Material = Enum.Material.Metal,
			})
			local bulb = Instance.new("PointLight")
			bulb.Brightness = 0.6
			bulb.Range = 18
			bulb.Color = Color3.fromRGB(255, 206, 156)
			bulb.Shadows = false
			bulb.Parent = fixture
			table.insert(bulbs, bulb)
		end
	end
end

-- one random bulb stutters briefly every few seconds -- atmospheric, not a strobe
task.spawn(function()
	while map.Parent and #bulbs > 0 do
		task.wait(math.random() * 5 + 4)
		local b = bulbs[math.random(#bulbs)]
		for _ = 1, math.random(2, 5) do
			b.Brightness = 0.6 * (math.random() * 0.55 + 0.25)
			task.wait(0.06)
		end
		b.Brightness = 0.6
	end
end)

------------------------------------------------------------------- scattered rocks
for _ = 1, 5 do
	local i, j = math.random(0, GRID - 1), math.random(0, GRID - 1)
	local rock = part({
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		Position = roomCenter(i, j) + Vector3.new(math.random(-15, 15), 1, math.random(-15, 15)),
		Color = Color3.fromRGB(70, 70, 78),
		Material = Enum.Material.Slate,
		Anchored = false,
	})
	CollectionService:AddTag(rock, "Throwable")
end

print(("MapBuilder: %d parts, %d rooms"):format(#map:GetChildren(), GRID * GRID))
