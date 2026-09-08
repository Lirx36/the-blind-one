--!strict
-- The Blind One. It cannot see. It builds a picture of the world from noise events
-- (footsteps, thrown rocks, doors) and the continuous noise meter of nearby players.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local noiseBindable = ServerStorage:WaitForChild("Noise") :: BindableEvent
local catchBindable = ServerStorage:WaitForChild("CatchPlayer") :: BindableEvent

local AGENT = {
	AgentRadius = 3,
	AgentHeight = 7,
	AgentCanJump = false,
}

------------------------------------------------------------------- build the body
local monster = Instance.new("Model")
monster.Name = "TheBlindOne"

local ROOT_Y = 3.9 -- centre height so the figure's feet sit near the floor (floor top = 0)

local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(2.4, 7, 1.6)
root.Transparency = 1 -- invisible; the figure below is cosmetic
root.CanCollide = false
root.Anchored = true -- moved directly by CFrame, no ragdoll physics / replication stutter
root.Parent = monster
monster.PrimaryPart = root

local DARK = Color3.fromRGB(13, 13, 17)

local function limb(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Anchored = true -- whole model is moved rigidly with monster:PivotTo()
	p.CastShadow = true
	p.Parent = monster
	p.CFrame = root.CFrame * offset
end

-- tall, gaunt, slightly hunched silhouette
limb("Torso", Vector3.new(1.9, 3.4, 1.0), CFrame.new(0, 0.7, 0) * CFrame.Angles(math.rad(12), 0, 0), DARK, Enum.Material.Slate)
limb("Head", Vector3.new(1.05, 1.3, 1.05), CFrame.new(0, 2.8, -0.35), DARK, Enum.Material.Slate)
limb("ArmL", Vector3.new(0.5, 3.7, 0.5), CFrame.new(-1.25, -0.1, 0.1) * CFrame.Angles(math.rad(6), 0, math.rad(6)), DARK, Enum.Material.Slate)
limb("ArmR", Vector3.new(0.5, 3.7, 0.5), CFrame.new(1.25, -0.1, 0.1) * CFrame.Angles(math.rad(6), 0, math.rad(-6)), DARK, Enum.Material.Slate)
limb("LegL", Vector3.new(0.6, 3.2, 0.6), CFrame.new(-0.5, -2.9, 0), DARK, Enum.Material.Slate)
limb("LegR", Vector3.new(0.6, 3.2, 0.6), CFrame.new(0.5, -2.9, 0), DARK, Enum.Material.Slate)
limb("EyeL", Vector3.new(0.26, 0.14, 0.14), CFrame.new(-0.26, 2.9, -0.9), Color3.fromRGB(225, 240, 255), Enum.Material.Neon)
limb("EyeR", Vector3.new(0.26, 0.14, 0.14), CFrame.new(0.26, 2.9, -0.9), Color3.fromRGB(225, 240, 255), Enum.Material.Neon)

local humanoid = Instance.new("Humanoid")
humanoid.Name = "Humanoid"
humanoid.WalkSpeed = 0 -- movement is done by CFrame; the Humanoid is just for Health/death
humanoid.AutoRotate = false
humanoid.BreakJointsOnDeath = false
humanoid.EvaluateStateMachine = false
humanoid.Parent = monster

------------------------------------------------------------------- patrol points
local function gatherNodes(): { Vector3 }
	local nodes: { Vector3 } = {}
	for _, inst in CollectionService:GetTagged("PatrolNode") do
		if inst:IsA("BasePart") then
			table.insert(nodes, inst.Position)
		end
	end
	return nodes
end

------------------------------------------------------------------- start / spawn
local patrolNodes: { Vector3 } = {}

local function spawnMonster()
	patrolNodes = gatherNodes()
	-- start as far as possible from the player spawn so nobody dies on frame one
	local spawnPart = workspace:FindFirstChild("GeneratedMap")
		and (workspace.GeneratedMap :: Instance):FindFirstChild("Spawn") :: BasePart?
	local origin = spawnPart and spawnPart.Position or Vector3.zero
	local start = Vector3.new(0, 6, 0)
	local bestD = -1
	for _, node in patrolNodes do
		local d = (node - origin).Magnitude
		if d > bestD then
			bestD, start = d, node
		end
	end
	monster.Parent = workspace
	monster:PivotTo(CFrame.new(Vector3.new(start.X, ROOT_Y, start.Z)))
end

------------------------------------------------------------------- hearing model
type Heard = { pos: Vector3, strength: number, at: number, player: Player? }
local heard: Heard? = nil

local function registerNoise(pos: Vector3, loudness: number, player: Player?)
	if not monster.Parent then
		return
	end
	local dist = (pos - root.Position).Magnitude
	local strength = loudness - dist / Config.NoiseCarry
	if strength < Config.MonsterHearingFloor then
		return
	end
	-- the freshest sufficiently-strong sound wins; a much louder one always wins
	if not heard or strength >= heard.strength - 4 or os.clock() - heard.at > 1.5 then
		heard = { pos = pos, strength = strength, at = os.clock(), player = player }
	end
end

noiseBindable.Event:Connect(function(pos: Vector3, loudness: number)
	registerNoise(pos, loudness, nil)
end)

------------------------------------------------------------------- main AI loop
local state = "wander" -- "wander" | "investigate" | "hunt"
local wanderGoal: Vector3? = nil
local lastHuntHeard = 0
local targetSpeed = Config.MonsterWanderSpeed
local currentSpeed = Config.MonsterWanderSpeed

local function nearestNode(from: Vector3): Vector3
	if #patrolNodes == 0 then
		return from
	end
	local pick = patrolNodes[math.random(#patrolNodes)]
	-- bias slightly toward a random-but-not-current node so it roams
	if wanderGoal and (pick - wanderGoal).Magnitude < 6 and #patrolNodes > 1 then
		pick = patrolNodes[math.random(#patrolNodes)]
	end
	return pick
end

local function pollPlayers()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local meter = player:GetAttribute("Noise")
			if typeof(meter) == "number" and meter > 0 then
				registerNoise(hrp.Position, meter, player)
			end
			-- it can always feel something right next to it
			if (hrp.Position - root.Position).Magnitude < Config.MonsterCatchDistance + 3 then
				registerNoise(hrp.Position, 60, player)
			end
		end
	end
end

local function decide()
	local now = os.clock()
	if heard then
		local age = now - heard.at
		local distToHeard = (heard.pos - root.Position).Magnitude
		local escalate = heard.player ~= nil
			and heard.strength > Config.MonsterHuntNoise
			and distToHeard < Config.MonsterHuntRange
		if escalate then
			state = "hunt"
			lastHuntHeard = now
		elseif state == "hunt" and now - lastHuntHeard > Config.MonsterHuntGrace then
			state = "investigate"
		elseif state ~= "hunt" then
			state = "investigate"
		end
		if state ~= "hunt" and age > Config.MonsterInvestigateTime then
			heard = nil
			state = "wander"
		end
	elseif state ~= "wander" then
		state = "wander"
	end

	if state == "hunt" or state == "investigate" then
		targetSpeed = (state == "hunt") and Config.MonsterHuntSpeed or Config.MonsterInvestigateSpeed
		return heard and heard.pos or root.Position
	end

	targetSpeed = Config.MonsterWanderSpeed
	if not wanderGoal or (root.Position - wanderGoal).Magnitude < 8 then
		wanderGoal = nearestNode(root.Position)
	end
	return wanderGoal or root.Position
end

------------------------------------------------------------------- locomotion
local waypoints: { PathWaypoint } = {}
local wpIndex = 1
local lastCompute = 0
local currentGoal = Vector3.zero
local pathObj = PathfindingService:CreatePath(AGENT)

local function recompute(goal: Vector3)
	lastCompute = os.clock()
	currentGoal = goal
	local ok = pcall(function()
		pathObj:ComputeAsync(root.Position, goal)
	end)
	if ok and pathObj.Status == Enum.PathStatus.Success then
		waypoints = pathObj:GetWaypoints()
		wpIndex = 2 -- waypoint 1 is our own position
	else
		waypoints = {}
	end
end

task.wait(1.5) -- let MapBuilder finish placing nodes
spawnMonster()

-- decision loop: choose a goal, refresh the path only when it's stale
task.spawn(function()
	while true do
		if monster.Parent and humanoid.Health > 0 then
			if #patrolNodes == 0 then
				patrolNodes = gatherNodes()
			end
			pollPlayers()
			local goal = decide()
			local maxAge = (state == "hunt") and 0.4 or 0.9
			local moved = (goal - currentGoal).Magnitude > 6
			if moved or os.clock() - lastCompute > maxAge or #waypoints == 0 or wpIndex > #waypoints then
				recompute(goal)
			end
		end
		task.wait(0.15)
	end
end)

-- mover: glide the anchored root along the path by CFrame every frame
RunService.Heartbeat:Connect(function(dt)
	if not monster.Parent or humanoid.Health <= 0 then
		return
	end
	local wp = waypoints[wpIndex]
	if not wp then
		return
	end

	currentSpeed += (targetSpeed - currentSpeed) * math.clamp(dt * 4, 0, 1)

	local target = Vector3.new(wp.Position.X, ROOT_Y, wp.Position.Z)
	local toTarget = target - root.Position
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)

	if flat.Magnitude < 2.5 then
		wpIndex += 1
		return
	end

	local dir = flat.Unit
	local newPos = root.Position + dir * math.min(currentSpeed * dt, flat.Magnitude)
	local goalRot = CFrame.lookAt(Vector3.zero, dir).Rotation
	local easedRot = root.CFrame.Rotation:Lerp(goalRot, math.clamp(dt * 6, 0, 1))
	monster:PivotTo(CFrame.new(newPos) * easedRot)
end)

-- catch check + dread broadcast
RunService.Heartbeat:Connect(function()
	if not monster.Parent then
		return
	end
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - root.Position).Magnitude
			if d < Config.MonsterCatchDistance then
				catchBindable:Fire(player)
			end
			local dread = math.clamp(1 - d / 45, 0, 1)
			Remotes.Dread:FireClient(player, dread)
		end
	end
end)
