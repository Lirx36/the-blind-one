--!strict
-- Client presentation for a player-controlled Blind One. The world is heavily
-- desaturated and noisy survivors appear as short-lived sound silhouettes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local player = Players.LocalPlayer

local oldVision = Lighting:FindFirstChild("LocalBlindOneVision")
if oldVision then
	oldVision:Destroy()
end
local vision = Instance.new("ColorCorrectionEffect")
vision.Name = "LocalBlindOneVision"
-- Map hiding supplies blindness. Crushing all scene colors also crushed the
-- cyan surface echoes into dark reddish pixels.
vision.Brightness = 0
vision.Contrast = 0
vision.Saturation = 0
vision.TintColor = Color3.new(1, 1, 1)
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

local oldSoundFigures = workspace:FindFirstChild("LocalBlindSoundFigures")
if oldSoundFigures then
	oldSoundFigures:Destroy()
end
local soundFigures = Instance.new("Folder")
soundFigures.Name = "LocalBlindSoundFigures"
soundFigures.Parent = workspace

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

	local excluded: { Instance } = { ownCharacter, geometrySense, soundFigures }
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
local roleSequence = 0
local ROLE_HIDDEN_POSITION = UDim2.new(0.5, 0, 0, -62)
local ROLE_SHOWN_POSITION = UDim2.new(0.5, 0, 0, 74)
local ROLE_TWEEN = TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function playRoleReveal(isBlindOne: boolean)
	roleSequence += 1
	local sequence = roleSequence
	player:SetAttribute("RoleIntroComplete", false)
	gui.Enabled = true
	title.Position = ROLE_HIDDEN_POSITION
	title.TextTransparency = 1
	title.TextStrokeTransparency = 1
	hint.Visible = isBlindOne
	hint.TextTransparency = 1
	hint.TextStrokeTransparency = 1

	local titleIn = TweenService:Create(title, ROLE_TWEEN, {
		Position = ROLE_SHOWN_POSITION,
		TextTransparency = 0,
		TextStrokeTransparency = 0.35,
	})
	titleIn:Play()
	if isBlindOne then
		TweenService:Create(hint, ROLE_TWEEN, {
			TextTransparency = 0,
			TextStrokeTransparency = 0.55,
		}):Play()
	end
	titleIn.Completed:Wait()
	task.wait(2.15)
	if sequence ~= roleSequence then return end

	local titleOut = TweenService:Create(title, ROLE_TWEEN, {
		Position = ROLE_HIDDEN_POSITION,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	titleOut:Play()
	if isBlindOne then
		TweenService:Create(hint, ROLE_TWEEN, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end
	titleOut.Completed:Wait()
	if sequence ~= roleSequence then return end
	gui.Enabled = false
	player:SetAttribute("RoleIntroComplete", true)
end
local NEAR_ECHO_ENTER = 42
local NEAR_ECHO_EXIT = 50 -- hysteresis avoids flickering at the transition

type EchoFigure = {
	model: Model,
	highlight: Highlight,
	billboard: BillboardGui,
	strokes: { UIStroke },
	parts: { [string]: Part },
	phase: number,
	position: Vector3?,
	direction: Vector3?,
	near: boolean,
}

local survivorFigures: { [Player]: EchoFigure } = {}
local rockFigures: { [BasePart]: EchoFigure } = {}
local hiddenParts: { [BasePart]: number } = {}
local hiddenNameplates: { [Humanoid]: Enum.HumanoidDisplayDistanceType } = {}
local hiddenDecoyBalls: { [BasePart]: number } = {}
local ownVisualParts: { [BasePart]: number } = {}
local ownVisualLights: { [Light]: boolean } = {}
local ownVisualHighlights: { [Highlight]: boolean } = {}

local function echoPart(model: Model, name: string, size: Vector3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Color = Color3.fromRGB(103, 177, 217)
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function newEchoFigure(name: string): EchoFigure
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = soundFigures
	local parts = {
		Torso = echoPart(model, "Torso", Vector3.new(1.3, 1.65, 0.62)),
		Head = echoPart(model, "Head", Vector3.new(0.82, 0.82, 0.82), Enum.PartType.Ball),
		LeftArm = echoPart(model, "LeftArm", Vector3.new(0.42, 1.62, 0.48)),
		RightArm = echoPart(model, "RightArm", Vector3.new(0.42, 1.62, 0.48)),
		LeftLeg = echoPart(model, "LeftLeg", Vector3.new(0.5, 1.72, 0.55)),
		RightLeg = echoPart(model, "RightLeg", Vector3.new(0.5, 1.72, 0.55)),
	}
	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalSoundSilhouette"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(68, 143, 193)
	highlight.OutlineColor = Color3.fromRGB(125, 205, 250)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Adornee = model
	highlight.Parent = model

	-- Highlights are not dependable through every opaque Roblox material. This
	-- anonymous outline is drawn in screen space over the echo's torso, so sound
	-- is readable through walls without revealing the survivor's real avatar.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ThroughWallSoundOutline"
	billboard.Adornee = parts.Torso
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	-- Sound is global, but the marker stays deliberately small so distance is
	-- readable instead of turning every survivor into a giant HUD target.
	billboard.MaxDistance = 100000
	billboard.Size = UDim2.fromOffset(28, 44)
	billboard.Enabled = false
	billboard.Parent = parts.Torso

	local strokes: { UIStroke } = {}
	local function outlinePiece(
		pieceName: string,
		position: UDim2,
		size: UDim2,
		rotation: number,
		round: boolean
	)
		local piece = Instance.new("Frame")
		piece.Name = pieceName
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = position
		piece.Size = size
		piece.Rotation = rotation
		piece.BackgroundTransparency = 1
		piece.Parent = billboard
		if round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = piece
		end
		local stroke = Instance.new("UIStroke")
		stroke.Name = "SoundStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(225, 244, 255)
		stroke.Thickness = 1.35
		stroke.Transparency = 1
		stroke.Parent = piece
		table.insert(strokes, stroke)
	end

	outlinePiece("Head", UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.31, 0.2), 0, true)
	outlinePiece("Torso", UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.45, 0.36), 0, false)
	outlinePiece("LeftArm", UDim2.fromScale(0.25, 0.45), UDim2.fromScale(0.15, 0.44), 8, true)
	outlinePiece("RightArm", UDim2.fromScale(0.75, 0.45), UDim2.fromScale(0.15, 0.44), -8, true)
	outlinePiece("LeftLeg", UDim2.fromScale(0.39, 0.78), UDim2.fromScale(0.17, 0.42), 3, true)
	outlinePiece("RightLeg", UDim2.fromScale(0.61, 0.78), UDim2.fromScale(0.17, 0.42), -3, true)

	return {
		model = model,
		highlight = highlight,
		billboard = billboard,
		strokes = strokes,
		parts = parts,
		phase = 0,
		near = false,
	}
end

local function survivorFigure(target: Player): EchoFigure
	local existing = survivorFigures[target]
	if existing then
		return existing
	end
	local figure = newEchoFigure("AnonymousSurvivorEcho")
	survivorFigures[target] = figure
	return figure
end

local function rockFigure(rock: BasePart): EchoFigure
	local existing = rockFigures[rock]
	if existing then
		return existing
	end
	local figure = newEchoFigure("AnonymousDecoyEcho")
	rockFigures[rock] = figure
	return figure
end


local function poseEcho(
	figure: EchoFigure,
	center: Vector3,
	direction: Vector3,
	speed: number,
	strength: number,
	dt: number,
	forceMotion: boolean,
	distance: number
)
	figure.near = if figure.near then distance < NEAR_ECHO_EXIT else distance <= NEAR_ECHO_ENTER
	for _, part in figure.parts do
		-- Highlight stops rendering reliably on almost-fully-transparent parts.
		-- A dim Neon body guarantees a readable anonymous echo in the darkness;
		-- the real survivor avatar remains locally hidden.
		part.Transparency = if figure.near then 0.82 else 1
	end
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.01 then
		flatDirection = Vector3.new(0, 0, -1)
	else
		flatDirection = flatDirection.Unit
	end
	local base = CFrame.lookAt(center, center + flatDirection)
	local motionWeight = if forceMotion then 0.9 else math.clamp(speed / 8, 0, 1)
	if motionWeight > 0.02 then
		figure.phase += dt * (3.8 + math.min(speed, 20) * 0.22)
	end
	local swing = math.sin(figure.phase) * math.rad(24) * motionWeight
	local bob = math.abs(math.sin(figure.phase)) * 0.08 * motionWeight
	figure.parts.Torso.CFrame = base * CFrame.new(0, bob, 0)
	figure.parts.Head.CFrame = base * CFrame.new(0, 1.36 + bob, 0)
	figure.parts.LeftArm.CFrame = base * CFrame.new(-0.91, 0.02 + bob, 0) * CFrame.Angles(swing, 0, 0)
	figure.parts.RightArm.CFrame = base * CFrame.new(0.91, 0.02 + bob, 0) * CFrame.Angles(-swing, 0, 0)
	figure.parts.LeftLeg.CFrame = base * CFrame.new(-0.37, -1.67 + bob, 0) * CFrame.Angles(-swing, 0, 0)
	figure.parts.RightLeg.CFrame = base * CFrame.new(0.37, -1.67 + bob, 0) * CFrame.Angles(swing, 0, 0)
	figure.highlight.Enabled = figure.near and strength > 0.02
	figure.highlight.FillTransparency = 0.93 - strength * 0.2
	figure.highlight.OutlineTransparency = 0.62 - strength * 0.58
	figure.billboard.Enabled = not figure.near and strength > 0.02
	local strokeTransparency = math.clamp(0.76 - strength * 0.72, 0.04, 0.72)
	for _, stroke in figure.strokes do
		stroke.Transparency = strokeTransparency
	end
end

local function hideEcho(figure: EchoFigure)
	figure.near = false
	figure.highlight.Enabled = false
	figure.billboard.Enabled = false
	for _, part in figure.parts do
		part.Transparency = 1
	end
end

local function hideOwnBlindOneVisual(character: Model?, hidden: boolean)
	local visual = character and character:FindFirstChild("BlindOneVisual")
	if hidden and visual then
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				if ownVisualParts[descendant] == nil then
					ownVisualParts[descendant] = descendant.LocalTransparencyModifier
				end
				descendant.LocalTransparencyModifier = 1
			elseif descendant:IsA("Light") then
				if ownVisualLights[descendant] == nil then
					ownVisualLights[descendant] = descendant.Enabled
				end
				descendant.Enabled = false
			elseif descendant:IsA("Highlight") then
				if ownVisualHighlights[descendant] == nil then
					ownVisualHighlights[descendant] = descendant.Enabled
				end
				descendant.Enabled = false
			end
		end
		return
	end
	for part, original in ownVisualParts do
		if part.Parent then
			part.LocalTransparencyModifier = original
		end
		ownVisualParts[part] = nil
	end
	for light, original in ownVisualLights do
		if light.Parent then
			light.Enabled = original
		end
		ownVisualLights[light] = nil
	end
	for highlight, original in ownVisualHighlights do
		if highlight.Parent then
			highlight.Enabled = original
		end
		ownVisualHighlights[highlight] = nil
	end
end

local function hideActualCharacter(character: Model, hidden: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if hidden then
			if hiddenNameplates[humanoid] == nil then
				hiddenNameplates[humanoid] = humanoid.DisplayDistanceType
			end
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		elseif hiddenNameplates[humanoid] ~= nil then
			humanoid.DisplayDistanceType = hiddenNameplates[humanoid]
			hiddenNameplates[humanoid] = nil
		end
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			if hidden then
				if hiddenParts[descendant] == nil then
					hiddenParts[descendant] = descendant.LocalTransparencyModifier
				end
				descendant.LocalTransparencyModifier = 1
			elseif hiddenParts[descendant] ~= nil then
				descendant.LocalTransparencyModifier = hiddenParts[descendant]
				hiddenParts[descendant] = nil
			end
		end
	end
end

-- Blindness must not depend on how bright the map happens to be. Hide the
-- generated world locally while keeping its collision/query geometry intact;
-- the close-range surface echoes can still raycast against invisible walls.
local hiddenMapParts: { [BasePart]: number } = {}
local hiddenMapEffects: { [Instance]: boolean } = {}
local hiddenMapTextures: { [Decal]: number } = {}
local savedVisionFog: {color: Color3, start: number, finish: number}? = nil
local pausedGrades: { [PostEffect]: boolean } = {}
local hiddenMap: Instance? = nil
local mapDescendantConnection: RBXScriptConnection? = nil

local function hideMapDescendant(descendant: Instance)
	if descendant:IsA("BasePart") then
		if hiddenMapParts[descendant] == nil then
			hiddenMapParts[descendant] = descendant.LocalTransparencyModifier
		end
		descendant.LocalTransparencyModifier = 1
	elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui")
		or descendant:IsA("Light") or descendant:IsA("ParticleEmitter")
		or descendant:IsA("Beam") or descendant:IsA("Highlight") then
		hiddenMapEffects[descendant] = (descendant :: any).Enabled
		;(descendant :: any).Enabled = false
	elseif descendant:IsA("Decal") then
		hiddenMapTextures[descendant] = descendant.Transparency
		descendant.Transparency = 1
	end
end

local function restoreHiddenMap()
	if mapDescendantConnection then
		mapDescendantConnection:Disconnect()
		mapDescendantConnection = nil
	end
	for mapPart, original in hiddenMapParts do
		if mapPart.Parent then
			mapPart.LocalTransparencyModifier = original
		end
		hiddenMapParts[mapPart] = nil
	end
	hiddenMap = nil
	for effect, enabled in hiddenMapEffects do
		if effect.Parent then (effect :: any).Enabled = enabled end
		hiddenMapEffects[effect] = nil
	end
	for texture, transparency in hiddenMapTextures do
		if texture.Parent then texture.Transparency = transparency end
		hiddenMapTextures[texture] = nil
	end
end

local function setMapBlindness(enabled: boolean)
	if not enabled then
		if savedVisionFog then
			Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = savedVisionFog.color, savedVisionFog.start, savedVisionFog.finish
			savedVisionFog = nil
			for effect, wasEnabled in pausedGrades do
				if effect.Parent then effect.Enabled = wasEnabled end
				pausedGrades[effect] = nil
			end
		end
		if hiddenMap then
			restoreHiddenMap()
		end
		return
	end
	if not savedVisionFog then
		savedVisionFog = {color = Lighting.FogColor, start = Lighting.FogStart, finish = Lighting.FogEnd}
	end
	-- The sky and hidden map stay black; the blue echoes retain their own color.
	Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.new(), 100000, 100001
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("PostEffect") and effect ~= vision then
			if pausedGrades[effect] == nil then pausedGrades[effect] = effect.Enabled end
			effect.Enabled = false
		end
	end
	local currentMap = Workspace:FindFirstChild("GeneratedMap")
	if currentMap == hiddenMap then
		return
	end
	restoreHiddenMap()
	if not currentMap then
		return
	end
	hiddenMap = currentMap
	for _, descendant in currentMap:GetDescendants() do
		hideMapDescendant(descendant)
	end
	mapDescendantConnection = currentMap.DescendantAdded:Connect(hideMapDescendant)
end

Players.PlayerRemoving:Connect(function(target)
	local figure = survivorFigures[target]
	if figure then
		figure.model:Destroy()
	end
	survivorFigures[target] = nil
end)

RunService.RenderStepped:Connect(function(dt)
	local roleValue = player:GetAttribute("Role")
	local role = if typeof(roleValue) == "string" then roleValue else ""
	local isBlindOne = role == "BlindOne"
	local now = os.clock()
	if role ~= "" and role ~= lastRole then
		lastRole = role
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
		task.spawn(playRoleReveal, isBlindOne)
	end
	vision.Enabled = isBlindOne
	setMapBlindness(isBlindOne)
	local ownCharacter = player.Character
	local ownRoot = ownCharacter and ownCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- The monster skin is deliberately huge and textured, but those same meshes
	-- must not sit inside the local first-person camera. This is client-only.
	hideOwnBlindOneVisual(ownCharacter, isBlindOne)
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
		local figure = survivorFigure(target)
		local character = target.Character
		if character then
			hideActualCharacter(character, isBlindOne)
		end
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local noiseValue = target:GetAttribute("Noise")
		local noise = if typeof(noiseValue) == "number" then noiseValue else 0
		local audible = false
		local strength = 0
		if isBlindOne and ownRoot and root and humanoid and humanoid.Health > 0
			and target:GetAttribute("Role") ~= "BlindOne" and noise >= Config.MonsterHearingFloor then
			-- The Blind One hears qualifying survivor noise anywhere on the map.
			-- Distance never suppresses the echo; silence is the only way to vanish.
			audible = true
			local loudness = math.clamp(noise / Config.NoiseWalk, 0.45, 1)
			strength = math.clamp(loudness, 0, 1)
		end
		-- No after-image: once the survivor's noise falls below the hearing floor,
		-- the outline vanishes with the meter instead of leaking their position.
		local shownStrength = if audible then strength else 0
		if isBlindOne and root and shownStrength > 0.02 then
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			poseEcho(figure, root.Position, root.CFrame.LookVector, speed, shownStrength, dt, false,
				if ownRoot then (root.Position-ownRoot.Position).Magnitude else math.huge)
		else
			hideEcho(figure)
		end
	end

	-- A thrown rock is deliberately indistinguishable from a survivor echo. The
	-- projectile may travel at 90 studs/sec, but its fake person is capped at a
	-- believable running speed and projected onto the floor.
	local seenRocks: { [BasePart]: boolean } = {}
	local serverNow = Workspace:GetServerTimeNow()
	local rockGroundParams = RaycastParams.new()
	rockGroundParams.FilterType = Enum.RaycastFilterType.Exclude
	rockGroundParams.IgnoreWater = true
	for _, tagged in CollectionService:GetTagged("Throwable") do
		if not tagged:IsA("BasePart") or tagged:GetAttribute("BlindOneDecoy") ~= true then
			continue
		end
		local untilValue = tagged:GetAttribute("BlindOneDecoyUntil")
		if typeof(untilValue) ~= "number" or untilValue <= serverNow then
			continue
		end
		seenRocks[tagged] = true
		local figure = rockFigure(tagged)
		if isBlindOne then
			if hiddenDecoyBalls[tagged] == nil then
				hiddenDecoyBalls[tagged] = tagged.LocalTransparencyModifier
			end
			tagged.LocalTransparencyModifier = 1
		elseif hiddenDecoyBalls[tagged] ~= nil then
			tagged.LocalTransparencyModifier = hiddenDecoyBalls[tagged]
			hiddenDecoyBalls[tagged] = nil
		end
		local strength = 0
		if isBlindOne and ownRoot then
			strength = math.clamp((untilValue - serverNow) / 1.2, 0, 1)
		end
		if strength > 0.02 then
			local velocity = tagged.AssemblyLinearVelocity
			local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
			local excluded: { Instance } = { tagged, soundFigures, geometrySense }
			if ownCharacter then
				table.insert(excluded, ownCharacter)
			end
			rockGroundParams.FilterDescendantsInstances = excluded
			local groundHit = workspace:Raycast(tagged.Position + Vector3.new(0, 5, 0), Vector3.new(0, -35, 0), rockGroundParams)
			local desiredPosition = if groundHit
				then Vector3.new(tagged.Position.X, groundHit.Position.Y + 2.55, tagged.Position.Z)
				else tagged.Position + Vector3.new(0, 2.55, 0)
			if not figure.position then
				figure.position = desiredPosition
			end
			local currentPosition = figure.position :: Vector3
			local flatDelta = Vector3.new(desiredPosition.X - currentPosition.X, 0, desiredPosition.Z - currentPosition.Z)
			local fakeRunSpeed = math.min(Config.SprintSpeed - 1, 16)
			local moving = flatDelta.Magnitude > 0.08
			local direction = figure.direction or tagged.CFrame.LookVector
			if moving then
				direction = flatDelta.Unit
				local step = math.min(flatDelta.Magnitude, fakeRunSpeed * dt)
				currentPosition += direction * step
			end
			currentPosition = Vector3.new(
				currentPosition.X,
				currentPosition.Y + (desiredPosition.Y - currentPosition.Y) * math.min(1, dt * 10),
				currentPosition.Z
			)
			figure.position = currentPosition
			figure.direction = direction
			poseEcho(
				figure,
				currentPosition,
				direction,
				if moving then fakeRunSpeed else math.min(flatVelocity.Magnitude, 3),
				strength,
				dt,
				moving,
				if ownRoot then (currentPosition-ownRoot.Position).Magnitude else math.huge
			)
		else
			hideEcho(figure)
		end
	end
	for rock, figure in rockFigures do
		if not seenRocks[rock] or not rock.Parent then
			if rock.Parent and hiddenDecoyBalls[rock] ~= nil then
				rock.LocalTransparencyModifier = hiddenDecoyBalls[rock]
			end
			hiddenDecoyBalls[rock] = nil
			figure.model:Destroy()
			rockFigures[rock] = nil
		end
	end

	if not isBlindOne then
		for part, original in hiddenParts do
			if part.Parent then
				part.LocalTransparencyModifier = original
			end
			hiddenParts[part] = nil
		end
		for humanoid, original in hiddenNameplates do
			if humanoid.Parent then
				humanoid.DisplayDistanceType = original
			end
			hiddenNameplates[humanoid] = nil
		end
		for rock, original in hiddenDecoyBalls do
			if rock.Parent then
				rock.LocalTransparencyModifier = original
			end
			hiddenDecoyBalls[rock] = nil
		end
	end
end)
