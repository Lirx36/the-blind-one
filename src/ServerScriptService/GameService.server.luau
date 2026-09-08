--!strict
-- Objective flow (key -> exit), and what happens when the monster catches you.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local noiseBindable = ServerStorage:WaitForChild("Noise") :: BindableEvent

local catchBindable = Instance.new("BindableEvent")
catchBindable.Name = "CatchPlayer"
catchBindable.Parent = ServerStorage

Players.RespawnTime = Config.RespawnDelay
Players.CharacterAutoLoads = true

local START_OBJECTIVE = "Find the key. Don't let it hear you."

local caughtDebounce: { [Player]: boolean } = {}

local function setObjective(player: Player, text: string)
	Remotes.Objective:FireClient(player, text)
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("HasKey", false)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("HasKey", false)
		caughtDebounce[player] = nil
		task.wait(0.5)
		setObjective(player, START_OBJECTIVE)
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	caughtDebounce[player] = nil
end)

catchBindable.Event:Connect(function(player: Player)
	if caughtDebounce[player] then
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
	if not player or player:GetAttribute("HasKey") then
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
	if not player then
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
