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
	diffuseScale: number,
	specularScale: number,
	globalShadows: boolean,
	shadowSoftness: number,
	fogColor: Color3,
	fogStart: number,
	fogEnd: number,
	exposure: number,
	effects: { [Instance]: boolean },
	atmospheres: { [Atmosphere]: AtmosphereState },
}

local savedLighting: LightingState? = nil

local function setPostEffectEnabled(effect: Instance, enabled: boolean)
	if effect:IsA("BloomEffect")
		or effect:IsA("BlurEffect")
		or effect:IsA("ColorCorrectionEffect")
		or effect:IsA("DepthOfFieldEffect")
		or effect:IsA("SunRaysEffect") then
		effect.Enabled = enabled
	end
end

local function enableInspectionLighting()
	if savedLighting then
		return
	end

	local effects: { [Instance]: boolean } = {}
	local atmospheres: { [Atmosphere]: AtmosphereState } = {}
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BloomEffect")
			or effect:IsA("BlurEffect")
			or effect:IsA("ColorCorrectionEffect")
			or effect:IsA("DepthOfFieldEffect")
			or effect:IsA("SunRaysEffect") then
			effects[effect] = effect.Enabled
			effect.Enabled = false
		elseif effect:IsA("Atmosphere") then
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
			effect.Offset = 0
			effect.Color = Color3.new(1, 1, 1)
			effect.Decay = Color3.new(1, 1, 1)
		end
	end

	savedLighting = {
		clockTime = Lighting.ClockTime,
		brightness = Lighting.Brightness,
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
		diffuseScale = Lighting.EnvironmentDiffuseScale,
		specularScale = Lighting.EnvironmentSpecularScale,
		globalShadows = Lighting.GlobalShadows,
		shadowSoftness = Lighting.ShadowSoftness,
		fogColor = Lighting.FogColor,
		fogStart = Lighting.FogStart,
		fogEnd = Lighting.FogEnd,
		exposure = Lighting.ExposureCompensation,
		effects = effects,
		atmospheres = atmospheres,
	}

	-- Local-only neutral daylight for examining the procedural character. These
	-- values never replicate to the server or alter normal gameplay lighting.
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 4
	Lighting.Ambient = Color3.fromRGB(255, 255, 255)
	Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = false
	Lighting.ShadowSoftness = 0
	Lighting.FogColor = Color3.fromRGB(235, 238, 240)
	Lighting.FogStart = 100000
	Lighting.FogEnd = 100001
	Lighting.ExposureCompensation = 1.15
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
	Lighting.EnvironmentDiffuseScale = state.diffuseScale
	Lighting.EnvironmentSpecularScale = state.specularScale
	Lighting.GlobalShadows = state.globalShadows
	Lighting.ShadowSoftness = state.shadowSoftness
	Lighting.FogColor = state.fogColor
	Lighting.FogStart = state.fogStart
	Lighting.FogEnd = state.fogEnd
	Lighting.ExposureCompensation = state.exposure

	for effect, enabled in state.effects do
		if effect.Parent then
			setPostEffectEnabled(effect, enabled)
		end
	end
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
	if frozen then
		enableInspectionLighting()
	else
		restoreGameplayLighting()
	end
	label.Text = if frozen
		then "PHOTO MODE — FULL INSPECTION LIGHT  •  P TO RESUME"
		else "PHOTO MODE OFF — THE BLIND ONE IS MOVING  •  P TO FREEZE"
	label.TextColor3 = if frozen then Color3.fromRGB(190, 235, 245) else Color3.fromRGB(225, 235, 238)
end)
