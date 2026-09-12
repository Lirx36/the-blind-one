--!strict
-- Physical matchmaking hub: four configurable private elevators and one
-- unrestricted public queue. Matches reuse this same place in reserved servers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local actionRemote = Remotes.LobbyAction
local stateRemote = Remotes.LobbyState

local ORIGIN = Vector3.new(0, 420, 0)
local GAME_PLACE_ID = 121524238363010
local PRIVATE_CAPACITY_MIN = 2
local PRIVATE_CAPACITY_MAX = 6
local PUBLIC_CAPACITY = 10
local PUBLIC_COUNTDOWN = 15

type Queue = {
	id: string,
	kind: string,
	ownerUserId: number?,
	capacity: number,
	friendsOnly: boolean,
	blindMode: string,
	members: { [Player]: boolean },
	countdown: number?,
	generation: number,
	launching: boolean,
	label: TextLabel?,
}

local queues: { [string]: Queue } = {}
local playerQueue: { [Player]: Queue } = {}
local hubSpawn: BasePart
local menuHolding: BasePart

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material
	object.Anchored = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

local function addWorldLabel(partObject: BasePart, titleText: string, detailText: string): TextLabel
	local board = Instance.new("BillboardGui")
	board.Name = "QueueSign"
	board.Size = UDim2.fromOffset(180, 58)
	board.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 55
	board.Parent = partObject
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(218, 228, 226)
	title.TextStrokeTransparency = 0.18
	title.Parent = board
	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Position = UDim2.fromOffset(0, 28)
	detail.Size = UDim2.new(1, 0, 0, 24)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.Text = detailText
	detail.TextSize = 9
	detail.TextColor3 = Color3.fromRGB(139, 161, 161)
	detail.TextStrokeTransparency = 0.35
	detail.Parent = board
	return detail
end

local function queueCount(queue: Queue): number
	local count = 0
	for member in queue.members do
		if member.Parent == Players then count += 1 end
	end
	return count
end

local function updateWorldLabel(queue: Queue)
	if not queue.label then return end
	local count = queueCount(queue)
	if queue.kind == "Public" then
		queue.label.Text = if queue.countdown then
			("%d/%d  •  DEPARTING IN %d"):format(count, queue.capacity, queue.countdown)
			else ("%d/%d  •  WALK IN TO JOIN"):format(count, queue.capacity)
	else
		local access = if queue.friendsOnly then "FRIENDS ONLY" else "OPEN PARTY"
		queue.label.Text = if queue.ownerUserId then
			("%d/%d  •  %s  •  %s"):format(count, queue.capacity, access, string.upper(queue.blindMode))
			else "EMPTY  •  ENTER TO HOST"
	end
end

local function stateFor(player: Player)
	local queue = playerQueue[player]
	local queueData = nil
	if queue then
		local members = {}
		for member in queue.members do
			if member.Parent == Players then
				table.insert(members, { name = member.DisplayName, username = member.Name, userId = member.UserId })
			end
		end
		table.sort(members, function(a, b)
			if a.userId == queue.ownerUserId then return true end
			if b.userId == queue.ownerUserId then return false end
			return a.name < b.name
		end)
		queueData = {
			id = queue.id,
			kind = queue.kind,
			ownerUserId = queue.ownerUserId,
			capacity = queue.capacity,
			friendsOnly = queue.friendsOnly,
			blindMode = queue.blindMode,
			countdown = queue.countdown,
			members = members,
		}
	end
	return {
		phase = if player:GetAttribute("InMatch") == true then "Match" elseif player:GetAttribute("InHub") == true then "Hub" else "Menu",
		queue = queueData,
	}
end

local function broadcast()
	for _, queue in queues do updateWorldLabel(queue) end
	for _, player in Players:GetPlayers() do stateRemote:FireClient(player, stateFor(player)) end
end

