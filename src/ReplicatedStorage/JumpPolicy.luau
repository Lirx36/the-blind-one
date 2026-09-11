--!strict
-- Apply on BOTH server and client: Humanoid state-enable flags don't replicate.
local JumpPolicy = {}

function JumpPolicy.Apply(humanoid: Humanoid, survivor: boolean)
	if humanoid:GetAttribute("OriginalJumpPower") == nil then
		humanoid:SetAttribute("OriginalJumpPower", humanoid.JumpPower)
		humanoid:SetAttribute("OriginalJumpHeight", humanoid.JumpHeight)
		humanoid:SetAttribute("OriginalAutoJump", humanoid.AutoJumpEnabled)
		humanoid:SetAttribute("OriginalJumpState", humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping))
	end
	if survivor then
		humanoid.Jump = false
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoJumpEnabled = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	else
		humanoid.JumpPower = humanoid:GetAttribute("OriginalJumpPower") :: number
		humanoid.JumpHeight = humanoid:GetAttribute("OriginalJumpHeight") :: number
		humanoid.AutoJumpEnabled = humanoid:GetAttribute("OriginalAutoJump") :: boolean
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, humanoid:GetAttribute("OriginalJumpState") :: boolean)
	end
end

return JumpPolicy
