--!strict
-- Client presentation for a player-controlled Blind One. The world is heavily
-- desaturated and noisy survivors appear as short-lived sound silhouettes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local player = Players.LocalPlayer

local oldVision = Lighting:FindFirstChild("LocalBlindOneVision")
if oldVision then
	oldVision:Destroy()
end
local vision = Instance.new("ColorCorrectionEffect")
vision.Name = "LocalBlindOneVision"
vision.Brightness = 0.06
vision.Contrast = 0.2
vision.Saturation = -0.78
vision.TintColor = Color3.fromRGB(165, 185, 195)
vision.Enabled = false
vision.Parent = Lighting

-- MapBuilder intentionally disables old post effects. This local bloom is
-- deterministic and lets the monster's Neon eye cores produce a real soft halo
-- on every client without changing the server's darkness or exposure.
local oldEyeBloom = Lighting:FindFirstChild("LocalMonsterEyeBloom")
if oldEyeBloom then
	oldEyeBloom:Destroy()
end
local eyeBloom = Instance.new("BloomEffect")
eyeBloom.Name = "LocalMonsterEyeBloom"
eyeBloom.Intensity = 1.45
eyeBloom.Size = 18
eyeBloom.Threshold = 0.82
eyeBloom.Enabled = true
eyeBloom.Parent = Lighting

local gui = Instance.new("ScreenGui")
gui.Name = "BlindOneRoleHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 74)
title.Size = UDim2.fromOffset(520, 58)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "THE BLIND ONE"
title.TextSize = 25
title.TextColor3 = Color3.fromRGB(210, 225, 232)
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.TextStrokeTransparency = 0.35
title.Parent = gui

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 108)
hint.Size = UDim2.fromOffset(620, 28)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.Text = "Noisy survivors leave bright silhouettes. Get close to catch them."
hint.TextSize = 14
hint.TextColor3 = Color3.fromRGB(155, 175, 185)
hint.TextStrokeTransparency = 0.55
hint.Parent = gui

local senseLight = Instance.new("PointLight")
senseLight.Name = "BlindSenseGlow"
senseLight.Color = Color3.fromRGB(105, 130, 138)
senseLight.Brightness = 3.1
senseLight.Range = 10
senseLight.Shadows = false
senseLight.Enabled = false

-- Direct surface samples make nearby geometry readable even when Lighting's
-- ambient/fog settings swallow local lights. The fixed pool is local-only and
-- allocation-free during play, so it cannot create the clone/performance issue.
local oldGeometrySense = workspace:FindFirstChild("LocalBlindSenseGeometry")
if oldGeometrySense then
	oldGeometrySense:Destroy()
end
local geometrySense = Instance.new("Folder")
geometrySense.Name = "LocalBlindSenseGeometry"
geometrySense.Parent = workspace

local SENSE_COLUMNS = 7
local SENSE_ROWS = 5
local SENSE_RANGE = 12
local senseDots: { Part } = {}
for index = 1, SENSE_COLUMNS * SENSE_ROWS do
	local dot = Instance.new("Part")
	dot.Name = "SurfaceEcho"
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.one * 0.2
	dot.Color = Color3.fromRGB(125, 155, 165)
	dot.Material = Enum.Material.Neon
	dot.Anchored = true
	dot.CanCollide = false
	dot.CanTouch = false
	dot.CanQuery = false
	dot.CastShadow = false
	dot.Transparency = 1
	dot.Parent = geometrySense
	senseDots[index] = dot
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
local nextGeometrySenseAt = 0

local function hideGeometrySense()
	for _, dot in senseDots do
		dot.Transparency = 1
	end
end

local function updateGeometrySense(camera: Camera, ownCharacter: Model, now: number)
	if now < nextGeometrySenseAt then
		return
	end
	nextGeometrySenseAt = now + 0.065

	local excluded: { Instance } = { ownCharacter, geometrySense }
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer.Character and otherPlayer.Character ~= ownCharacter then
			table.insert(excluded, otherPlayer.Character)
		end
	end
	raycastParams.FilterDescendantsInstances = excluded

	local viewport = camera.ViewportSize
	local dotIndex = 0
	for row = 0, SENSE_ROWS - 1 do
		for column = 0, SENSE_COLUMNS - 1 do
			dotIndex += 1
			local screenX = viewport.X * (0.06 + 0.88 * column / (SENSE_COLUMNS - 1))
			local screenY = viewport.Y * (0.24 + 0.72 * row / (SENSE_ROWS - 1))
			local ray = camera:ViewportPointToRay(screenX, screenY)
			local result = workspace:Raycast(ray.Origin, ray.Direction * SENSE_RANGE, raycastParams)
			local dot = senseDots[dotIndex]
			if result then
				local distance = (result.Position - ray.Origin).Magnitude
				local closeness = 1 - math.clamp(distance / SENSE_RANGE, 0, 1)
				local size = 0.16 + closeness * 0.2
				dot.Size = Vector3.one * size
				dot.CFrame = CFrame.new(result.Position + result.Normal * 0.035)
				dot.Transparency = 0.24 + (1 - closeness) * 0.54
			else
				dot.Transparency = 1
			end
		end
	end
