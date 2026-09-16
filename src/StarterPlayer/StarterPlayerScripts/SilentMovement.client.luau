--!strict
-- Mute only this player's stock movement loop. The server-side noise meter and
-- positional footstep events still run, so The Blind One can hear movement even
-- though the survivor does not hear repetitive footsteps from their own avatar.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function muteMovementSound(instance: Instance)
	if instance:IsA("Sound") and instance.Name == "Running" then
		instance.Volume = 0
	end
end

local function bindCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		muteMovementSound(descendant)
	end
	character.DescendantAdded:Connect(muteMovementSound)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end
