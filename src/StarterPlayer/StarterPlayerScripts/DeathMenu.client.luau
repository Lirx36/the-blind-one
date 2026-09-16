--!strict
local Responsive = require(game:GetService("ReplicatedStorage"):WaitForChild("ResponsiveUI"))
-- Post-jumpscare casualty terminal: three server-authoritative returns, a fixed-
-- distance third-person spectator camera, and a route back to the lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACCENT = Color3.fromRGB(137, 35, 30)
local ACCENT_BRIGHT = Color3.fromRGB(205, 65, 52)
local TEXT = Color3.fromRGB(206, 211, 206)
local MUTED = Color3.fromRGB(99, 112, 112)
local PANEL = Color3.fromRGB(3, 5, 5)
local BUTTON = Color3.fromRGB(9, 13, 13)
local DISABLED = Color3.fromRGB(29, 33, 33)
local SPECTATE_DISTANCE = 12
local SPECTATE_FOV = 68
local SPECTATE_BIND = "CasualtyTerminalSpectateCamera"

local gui = Instance.new("ScreenGui")
gui.Name = "CasualtyTerminal"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 19000
gui.Enabled = false
gui.Parent = playerGui

local blackout = Instance.new("Frame")
blackout.Name = "Blackout"
blackout.Size = UDim2.fromScale(1, 1)
blackout.BackgroundColor3 = Color3.new()
blackout.BorderSizePixel = 0
blackout.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Terminal"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.82, 0.72)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.ZIndex = 2
panel.Parent = blackout
local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(320, 430)
panelConstraint.MaxSize = Vector2.new(590, 610)
panelConstraint.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = ACCENT
panelStroke.Thickness = 1.3
panelStroke.Transparency = 0.08
panelStroke.Parent = panel

local rail = Instance.new("Frame")
rail.Name = "SignalRail"
rail.Position = UDim2.fromOffset(0, 28)
rail.Size = UDim2.new(0, 6, 0, 132)
rail.BackgroundColor3 = ACCENT_BRIGHT
rail.BorderSizePixel = 0
rail.ZIndex = 3
rail.Parent = panel
local railCorner = Instance.new("UICorner")
railCorner.CornerRadius = UDim.new(1, 0)
railCorner.Parent = rail

local eyebrow = Instance.new("TextLabel")
eyebrow.Position = UDim2.new(0, 28, 0, 25)
eyebrow.Size = UDim2.new(1, -56, 0, 18)
eyebrow.BackgroundTransparency = 1
eyebrow.Font = Enum.Font.GothamBold
eyebrow.Text = "CASUALTY TERMINAL  //  OPERATIVE STATUS"
eyebrow.TextColor3 = MUTED
eyebrow.TextSize = 10
eyebrow.TextXAlignment = Enum.TextXAlignment.Left
eyebrow.ZIndex = 3
eyebrow.Parent = panel

local title = Instance.new("TextLabel")
title.Position = UDim2.new(0, 28, 0, 49)
title.Size = UDim2.new(1, -56, 0, 52)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "YOU WERE HEARD"
title.TextColor3 = TEXT
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = panel
local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MinTextSize = 22
titleConstraint.MaxTextSize = 35
titleConstraint.Parent = title

local divider = Instance.new("Frame")
divider.Position = UDim2.new(0, 28, 0, 112)
divider.Size = UDim2.new(1, -56, 0, 1)
divider.BackgroundColor3 = ACCENT
divider.BorderSizePixel = 0
divider.ZIndex = 3
divider.Parent = panel

