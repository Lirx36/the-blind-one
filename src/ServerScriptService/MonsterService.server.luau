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

local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(3, 7, 2)
root.Color = Color3.fromRGB(18, 18, 22)
root.Material = Enum.Material.Slate
root.Transparency = 0.05
root.CanCollide = true
root.Parent = monster
monster.PrimaryPart = root

for _, side in { -1, 1 } do
	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Shape = Enum.PartType.Ball
	eye.Size = Vector3.new(0.5, 0.5, 0.5)
	eye.Color = Color3.fromRGB(220, 235, 255)
	eye.Material = Enum.Material.Neon
	eye.CanCollide = false
	eye.Massless = true
	eye.Parent = monster
	eye.CFrame = root.CFrame * CFrame.new(side * 0.7, 2.6, -1.05)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = eye
	weld.Parent = eye
end

local humanoid = Instance.new("Humanoid")
humanoid.Name = "Humanoid"
humanoid.HipHeight = 3.6
humanoid.WalkSpeed = Config.MonsterWanderSpeed
humanoid.AutoRotate = true
humanoid.BreakJointsOnDeath = false
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
	root.CFrame = CFrame.new(start + Vector3.new(0, 4, 0))
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
		humanoid.WalkSpeed = (state == "hunt") and Config.MonsterHuntSpeed or Config.MonsterInvestigateSpeed
		return heard and heard.pos or root.Position
	end

	humanoid.WalkSpeed = Config.MonsterWanderSpeed
	if not wanderGoal or (root.Position - wanderGoal).Magnitude < 8 then
		wanderGoal = nearestNode(root.Position)
	end
	return wanderGoal or root.Position
end

local function stepToward(goal: Vector3)
	local path = PathfindingService:CreatePath(AGENT)
	local ok = pcall(function()
		path:ComputeAsync(root.Position, goal)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local wps = path:GetWaypoints()
		local nextPoint = wps[math.min(2, #wps)]
		if nextPoint then
			humanoid:MoveTo(nextPoint.Position)
			return
		end
	end
	-- no path: shuffle straight at it, physics will slide us along walls
	humanoid:MoveTo(root.Position + (goal - root.Position).Unit * 6)
end

task.wait(1.5) -- let MapBuilder finish placing nodes
spawnMonster()

task.spawn(function()
	while true do
		if monster.Parent and humanoid.Health > 0 then
			if #patrolNodes == 0 then
				patrolNodes = gatherNodes()
			end
			pollPlayers()
			local goal = decide()
			stepToward(goal)
		end
		task.wait(Config.MonsterRepath)
	end
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
