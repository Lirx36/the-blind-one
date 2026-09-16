--!strict
local Responsive = require(game:GetService("ReplicatedStorage"):WaitForChild("ResponsiveUI"))
-- Cross-place destination sequence: wait for the complete party, watch their
-- elevator reach the labyrinth floor, reveal the real avatars, then fade in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Chime = require(ReplicatedStorage:WaitForChild("ElevatorChime"))
local player = Players.LocalPlayer
local teleportData = TeleportService:GetLocalPlayerTeleportData()
local isArrival = (typeof(teleportData) == "table" and teleportData.DirectMatch == true)
	or player:GetAttribute("ArrivalActive") == true

if not isArrival then return end

local DESCEND_TIME = 3.25
local CABIN_START_HEIGHT = 32
local STAGE_ORIGIN = Vector3.new(0, 2500, 0)

local ACCENTS = {
	Private1 = Color3.fromRGB(211, 107, 190),
	Private2 = Color3.fromRGB(229, 152, 76),
	Private3 = Color3.fromRGB(72, 210, 224),
	Private4 = Color3.fromRGB(128, 212, 112),
	Public = Color3.fromRGB(225, 70, 58),
}

local queueId = if typeof(teleportData) == "table" and typeof(teleportData.ElevatorQueueId) == "string"
	then teleportData.ElevatorQueueId else (player:GetAttribute("ArrivalQueueId") or "Public")
local isPublic = queueId == "Public"
local accent = ACCENTS[queueId] or ACCENTS.Public
local openingWidth = if isPublic then 34 else 16
local cabinDepth = if isPublic then 15 else 12
local cameraDistance = if isPublic then 52 else 38

local arrivingGui = TeleportService:GetArrivingTeleportGui()
if arrivingGui then arrivingGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ArrivalCinematic"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local blackout = Instance.new("Frame")
blackout.Name = "Blackout"
blackout.Size = UDim2.fromScale(1, 1)
blackout.BackgroundColor3 = Color3.new()
blackout.BorderSizePixel = 0
blackout.ZIndex = 20
blackout.Parent = gui

local waiting = Instance.new("CanvasGroup")
waiting.Name = "PartyLoading"
waiting.AnchorPoint = Vector2.new(0.5, 0.5)
waiting.Position = UDim2.fromScale(0.5, 0.5)
waiting.Size = UDim2.fromOffset(620, 210)
waiting.BackgroundTransparency = 1
waiting.ZIndex = 21
waiting.Parent = gui

local eyebrow = Instance.new("TextLabel")
eyebrow.Size = UDim2.new(1, 0, 0, 24)
eyebrow.BackgroundTransparency = 1
eyebrow.Font = Enum.Font.GothamBold
eyebrow.Text = "SECURE DESCENT LINK  //  PARTY SYNCHRONIZATION"
eyebrow.TextColor3 = accent
eyebrow.TextSize = 12
eyebrow.TextTransparency = 0.1
eyebrow.ZIndex = 22
eyebrow.Parent = waiting

local waitingTitle = Instance.new("TextLabel")
waitingTitle.Position = UDim2.fromOffset(0, 35)
waitingTitle.Size = UDim2.new(1, 0, 0, 55)
waitingTitle.BackgroundTransparency = 1
waitingTitle.Font = Enum.Font.GothamBlack
waitingTitle.Text = "WAITING FOR PLAYERS"
waitingTitle.TextColor3 = Color3.fromRGB(226, 232, 231)
waitingTitle.TextSize = 34
waitingTitle.TextStrokeTransparency = 0.68
waitingTitle.ZIndex = 22
waitingTitle.Parent = waiting

local loadingLine = Instance.new("Frame")
loadingLine.AnchorPoint = Vector2.new(0.5, 0)
loadingLine.Position = UDim2.new(0.5, 0, 0, 101)
loadingLine.Size = UDim2.fromOffset(420, 2)
loadingLine.BackgroundColor3 = Color3.fromRGB(35, 43, 45)
loadingLine.BorderSizePixel = 0
loadingLine.ZIndex = 22
loadingLine.Parent = waiting
local loadingFill = Instance.new("Frame")
loadingFill.Size = UDim2.fromScale(0, 1)
loadingFill.BackgroundColor3 = accent
loadingFill.BorderSizePixel = 0
loadingFill.ZIndex = 23
loadingFill.Parent = loadingLine

