--!strict
-- Survivor objective flow for The Hollow:
-- restore five noisy generators, crank open the labyrinth gate, then escape.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LOBBY_PLACE_ID = 80010173580795

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local function waitForCurrentMap(): Folder
	while true do
		local candidate = workspace:FindFirstChild("GeneratedMap")
		if candidate and candidate:IsA("Folder")
			and candidate:GetAttribute("MapVersion") == "HollowLabyrinth_4_RandomGenerators"
			and candidate:GetAttribute("Ready") == true then
			return candidate
		end
		task.wait(0.1)
	end
end
local generatedMap = waitForCurrentMap()
local noiseBindable = ServerStorage:WaitForChild("Noise") :: BindableEvent

local catchBindable = ServerStorage:FindFirstChild("CatchPlayer") :: BindableEvent?
if catchBindable and not catchBindable:IsA("BindableEvent") then
	catchBindable:Destroy()
	catchBindable = nil
end
if not catchBindable then
	catchBindable = Instance.new("BindableEvent")
	catchBindable.Name = "CatchPlayer"
	catchBindable.Parent = ServerStorage
end
for _, child in ServerStorage:GetChildren() do
	if child.Name == "CatchPlayer" and child ~= catchBindable then child:Destroy() end
end
local catchEvent = catchBindable :: BindableEvent

Players.RespawnTime = Config.RespawnDelay
-- Death is handled by the casualty terminal. Roblox's automatic respawn would
-- bypass the three-return limit and tear the spectator camera away from its target.
Players.CharacterAutoLoads = false

local caughtDebounce: { [Player]: boolean } = {}
local respawnRequests: { [Player]: boolean } = {}
local connectedMechanisms: { [Instance]: boolean } = {}
local connectedCranks: { [Instance]: boolean } = {}
local connectedEscapeZones: { [Instance]: boolean } = {}
local crankHolds: { [Player]: boolean } = {}
local gateOpening = false
local GENERATOR_LOCKOUT_SECONDS = 90

type RepairSession = { station: Instance, token: string, startedAt: number }
local repairSessions: { [Player]: RepairSession } = {}
local stationRepairers: { [Instance]: Player } = {}

local function clearRepair(player: Player): RepairSession?
	local session = repairSessions[player]
	if not session then return nil end
	repairSessions[player] = nil
	local station = session.station
	if stationRepairers[station] == player then
		stationRepairers[station] = nil
	end
	if station.Parent and (station:GetAttribute("RepairingUserId") or 0) == player.UserId then
		station:SetAttribute("RepairingUserId", 0)
		local prompt = station:FindFirstChild("RestorePrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") and station:GetAttribute("Activated") ~= true then
			local lockedUntil = tonumber(station:GetAttribute("LockedUntil")) or 0
			prompt.Enabled = lockedUntil <= workspace:GetServerTimeNow() and stationRepairers[station] == nil
		end
	end
	return session
end

local function setLockoutVisual(station: Instance, remaining: number)
	local billboard = station:FindFirstChild("LockoutBillboard", true)
	if not billboard or not billboard:IsA("BillboardGui") then return end
	billboard.Enabled = remaining > 0
	local label = billboard:FindFirstChild("Status")
	if label and label:IsA("TextLabel") and remaining > 0 then
		local seconds = math.max(0, math.ceil(remaining))
		label.Text = ("SYSTEM LOCKED  //  %02d:%02d"):format(math.floor(seconds / 60), seconds % 60)
	end
end

