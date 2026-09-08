--!strict
-- Screen slam + shake when the monster catches you. Swap SCARE_IMAGE / SCARE_SOUND
-- for your own asset ids.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local SCARE_IMAGE = "" -- e.g. "rbxassetid://0000000000" (a scary face). Empty = red flash only.
local SCARE_SOUND = "" -- e.g. "rbxassetid://0000000000" (a stinger).

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Jumpscare"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local face = Instance.new("ImageLabel")
face.Size = UDim2.fromScale(1, 1)
face.BackgroundTransparency = 1
face.ScaleType = Enum.ScaleType.Fit
face.Image = SCARE_IMAGE
face.Visible = SCARE_IMAGE ~= ""
face.Parent = gui

local sound = Instance.new("Sound")
sound.Volume = 1
sound.SoundId = SCARE_SOUND
sound.Parent = gui

local function shake(duration: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = os.clock() - t0
		if a >= duration then
			conn:Disconnect()
			return
		end
		local mag = (1 - a / duration) * 1.2
		cam.CFrame = cam.CFrame * CFrame.Angles(
			(math.random() - 0.5) * mag * 0.1,
			(math.random() - 0.5) * mag * 0.1,
			(math.random() - 0.5) * mag * 0.1
		)
	end)
end

Remotes.Jumpscare.OnClientEvent:Connect(function()
	gui.Enabled = true
	backdrop.BackgroundTransparency = 0
	if SCARE_SOUND ~= "" then
		sound:Play()
	end
	shake(0.6)
	task.spawn(function()
		for i = 0, 1, 0.06 do
			backdrop.BackgroundTransparency = i
			face.ImageTransparency = i
			task.wait(0.03)
		end
		gui.Enabled = false
	end)
end)
