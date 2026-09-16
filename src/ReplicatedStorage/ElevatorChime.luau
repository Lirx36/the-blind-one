--!strict
-- Roblox's short electronic bell, shared by lobby doors and destination arrival.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Chime = {}
local template = Instance.new("Sound")
template.Name = "ElevatorDing"
template.SoundId = "rbxassetid://12221990"
template.Volume = 0.55
template.RollOffMinDistance = 15
template.RollOffMaxDistance = 75
task.spawn(function()
	pcall(function() ContentProvider:PreloadAsync({template}) end)
end)
function Chime.Play(parent: Instance, arriving: boolean)
	local sound = template:Clone()
	sound.Name = if arriving then "ElevatorArrivalDing" else "ElevatorDepartureDing"
	sound.PlaybackSpeed = if arriving then 1.05 else 0.85
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 6)
end
return Chime
