--!strict
-- Touch actions complement Roblox's thumbstick and camera; keyboard input stays available.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Responsive = require(game:GetService("ReplicatedStorage"):WaitForChild("ResponsiveUI"))
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "SurvivorTouchControls"
gui.ResetOnSpawn = false
-- Below the modal menus, above the ordinary HUD.
gui.DisplayOrder = 120
gui.Parent = player:WaitForChild("PlayerGui")
local buttons: {[string]: TextButton} = {}
local function action(name: string, x: number, y: number, callback: ()->())
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(1,1)
	button.Position = UDim2.new(1,x,1,y)
	button.Size = UDim2.fromOffset(64,48)
	button.BackgroundColor3 = Color3.fromRGB(12,20,22)
	button.BackgroundTransparency = 0.15
	button.TextColor3 = Color3.fromRGB(225,234,230)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = name
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,10)
	corner.Parent = button
	button.Activated:Connect(callback)
	buttons[name] = button
end
local function reset()
	player:SetAttribute("TouchSprint",false)
	player:SetAttribute("TouchCrouch",false)
end
action("RUN",-86,-84,function()
	player:SetAttribute("TouchSprint",player:GetAttribute("TouchSprint")~=true)
	player:SetAttribute("TouchCrouch",false)
end)
action("CROUCH",-14,-84,function()
	player:SetAttribute("TouchCrouch",player:GetAttribute("TouchCrouch")~=true)
	player:SetAttribute("TouchSprint",false)
end)
action("LIGHT",-14,-140,function()
	player:SetAttribute("TouchLightToggle",(player:GetAttribute("TouchLightToggle") or 0)+1)
end)
local function refresh()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local available = Responsive.IsTouch() and player:GetAttribute("InMatch")==true
		and player:GetAttribute("Role")=="Survivor" and player:GetAttribute("Escaped")~=true
		and player:GetAttribute("RepairMinigameActive")~=true and player:GetAttribute("Spectating")~=true
		and player:GetAttribute("PhotoModeActive")~=true and hum~=nil and hum.Health>0
	gui.Enabled = available
	if not available then reset() end
	for name, button in buttons do
		local selected = (name=="RUN" and player:GetAttribute("TouchSprint")==true)
			or (name=="CROUCH" and player:GetAttribute("TouchCrouch")==true)
		button.BackgroundColor3 = if selected then Color3.fromRGB(100,45,30) else Color3.fromRGB(12,20,22)
	end
end
player.CharacterAdded:Connect(reset)
Input.WindowFocusReleased:Connect(reset)
Responsive.Watch(gui,refresh)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
	elapsed+=dt
	if elapsed>=0.15 then elapsed=0;refresh() end
end)