local countLabel = Instance.new("TextLabel")
countLabel.Position = UDim2.fromOffset(0, 116)
countLabel.Size = UDim2.new(1, 0, 0, 50)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamBlack
countLabel.Text = "0 / 1"
countLabel.TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.28)
countLabel.TextSize = 30
countLabel.ZIndex = 22
countLabel.Parent = waiting

local waitingDetail = Instance.new("TextLabel")
waitingDetail.Position = UDim2.fromOffset(0, 168)
waitingDetail.Size = UDim2.new(1, 0, 0, 24)
waitingDetail.BackgroundTransparency = 1
waitingDetail.Font = Enum.Font.GothamMedium
waitingDetail.Text = "HOLDING THE LIFT UNTIL EVERY OPERATIVE IS READY"
waitingDetail.TextColor3 = Color3.fromRGB(103, 121, 124)
waitingDetail.TextSize = 11
waitingDetail.ZIndex = 22
waitingDetail.Parent = waiting

local guiStates: { [ScreenGui]: boolean } = {}
local function suspendGui(item: Instance)
	if item == gui or not item:IsA("ScreenGui") or guiStates[item] ~= nil then return end
	guiStates[item] = item.Enabled
	item.Enabled = false
end
for _, item in ipairs(player.PlayerGui:GetChildren()) do suspendGui(item) end
local guiAddedConnection = player.PlayerGui.ChildAdded:Connect(function(item) task.defer(suspendGui, item) end)
ProximityPromptService.Enabled = false
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
UserInputService.MouseIconEnabled = false

local stage = Instance.new("Model")
stage.Name = "LocalArrivalElevator"
stage.Parent = workspace
local cabin = Instance.new("Model")
cabin.Name = "DescendingCabin"
cabin.Parent = stage

local metal = Color3.fromRGB(13, 17, 19)
local darkMetal = Color3.fromRGB(5, 7, 8)
local inset = Color3.fromRGB(23, 28, 30)

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material
	object.Anchored = true
	object.CanCollide = false
	object.CanQuery = false
	object.CanTouch = false
	object.CastShadow = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

local function addGlow(object: BasePart, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = accent
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = object
end

-- The fixed floor facade and shaft stay level with the camera while the entire
-- closed car descends behind it.
makePart(stage, "ShaftVoid", Vector3.new(openingWidth + 16, 44, 2), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 11, -cabinDepth - 2.5)), Color3.new(), Enum.Material.SmoothPlastic)
makePart(stage, "LeftShaftWall", Vector3.new(5, 23, 7), CFrame.new(STAGE_ORIGIN + Vector3.new(-openingWidth / 2 - 2.5, 9, -1.5)), darkMetal, Enum.Material.DiamondPlate)
makePart(stage, "RightShaftWall", Vector3.new(5, 23, 7), CFrame.new(STAGE_ORIGIN + Vector3.new(openingWidth / 2 + 2.5, 9, -1.5)), darkMetal, Enum.Material.DiamondPlate)
makePart(stage, "HeaderBlock", Vector3.new(openingWidth + 10, 5.5, 7), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 19.25, -1.5)), metal, Enum.Material.DiamondPlate)
makePart(stage, "Threshold", Vector3.new(openingWidth + 2, 0.65, 4), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 0.1, 1)), inset, Enum.Material.Metal)
makePart(stage, "ForegroundFloor", Vector3.new(openingWidth + 30, 0.6, 26), CFrame.new(STAGE_ORIGIN + Vector3.new(0, -0.45, 11)), Color3.fromRGB(8, 11, 12), Enum.Material.DiamondPlate)

-- The moving panels travel into these opaque wall pockets. Their front faces sit
-- just ahead of the panels, hiding the entire door instead of letting it slide
-- visibly through the elevator frame.
local pocketWidth = openingWidth / 2 + 4
makePart(stage, "LeftDoorPocket", Vector3.new(pocketWidth, 17.4, 0.42), CFrame.new(STAGE_ORIGIN + Vector3.new(-openingWidth / 2 - pocketWidth / 2, 8.2, 0.72)), darkMetal, Enum.Material.DiamondPlate)
makePart(stage, "RightDoorPocket", Vector3.new(pocketWidth, 17.4, 0.42), CFrame.new(STAGE_ORIGIN + Vector3.new(openingWidth / 2 + pocketWidth / 2, 8.2, 0.72)), darkMetal, Enum.Material.DiamondPlate)