local messageBox = Instance.new("Frame")
messageBox.Position = UDim2.new(0, 28, 0, 132)
messageBox.Size = UDim2.new(1, -56, 0, 72)
messageBox.BackgroundColor3 = Color3.fromRGB(8, 13, 14)
messageBox.BorderSizePixel = 0
messageBox.ZIndex = 3
messageBox.Parent = panel
local messageCorner = Instance.new("UICorner")
messageCorner.CornerRadius = UDim.new(0, 9)
messageCorner.Parent = messageBox
local messageDot = Instance.new("Frame")
messageDot.AnchorPoint = Vector2.new(0.5, 0.5)
messageDot.Position = UDim2.new(0, 20, 0.5, 0)
messageDot.Size = UDim2.fromOffset(9, 9)
messageDot.BackgroundColor3 = ACCENT_BRIGHT
messageDot.BorderSizePixel = 0
messageDot.ZIndex = 4
messageDot.Parent = messageBox
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = messageDot
local message = Instance.new("TextLabel")
message.Position = UDim2.new(0, 38, 0, 0)
message.Size = UDim2.new(1, -50, 1, 0)
message.BackgroundTransparency = 1
message.Font = Enum.Font.Gotham
message.Text = "Vital signal lost. Select an available recovery protocol."
message.TextColor3 = Color3.fromRGB(151, 160, 158)
message.TextSize = 12
message.TextWrapped = true
message.TextXAlignment = Enum.TextXAlignment.Left
message.ZIndex = 4
message.Parent = messageBox

local optionsLabel = Instance.new("TextLabel")
optionsLabel.Position = UDim2.new(0, 28, 0, 224)
optionsLabel.Size = UDim2.new(1, -56, 0, 18)
optionsLabel.BackgroundTransparency = 1
optionsLabel.Font = Enum.Font.GothamBold
optionsLabel.Text = "RECOVERY OPTIONS"
optionsLabel.TextColor3 = MUTED
optionsLabel.TextSize = 10
optionsLabel.TextXAlignment = Enum.TextXAlignment.Left
optionsLabel.ZIndex = 3
optionsLabel.Parent = panel

local actions = Instance.new("Frame")
actions.Position = UDim2.new(0, 28, 0, 252)
actions.Size = UDim2.new(1, -56, 1, -294)
actions.BackgroundTransparency = 1
actions.ZIndex = 3
actions.Parent = panel
local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Vertical
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
actionLayout.Padding = UDim.new(0, 12)
actionLayout.Parent = actions

local function makeAction(name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 60)
	button.BackgroundColor3 = BUTTON
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = TEXT
	button.TextSize = 15
	button.ZIndex = 4
	button.Parent = actions
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = Color3.fromRGB(34, 43, 43)
	stroke.Thickness = 1
	stroke.Transparency = 0.22
	stroke.Parent = button
	return button
end

local respawnButton = makeAction("Respawn", "RESPAWN (3)")
local spectateButton = makeAction("Spectate", "SPECTATE  ›")
local lobbyButton = makeAction("ReturnLobby", "RETURN TO LOBBY")
lobbyButton.TextColor3 = Color3.fromRGB(202, 111, 98)

local footer = Instance.new("TextLabel")
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, -18)
footer.Size = UDim2.new(1, -56, 0, 18)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.GothamBold
footer.Text = "THE HOLLOW  //  DESCENT RECOVERY NETWORK"
footer.TextColor3 = Color3.fromRGB(52, 62, 62)
footer.TextSize = 9
footer.ZIndex = 3
footer.Parent = panel

local spectateOverlay = Instance.new("Frame")
spectateOverlay.Name = "SpectateOverlay"
spectateOverlay.Size = UDim2.fromScale(1, 1)
spectateOverlay.BackgroundTransparency = 1
spectateOverlay.Visible = false
spectateOverlay.ZIndex = 10
spectateOverlay.Parent = gui

local spectateHeader = Instance.new("Frame")
spectateHeader.AnchorPoint = Vector2.new(0.5, 0)
spectateHeader.Position = UDim2.new(0.5, 0, 0, 30)
spectateHeader.Size = UDim2.new(0.84, 0, 0, 76)
spectateHeader.BackgroundColor3 = Color3.fromRGB(2, 4, 4)
spectateHeader.BackgroundTransparency = 0.12
spectateHeader.BorderSizePixel = 0
spectateHeader.ZIndex = 11
spectateHeader.Parent = spectateOverlay
local headerConstraint = Instance.new("UISizeConstraint")
headerConstraint.MinSize = Vector2.new(310, 76)
headerConstraint.MaxSize = Vector2.new(720, 76)
headerConstraint.Parent = spectateHeader
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = spectateHeader
local headerStroke = Instance.new("UIStroke")
headerStroke.Color = ACCENT
headerStroke.Thickness = 1.2
headerStroke.Parent = spectateHeader

