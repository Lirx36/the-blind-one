--!strict
-- Studio-only convenience for photographing the solo AI monster.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer

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
label.Size = UDim2.fromOffset(390, 36)
label.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
label.BackgroundTransparency = 0.22
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(225, 235, 238)
label.TextSize = 15
label.Text = "Press P to freeze The Blind One for photos"
label.Parent = gui

UserInputService.InputBegan:Connect(function(input)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if input.KeyCode == Enum.KeyCode.P and not shiftHeld then
		Remotes.PhotoMode:FireServer()
	end
end)

Remotes.PhotoMode.OnClientEvent:Connect(function(frozen: boolean)
	player:SetAttribute("PhotoModeActive", frozen)
	if frozen then
		enableInspectionLighting()
	else
		restoreGameplayLighting()
	end
	label.Text = if frozen
		then "PHOTO MODE — CLEAR DAYLIGHT / CINEMATIC GRAPHICS ON  •  P TO RESUME"
		else "PHOTO MODE OFF — THE BLIND ONE IS MOVING  •  P TO FREEZE"
	label.TextColor3 = if frozen then Color3.fromRGB(190, 235, 245) else Color3.fromRGB(225, 235, 238)
end)
