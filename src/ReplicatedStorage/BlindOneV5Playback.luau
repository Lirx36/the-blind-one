--!strict
-- Shared visual playback for every viewer, for both AI and player characters.
local Motion = require(script.Parent:WaitForChild("BlindOneV5Motion"))
local Playback = {}
local states = setmetatable({}, {__mode = "k"}) :: any
local function frame(v: {number}): CFrame
	return CFrame.new(v[1],v[2],v[3],v[4],v[5],v[6],v[7])
end
local tracks = {}
for name, data in Motion.Bones do
	local rest = frame(data.Rest)
	local samples = {}
	for _, value in data.Samples do table.insert(samples, rest:ToObjectSpace(frame(value))) end
	tracks[name] = samples
end
function Playback.Step(visual: Model, root: BasePart, dt: number, forcedSpeed: number?)
	local state = states[visual]
	if not state then
		local bones = {}
		for _, item in visual:GetDescendants() do
			if item:IsA("Bone") and tracks[item.Name] then table.insert(bones,item) end
		end
		state = {phase=0,weight=0,bones=bones,position=root.Position,rescan=0}
		states[visual]=state
	end
	-- Streaming can deliver bones after the visual Model first becomes visible.
	state.rescan -= dt
	if state.rescan <= 0 then
		state.rescan = 1
		state.bones = {}
		for _, item in visual:GetDescendants() do
			if item:IsA("Bone") and tracks[item.Name] then table.insert(state.bones,item) end
		end
	end
	local delta=root.Position-state.position
	state.position=root.Position
	-- Position deltas work for remote players too; MoveDirection is local-only.
	local measured=Vector3.new(delta.X,0,delta.Z).Magnitude/math.max(dt,0.001)
	local speed=forcedSpeed or (if delta.Magnitude>10 then 0 else measured)
	local moving=speed>0.6
	state.weight += ((if moving then 1 else 0)-state.weight)*(1-math.exp(-dt*8))
	if moving then state.phase=(state.phase+dt*math.clamp(speed/8,0.4,2.2)/Motion.Duration)%1 end
	local position=state.phase*Motion.Frames
	local index=math.floor(position)+1
	local nextIndex=index%Motion.Frames+1
	local scale=visual:GetAttribute("MotionTranslationScale") or 1
	for _, bone in state.bones do
		if not bone:IsDescendantOf(visual) then continue end
		local samples=tracks[bone.Name]
		local pose=samples[index]:Lerp(samples[nextIndex],position%1)
		pose=CFrame.new(pose.Position*scale)*pose.Rotation
		bone.Transform=CFrame.identity:Lerp(pose,state.weight)
	end
end
return Playback
