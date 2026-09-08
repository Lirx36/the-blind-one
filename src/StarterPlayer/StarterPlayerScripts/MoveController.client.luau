--!strict
-- Walk / crouch / sprint. Sets local WalkSpeed and tells the server which state
-- you're in so the noise system knows how loud you are.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local csModule = ReplicatedStorage:WaitForChild("ClientState", 5)
local ClientState = (csModule and require(csModule)) or { stamina = 1 }

local player = Players.LocalPlayer

-- kill Roblox's Shift-Lock so Left Shift is free for sprinting
player.DevEnableMouseLock = false

-- BIG obvious debug panel
local dbgGui = Instance.new("ScreenGui")
dbgGui.Name = "MoveDebug"
dbgGui.ResetOnSpawn = false
dbgGui.IgnoreGuiInset = true
dbgGui.Parent = player:WaitForChild("PlayerGui")
local dbg = Instance.new("TextLabel")
dbg.AnchorPoint = Vector2.new(0.5, 0)
dbg.Size = UDim2.fromOffset(560, 110)
dbg.Position = UDim2.new(0.5, 0, 0, 6)
dbg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dbg.BackgroundTransparency = 0.35
dbg.Font = Enum.Font.Code
dbg.TextSize = 17
dbg.TextXAlignment = Enum.TextXAlignment.Center
dbg.TextYAlignment = Enum.TextYAlignment.Top
dbg.TextColor3 = Color3.fromRGB(120, 255, 140)
dbg.Text = "MoveController: starting..."
dbg.Parent = dbgGui

local wantSprint = false
local crouched = false
local stamina = Config.StaminaMax
local exhausted = false
local sentState = ""

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- Sprint via ContextActionService: fires even though Left Shift is a reserved engine key
ContextActionService:BindAction("Sprint", function(_, inputState)
	wantSprint = inputState == Enum.UserInputState.Begin
	if wantSprint then
		crouched = false
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

-- Crouch toggle
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		crouched = not crouched
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
	ClientState.move = state
	ClientState.walkSpeed = speed

	dbg.Text = string.format(
		"MoveController RUNNING\nwantSprint=%s  moving=%s  crouched=%s  exhausted=%s\nstate=%s  speed set=%d\nhum.WalkSpeed NOW=%.1f   stamina=%.1f",
		tostring(wantSprint), tostring(moving), tostring(crouched), tostring(exhausted),
		state, speed, hum.WalkSpeed, stamina
	)

	if state ~= sentState then
		sentState = state
		Remotes.SetMoveState:FireServer(state)
	end
end)

print("[MoveController] running")
