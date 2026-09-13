--!strict
-- Slowly brings in the bunker ambience for each player without overpowering
-- dialogue, elevator effects, or UI feedback.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mutedMovementSounds = {
	Running = true,
	Jumping = true,
	Landing = true,
}

local function muteCharacterMovement(character: Model)
	local function mute(item: Instance)
		if item:IsA("Sound") and mutedMovementSounds[item.Name] then
			item.Volume = 0
		end
	end
	for _, item in character:GetDescendants() do mute(item) end
	character.DescendantAdded:Connect(mute)
end

player.CharacterAdded:Connect(muteCharacterMovement)
if player.Character then muteCharacterMovement(player.Character) end

local atmosphere = SoundService:WaitForChild("LobbyAtmosphere", 15)
if not atmosphere then return end

for _, item in atmosphere:GetChildren() do
	if item:IsA("Sound") then
		local targetVolume = item:GetAttribute("TargetVolume")
		if typeof(targetVolume) ~= "number" then targetVolume = 0.1 end
		item.Volume = 0
		if not item.IsPlaying then item:Play() end
		TweenService:Create(
			item,
			TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Volume = targetVolume }
		):Play()
	end
end
