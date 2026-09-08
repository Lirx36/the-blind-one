--!strict
-- Solo servers use the AI. With two or more players, one player is selected as
-- The Blind One and the remaining players stay survivors.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local rng = Random.new()

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
	local old = character:FindFirstChild("BlindOneVisual")
	if old then
		old:Destroy()
	end
end

local function addMonsterVisual(character: Model)
	clearMonsterVisual(character)
	local marker = Instance.new("Folder")
	marker.Name = "BlindOneVisual"
	marker.Parent = character

	local aura = Instance.new("Highlight")
	aura.Name = "DarkAura"
	aura.Adornee = character
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.FillColor = Color3.fromRGB(7, 8, 11)
	aura.FillTransparency = 0.22
	aura.OutlineColor = Color3.fromRGB(185, 210, 225)
	aura.OutlineTransparency = 0.35
	aura.Parent = marker

	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	for _, x in { -0.2, 0.2 } do
		local eye = Instance.new("Part")
		eye.Name = "BlindEye"
		eye.Size = Vector3.new(0.16, 0.1, 0.08)
		eye.Color = Color3.fromRGB(220, 235, 245)
		eye.Material = Enum.Material.Neon
		eye.Massless = true
		eye.CanCollide = false
		eye.CanTouch = false
		eye.CanQuery = false
		eye.CastShadow = false
		eye.CFrame = head.CFrame * CFrame.new(x, 0.08, -(head.Size.Z / 2 + 0.045))
		eye.Parent = marker
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
	end
end

local function styleCharacter(player: Player, character: Model, moveToMonsterSpawn: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if player:GetAttribute("Role") == "BlindOne" then
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
		if role == "BlindOne" then
			Remotes.Objective:FireClient(player, "YOU ARE THE BLIND ONE — follow sound and catch every survivor.")
		else
			Remotes.Objective:FireClient(player, "Find the key. Don't let it hear you.")
		end
	end
end

local function refreshRoles()
	local players = Players:GetPlayers()
	if not Config.PlayerBlindOneEnabled or #players < 2 then
		for _, player in players do
			setRole(player, "Survivor")
		end
		return
	end

	local chosen: Player? = nil
	for _, player in players do
		if player:GetAttribute("Role") == "BlindOne" then
			chosen = player
			break
		end
	end
	if not chosen then
		chosen = players[rng:NextInteger(1, #players)]
	end
	for _, player in players do
		setRole(player, if player == chosen then "BlindOne" else "Survivor")
	end
end

local function setupPlayer(player: Player)
	if player:GetAttribute("Role") == nil then
		player:SetAttribute("Role", "Survivor")
	end
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		styleCharacter(player, character, player:GetAttribute("Role") == "BlindOne")
	end)
end

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(function(player)
	setupPlayer(player)
	task.defer(refreshRoles)
end)
Players.PlayerRemoving:Connect(function()
	task.delay(0.15, refreshRoles)
end)

task.defer(refreshRoles)
