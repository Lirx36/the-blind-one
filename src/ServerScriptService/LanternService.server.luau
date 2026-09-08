--!strict
-- Gives every player a lantern Tool they always hold. The light lives on the handle,
-- so it renders in first person and (later) other players can see who's carrying light.
local Players = game:GetService("Players")

local function makeLantern(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Lantern"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Lantern"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.9, 0.5)
	handle.Color = Color3.fromRGB(34, 27, 19)
	handle.Material = Enum.Material.Metal
	handle.Parent = tool

	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new(0.32, 0.32, 0.32)
	glow.Color = Color3.fromRGB(255, 218, 150)
	glow.Material = Enum.Material.Neon
	glow.Massless = true
	glow.CanCollide = false
	glow.Parent = tool
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = glow
	weld.C0 = CFrame.new(0, 0.35, 0)
	weld.Parent = handle

	local light = Instance.new("PointLight")
	light.Name = "LanternLight"
	light.Range = 15 -- small, tight pool
	light.Brightness = 2.6
	light.Color = Color3.fromRGB(255, 220, 182)
	light.Shadows = false
	light.Parent = glow

	return tool
end

local function giveLantern(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local backpack = player:WaitForChild("Backpack")

	for _, t in backpack:GetChildren() do
		if t.Name == "Lantern" then
			t:Destroy()
		end
	end
	for _, t in char:GetChildren() do
		if t:IsA("Tool") and t.Name == "Lantern" then
			t:Destroy()
		end
	end

	local tool = makeLantern()
	tool.Parent = char -- parenting a Tool into the character equips it

	-- keep it in hand: re-equip if it ever gets put away
	tool.Unequipped:Connect(function()
		task.defer(function()
			if tool.Parent and hum.Health > 0 then
				hum:EquipTool(tool)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		giveLantern(player, char)
	end)
	if player.Character then
		giveLantern(player, player.Character)
	end
end)