local function removeFromQueue(player: Player)
	local queue = playerQueue[player]
	if not queue then return end
	queue.members[player] = nil
	playerQueue[player] = nil
	player:SetAttribute("QueueId", nil)
	queue.generation += 1
	queue.countdown = nil
	if queue.ownerUserId == player.UserId then
		queue.ownerUserId = nil
		for member in queue.members do queue.ownerUserId = member.UserId break end
	end
	if queueCount(queue) == 0 and queue.kind == "Private" then
		queue.ownerUserId = nil
		queue.capacity = 4
		queue.friendsOnly = true
		queue.blindMode = "Bot"
	end
	broadcast()
end

local function canJoin(player: Player, queue: Queue): boolean
	if queue.launching or queueCount(queue) >= queue.capacity then return false end
	if queue.kind ~= "Private" or not queue.ownerUserId or not queue.friendsOnly then return true end
	local owner = Players:GetPlayerByUserId(queue.ownerUserId)
	if not owner then return false end
	local ok, friends = pcall(function() return owner:IsFriendsWith(player.UserId) end)
	return ok and friends
end

local function localLaunch(queue: Queue)
	workspace:SetAttribute("BlindOneMode", queue.blindMode)
	local map = workspace:WaitForChild("GeneratedMap")
	local spawn = map:WaitForChild("Spawn")
	local departing = {}
	for member in queue.members do table.insert(departing, member) end
	for _, member in departing do
		queue.members[member] = nil
		playerQueue[member] = nil
		member:SetAttribute("QueueId", nil)
		member:SetAttribute("InHub", false)
		member:SetAttribute("InMatch", true)
		local character = member.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then root.Anchored = false end
		if character and spawn:IsA("BasePart") then character:PivotTo(spawn.CFrame + Vector3.new(math.random(-5, 5), 4, math.random(-5, 5))) end
	end
	queue.ownerUserId = nil
	queue.countdown = nil
	queue.launching = false
	queue.generation += 1
	broadcast()
end

local function launch(queue: Queue)
	if queue.launching or queueCount(queue) == 0 then return end
	if queue.blindMode == "Player" and queueCount(queue) < 2 then return end
	queue.launching = true
	broadcast()
	local party = {}
	for member in queue.members do if member.Parent == Players then table.insert(party, member) end end
	if RunService:IsStudio() then
		queue.launching = false
		queue.countdown = nil
		broadcast()
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ DirectMatch = true, BlindOneMode = queue.blindMode })
	local ok = pcall(function() TeleportService:TeleportAsync(GAME_PLACE_ID, party, options) end)
	if not ok then
		queue.launching = false
		broadcast()
	end
end

local function startPublicCountdown(queue: Queue)
	if queue.kind ~= "Public" or queue.countdown or queueCount(queue) < 2 then return end
	queue.generation += 1
	local generation = queue.generation
	task.spawn(function()
		for remaining = PUBLIC_COUNTDOWN, 0, -1 do
			if queue.generation ~= generation or queueCount(queue) < 2 or queue.launching then
				queue.countdown = nil
				broadcast()
				return
			end
			queue.countdown = remaining
			broadcast()
			if remaining > 0 then task.wait(1) end
		end
		launch(queue)
	end)
end

local function joinQueue(player: Player, queue: Queue)
	if player:GetAttribute("InHub") ~= true or playerQueue[player] == queue then return end
	if not canJoin(player, queue) then
		stateRemote:FireClient(player, stateFor(player))
		return
	end
	removeFromQueue(player)
	queue.members[player] = true
	playerQueue[player] = queue
	player:SetAttribute("QueueId", queue.id)
	if queue.kind == "Private" and not queue.ownerUserId then queue.ownerUserId = player.UserId end
	broadcast()
	startPublicCountdown(queue)
end

