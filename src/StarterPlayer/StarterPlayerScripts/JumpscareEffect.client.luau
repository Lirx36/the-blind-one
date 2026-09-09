--!strict
-- Death jumpscare using a palette-compressed portrait embedded in the place.
-- No Roblox image upload or cloud asset permission is required.
local Players = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EmbeddedImage = require(script.Parent:WaitForChild("EmbeddedJumpscareImage"))

-- Add an uploaded stinger later without changing the effect code. The visual
-- jumpscare remains fully functional while this is empty.
local SCARE_SOUND = Config.JumpscareSound
local JUMPSCARE_DURATION = 1.05

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Jumpscare"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local black = Instance.new("Frame")
black.Name = "Blackout"
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BorderSizePixel = 0
black.ZIndex = 1
black.Parent = gui

local scareImage = Instance.new("ImageLabel")
scareImage.Name = "UploadedJumpscareFace"
scareImage.AnchorPoint = Vector2.new(0.5, 0.5)
scareImage.Position = UDim2.fromScale(0.5, 0.5)
scareImage.Size = UDim2.fromScale(1, 1)
scareImage.BackgroundTransparency = 1
scareImage.Image = ""
scareImage.ScaleType = Enum.ScaleType.Crop
scareImage.Visible = false
scareImage.ZIndex = 3
scareImage.Parent = gui
local scareImageScale = Instance.new("UIScale")
scareImageScale.Parent = scareImage

-- Offset color ghosts make the generated portrait feel like a corrupted
-- camera feed while keeping the white eyes and open maw readable.
local redGhost = scareImage:Clone()
redGhost.Name = "RedGhost"
redGhost.ImageColor3 = Color3.fromRGB(255, 34, 34)
redGhost.ImageTransparency = 0.7
redGhost.ZIndex = 2
redGhost.Parent = gui
local redGhostScale = redGhost:FindFirstChildOfClass("UIScale") :: UIScale

local cyanGhost = scareImage:Clone()
cyanGhost.Name = "CyanGhost"
cyanGhost.ImageColor3 = Color3.fromRGB(74, 227, 255)
cyanGhost.ImageTransparency = 0.74
cyanGhost.ZIndex = 2
cyanGhost.Parent = gui
local cyanGhostScale = cyanGhost:FindFirstChildOfClass("UIScale") :: UIScale

local imageReady = false
local embeddedEditable: EditableImage? = nil
do
	local ok, result = pcall(function()
		local created = AssetService:CreateEditableImage({
			Size = Vector2.new(EmbeddedImage.Width, EmbeddedImage.Height),
		})
		if not created then
			error("EditableImage memory budget exhausted")
		end

		local byteToPalette: { [number]: number } = {}
		for index = 1, #EmbeddedImage.Alphabet do
			byteToPalette[string.byte(EmbeddedImage.Alphabet, index)] = index
		end
		local pixels = buffer.create(EmbeddedImage.Width * EmbeddedImage.Height * 4)
		for y, row in EmbeddedImage.Rows do
			for x = 1, #row do
				local paletteIndex = byteToPalette[string.byte(row, x)]
				local packed = EmbeddedImage.Palette[paletteIndex]
				local offset = (((y - 1) * EmbeddedImage.Width) + (x - 1)) * 4
				buffer.writeu8(pixels, offset, bit32.rshift(packed, 16))
				buffer.writeu8(pixels, offset + 1, bit32.band(bit32.rshift(packed, 8), 0xFF))
				buffer.writeu8(pixels, offset + 2, bit32.band(packed, 0xFF))
				buffer.writeu8(pixels, offset + 3, 0xFF)
			end
		end
		created:WritePixelsBuffer(
			Vector2.zero,
			Vector2.new(EmbeddedImage.Width, EmbeddedImage.Height),
			pixels
		)
		local content = Content.fromObject(created)
		scareImage.ImageContent = content
		redGhost.ImageContent = content
		cyanGhost.ImageContent = content
		return created
	end)
	if ok then
		embeddedEditable = result :: EditableImage
		imageReady = true
	else
		warn("Embedded jumpscare image could not be created:", result)
	end
end

