--!strict
-- Studio-only convenience for photographing the solo AI monster.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

if not RunService:IsStudio() then
	return
end

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
local flightState: any = nil
local windowFocused = true
UserInputService.WindowFocused:Connect(function() windowFocused = true end)
UserInputService.WindowFocusReleased:Connect(function() windowFocused = false end)

local function startFlight()
	local camera = workspace.CurrentCamera
	if flightState or not camera then return end
	local pitch, yaw = camera.CFrame:ToOrientation()
	flightState = {
		camera = camera, cameraType = camera.CameraType, subject = camera.CameraSubject,
		frame = camera.CFrame, focus = camera.Focus,
		mouseBehavior = UserInputService.MouseBehavior, mouseIcon = UserInputService.MouseIconEnabled,
		prompts = ProximityPromptService.Enabled,
		position = camera.CFrame.Position, pitch = pitch, yaw = yaw,
	}
	controls:Disable()
	ProximityPromptService.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("PhotoModeFlight", Enum.RenderPriority.Camera.Value + 3, function(dt)
		local state = flightState
		if not state or workspace.CurrentCamera ~= state.camera then return end
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		local inMenu = game:GetService("GuiService").MenuIsOpen
		if windowFocused and not typing and not inMenu then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			local mouse = UserInputService:GetMouseDelta()
			state.yaw -= mouse.X * 0.0025
			state.pitch = math.clamp(state.pitch - mouse.Y * 0.0025, -math.pi/2 + 0.01, math.pi/2 - 0.01)
			local function key(code: Enum.KeyCode): number
				return if UserInputService:IsKeyDown(code) then 1 else 0
			end
			local rotation = CFrame.fromOrientation(state.pitch, state.yaw, 0)
			local direction = rotation.LookVector * (key(Enum.KeyCode.W)-key(Enum.KeyCode.S))
				+ rotation.RightVector * (key(Enum.KeyCode.D)-key(Enum.KeyCode.A))
				+ Vector3.yAxis * (math.max(key(Enum.KeyCode.Space),key(Enum.KeyCode.E))
					- math.max(key(Enum.KeyCode.Q),key(Enum.KeyCode.LeftControl),key(Enum.KeyCode.RightControl)))
			local fast = key(Enum.KeyCode.LeftShift) + key(Enum.KeyCode.RightShift) > 0
			if direction.Magnitude > 0 then
				state.position += direction.Unit * (if fast then 72 else 28) * math.min(dt, 0.1)
			end
		end
		state.camera.CameraType = Enum.CameraType.Scriptable
		state.camera.CFrame = CFrame.new(state.position) * CFrame.fromOrientation(state.pitch, state.yaw, 0)
		state.camera.Focus = state.camera.CFrame * CFrame.new(0, 0, -24)
	end)
end

local function stopFlight()
	local state = flightState
	if not state then return end
	flightState = nil
	RunService:UnbindFromRenderStep("PhotoModeFlight")
	local camera = workspace.CurrentCamera
	if camera then
		local character = player.Character
		camera.CameraSubject = (character and character:FindFirstChildOfClass("Humanoid")) or state.subject
		camera.CFrame, camera.Focus, camera.CameraType = state.frame, state.focus, state.cameraType
	end
	UserInputService.MouseBehavior, UserInputService.MouseIconEnabled = state.mouseBehavior, state.mouseIcon
	ProximityPromptService.Enabled = state.prompts
	controls:Enable()
end

type AtmosphereState = {
	density: number,
	haze: number,
	glare: number,
	offset: number,
	color: Color3,
	decay: Color3,
}

type LightingState = {
	clockTime: number,
	brightness: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogColor: Color3,
	fogStart: number,
	fogEnd: number,
	exposure: number,
	atmospheres: { [Atmosphere]: AtmosphereState },
}

local savedLighting: LightingState? = nil

