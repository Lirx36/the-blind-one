--!strict
-- Rocks you can pick up (E) and throw (click). A thrown rock makes a loud noise where
-- it lands -- the core tool for pulling the monster away from you.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local noiseBindable = ServerStorage:WaitForChild("Noise") :: BindableEvent

local held: { [Player]: number } = {}

local function setHeld(player: Player, n: number)
	held[player] = math.max(0, n)
	Remotes.HeldCount:FireClient(player, held[player])
end

Players.PlayerAdded:Connect(function(player)
	held[player] = 0
	player.CharacterAdded:Connect(function()
		setHeld(player, Config.StartThrowables)
	end)
end)
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
	rock.Parent = workspace
	CollectionService:AddTag(rock, "Throwable")
	return rock
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
		noiseBindable:Fire(rock.Position, Config.ThrowImpactNoise)
	end
	rock.Touched:Connect(onHit)
	task.delay(4, function()
		if not landed then
			landed = true
			noiseBindable:Fire(rock.Position, Config.ThrowImpactNoise * 0.6)
		end
	end)
end)