-- Used only if the killer disappears before the event reaches this client,
-- such as during a Rojo hot-sync restart.
local fallback = Instance.new("Frame")
fallback.Name = "FallbackFace"
fallback.AnchorPoint = Vector2.new(0.5, 0.5)
fallback.Position = UDim2.fromScale(0.5, 0.5)
fallback.Size = UDim2.fromScale(1, 1)
fallback.BackgroundTransparency = 1
fallback.Visible = false
fallback.ZIndex = 3
fallback.Parent = gui

local fallbackHead = Instance.new("Frame")
fallbackHead.AnchorPoint = Vector2.new(0.5, 0.5)
fallbackHead.Position = UDim2.fromScale(0.5, 0.52)
fallbackHead.Size = UDim2.fromScale(0.42, 0.78)
fallbackHead.BackgroundColor3 = Color3.fromRGB(8, 5, 8)
fallbackHead.BorderSizePixel = 0
fallbackHead.ZIndex = 3
fallbackHead.Parent = fallback
local fallbackHeadCorner = Instance.new("UICorner")
fallbackHeadCorner.CornerRadius = UDim.new(0.46, 0)
fallbackHeadCorner.Parent = fallbackHead

for _, x in { 0.39, 0.61 } do
	local eye = Instance.new("Frame")
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.Position = UDim2.fromScale(x, 0.39)
	eye.Size = UDim2.fromScale(0.09, 0.018)
	eye.BackgroundColor3 = Color3.fromRGB(220, 240, 244)
	eye.BorderSizePixel = 0
	eye.Rotation = if x < 0.5 then 9 else -9
	eye.ZIndex = 4
	eye.Parent = fallback
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.fromRGB(151, 206, 218)
	glow.Thickness = 5
	glow.Transparency = 0.42
	glow.Parent = eye
end

local fallbackMaw = Instance.new("Frame")
fallbackMaw.AnchorPoint = Vector2.new(0.5, 0.5)
fallbackMaw.Position = UDim2.fromScale(0.5, 0.64)
fallbackMaw.Size = UDim2.fromScale(0.075, 0.28)
fallbackMaw.BackgroundColor3 = Color3.fromRGB(70, 0, 3)
fallbackMaw.BorderSizePixel = 0
fallbackMaw.ZIndex = 4
fallbackMaw.Parent = fallback
local fallbackMawCorner = Instance.new("UICorner")
fallbackMawCorner.CornerRadius = UDim.new(0.45, 0)
fallbackMawCorner.Parent = fallbackMaw

local redFlash = Instance.new("Frame")
redFlash.Name = "ImpactFlash"
redFlash.Size = UDim2.fromScale(1, 1)
redFlash.BackgroundColor3 = Color3.fromRGB(128, 0, 4)
redFlash.BackgroundTransparency = 1
redFlash.BorderSizePixel = 0
redFlash.ZIndex = 10
redFlash.Parent = gui

local staticLines: { Frame } = {}
for index = 1, 13 do
	local line = Instance.new("Frame")
	line.Name = "Static" .. index
	line.BorderSizePixel = 0
	line.BackgroundColor3 = if index % 4 == 0
		then Color3.fromRGB(117, 5, 7)
		else Color3.fromRGB(211, 222, 219)
	line.BackgroundTransparency = 1
	line.ZIndex = 9
	line.Parent = gui
	table.insert(staticLines, line)
end

local function addVignetteEdge(name: string, size: UDim2, position: UDim2, rotation: number)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.Size = size
	edge.Position = position
	edge.BackgroundColor3 = Color3.new(0, 0, 0)
	edge.BorderSizePixel = 0
	edge.ZIndex = 8
	edge.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = edge
end

addVignetteEdge("VignetteTop", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90)
addVignetteEdge("VignetteBottom", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), -90)
addVignetteEdge("VignetteLeft", UDim2.fromScale(0.25, 1), UDim2.fromScale(0, 0), 0)
addVignetteEdge("VignetteRight", UDim2.fromScale(0.25, 1), UDim2.fromScale(0.75, 0), 180)

local sound = Instance.new("Sound")
sound.Name = "JumpscareStinger"
sound.Volume = 1.35
sound.PlaybackSpeed = 0.82
sound.SoundId = SCARE_SOUND
sound.Parent = gui

local activeSequence = 0

local function resetStatic()
	for _, line in staticLines do
		line.BackgroundTransparency = 1
	end
end

