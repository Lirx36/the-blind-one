--!strict
-- Local cinematic storm. Everything is pooled so the rain can look dense
-- without continuously creating and destroying instances.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local rng = Random.new(7721)
local rainFolder = Instance.new("Folder")
rainFolder.Name = "ClientStorm"
rainFolder.Parent = workspace

local FALL = Vector3.new(-4, -112, -2)
local RADIUS = 48
local STREAK_COUNT = 104
local streaks: { Part } = {}

local function placeStreak(streak: Part, cameraPosition: Vector3, fullHeight: boolean)
	local position = cameraPosition + Vector3.new(
		rng:NextNumber(-RADIUS, RADIUS),
		rng:NextNumber(if fullHeight then -4 else 28, 48),
		rng:NextNumber(-RADIUS, RADIUS)
	)
	streak.Position = position
	streak:SetAttribute("RainSpeed", rng:NextNumber(0.82, 1.24))
end

for index = 1, STREAK_COUNT do
	local streak = Instance.new("Part")
	streak.Name = "Rain"
	streak.Anchored = true
	streak.CanCollide = false
	streak.CanQuery = false
	streak.CanTouch = false
	streak.CastShadow = false
	streak.Material = Enum.Material.Neon
	streak.Color = Color3.fromRGB(151, 165, 170)
	streak.Transparency = rng:NextNumber(0.72, 0.88)
	streak.Size = Vector3.new(0.018, 0.018, rng:NextNumber(1.5, 3.3))
	streak.Parent = rainFolder
	streaks[index] = streak
end

-- Subtle screen-edge falloff adds the heavy analog lens feel without placing a
-- dark overlay over the player's actual field of view.
local stormGui = Instance.new("ScreenGui")
stormGui.Name = "StormLens"
stormGui.IgnoreGuiInset = true
stormGui.ResetOnSpawn = false
stormGui.DisplayOrder = -5
stormGui.Parent = player:WaitForChild("PlayerGui")

local function edge(name: string, position: UDim2, size: UDim2, rotation: number)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = Color3.fromRGB(3, 6, 8)
	frame.BackgroundTransparency = 0.32
	frame.BorderSizePixel = 0
	frame.Parent = stormGui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
end

edge("TopVignette", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.17), 90)
edge("BottomVignette", UDim2.fromScale(0, 0.82), UDim2.fromScale(1, 0.18), 270)
edge("LeftVignette", UDim2.fromScale(0, 0), UDim2.fromScale(0.12, 1), 0)
edge("RightVignette", UDim2.fromScale(0.88, 0), UDim2.fromScale(0.12, 1), 180)

local function refreshStormLens()
	-- Rain and the renderer stay active in Photo Mode; only the dark lens edges
	-- disappear so the model can be inspected without any artificial darkness.
	stormGui.Enabled = player:GetAttribute("PhotoModeActive") ~= true
end
player:GetAttributeChangedSignal("PhotoModeActive"):Connect(refreshStormLens)
refreshStormLens()

local lightning = Instance.new("ColorCorrectionEffect")
lightning.Name = "StormLightningFlash"
lightning.Brightness = 0
lightning.Contrast = 0
lightning.Saturation = -0.08
lightning.TintColor = Color3.fromRGB(205, 224, 232)
lightning.Parent = Lighting

local nextLightning = os.clock() + rng:NextNumber(28, 55)
local initialized = false

RunService.RenderStepped:Connect(function(deltaTime)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	if not initialized then
		for _, streak in streaks do
			placeStreak(streak, cameraPosition, true)
		end
		initialized = true
	end

	for _, streak in streaks do
		local speedValue = streak:GetAttribute("RainSpeed")
		local speed = if typeof(speedValue) == "number" then speedValue else 1
		local position = streak.Position + FALL * deltaTime * speed
		local offset = position - cameraPosition
		if position.Y < cameraPosition.Y - 10 or math.abs(offset.X) > RADIUS + 8 or math.abs(offset.Z) > RADIUS + 8 then
			placeStreak(streak, cameraPosition, false)
			position = streak.Position
		end
		streak.CFrame = CFrame.lookAt(position, position + FALL.Unit)
	end

	if os.clock() >= nextLightning then
		nextLightning = os.clock() + rng:NextNumber(34, 72)
		lightning.Brightness = 0
		local flashIn = TweenService:Create(lightning, TweenInfo.new(0.055), { Brightness = 0.42, Contrast = 0.08 })
		local flashOut = TweenService:Create(lightning, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, Contrast = 0 })
		flashIn:Play()
		flashIn.Completed:Once(function()
			flashOut:Play()
		end)
	end
end)
