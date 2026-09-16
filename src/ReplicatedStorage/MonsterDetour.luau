--!strict
-- Bounded local search using the same clearance sweep as actual movement.
local Detour = {}
function Detour.Find(from: Vector3, goals: {Vector3}, clear: (Vector3,Vector3)->boolean): {Vector3}?
	local ahead = {}
	for _, goal in goals do
		if Vector3.new(goal.X-from.X,0,goal.Z-from.Z).Magnitude>1.5 then table.insert(ahead,goal) end
	end
	goals = ahead
	local function heuristic(p: Vector3): number
		local best=math.huge
		for _, goal in goals do best=math.min(best,(Vector3.new(goal.X,p.Y,goal.Z)-p).Magnitude) end
		return best
	end
	if #goals==0 then return nil end
	local open={ {x=0,z=0,p=from,g=0,f=heuristic(from),parent=0} }
	local nodes={open[1]}
	local bestCost: {[string]: number}={['0:0']=0}
	local expanded=0
	while #open>0 and expanded<400 do
		local pick=1
		for i=2,#open do if open[i].f<open[pick].f then pick=i end end
		local current=table.remove(open,pick)
		local key=current.x..':'..current.z
		if current.g>bestCost[key] then continue end
		expanded+=1
		for _, goal in goals do
			if (Vector3.new(goal.X,from.Y,goal.Z)-current.p).Magnitude<=12 and clear(current.p,goal) then
				local route={Vector3.new(goal.X,from.Y,goal.Z)}
				local n=current
				while n.parent~=0 do table.insert(route,1,n.p);n=nodes[n.parent] end
				return route
			end
		end
		local parentIndex=#nodes+1;table.insert(nodes,current)
		for dx=-1,1 do for dz=-1,1 do
			if dx==0 and dz==0 then continue end
			local x,z=current.x+dx,current.z+dz
			if math.abs(x)>10 or math.abs(z)>10 then continue end
			local p=from+Vector3.new(x*3,0,z*3)
			local cost=current.g+(p-current.p).Magnitude
			local nextKey=x..':'..z
			if cost<(bestCost[nextKey] or math.huge) and clear(current.p,p) then
				bestCost[nextKey]=cost
				table.insert(open,{x=x,z=z,p=p,g=cost,f=cost+heuristic(p),parent=parentIndex})
			end
		end end
	end
	return nil
end
return Detour
