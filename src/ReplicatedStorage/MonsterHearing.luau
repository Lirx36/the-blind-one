--!strict
-- Bot-only hearing and target commitment. Does not change survivor noise meters.
local Hearing = {}
function Hearing.Strength(loudness: number, distance: number, config: any): number?
	if distance > config.BotHearingRange then return nil end
	local strength = loudness - distance / config.BotNoiseCarry
	return if strength >= config.MonsterHearingFloor then strength else nil
end
function Hearing.ShouldSwitch(currentScore: number, candidateScore: number, lockedFor: number, config: any): boolean
	local margin = math.max(config.BotTargetSwitchMargin, math.abs(currentScore) * 0.2)
	if lockedFor < config.BotTargetCommitTime then margin *= 2 end
	return candidateScore > currentScore + margin
end
return Hearing
