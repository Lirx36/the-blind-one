--!strict
-- A short, monster-facing death sting. It uses the actual Blind One whenever
-- possible and falls back to its signature white eyes if no hunter is present.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local rng = Random.new()
local jumpscaring = false

local gui = Instance.new("ScreenGui")
gui.Name = "DeathJumpscare"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 20000
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local blackout = Instance.new("Frame")
blackout.Size = UDim2.fromScale(1, 1)
blackout.BackgroundColor3 = Color3.new()
blackout.BackgroundTransparency = 1
blackout.BorderSizePixel = 0
blackout.ZIndex = 1
blackout.Parent = gui

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(111, 5, 3)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 2
flash.Parent = gui

local fallbackFace = Instance.new("Frame")
fallbackFace.AnchorPoint = Vector2.new(0.5, 0.5)
fallbackFace.Position = UDim2.fromScale(0.5, 0.46)
fallbackFace.Size = UDim2.fromOffset(430, 540)
fallbackFace.BackgroundColor3 = Color3.fromRGB(2, 3, 3)
fallbackFace.BackgroundTransparency = 0.05
fallbackFace.BorderSizePixel = 0
fallbackFace.Visible = false
fallbackFace.ZIndex = 3
fallbackFace.Parent = gui
local faceCorner = Instance.new("UICorner")
faceCorner.CornerRadius = UDim.new(0.46, 0)
faceCorner.Parent = fallbackFace
for _, x in { 0.38, 0.62 } do
	local eye = Instance.new("Frame")
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.Position = UDim2.fromScale(x, 0.34)
	eye.Size = UDim2.fromOffset(56, 15)
	eye.BackgroundColor3 = Color3.fromRGB(247, 250, 239)
	eye.BorderSizePixel = 0
	eye.ZIndex = 4
	eye.Parent = fallbackFace
	local eyeCorner = Instance.new("UICorner")
	eyeCorner.CornerRadius = UDim.new(1, 0)
	eyeCorner.Parent = eye
	local eyeStroke = Instance.new("UIStroke")
	eyeStroke.Color = Color3.new(1, 1, 1)
	eyeStroke.Thickness = 8
	eyeStroke.Transparency = 0.55
	eyeStroke.Parent = eye
end

local deathText = Instance.new("TextLabel")
deathText.AnchorPoint = Vector2.new(0.5, 1)
deathText.Position = UDim2.new(0.5, 0, 1, -70)
deathText.Size = UDim2.fromOffset(620, 64)
deathText.BackgroundTransparency = 1
deathText.Font = Enum.Font.GothamBlack
deathText.Text = "IT HEARD YOU"
deathText.TextColor3 = Color3.fromRGB(223, 222, 208)
deathText.TextSize = 34
deathText.TextStrokeColor3 = Color3.fromRGB(61, 0, 0)
deathText.TextStrokeTransparency = 0.15
deathText.TextTransparency = 1
deathText.ZIndex = 8
deathText.Parent = gui

local glitches = {}
for _ = 1, 12 do
	local line = Instance.new("Frame")
	line.BackgroundColor3 = if rng:NextNumber() > 0.55 then Color3.fromRGB(198, 205, 194) else Color3.fromRGB(125, 12, 8)
	line.BorderSizePixel = 0
	line.BackgroundTransparency = 1
	line.ZIndex = 7
	line.Parent = gui
	table.insert(glitches, line)
end

local sting = Instance.new("Sound")
sting.Name = "BlindOneDeathSting"
sting.SoundId = "rbxassetid://9113985598"
sting.Volume = 1
sting.PlaybackSpeed = 0.92
sting.Parent = SoundService
local impact = Instance.new("Sound")
impact.Name = "BlindOneDeathImpact"
impact.SoundId = "rbxassetid://9116889970"
impact.Volume = 0.62
impact.PlaybackSpeed = 0.8
impact.Parent = SoundService

local function hunterHead(): BasePart?
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player and candidate:GetAttribute("Role") == "BlindOne" then
			local head = candidate.Character and candidate.Character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then return head end
		end
	end
	local bot = workspace:FindFirstChild("TheBlindOne")
	local head = bot and bot:FindFirstChild("Head", true)
	return if head and head:IsA("BasePart") then head else nil
end

local function runJumpscare()
	if jumpscaring then return end
	if player:GetAttribute("InMatch") ~= true or player:GetAttribute("Role") == "BlindOne" then
		player:SetAttribute("DeathJumpscareFinished", true)
		return
	end
	jumpscaring = true
	player:SetAttribute("DeathJumpscareFinished", false)
	gui.Enabled = true
	blackout.BackgroundTransparency = 0.42
	flash.BackgroundTransparency = 0.3
	deathText.TextTransparency = 0
	UserInputService.MouseIconEnabled = false
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

	local target = hunterHead()
	fallbackFace.Visible = target == nil
	sting.TimePosition = 0
	impact.TimePosition = 0
	sting:Play()
	impact:Play()

	local started = os.clock()
	RunService:BindToRenderStep("BlindOneDeathJumpscare", Enum.RenderPriority.Camera.Value + 250, function()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local elapsed = os.clock() - started
		local intensity = math.clamp(1 - elapsed / 1.45, 0.15, 1)
		local shake = Vector3.new(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.08, 0.08)) * intensity
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 61 + math.sin(elapsed * 42) * 5 * intensity
		if target and target.Parent then
			local facePosition = target.Position + target.CFrame.LookVector * 1.55 + shake
			camera.CFrame = CFrame.lookAt(facePosition, target.Position + Vector3.new(0, 0.05, 0))
		end
		for _, line in glitches do
			line.Position = UDim2.fromScale(rng:NextNumber(-0.05, 0.85), rng:NextNumber())
			line.Size = UDim2.fromScale(rng:NextNumber(0.12, 0.65), rng:NextNumber(0.002, 0.015))
			line.BackgroundTransparency = rng:NextNumber(0.18, 0.78)
		end
		flash.BackgroundTransparency = if math.floor(elapsed * 22) % 4 == 0 then 0.24 else 0.82
	end)

	task.wait(1.35)
	RunService:UnbindFromRenderStep("BlindOneDeathJumpscare")
	TweenService:Create(blackout, TweenInfo.new(0.16), { BackgroundTransparency = 0 }):Play()
	flash.BackgroundTransparency = 1
	deathText.TextTransparency = 1
	for _, line in glitches do line.BackgroundTransparency = 1 end
	task.wait(0.65)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		if humanoid then camera.CameraSubject = humanoid end
	end
	sting:Stop()
	impact:Stop()
	-- The casualty terminal listens for this before taking over the same black
	-- screen, preventing a one-frame flash of the dead character or normal HUD.
	player:SetAttribute("DeathJumpscareFinished", true)
	task.wait(0.08)
	gui.Enabled = false
	blackout.BackgroundTransparency = 1
	fallbackFace.Visible = false
	jumpscaring = false
end

local function bindCharacter(character: Model)
	player:SetAttribute("DeathJumpscareFinished", false)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function() task.spawn(runJumpscare) end)
end
if player.Character then task.spawn(bindCharacter, player.Character) end
player.CharacterAdded:Connect(bindCharacter)
