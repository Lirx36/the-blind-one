--!strict
-- Coordinates the cross-place elevator arrival. A teleported party stays out of
-- the live match until every avatar and every arrival client reports ready.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_MODE = "Bot"
local HOLD_ORIGIN = Vector3.new(0, 3500, 0)
local ARRIVAL_TIMEOUT = 50
local DESCEND_TIME = 3.25
local REVEAL_TIME = 2.35
local FADE_TIME = 1.05

local readyRemote = ReplicatedStorage:FindFirstChild("ArrivalReady")
if readyRemote and not readyRemote:IsA("RemoteEvent") then readyRemote:Destroy() readyRemote = nil end
if not readyRemote then
	readyRemote = Instance.new("RemoteEvent")
	readyRemote.Name = "ArrivalReady"
	readyRemote.Parent = ReplicatedStorage
end
local arrivalReady = readyRemote :: RemoteEvent

workspace:SetAttribute("BlindOneMode", DEFAULT_MODE)
workspace:SetAttribute("ArrivalPhase", "None")
workspace:SetAttribute("ArrivalExpected", 0)
workspace:SetAttribute("ArrivalLoaded", 0)
workspace:SetAttribute("ArrivalQueueId", "")
workspace:SetAttribute("ArrivalPhaseStartedAt", 0)

local directParty: { [Player]: boolean } = {}
local characterReady: { [Player]: boolean } = {}
local clientReady: { [Player]: boolean } = {}
local expectedPlayers = 0
local transitionActive = false
local transitionStarted = false
local transitionFinished = false
local queueId = "Public"
local beginArrivalIfReady: () -> ()

local function teleportDataFor(player: Player): any
	local joinData = player:GetJoinData()
	local data = joinData.TeleportData
	return if typeof(data) == "table" then data else nil
end

local function matchSpawn(): BasePart?
	local deadline = os.clock() + 30
	repeat
		local map = workspace:FindFirstChild("GeneratedMap")
		if map and map:GetAttribute("MapVersion") == "HollowLabyrinth_4_RandomGenerators"
			and map:GetAttribute("Ready") == true then
			local spawn = map:FindFirstChild("Spawn")
			if spawn and spawn:IsA("BasePart") then return spawn end
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

local function setPhase(phase: string)
	workspace:SetAttribute("ArrivalPhaseStartedAt", workspace:GetServerTimeNow())
	workspace:SetAttribute("ArrivalPhase", phase)
end

local function combinedReadyCount(): number
	local count = 0
	for player in directParty do
		if player.Parent == Players and characterReady[player] and clientReady[player] then count += 1 end
	end
	return count
end

local function directPlayerCount(): number
	local count = 0
	for player in directParty do if player.Parent == Players then count += 1 end end
	return count
end

