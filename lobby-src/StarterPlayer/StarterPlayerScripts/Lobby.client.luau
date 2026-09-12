--!strict
-- Title screen, physical hub guidance, and queue configuration UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local actionRemote = Remotes.LobbyAction

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 200
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent: Instance, value: string, size: number, font: Enum.Font): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = value
	item.TextSize = size
	item.Font = font
	item.TextColor3 = Color3.fromRGB(221, 227, 224)
	item.TextStrokeColor3 = Color3.new()
	item.TextStrokeTransparency = 0.35
	item.Parent = parent
	return item
end

local function button(parent: Instance, value: string, position: UDim2, size: UDim2): TextButton
	local item = Instance.new("TextButton")
	item.Position = position
	item.Size = size
	item.BackgroundColor3 = Color3.fromRGB(12, 16, 17)
	item.BackgroundTransparency = 0.08
	item.BorderSizePixel = 0
	item.AutoButtonColor = false
	item.Text = value
	item.TextSize = 14
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = Color3.fromRGB(210, 219, 216)
	item.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(93, 116, 118)
	stroke.Transparency = 0.42
	stroke.Parent = item
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 8)
	rounded.Parent = item
	item.MouseEnter:Connect(function() TweenService:Create(item, TweenInfo.new(0.14), { BackgroundColor3 = Color3.fromRGB(30, 38, 39) }):Play() end)
	item.MouseLeave:Connect(function() TweenService:Create(item, TweenInfo.new(0.14), { BackgroundColor3 = Color3.fromRGB(12, 16, 17) }):Play() end)
	return item
end

local menuShade = Instance.new("Frame")
menuShade.Size = UDim2.fromScale(1, 1)
menuShade.BackgroundColor3 = Color3.new()
menuShade.BackgroundTransparency = 0.3
menuShade.BorderSizePixel = 0
menuShade.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.02),
	NumberSequenceKeypoint.new(0.48, 0.35),
	NumberSequenceKeypoint.new(1, 0.08),
})
gradient.Parent = menuShade

local menu = Instance.new("CanvasGroup")
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 70, 0.5, 0)
menu.Size = UDim2.fromOffset(510, 430)
menu.BackgroundTransparency = 1
menu.Parent = menuShade
local eyebrow = text(menu, "AN ANALOG HORROR EXPERIENCE", 11, Enum.Font.GothamMedium)
eyebrow.Position = UDim2.fromOffset(4, 38)
eyebrow.Size = UDim2.fromOffset(470, 20)
eyebrow.TextXAlignment = Enum.TextXAlignment.Left
eyebrow.TextColor3 = Color3.fromRGB(129, 146, 146)
local title = text(menu, "THE\nBLIND ONE", 58, Enum.Font.Garamond)
title.Position = UDim2.fromOffset(0, 60)
title.Size = UDim2.fromOffset(490, 145)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Top
title.TextColor3 = Color3.fromRGB(199, 35, 29)
title.TextStrokeTransparency = 0.12
local rule = Instance.new("Frame")
rule.Position = UDim2.fromOffset(2, 213)
rule.Size = UDim2.fromOffset(370, 2)
rule.BackgroundColor3 = Color3.fromRGB(161, 31, 26)
rule.BorderSizePixel = 0
rule.Parent = menu
local tagline = text(menu, "It cannot see you.  It can hear everything.", 15, Enum.Font.Garamond)
tagline.Position = UDim2.fromOffset(4, 232)
tagline.Size = UDim2.fromOffset(450, 30)
tagline.TextXAlignment = Enum.TextXAlignment.Left
tagline.TextColor3 = Color3.fromRGB(168, 175, 171)
local playButton = button(menu, "PLAY", UDim2.fromOffset(2, 292), UDim2.fromOffset(250, 58))
playButton.TextSize = 18

local hubHint = Instance.new("CanvasGroup")
hubHint.AnchorPoint = Vector2.new(0.5, 0)
hubHint.Position = UDim2.new(0.5, 0, 0, 26)
hubHint.Size = UDim2.fromOffset(650, 76)
hubHint.BackgroundColor3 = Color3.fromRGB(5, 8, 9)
hubHint.BackgroundTransparency = 0.2
hubHint.BorderSizePixel = 0
hubHint.Visible = false
hubHint.Parent = gui
local hintTitle = text(hubHint, "THE DESCENT LOBBY", 23, Enum.Font.Garamond)
hintTitle.Size = UDim2.new(1, 0, 0, 38)
local hintBody = text(hubHint, "Enter a private module with friends, or walk onto PUBLIC DESCENT to match with anyone.", 12, Enum.Font.GothamMedium)
hintBody.Position = UDim2.fromOffset(10, 37)
hintBody.Size = UDim2.new(1, -20, 0, 28)
hintBody.TextColor3 = Color3.fromRGB(142, 159, 159)