local function buildHub()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(118, 128, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(146, 157, 160)
	Lighting.FogColor = Color3.fromRGB(177, 205, 209)
	Lighting.FogStart = 150
	Lighting.FogEnd = 420
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.45
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.35
	for _, effect in Lighting:GetChildren() do
		if effect.Name == "LobbyGrade" or effect.Name == "LobbyBloom" or effect.Name == "LobbyAtmosphere" or effect.Name == "LobbySunRays" then effect:Destroy() end
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LobbyGrade"
	grade.Brightness = 0.045
	grade.Contrast = 0.06
	grade.Saturation = 0.16
	grade.TintColor = Color3.fromRGB(245, 251, 242)
	grade.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "LobbyBloom"
	bloom.Intensity = 0.22
	bloom.Size = 18
	bloom.Threshold = 1.35
	bloom.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "LobbyAtmosphere"
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 224, 224)
	atmosphere.Decay = Color3.fromRGB(116, 151, 153)
	atmosphere.Glare = 0.08
	atmosphere.Haze = 0.7
	atmosphere.Parent = Lighting
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "LobbySunRays"
	sunRays.Intensity = 0.035
	sunRays.Spread = 0.7
	sunRays.Parent = Lighting
	local old = workspace:FindFirstChild("GeneratedLobby")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "GeneratedLobby"
	folder.Parent = workspace
	local grassColor = Color3.fromRGB(84, 155, 74)
	local stone = Color3.fromRGB(90, 101, 99)
	local floor = makePart(folder, "HubFloor", Vector3.new(280, 2, 210), CFrame.new(ORIGIN), grassColor, Enum.Material.Grass)
	local plaza = makePart(folder, "GardenPlaza", Vector3.new(164, 0.8, 190), CFrame.new(ORIGIN + Vector3.new(0, 1.25, 0)), Color3.fromRGB(191, 174, 126), Enum.Material.Cobblestone)
	local roadColor = Color3.fromRGB(48, 55, 58)
	makePart(folder, "WestRoad", Vector3.new(38, 0.7, 190), CFrame.new(ORIGIN + Vector3.new(-108, 1.2, 0)), roadColor, Enum.Material.Asphalt)
	makePart(folder, "EastRoad", Vector3.new(38, 0.7, 190), CFrame.new(ORIGIN + Vector3.new(108, 1.2, 0)), roadColor, Enum.Material.Asphalt)
	for z = -82, 82, 16 do
		makePart(folder, "RoadMarking", Vector3.new(0.7, 0.08, 7), CFrame.new(ORIGIN + Vector3.new(-108, 1.6, z)), Color3.fromRGB(245, 218, 84), Enum.Material.Neon)
		makePart(folder, "RoadMarking", Vector3.new(0.7, 0.08, 7), CFrame.new(ORIGIN + Vector3.new(108, 1.6, z)), Color3.fromRGB(245, 218, 84), Enum.Material.Neon)
	end
	-- A complete low perimeter fixes the missing wall without boxing in the cheerful park.
	for _, data in {
		{Vector3.new(-139, 5, 0), Vector3.new(2, 12, 210)},
		{Vector3.new(139, 5, 0), Vector3.new(2, 12, 210)},
		{Vector3.new(0, 5, -104), Vector3.new(280, 12, 2)},
		{Vector3.new(0, 5, 104), Vector3.new(280, 12, 2)},
	} do
		makePart(folder, "BoundaryWall", data[2], CFrame.new(ORIGIN + data[1]), Color3.fromRGB(116, 126, 119), Enum.Material.Brick)
	end

	local function addTree(position: Vector3, scale: number)
		local model = Instance.new("Model")
		model.Name = "ParkTree"
		model.Parent = folder
		makePart(model, "Trunk", Vector3.new(3.2 * scale, 13 * scale, 3.2 * scale), CFrame.new(ORIGIN + position + Vector3.new(0, 6.5 * scale, 0)), Color3.fromRGB(105, 70, 42), Enum.Material.Wood)
		local leafColor = Color3.fromRGB(61, 151, 72)
		for _, leaf in {
			{Vector3.new(0, 14, 0), Vector3.new(12, 8, 12)},
			{Vector3.new(-5, 12, 1), Vector3.new(8, 7, 8)},
			{Vector3.new(5, 12.5, -1), Vector3.new(8, 7, 8)},
			{Vector3.new(0, 17, 0), Vector3.new(8, 6, 8)},
		} do
			local canopy = makePart(model, "Canopy", leaf[2] * scale, CFrame.new(ORIGIN + position + leaf[1] * scale), leafColor, Enum.Material.LeafyGrass)
			canopy.Shape = Enum.PartType.Ball
		end
	end

	local function addLamp(position: Vector3)
		local model = Instance.new("Model")
		model.Name = "ParkLamp"
		model.Parent = folder
		makePart(model, "Post", Vector3.new(0.7, 11, 0.7), CFrame.new(ORIGIN + position + Vector3.new(0, 5.5, 0)), Color3.fromRGB(42, 52, 56), Enum.Material.Metal)
		local bulb = makePart(model, "Lamp", Vector3.new(2.8, 1.2, 2.8), CFrame.new(ORIGIN + position + Vector3.new(0, 11.2, 0)), Color3.fromRGB(255, 235, 167), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Brightness = 1.1
		light.Range = 24
		light.Color = bulb.Color
		light.Shadows = true
		light.Parent = bulb
	end

	local function addBench(position: Vector3, yaw: number)
		local model = Instance.new("Model")
		model.Name = "ParkBench"
		model.Parent = folder
		local cf = CFrame.new(ORIGIN + position) * CFrame.Angles(0, math.rad(yaw), 0)
		makePart(model, "Seat", Vector3.new(11, 0.8, 3), cf + Vector3.new(0, 3, 0), Color3.fromRGB(151, 91, 48), Enum.Material.WoodPlanks)
		makePart(model, "Back", Vector3.new(11, 4, 0.7), cf * CFrame.new(0, 4.8, 1.15), Color3.fromRGB(151, 91, 48), Enum.Material.WoodPlanks)
		for x = -4.2, 4.2, 8.4 do
			makePart(model, "Leg", Vector3.new(0.7, 3, 0.7), cf * CFrame.new(x, 1.5, 0), Color3.fromRGB(50, 56, 57), Enum.Material.Metal)
		end
	end

	local function addFlowerBed(position: Vector3)
		local model = Instance.new("Model")
		model.Name = "FlowerBed"
		model.Parent = folder
		makePart(model, "Soil", Vector3.new(18, 1, 7), CFrame.new(ORIGIN + position + Vector3.new(0, 1.8, 0)), Color3.fromRGB(91, 61, 40), Enum.Material.Ground)
		local colors = { Color3.fromRGB(255, 104, 126), Color3.fromRGB(255, 212, 76), Color3.fromRGB(126, 173, 255), Color3.fromRGB(239, 141, 255) }
		for index = 1, 8 do
			local x = -7.5 + ((index - 1) % 4) * 5
			local z = if index <= 4 then -1.8 else 1.8
			local flower = makePart(model, "Flower", Vector3.new(1.3, 1.3, 1.3), CFrame.new(ORIGIN + position + Vector3.new(x, 3, z)), colors[((index - 1) % #colors) + 1], Enum.Material.SmoothPlastic)
			flower.Shape = Enum.PartType.Ball
		end
	end

	local function addCar(position: Vector3, color: Color3, yaw: number)
		local model = Instance.new("Model")
		model.Name = "ParkedCar"
		model.Parent = folder
		local cf = CFrame.new(ORIGIN + position) * CFrame.Angles(0, math.rad(yaw), 0)
		makePart(model, "Body", Vector3.new(8, 2.2, 14), cf * CFrame.new(0, 2.7, 0), color, Enum.Material.SmoothPlastic)
		makePart(model, "Cabin", Vector3.new(7, 2.5, 7), cf * CFrame.new(0, 4.7, -0.5), Color3.fromRGB(93, 143, 172), Enum.Material.Glass)
		for _, wheelPos in { Vector3.new(-4.1, 1.7, -4.5), Vector3.new(4.1, 1.7, -4.5), Vector3.new(-4.1, 1.7, 4.5), Vector3.new(4.1, 1.7, 4.5) } do
			local wheel = makePart(model, "Wheel", Vector3.new(1.2, 3, 3), cf * CFrame.new(wheelPos), Color3.fromRGB(24, 27, 29), Enum.Material.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	-- Detailed park props are persisted in Workspace.LobbyDetailedDecor.
	-- They come from cleaned Toolbox models instead of primitive placeholders.

	hubSpawn = makePart(folder, "HubSpawn", Vector3.new(4,1,4), CFrame.new(ORIGIN + Vector3.new(0,3,-76)), stone, Enum.Material.SmoothPlastic)
	hubSpawn.Transparency = 1
	hubSpawn.CanCollide = false
	menuHolding = makePart(folder, "MenuHolding", Vector3.new(4,1,4), CFrame.new(ORIGIN + Vector3.new(0,3,-90)), stone, Enum.Material.SmoothPlastic)
	menuHolding.Transparency = 1
	menuHolding.CanCollide = false
	local camera = makePart(folder, "MenuCamera", Vector3.one, CFrame.new(ORIGIN + Vector3.new(62,20,-76)), stone, Enum.Material.SmoothPlastic)
	camera.Transparency = 1
	camera.CanCollide = false
	camera.CFrame = CFrame.lookAt(camera.Position, ORIGIN + Vector3.new(0,8,-6))
	local privatePositions = { Vector3.new(-56,1,18), Vector3.new(0,1,18), Vector3.new(56,1,18) }
	for index, offset in privatePositions do
		local padColors = { Color3.fromRGB(77, 156, 212), Color3.fromRGB(110, 184, 126), Color3.fromRGB(168, 116, 211) }
		local pad = makePart(folder, "PrivateModule" .. index, Vector3.new(34,0.6,28), CFrame.new(ORIGIN + offset), padColors[index], Enum.Material.SmoothPlastic)
		local ring = Instance.new("SelectionBox")
		ring.Adornee = pad
		ring.Color3 = Color3.fromRGB(235, 247, 255)
		ring.LineThickness = 0.035
		ring.SurfaceTransparency = 0.88
		ring.Parent = pad
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter private module"
		prompt.ObjectText = "PRIVATE " .. index
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 13
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		local queue: Queue = { id = "Private" .. index, kind = "Private", ownerUserId = nil, capacity = 4, friendsOnly = true, blindMode = "Bot", members = {}, countdown = nil, generation = 0, launching = false, label = nil }
		queue.label = addWorldLabel(pad, "PRIVATE MODULE " .. index, "EMPTY  •  ENTER TO HOST")
		queues[queue.id] = queue
		prompt.Triggered:Connect(function(player) joinQueue(player, queue) end)
	end
	local publicPad = makePart(folder, "PublicQueue", Vector3.new(128,0.6,30), CFrame.new(ORIGIN + Vector3.new(0,1,68)), Color3.fromRGB(240, 151, 67), Enum.Material.SmoothPlastic)
	local publicQueue: Queue = { id = "Public", kind = "Public", ownerUserId = nil, capacity = PUBLIC_CAPACITY, friendsOnly = false, blindMode = "Bot", members = {}, countdown = nil, generation = 0, launching = false, label = nil }
	publicQueue.label = addWorldLabel(publicPad, "PUBLIC DESCENT", "0/10  •  WALK IN TO JOIN")
	queues.Public = publicQueue
	local touchDebounce: { [Player]: number } = {}
	publicPad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or (touchDebounce[player] or 0) > os.clock() then return end
		touchDebounce[player] = os.clock() + 1
		joinQueue(player, publicQueue)
	end)
	floor:SetAttribute("LobbyHub", true)
	plaza:SetAttribute("LobbyHub", true)
end

local function buildBunkerHub()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2.35
	Lighting.ExposureCompensation = 0.65
	Lighting.Ambient = Color3.fromRGB(66, 74, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(48, 56, 62)
	Lighting.FogColor = Color3.fromRGB(70, 82, 87)
	Lighting.FogStart = 75
	Lighting.FogEnd = 260
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.28
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.6
	for _, effect in Lighting:GetChildren() do
		if effect.Name == "LobbyGrade" or effect.Name == "LobbyBloom" or effect.Name == "LobbyAtmosphere" or effect.Name == "LobbySunRays" or effect.Name == "LobbyDepth" then
			effect:Destroy()
		end
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LobbyGrade"
	grade.Brightness = 0.035
	grade.Contrast = 0.12
	grade.Saturation = -0.12
	grade.TintColor = Color3.fromRGB(218, 229, 231)
	grade.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "LobbyBloom"
	bloom.Intensity = 0.3
	bloom.Size = 28
	bloom.Threshold = 1.15
	bloom.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "LobbyAtmosphere"
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(114, 132, 137)
	atmosphere.Decay = Color3.fromRGB(38, 45, 49)
	atmosphere.Glare = 0.02
	atmosphere.Haze = 0.65
	atmosphere.Parent = Lighting
	local depth = Instance.new("DepthOfFieldEffect")
	depth.Name = "LobbyDepth"
	depth.FarIntensity = 0.09
	depth.FocusDistance = 75
	depth.InFocusRadius = 55
	depth.NearIntensity = 0.02
	depth.Parent = Lighting

	local old = workspace:FindFirstChild("GeneratedLobby")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "GeneratedLobby"
	folder.Parent = workspace
	local hiddenColor = Color3.fromRGB(50, 58, 61)

	hubSpawn = makePart(folder, "HubSpawn", Vector3.new(4, 1, 4), CFrame.new(ORIGIN + Vector3.new(0, 3, -70)), hiddenColor, Enum.Material.SmoothPlastic)
	hubSpawn.Transparency = 1
	hubSpawn.CanCollide = false
	menuHolding = makePart(folder, "MenuHolding", Vector3.new(4, 1, 4), CFrame.new(ORIGIN + Vector3.new(0, 3, -78)), hiddenColor, Enum.Material.SmoothPlastic)
	menuHolding.Transparency = 1
	menuHolding.CanCollide = false
	local camera = makePart(folder, "MenuCamera", Vector3.one, CFrame.new(ORIGIN + Vector3.new(25, 11, -80)), hiddenColor, Enum.Material.SmoothPlastic)
	camera.Transparency = 1
	camera.CanCollide = false
	camera.CFrame = CFrame.lookAt(camera.Position, ORIGIN + Vector3.new(0, 8, -46))

	local privatePositions = {
		Vector3.new(84, 2.25, -32),
		Vector3.new(84, 2.25, 18),
		Vector3.new(-84, 2.25, -32),
		Vector3.new(-84, 2.25, 18),
	}
	local privateColors = {
		Color3.fromRGB(176, 109, 188),
		Color3.fromRGB(216, 137, 69),
		Color3.fromRGB(62, 162, 205),
		Color3.fromRGB(125, 176, 107),
	}
	for index, offset in privatePositions do
		local pad = makePart(folder, "PrivateModule" .. index, Vector3.new(24, 0.35, 17), CFrame.new(ORIGIN + offset), privateColors[index], Enum.Material.Neon)
		pad.Transparency = 0.72
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Configure private match"
		prompt.ObjectText = "PRIVATE CHAMBER " .. string.format("%02d", index)
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		local queue: Queue = { id = "Private" .. index, kind = "Private", ownerUserId = nil, capacity = 4, friendsOnly = true, blindMode = "Bot", members = {}, countdown = nil, generation = 0, launching = false, label = nil }
		queue.label = addWorldLabel(pad, "PRIVATE " .. string.format("%02d", index), "EMPTY  •  ENTER")
		queues[queue.id] = queue
		prompt.Triggered:Connect(function(player) joinQueue(player, queue) end)
	end

	local publicPad = makePart(folder, "PublicQueue", Vector3.new(50, 0.35, 21), CFrame.new(ORIGIN + Vector3.new(0, 2.25, 68)), Color3.fromRGB(177, 39, 33), Enum.Material.Neon)
	publicPad.Transparency = 0.78
	local publicQueue: Queue = { id = "Public", kind = "Public", ownerUserId = nil, capacity = PUBLIC_CAPACITY, friendsOnly = false, blindMode = "Bot", members = {}, countdown = nil, generation = 0, launching = false, label = nil }
	publicQueue.label = addWorldLabel(publicPad, "PUBLIC DESCENT", "0/10  •  CROSS THE HAZARD LINE")
	queues.Public = publicQueue
	local touchDebounce: { [Player]: number } = {}
	publicPad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or (touchDebounce[player] or 0) > os.clock() then return end
		touchDebounce[player] = os.clock() + 1
		joinQueue(player, publicQueue)
	end)
end

local function enableDetailedDecorCollision()
	local detailed = workspace:FindFirstChild("LobbyDetailedDecor")
	if not detailed then return end
	local function uprightProxy(model: Model, width: number, depth: number, height: number)
		local oldProxy = model:FindFirstChild("CollisionProxy")
		if oldProxy then oldProxy:Destroy() end
		local boxCFrame, boxSize = model:GetBoundingBox()
		local proxy = Instance.new("Part")
		proxy.Name = "CollisionProxy"
		proxy.Size = Vector3.new(width,height,depth)
		proxy.CFrame = boxCFrame*CFrame.new(0,-boxSize.Y/2+height/2,0)
		proxy.Transparency = 1
		proxy.Anchored, proxy.CanCollide, proxy.CanQuery, proxy.CanTouch = true, true, true, false
		proxy.Parent = model
	end
	for _, model in detailed:GetChildren() do
		if not model:IsA("Model") then continue end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then item.CanCollide = false end
		end
		if string.match(model.Name,"^Tree_") then
			uprightProxy(model,3.2,3.2,13)
		elseif string.match(model.Name,"^Lamp_") then
			uprightProxy(model,1.2,1.2,12)
		else
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") and item.Transparency < 0.92 then
					item.CanCollide, item.CanQuery = true, true
				end
			end
		end
	end
end

local function moveCharacter(player: Player, character: Model)
	if player:GetAttribute("InMatch") == true then return end
	local root = character:WaitForChild("HumanoidRootPart", 8)
	if not root or not root:IsA("BasePart") then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = 20 end
	character:PivotTo((if player:GetAttribute("InHub") == true then hubSpawn else menuHolding).CFrame + Vector3.new(0,4,0))
	root.Anchored = player:GetAttribute("InHub") ~= true
end

local function setupPlayer(player: Player)
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	local direct = typeof(teleportData) == "table" and teleportData.DirectMatch == true
	player:SetAttribute("Role", "")
	player:SetAttribute("InHub", false)
	player:SetAttribute("InMatch", direct)
	if direct then workspace:SetAttribute("BlindOneMode", teleportData.BlindOneMode == "Player" and "Player" or "Bot") end
	player.CharacterAdded:Connect(function(character) task.defer(moveCharacter, player, character) end)
	if player.Character then task.defer(moveCharacter, player, player.Character) end
	task.delay(1, function() stateRemote:FireClient(player, stateFor(player)) end)
end

actionRemote.OnServerEvent:Connect(function(player: Player, action: string, value: any)
	local queue = playerQueue[player]
	if action == "EnterHub" and player:GetAttribute("InMatch") ~= true then
		player:SetAttribute("InHub", true)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then root.Anchored = false end
		if character then character:PivotTo(hubSpawn.CFrame + Vector3.new(0,4,0)) end
		broadcast()
	elseif action == "Leave" then
		removeFromQueue(player)
	elseif action == "Capacity" and queue and queue.kind == "Private" and queue.ownerUserId == player.UserId and typeof(value) == "number" then
		queue.capacity = math.clamp(math.floor(value), math.max(PRIVATE_CAPACITY_MIN, queueCount(queue)), PRIVATE_CAPACITY_MAX)
		broadcast()
	elseif action == "FriendsOnly" and queue and queue.kind == "Private" and queue.ownerUserId == player.UserId then
		queue.friendsOnly = value == true
		broadcast()
	elseif action == "BlindMode" and queue and (queue.kind == "Public" or queue.ownerUserId == player.UserId) then
		queue.blindMode = value == "Player" and "Player" or "Bot"
		broadcast()
	elseif action == "Start" and queue and queue.kind == "Private" and queue.ownerUserId == player.UserId then
		launch(queue)
	elseif action == "Refresh" then
		stateRemote:FireClient(player, stateFor(player))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

buildBunkerHub()
enableDetailedDecorCollision()
workspace:SetAttribute("BlindOneMode", "Bot")
for _, player in Players:GetPlayers() do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)