local function holdCharacter(player: Player, character: Model)
	if transitionFinished then return end
	local root = character:WaitForChild("HumanoidRootPart", 12)
	if not root or not root:IsA("BasePart") then return end
	local index = 0
	for member in directParty do
		index += 1
		if member == player then break end
	end
	character:PivotTo(CFrame.new(HOLD_ORIGIN + Vector3.new((index - 1) * 7, 0, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	character:SetAttribute("ArrivalHeld", true)

	local function markCharacterReady()
		if player.Character ~= character or player.Parent ~= Players then return end
		characterReady[player] = true
		task.defer(beginArrivalIfReady)
	end
	local ok, alreadyLoaded = pcall(function() return player:HasAppearanceLoaded() end)
	if ok and alreadyLoaded then
		markCharacterReady()
	else
		local connection: RBXScriptConnection?
		connection = player.CharacterAppearanceLoaded:Connect(function(loadedCharacter)
			if loadedCharacter ~= character then return end
			if connection then connection:Disconnect() end
			markCharacterReady()
		end)
		task.delay(12, function()
			if connection then connection:Disconnect() end
			markCharacterReady()
		end)
	end
end

local function placeInMatch(player: Player, character: Model, index: number)
	local root = character:WaitForChild("HumanoidRootPart", 8)
	if not root or not root:IsA("BasePart") then return end
	local spawn = matchSpawn()
	if spawn then
		local column = ((index - 1) % 4) - 1.5
		local row = math.floor((index - 1) / 4)
		character:PivotTo(spawn.CFrame * CFrame.new(column * 4.5, 4, row * 4.5))
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = false
	character:SetAttribute("ArrivalHeld", false)
end

beginArrivalIfReady = function()
	if not transitionActive or transitionStarted then return end
	local loaded = combinedReadyCount()
	workspace:SetAttribute("ArrivalLoaded", loaded)
	if expectedPlayers <= 0 or loaded < expectedPlayers then return end
	transitionStarted = true
	task.spawn(function()
		task.wait(0.35)
		setPhase("Descending")
		task.wait(DESCEND_TIME)
		setPhase("Reveal")
		task.wait(REVEAL_TIME)
		setPhase("Fade")
		task.wait(FADE_TIME)

		transitionFinished = true
		local ordered = {}
		for member in directParty do if member.Parent == Players then table.insert(ordered, member) end end
		table.sort(ordered, function(a, b) return a.UserId < b.UserId end)
		for index, member in ipairs(ordered) do
			if member.Character then placeInMatch(member, member.Character, index) end
		end
		for _, member in ipairs(ordered) do
			member:SetAttribute("InHub", false)
			member:SetAttribute("InMatch", true)
			member:SetAttribute("ArrivalActive", false)
		end
		setPhase("Complete")
	end)
end

local function setupDirectPlayer(player: Player, data: any)
	directParty[player] = true
	transitionActive = true
	queueId = if typeof(data.ElevatorQueueId) == "string" then data.ElevatorQueueId else queueId
	expectedPlayers = math.max(expectedPlayers, math.max(1, tonumber(data.ExpectedPlayers) or 1))
	workspace:SetAttribute("BlindOneMode", if data.BlindOneMode == "Player" then "Player" else "Bot")
	workspace:SetAttribute("ArrivalQueueId", queueId)
	workspace:SetAttribute("ArrivalExpected", expectedPlayers)
	if workspace:GetAttribute("ArrivalPhase") == "None" then setPhase("Waiting") end

	player:SetAttribute("Role", "")
	player:SetAttribute("InHub", false)
	player:SetAttribute("InMatch", false)
	player:SetAttribute("ArrivalActive", true)
	player:SetAttribute("ArrivalQueueId", queueId)
	player.CharacterAdded:Connect(function(character)
		characterReady[player] = false
		task.defer(holdCharacter, player, character)
	end)
	if player.Character then task.defer(holdCharacter, player, player.Character) end
	task.defer(beginArrivalIfReady)
end

local function setupManualPlayer(player: Player)
	player:SetAttribute("Role", "")
	player:SetAttribute("InHub", false)
	player:SetAttribute("InMatch", true)
	player:SetAttribute("ArrivalActive", false)
	player.CharacterAdded:Connect(function(character) task.defer(placeInMatch, player, character, 1) end)
	if player.Character then task.defer(placeInMatch, player, player.Character, 1) end
end

local function setupPlayer(player: Player)
	local data = teleportDataFor(player)
	if data and data.DirectMatch == true then setupDirectPlayer(player, data) else setupManualPlayer(player) end
end

arrivalReady.OnServerEvent:Connect(function(player)
	if not directParty[player] or transitionFinished then return end
	clientReady[player] = true
	beginArrivalIfReady()
end)

Players.PlayerRemoving:Connect(function(player)
	if not directParty[player] then return end
	directParty[player] = nil
	characterReady[player] = nil
	clientReady[player] = nil
	if not transitionStarted then
		expectedPlayers = math.max(1, math.min(expectedPlayers, directPlayerCount()))
		workspace:SetAttribute("ArrivalExpected", expectedPlayers)
		beginArrivalIfReady()
	end
end)

for _, player in Players:GetPlayers() do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)

task.delay(ARRIVAL_TIMEOUT, function()
	if not transitionActive or transitionStarted then return end
	-- A failed cross-place transfer must not strand the players who did arrive.
	expectedPlayers = math.max(1, directPlayerCount())
	for member in directParty do
		clientReady[member] = true
		local root = member.Character and member.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then characterReady[member] = true end
	end
	workspace:SetAttribute("ArrivalExpected", expectedPlayers)
	beginArrivalIfReady()
end)