local function startGeneratorLockout(station: Instance, lockedUntil: number)
	station:SetAttribute("LockedUntil", lockedUntil)
	local prompt = station:FindFirstChild("RestorePrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then prompt.Enabled = false end
	task.spawn(function()
		while station.Parent and station:GetAttribute("Activated") ~= true
			and station:GetAttribute("LockedUntil") == lockedUntil do
			local remaining = lockedUntil - workspace:GetServerTimeNow()
			if remaining <= 0 then break end
			setLockoutVisual(station, remaining)
			task.wait(1)
		end
		if not station.Parent or station:GetAttribute("LockedUntil") ~= lockedUntil then return end
		station:SetAttribute("LockedUntil", 0)
		setLockoutVisual(station, 0)
		if station:GetAttribute("Activated") ~= true and stationRepairers[station] == nil then
			local currentPrompt = station:FindFirstChild("RestorePrompt", true)
			if currentPrompt and currentPrompt:IsA("ProximityPrompt") then currentPrompt.Enabled = true end
		end
	end)
end

local function setObjective(player: Player, text: string)
	Remotes.Objective:FireClient(player, text)
end

local function mechanismProgress(): (number, number)
	local active = 0
	local total = 0
	for _, station in CollectionService:GetTagged("GateMechanism") do
		if station:IsDescendantOf(generatedMap) then
			total += 1
			if station:GetAttribute("Activated") == true then active += 1 end
		end
	end
	total = math.max(total, generatedMap:GetAttribute("MechanismsTotal") or 5)
	generatedMap:SetAttribute("MechanismsActive", active)
	generatedMap:SetAttribute("MechanismsTotal", total)
	return active, total
end

local function survivorObjective(): string
	local active, total = mechanismProgress()
	if generatedMap:GetAttribute("GateOpen") == true then
		return "THE GATE IS OPEN — escape the labyrinth."
	elseif active >= total then
		return "ALL GENERATORS RESTORED — crank open the perimeter gate."
	end
	return ("Restore the generators (%d/%d). Stay quiet."):format(active, total)
end

local function broadcastSurvivorObjective(text: string?)
	local message = text or survivorObjective()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Role") ~= "BlindOne" and player:GetAttribute("Escaped") ~= true then
			setObjective(player, message)
		end
	end
end

local function markPlayerNoise(player: Player, amount: number, duration: number)
	player:SetAttribute("NoiseOverrideLevel", amount)
	player:SetAttribute("NoiseOverrideUntil", os.clock() + duration)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then noiseBindable:Fire(root.Position, amount) end
end

local function removeOrphanedCharacters(player: Player, currentCharacter: Model)
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child ~= currentCharacter and child.Name == player.Name and child:FindFirstChildOfClass("Humanoid") then
			child:Destroy()
		end
	end
end

local function onCharacter(player: Player, character: Model)
	clearRepair(player)
	player:SetAttribute("AwaitingDeathChoice", false)
	player:SetAttribute("RepairMinigameActive", false)
	player:SetAttribute("Crouched", false)
	player:SetAttribute("BallEquipped", false)
	player:SetAttribute("HasKey", false)
	player:SetAttribute("Escaped", false)
	player:SetAttribute("NoiseOverrideUntil", 0)
	caughtDebounce[player] = nil
	removeOrphanedCharacters(player, character)
	local forceField = character:FindFirstChildOfClass("ForceField")
	if forceField then forceField:Destroy() end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Once(function()
			clearRepair(player)
			if player.Parent == Players and player:GetAttribute("Escaped") ~= true then
				player:SetAttribute("AwaitingDeathChoice", true)
			end
		end)
	end
	task.wait(0.5)
	if player.Character ~= character then return end
	if player:GetAttribute("Role") == "BlindOne" then
		setObjective(player, "YOU ARE THE BLIND ONE — follow sound and catch every survivor.")
	else
		setObjective(player, survivorObjective())
	end
end

local function setupPlayer(player: Player)
	if player:GetAttribute("RespawnsRemaining") == nil then
		player:SetAttribute("RespawnsRemaining", Config.MaxRespawns)
	end
	player:SetAttribute("AwaitingDeathChoice", false)
	player:SetAttribute("HasKey", false)
	player:SetAttribute("Escaped", false)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character :: Model)
	else
		task.defer(function()
			if player.Parent == Players and not player.Character then
				player:LoadCharacter()
			end
		end)
	end
end

for _, player in Players:GetPlayers() do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	caughtDebounce[player] = nil
	respawnRequests[player] = nil
	clearRepair(player)
	crankHolds[player] = nil
end)