local watching = Instance.new("TextLabel")
watching.Position = UDim2.new(0, 18, 0, 9)
watching.Size = UDim2.new(1, -36, 0, 16)
watching.BackgroundTransparency = 1
watching.Font = Enum.Font.GothamBold
watching.Text = "SURVEILLANCE FEED  //  WATCHING"
watching.TextColor3 = MUTED
watching.TextSize = 9
watching.TextXAlignment = Enum.TextXAlignment.Left
watching.ZIndex = 12
watching.Parent = spectateHeader
local targetLabel = Instance.new("TextLabel")
targetLabel.Position = UDim2.new(0, 18, 0, 28)
targetLabel.Size = UDim2.new(1, -36, 0, 36)
targetLabel.BackgroundTransparency = 1
targetLabel.Font = Enum.Font.GothamBlack
targetLabel.Text = "NO ACTIVE SIGNALS"
targetLabel.TextColor3 = TEXT
targetLabel.TextScaled = true
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.ZIndex = 12
targetLabel.Parent = spectateHeader
local targetTextConstraint = Instance.new("UITextSizeConstraint")
targetTextConstraint.MinTextSize = 14
targetTextConstraint.MaxTextSize = 24
targetTextConstraint.Parent = targetLabel

local nav = Instance.new("Frame")
nav.AnchorPoint = Vector2.new(0.5, 1)
nav.Position = UDim2.new(0.5, 0, 1, -34)
nav.Size = UDim2.new(0.9, 0, 0, 64)
nav.BackgroundTransparency = 1
nav.ZIndex = 11
nav.Parent = spectateOverlay
local navConstraint = Instance.new("UISizeConstraint")
navConstraint.MinSize = Vector2.new(330, 64)
navConstraint.MaxSize = Vector2.new(650, 64)
navConstraint.Parent = nav

local function makeNavButton(name: string, text: string, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(3, 6, 6)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = TEXT
	button.TextSize = 18
	button.ZIndex = 12
	button.Parent = nav
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Thickness = 1
	stroke.Parent = button
	return button
end

local previousButton = makeNavButton("Previous", "‹", UDim2.fromScale(0, 0), UDim2.new(0, 64, 1, 0))
local stopButton = makeNavButton("Stop", "STOP SPECTATING", UDim2.new(0, 76, 0, 0), UDim2.new(1, -152, 1, 0))
local nextButton = makeNavButton("Next", "›", UDim2.new(1, -64, 0, 0), UDim2.new(0, 64, 1, 0))

type SpectateTarget = {
	humanoid: Humanoid,
	label: string,
	sortKey: string,
}

local targets: { SpectateTarget } = {}
local targetIndex = 0
local spectating = false
local switchQueued = false
local requestPending = false
local hiddenScreens: { [ScreenGui]: boolean } = {}

local function setPlayerControlsEnabled(enabled: boolean)
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then return end
	local ok, module = pcall(require, playerModule)
	if ok and module and module.GetControls then
		local controls = module:GetControls()
		if enabled then controls:Enable() else controls:Disable() end
	end
end

local function setCoreVisible(visible: boolean)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, visible) end)
	pcall(function() StarterGui:SetCore("TopbarEnabled", visible) end)
	if visible then
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	end
end

local function hideGameplayScreens()
	table.clear(hiddenScreens)
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child ~= gui and child.Name ~= "DeathJumpscare" then
			hiddenScreens[child] = child.Enabled
			child.Enabled = false
		end
	end
end

local function restoreGameplayScreens()
	for screen, wasEnabled in hiddenScreens do
		if screen.Parent then screen.Enabled = wasEnabled end
	end
	table.clear(hiddenScreens)
end

local function updateRespawnButton()
	local remaining = math.max(0, tonumber(player:GetAttribute("RespawnsRemaining")) or 0)
	respawnButton.Text = ("RESPAWN (%d)"):format(remaining)
	respawnButton.Active = remaining > 0 and not requestPending
	respawnButton.BackgroundColor3 = if remaining > 0 then BUTTON else DISABLED
	respawnButton.TextColor3 = if remaining > 0 then TEXT else Color3.fromRGB(80, 85, 84)
	local stroke = respawnButton:FindFirstChild("Outline")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = if remaining > 0 then ACCENT else Color3.fromRGB(42, 45, 45)
	end
end

