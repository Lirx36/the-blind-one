--!strict
-- Tracks every player's 0..100 noise meter and broadcasts positional "noise events"
-- that the monster listens to. Other server scripts emit spikes via the ServerStorage
-- BindableEvent "Noise" :Fire(position, loudness).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

-- Reuse one noise bus when Rojo restarts this script during a playtest.
local noiseBindable = ServerStorage:FindFirstChild("Noise") :: BindableEvent?
if noiseBindable and not noiseBindable:IsA("BindableEvent") then
	noiseBindable:Destroy()
	noiseBindable = nil
end
if not noiseBindable then
	noiseBindable = Instance.new("BindableEvent")
	noiseBindable.Name = "Noise"
	noiseBindable.Parent = ServerStorage
end
for _, child in ServerStorage:GetChildren() do
	if child.Name == "Noise" and child ~= noiseBindable then
		child:Destroy()
	end
end
local noiseEvent = noiseBindable :: BindableEvent

local NOISE_TARGET = {
	idle = Config.NoiseIdle,
	walk = Config.NoiseWalk,
	crouch = Config.NoiseCrouch,
	sprint = Config.NoiseSprint,
}

local MOVE_SPEED = {
	idle = Config.WalkSpeed,
	walk = Config.WalkSpeed,
	crouch = Config.CrouchSpeed,
	sprint = Config.SprintSpeed,
}

type State = { meter: number, move: string, lastStep: number }
local states: { [Player]: State } = {}

local function setupPlayer(player: Player)
	states[player] = { meter = 0, move = "idle", lastStep = 0 }
end
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

Remotes.SetMoveState.OnServerEvent:Connect(function(player, move)
	local st = states[player]
	if st and typeof(move) == "string" and NOISE_TARGET[move] ~= nil then
		st.move = move
	end
end)

local broadcast = 0
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for player, st in states do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			st.meter = math.max(0, st.meter - Config.NoiseSmoothing * 6 * dt)
			player:SetAttribute("Noise", st.meter)
			continue
		end
		if player:GetAttribute("Role") == "BlindOne" then
			st.meter = 0
			st.move = "idle"
			player:SetAttribute("Noise", 0)
			if hum.WalkSpeed ~= Config.PlayerBlindOneSpeed then
				hum.WalkSpeed = Config.PlayerBlindOneSpeed
			end
			continue
		end

		-- Humanoid properties are server-authoritative in newer authority modes.
		-- Mirror the client's validated movement state so WalkSpeed cannot be
		-- discarded by replication after the local controller applies it.
		local desiredSpeed = MOVE_SPEED[st.move] or Config.WalkSpeed
		if hum.WalkSpeed ~= desiredSpeed then
			hum.WalkSpeed = desiredSpeed
		end

		local vel = hrp.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local moving = speed > 1.5
		-- target noise scales with how fast you're actually going, not just the key you hold
		local speedFactor = math.clamp(speed / Config.WalkSpeed, 0, 1.3)
		local target = (NOISE_TARGET[st.move] or 0) * (moving and speedFactor or 0)
		-- Objectives such as repairing a relay or cranking the escape gate are
		-- deliberately loud even when the survivor is standing still. GameService
		-- supplies a short override so human Blind Ones also see that survivor's
		-- sound silhouette through the forest and buildings.
		local overrideUntil = player:GetAttribute("NoiseOverrideUntil")
		local overrideLevel = player:GetAttribute("NoiseOverrideLevel")
		if typeof(overrideUntil) == "number" and typeof(overrideLevel) == "number" and os.clock() < overrideUntil then
			target = math.max(target, overrideLevel)
		end

		if st.meter < target then
			st.meter = math.min(target, st.meter + Config.NoiseSmoothing * 3 * dt)
		else
			st.meter = math.max(target, st.meter - Config.NoiseSmoothing * dt)
		end
		player:SetAttribute("Noise", st.meter)

		-- positional footstep blips while moving
		if moving and st.meter > 8 then
			local interval = Config.FootstepInterval * (st.move == "sprint" and 0.6 or 1)
			if now - st.lastStep >= interval then
				st.lastStep = now
				noiseEvent:Fire(hrp.Position, st.meter)
			end
		end
	end

	broadcast += dt
	if broadcast >= 0.1 then
		broadcast = 0
		for player, st in states do
			Remotes.NoiseMeter:FireClient(player, math.floor(st.meter + 0.5))
		end
	end
end)