local panelShadow = Instance.new("Frame")
panelShadow.AnchorPoint = Vector2.new(1, 0.5)
panelShadow.Position = UDim2.new(1, -17, 0.5, 10)
panelShadow.Size = UDim2.fromOffset(470, 640)
panelShadow.BackgroundColor3 = Color3.new()
panelShadow.BackgroundTransparency = 0.35
panelShadow.BorderSizePixel = 0
panelShadow.Visible = false
panelShadow.Parent = gui
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 18)
shadowCorner.Parent = panelShadow

local panel = Instance.new("CanvasGroup")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -24, 0.5, 0)
panel.Size = UDim2.fromOffset(470, 640)
panel.BackgroundColor3 = Color3.fromRGB(6, 10, 12)
panel.BackgroundTransparency = 0.025
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 18)
panelCorner.Parent = panel
local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 22, 26)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(7, 12, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 7, 9)),
})
panelGradient.Rotation = 90
panelGradient.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(90, 205, 219)
panelStroke.Transparency = 0.18
panelStroke.Thickness = 1.4
panelStroke.Parent = panel

local headerGlow = Instance.new("Frame")
headerGlow.Size = UDim2.fromOffset(6, 132)
headerGlow.BackgroundColor3 = Color3.fromRGB(90, 205, 219)
headerGlow.BorderSizePixel = 0
headerGlow.Parent = panel
local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(0, 18)
glowCorner.Parent = headerGlow
local headerLine = Instance.new("Frame")
headerLine.Position = UDim2.fromOffset(24, 84)
headerLine.Size = UDim2.fromOffset(422, 1)
headerLine.BackgroundColor3 = Color3.fromRGB(90, 205, 219)
headerLine.BackgroundTransparency = 0.25
headerLine.BorderSizePixel = 0
headerLine.Parent = panel

local panelEyebrow = text(panel, "SECURE MATCH TERMINAL  //  HOST CONTROL", 10, Enum.Font.GothamBold)
panelEyebrow.Position = UDim2.fromOffset(24, 18)
panelEyebrow.Size = UDim2.fromOffset(390, 16)
panelEyebrow.TextXAlignment = Enum.TextXAlignment.Left
panelEyebrow.TextColor3 = Color3.fromRGB(123, 153, 158)
local liveDot = Instance.new("Frame")
liveDot.Position = UDim2.fromOffset(426, 20)
liveDot.Size = UDim2.fromOffset(8, 8)
liveDot.BackgroundColor3 = Color3.fromRGB(90, 205, 219)
liveDot.BorderSizePixel = 0
liveDot.Parent = panel
local liveCorner = Instance.new("UICorner")
liveCorner.CornerRadius = UDim.new(1, 0)
liveCorner.Parent = liveDot
local panelTitle = text(panel, "PRIVATE ELEVATOR 01", 27, Enum.Font.GothamBlack)
panelTitle.Position = UDim2.fromOffset(24, 39)
panelTitle.Size = UDim2.fromOffset(422, 38)
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.TextStrokeTransparency = 0.7

local statusCard = Instance.new("Frame")
statusCard.Position = UDim2.fromOffset(24, 96)
statusCard.Size = UDim2.fromOffset(422, 42)
statusCard.BackgroundColor3 = Color3.fromRGB(15, 23, 26)
statusCard.BackgroundTransparency = 0.08
statusCard.BorderSizePixel = 0
statusCard.Parent = panel
local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 9)
statusCorner.Parent = statusCard
local statusDot = Instance.new("Frame")
statusDot.Position = UDim2.fromOffset(14, 16)
statusDot.Size = UDim2.fromOffset(9, 9)
statusDot.BackgroundColor3 = Color3.fromRGB(90, 205, 219)
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard
local statusDotCorner = Instance.new("UICorner")
statusDotCorner.CornerRadius = UDim.new(1, 0)
statusDotCorner.Parent = statusDot
local panelStatus = text(statusCard, "Waiting for a secure party...", 11, Enum.Font.GothamMedium)
panelStatus.Position = UDim2.fromOffset(34, 4)
panelStatus.Size = UDim2.fromOffset(374, 34)
panelStatus.TextXAlignment = Enum.TextXAlignment.Left
panelStatus.TextColor3 = Color3.fromRGB(164, 181, 182)