local function collectTargets(): { SpectateTarget }
	local collected: { SpectateTarget } = {}
	local hasHumanBlindOne = false
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player and candidate:GetAttribute("InMatch") == true
			and candidate:GetAttribute("Escaped") ~= true then
			local character = candidate.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local blindOne = candidate:GetAttribute("Role") == "BlindOne"
				hasHumanBlindOne = hasHumanBlindOne or blindOne
				table.insert(collected, {
					humanoid = humanoid,
					label = if blindOne then "THE BLIND ONE  //  " .. candidate.Name else "SURVIVOR  //  " .. candidate.Name,
					sortKey = (if blindOne then "2" else "1") .. string.lower(candidate.Name),
				})
			end
		end
	end
	if not hasHumanBlindOne then
		local bot = workspace:FindFirstChild("TheBlindOne")
		local humanoid = bot and bot:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(collected, {
				humanoid = humanoid,
				label = "THE BLIND ONE  //  BOT",
				sortKey = "2bot",
			})
		end
	end
	table.sort(collected, function(a, b) return a.sortKey < b.sortKey end)
	return collected
end

local function targetIsValid(target: SpectateTarget?): boolean
	return target ~= nil and target.humanoid.Parent ~= nil and target.humanoid.Health > 0
end

local function applyTarget(index: number)
	targets = collectTargets()
	if #targets == 0 then
		targetIndex = 0
		targetLabel.Text = "NO ACTIVE SIGNALS"
		return
	end
	targetIndex = ((index - 1) % #targets) + 1
	local target = targets[targetIndex]
	targetLabel.Text = target.label
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = target.humanoid
		camera.FieldOfView = SPECTATE_FOV
	end
end

local function stopSpectating()
	if spectating then RunService:UnbindFromRenderStep(SPECTATE_BIND) end
	spectating = false
	player:SetAttribute("Spectating", false)
	spectateOverlay.Visible = false
	blackout.Visible = true
	panel.Visible = true
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 70
	end
end

local function beginSpectating()
	if spectating then return end
	spectating = true
	player:SetAttribute("Spectating", true)
	panel.Visible = false
	blackout.Visible = false
	spectateOverlay.Visible = true
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = SPECTATE_DISTANCE
	player.CameraMaxZoomDistance = SPECTATE_DISTANCE
	applyTarget(1)
	RunService:BindToRenderStep(SPECTATE_BIND, Enum.RenderPriority.Camera.Value - 2, function()
		if not spectating then return end
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = SPECTATE_DISTANCE
		player.CameraMaxZoomDistance = SPECTATE_DISTANCE
		local target = targets[targetIndex]
		if not targetIsValid(target) then
			if not switchQueued then
				switchQueued = true
				task.defer(function()
					applyTarget(math.max(targetIndex, 1))
					switchQueued = false
				end)
			end
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = target.humanoid
			camera.FieldOfView = SPECTATE_FOV
		end
	end)
end

local function showMenu()
	if player:GetAttribute("AwaitingDeathChoice") ~= true then return end
	if spectating then stopSpectating() end
	local escaped = player:GetAttribute("RecoveryContext") == "Escape"
	gui.Enabled = true
	blackout.Visible = true
	panel.Visible = true
	spectateOverlay.Visible = false
	eyebrow.Text = if escaped then "EXTRACTION TERMINAL  //  OPERATIVE STATUS"
		else "CASUALTY TERMINAL  //  OPERATIVE STATUS"
	title.Text = if escaped then "YOU ESCAPED THE HOLLOW" else "YOU WERE HEARD"
	titleConstraint.MinTextSize = if escaped then 15 else 22
	message.Text = if escaped then "Extraction confirmed. Select your next protocol."
		else "Vital signal lost. Select an available recovery protocol."
	optionsLabel.Text = if escaped then "POST-ESCAPE OPTIONS" else "RECOVERY OPTIONS"
	message.TextColor3 = Color3.fromRGB(151, 160, 158)
	requestPending = false
	updateRespawnButton()
	hideGameplayScreens()
	setCoreVisible(false)
	setPlayerControlsEnabled(false)
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local camera = workspace.CurrentCamera
	if camera then camera.CameraType = Enum.CameraType.Scriptable end
end

local function closeMenuForRespawn(newCharacter: Model?)
	if spectating then RunService:UnbindFromRenderStep(SPECTATE_BIND) end
	spectating = false
	player:SetAttribute("Spectating", false)
	gui.Enabled = false
	requestPending = false
	restoreGameplayScreens()
	setCoreVisible(true)
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	-- Spectating points CameraSubject at somebody else's Humanoid. CameraMode by
	-- itself does not replace that subject, so explicitly hand the camera back to
	-- the newly respawned character.
	local character = newCharacter or player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if camera and humanoid then
		camera.CameraSubject = humanoid
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
	setPlayerControlsEnabled(true)
end

respawnButton.MouseButton1Click:Connect(function()
	local remaining = math.max(0, tonumber(player:GetAttribute("RespawnsRemaining")) or 0)
	if requestPending or remaining <= 0 or player:GetAttribute("AwaitingDeathChoice") ~= true then return end
	requestPending = true
	message.Text = "Reconstructing operative signal..."
	updateRespawnButton()
	Remotes.DeathAction:FireServer("Respawn")
end)

spectateButton.MouseButton1Click:Connect(beginSpectating)
lobbyButton.MouseButton1Click:Connect(function()
	if requestPending or player:GetAttribute("AwaitingDeathChoice") ~= true then return end
	requestPending = true
	message.Text = "Routing operative back to the descent lobby..."
	message.TextColor3 = TEXT
	updateRespawnButton()
	Remotes.DeathAction:FireServer("ReturnLobby")
end)

previousButton.MouseButton1Click:Connect(function() applyTarget(targetIndex - 1) end)
nextButton.MouseButton1Click:Connect(function() applyTarget(targetIndex + 1) end)
stopButton.MouseButton1Click:Connect(stopSpectating)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not spectating then return end
	if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
		applyTarget(targetIndex - 1)
	elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
		applyTarget(targetIndex + 1)
	elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
		stopSpectating()
	end
end)

