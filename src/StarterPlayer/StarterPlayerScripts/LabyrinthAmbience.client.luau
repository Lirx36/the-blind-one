--!strict
-- Low industrial room tone plus sparse, positional noises that make the maze
-- feel occupied without masking survivor movement or the lobby soundtrack.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local rng = Random.new()

local bed = Instance.new("Sound")
bed.Name = "HollowIndustrialBed"
bed.SoundId = "rbxassetid://9119386571"
bed.Looped = true
bed.Volume = 0
bed.PlaybackSpeed = 0.82
bed.Parent = SoundService
local bedReverb = Instance.new("ReverbSoundEffect")
bedReverb.DecayTime = 7.5
bedReverb.Density = 0.72
bedReverb.Diffusion = 0.58
bedReverb.DryLevel = -5
bedReverb.WetLevel = -14
bedReverb.Parent = bed

local oneShots = {
	{ id = "rbxassetid://9126147789", volume = 0.86, life = 9 }, -- distant sheet-metal groan
	{ id = "rbxassetid://9116893519", volume = 0.76, life = 9 }, -- tank scrape
	{ id = "rbxassetid://9116889970", volume = 0.72, life = 14 }, -- hollow machinery impact
	{ id = "rbxassetid://9120505299", volume = 0.58, life = 14 }, -- reverberant water trickle
	{ id = "rbxassetid://9112903308", volume = 0.64, life = 14 }, -- drops in an empty metal vessel
}

-- A real human lub-dub recording from the Creator Store. Keeping the complete
-- beat intact avoids the violent metallic kick produced by the old impact clip.
local heartbeat = Instance.new("Sound")
heartbeat.Name = "BlindOneProximityHeartbeat"
heartbeat.SoundId = "rbxassetid://2936809023"
heartbeat.Looped = true
heartbeat.Volume = 0
heartbeat.PlaybackSpeed = 0.82
heartbeat.Parent = SoundService

local HEARTBEAT_RANGE = 100
local HEARTBEAT_PANIC_RANGE = 12
local heartbeatStrength = 0

local function blindOneRoot(): BasePart?
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player and candidate:GetAttribute("InMatch") == true
			and candidate:GetAttribute("Role") == "BlindOne" then
			local character = candidate.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				return root
			end
		end
	end
	local bot = workspace:FindFirstChild("TheBlindOne")
	if not bot or not bot:IsA("Model") then return nil end
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local root = bot:FindFirstChild("HumanoidRootPart") or bot.PrimaryPart
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end

local active = false
local function shouldPlay(): boolean
	return player:GetAttribute("InMatch") == true and player:GetAttribute("ArrivalActive") ~= true
end

local function refresh()
	local nextActive = shouldPlay()
	if nextActive == active then return end
	active = nextActive
	if active then
		if not bed.IsPlaying then bed:Play() end
		TweenService:Create(bed, TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0.23 }):Play()
	else
		TweenService:Create(bed, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 }):Play()
	end
end

player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
player:GetAttributeChangedSignal("ArrivalActive"):Connect(refresh)
refresh()

local function emitDistantNoise()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not active or not root or not root:IsA("BasePart") then return end
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(18, 54)
	local emitter = Instance.new("Part")
	emitter.Name = "LocalAmbientEmitter"
	emitter.Size = Vector3.one
	emitter.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * distance, rng:NextNumber(1, 9), math.sin(angle) * distance))
	emitter.Transparency = 1
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Parent = workspace
	local choice = oneShots[rng:NextInteger(1, #oneShots)]
	local sound = Instance.new("Sound")
	sound.Name = "DistantLabyrinthNoise"
	sound.SoundId = choice.id
	sound.Volume = choice.volume
	sound.PlaybackSpeed = rng:NextNumber(0.86, 1.04)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 110
	sound.EmitterSize = 7
	sound.Parent = emitter
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 8
	reverb.Density = 0.78
	reverb.Diffusion = 0.45
	reverb.DryLevel = -4
	reverb.WetLevel = -9
	reverb.Parent = sound
	sound:Play()
	Debris:AddItem(emitter, choice.life)
end

RunService.Heartbeat:Connect(function(dt)
	local targetStrength = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if active and player:GetAttribute("Role") ~= "BlindOne"
		and player:GetAttribute("Spectating") ~= true
		and player:GetAttribute("AwaitingDeathChoice") ~= true
		and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		local hunterRoot = blindOneRoot()
		if hunterRoot then
			local distance = (hunterRoot.Position - root.Position).Magnitude
			targetStrength = 1 - math.clamp(
				(distance - HEARTBEAT_PANIC_RANGE) / (HEARTBEAT_RANGE - HEARTBEAT_PANIC_RANGE),
				0,
				1
			)
		end
	end

	local response = 1 - math.exp(-4.5 * dt)
	heartbeatStrength += (targetStrength - heartbeatStrength) * response
	if heartbeatStrength <= 0.015 then
		heartbeat.Volume = 0
		if heartbeat.IsPlaying then heartbeat:Stop() end
		return
	end
	if not heartbeat.IsPlaying then heartbeat:Play() end
	heartbeat.Volume = 0.06 + heartbeatStrength * 0.66
	-- The natural recording stays slow at the edge, then rises to roughly double
	-- speed only when the hunter is extremely close.
	heartbeat.PlaybackSpeed = 0.78 + heartbeatStrength * 0.92
end)

task.spawn(function()
	task.wait(4)
	while true do
		if active then emitDistantNoise() end
		task.wait(rng:NextNumber(6, 14))
	end
end)