local function enableInspectionLighting()
	if savedLighting then
		return
	end

	local atmospheres: { [Atmosphere]: AtmosphereState } = {}
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("Atmosphere") then
			atmospheres[effect] = {
				density = effect.Density,
				haze = effect.Haze,
				glare = effect.Glare,
				offset = effect.Offset,
				color = effect.Color,
				decay = effect.Decay,
			}
			effect.Density = 0
			effect.Haze = 0
			effect.Glare = 0
		end
	end

	savedLighting = {
		clockTime = Lighting.ClockTime,
		brightness = Lighting.Brightness,
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
		fogColor = Lighting.FogColor,
		fogStart = Lighting.FogStart,
		fogEnd = Lighting.FogEnd,
		exposure = Lighting.ExposureCompensation,
		atmospheres = atmospheres,
	}

	-- Photo mode changes only visibility: bright daylight removes the darkness
	-- and Atmosphere/Fog are cleared above. Bloom, depth of field, color grade,
	-- Future lighting, wet reflections, shadows, and weather remain untouched.
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 3.1
	Lighting.Ambient = Color3.fromRGB(142, 150, 153)
	Lighting.OutdoorAmbient = Color3.fromRGB(164, 174, 178)
	Lighting.FogColor = Color3.fromRGB(235, 238, 240)
	Lighting.FogStart = 100000
	Lighting.FogEnd = 100001
	Lighting.ExposureCompensation = 0.72
end

local function restoreGameplayLighting()
	local state = savedLighting
	if not state then
		return
	end
	savedLighting = nil

	Lighting.ClockTime = state.clockTime
	Lighting.Brightness = state.brightness
	Lighting.Ambient = state.ambient
	Lighting.OutdoorAmbient = state.outdoorAmbient
	Lighting.FogColor = state.fogColor
	Lighting.FogStart = state.fogStart
	Lighting.FogEnd = state.fogEnd
	Lighting.ExposureCompensation = state.exposure

	for atmosphere, atmosphereState in state.atmospheres do
		if atmosphere.Parent then
			atmosphere.Density = atmosphereState.density
			atmosphere.Haze = atmosphereState.haze
			atmosphere.Glare = atmosphereState.glare
			atmosphere.Offset = atmosphereState.offset
			atmosphere.Color = atmosphereState.color
			atmosphere.Decay = atmosphereState.decay
		end
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "PhotoModeHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -84)
label.Size = UDim2.new(0.94, 0, 0, 54)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize, sizeLimit.Parent = Vector2.new(680, 54), label
label.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
label.BackgroundTransparency = 0.22
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(225, 235, 238)
label.TextSize = 15
label.TextWrapped = true
label.Text = "Press P for Photo Mode / free flight"
label.Parent = gui

player:GetAttributeChangedSignal("Role"):Connect(function()
	gui.Enabled = player:GetAttribute("Role") ~= "BlindOne"
	if player:GetAttribute("Role") == "BlindOne" and savedLighting then
		player:SetAttribute("PhotoModeActive", false)
		stopFlight()
		restoreGameplayLighting()
		Remotes.PhotoMode:FireServer(false)
	end
end)
gui.Enabled = player:GetAttribute("Role") ~= "BlindOne"

UserInputService.InputBegan:Connect(function(input)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if input.KeyCode == Enum.KeyCode.P and not shiftHeld and player:GetAttribute("Role") ~= "BlindOne" then
		Remotes.PhotoMode:FireServer()
	end
end)

Remotes.PhotoMode.OnClientEvent:Connect(function(frozen: boolean)
	if frozen and (player:GetAttribute("Role") == "BlindOne" or not player.Character) then
		Remotes.PhotoMode:FireServer(false)
		return
	end
	player:SetAttribute("PhotoModeActive", frozen)
	if frozen then
		enableInspectionLighting()
		startFlight()
	else
		stopFlight()
		restoreGameplayLighting()
	end
	label.Text = if frozen
		then "PHOTO FLIGHT  ·  WASD + mouse  ·  Space/E up  ·  Q/Ctrl down\nShift faster  ·  P return  ·  Clear lighting / graphics on"
		else "Press P for Photo Mode / free flight"
	label.TextColor3 = if frozen then Color3.fromRGB(190, 235, 245) else Color3.fromRGB(225, 235, 238)
end)

player.CharacterRemoving:Connect(function()
	if savedLighting or flightState then
		player:SetAttribute("PhotoModeActive", false)
		stopFlight()
		restoreGameplayLighting()
		Remotes.PhotoMode:FireServer(false)
	end
end)
