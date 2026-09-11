--!strict
-- Fixed, connected labyrinth. Passage bits: north=1, east=2, south=4, west=8.
-- These cells are shared by construction and the bot's navigation fallback.
local Layout = {}
Layout.Size = 19
Layout.Cell = 18
Layout.Wall = 2.8
Layout.Masks = {
	{ 6, 14, 12, 6, 14, 12, 6, 10, 10, 12, 6, 14, 14, 10, 10, 10, 12, 6, 12 },
	{ 5, 3, 11, 9, 7, 9, 3, 14, 10, 13, 7, 9, 5, 2, 10, 12, 3, 9, 5 },
	{ 5, 6, 10, 12, 3, 10, 10, 9, 6, 11, 15, 12, 5, 6, 12, 3, 12, 6, 9 },
	{ 3, 11, 14, 15, 14, 10, 10, 12, 3, 12, 5, 5, 3, 9, 7, 14, 13, 5, 4 },
	{ 6, 10, 15, 15, 15, 14, 12, 5, 6, 13, 3, 15, 10, 14, 15, 15, 13, 7, 13 },
	{ 3, 12, 7, 11, 9, 5, 7, 9, 5, 5, 6, 15, 12, 5, 3, 15, 15, 9, 5 },
	{ 6, 13, 5, 6, 12, 3, 13, 6, 13, 5, 5, 7, 11, 15, 10, 9, 5, 6, 9 },
	{ 5, 3, 13, 5, 5, 6, 15, 11, 9, 7, 15, 11, 10, 15, 12, 6, 11, 11, 12 },
	{ 3, 12, 5, 5, 3, 9, 7, 10, 14, 15, 15, 12, 4, 7, 13, 5, 6, 10, 13 },
	{ 6, 9, 7, 15, 12, 6, 11, 14, 15, 15, 15, 11, 15, 13, 5, 5, 1, 6, 9 },
	{ 5, 6, 9, 5, 7, 15, 10, 9, 7, 11, 15, 10, 9, 5, 3, 11, 12, 3, 12 },
	{ 7, 9, 6, 13, 7, 9, 6, 14, 11, 10, 11, 14, 14, 15, 12, 4, 3, 12, 5 },
	{ 5, 6, 9, 5, 3, 12, 7, 13, 6, 14, 10, 9, 3, 15, 9, 7, 12, 5, 5 },
	{ 5, 3, 14, 15, 12, 3, 15, 13, 5, 3, 12, 6, 10, 15, 14, 15, 15, 9, 5 },
	{ 3, 10, 15, 15, 15, 10, 13, 7, 15, 12, 5, 5, 6, 15, 15, 15, 15, 12, 5 },
	{ 6, 10, 11, 11, 11, 12, 3, 15, 9, 3, 9, 7, 15, 9, 7, 15, 15, 9, 5 },
	{ 3, 10, 12, 6, 12, 3, 12, 7, 14, 12, 6, 9, 3, 10, 9, 5, 7, 10, 13 },
	{ 6, 12, 5, 5, 3, 10, 9, 5, 5, 5, 3, 14, 10, 10, 12, 5, 5, 6, 13 },
	{ 3, 11, 11, 11, 10, 10, 10, 9, 3, 11, 10, 11, 10, 10, 9, 3, 11, 11, 9 },
}
Layout.Rooms = {
	{ Name = "Listening Court", Id = "COURT", X = 10, Z = 10 },
	{ Name = "Generator House", Id = "POWER", X = 4, Z = 5 },
	{ Name = "Drowned Gallery", Id = "WATER", X = 16, Z = 5 },
	{ Name = "Silent Chapel", Id = "CHAPEL", X = 4, Z = 15 },
	{ Name = "Records Yard", Id = "RECORDS", X = 16, Z = 15 },
}
local directions = { {0,-1,1,4}, {1,0,2,8}, {0,1,4,1}, {-1,0,8,2} }
function Layout.Position(x: number, z: number): Vector3
	return Vector3.new((x - 10) * Layout.Cell, 0, (z - 10) * Layout.Cell)
end
function Layout.CellAt(position: Vector3): (number, number)
	return math.clamp(math.floor(position.X / Layout.Cell + 10.5), 1, Layout.Size),
		math.clamp(math.floor(position.Z / Layout.Cell + 10.5), 1, Layout.Size)
end
function Layout.Neighbors(x: number, z: number): {{number}}
	local result = {}
	for _, direction in directions do
		if bit32.band(Layout.Masks[z][x], direction[3]) ~= 0 then
			table.insert(result, {x + direction[1], z + direction[2]})
		end
	end
	return result
end
function Layout.Route(from: Vector3, target: Vector3): {Vector3}
	local sx, sz = Layout.CellAt(from)
	local tx, tz = Layout.CellAt(target)
	local start, finish = (sz-1)*19+sx, (tz-1)*19+tx
	local queue, previous = {start}, {[start] = 0}
	local cursor = 1
	while cursor <= #queue do
		local id = queue[cursor]
		if id == finish then break end
		cursor += 1
		local x, z = (id-1)%19+1, math.floor((id-1)/19)+1
		for _, nextCell in Layout.Neighbors(x, z) do
			local nextId = (nextCell[2]-1)*19+nextCell[1]
			if previous[nextId] == nil then
				previous[nextId] = id
				table.insert(queue, nextId)
			end
		end
	end
	if previous[finish] == nil then return {} end
	local route, id = {}, finish
	while id ~= 0 do
		table.insert(route, 1, Layout.Position((id-1)%19+1, math.floor((id-1)/19)+1))
		id = previous[id]
	end
	table.insert(route, target)
	return route
end
-- Fail before spawning geometry if an edited passage is disconnected or one-way.
function Layout.Validate()
	local edges = 0
	for z, row in Layout.Masks do
		for x, mask in row do
			for _, d in directions do
				if bit32.band(mask, d[3]) ~= 0 then
					local nx, nz = x+d[1], z+d[2]
					assert(nx >= 1 and nx <= 19 and nz >= 1 and nz <= 19, "Maze opening outside boundary")
					assert(bit32.band(Layout.Masks[nz][nx], d[4]) ~= 0, "One-way maze opening")
					edges += 1
				end
			end
			assert(#Layout.Route(Layout.Position(10,19), Layout.Position(x,z)) > 0, "Unreachable maze cell")
		end
	end
	return edges / 2 - 361 + 1
end
return Layout

