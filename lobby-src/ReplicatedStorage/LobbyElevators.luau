--!strict
-- Builds and operates the five physical lobby elevators. The same Ensure call is
-- also run once in Edit mode so the cabins remain visible while building.
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")

local Chime = require(game:GetService("ReplicatedStorage"):WaitForChild("ElevatorChime"))
local LobbyElevators = {}

LobbyElevators.DOOR_TIME = 0.8
LobbyElevators.DEPARTURE_TIME = 2.4

local ROOT_NAME = "QueueElevators"
local BUILD_VERSION = 30
local BUNKER_NAME = "BunkerLobby"

local PRIVATE = {
	{ id = "Private1", modelIndex = 3, x = 101.2, z = -32, insideSign = 1, color = Color3.fromRGB(176, 109, 188) },
	{ id = "Private2", modelIndex = 4, x = 101.2, z = 18, insideSign = 1, color = Color3.fromRGB(216, 137, 69) },
	{ id = "Private3", modelIndex = 1, x = -101.2, z = -32, insideSign = -1, color = Color3.fromRGB(62, 162, 205) },
	{ id = "Private4", modelIndex = 2, x = -101.2, z = 18, insideSign = -1, color = Color3.fromRGB(125, 176, 107) },
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material
	item.Anchored = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function marker(parent: Instance, name: string, cframe: CFrame): Part
	local item = part(parent, name, Vector3.new(1, 1, 1), cframe, Color3.new(), Enum.Material.SmoothPlastic)
	item.Transparency = 1
	item.CanCollide = false
	item.CanQuery = false
	item.CanTouch = false
	return item
end

local function segmentPrivateElevatorWall(root: Folder, bunker: Instance, wallName: string)
	local wall = bunker:FindFirstChild(wallName)
	if not wall or not wall:IsA("BasePart") then return end
	if wall:GetAttribute("ElevatorOriginalTransparency") == nil then
		wall:SetAttribute("ElevatorOriginalTransparency", wall.Transparency)
		wall:SetAttribute("ElevatorOriginalCanCollide", wall.CanCollide)
		wall:SetAttribute("ElevatorOriginalCanQuery", wall.CanQuery)
	end
	local originalTransparency = wall:GetAttribute("ElevatorOriginalTransparency") :: number
	local originalCanCollide = wall:GetAttribute("ElevatorOriginalCanCollide") :: boolean
	local originalCanQuery = wall:GetAttribute("ElevatorOriginalCanQuery") :: boolean
	-- The old wall crossed both private doorways. Preserve it as three solid
	-- sections while leaving genuine 12-stud openings at z -32 and z 18.
	for index, section in ipairs({
		{ centerZ = -64, length = 52 },
		{ centerZ = -7, length = 38 },
		{ centerZ = 57, length = 66 },
	}) do
		local replacement = wall:Clone()
		replacement.Name = wallName .. "ElevatorSection" .. index
		replacement.Size = Vector3.new(wall.Size.X, wall.Size.Y, section.length)
		replacement.CFrame = CFrame.new(wall.Position.X, wall.Position.Y, section.centerZ)
		replacement.Transparency = originalTransparency
		replacement.CanCollide = originalCanCollide
		replacement.CanQuery = originalCanQuery
		replacement.Parent = root
	end
	wall.Transparency = 1
	wall.CanCollide = false
	wall.CanQuery = false
end

local function segmentPrivateContainment(root: Folder, bunker: Instance)
	for _, collider in bunker:GetChildren() do
		if not collider:IsA("BasePart") or collider.Name ~= "ContainmentCollider" or collider.Size.Z < 100 then continue end
		if collider:GetAttribute("ElevatorOriginalCanCollide") == nil then
			collider:SetAttribute("ElevatorOriginalCanCollide", collider.CanCollide)
			collider:SetAttribute("ElevatorOriginalCanQuery", collider.CanQuery)
		end
		local originalCanCollide = collider:GetAttribute("ElevatorOriginalCanCollide") :: boolean
		local originalCanQuery = collider:GetAttribute("ElevatorOriginalCanQuery") :: boolean
		for index, section in ipairs({
			{ centerZ = -64, length = 52 },
			{ centerZ = -7, length = 38 },
			{ centerZ = 57, length = 66 },
		}) do
			local replacement = collider:Clone()
			replacement.Name = "ContainmentElevatorSection" .. index
			replacement.Size = Vector3.new(collider.Size.X, collider.Size.Y, section.length)
			replacement.CFrame = CFrame.new(collider.Position.X, collider.Position.Y, section.centerZ)
			replacement.CanCollide = originalCanCollide
			replacement.CanQuery = originalCanQuery
			replacement.Parent = root
		end
		collider.CanCollide = false
		collider.CanQuery = false
	end
end

local function segmentPublicElevatorWall(root: Folder, bunker: Instance)
	local targets = {}
	local forwardWall = bunker:FindFirstChild("ForwardWall")
	if forwardWall and forwardWall:IsA("BasePart") then table.insert(targets, forwardWall) end
	for _, item in bunker:GetChildren() do
		if item:IsA("BasePart") and item.Name == "ContainmentCollider" and item.Position.Z > 80 and item.Size.X > 100 then
			table.insert(targets, item)
		end
	end
	for _, wall in targets do
		if wall:GetAttribute("ElevatorOriginalTransparency") == nil then
			wall:SetAttribute("ElevatorOriginalTransparency", wall.Transparency)
			wall:SetAttribute("ElevatorOriginalCanCollide", wall.CanCollide)
			wall:SetAttribute("ElevatorOriginalCanQuery", wall.CanQuery)
		end
		local originalTransparency = wall:GetAttribute("ElevatorOriginalTransparency") :: number
		local originalCanCollide = wall:GetAttribute("ElevatorOriginalCanCollide") :: boolean
		local originalCanQuery = wall:GetAttribute("ElevatorOriginalCanQuery") :: boolean
		for _, side in ipairs({ -1, 1 }) do
			local replacement = wall:Clone()
			replacement.Name = (if wall.Name == "ForwardWall" then "ForwardWallPublicSection" else "ContainmentPublicSection") .. (if side < 0 then "Left" else "Right")
			replacement.Size = Vector3.new(80, wall.Size.Y, wall.Size.Z)
			replacement.CFrame = CFrame.new(side * 65, wall.Position.Y, wall.Position.Z)
			replacement.Transparency = originalTransparency
			replacement.CanCollide = originalCanCollide
			replacement.CanQuery = originalCanQuery
			replacement.Parent = root
		end
		wall.Transparency = 1
		wall.CanCollide = false
		wall.CanQuery = false
	end
end

local function mountWallPipes(bunker: Instance)
	local function worldBounds(model: Model)
		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item.Name ~= "PipeCollision" then
				minX, minY, minZ = math.min(minX, item.Position.X), math.min(minY, item.Position.Y), math.min(minZ, item.Position.Z)
				maxX, maxY, maxZ = math.max(maxX, item.Position.X), math.max(maxY, item.Position.Y), math.max(maxZ, item.Position.Z)
			end
		end
		return Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2), Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	end
	for index = 1, 4 do
		local model = bunker:FindFirstChild("WallPipes_" .. index)
		if not model or not model:IsA("Model") then continue end
		local oldProxy = model:FindFirstChild("PipeCollision")
		if oldProxy then oldProxy:Destroy() end
		local originalCenter, beforeSize = worldBounds(model)
		if beforeSize.X > beforeSize.Z * 2 then
			local transform = CFrame.new(originalCenter) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(-originalCenter)
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then item.CFrame = transform * item.CFrame end
			end
		end
		local rotatedCenter = worldBounds(model)
		local wallX = if originalCenter.X < 0 then -102.55 else 102.55
		local offset = Vector3.new(wallX - rotatedCenter.X, 0, originalCenter.Z - rotatedCenter.Z)
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then item.CFrame += offset end
		end
		model:SetAttribute("MountedToSideWall", true)
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then item.CanCollide = false end
		end
		local boxCenter, boxSize = worldBounds(model)
		local proxy = part(model, "PipeCollision", Vector3.new(2, boxSize.Y + 1, boxSize.Z + 1), CFrame.new(boxCenter), Color3.new(), Enum.Material.SmoothPlastic)
		proxy.Transparency = 1
		proxy.CanCollide = true
		proxy.CanQuery = true
		proxy.CanTouch = false
	end