local rosterTitle = text(panel, "OPERATIVE ROSTER", 10, Enum.Font.GothamBold)
rosterTitle.Position = UDim2.fromOffset(24, 151)
rosterTitle.Size = UDim2.fromOffset(240, 18)
rosterTitle.TextXAlignment = Enum.TextXAlignment.Left
rosterTitle.TextColor3 = Color3.fromRGB(132, 154, 157)
local occupancy = text(panel, "0 / 4 READY", 10, Enum.Font.GothamBold)
occupancy.Position = UDim2.fromOffset(298, 151)
occupancy.Size = UDim2.fromOffset(148, 18)
occupancy.TextXAlignment = Enum.TextXAlignment.Right
occupancy.TextColor3 = Color3.fromRGB(90, 205, 219)

local rosterBox = Instance.new("ScrollingFrame")
rosterBox.Position = UDim2.fromOffset(24, 174)
rosterBox.Size = UDim2.fromOffset(422, 220)
rosterBox.BackgroundColor3 = Color3.fromRGB(3, 7, 9)
rosterBox.BackgroundTransparency = 0.2
rosterBox.BorderSizePixel = 0
rosterBox.ScrollBarThickness = 3
rosterBox.ScrollBarImageColor3 = Color3.fromRGB(90, 205, 219)
rosterBox.CanvasSize = UDim2.fromOffset(0, 400)
rosterBox.Parent = panel
local rosterCorner = Instance.new("UICorner")
rosterCorner.CornerRadius = UDim.new(0, 10)
rosterCorner.Parent = rosterBox
local rosterPadding = Instance.new("UIPadding")
rosterPadding.PaddingTop = UDim.new(0, 7)
rosterPadding.PaddingLeft = UDim.new(0, 7)
rosterPadding.PaddingRight = UDim.new(0, 7)
rosterPadding.Parent = rosterBox

type RosterRow = { frame: Frame, slot: TextLabel, name: TextLabel, badge: TextLabel }
local roster: { RosterRow } = {}
for index = 1, 10 do
	local row = Instance.new("Frame")
	row.Name = "Slot" .. index
	row.Position = UDim2.fromOffset(0, (index - 1) * 39)
	row.Size = UDim2.new(1, -14, 0, 34)
	row.BackgroundColor3 = Color3.fromRGB(15, 22, 25)
	row.BackgroundTransparency = 0.18
	row.BorderSizePixel = 0
	row.Parent = rosterBox
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 7)
	rowCorner.Parent = row
	local slot = text(row, string.format("%02d", index), 10, Enum.Font.RobotoMono)
	slot.Position = UDim2.fromOffset(11, 0)
	slot.Size = UDim2.fromOffset(28, 34)
	slot.TextXAlignment = Enum.TextXAlignment.Left
	slot.TextColor3 = Color3.fromRGB(83, 107, 111)
	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(40, 8)
	divider.Size = UDim2.fromOffset(1, 18)
	divider.BackgroundColor3 = Color3.fromRGB(60, 78, 82)
	divider.BackgroundTransparency = 0.35
	divider.BorderSizePixel = 0
	divider.Parent = row
	local nameLabel = text(row, "VACANT SLOT", 12, Enum.Font.GothamMedium)
	nameLabel.Position = UDim2.fromOffset(53, 0)
	nameLabel.Size = UDim2.fromOffset(245, 34)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(78, 94, 97)
	local badge = text(row, "EMPTY", 9, Enum.Font.GothamBold)
	badge.Position = UDim2.new(1, -92, 0, 0)
	badge.Size = UDim2.fromOffset(80, 34)
	badge.TextXAlignment = Enum.TextXAlignment.Right
	badge.TextColor3 = Color3.fromRGB(67, 82, 85)
	table.insert(roster, { frame = row, slot = slot, name = nameLabel, badge = badge })
end

