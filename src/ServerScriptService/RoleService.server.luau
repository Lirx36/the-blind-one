--!strict
-- Solo servers use the AI. With two or more players, one player is selected as
-- The Blind One and the remaining players stay survivors.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local JumpPolicy = require(ReplicatedStorage:WaitForChild("JumpPolicy"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local MonsterAppearance = require(script.Parent:WaitForChild("MonsterAppearance"))

local rng = Random.new()
local ORIGINAL_ANIMATE_ENABLED = "BlindOneOriginalAnimateEnabled"
local selectedHumanHunterId: number? = nil

local function chosenFromTeleport(players: { Player }): Player?
	for _, member in players do
		local data = member:GetJoinData().TeleportData
		local chosenId = if typeof(data) == "table" then data.BlindOneUserId else nil
		if typeof(chosenId) == "number" then
			for _, candidate in players do
				if candidate.UserId == chosenId then return candidate end
			end
		end
	end
	return nil
end

local function farMonsterSpawn(): Vector3?
	local generatedMap = workspace:FindFirstChild("GeneratedMap")
	local spawnPart = generatedMap and generatedMap:FindFirstChild("Spawn")
	local origin = if spawnPart and spawnPart:IsA("BasePart") then spawnPart.Position else Vector3.zero
	local best: Vector3? = nil
	local bestDistance = -1
	for _, node in CollectionService:GetTagged("PatrolNode") do
		if node:IsA("BasePart") then
			local distance = (node.Position - origin).Magnitude
			if distance > bestDistance then
				bestDistance = distance
				best = node.Position
			end
		end
	end
	return best
end

local function moveMonsterToFarSpawn(player: Player, character: Model)
	for _ = 1, 30 do
		if player.Character ~= character or player:GetAttribute("Role") ~= "BlindOne" then
			return
		end
		local position = farMonsterSpawn()
		if position then
			character:PivotTo(CFrame.new(position + Vector3.new(0, 3.5, 0)))
			return
		end
		task.wait(0.2)
	end
end

local function clearMonsterVisual(character: Model)
	MonsterAppearance.Clear(character)
end

local function addMonsterVisual(character: Model)
	MonsterAppearance.Apply(character)
end

local function styleCharacter(player: Player, character: Model, moveToMonsterSpawn: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animate = character:FindFirstChild("Animate")
	if humanoid then
		JumpPolicy.Apply(humanoid, true)
	end
	if player:GetAttribute("Role") == "BlindOne" then
		if animate and animate:IsA("LocalScript") then
			if animate:GetAttribute(ORIGINAL_ANIMATE_ENABLED) == nil then
				animate:SetAttribute(ORIGINAL_ANIMATE_ENABLED, animate.Enabled)
			end
			-- The monster has its own procedural limp. Leaving Roblox's stock walk
			-- active makes the two gaits fight and the normal walk wins remotely.
			animate.Enabled = false
		end
		addMonsterVisual(character)
		if humanoid then
			humanoid.WalkSpeed = Config.PlayerBlindOneSpeed
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		if moveToMonsterSpawn then
			task.spawn(moveMonsterToFarSpawn, player, character)
		end
	else
		if animate and animate:IsA("LocalScript") then
			local originalEnabled = animate:GetAttribute(ORIGINAL_ANIMATE_ENABLED)
			if typeof(originalEnabled) == "boolean" then
				animate.Enabled = originalEnabled
				animate:SetAttribute(ORIGINAL_ANIMATE_ENABLED, nil)
			end
		end
		clearMonsterVisual(character)
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
		end
	end
end

local function setRole(player: Player, role: string)
	local changed = player:GetAttribute("Role") ~= role
	player:SetAttribute("Role", role)
	if changed then
		player:SetAttribute("HasKey", false)
	end
	local character = player.Character
	if character then
		styleCharacter(player, character, changed and role == "BlindOne")
	end
	if changed then
		if role == "" then
			return
		elseif role == "BlindOne" then
			Remotes.Objective:FireClient(player, "YOU ARE THE BLIND ONE — follow sound and catch every survivor.")
		else
			local map = workspace:FindFirstChild("GeneratedMap")
			local active = if map then map:GetAttribute("MechanismsActive") else 0
			local total = if map then map:GetAttribute("MechanismsTotal") else 5
			Remotes.Objective:FireClient(player, ("Restore the generators (%d/%d). Stay quiet."):format(
				if typeof(active) == "number" then active else 0,
				if typeof(total) == "number" then total else 5
			))
		end
	end
end

local function refreshRoles()
	local players = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMatch") == true then
			table.insert(players, player)
		else
			setRole(player, "")
		end
	end
	if #players == 0 then return end
	local playerControlled = workspace:GetAttribute("BlindOneMode") == "Player"
	-- MatchBootstrap marks party members InMatch one at a time. Wait until its
	-- arrival handoff is complete before drawing a random player from the full
	-- party; otherwise only the first two arrivals can ever be chosen.
	local expectedArrivals = workspace:GetAttribute("ArrivalExpected")
	if playerControlled and typeof(expectedArrivals) == "number" and expectedArrivals > 0
		and workspace:GetAttribute("ArrivalPhase") ~= "Complete" then
		return
	end
	if not Config.PlayerBlindOneEnabled or not playerControlled then
		for _, player in players do
			setRole(player, "Survivor")
		end
		workspace:SetAttribute("BlindOneUsername", "BOT")
		return
	end

	local chosen: Player? = nil
	if selectedHumanHunterId then
		for _, member in players do
			if member.UserId == selectedHumanHunterId then
				chosen = member
				break
			end
		end
		if not chosen then
			workspace:SetAttribute("BlindOneMode", "Bot")
			workspace:SetAttribute("BlindOneUsername", "BOT")
			workspace:SetAttribute("BlindOneBotTakeoverAt", workspace:GetServerTimeNow())
			return
		end
	elseif #players < 2 then
		for _, member in players do setRole(member, "Survivor") end
		return
	end
	if not chosen then
		chosen = chosenFromTeleport(players) or players[rng:NextInteger(1, #players)]
		selectedHumanHunterId = chosen.UserId
		print(("RoleService: picked %s (%d) as Blind One from %d loaded players"):format(chosen.Name, chosen.UserId, #players))
	end
	workspace:SetAttribute("BlindOneUsername", chosen.Name)
	for _, player in players do
		setRole(player, if player == chosen then "BlindOne" else "Survivor")
	end
end

local function setupPlayer(player: Player)
	if player:GetAttribute("Role") == nil then
		player:SetAttribute("Role", "")
	end
	player:GetAttributeChangedSignal("InMatch"):Connect(refreshRoles)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		styleCharacter(player, character, player:GetAttribute("Role") == "BlindOne")
	end)
	player.CharacterAppearanceLoaded:Connect(function(character)
		-- Catalog accessories can arrive after CharacterAdded. Reapply once Roblox
		-- finishes loading them so the personal avatar never leaks through the skin.
		if player.Character == character and player:GetAttribute("Role") == "BlindOne" then
			addMonsterVisual(character)
		end
	end)
end

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(function(player)
	setupPlayer(player)
	task.defer(refreshRoles)
end)
Players.PlayerRemoving:Connect(function(player)
	if selectedHumanHunterId == player.UserId and workspace:GetAttribute("BlindOneMode") == "Player" then
		workspace:SetAttribute("BlindOneMode", "Bot")
		workspace:SetAttribute("BlindOneUsername", "BOT")
		workspace:SetAttribute("BlindOneBotTakeoverAt", workspace:GetServerTimeNow())
	end
	task.delay(0.15, refreshRoles)
end)

task.defer(refreshRoles)
workspace:GetAttributeChangedSignal("BlindOneMode"):Connect(refreshRoles)
workspace:GetAttributeChangedSignal("ArrivalPhase"):Connect(refreshRoles)