Remotes.DeathAction.OnClientEvent:Connect(function(action: any, detail: any)
	if action ~= "Error" then return end
	requestPending = false
	message.Text = if typeof(detail) == "string" then detail else "RECOVERY NETWORK UNAVAILABLE"
	message.TextColor3 = Color3.fromRGB(221, 92, 77)
	updateRespawnButton()
end)

player:GetAttributeChangedSignal("RespawnsRemaining"):Connect(updateRespawnButton)
player:GetAttributeChangedSignal("AwaitingDeathChoice"):Connect(function()
	if player:GetAttribute("AwaitingDeathChoice") == true
		and player:GetAttribute("RecoveryContext") == "Escape" then
		task.defer(showMenu)
	end
end)

local function watchDeath(character: Model)
	player:SetAttribute("DeathJumpscareFinished", false)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.spawn(function()
			local deadline = os.clock() + 3.5
			repeat task.wait(0.05) until (player:GetAttribute("DeathJumpscareFinished") == true
				and player:GetAttribute("AwaitingDeathChoice") == true) or os.clock() >= deadline
			if player.Character == character and player:GetAttribute("AwaitingDeathChoice") == true then
				showMenu()
			end
		end)
	end)
end

player.CharacterAdded:Connect(function(character)
	if gui.Enabled or spectating then closeMenuForRespawn(character) end
	watchDeath(character)
end)
if player.Character then task.spawn(watchDeath, player.Character) end

panelConstraint:Destroy()
local terminalScale = Responsive.Scale(panel)
Responsive.Watch(gui, function(size)
	-- This ScreenGui owns the full-screen death blackout. Responsive.Watch uses
	-- CoreUISafeInsets by default for ordinary menus, which leaves the topbar
	-- strip uncovered; the centered terminal already scales safely on its own.
	gui.ScreenInsets = Enum.ScreenInsets.None
	local width = math.min(590, size.X-24)
	panel.Size = UDim2.fromOffset(width, 570)
	terminalScale.Scale = math.min(1,(size.X-24)/width,(size.Y-24)/570)
	navConstraint.MinSize = Vector2.new(0, 56)
	headerConstraint.MinSize = Vector2.new(0, 60)
	nav.Position = UDim2.new(0.5, 0, 1, -12)
	spectateHeader.Position = UDim2.new(0.5, 0, 0, 8)
end)