local settingsTitle = text(panel, "MATCH PARAMETERS", 10, Enum.Font.GothamBold)
settingsTitle.Position = UDim2.fromOffset(24, 409)
settingsTitle.Size = UDim2.fromOffset(240, 18)
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.TextColor3 = Color3.fromRGB(132, 154, 157)
local capacityCard = Instance.new("Frame")
capacityCard.Position = UDim2.fromOffset(24, 434)
capacityCard.Size = UDim2.fromOffset(202, 58)
capacityCard.BackgroundColor3 = Color3.fromRGB(12, 18, 21)
capacityCard.BorderSizePixel = 0
capacityCard.Parent = panel
local capacityCorner = Instance.new("UICorner")
capacityCorner.CornerRadius = UDim.new(0, 9)
capacityCorner.Parent = capacityCard
local capacityCaption = text(capacityCard, "PARTY CAPACITY", 9, Enum.Font.GothamBold)
capacityCaption.Position = UDim2.fromOffset(12, 6)
capacityCaption.Size = UDim2.fromOffset(110, 14)
capacityCaption.TextXAlignment = Enum.TextXAlignment.Left
capacityCaption.TextColor3 = Color3.fromRGB(111, 132, 136)
local capacityText = text(capacityCard, "4 SLOTS", 16, Enum.Font.GothamBold)
capacityText.Position = UDim2.fromOffset(12, 20)
capacityText.Size = UDim2.fromOffset(88, 32)
capacityText.TextXAlignment = Enum.TextXAlignment.Left
local minus = button(capacityCard, "−", UDim2.fromOffset(112, 13), UDim2.fromOffset(35, 34))
local plus = button(capacityCard, "+", UDim2.fromOffset(155, 13), UDim2.fromOffset(35, 34))
local access = button(panel, "FRIENDS ONLY  //  ON", UDim2.fromOffset(234, 434), UDim2.fromOffset(212, 58))
access.TextSize = 11

local modeTitle = text(panel, "THE BLIND ONE", 10, Enum.Font.GothamBold)
modeTitle.Position = UDim2.fromOffset(24, 509)
modeTitle.Size = UDim2.fromOffset(220, 18)
modeTitle.TextXAlignment = Enum.TextXAlignment.Left
modeTitle.TextColor3 = Color3.fromRGB(132, 154, 157)
local modeHint = text(panel, "SELECT WHO HUNTS", 9, Enum.Font.GothamMedium)
modeHint.Position = UDim2.fromOffset(250, 509)
modeHint.Size = UDim2.fromOffset(196, 18)
modeHint.TextXAlignment = Enum.TextXAlignment.Right
modeHint.TextColor3 = Color3.fromRGB(78, 97, 101)
local bot = button(panel, "◉  BOT", UDim2.fromOffset(24, 532), UDim2.fromOffset(130, 42))
local human = button(panel, "♟  PLAYER", UDim2.fromOffset(162, 532), UDim2.fromOffset(142, 42))
local leave = button(panel, "LEAVE", UDim2.fromOffset(312, 532), UDim2.fromOffset(134, 42))
leave.TextColor3 = Color3.fromRGB(221, 126, 116)
local start = button(panel, "BEGIN DESCENT   ››", UDim2.fromOffset(24, 584), UDim2.fromOffset(422, 42))
start.BackgroundColor3 = Color3.fromRGB(124, 40, 32)
start.TextColor3 = Color3.fromRGB(255, 239, 228)
start.TextSize = 13
local startGradient = Instance.new("UIGradient")
startGradient.Color = ColorSequence.new(Color3.fromRGB(113, 34, 29), Color3.fromRGB(183, 76, 48))
startGradient.Parent = start

local function resizePanel()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	panelScale.Scale = math.min(1, math.max(0.68, (viewport.Y - 18) / 640))
end
resizePanel()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizePanel) end

local currentState: any = nil
local currentQueue: any = nil
local activeAccent = Color3.fromRGB(90, 205, 219)
local function setSelected(target: TextButton, selected: boolean)
	target.BackgroundColor3 = if selected then activeAccent:Lerp(Color3.new(), 0.7) else Color3.fromRGB(12, 16, 17)
	target.TextColor3 = if selected then Color3.fromRGB(246, 250, 247) else Color3.fromRGB(157, 174, 174)
end