-- Enclose the local cinematic in a complete bunker transfer room. The camera
-- is inside this shell, so no sky, horizon, or empty-world void can appear at
-- the edges while the elevator is descending.
local roomWidth = openingWidth + 38
local roomNearZ = -cabinDepth - 4
local roomFarZ = cameraDistance + 11
local roomDepth = roomFarZ - roomNearZ
local roomCenterZ = (roomFarZ + roomNearZ) / 2
makePart(stage, "TransferRoomFloor", Vector3.new(roomWidth, 1, roomDepth), CFrame.new(STAGE_ORIGIN + Vector3.new(0, -0.72, roomCenterZ)), Color3.fromRGB(10, 14, 16), Enum.Material.DiamondPlate)
makePart(stage, "TransferRoomCeiling", Vector3.new(roomWidth, 1, roomDepth), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 24.5, roomCenterZ)), Color3.fromRGB(7, 10, 11), Enum.Material.Metal)
makePart(stage, "TransferRoomLeft", Vector3.new(1, 26, roomDepth), CFrame.new(STAGE_ORIGIN + Vector3.new(-roomWidth / 2, 11.8, roomCenterZ)), Color3.fromRGB(17, 22, 24), Enum.Material.Concrete)
makePart(stage, "TransferRoomRight", Vector3.new(1, 26, roomDepth), CFrame.new(STAGE_ORIGIN + Vector3.new(roomWidth / 2, 11.8, roomCenterZ)), Color3.fromRGB(17, 22, 24), Enum.Material.Concrete)
makePart(stage, "TransferRoomFront", Vector3.new(roomWidth, 26, 1), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 11.8, roomNearZ)), Color3.fromRGB(8, 11, 13), Enum.Material.DiamondPlate)
makePart(stage, "TransferRoomRear", Vector3.new(roomWidth, 26, 1), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 11.8, roomFarZ)), Color3.fromRGB(6, 8, 9), Enum.Material.DiamondPlate)
for _, side in ipairs({ -1, 1 }) do
	local floorTrack = makePart(stage, "FloorGuide", Vector3.new(0.22, 0.12, roomDepth - 3), CFrame.new(STAGE_ORIGIN + Vector3.new(side * (openingWidth / 2 + 4), -0.12, roomCenterZ)), accent, Enum.Material.Neon)
	floorTrack.Transparency = 0.48
	for z = 8, cameraDistance - 5, 14 do
		makePart(stage, "WallButtress", Vector3.new(2.2, 24, 1.1), CFrame.new(STAGE_ORIGIN + Vector3.new(side * (roomWidth / 2 - 1.1), 11.8, z)), Color3.fromRGB(25, 31, 33), Enum.Material.DiamondPlate)
	end
end
for z = 7, cameraDistance - 4, 13 do
	local lamp = makePart(stage, "TransferCeilingLight", Vector3.new(math.min(9, openingWidth / 2), 0.22, 1.1), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 23.85, z)), accent, Enum.Material.Neon)
	lamp.Transparency = 0.18
	addGlow(lamp, 0.75, 16)
end

local leftFixedGlow = makePart(stage, "LeftFloorGlow", Vector3.new(0.35, 17, 0.35), CFrame.new(STAGE_ORIGIN + Vector3.new(-openingWidth / 2 - 0.35, 8.5, 2.2)), accent, Enum.Material.Neon)
local rightFixedGlow = makePart(stage, "RightFloorGlow", Vector3.new(0.35, 17, 0.35), CFrame.new(STAGE_ORIGIN + Vector3.new(openingWidth / 2 + 0.35, 8.5, 2.2)), accent, Enum.Material.Neon)
addGlow(leftFixedGlow, 1.5, 18)
addGlow(rightFixedGlow, 1.5, 18)

