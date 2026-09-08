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

local noiseBindable = Instance.new("BindableEvent")
noiseBindable.Name = "Noise"
noiseBindable.Parent = ServerStorage

local NOISE_TARGET = {
	idle = Config.NoiseIdle,
	walk = Config.NoiseWalk,
	crouch = Config.NoiseCrouch,
	sprint = Config.NoiseSprint,
}

type State = { meter: number, move: string, lastStep: number }
local states: { [Player]: State } = {}

Players.PlayerAdded:Connect(function(player)
	states[player] = { meter = 0, move = "idle", lastStep = 0 }
end)
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

Remotes.SetMoveState.OnServerEvent:Connect(function(player, move)
	local st = states[player]
	if st and NOISE_TARGET[move] ~= nil then
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

		local vel = hrp.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local moving = speed > 1.5
		-- target noise scales with how fast you're actually going, not just the key you hold
		local speedFactor = math.clamp(speed / Config.WalkSpeed, 0, 1.3)
		local target = (NOISE_TARGET[st.move] or 0) * (moving and speedFactor or 0)

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
				noiseBindable:Fire(hrp.Position, st.meter)
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