end

local function registerDoor(rig: Model, doorPart: BasePart, openOffset: Vector3, collides: boolean)
	doorPart:SetAttribute("ElevatorDoor", true)
	doorPart:SetAttribute("ClosedCFrame", doorPart.CFrame)
	doorPart:SetAttribute("OpenCFrame", doorPart.CFrame + openOffset)
	doorPart:SetAttribute("DoorCollides", collides)
	doorPart:SetAttribute("ClosedTransparency", doorPart.Transparency)
	local reference = Instance.new("ObjectValue")
	reference.Name = "Door_" .. doorPart.Name
	reference.Value = doorPart
	reference.Parent = rig:WaitForChild("DoorRefs")
end

local function addCabinSign(parent: BasePart, titleText: string, accent: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CabinStatus"
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(520, 190)
	gui.LightInfluence = 0.2
	gui.Parent = parent
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.86, 0.58)
	frame.BackgroundColor3 = Color3.fromRGB(7, 10, 12)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Transparency = 0.25
	stroke.Thickness = 2
	stroke.Parent = frame
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.12)
	title.Size = UDim2.fromScale(0.9, 0.38)
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(226, 234, 233)
	title.TextScaled = true
	title.Parent = frame
	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromScale(0.05, 0.58)
	detail.Size = UDim2.fromScale(0.9, 0.2)
	detail.Font = Enum.Font.GothamMedium
	detail.Text = "STAND CLEAR  /  AWAIT DESCENT"
	detail.TextColor3 = accent
	detail.TextScaled = true
	detail.Parent = frame
end