local function playJumpscare(sourcePosition: Vector3?)
	activeSequence += 1
	local sequence = activeSequence
	local _sourcePosition = sourcePosition -- retained for remote compatibility
	local hasUploadedImage = imageReady and embeddedEditable ~= nil

	gui.Enabled = true
	scareImage.Visible = hasUploadedImage
	redGhost.Visible = hasUploadedImage
	cyanGhost.Visible = hasUploadedImage
	scareImage.Position = UDim2.fromScale(0.5, 0.5)
	scareImage.Rotation = 0
	scareImageScale.Scale = 0.92
	redGhostScale.Scale = 0.92
	cyanGhostScale.Scale = 0.92
	redGhost.Position = UDim2.fromScale(0.494, 0.5)
	cyanGhost.Position = UDim2.fromScale(0.506, 0.5)
	fallback.Visible = not hasUploadedImage
	fallback.Position = UDim2.fromScale(0.5, 0.5)
	fallback.Size = UDim2.fromScale(0.62, 0.62)
	fallback.Rotation = 0
	black.BackgroundTransparency = 0
	redFlash.BackgroundTransparency = 0.08
	resetStatic()
	if SCARE_SOUND ~= "" then
		sound:Play()
	end

	local started = os.clock()
	while sequence == activeSequence do
		local elapsed = os.clock() - started
		local alpha = math.clamp(elapsed / JUMPSCARE_DURATION, 0, 1)
		if alpha >= 1 then
			break
		end
		local slam = 1 - (1 - alpha) ^ 4
		local jitter = (0.03 + slam * 0.12) * (1 - alpha * 0.35)

		if hasUploadedImage then
			local zoom = 0.82 + slam * 0.58
			scareImageScale.Scale = zoom
			redGhostScale.Scale = zoom
			cyanGhostScale.Scale = zoom
			scareImage.Position = UDim2.fromScale(
				0.5 + (math.random() - 0.5) * jitter * 0.12,
				0.5 + (math.random() - 0.5) * jitter * 0.12
			)
			scareImage.Rotation = (math.random() - 0.5) * 2.8 * slam
			local split = 0.004 + math.random() * 0.012 * slam
			redGhost.Position = UDim2.fromScale(0.5 - split, 0.5)
			cyanGhost.Position = UDim2.fromScale(0.5 + split, 0.5)
			redGhost.Rotation = scareImage.Rotation - 0.5
			cyanGhost.Rotation = scareImage.Rotation + 0.5
		else
			local scale = 0.62 + slam * 1.18
			fallback.Size = UDim2.fromScale(scale, scale)
			fallback.Position = UDim2.fromScale(
				0.5 + (math.random() - 0.5) * jitter * 0.18,
				0.5 + (math.random() - 0.5) * jitter * 0.18
			)
			fallback.Rotation = (math.random() - 0.5) * 4 * slam
		end

		redFlash.BackgroundTransparency = math.clamp(
			0.34 + alpha * 0.7 + math.sin(elapsed * 18) * 0.12,
			0.18,
			1
		)
		for index, line in staticLines do
			local visible = math.random() < 0.28 + slam * 0.36
			line.BackgroundTransparency = if visible then 0.32 + math.random() * 0.5 else 1
			line.Position = UDim2.fromScale(math.random() * 0.12 - 0.06, math.random())
			line.Size = UDim2.fromScale(0.88 + math.random() * 0.24, 0.001 + math.random() * 0.008)
			line.Rotation = if index % 3 == 0 then (math.random() - 0.5) * 3 else 0
		end
		RunService.RenderStepped:Wait()
	end

	if sequence ~= activeSequence then
		return
	end
	scareImage.Visible = false
	redGhost.Visible = false
	cyanGhost.Visible = false
	fallback.Visible = false
	resetStatic()
	redFlash.BackgroundTransparency = 1
	black.BackgroundTransparency = 0
	task.wait(0.22)
	for step = 1, 10 do
		if sequence ~= activeSequence then
			return
		end
		black.BackgroundTransparency = step / 10
		RunService.RenderStepped:Wait()
	end
	gui.Enabled = false
end

Remotes.Jumpscare.OnClientEvent:Connect(function(sourcePosition: Vector3?)
	task.spawn(playJumpscare, sourcePosition)
end)

-- Solo AI catches are non-lethal while StudioSafeMode is enabled. J previews
-- the exact production effect without changing server safety or player health.
if RunService:IsStudio() then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.J then
			task.spawn(playJumpscare, nil)
		end
	end)
end
