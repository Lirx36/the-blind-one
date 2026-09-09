--!strict
-- Keep Studio playtests focused on the actual player camera. Roblox injects a
-- developer Freecam into playtests for place owners; it is not listed in
-- Studio's customizable shortcuts, so remove the injected interface here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local function isInjectedFreecam(instance: Instance): boolean
	local compactName = string.lower(instance.Name):gsub("[^%a]", "")
	return compactName == "freecam" or compactName == "freecamera"
end

local function removeFreecam(instance: Instance)
	if isInjectedFreecam(instance) then
		instance:Destroy()
	end
end

for _, container in { playerGui, playerScripts } do
	for _, descendant in container:GetDescendants() do
		removeFreecam(descendant)
	end
	container.DescendantAdded:Connect(function(descendant)
		-- Let Roblox finish parenting the injected hierarchy before removing its
		-- root. The exact injection timing varies between Studio versions.
		task.defer(function()
			if descendant.Parent then
				removeFreecam(descendant)
			end
		end)
	end)
end