end

local lastRole = ""
local roleShownAt = 0

local highlights: { [Player]: Highlight } = {}
local lastHeard: { [Player]: number } = {}
local lastStrength: { [Player]: number } = {}

local function highlightFor(target: Player): Highlight
	local existing = highlights[target]
	if existing then
		return existing
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalSoundSilhouette"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(205, 225, 235)
	highlight.OutlineColor = Color3.fromRGB(240, 250, 255)
	highlight.FillTransparency = 0.82
	highlight.OutlineTransparency = 0.08
	highlight.Enabled = false
	highlight.Parent = workspace
	highlights[target] = highlight
	return highlight
end

Players.PlayerRemoving:Connect(function(target)
	local highlight = highlights[target]
	if highlight then
		highlight:Destroy()
	end
	highlights[target] = nil
	lastHeard[target] = nil
	lastStrength[target] = nil
end)

RunService.RenderStepped:Connect(function()
	local roleValue = player:GetAttribute("Role")
	local role = if typeof(roleValue) == "string" then roleValue else ""
	local isBlindOne = role == "BlindOne"
	local now = os.clock()
	if role ~= "" and role ~= lastRole then
		lastRole = role
		roleShownAt = now
		if isBlindOne then
			title.Text = "YOU ARE THE BLIND ONE"
			title.TextColor3 = Color3.fromRGB(210, 225, 232)
			hint.Text = "Follow bright sound silhouettes • Get close to catch survivors • You carry no light"
			hint.TextColor3 = Color3.fromRGB(155, 185, 200)
		else
			title.Text = "YOU ARE A SURVIVOR"
			title.TextColor3 = Color3.fromRGB(220, 235, 215)
			hint.Text = "Hold Ctrl to crouch • Shift to sprint • E picks up rocks • Click throws them"
			hint.TextColor3 = Color3.fromRGB(170, 195, 165)
		end
	end
	vision.Enabled = isBlindOne
	gui.Enabled = role ~= "" and now - roleShownAt < 8
	local ownCharacter = player.Character
	local ownRoot = ownCharacter and ownCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if isBlindOne and ownRoot then
		if senseLight.Parent ~= ownRoot then
			senseLight.Parent = ownRoot
		end
		senseLight.Enabled = true
		-- A bright but tiny local bubble reveals only the floor and walls within a
		-- few steps. It prevents blind wall-bumping without becoming normal vision.
		senseLight.Brightness = 3.1 + math.sin(now * 2.4) * 0.16
		local camera = workspace.CurrentCamera
		if camera and ownCharacter then
			updateGeometrySense(camera, ownCharacter, now)
		end
	else
		senseLight.Enabled = false
		senseLight.Parent = nil
		hideGeometrySense()
	end

	for _, target in Players:GetPlayers() do
		if target == player then
			continue
		end
		local highlight = highlightFor(target)
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local noiseValue = target:GetAttribute("Noise")
		local noise = if typeof(noiseValue) == "number" then noiseValue else 0
		local audible = false
		local strength = 0
		if isBlindOne and ownRoot and root and humanoid and humanoid.Health > 0
			and target:GetAttribute("Role") ~= "BlindOne" and noise >= Config.MonsterHearingFloor then
			local distance = (root.Position - ownRoot.Position).Magnitude
			-- Human-controlled monsters need a readable signal across these large
			-- rooms. Walking carries at least 90 studs; sprinting carries much farther.
			local hearingRange = math.max(90, noise * Config.NoiseCarry * 1.55)
			audible = distance <= hearingRange
			local proximity = math.clamp(1 - distance / hearingRange, 0, 1)
			local loudness = math.clamp(noise / Config.NoiseWalk, 0.45, 1)
			strength = math.clamp((0.35 + proximity * 0.65) * loudness, 0, 1)
		end
		if audible then
			lastHeard[target] = now
			lastStrength[target] = strength
		end
		local age = now - (lastHeard[target] or -100)
		local afterglow = math.clamp(1 - age / 2.5, 0, 1)
		local shownStrength = math.max(strength, (lastStrength[target] or 0) * afterglow)
		highlight.Adornee = character
		highlight.Enabled = isBlindOne and character ~= nil and shownStrength > 0.02
		highlight.FillTransparency = 0.94 - shownStrength * 0.3
		highlight.OutlineTransparency = 0.8 - shownStrength * 0.72
	end
end)
