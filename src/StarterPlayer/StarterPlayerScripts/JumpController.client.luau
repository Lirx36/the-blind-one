--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local JumpPolicy = require(ReplicatedStorage:WaitForChild("JumpPolicy"))
local player = Players.LocalPlayer

local function refresh()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- The server snapshots the original values before locking jumping. Wait for
	-- that snapshot instead of accidentally remembering its replicated zeroes.
	if humanoid and humanoid:GetAttribute("OriginalJumpPower") ~= nil then
		JumpPolicy.Apply(humanoid, true)
	end
end

local function characterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:GetAttributeChangedSignal("OriginalJumpPower"):Connect(function()
		task.defer(refresh)
	end)
	refresh()
end
player.CharacterAdded:Connect(characterAdded)
player:GetAttributeChangedSignal("Role"):Connect(refresh)
if player.Character then task.spawn(characterAdded, player.Character) end

ContextActionService:BindActionAtPriority("NoMatchJump", function()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.PlayerActions.CharacterJump)
