--!strict
-- Rocks you can pick up (E) and throw (click). A thrown rock makes a loud noise where
-- it lands -- the core tool for pulling the monster away from you.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local noiseBindable = ServerStorage:WaitForChild("Noise") :: BindableEvent

local held: { [Player]: number } = {}

local function setHeld(player: Player, n: number)
	held[player] = math.clamp(n, 0, Config.MaxThrowables)
	player:SetAttribute("HeldBalls", held[player])
	Remotes.HeldCount:FireClient(player, held[player])
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
	rock.Size = Vector3.new(0.92, 0.92, 0.92)
	rock.Color = Color3.fromRGB(58, 55, 49)
	rock.Material = Enum.Material.Rock
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

Remotes.Pickup.OnServerEvent:Connect(function(player, rock, cameraOrigin, cameraLook)
	if player:GetAttribute("Role") == "BlindOne" then
		return
	end
	if typeof(rock) ~= "Instance" or not rock:IsA("BasePart") or not rock:HasTag("Throwable") then
		return
	end
	if (held[player] or 0) >= Config.MaxThrowables then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not hrp or not head or typeof(cameraOrigin) ~= "Vector3" or typeof(cameraLook) ~= "Vector3" then
		return
	end
	local toRock = rock.Position - cameraOrigin
	if (hrp.Position - rock.Position).Magnitude > 12 or (cameraOrigin - head.Position).Magnitude > 6 or toRock.Magnitude < 0.1 then
		return
	end
	if cameraLook.Magnitude < 0.9 or cameraLook.Unit:Dot(toRock.Unit) < 0.975 then
		return
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { char }
	rayParams.IgnoreWater = true
	local hit = workspace:Raycast(cameraOrigin, toRock, rayParams)
	if not hit or hit.Instance ~= rock then
		return
	end
	rock:Destroy()
	setHeld(player, (held[player] or 0) + 1)
end)

Remotes.Throw.OnServerEvent:Connect(function(player, direction)
	if player:GetAttribute("Role") == "BlindOne" then
		return
	end
	if typeof(direction) ~= "Vector3" or (held[player] or 0) <= 0 then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	setHeld(player, (held[player] or 0) - 1)

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
