--!strict
-- Shared remote registry. require() this from either side.
-- Server creates the folder + events; client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"SetMoveState", -- client -> server: "idle" | "walk" | "crouch" | "sprint"
	"NoiseMeter", -- server -> client: current noise 0..100
	"Dread", -- server -> client: 0..1 proximity of the monster (for the vignette)
	"Throw", -- client -> server: throw a held rock in a direction
	"Pickup", -- client -> server: pick up a nearby rock
	"HeldCount", -- server -> client: how many rocks you hold
	"Objective", -- server -> client: objective text
	"PhotoMode", -- Studio testing: client toggles the solo AI freeze
	"LobbyAction", -- client -> server: enter lobby, set capacity, or start
	"LobbyState", -- server -> client: current lobby roster and status
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("RemoteEvents") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RemoteEvents"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("RemoteEvents") :: Folder
end

local remotes: { [string]: RemoteEvent } = {}
for _, name in NAMES do
	remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end
return remotes
