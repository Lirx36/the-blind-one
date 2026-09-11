--!strict
-- Distance fog is configured on Lighting by MapBuilder (no Atmosphere override).
-- World-anchored mist adds motion; turning the camera never drags the fog.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local old = workspace:FindFirstChild("ClientGroundFog")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "ClientGroundFog", workspace
local patches: {{part: Part, emitter: ParticleEmitter, x: number, z: number}} = {}
for z=-2,2 do
	for x=-2,2 do
		local anchor=Instance.new("Part")
		anchor.Name,anchor.Size,anchor.Transparency="MistBank",Vector3.new(18,1,18),1
		anchor.Anchored,anchor.CanCollide,anchor.CanQuery,anchor.CanTouch=true,false,false,false
		anchor.CastShadow,anchor.Parent=false,folder
		local emitter=Instance.new("ParticleEmitter")
		emitter.Name,emitter.Texture="Mist","rbxasset://textures/particles/smoke_main.dds"
		emitter.Color=ColorSequence.new(Color3.fromRGB(117,130,134),Color3.fromRGB(91,108,111))
		emitter.Transparency=NumberSequence.new({
			NumberSequenceKeypoint.new(0,1),
			NumberSequenceKeypoint.new(0.15,0.88),
			NumberSequenceKeypoint.new(0.7,0.93),
			NumberSequenceKeypoint.new(1,1),
		})
		emitter.Size=NumberSequence.new({
			NumberSequenceKeypoint.new(0,12),
			NumberSequenceKeypoint.new(1,23),
		})
		emitter.Lifetime,emitter.Rate=NumberRange.new(8,12),1.2
		emitter.Speed,emitter.Acceleration=NumberRange.new(0.1,0.4),Vector3.new(0.09,0,0.04)
		emitter.Rotation,emitter.RotSpeed=NumberRange.new(0,360),NumberRange.new(-2,2)
		emitter.SpreadAngle=Vector2.new(180,180)
		-- Most of the fog color survives the dark ambient lighting.
		emitter.LightInfluence,emitter.LightEmission=0.12,0.2
		emitter.LockedToPart,emitter.Enabled=false,false
		emitter.Parent=anchor
		table.insert(patches,{part=anchor,emitter=emitter,x=x,z=z})
	end
end
local visible=false
local gridX,gridZ=math.huge,math.huge
RunService.Heartbeat:Connect(function()
	local camera=workspace.CurrentCamera
	local enabled=camera~=nil and player:GetAttribute("Role")~="BlindOne"
		and player:GetAttribute("PhotoModeActive")~=true
	if not enabled then
		if visible then
			for _, patch in patches do patch.emitter.Enabled=false; patch.emitter:Clear() end
		end
		visible=false
		gridX,gridZ=math.huge,math.huge
		return
	end
	if not camera then return end
	local x,z=math.floor(camera.CFrame.X/22),math.floor(camera.CFrame.Z/22)
	if gridX~=x or gridZ~=z then
		gridX,gridZ=x,z
		for _, patch in patches do
			-- Modulo tiling keeps 20/25 banks at their old world position per step.
			local px=x-2+(patch.x-(x-2))%5
			local pz=z-2+(patch.z-(z-2))%5
			local position=Vector3.new(px*22,2.5,pz*22)
			if patch.part.Position~=position then
				patch.emitter:Clear()
				patch.part.Position=position
				patch.emitter:Emit(5)
			end
		end
	end
	if not visible then
		visible=true
		for _, patch in patches do patch.emitter.Enabled=true end
	end
end)
