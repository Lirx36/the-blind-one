--!strict
-- Walk / crouch / sprint. Sets local WalkSpeed and tells the server which state you're
-- in so the noise system knows how loud you are.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local csModule = ReplicatedStorage:WaitForChild("ClientState", 5)
local ClientState = (csModule and require(csModule)) or { stamina = 1 }

local player = Players.LocalPlayer

local wantSprint = false
local crouched = false
local stamina = Config.StaminaMax
local exhausted = false
local sentState = ""

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		wantSprint = true
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		crouched = not crouched
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		wantSprint = false
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local hum = humanoid()
	if not hum or hum.Health <= 0 then
		return
	end

	local moving = hum.MoveDirection.Magnitude > 0.1
	local sprinting = wantSprint and moving and not crouched and not exhausted

	if sprinting then
		stamina = math.max(0, stamina - Config.StaminaDrainPerSec * dt)
		if stamina <= 0 then
			exhausted = true
		end
	else
		stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegenPerSec * dt)
		if exhausted and stamina > Config.StaminaMax * 0.35 then
			exhausted = false
		end
	end
	ClientState.stamina = math.clamp(stamina / Config.StaminaMax, 0, 1)

	local state, speed
	if sprinting then
		state, speed = "sprint", Config.SprintSpeed
	elseif crouched then
		state, speed = "crouch", Config.CrouchSpeed
	elseif moving then
		state, speed = "walk", Config.WalkSpeed
	else
		state, speed = "idle", crouched and Config.CrouchSpeed or Config.WalkSpeed
	end

	hum.WalkSpeed = speed
	player:SetAttribute("Crouched", crouched)

	if state ~= sentState then
		sentState = state
		Remotes.SetMoveState:FireServer(state)
	end
end)
