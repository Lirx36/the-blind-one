--!strict
-- E: pick up a nearby rock.  Left click / R2: throw one where you're looking.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local PICKUP_RANGE = 12

local function root(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart? or nil
end

local function nearestRock(): BasePart?
	local hrp = root()
	if not hrp then
		return nil
	end
	local best: BasePart? = nil
	local bestD = PICKUP_RANGE
	for _, rock in CollectionService:GetTagged("Throwable") do
		if rock:IsA("BasePart") and rock:IsDescendantOf(Workspace) then
			local d = (rock.Position - hrp.Position).Magnitude
			if d < bestD then
				best, bestD = rock, d
			end
		end
	end
	return best
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		local rock = nearestRock()
		if rock then
			Remotes.Pickup:FireServer(rock)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		local cam = Workspace.CurrentCamera
		if cam then
			Remotes.Throw:FireServer(cam.CFrame.LookVector)
		end
	end
end)
