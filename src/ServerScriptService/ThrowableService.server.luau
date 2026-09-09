--!strict
-- Rocks you can pick up (E) and throw (click). A thrown rock makes a loud noise where
-- it lands -- the core tool for pulling the monster away from you.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local noiseBindable = ServerStorage:WaitForChild("Noise") :: BindableEvent

local held: { [Player]: number } = {}

local function isInfiniteBallTester(player: Player): boolean
	-- Lirx is the project owner/tester. Studio's first simulated client stands in
	-- for that account during Server + Players tests.
	return player.Name == "Lirx"
		or player.Name == "Lirx36"
		or (game.CreatorId > 0 and player.UserId == game.CreatorId)
		or (RunService:IsStudio() and player.Name == "Player1")
end

local function setHeld(player: Player, n: number)
	held[player] = math.max(0, n)
	local shownCount = if isInfiniteBallTester(player) then -1 else held[player]
	player:SetAttribute("HeldBalls", shownCount)
	Remotes.HeldCount:FireClient(player, shownCount)
end

local function setupPlayer(player: Player)
	held[player] = 0
	player.CharacterAdded:Connect(function()
		setHeld(player, Config.StartThrowables)
	end)
	if player.Character then
		setHeld(player, Config.StartThrowables)
	end
end

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	held[player] = nil
end)

local function makeRock(pos: Vector3): BasePart
	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(1, 1, 1)
	rock.Color = Color3.fromRGB(70, 70, 78)
	rock.Material = Enum.Material.Slate
	rock.Position = pos
	rock:SetAttribute("SessionThrownBall", true)
	rock.Parent = workspace
	CollectionService:AddTag(rock, "Throwable")
	-- A missed throw should never build an endless pile during a long test server.
	Debris:AddItem(rock, 45)
	return rock
end

-- Also covers Rojo restarting this script during an active Studio server.
for _, oldRock in CollectionService:GetTagged("Throwable") do
	if oldRock:GetAttribute("SessionThrownBall") == true then
		oldRock:Destroy()
	end
end

Remotes.Pickup.OnServerEvent:Connect(function(player, rock)
	if player:GetAttribute("Role") == "BlindOne" then
		return
	end
	if typeof(rock) ~= "Instance" or not rock:IsA("BasePart") or not rock:HasTag("Throwable") then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - rock.Position).Magnitude > 12 then
		return
	end
	rock:Destroy()
	if isInfiniteBallTester(player) then
		setHeld(player, held[player] or Config.StartThrowables)
	else
		setHeld(player, (held[player] or 0) + 1)
	end
end)

Remotes.Throw.OnServerEvent:Connect(function(player, direction)
	if player:GetAttribute("Role") == "BlindOne" then
		return
	end
	local infinite = isInfiniteBallTester(player)
	if typeof(direction) ~= "Vector3" or (not infinite and (held[player] or 0) <= 0) then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	if infinite then
		setHeld(player, held[player] or Config.StartThrowables)
	else
		setHeld(player, (held[player] or 0) - 1)
	end

	local dir = direction.Unit
	local rock = makeRock(hrp.Position + dir * 3 + Vector3.new(0, 2, 0))
	-- The player-controlled Blind One sees this as the same anonymous human
	-- sound silhouette used for survivors, never as a visibly identifiable rock.
	rock:SetAttribute("BlindOneDecoy", true)
	rock:SetAttribute("BlindOneDecoyUntil", workspace:GetServerTimeNow() + 5)
	rock:SetNetworkOwner(nil)
	rock.AssemblyLinearVelocity = dir * 90 + Vector3.new(0, 18, 0)

	local landed = false
	local function onHit(other: BasePart)
		if landed then
			return
		end
		if other:IsDescendantOf(char) then
			return
		end
		landed = true
		rock:SetAttribute("BlindOneDecoyUntil", workspace:GetServerTimeNow() + 3.2)
		noiseBindable:Fire(rock.Position, Config.ThrowImpactNoise)
	end
	rock.Touched:Connect(onHit)
	task.delay(4, function()
		if not landed then
			landed = true
			rock:SetAttribute("BlindOneDecoyUntil", workspace:GetServerTimeNow() + 3.2)
			noiseBindable:Fire(rock.Position, Config.ThrowImpactNoise * 0.6)
		end
	end)
end)