local function placeRespawnCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	local spawn = generatedMap:FindFirstChild("Spawn")
	if not root or not root:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid")
		or not spawn or not spawn:IsA("BasePart") then return end
	character:PivotTo(spawn.CFrame * CFrame.new(0, 4, 0))
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = if player:GetAttribute("Role") == "BlindOne" then Config.PlayerBlindOneSpeed else Config.WalkSpeed
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	character:SetAttribute("ArrivalHeld", false)
end

Remotes.DeathAction.OnServerEvent:Connect(function(player: Player, action: any)
	if typeof(action) ~= "string" or player:GetAttribute("AwaitingDeathChoice") ~= true then return end
	if action == "Respawn" then
		if respawnRequests[player] then return end
		local remaining = math.max(0, tonumber(player:GetAttribute("RespawnsRemaining")) or 0)
		if remaining <= 0 then return end
		respawnRequests[player] = true
		player:SetAttribute("RespawnsRemaining", remaining - 1)
		player:SetAttribute("AwaitingDeathChoice", false)
		task.spawn(function()
			local ok = pcall(function() player:LoadCharacter() end)
			if ok and player.Parent == Players and player.Character then
				placeRespawnCharacter(player, player.Character)
			else
				if player.Parent == Players then
					player:SetAttribute("RespawnsRemaining", remaining)
					player:SetAttribute("AwaitingDeathChoice", true)
					Remotes.DeathAction:FireClient(player, "Error", "RESPAWN SIGNAL FAILED — TRY AGAIN")
				end
			end
			respawnRequests[player] = nil
		end)
	elseif action == "ReturnLobby" then
		if respawnRequests[player] then return end
		respawnRequests[player] = true
		if RunService:IsStudio() then
			respawnRequests[player] = nil
			Remotes.DeathAction:FireClient(player, "Error", "RETURN TO LOBBY REQUIRES A PUBLISHED SERVER")
			return
		end
		local ok = pcall(function()
			TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player })
		end)
		if not ok and player.Parent == Players then
			respawnRequests[player] = nil
			Remotes.DeathAction:FireClient(player, "Error", "LOBBY LINK FAILED — TRY AGAIN")
		end
	end
end)

catchEvent.Event:Connect(function(player: Player, caughtByHuman: boolean?)
	if caughtDebounce[player] or player:GetAttribute("Escaped") == true or player:GetAttribute("Role") == "BlindOne" then return end
	if Config.StudioSafeMode and RunService:IsStudio() and not caughtByHuman then
		caughtDebounce[player] = true
		task.delay(1, function() caughtDebounce[player] = nil end)
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	caughtDebounce[player] = true
	humanoid.Health = 0
end)

--------------------------------------------------------------------- mechanisms
local function stationPosition(station: Instance): Vector3
	if station:IsA("Model") then return station:GetPivot().Position end
	if station:IsA("BasePart") then return station.Position end
	return Vector3.zero
end

local function setMechanismVisual(station: Instance, activated: boolean)
	local core = station:FindFirstChild("Core", true)
	if core and core:IsA("BasePart") then
		core.Color = if activated then Color3.fromRGB(91, 207, 136) else Color3.fromRGB(145, 38, 24)
		for _, child in core:GetChildren() do
			if child:IsA("PointLight") then
				child.Color = core.Color
				child.Brightness = if activated then 0.8 else 0.35
			end
		end
	end
	local hum = station:FindFirstChild("GeneratorHum", true)
	if hum and hum:IsA("Sound") then
		hum.Volume = if activated then 0.16 else 0
		if activated and not hum.IsPlaying then hum:Play() end
		if not activated and hum.IsPlaying then hum:Stop() end
	end
end

