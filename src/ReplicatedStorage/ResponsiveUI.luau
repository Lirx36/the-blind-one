--!strict
-- Shared safe-area and resize handling for both places; never scales a fullscreen effect.
local Input = game:GetService("UserInputService")
local Responsive = {}
function Responsive.IsTouch(): boolean
	return Input.PreferredInput == Enum.PreferredInput.Touch
end
function Responsive.Scale(item: GuiObject): UIScale
	local existing = item:FindFirstChildOfClass("UIScale")
	if existing then return existing end
	local scale = Instance.new("UIScale")
	scale.Parent = item
	return scale
end
function Responsive.Watch(gui: ScreenGui, update: (Vector2, boolean)->())
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local bounds = Instance.new("Frame")
	bounds.Name = "SafeLayoutBounds"
	bounds.Size = UDim2.fromScale(1, 1)
	bounds.BackgroundTransparency = 1
	bounds.Active = false
	bounds.Parent = gui
	local function refresh()
		local size = bounds.AbsoluteSize
		if size.X > 0 and size.Y > 0 then update(size, Responsive.IsTouch()) end
	end
	local changed = bounds:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	local input = Input:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	gui.Destroying:Once(function() changed:Disconnect(); input:Disconnect() end)
	task.defer(refresh)
end
return Responsive
