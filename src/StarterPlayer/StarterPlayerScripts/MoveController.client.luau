--!strict
-- Walk / crouch / sprint. Sets local WalkSpeed and tells the server which state
-- you're in so the noise system knows how loud you are.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local csModule = ReplicatedStorage:WaitForChild("ClientState", 5)
local ClientState = (csModule and require(csModule)) or { stamina = 1 }

local player = Players.LocalPlayer

local crouched = false
local stamina = Config.StaminaMax
local exhausted = false
local sentState = ""

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- Poll held input instead of relying on one-time input callbacks. This cannot get
-- stuck if focus changes while Shift is held.
local function wantsToSprint(): boolean
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		return true
	end
	return UserInputService.GamepadEnabled
		and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL3)
end

-- Poll crouch just like sprint so releasing Ctrl always stands the player up,
-- even if Studio or the camera consumed one of the input events.
local function wantsToCrouch(): boolean
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
		return true
	end
	return UserInputService.GamepadEnabled
		and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonB)
end

-- Set WalkSpeed before the physics step that consumes it. The server mirrors this
-- validated state as well, which keeps movement working with server authority on.
RunService.PreSimulation:Connect(function(dt)
	local hum = humanoid()
	if not hum or hum.Health <= 0 then
		return
	end
	if player:GetAttribute("PhotoModeActive") == true then
		hum:Move(Vector3.zero)
		hum.WalkSpeed, hum.Jump = 0, false
		crouched = false
		player:SetAttribute("Crouched", false)
		ClientState.move, ClientState.walkSpeed = "idle", 0
		if sentState ~= "idle" then
			sentState = "idle"
			Remotes.SetMoveState:FireServer("idle")
		end
		return
	end
	if player:GetAttribute("Role") == "BlindOne" then
		crouched = false
		stamina = Config.StaminaMax
		exhausted = false
		hum.WalkSpeed = Config.PlayerBlindOneSpeed
		player:SetAttribute("Crouched", false)
		ClientState.stamina = 1
		ClientState.move = "monster"
		ClientState.walkSpeed = Config.PlayerBlindOneSpeed
		sentState = "monster"
		return
	end

	local wantSprint = wantsToSprint()
	crouched = wantsToCrouch() and not wantSprint
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
	ClientState.move = state
	ClientState.walkSpeed = speed

	if state ~= sentState then
		sentState = state
		Remotes.SetMoveState:FireServer(state)
	end
end)
