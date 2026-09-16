--!strict
-- All tuning for The Blind One. Change numbers here; no other edits needed.
return {
	-- ---- player movement ----
	WalkSpeed = 13,
	CrouchSpeed = 6,
	SprintSpeed = 20,
	StaminaMax = 4.5, -- seconds of sprint
	StaminaDrainPerSec = 1,
	StaminaRegenPerSec = 0.7,

	-- ---- noise ----
	-- Each player has a 0..100 "noise" meter. The monster hears the world in the
	-- same units: a sound of loudness L is audible out to about L * NoiseCarry studs.
	NoiseWalk = 24, -- meter target while walking at full speed
	NoiseCrouch = 3,
	NoiseSprint = 78,
	NoiseIdle = 0,
	NoiseSmoothing = 6, -- how fast the meter chases its target, per second
	NoiseCrouchDecayMultiplier = 3, -- crouching sheds existing noise three times faster
	FootstepInterval = 0.45, -- seconds between positional footstep blips while moving
	NoiseCarry = 1.7, -- studs of travel per point of loudness
	DoorNoise = 55,
	ThrowImpactNoise = 95,
	BumpNoise = 32,

	-- ---- monster: The Blind One ----
	MonsterWanderSpeed = 9,
	MonsterInvestigateSpeed = 14,
	MonsterHuntSpeed = 17.5, -- below survivor sprint speed, above normal walking
	MonsterCatchDistance = 5.5,
	MonsterHearingFloor = 4, -- crouching stays below this threshold
	BotNoiseCarry = 4, -- bot hears normal walking at about 80 studs
	BotHearingRange = 300, -- cap for sprinting, objectives and impact sounds
	BotTargetCommitTime = 2, -- resist marginal target changes after selection
	BotTargetSwitchMargin = 8, -- another sound must be clearly stronger
	BotSoundMemory = 60, -- allow time to traverse winding routes to distant noise
	MonsterInvestigateTime = 6, -- seconds it searches a heard spot before losing interest
	MonsterHuntGrace = 2.5, -- seconds of silence before HUNT downgrades to INVESTIGATE
	MonsterRepath = 0.35, -- seconds between path recomputes
	MonsterHuntNoise = 42, -- heard loudness at short range that escalates INVESTIGATE -> HUNT
	MonsterHuntRange = 85, -- loud nearby survivors trigger a faster pursuit
	PlayerBlindOneEnabled = true, -- with 2+ players, one player replaces the AI
	PlayerBlindOneSpeed = 19,

	-- ---- round ----
	StudioSafeMode = false, -- allow Studio playtests to trigger death, jumpscares, and recovery UI
	StudioAutoOpenGate = true, -- temporary: immediately open the exit gate during Studio playtests
	RespawnDelay = 3,
	MaxRespawns = 3, -- manual returns offered by the casualty terminal
	SpawnGrace = 3, -- seconds of immunity right after (re)spawning
	StartThrowables = 3,
	MaxThrowables = 4,
}
