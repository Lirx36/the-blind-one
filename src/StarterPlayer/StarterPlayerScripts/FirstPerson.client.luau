--!strict
-- Survivors are locked to first person -- no peeking around corners with a 3rd-person camera.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function lock()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
end

lock()
player.CharacterAdded:Connect(lock)