local headerFace = makePart(stage, "HeaderFace", Vector3.new(openingWidth + 6, 3.8, 0.35), CFrame.new(STAGE_ORIGIN + Vector3.new(0, 19.25, 2.05)), Color3.fromRGB(4, 6, 7), Enum.Material.SmoothPlastic)
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Back
surface.CanvasSize = Vector2.new(1100, 190)
surface.LightInfluence = 0
surface.Parent = headerFace
local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, 0, 0.66, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Font = Enum.Font.GothamBlack
headerTitle.Text = if isPublic then "PUBLIC FREIGHT ELEVATOR" else "PRIVATE ELEVATOR " .. string.format("%02d", tonumber(string.match(queueId, "%d+")) or 1)
headerTitle.TextColor3 = Color3.fromRGB(224, 230, 229)
headerTitle.TextScaled = true
headerTitle.Parent = surface
local headerSub = Instance.new("TextLabel")
headerSub.Position = UDim2.fromScale(0, 0.66)
headerSub.Size = UDim2.new(1, 0, 0.25, 0)
headerSub.BackgroundTransparency = 1
headerSub.Font = Enum.Font.GothamMedium
headerSub.Text = "LABYRINTH ACCESS  //  DESCENT LEVEL"
headerSub.TextColor3 = accent:Lerp(Color3.fromRGB(192, 205, 206), 0.45)
headerSub.TextScaled = true
headerSub.Parent = surface

local startOffset = Vector3.new(0, CABIN_START_HEIGHT, 0)
local function cabinPart(name: string, size: Vector3, basePosition: Vector3, color: Color3, material: Enum.Material): Part
	local object = makePart(cabin, name, size, CFrame.new(STAGE_ORIGIN + basePosition + startOffset), color, material)
	object:SetAttribute("ArrivalTarget", object.CFrame - startOffset)
	return object
end

cabinPart("CabinBack", Vector3.new(openingWidth, 16, 0.8), Vector3.new(0, 8, -cabinDepth), inset, Enum.Material.Metal)
cabinPart("CabinFloor", Vector3.new(openingWidth, 0.8, cabinDepth), Vector3.new(0, 0.35, -cabinDepth / 2), Color3.fromRGB(25, 29, 30), Enum.Material.DiamondPlate)
cabinPart("CabinCeiling", Vector3.new(openingWidth, 0.8, cabinDepth), Vector3.new(0, 16, -cabinDepth / 2), Color3.fromRGB(12, 15, 16), Enum.Material.Metal)
cabinPart("CabinLeft", Vector3.new(0.8, 16, cabinDepth), Vector3.new(-openingWidth / 2, 8, -cabinDepth / 2), metal, Enum.Material.Metal)
cabinPart("CabinRight", Vector3.new(0.8, 16, cabinDepth), Vector3.new(openingWidth / 2, 8, -cabinDepth / 2), metal, Enum.Material.Metal)
local ceilingLight = cabinPart("CabinLight", Vector3.new(math.min(openingWidth - 4, 12), 0.25, 1), Vector3.new(0, 15.45, -cabinDepth / 2), accent, Enum.Material.Neon)
addGlow(ceilingLight, 2.3, 24)
for y = 3.2, 12.8, 3.2 do
	cabinPart("RearWallBrace", Vector3.new(openingWidth - 2.2, 0.22, 0.22), Vector3.new(0, y, -cabinDepth + 0.48), Color3.fromRGB(82, 94, 96), Enum.Material.Metal)
end
local rearGlow = cabinPart("RearWallGlow", Vector3.new(math.min(openingWidth - 4, 13), 0.22, 0.2), Vector3.new(0, 13.9, -cabinDepth + 0.42), accent, Enum.Material.Neon)
addGlow(rearGlow, 0.9, 13)

-- Keep the handrail on the rear wall only. The old second rail sat between the
-- camera and the avatars, creating the bright line through their heads.
cabinPart("SafetyRail", Vector3.new(openingWidth - 3, 0.28, 0.28), Vector3.new(0, 4.25, -cabinDepth + 0.6), Color3.fromRGB(74, 84, 87), Enum.Material.Metal)

local leftDoor = cabinPart("LeftDoor", Vector3.new(openingWidth / 2, 15.3, 0.75), Vector3.new(-openingWidth / 4, 7.8, 0), Color3.fromRGB(18, 23, 25), Enum.Material.Metal)
local rightDoor = cabinPart("RightDoor", Vector3.new(openingWidth / 2, 15.3, 0.75), Vector3.new(openingWidth / 4, 7.8, 0), Color3.fromRGB(18, 23, 25), Enum.Material.Metal)
leftDoor:SetAttribute("OpenOffset", -openingWidth / 2)
rightDoor:SetAttribute("OpenOffset", openingWidth / 2)
for _, x in { -openingWidth / 2 + 0.35, openingWidth / 2 - 0.35 } do
	local edge = cabinPart("DoorEdgeGlow", Vector3.new(0.28, 14.6, 0.22), Vector3.new(x, 7.8, 0.48), accent, Enum.Material.Neon)
	addGlow(edge, 0.8, 10)
