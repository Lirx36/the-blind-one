--!strict
-- Rotate quiet patrols across nine map regions rather than circling nearby nodes.
local Patrol = {}
function Patrol.New(nodes: {Vector3})
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, p in nodes do
		minX, minZ = math.min(minX,p.X), math.min(minZ,p.Z)
		maxX, maxZ = math.max(maxX,p.X), math.max(maxZ,p.Z)
	end
	local function region(p: Vector3): number
		local x = math.clamp(math.floor((p.X-minX)/math.max(maxX-minX+0.01,1)*3),0,2)
		local z = math.clamp(math.floor((p.Z-minZ)/math.max(maxZ-minZ+0.01,1)*3),0,2)
		return z*3+x+1
	end
	local visited: {[number]: number} = {}
	local attempted: {[number]: number} = {}
	local sequence = 0
	return {
		Select = function(from: Vector3, cooldowns: {[Vector3]: number}, now: number): Vector3
			if #nodes == 0 then return from end
			sequence += 1
			-- Only our physical position counts as visited, never a planned goal.
			visited[region(from)] = sequence
			local groups: {[number]: {Vector3}} = {}
			for _, node in nodes do
				local distance = Vector3.new(node.X-from.X,0,node.Z-from.Z).Magnitude
				if distance >= 12 and (cooldowns[node] or 0) <= now then
					local id = region(node)
					groups[id] = groups[id] or {}
					table.insert(groups[id],node)
				end
			end
			local chosen: number? = nil
			for id in groups do
				if chosen == nil or (visited[id] or 0) < (visited[chosen] or 0)
					or ((visited[id] or 0) == (visited[chosen] or 0)
						and ((attempted[id] or 0) < (attempted[chosen] or 0)
							or ((attempted[id] or 0) == (attempted[chosen] or 0) and id < chosen))) then
					chosen = id
				end
			end
			if chosen == nil then return from end
			attempted[chosen] = sequence
			local options = groups[chosen]
			return options[math.random(#options)]
		end,
	}
end
return Patrol
