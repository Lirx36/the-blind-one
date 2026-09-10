--!strict
-- Survivor objective flow for The Hollow:
-- restore three noisy mechanisms, crank open the town perimeter, then escape.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local generatedMap = workspace:WaitForChild("GeneratedMap")
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
Players.CharacterAutoLoads = true

local caughtDebounce: { [Player]: boolean } = {}
local connectedMechanisms: { [Instance]: boolean } = {}
local connectedCranks: { [Instance]: boolean } = {}
local connectedEscapeZones: { [Instance]: boolean } = {}
local mechanismHolds: { [Player]: boolean } = {}
local crankHolds: { [Player]: boolean } = {}
local gateOpening = false

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
	total = math.max(total, generatedMap:GetAttribute("MechanismsTotal") or 3)
	generatedMap:SetAttribute("MechanismsActive", active)
	generatedMap:SetAttribute("MechanismsTotal", total)
	return active, total
end

local function survivorObjective(): string
	local active, total = mechanismProgress()
	if generatedMap:GetAttribute("GateOpen") == true then
		return "THE GATE IS OPEN — get beyond the town perimeter."
	elseif active >= total then
		return "ALL MECHANISMS RESTORED — crank open the perimeter gate."
	end
	return ("Restore the gate mechanisms (%d/%d). Stay quiet."):format(active, total)
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
	player:SetAttribute("HasKey", false)
	player:SetAttribute("Escaped", false)
	player:SetAttribute("NoiseOverrideUntil", 0)
	caughtDebounce[player] = nil
	removeOrphanedCharacters(player, character)
	local forceField = character:FindFirstChildOfClass("ForceField")
	if forceField then forceField:Destroy() end
	task.wait(0.5)
	if player:GetAttribute("Role") == "BlindOne" then
		setObjective(player, "YOU ARE THE BLIND ONE — follow sound and catch every survivor.")
	else
		setObjective(player, survivorObjective())
	end
end

local function setupPlayer(player: Player)
	player:SetAttribute("HasKey", false)
	player:SetAttribute("Escaped", false)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	if player.Character then task.spawn(onCharacter, player, player.Character :: Model) end
end

for _, player in Players:GetPlayers() do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	caughtDebounce[player] = nil
	mechanismHolds[player] = nil
	crankHolds[player] = nil
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

local function connectMechanism(station: Instance)
	if connectedMechanisms[station] then return end
	connectedMechanisms[station] = true
	setMechanismVisual(station, station:GetAttribute("Activated") == true)
	local prompt = station:FindFirstChild("RestorePrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if player:GetAttribute("Role") == "BlindOne" or station:GetAttribute("Activated") == true then return end
		mechanismHolds[player] = true
		task.spawn(function()
			while mechanismHolds[player] and station.Parent and station:GetAttribute("Activated") ~= true do
				markPlayerNoise(player, 72, 0.85)
				noiseBindable:Fire(stationPosition(station), 72)
				task.wait(0.65)
			end
		end)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player) mechanismHolds[player] = nil end)
	prompt.Triggered:Connect(function(player)
		mechanismHolds[player] = nil
		if player:GetAttribute("Role") == "BlindOne" or station:GetAttribute("Activated") == true then return end
		station:SetAttribute("Activated", true)
		prompt.Enabled = false
		setMechanismVisual(station, true)
		markPlayerNoise(player, 92, 1.5)
		noiseBindable:Fire(stationPosition(station), 96)
		local active, total = mechanismProgress()
		refreshGatePrompt()
		if active >= total then
			broadcastSurvivorObjective("ALL MECHANISMS RESTORED — crank open the perimeter gate.")
		else
			broadcastSurvivorObjective(("Mechanism restored (%d/%d). Find the others."):format(active, total))
		end
	end)
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
	broadcastSurvivorObjective("THE GATE IS OPEN — get beyond the town perimeter.")
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
	end)
end

for _, zone in CollectionService:GetTagged("EscapeZone") do connectEscapeZone(zone) end
CollectionService:GetInstanceAddedSignal("EscapeZone"):Connect(connectEscapeZone)

task.delay(1, function()
	refreshGatePrompt()
	broadcastSurvivorObjective()
end)
