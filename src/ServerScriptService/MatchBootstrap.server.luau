--!strict
-- The gameplay place has no menu or matchmaking. Players arriving from the
-- lobby immediately enter the labyrinth using the queue's chosen monster mode.
local Players = game:GetService("Players")

local DEFAULT_MODE = "Bot"
workspace:SetAttribute("BlindOneMode", DEFAULT_MODE)

local function chosenMode(player: Player): string
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	if typeof(teleportData) == "table" and teleportData.BlindOneMode == "Player" then
		return "Player"
	end
	return "Bot"
end

local function placeInMatch(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 8)
	if not root or not root:IsA("BasePart") then return end
	root.Anchored = false
	local map = workspace:WaitForChild("GeneratedMap")
	local spawn = map:WaitForChild("Spawn")
	if spawn:IsA("BasePart") then
		character:PivotTo(spawn.CFrame + Vector3.new(math.random(-5, 5), 4, math.random(-5, 5)))
	end
end

local function setupPlayer(player: Player)
	workspace:SetAttribute("BlindOneMode", chosenMode(player))
	player:SetAttribute("InHub", false)
	player:SetAttribute("InMatch", true)
	if player:GetAttribute("Role") == nil then player:SetAttribute("Role", "") end
	player.CharacterAdded:Connect(function(character) task.defer(placeInMatch, player, character) end)
	if player.Character then task.defer(placeInMatch, player, player.Character) end
end

for _, player in Players:GetPlayers() do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)
