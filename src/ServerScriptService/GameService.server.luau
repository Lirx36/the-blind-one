--!strict
-- Objective flow (key -> exit), and what happens when the monster catches you.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local noiseBindable = ServerStorage:WaitForChild("Noise") :: BindableEvent

-- Keep one catch bus across Rojo hot reloads and discard duplicate buses left by
-- older script runs.
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
	if child.Name == "CatchPlayer" and child ~= catchBindable then
		child:Destroy()
	end
end
local catchEvent = catchBindable :: BindableEvent

Players.RespawnTime = Config.RespawnDelay
Players.CharacterAutoLoads = true

local START_OBJECTIVE = "Find the key. Don't let it hear you."

local caughtDebounce: { [Player]: boolean } = {}

local function setObjective(player: Player, text: string)
	Remotes.Objective:FireClient(player, text)
end

local function removeOrphanedCharacters(player: Player, currentCharacter: Model)
	for _, child in workspace:GetChildren() do
		if child:IsA("Model")
			and child ~= currentCharacter
			and child.Name == player.Name
			and child:FindFirstChildOfClass("Humanoid") then
			child:Destroy()
		end
	end
end

local function onCharacter(player: Player, char: Model)
	player:SetAttribute("HasKey", false)
	caughtDebounce[player] = nil
	removeOrphanedCharacters(player, char)
	local ff = char:FindFirstChildOfClass("ForceField")
	if ff then
		ff:Destroy()
	end
	task.wait(0.5)
	if player:GetAttribute("Role") == "BlindOne" then
		setObjective(player, "YOU ARE THE BLIND ONE — follow sound and catch every survivor.")
	else
		setObjective(player, START_OBJECTIVE)
	end
end

local function setupPlayer(player: Player)
	player:SetAttribute("HasKey", false)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	local currentCharacter = player.Character
	if currentCharacter then
		task.spawn(onCharacter, player, currentCharacter)
	end
end

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	caughtDebounce[player] = nil
end)

catchEvent.Event:Connect(function(player: Player, caughtByHuman: boolean?)
	if caughtDebounce[player] then
		return
	end
	if player:GetAttribute("Role") == "BlindOne" then
		return
	end
	if Config.StudioSafeMode and RunService:IsStudio() and not caughtByHuman then
		-- Keep the AI active for movement/hearing tests without repeatedly killing
		-- the tester. This branch can never run in a published Roblox server.
		caughtDebounce[player] = true
		task.delay(1, function()
			caughtDebounce[player] = nil
		end)
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	caughtDebounce[player] = true
	Remotes.Jumpscare:FireClient(player)
	task.wait(0.15)
	hum.Health = 0
end)

------------------------------------------------------------------- key & exit
local function onKeyTouched(hit: BasePart, key: BasePart)
	local char = hit:FindFirstAncestorOfClass("Model")
	local player = char and Players:GetPlayerFromCharacter(char)
	if not player or player:GetAttribute("Role") == "BlindOne" or player:GetAttribute("HasKey") then
		return
	end
	player:SetAttribute("HasKey", true)
	noiseBindable:Fire(key.Position, 30) -- the key clinks
	key:Destroy()
	setObjective(player, "You have the key. Get to the exit.")
end

local function onExitTouched(hit: BasePart)
	local char = hit:FindFirstAncestorOfClass("Model")
	local player = char and Players:GetPlayerFromCharacter(char)
	if not player or player:GetAttribute("Role") == "BlindOne" then
		return
	end
	if not player:GetAttribute("HasKey") then
		setObjective(player, "The exit is locked. Find the key first.")
		return
	end
	player:SetAttribute("HasKey", false)
	setObjective(player, "YOU ESCAPED.")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		task.wait(2.5)
		hum.Health = 0 -- quick reset back to start for another run
	end
end

for _, key in CollectionService:GetTagged("KeyPickup") do
	if key:IsA("BasePart") then
		key.Touched:Connect(function(hit)
			onKeyTouched(hit, key)
		end)
	end
end
CollectionService:GetInstanceAddedSignal("KeyPickup"):Connect(function(key)
	if key:IsA("BasePart") then
		key.Touched:Connect(function(hit)
			onKeyTouched(hit, key :: BasePart)
		end)
	end
end)

for _, door in CollectionService:GetTagged("ExitDoor") do
	if door:IsA("BasePart") then
		door.Touched:Connect(onExitTouched)
	end
end
CollectionService:GetInstanceAddedSignal("ExitDoor"):Connect(function(door)
	if door:IsA("BasePart") then
		door.Touched:Connect(onExitTouched)
	end
end)