end
for y = 3.5, 12.5, 3 do
	cabinPart("DoorBraceLeft", Vector3.new(openingWidth / 2 - 1.3, 0.16, 0.18), Vector3.new(-openingWidth / 4, y, 0.48), Color3.fromRGB(77, 91, 94), Enum.Material.Metal)
	cabinPart("DoorBraceRight", Vector3.new(openingWidth / 2 - 1.3, 0.16, 0.18), Vector3.new(openingWidth / 4, y, 0.48), Color3.fromRGB(77, 91, 94), Enum.Material.Metal)
end

local function stripClone(clone: Model)
	-- AnimationTracks are runtime state, so deleting only the Animate script is
	-- not enough: a copied falling track can keep writing to the clone's joints.
	-- Stop and remove every Animator before applying the neutral pose.
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("Animator") then
			for _, track in ipairs(item:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
			item:Destroy()
		end
	end
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		elseif item:IsA("Humanoid") then
			item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			item.AutoRotate = false
		elseif item:IsA("Motor6D") then
			-- With the Animator gone, this reset remains stable for the reveal.
			item.Transform = CFrame.identity
		end
	end
end

local function placeAvatarOnCabinFloor(clone: Model, x: number, z: number)
	clone:PivotTo(CFrame.new(STAGE_ORIGIN + Vector3.new(x, 3.2, z) + startOffset) * CFrame.Angles(0, math.pi, 0))
	local lowestFootY = math.huge
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("BasePart") and (item.Name == "LeftFoot" or item.Name == "RightFoot" or item.Name == "Left Leg" or item.Name == "Right Leg") then
			lowestFootY = math.min(lowestFootY, item.Position.Y - item.Size.Y / 2)
		end
	end
	local floorTopY = STAGE_ORIGIN.Y + startOffset.Y + 0.77
	if lowestFootY < math.huge then
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, floorTopY - lowestFootY, 0))
	else
		local root = clone:FindFirstChild("HumanoidRootPart")
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid then
			local targetRootY = floorTopY + humanoid.HipHeight + root.Size.Y / 2
			clone:PivotTo(clone:GetPivot() + Vector3.new(0, targetRootY - root.Position.Y, 0))
		end
	end
end