local function addPrivateRig(root: Folder, bunker: Instance, config)
	local rig = Instance.new("Model")
	rig.Name = "QueueElevator_" .. config.id
	rig:SetAttribute("QueueId", config.id)
	rig:SetAttribute("Open", false)
	rig.Parent = root
	local refs = Instance.new("Folder")
	refs.Name = "DoorRefs"
	refs.Parent = rig

	local x = config.x
	local z = config.z
	local direction = config.insideSign
	local cabinCenterX = x + direction * 14
	local dark = Color3.fromRGB(23, 28, 30)
	local wall = Color3.fromRGB(48, 56, 59)
	local shaft = Color3.fromRGB(7, 10, 12)
	local floor = part(rig, "CabinFloor", Vector3.new(28, 0.45, 16), CFrame.new(cabinCenterX, 421.15, z), Color3.fromRGB(42, 49, 52), Enum.Material.DiamondPlate)
	floor.CanCollide = true
	part(rig, "CabinCeiling", Vector3.new(28, 0.4, 16), CFrame.new(cabinCenterX, 436.05, z), dark, Enum.Material.Metal)
	part(rig, "BackWall", Vector3.new(0.5, 14.8, 16), CFrame.new(x + direction * 27.75, 428.6, z), wall, Enum.Material.Concrete)
	part(rig, "SideWallA", Vector3.new(28, 14.8, 0.45), CFrame.new(cabinCenterX, 428.6, z - 7.75), wall, Enum.Material.Concrete)
	part(rig, "SideWallB", Vector3.new(28, 14.8, 0.45), CFrame.new(cabinCenterX, 428.6, z + 7.75), wall, Enum.Material.Concrete)
	-- A full-height stationary shaft remains after the car drops. Its shell sits
	-- just outside the cabin, so it is invisible normally and seals every void
	-- angle during the departure shot.
	local shaftBack = part(rig, "DepartureShaftBack", Vector3.new(0.7, 64, 17.2), CFrame.new(x + direction * 28.2, 410, z), shaft, Enum.Material.DiamondPlate)
	local shaftSideA = part(rig, "DepartureShaftSide", Vector3.new(29, 64, 0.7), CFrame.new(cabinCenterX, 410, z - 8.2), shaft, Enum.Material.DiamondPlate)
	local shaftSideB = part(rig, "DepartureShaftSide", Vector3.new(29, 64, 0.7), CFrame.new(cabinCenterX, 410, z + 8.2), shaft, Enum.Material.DiamondPlate)
	local shaftBottom = part(rig, "DepartureShaftBottom", Vector3.new(29, 0.7, 17.2), CFrame.new(cabinCenterX, 378.2, z), shaft, Enum.Material.Metal)
	local shaftTop = part(rig, "DepartureShaftTop", Vector3.new(29, 0.7, 17.2), CFrame.new(cabinCenterX, 441.8, z), shaft, Enum.Material.Metal)
	for _, shellPart in ipairs({ shaftBack, shaftSideA, shaftSideB, shaftBottom, shaftTop }) do shellPart.CanCollide = false end
	for _, guideZ in ipairs({ -4.6, 4.6 }) do
		local guide = part(rig, "DepartureShaftGuide", Vector3.new(0.18, 59, 0.28), CFrame.new(x + direction * 27.78, 408.8, z + guideZ), config.color:Lerp(shaft, 0.58), Enum.Material.Metal)
		guide.CanCollide = false
	end
	local jambColor = Color3.fromRGB(24, 29, 31)
	part(rig, "DoorJambTop", Vector3.new(1.6, 0.8, 11.1), CFrame.new(x - direction * 0.15, 435.1, z), jambColor, Enum.Material.DiamondPlate)
	part(rig, "DoorJambLeft", Vector3.new(1.6, 14.4, 1.05), CFrame.new(x - direction * 0.15, 428.15, z - 5.05), jambColor, Enum.Material.DiamondPlate)
	part(rig, "DoorJambRight", Vector3.new(1.6, 14.4, 1.05), CFrame.new(x - direction * 0.15, 428.15, z + 5.05), jambColor, Enum.Material.DiamondPlate)
	-- Tie the doors, existing sign and bunker ceiling into one continuous
	-- structure instead of leaving floating black strips between each layer.
	part(rig, "DoorHeaderSeal", Vector3.new(5.8, 1.5, 16), CFrame.new(x - direction * 0.9, 435.65, z), jambColor, Enum.Material.DiamondPlate)
	part(rig, "UpperHeaderBulkhead", Vector3.new(5.8, 3.5, 24), CFrame.new(x - direction * 0.9, 443.8, z), jambColor, Enum.Material.DiamondPlate)
	-- A solid backbox fills the full space from the existing sign face to the
	-- elevator shell. This prevents side angles from seeing behind the sign and
	-- out into the void.
	part(rig, "HeaderSignBackbox", Vector3.new(5.1, 6.05, 24.25), CFrame.new(x - direction * 0.35, 439.05, z), jambColor, Enum.Material.DiamondPlate)
	local headerAccent = part(rig, "HeaderUndersideAccent", Vector3.new(5.95, 0.12, 11.2), CFrame.new(x - direction * 0.93, 435.12, z), config.color, Enum.Material.Neon)
	headerAccent.CanCollide = false
	-- Real elevator doors slide behind these deep facade pockets instead of
	-- remaining visible outside the frame.
	for _, side in ipairs({ -1, 1 }) do
		part(rig, if side < 0 then "DoorPocketLeft" else "DoorPocketRight", Vector3.new(2.2, 14.8, 4.75), CFrame.new(x - direction * 1.15, 428.35, z + side * 7.05), jambColor, Enum.Material.DiamondPlate)
		local pocketEdge = part(rig, "DoorPocketEdge", Vector3.new(2.3, 13.7, 0.16), CFrame.new(x - direction * 1.18, 428.35, z + side * 4.75), config.color, Enum.Material.Neon)
		pocketEdge.CanCollide = false
	end
	part(rig, "DoorThreshold", Vector3.new(1.8, 0.32, 10.2), CFrame.new(x - direction * 0.05, 421.32, z), Color3.fromRGB(105, 113, 114), Enum.Material.Metal)
	local barrier = part(rig, "OccupantBarrier", Vector3.new(0.55, 14.1, 9.25), CFrame.new(x + direction * 1.05, 428.25, z), Color3.new(), Enum.Material.SmoothPlastic)
	barrier.Transparency = 1
	barrier.CanCollide = false
	barrier.CanQuery = false
	barrier.CanTouch = false

	-- Purpose-built two-panel bunker lift doors. The legacy model used a single
	-- concrete-looking backing slab, which never read as an elevator.
	local doorX = x - direction * 0.58
	local detailX = x - direction * 0.99
	local doorColor = Color3.fromRGB(43, 50, 53)
	local insetColor = Color3.fromRGB(25, 31, 33)
	for panelIndex, panelSign in ipairs({ -1, 1 }) do
		local panelZ = z + panelSign * 2.28
		local openOffset = Vector3.new(0, 0, panelSign * 4.75)
		local door = part(rig, if panelSign < 0 then "BunkerDoorLeft" else "BunkerDoorRight", Vector3.new(0.78, 13.75, 4.48), CFrame.new(doorX, 428.35, panelZ), doorColor, Enum.Material.DiamondPlate)
		registerDoor(rig, door, openOffset, true)
		local inset = part(rig, "DoorInset", Vector3.new(0.1, 9.25, 3.62), CFrame.new(detailX, 428.45, panelZ), insetColor, Enum.Material.Metal)
		inset.CanCollide = false
		registerDoor(rig, inset, openOffset, false)
		for ribY = 424.2, 432.6, 4.2 do
			local rib = part(rig, "DoorRib", Vector3.new(0.14, 0.2, 4.05), CFrame.new(detailX - direction * 0.03, ribY, panelZ), Color3.fromRGB(91, 102, 104), Enum.Material.Metal)
			rib.CanCollide = false
			registerDoor(rig, rib, openOffset, false)
		end
		local seamStrip = part(rig, "DoorSafetyEdge", Vector3.new(0.15, 12.9, 0.18), CFrame.new(detailX - direction * 0.04, 428.35, z + panelSign * 0.13), config.color, Enum.Material.Neon)
		seamStrip.CanCollide = false
		registerDoor(rig, seamStrip, openOffset, false)
		for _, boltY in ipairs({ 423.1, 433.55 }) do
			for _, boltOffset in ipairs({ -1.55, 1.55 }) do
				local bolt = part(rig, "DoorBolt", Vector3.new(0.25, 0.25, 0.25), CFrame.new(detailX - direction * 0.09, boltY, panelZ + boltOffset), Color3.fromRGB(144, 151, 150), Enum.Material.Metal)
				bolt.Shape = Enum.PartType.Ball
				bolt.CanCollide = false
				registerDoor(rig, bolt, openOffset, false)
			end
		end
		if panelIndex == 1 then
			local stencil = Instance.new("SurfaceGui")
			stencil.Name = "LiftStencil"
			stencil.Face = if direction > 0 then Enum.NormalId.Left else Enum.NormalId.Right
			stencil.CanvasSize = Vector2.new(220, 520)
			stencil.LightInfluence = 0.15
			stencil.Parent = door
			local liftText = Instance.new("TextLabel")
			liftText.BackgroundTransparency = 1
			liftText.Position = UDim2.fromScale(0.08, 0.7)
			liftText.Size = UDim2.fromScale(0.84, 0.18)
			liftText.Font = Enum.Font.RobotoMono
			liftText.Text = "LIFT " .. config.id:sub(-1) .. "\nAUTHORIZED DESCENT"
			liftText.TextColor3 = Color3.fromRGB(168, 181, 180)
			liftText.TextScaled = true
			liftText.TextTransparency = 0.2
			liftText.Parent = stencil
		end
	end
	local backX = x + direction * 27.45
	-- Broad horizontal rear panels make the far wall read as the inside of a
	-- bunker cabin, never as another pair of elevator doors.
	for panelIndex, panelY in ipairs({ 423.25, 426.55, 429.85, 433.15 }) do
		local panelColor = if panelIndex % 2 == 0 then Color3.fromRGB(55, 64, 67) else Color3.fromRGB(40, 48, 51)
		local rearPanel = part(rig, "BackWallPanel", Vector3.new(0.18, 2.95, 14.7), CFrame.new(backX + direction * 0.08, panelY, z), panelColor, Enum.Material.DiamondPlate)
		rearPanel.CanCollide = false
		rearPanel.CastShadow = false
	end
	for _, braceY in ipairs({ 425.1, 429.2, 433.3 }) do
		local brace = part(rig, "BackWallBrace", Vector3.new(0.14, 0.32, 13.2), CFrame.new(backX, braceY, z), Color3.fromRGB(105, 116, 117), Enum.Material.Metal)
		brace.CanCollide = false
	end
	local backWallLight = part(rig, "BackWallLight", Vector3.new(0.16, 0.38, 8.8), CFrame.new(backX - direction * 0.03, 434.55, z), config.color, Enum.Material.Neon)
	backWallLight.CanCollide = false
	local handrail = part(rig, "Handrail", Vector3.new(0.32, 0.28, 13.2), CFrame.new(x + direction * 27.25, 425.35, z), Color3.fromRGB(116, 125, 126), Enum.Material.Metal)
	handrail.CanCollide = false

	for ribIndex = -2, 2 do
		local rib = part(rig, "FloorGuide", Vector3.new(26, 0.05, 0.08), CFrame.new(cabinCenterX, 421.4, z + ribIndex * 2.45), config.color, Enum.Material.Neon)
		rib.Transparency = 0.48
		rib.CanCollide = false
	end
	local lamp = part(rig, "CabinLight", Vector3.new(5.2, 0.12, 1.25), CFrame.new(cabinCenterX, 435.78, z), config.color, Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = config.color
	light.Brightness = 2.8
	light.Range = 18
	light.Shadows = false
	light.Parent = lamp
	local occupantLamp = part(rig, "OccupantLight", Vector3.new(2.8, 0.1, 2.8), CFrame.new(x + direction * 5.8, 435.72, z), config.color, Enum.Material.Neon)
	occupantLamp.Transparency = 0.18
	occupantLamp.CanCollide = false
	local occupantLight = Instance.new("PointLight")
	occupantLight.Color = config.color
	occupantLight.Brightness = 3.2
	occupantLight.Range = 14
	occupantLight.Shadows = false
	occupantLight.Parent = occupantLamp

	local statusPanel = part(rig, "StatusPanel", Vector3.new(0.12, 4.8, 8.2), CFrame.new(x + direction * 27.45, 430, z), dark, Enum.Material.SmoothPlastic)
	statusPanel.CanCollide = false
	-- This panel is already a Y/Z wall plane. Rotating it 90 degrees made the
	-- wide display render edge-on as a glowing vertical seam, which looked like
	-- a second closed elevator door behind the animated doors.
	addCabinSign(statusPanel, string.upper(config.id:gsub("Private", "PRIVATE ")), config.color, if direction > 0 then Enum.NormalId.Left else Enum.NormalId.Right)

	local entrancePosition = Vector3.new(x + direction * 5.2, 424.25, z)
	local exitPosition = Vector3.new(x - direction * 10.5, 424.6, z)
	marker(rig, "EntryPoint", CFrame.lookAt(entrancePosition, Vector3.new(x, entrancePosition.Y, z)))
	marker(rig, "ExitPoint", CFrame.lookAt(exitPosition, Vector3.new(x, exitPosition.Y, z)))
	local cameraPosition = Vector3.new(x - direction * 32, 430.5, z)
	marker(rig, "CameraPoint", CFrame.lookAt(cameraPosition, Vector3.new(x + direction * 5.7, 429.3, z)))
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = rig
	local slotIndex = 0
	local privateSlotOffsets = { 0, -2.7, 2.7 }
	for row = 0, 1 do
		for _, columnOffset in ipairs(privateSlotOffsets) do
			slotIndex += 1
			local slotPosition = Vector3.new(x + direction * (5.8 + row * 5), 424.25, z + columnOffset)
			marker(slots, string.format("Slot%02d", slotIndex), CFrame.lookAt(slotPosition, Vector3.new(x, slotPosition.Y, z)))
		end
	end

	local sourceModel = bunker:FindFirstChild("PrivateElevator_" .. config.modelIndex)
	local facadeBacking = bunker:FindFirstChild("PrivateElevatorFrame_" .. config.modelIndex)
	if facadeBacking and facadeBacking:IsA("BasePart") then
		facadeBacking.Transparency = 1
		facadeBacking.CanCollide = false
		facadeBacking.CanQuery = false
	end
	if sourceModel then
		local solidBacking = sourceModel:FindFirstChild("Frame", true)
		if solidBacking and solidBacking:IsA("BasePart") then
			solidBacking.Transparency = 1
			solidBacking.CanCollide = false
			solidBacking.CanQuery = false
		end
		for _, doorName in ipairs({ "Door1", "Door2", "Door3", "Door4" }) do
			local door = sourceModel:FindFirstChild(doorName, true)
			if door and door:IsA("BasePart") then
				door.Transparency = 1
				door.CanCollide = false
				door.CanQuery = false
			end
		end
	end
	local collider = bunker:FindFirstChild("PrivateElevatorCollider_" .. config.modelIndex)
	if collider and collider:IsA("BasePart") then
		local reference = Instance.new("ObjectValue")
		reference.Name = "Collider"
		reference.Value = collider
		reference.Parent = rig
	end
end

local function addPublicRig(root: Folder, bunker: Instance)
	local legacyFreight = bunker:FindFirstChild("PublicFreightElevator")
	if legacyFreight then
		local archived = ServerStorage:FindFirstChild("LegacyPublicFreightElevator")
		if archived then archived:Destroy() end
		legacyFreight.Name = "LegacyPublicFreightElevator"
		legacyFreight.Parent = ServerStorage
	end
	local rig = Instance.new("Model")
	rig.Name = "QueueElevator_Public"
	rig:SetAttribute("QueueId", "Public")
	rig:SetAttribute("Open", false)
	rig.Parent = root
	local refs = Instance.new("Folder")
	refs.Name = "DoorRefs"
	refs.Parent = rig
	local accent = Color3.fromRGB(177, 39, 33)
	local dark = Color3.fromRGB(24, 25, 25)
	local wall = Color3.fromRGB(42, 49, 51)
	local shaft = Color3.fromRGB(7, 10, 12)

	part(rig, "CabinFloor", Vector3.new(44, 0.5, 34), CFrame.new(0, 421.8, 100.6), Color3.fromRGB(31, 36, 39), Enum.Material.DiamondPlate)
	part(rig, "CabinCeiling", Vector3.new(44, 0.45, 34), CFrame.new(0, 440.55, 100.6), dark, Enum.Material.Metal)
	part(rig, "BackWall", Vector3.new(44, 18.5, 0.55), CFrame.new(0, 431.2, 117.35), wall, Enum.Material.Metal)
	part(rig, "SideWallA", Vector3.new(0.55, 18.5, 34), CFrame.new(-21.75, 431.2, 100.6), wall, Enum.Material.Metal)
	part(rig, "SideWallB", Vector3.new(0.55, 18.5, 34), CFrame.new(21.75, 431.2, 100.6), wall, Enum.Material.Metal)
	local shaftBack = part(rig, "DepartureShaftBack", Vector3.new(46, 66, 0.7), CFrame.new(0, 410, 117.82), shaft, Enum.Material.DiamondPlate)
	local shaftSideA = part(rig, "DepartureShaftSide", Vector3.new(0.7, 66, 35.5), CFrame.new(-22.25, 410, 100.6), shaft, Enum.Material.DiamondPlate)
	local shaftSideB = part(rig, "DepartureShaftSide", Vector3.new(0.7, 66, 35.5), CFrame.new(22.25, 410, 100.6), shaft, Enum.Material.DiamondPlate)
	local shaftBottom = part(rig, "DepartureShaftBottom", Vector3.new(46, 0.7, 35.5), CFrame.new(0, 377.3, 100.6), shaft, Enum.Material.Metal)
	local shaftTop = part(rig, "DepartureShaftTop", Vector3.new(46, 0.7, 35.5), CFrame.new(0, 442.7, 100.6), shaft, Enum.Material.Metal)
	for _, shellPart in ipairs({ shaftBack, shaftSideA, shaftSideB, shaftBottom, shaftTop }) do shellPart.CanCollide = false end
	for _, guideX in ipairs({ -15, 0, 15 }) do
		local guide = part(rig, "DepartureShaftGuide", Vector3.new(0.28, 61, 0.18), CFrame.new(guideX, 408.5, 117.43), accent:Lerp(shaft, 0.62), Enum.Material.Metal)
		guide.CanCollide = false
	end

	for x = -16, 16, 8 do
		local guide = part(rig, "FreightGuide", Vector3.new(0.12, 0.06, 30), CFrame.new(x, 422.08, 100.6), accent, Enum.Material.Neon)
		guide.Transparency = 0.52
		guide.CanCollide = false
	end
	for _, lightZ in ipairs({ 91.8, 108.8 }) do
		for x = -12, 12, 24 do
			local lamp = part(rig, "FreightLight", Vector3.new(6.8, 0.12, 1.35), CFrame.new(x, 440.28, lightZ), accent, Enum.Material.Neon)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = accent
			light.Brightness = 2.35
			light.Range = 22
			light.Shadows = false
			light.Parent = lamp
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local rail = part(rig, "FreightHandrail", Vector3.new(0.28, 0.3, 27), CFrame.new(side * 21.35, 425.4, 101.4), Color3.fromRGB(116, 125, 126), Enum.Material.Metal)
		rail.CanCollide = false
		for _, panelZ in ipairs({ 90.5, 101, 111.5 }) do
			local wallPanel = part(rig, "FreightWallPanel", Vector3.new(0.12, 10.8, 8.8), CFrame.new(side * 21.43, 431.1, panelZ), Color3.fromRGB(27, 33, 35), Enum.Material.DiamondPlate)
			wallPanel.CanCollide = false
		end
	end
	for panelIndex, panelY in ipairs({ 424.2, 428.1, 432, 435.9 }) do
		local panelColor = if panelIndex % 2 == 0 then Color3.fromRGB(49, 57, 60) else Color3.fromRGB(35, 42, 45)
		local wallPanel = part(rig, "FreightBackWallPanel", Vector3.new(40, 3.45, 0.18), CFrame.new(0, panelY, 117.12), panelColor, Enum.Material.DiamondPlate)
		wallPanel.CanCollide = false
		wallPanel.CastShadow = false
	end
	for _, braceY in ipairs({ 426.2, 431.2, 436.2 }) do
		local divider = part(rig, "FreightBackWallBrace", Vector3.new(38, 0.2, 0.15), CFrame.new(0, braceY, 117.02), Color3.fromRGB(16, 20, 22), Enum.Material.Metal)
		divider.CanCollide = false
	end
	local panel = part(rig, "StatusPanel", Vector3.new(18, 5.2, 0.12), CFrame.new(0, 432.7, 117.02), dark, Enum.Material.SmoothPlastic)
	panel.CanCollide = false
	addCabinSign(panel, "PUBLIC DESCENT", accent)

	local publicBarrier = part(rig, "OccupantBarrier", Vector3.new(43.5, 14.8, 0.55), CFrame.new(0, 429.65, 83.85), Color3.new(), Enum.Material.SmoothPlastic)
	publicBarrier.Transparency = 1
	publicBarrier.CanCollide = false
	publicBarrier.CanQuery = false
	publicBarrier.CanTouch = false
	part(rig, "FreightHeaderSeal", Vector3.new(50, 1.4, 4.2), CFrame.new(0, 437.2, 84.4), dark, Enum.Material.DiamondPlate)
	part(rig, "FreightHeaderSignBackbox", Vector3.new(52, 5.3, 5.1), CFrame.new(0, 439.55, 84.85), dark, Enum.Material.DiamondPlate)
	local freightHeaderAccent = part(rig, "FreightHeaderAccent", Vector3.new(43.6, 0.14, 4.3), CFrame.new(0, 436.72, 84.32), accent, Enum.Material.Neon)
	freightHeaderAccent.CanCollide = false
	local doorLeft = part(rig, "PublicDoorLeft", Vector3.new(21.65, 14.4, 0.75), CFrame.new(-10.9, 429.6, 82.9), Color3.fromRGB(44, 48, 51), Enum.Material.DiamondPlate)
	local doorRight = part(rig, "PublicDoorRight", Vector3.new(21.65, 14.4, 0.75), CFrame.new(10.9, 429.6, 82.9), Color3.fromRGB(44, 48, 51), Enum.Material.DiamondPlate)
	registerDoor(rig, doorLeft, Vector3.new(-21.8, 0, 0), true)
	registerDoor(rig, doorRight, Vector3.new(21.8, 0, 0), true)
	-- Full-width front wall pockets conceal the freight panels once open.
	for _, side in ipairs({ -1, 1 }) do
		part(rig, if side < 0 then "FreightDoorPocketLeft" else "FreightDoorPocketRight", Vector3.new(22.1, 14.8, 2.2), CFrame.new(side * 32.8, 429.4, 82.05), dark, Enum.Material.DiamondPlate)
		local pocketEdge = part(rig, "FreightPocketEdge", Vector3.new(0.38, 13.6, 2.28), CFrame.new(side * 21.8, 429.4, 82.02), accent, Enum.Material.Neon)
		pocketEdge.CanCollide = false
	end
	for _, x in ipairs({ -10.9, 10.9 }) do
		local side = if x < 0 then -1 else 1
		for y = 424, 434.5, 3.5 do
			local rib = part(rig, "DoorRib", Vector3.new(19.6, 0.12, 0.86), CFrame.new(x, y, 82.48), Color3.fromRGB(91, 99, 101), Enum.Material.Metal)
			rib.CanCollide = false
			registerDoor(rig, rib, Vector3.new(side * 21.8, 0, 0), false)
		end
		local stripe = part(rig, "DoorWarning", Vector3.new(0.35, 13.4, 0.88), CFrame.new(x - side * 10.15, 429.6, 82.45), accent, Enum.Material.Neon)
		stripe.CanCollide = false
		registerDoor(rig, stripe, Vector3.new(side * 21.8, 0, 0), false)
	end

	marker(rig, "EntryPoint", CFrame.lookAt(Vector3.new(0, 425, 91.2), Vector3.new(0, 425, 82.9)))
	marker(rig, "ExitPoint", CFrame.lookAt(Vector3.new(0, 425, 73.5), Vector3.new(0, 425, 82.9)))
	marker(rig, "CameraPoint", CFrame.lookAt(Vector3.new(0, 430.5, 42), Vector3.new(0, 429, 94)))
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = rig
	local slotIndex = 0
	local publicSlotOffsets = { 0, -1, 1 }
	for row = 0, 1 do
		for _, column in ipairs(publicSlotOffsets) do
			slotIndex += 1
			local slotPosition = Vector3.new(column * 6.5, 425, 89.2 + row * 6.1)
			marker(slots, string.format("Slot%02d", slotIndex), CFrame.lookAt(slotPosition, Vector3.new(slotPosition.X, slotPosition.Y, 82.9)))
		end
	end
	local collider = bunker:FindFirstChild("PublicElevatorCollider")
	if collider and collider:IsA("BasePart") then
		local reference = Instance.new("ObjectValue")
		reference.Name = "Collider"
		reference.Value = collider
		reference.Parent = rig
	end
end

local function rootFolder(): Folder?
	local bunker = workspace:FindFirstChild(BUNKER_NAME)
	if not bunker then return nil end
	local root = bunker:FindFirstChild(ROOT_NAME)
	return if root and root:IsA("Folder") then root else nil
end

local function alignPublicSlots(root: Folder)
	local rig = root:FindFirstChild("QueueElevator_Public")
	local slots = rig and rig:FindFirstChild("Slots")
	if not slots then return end
	local columns = { 0, -1, 1 }
	for index = 1, 10 do
		local slot = slots:FindFirstChild(string.format("Slot%02d", index))
		if slot and index > 6 then
			slot:Destroy()
		elseif slot and slot:IsA("BasePart") then
			local row = math.floor((index - 1) / 3)
			local column = columns[(index - 1) % 3 + 1]
			local position = Vector3.new(column * 6.5, 425, 89.2 + row * 6.1)
			slot.CFrame = CFrame.lookAt(position, Vector3.new(position.X, position.Y, 82.9))
		end
	end
end

function LobbyElevators.Ensure(): Folder?
	local bunker = workspace:FindFirstChild(BUNKER_NAME)
	if not bunker then return nil end
	local existing = bunker:FindFirstChild(ROOT_NAME)
	if existing and existing:IsA("Folder") and existing:GetAttribute("BuildVersion") == BUILD_VERSION then
		alignPublicSlots(existing)
		return existing
	end
	if existing then
		for _, item in ipairs(existing:GetDescendants()) do
			if item:IsA("ObjectValue") and item.Name:sub(1, 5) == "Door_" then
				local door = item.Value
				local closed = door and door:IsA("BasePart") and door:GetAttribute("ClosedCFrame")
				if door and door:IsA("BasePart") and typeof(closed) == "CFrame" then door.CFrame = closed end
			end
		end
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root:SetAttribute("BuildVersion", BUILD_VERSION)
	root.Parent = bunker
	segmentPrivateElevatorWall(root, bunker, "EastWall")
	segmentPrivateElevatorWall(root, bunker, "WestWall")
	segmentPrivateContainment(root, bunker)
	segmentPublicElevatorWall(root, bunker)
	mountWallPipes(bunker)
	for _, config in ipairs(PRIVATE) do addPrivateRig(root, bunker, config) end
	addPublicRig(root, bunker)
	LobbyElevators.CloseAll(true)
	return root
end

local function rigFor(queueId: string): Model?
	local root = rootFolder()
	if not root then return nil end
	local rig = root:FindFirstChild("QueueElevator_" .. queueId)
	return if rig and rig:IsA("Model") then rig else nil
end

function LobbyElevators.SetOpen(queueId: string, shouldOpen: boolean, instant: boolean?): number
	local rig = rigFor(queueId)
	if not rig then return 0 end
	local wasOpen = rig:GetAttribute("Open") == true
	rig:SetAttribute("Open", shouldOpen)
	if shouldOpen and not wasOpen and not instant then
		local emitter = rig:FindFirstChild("EntryPoint")
		if emitter and emitter:IsA("BasePart") then Chime.Play(emitter, true) end
	end
	local refs = rig:FindFirstChild("DoorRefs")
	if refs then
		for _, reference in ipairs(refs:GetChildren()) do
			if not reference:IsA("ObjectValue") then continue end
			local door = reference.Value
			if not door or not door:IsA("BasePart") then continue end
			local target = door:GetAttribute(if shouldOpen then "OpenCFrame" else "ClosedCFrame")
			if typeof(target) ~= "CFrame" then continue end
			local closedTransparency = door:GetAttribute("ClosedTransparency")
			if typeof(closedTransparency) ~= "number" then closedTransparency = 0 end
			local function setDoorGraphicsVisible(visible: boolean)
				for _, item in ipairs(door:GetDescendants()) do
					if item:IsA("SurfaceGui") or item:IsA("BillboardGui") then item.Enabled = visible end
				end
			end
			door.CanCollide = (not shouldOpen) and door:GetAttribute("DoorCollides") == true
			-- Closed panels must be visible before they slide out of their pockets.
			-- Open panels become completely concealed only after the slide finishes,
			-- matching a real elevator door disappearing inside the wall.
			if not shouldOpen then
				door.Transparency = closedTransparency
				setDoorGraphicsVisible(true)
			end
			if instant then
				door.CFrame = target
				door.Transparency = if shouldOpen then 1 else closedTransparency
				setDoorGraphicsVisible(not shouldOpen)
			else
				TweenService:Create(door, TweenInfo.new(LobbyElevators.DOOR_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), { CFrame = target }):Play()
				if shouldOpen then
					task.delay(LobbyElevators.DOOR_TIME, function()
						if door.Parent and rig.Parent and rig:GetAttribute("Open") == true then
							door.CFrame = target
							door.Transparency = 1
							setDoorGraphicsVisible(false)
						end
					end)
				end
			end
		end
	end
	local colliderReference = rig:FindFirstChild("Collider")
	if colliderReference and colliderReference:IsA("ObjectValue") then
		local collider = colliderReference.Value
		if collider and collider:IsA("BasePart") then
			collider.CanCollide = not shouldOpen
			collider.CanQuery = not shouldOpen
		end
	end
	local barrier = rig:FindFirstChild("OccupantBarrier")
	if barrier and barrier:IsA("BasePart") then barrier.CanCollide = shouldOpen end
	return if instant then 0 else LobbyElevators.DOOR_TIME
end

function LobbyElevators.CloseAll(instant: boolean?)
	for _, queueId in ipairs({ "Private1", "Private2", "Private3", "Private4", "Public" }) do
		LobbyElevators.SetOpen(queueId, false, instant)
	end
end

local STATIC_DEPARTURE_PARTS = {
	EntryPoint = true,
	ExitPoint = true,
	CameraPoint = true,
	OccupantBarrier = true,
	DoorJambTop = true,
	DoorJambLeft = true,
	DoorJambRight = true,
	DoorHeaderSeal = true,
	UpperHeaderBulkhead = true,
	HeaderSignBackbox = true,
	HeaderUndersideAccent = true,
	DoorPocketLeft = true,
	DoorPocketRight = true,
	DoorPocketEdge = true,
	DoorThreshold = true,
	FreightHeaderSeal = true,
	FreightHeaderAccent = true,
	FreightHeaderSignBackbox = true,
	FreightDoorPocketLeft = true,
	FreightDoorPocketRight = true,
	FreightPocketEdge = true,
	DepartureShaftBack = true,
	DepartureShaftSide = true,
	DepartureShaftBottom = true,
	DepartureShaftTop = true,
	DepartureShaftGuide = true,
}

function LobbyElevators.BeginDeparture(queueId: string): number
	local rig = rigFor(queueId)
	if not rig or rig:GetAttribute("Departing") == true then return 0 end
	rig:SetAttribute("Departing", true)
	-- BeginDeparture runs after the close tween completes, once per launch.
	local emitter = rig:FindFirstChild("EntryPoint")
	if emitter and emitter:IsA("BasePart") then Chime.Play(emitter, false) end
	for _, item in ipairs(rig:GetDescendants()) do
		if not item:IsA("BasePart") or STATIC_DEPARTURE_PARTS[item.Name] then continue end
		if item:GetAttribute("DepartureRestCFrame") == nil then item:SetAttribute("DepartureRestCFrame", item.CFrame) end
		TweenService:Create(item, TweenInfo.new(LobbyElevators.DEPARTURE_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			CFrame = item.CFrame - Vector3.new(0, 34, 0),
		}):Play()
	end
	return LobbyElevators.DEPARTURE_TIME
end

function LobbyElevators.ResetDeparture(queueId: string)
	local rig = rigFor(queueId)
	if not rig then return end
	for _, item in ipairs(rig:GetDescendants()) do
		if not item:IsA("BasePart") then continue end
		local rest = item:GetAttribute("DepartureRestCFrame")
		if typeof(rest) == "CFrame" then item.CFrame = rest end
	end
	rig:SetAttribute("Departing", false)
	LobbyElevators.SetOpen(queueId, false, true)
end

function LobbyElevators.MoveInside(queueId: string, character: Model, slotIndex: number?): boolean
	local rig = rigFor(queueId)
	if not rig then return false end
	local slots = rig:FindFirstChild("Slots")
	if not slots then return false end
	local slot = slots:FindFirstChild(string.format("Slot%02d", slotIndex or 1))
	if not slot or not slot:IsA("BasePart") then return false end
	character:PivotTo(slot.CFrame)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = false
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.CFrame = slot.CFrame
	end
	return true
end

function LobbyElevators.MoveOutside(queueId: string, character: Model?): boolean
	if not character then return false end
	local rig = rigFor(queueId)
	local exit = rig and rig:FindFirstChild("ExitPoint")
	if not exit or not exit:IsA("BasePart") then return false end
	character:PivotTo(exit.CFrame)
	return true
end

return LobbyElevators