local function updateQueue(queue: any)
	currentQueue = queue
	panel.Visible = queue ~= nil
	panelShadow.Visible = queue ~= nil
	if not queue then return end
	local isPrivate = queue.kind == "Private"
	local isHost = queue.ownerUserId == player.UserId
	local accentByQueue = {
		Private1 = Color3.fromRGB(211, 107, 190),
		Private2 = Color3.fromRGB(229, 152, 76),
		Private3 = Color3.fromRGB(72, 210, 224),
		Private4 = Color3.fromRGB(128, 212, 112),
		Public = Color3.fromRGB(225, 70, 58),
	}
	activeAccent = accentByQueue[queue.id] or Color3.fromRGB(90, 205, 219)
	panelStroke.Color = activeAccent
	headerGlow.BackgroundColor3 = activeAccent
	headerLine.BackgroundColor3 = activeAccent
	liveDot.BackgroundColor3 = activeAccent
	statusDot.BackgroundColor3 = activeAccent
	occupancy.TextColor3 = activeAccent
	rosterBox.ScrollBarImageColor3 = activeAccent
	local queueNumber = tostring(queue.id):match("%d+") or ""
	panelTitle.Text = if isPrivate then "PRIVATE ELEVATOR " .. string.format("%02d", tonumber(queueNumber) or 0) else "PUBLIC FREIGHT ELEVATOR"
	panelStatus.Text = if queue.countdown then ("The descent begins in %d seconds..."):format(queue.countdown)
		elseif isPrivate and isHost then "Configure the party, then begin the descent."
		elseif isPrivate then "Party secured. Waiting for the host."
		else "Open matchmaking active. Awaiting more operatives."
	occupancy.Text = ("%d / %d READY"):format(#queue.members, queue.capacity)
	capacityText.Text = ("%d SLOTS"):format(queue.capacity)
	capacityCard.Visible = isPrivate
	settingsTitle.Visible = isPrivate
	minus.Visible, plus.Visible = isPrivate and isHost, isPrivate and isHost
	access.Visible = isPrivate and isHost
	access.Text = "FRIENDS ONLY  //  " .. (if queue.friendsOnly then "ON" else "OFF")
	start.Visible = isPrivate and isHost
	modeTitle.Visible = isHost or not isPrivate
	modeHint.Visible = isHost or not isPrivate
	bot.Visible, human.Visible = isHost or not isPrivate, isHost or not isPrivate
	setSelected(bot, queue.blindMode == "Bot")
	setSelected(human, queue.blindMode == "Player")
	for index, row in roster do
		local member = queue.members[index]
		row.frame.Visible = index <= queue.capacity
		if member then
			local isOwner = member.userId == queue.ownerUserId
			row.frame.BackgroundColor3 = if isOwner then activeAccent:Lerp(Color3.new(), 0.78) else Color3.fromRGB(15, 22, 25)
			row.slot.TextColor3 = if isOwner then activeAccent else Color3.fromRGB(104, 128, 131)
			row.name.Text = string.upper(member.name)
			row.name.TextColor3 = Color3.fromRGB(215, 226, 224)
			row.badge.Text = if isOwner then "HOST" else "READY"
			row.badge.TextColor3 = if isOwner then activeAccent else Color3.fromRGB(115, 165, 143)
		else
			row.frame.BackgroundColor3 = Color3.fromRGB(12, 18, 21)
			row.slot.TextColor3 = Color3.fromRGB(65, 81, 84)
			row.name.Text = "VACANT SLOT"
			row.name.TextColor3 = Color3.fromRGB(67, 82, 85)
			row.badge.Text = "EMPTY"
			row.badge.TextColor3 = Color3.fromRGB(58, 71, 74)
		end
	end
end

playButton.Activated:Connect(function()
	playButton.Active = false
	playButton.Text = "ENTERING..."
	actionRemote:FireServer("EnterHub")
end)
minus.Activated:Connect(function() if currentQueue then actionRemote:FireServer("Capacity", currentQueue.capacity - 1) end end)
plus.Activated:Connect(function() if currentQueue then actionRemote:FireServer("Capacity", currentQueue.capacity + 1) end end)
access.Activated:Connect(function() if currentQueue then actionRemote:FireServer("FriendsOnly", not currentQueue.friendsOnly) end end)
bot.Activated:Connect(function() actionRemote:FireServer("BlindMode", "Bot") end)
human.Activated:Connect(function() actionRemote:FireServer("BlindMode", "Player") end)
leave.Activated:Connect(function() actionRemote:FireServer("Leave") end)
start.Activated:Connect(function() actionRemote:FireServer("Start") end)

Remotes.LobbyState.OnClientEvent:Connect(function(state: any)
	currentState = state
	local phase = state.phase
	menuShade.Visible = phase == "Menu"
	hubHint.Visible = phase == "Hub" and state.queue == nil
	updateQueue(state.queue)
	if phase == "Match" then
		gui.Enabled = false
	end
	UserInputService.MouseIconEnabled = phase ~= "Match"
end)

local cameraRestored = false
RunService:BindToRenderStep("LobbyCamera", Enum.RenderPriority.Camera.Value + 5, function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local phase = currentState and currentState.phase or "Menu"
	if phase == "Menu" then
		cameraRestored = false
		local folder = workspace:FindFirstChild("GeneratedLobby")
		local cameraPart = folder and folder:FindFirstChild("MenuCamera")
		if cameraPart and cameraPart:IsA("BasePart") then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cameraPart.CFrame * CFrame.new(math.sin(os.clock() * 0.2) * 0.32, math.sin(os.clock() * 0.29) * 0.12, 0)
		end
	elseif not cameraRestored then
		cameraRestored = true
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
	end
end)

actionRemote:FireServer("Refresh")