local avatarsBuilt = false
local function buildPartyAvatars()
	if avatarsBuilt then return end
	avatarsBuilt = true
	local party = Players:GetPlayers()
	table.sort(party, function(a, b) return a.UserId < b.UserId end)
	local columns = if isPublic then 5 else math.min(4, math.max(1, #party))
	local spacing = if isPublic then 5.5 else 4.6
	for index, member in ipairs(party) do
		local character = member.Character
		if not character then continue end
		local oldArchivable = character.Archivable
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = oldArchivable
		clone.Name = "ArrivalAvatar_" .. member.Name
		stripClone(clone)
		clone.Parent = cabin
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local x = (column - (math.min(columns, #party) - 1) / 2) * spacing
		local z = -3.4 - row * 4.6
		placeAvatarOnCabinFloor(clone, x, z)
		for _, item in ipairs(clone:GetDescendants()) do
			if item:IsA("BasePart") then item:SetAttribute("ArrivalTarget", item.CFrame - startOffset) end
		end
		local head = clone:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local tag = Instance.new("BillboardGui")
			tag.Name = "OperativeTag"
			tag.Size = UDim2.fromOffset(180, 28)
			tag.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
			tag.AlwaysOnTop = false
			tag.Parent = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.Text = string.upper(member.DisplayName)
			label.TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.4)
			label.TextSize = 13
			label.TextStrokeTransparency = 0.2
			label.Parent = tag
		end
	end
end

local cameraTarget = CFrame.lookAt(STAGE_ORIGIN + Vector3.new(0, 9.5, cameraDistance), STAGE_ORIGIN + Vector3.new(0, 8.7, -1.5))
RunService:BindToRenderStep("ArrivalCinematicCamera", Enum.RenderPriority.Camera.Value + 100, function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 54
	camera.CFrame = cameraTarget
end)

local function updateCount()
	local loaded = tonumber(workspace:GetAttribute("ArrivalLoaded")) or 0
	local expected = math.max(1, tonumber(workspace:GetAttribute("ArrivalExpected")) or (if typeof(teleportData) == "table" then tonumber(teleportData.ExpectedPlayers) else nil) or 1)
	countLabel.Text = string.format("%d / %d", loaded, expected)
	TweenService:Create(loadingFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(math.clamp(loaded / math.max(expected, 1), 0, 1), 1),
	}):Play()
	waitingDetail.Text = if loaded >= expected
		then "PARTY LINK COMPLETE  //  ELEVATOR INBOUND"
		else "HOLDING THE LIFT UNTIL EVERY OPERATIVE IS READY"
end
workspace:GetAttributeChangedSignal("ArrivalLoaded"):Connect(updateCount)
workspace:GetAttributeChangedSignal("ArrivalExpected"):Connect(updateCount)
updateCount()

local descendingHandled = false
local revealHandled = false
local fadeHandled = false
local completeHandled = false

local function descendCabin()
	if descendingHandled then return end
	descendingHandled = true
	buildPartyAvatars()
	TweenService:Create(waiting, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 }):Play()
	TweenService:Create(blackout, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	for _, item in ipairs(cabin:GetDescendants()) do
		if not item:IsA("BasePart") then continue end
		local target = item:GetAttribute("ArrivalTarget")
		if typeof(target) == "CFrame" then
			TweenService:Create(item, TweenInfo.new(DESCEND_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { CFrame = target }):Play()
		end
	end
end

local function revealParty()
	if revealHandled then return end
	revealHandled = true
	Chime.Play(game:GetService("SoundService"), true)
	buildPartyAvatars()
	for _, item in ipairs(cabin:GetDescendants()) do
		if item:IsA("BasePart") then
			local target = item:GetAttribute("ArrivalTarget")
			if typeof(target) == "CFrame" then item.CFrame = target end
		end
	end
	for _, door in { leftDoor, rightDoor } do
		local offset = door:GetAttribute("OpenOffset")
		if typeof(offset) == "number" then
			TweenService:Create(door, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				CFrame = door.CFrame * CFrame.new(offset, 0, 0),
			}):Play()
		end
	end
	for _, item in ipairs(cabin:GetChildren()) do
		if item:IsA("BasePart") and (item.Name == "DoorEdgeGlow" or string.find(item.Name, "DoorBrace")) then
			local direction = if item.Position.X < STAGE_ORIGIN.X then -1 else 1
			TweenService:Create(item, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				CFrame = item.CFrame * CFrame.new(direction * openingWidth / 2, 0, 0),
			}):Play()
		end
	end
end

local function fadeToLabyrinth()
	if fadeHandled then return end
	fadeHandled = true
	blackout.BackgroundTransparency = 1
	TweenService:Create(blackout, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
end

local function finishArrival()
	if completeHandled then return end
	completeHandled = true
	blackout.BackgroundTransparency = 0
	RunService:UnbindFromRenderStep("ArrivalCinematicCamera")
	stage:Destroy()
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		if humanoid then camera.CameraSubject = humanoid end
	end
	task.wait(0.2)
	TweenService:Create(blackout, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.wait(1.2)
	guiAddedConnection:Disconnect()
	for screenGui, wasEnabled in guiStates do
		if screenGui.Parent then screenGui.Enabled = wasEnabled end
	end
	ProximityPromptService.Enabled = true
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
	if player:GetAttribute("InMatch") == true then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	gui:Destroy()
end

local function handlePhase()
	local phase = workspace:GetAttribute("ArrivalPhase")
	if phase == "Descending" then task.spawn(descendCabin)
	elseif phase == "Reveal" then task.spawn(revealParty)
	elseif phase == "Fade" then task.spawn(fadeToLabyrinth)
	elseif phase == "Complete" then task.spawn(finishArrival) end
end
workspace:GetAttributeChangedSignal("ArrivalPhase"):Connect(handlePhase)
handlePhase()

local readyRemote = ReplicatedStorage:WaitForChild("ArrivalReady", 20)
if readyRemote and readyRemote:IsA("RemoteEvent") then readyRemote:FireServer() end

Responsive.Watch(gui, function(size)
 Responsive.Scale(waiting).Scale = math.min(1, (size.X-24)/620, (size.Y-24)/210)
end)
