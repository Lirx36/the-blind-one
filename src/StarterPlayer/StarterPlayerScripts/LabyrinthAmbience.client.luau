--!strict
-- Low industrial room tone plus sparse, positional noises that make the maze
-- feel occupied without masking survivor movement or the lobby soundtrack.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
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
	{ id = "rbxassetid://9126147789", volume = 0.48, life = 9 }, -- distant sheet-metal groan
	{ id = "rbxassetid://9116893519", volume = 0.42, life = 9 }, -- tank scrape
	{ id = "rbxassetid://9116889970", volume = 0.4, life = 14 }, -- hollow machinery impact
	{ id = "rbxassetid://9120505299", volume = 0.3, life = 14 }, -- reverberant water trickle
	{ id = "rbxassetid://9112903308", volume = 0.34, life = 14 }, -- drops in an empty metal vessel
}

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
		TweenService:Create(bed, TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0.11 }):Play()
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
	local distance = rng:NextNumber(24, 68)
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
	sound.RollOffMinDistance = 7
	sound.RollOffMaxDistance = 96
	sound.EmitterSize = 4
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

task.spawn(function()
	task.wait(4)
	while true do
		if active then emitDistantNoise() end
		task.wait(rng:NextNumber(9, 22))
	end
end)