local function refreshGatePrompt()
	local active, total = mechanismProgress()
	for _, crank in CollectionService:GetTagged("GateCrank") do
		local prompt = crank:FindFirstChild("GatePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			if generatedMap:GetAttribute("GateOpen") == true then
				prompt.Enabled = false
			elseif active >= total then
				prompt.ActionText = "Crank open the gate"
				prompt.HoldDuration = 8
			else
				prompt.ActionText = ("Gate locked (%d/%d)"):format(active, total)
				prompt.HoldDuration = 0.35
			end
		end
	end
end

local function completeMechanism(player: Player, station: Instance)
	if station:GetAttribute("Activated") == true then return end
	station:SetAttribute("Activated", true)
	station:SetAttribute("LockedUntil", 0)
	setLockoutVisual(station, 0)
	station:SetAttribute("RepairingUserId", 0)
	local prompt = station:FindFirstChild("RestorePrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then prompt.Enabled = false end
	setMechanismVisual(station, true)
	markPlayerNoise(player, 92, 1.5)
	noiseBindable:Fire(stationPosition(station), 96)
	local active, total = mechanismProgress()
	refreshGatePrompt()
	if active >= total then
		broadcastSurvivorObjective("ALL GENERATORS RESTORED — crank open the perimeter gate.")
	else
		broadcastSurvivorObjective(("Generator restored (%d/%d). Find the others."):format(active, total))
	end
end

local function beginRepair(player: Player, station: Instance, prompt: ProximityPrompt)
	if player:GetAttribute("Role") == "BlindOne" or station:GetAttribute("Activated") == true then return end
	local lockedUntil = tonumber(station:GetAttribute("LockedUntil")) or 0
	if lockedUntil > workspace:GetServerTimeNow() then
		prompt.Enabled = false
		setLockoutVisual(station, lockedUntil - workspace:GetServerTimeNow())
		return
	end
	if repairSessions[player] or stationRepairers[station] ~= nil
		or (station:GetAttribute("RepairingUserId") or 0) ~= 0 then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end
	if (root.Position - stationPosition(station)).Magnitude > 13 then return end

	local session: RepairSession = {
		station = station,
		token = HttpService:GenerateGUID(false),
		startedAt = os.clock(),
	}
	repairSessions[player] = session
	stationRepairers[station] = player
	station:SetAttribute("RepairingUserId", player.UserId)
	prompt.Enabled = false
	markPlayerNoise(player, 64, 0.9)
	Remotes.GeneratorMinigame:FireClient(player, "Begin", station, session.token)
	task.spawn(function()
		while repairSessions[player] == session and stationRepairers[station] == player
			and station.Parent and station:GetAttribute("Activated") ~= true do
			markPlayerNoise(player, 68, 0.9)
			noiseBindable:Fire(stationPosition(station), 72)
			task.wait(0.72)
		end
	end)
	task.delay(28, function()
		if repairSessions[player] == session then
			clearRepair(player)
			Remotes.GeneratorMinigame:FireClient(player, "Result", false, "CALIBRATION TIMED OUT")
		end
	end)
end

Remotes.GeneratorMinigame.OnServerEvent:Connect(function(player: Player, action: any, token: any)
	if typeof(action) ~= "string" or typeof(token) ~= "string" then return end
	local session = repairSessions[player]
	if not session or session.token ~= token then return end
	if stationRepairers[session.station] ~= player
		or (session.station:GetAttribute("RepairingUserId") or 0) ~= player.UserId then return end
	if action == "Cancel" then
		clearRepair(player)
		return
	end
	if action == "Fail" then
		local station = session.station
		clearRepair(player)
		local lockedUntil = workspace:GetServerTimeNow() + GENERATOR_LOCKOUT_SECONDS
		startGeneratorLockout(station, lockedUntil)
		Remotes.GeneratorMinigame:FireClient(player, "Locked", GENERATOR_LOCKOUT_SECONDS)
		return
	end
	if action ~= "Complete" then return end
	local station = session.station
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local valid = os.clock() - session.startedAt >= 1.2
		and station.Parent ~= nil and station:GetAttribute("Activated") ~= true
		and stationRepairers[station] == player
		and (tonumber(station:GetAttribute("LockedUntil")) or 0) <= workspace:GetServerTimeNow()
		and player:GetAttribute("Role") ~= "BlindOne"
		and root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - stationPosition(station)).Magnitude <= 14
	clearRepair(player)
	if not valid then
		Remotes.GeneratorMinigame:FireClient(player, "Result", false, "SIGNAL LOST — TRY AGAIN")
		return
	end
	completeMechanism(player, station)
	Remotes.GeneratorMinigame:FireClient(player, "Result", true, "GENERATOR ONLINE")
end)

local function connectMechanism(station: Instance)
	if connectedMechanisms[station] then return end
	connectedMechanisms[station] = true
	setMechanismVisual(station, station:GetAttribute("Activated") == true)
	local prompt = station:FindFirstChild("RestorePrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	prompt.ClickablePrompt = false
	local lockedUntil = tonumber(station:GetAttribute("LockedUntil")) or 0
	if lockedUntil > workspace:GetServerTimeNow() then startGeneratorLockout(station, lockedUntil) end
	prompt.Triggered:Connect(function(player) beginRepair(player, station, prompt) end)
end

for _, station in CollectionService:GetTagged("GateMechanism") do connectMechanism(station) end
CollectionService:GetInstanceAddedSignal("GateMechanism"):Connect(connectMechanism)

--------------------------------------------------------------------- final gate
local function openGate(player: Player, crank: Instance)
	if gateOpening or generatedMap:GetAttribute("GateOpen") == true then return end
	local active, total = mechanismProgress()
	if active < total then
		setObjective(player, ("The gate is dead. Restore every mechanism (%d/%d)."):format(active, total))
		return
	end
	gateOpening = true
	generatedMap:SetAttribute("GateOpen", true)
	markPlayerNoise(player, 100, 2.5)
	for _, door in CollectionService:GetTagged("EscapeGateDoor") do
		if door:IsA("BasePart") then
			door.CanCollide = false
			local direction = if door.Position.X < 0 then -1 else 1
			TweenService:Create(door, TweenInfo.new(2.8, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
				Position = door.Position + Vector3.new(direction * 10.5, 0, 0),
			}):Play()
		end
	end
	for pulse = 1, 6 do
		noiseBindable:Fire(stationPosition(crank), 100)
		if pulse < 6 then task.wait(0.45) end
	end
	refreshGatePrompt()
	broadcastSurvivorObjective("THE GATE IS OPEN — escape the labyrinth.")
	gateOpening = false
end

local function connectCrank(crank: Instance)
	if connectedCranks[crank] then return end
	connectedCranks[crank] = true
	local prompt = crank:FindFirstChild("GatePrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	prompt.PromptButtonHoldBegan:Connect(function(player)
		local active, total = mechanismProgress()
		if player:GetAttribute("Role") == "BlindOne" or active < total then return end
		crankHolds[player] = true
		task.spawn(function()
			while crankHolds[player] and crank.Parent and generatedMap:GetAttribute("GateOpen") ~= true do
				markPlayerNoise(player, 100, 0.9)
				noiseBindable:Fire(stationPosition(crank), 100)
				task.wait(0.55)
			end
		end)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player) crankHolds[player] = nil end)
	prompt.Triggered:Connect(function(player)
		crankHolds[player] = nil
		if player:GetAttribute("Role") == "BlindOne" then return end
		openGate(player, crank)
	end)
	refreshGatePrompt()
end

for _, crank in CollectionService:GetTagged("GateCrank") do connectCrank(crank) end
CollectionService:GetInstanceAddedSignal("GateCrank"):Connect(connectCrank)

local function connectEscapeZone(zone: Instance)
	if connectedEscapeZones[zone] or not zone:IsA("BasePart") then return end
	connectedEscapeZones[zone] = true
	zone.Touched:Connect(function(hit)
		if generatedMap:GetAttribute("GateOpen") ~= true then return end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or player:GetAttribute("Role") == "BlindOne" or player:GetAttribute("Escaped") == true then return end
		player:SetAttribute("Escaped", true)
		setObjective(player, "YOU ESCAPED THE HOLLOW.")
		broadcastSurvivorObjective()
		if not RunService:IsStudio() then
			task.delay(5, function()
				if player.Parent == Players then
					pcall(function() TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player }) end)
				end
			end)
		end
	end)
end

for _, zone in CollectionService:GetTagged("EscapeZone") do connectEscapeZone(zone) end
CollectionService:GetInstanceAddedSignal("EscapeZone"):Connect(connectEscapeZone)

task.delay(1, function()
	refreshGatePrompt()
	broadcastSurvivorObjective()
end)
