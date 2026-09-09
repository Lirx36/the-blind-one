--!strict
-- Lightweight, fully procedural skin for a player-controlled Blind One. The
-- player's catalog avatar is hidden (not destroyed), so it can be restored if
-- their role changes without reloading the character.
local ServerStorage = game:GetService("ServerStorage")

local MonsterAppearance = {}

local VISUAL_NAME = "BlindOneVisual"
local IMPORTED_TEMPLATE_NAME = "BlindOneMesh"
local RIGGED_TEMPLATE_NAME = "BlindOneRig"
local ORIGINAL_TRANSPARENCY = "BlindOneOriginalTransparency"
local ORIGINAL_CAST_SHADOW = "BlindOneOriginalCastShadow"
local ORIGINAL_SCALE = "BlindOneOriginalScale"

local DARK = Color3.fromRGB(21, 17, 20)
local DEEP_DARK = Color3.fromRGB(2, 1, 3)
local BONE = Color3.fromRGB(132, 119, 99)
local WRAPPING = Color3.fromRGB(68, 57, 51)
local HORN = Color3.fromRGB(58, 42, 31)
local WOUND = Color3.fromRGB(135, 8, 5)
local EYE = Color3.fromRGB(235, 248, 255)

local BODY_SCALES: { [string]: Vector3 } = {
	UpperTorso = Vector3.new(1.1, 1.08, 1.02),
	LowerTorso = Vector3.new(0.78, 1.08, 0.88),
	Torso = Vector3.new(1.08, 1.08, 1.0),
	LeftUpperArm = Vector3.new(0.88, 1.15, 0.92),
	RightUpperArm = Vector3.new(0.88, 1.15, 0.92),
	LeftLowerArm = Vector3.new(1.08, 1.22, 1.04),
	RightLowerArm = Vector3.new(1.08, 1.22, 1.04),
	["Left Arm"] = Vector3.new(0.94, 1.16, 0.96),
	["Right Arm"] = Vector3.new(0.94, 1.16, 0.96),
	LeftHand = Vector3.new(1.06, 1.24, 1.02),
	RightHand = Vector3.new(1.06, 1.24, 1.02),
	LeftUpperLeg = Vector3.new(0.9, 1.13, 0.92),
	RightUpperLeg = Vector3.new(0.9, 1.13, 0.92),
	LeftLowerLeg = Vector3.new(0.86, 1.16, 0.9),
	RightLowerLeg = Vector3.new(0.86, 1.16, 0.9),
	["Left Leg"] = Vector3.new(0.88, 1.12, 0.9),
	["Right Leg"] = Vector3.new(0.88, 1.12, 0.9),
	LeftFoot = Vector3.new(0.96, 1.04, 1.05),
	RightFoot = Vector3.new(0.96, 1.04, 1.05),
}

local SCALE_TARGETS: { [string]: number } = {
	BodyHeightScale = 1.2,
	BodyWidthScale = 0.82,
	BodyDepthScale = 0.86,
	HeadScale = 0.92,
	BodyTypeScale = 0,
	BodyProportionScale = 0,
}

local function configurePart(part: BasePart, name: string, color: Color3, material: Enum.Material)
	part.Name = name
	part.Color = color
	part.Material = material
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function weldedPart(
	visual: Model,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	configurePart(part, name, color, material)
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.CFrame = anchor.CFrame * offset
	part.Parent = visual
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function weldedWedge(
	visual: Model,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): WedgePart
	local part = Instance.new("WedgePart")
	configurePart(part, name, color, material)
	part.Size = size
	part.CFrame = anchor.CFrame * offset
	part.Parent = visual
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function weldedRod(
	visual: Model,
	anchor: BasePart,
	name: string,
	fromLocal: Vector3,
	toLocal: Vector3,
	thickness: number,
	color: Color3
): Part
	local fromWorld = anchor.CFrame:PointToWorldSpace(fromLocal)
	local toWorld = anchor.CFrame:PointToWorldSpace(toLocal)
	local midpoint = (fromWorld + toWorld) / 2
	local length = (toWorld - fromWorld).Magnitude
	local part = Instance.new("Part")
	configurePart(part, name, color, Enum.Material.Slate)
	part.Size = Vector3.new(thickness, thickness, length)
	part.CFrame = CFrame.lookAt(midpoint, toWorld)
	part.Parent = visual
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function hideAvatar(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute(ORIGINAL_TRANSPARENCY) == nil then
				descendant:SetAttribute(ORIGINAL_TRANSPARENCY, descendant.Transparency)
				descendant:SetAttribute(ORIGINAL_CAST_SHADOW, descendant.CastShadow)
			end
			descendant.Transparency = 1
			descendant.CastShadow = false
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		for scaleName, target in SCALE_TARGETS do
			local scale = humanoid:FindFirstChild(scaleName)
			if scale and scale:IsA("NumberValue") then
				if scale:GetAttribute(ORIGINAL_SCALE) == nil then
					scale:SetAttribute(ORIGINAL_SCALE, scale.Value)
				end
				scale.Value = target
			end
		end
	end
end

local function restoreAvatar(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			local transparency = descendant:GetAttribute(ORIGINAL_TRANSPARENCY)
			local castShadow = descendant:GetAttribute(ORIGINAL_CAST_SHADOW)
			if typeof(transparency) == "number" then
				descendant.Transparency = transparency
				descendant:SetAttribute(ORIGINAL_TRANSPARENCY, nil)
			end
			if typeof(castShadow) == "boolean" then
				descendant.CastShadow = castShadow
				descendant:SetAttribute(ORIGINAL_CAST_SHADOW, nil)
			end
		elseif descendant:IsA("NumberValue") then
			local scale = descendant:GetAttribute(ORIGINAL_SCALE)
			if typeof(scale) == "number" then
				descendant.Value = scale
				descendant:SetAttribute(ORIGINAL_SCALE, nil)
			end
		end
	end
end

function MonsterAppearance.Clear(character: Model)
	local visual = character:FindFirstChild(VISUAL_NAME)
	if visual then
		visual:Destroy()
	end
	restoreAvatar(character)
end

local function addBodyShell(visual: Model, character: Model)
	for bodyName, scale in BODY_SCALES do
		local bodyPart = character:FindFirstChild(bodyName)
		if bodyPart and bodyPart:IsA("BasePart") then
			local size = Vector3.new(
				bodyPart.Size.X * scale.X,
				bodyPart.Size.Y * scale.Y,
				bodyPart.Size.Z * scale.Z
			)
			weldedPart(visual, bodyPart, "ShadowBody", size, CFrame.identity, DARK, Enum.Material.Slate)
		end
	end
end

local function characterFloorY(character: Model, root: BasePart): number
	local floorY = root.Position.Y - 3
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			floorY = math.min(floorY, child.Position.Y - child.Size.Y / 2)
		end
	end
	return floorY
end

local RIG_SEGMENTS: { { string } } = {
	{ "rightupperleg", "RightUpperLeg", "Right Leg" },
	{ "rightlowerleg", "RightLowerLeg", "Right Leg" },
	{ "rightfoot", "RightFoot", "Right Leg" },
	{ "leftupperleg", "LeftUpperLeg", "Left Leg" },
	{ "leftlowerleg", "LeftLowerLeg", "Left Leg" },
	{ "leftfoot", "LeftFoot", "Left Leg" },
	{ "rightupperarm", "RightUpperArm", "Right Arm" },
	{ "rightlowerarm", "RightLowerArm", "Right Arm" },
	{ "righthand", "RightHand", "Right Arm" },
	{ "leftupperarm", "LeftUpperArm", "Left Arm" },
	{ "leftlowerarm", "LeftLowerArm", "Left Arm" },
	{ "lefthand", "LeftHand", "Left Arm" },
	{ "lowertorso", "LowerTorso", "Torso" },
	{ "torso", "UpperTorso", "Torso" },
	{ "head", "Head" },
}

local function rigTarget(character: Model, importedPart: BasePart, importedRoot: Instance): BasePart?
	-- glTF imports commonly create a named Model node containing a MeshPart
	-- called "default". Read the complete ancestry instead of trusting only the
	-- leaf MeshPart name.
	local namePath = importedPart.Name
	local ancestor = importedPart.Parent
	while ancestor and ancestor ~= importedRoot do
		namePath ..= ancestor.Name
		ancestor = ancestor.Parent
	end
	local compactName = string.lower(namePath):gsub("[^%a]", "")
	for _, mapping in RIG_SEGMENTS do
		if string.find(compactName, mapping[1], 1, true) then
			for index = 2, #mapping do
				local candidate = character:FindFirstChild(mapping[index])
				if candidate and candidate:IsA("BasePart") then
					return candidate
				end
			end
		end
	end
	return nil
end

local function addImportedMonster(visual: Model, character: Model): boolean
	local template = ServerStorage:FindFirstChild(RIGGED_TEMPLATE_NAME)
		or ServerStorage:FindFirstChild(IMPORTED_TEMPLATE_NAME)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not template or not root or not root:IsA("BasePart") then
		return false
	end

	local clone = template:Clone()
	clone.Name = "ImportedMonster"
	clone.Parent = visual
	-- Freeze the asset before doing any scaling, hierarchy detection, or visual
	-- configuration. Even if Studio imported an unusual property, no loose limb
	-- can enter the physics simulation and fall away from the character.
	if clone:IsA("BasePart") then
		clone.Anchored = true
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	local desiredHeight = 9.2
	local floorY = characterFloorY(character, root)
	-- Roblox characters look along local -Z, while both authored monster assets
	-- present their detailed face on local +Z. Turn the complete shell around so
	-- its textured face, eye anchors, and movement direction all agree.
	local rotation = root.CFrame.Rotation * CFrame.Angles(0, math.rad(180), 0)
	local desiredBox = CFrame.new(root.Position.X, floorY + desiredHeight / 2, root.Position.Z) * rotation
	local importedParts: { BasePart } = {}

	if clone:IsA("BasePart") then
		local scale = desiredHeight / math.max(clone.Size.Y, 0.01)
		clone.Size *= scale
		clone.CFrame = desiredBox
		table.insert(importedParts, clone)
	elseif clone:IsA("Model") then
		local _, initialSize = clone:GetBoundingBox()
		local scale = desiredHeight / math.max(initialSize.Y, 0.01)
		clone:ScaleTo(clone:GetScale() * scale)
		local boxCFrame = clone:GetBoundingBox()
		local delta = desiredBox * boxCFrame:Inverse()
		clone:PivotTo(delta * clone:GetPivot())
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(importedParts, descendant)
			end
		end
	else
		clone:Destroy()
		return false
	end

	local rigTargets: { [BasePart]: BasePart } = {}
	local matchedSegments = 0
	for _, part in importedParts do
		local target = rigTarget(character, part, clone)
		if target then
			rigTargets[part] = target
			matchedSegments += 1
		end
	end
	local articulated = template.Name == RIGGED_TEMPLATE_NAME and matchedSegments >= 8
	visual:SetAttribute("Articulated", articulated)

	local rigAnchor: BasePart? = nil
	if not articulated then
		-- Backward-compatible support for the original one-piece mesh.
		local anchor = Instance.new("Part")
		configurePart(anchor, "ImportedRigAnchor", Vector3.new(0.2, 0.2, 0.2), DEEP_DARK, Enum.Material.SmoothPlastic)
		anchor.Transparency = 1
		anchor.CastShadow = false
		anchor.CFrame = desiredBox
		anchor.Parent = visual
		rigAnchor = anchor

		local visualMotor = Instance.new("Motor6D")
		visualMotor.Name = "BlindOneVisualMotor"
		visualMotor.Part0 = root
		visualMotor.Part1 = anchor
		visualMotor.C0 = root.CFrame:ToObjectSpace(desiredBox)
		visualMotor.C1 = CFrame.identity
		visualMotor.Parent = anchor
	end

	for _, part in importedParts do
		part.Massless = true
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = true
		if part:IsA("MeshPart") then
			-- These importer properties are not writable in every Studio/runtime
			-- version. They are cosmetic, so never let one block the attachment.
			pcall(function()
				part.RenderFidelity = Enum.RenderFidelity.Precise
				part.DoubleSided = true
			end)
		end
		local jointAnchor = if articulated then (rigTargets[part] or root) else (rigAnchor or root)
		local attachment = Instance.new("WeldConstraint")
		attachment.Name = "BlindOneSegmentJoint"
		attachment.Part0 = jointAnchor
		attachment.Part1 = part
		attachment.Parent = part
		part.Anchored = false
	end

	local eyeAnchor: BasePart = root
	if articulated then
		for _, part in importedParts do
			if rigTargets[part] == character:FindFirstChild("Head") then
				eyeAnchor = part
				break
			end
		end
	elseif rigAnchor then
		eyeAnchor = rigAnchor
	end

	-- The concept texture supplies the detailed eyes; these tiny Neon slits give
	-- them the same cold glow in the game's nearly black lighting.
	-- glTF's authored front is +Z after Studio import; the legacy OBJ backup is
	-- corrected to face -Z by its 180-degree rotation above.
	local eyeDepth = if template.Name == RIGGED_TEMPLATE_NAME then 0.88 else -0.88
	local haloDepth = if eyeDepth > 0 then 0.018 else -0.018
	for _, x in { -0.25, 0.25 } do
		local worldEye = desiredBox * CFrame.new(x, 2.42, eyeDepth)
		local eye = weldedPart(
			visual,
			eyeAnchor,
			"ImportedBlindEye",
			Vector3.new(0.14, 0.045, 0.04),
			eyeAnchor.CFrame:ToObjectSpace(worldEye),
			EYE,
			Enum.Material.Neon
		)
		eye.CastShadow = false
		local halo = weldedPart(
			visual,
			eyeAnchor,
			"ImportedEyeHalo",
			Vector3.new(0.27, 0.11, 0.025),
			eyeAnchor.CFrame:ToObjectSpace(worldEye * CFrame.new(0, 0, haloDepth)),
			Color3.fromRGB(195, 229, 245),
			Enum.Material.Neon
		)
		halo.Transparency = 0.72
		halo.CastShadow = false
		local glow = Instance.new("PointLight")
		glow.Color = EYE
		glow.Brightness = 0.78
		glow.Range = 4.5
		glow.Shadows = false
		glow.Parent = eye
	end

	-- Imported rigs used to return before receiving the shadow aura. The lantern
	-- controller darkens this overlay when its beam hits the creature, preserving
	-- the frightening silhouette instead of washing the texture orange.
	local aura = Instance.new("Highlight")
	aura.Name = "DarkAura"
	aura.Adornee = visual
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.FillColor = Color3.fromRGB(0, 0, 0)
	aura.FillTransparency = 0.88
	aura.OutlineColor = Color3.fromRGB(125, 25, 18)
	aura.OutlineTransparency = 0.22
	aura.Parent = visual

	return true
end

local function addFace(visual: Model, head: BasePart)
	weldedPart(visual, head, "CrackedCowl", Vector3.new(1.82, 2.06, 1.72), CFrame.new(0, 0.03, 0), DARK, Enum.Material.Slate, Enum.PartType.Ball)
	weldedPart(visual, head, "EyeBandage", Vector3.new(1.84, 0.44, 0.17), CFrame.new(0, 0.24, -0.89), WRAPPING, Enum.Material.Fabric)

	for _, x in { -0.32, 0.32 } do
		local eye = weldedPart(visual, head, "BlindEye", Vector3.new(0.28, 0.105, 0.08), CFrame.new(x, 0.24, -1), EYE, Enum.Material.Neon)
		if x < 0 then
			local glow = Instance.new("PointLight")
			glow.Name = "EyeGlow"
			glow.Color = EYE
			glow.Brightness = 1.8
			glow.Range = 8
			glow.Shadows = false
			glow.Parent = eye
		end
	end

	for index, x in { -0.58, -0.19, 0.19, 0.58 } do
		weldedPart(
			visual,
			head,
			"BandageStitch",
			Vector3.new(0.065, 0.54, 0.065),
			CFrame.new(x, 0.24, -1.015) * CFrame.Angles(0, 0, math.rad(if index % 2 == 0 then 15 else -15)),
			BONE,
			Enum.Material.Slate
		)
	end

	local mouth = weldedPart(visual, head, "VerticalMaw", Vector3.new(0.4, 0.73, 0.11), CFrame.new(0, -0.49, -0.92), DEEP_DARK, Enum.Material.SmoothPlastic)
	local mouthGlow = Instance.new("PointLight")
	mouthGlow.Name = "MawGlow"
	mouthGlow.Color = WOUND
	mouthGlow.Brightness = 0.48
	mouthGlow.Range = 5
	mouthGlow.Shadows = true
	mouthGlow.Parent = mouth
	for _, x in { -0.1, 0.1 } do
		for _, y in { -0.16, 0.16 } do
			weldedPart(visual, head, "MawTooth", Vector3.new(0.09, 0.17, 0.08), CFrame.new(x, -0.49 + y, -1), BONE, Enum.Material.Slate)
		end
	end
end

local function addAntlers(visual: Model, head: BasePart)
	for _, side in { -1, 1 } do
		local s = side
		weldedRod(visual, head, "Antler", Vector3.new(0.54 * s, 0.72, 0.08), Vector3.new(0.79 * s, 1.31, 0.04), 0.24, HORN)
		weldedRod(visual, head, "Antler", Vector3.new(0.79 * s, 1.31, 0.04), Vector3.new(1.18 * s, 1.84, 0), 0.21, HORN)
		weldedRod(visual, head, "AntlerBranch", Vector3.new(0.86 * s, 1.42, 0.02), Vector3.new(0.58 * s, 1.91, -0.02), 0.16, HORN)
		weldedRod(visual, head, "AntlerBranch", Vector3.new(1.03 * s, 1.64, 0.01), Vector3.new(1.38 * s, 1.98, -0.03), 0.14, HORN)
		weldedRod(visual, head, "AntlerTip", Vector3.new(1.18 * s, 1.84, 0), Vector3.new(1.08 * s, 2.23, -0.04), 0.13, BONE)
	end
end

local function addChest(visual: Model, torso: BasePart)
	local front = -(torso.Size.Z / 2 + 0.09)
	weldedPart(visual, torso, "SplitChest", Vector3.new(0.24, math.min(1.55, torso.Size.Y * 0.78), 0.1), CFrame.new(0, 0.04, front - 0.02), WOUND, Enum.Material.Neon)
	for index, y in { 0.48, 0.2, -0.08, -0.36 } do
		local reach = math.max(0.88, torso.Size.X * 0.48 - index * 0.025)
		for _, side in { -1, 1 } do
			local s = side
			local middle = Vector3.new(reach * 0.58 * s, y + 0.02, front - 0.06)
			weldedRod(visual, torso, "ExposedRib", Vector3.new(0.1 * s, y, front - 0.08), middle, 0.13, BONE)
			weldedRod(visual, torso, "ExposedRib", middle, Vector3.new(reach * s, y - 0.16, front + 0.02), 0.12, BONE)
		end
	end

	for _, side in { -1, 1 } do
		weldedPart(
			visual,
			torso,
			"ShoulderMass",
			Vector3.new(1.12, 1.18, 1.08),
			CFrame.new((torso.Size.X / 2 + 0.4) * side, 0.35, 0.03),
			DARK,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		weldedWedge(
			visual,
			torso,
			"ShoulderSpike",
			Vector3.new(0.5, 1.22, 0.54),
			CFrame.new((torso.Size.X / 2 + 0.48) * side, 0.82, 0.02) * CFrame.Angles(0, math.rad(90), math.rad(-58 * side)),
			BONE,
			Enum.Material.Slate
		)
		weldedWedge(
			visual,
			torso,
			"HangingShoulderTatter",
			Vector3.new(0.52, 1.75, 0.24),
			CFrame.new((torso.Size.X / 2 + 0.48) * side, -0.52, 0.2) * CFrame.Angles(0, 0, math.rad(7 * side)),
			DEEP_DARK,
			Enum.Material.Fabric
		)
	end
end

local function addClaws(visual: Model, hand: BasePart, side: number)
	for index, x in { -0.19, 0, 0.19 } do
		weldedWedge(
			visual,
			hand,
			"Claw",
			Vector3.new(0.15, 1.08, 0.18),
			CFrame.new(x, -(hand.Size.Y / 2 + 0.5), -0.08) * CFrame.Angles(math.rad(8), 0, math.rad((index - 2) * 11 * side)),
			BONE,
			Enum.Material.Slate
		)
	end
end

local function addTatters(visual: Model, torso: BasePart)
	for index, data in {
		{ -0.62, 1.15, -7 },
		{ -0.31, 1.55, 4 },
		{ 0, 1.8, -2 },
		{ 0.31, 1.42, 6 },
		{ 0.62, 1.08, -5 },
	} do
		local x = data[1]
		local length = data[2]
		local angle = data[3]
		weldedWedge(
			visual,
			torso,
			"ShadowTatter",
			Vector3.new(if index == 3 then 0.38 else 0.3, length, 0.18),
			CFrame.new(x, -(torso.Size.Y / 2 + length / 2 - 0.12), 0.12) * CFrame.Angles(0, 0, math.rad(angle)),
			DEEP_DARK,
			Enum.Material.Fabric
		)
	end
end

function MonsterAppearance.Apply(character: Model)
	MonsterAppearance.Clear(character)
	hideAvatar(character)

	local visual = Instance.new("Model")
	visual.Name = VISUAL_NAME
	visual.Parent = character
	local importedOk, importedResult = pcall(addImportedMonster, visual, character)
	if importedOk and importedResult then
		return
	end
	if not importedOk then
		warn("Blind One imported rig failed; using safe procedural fallback:", importedResult)
	end
	visual:ClearAllChildren()
	visual:SetAttribute("Articulated", false)

	addBodyShell(visual, character)

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		addFace(visual, head)
		addAntlers(visual, head)
	end

	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if upperTorso and upperTorso:IsA("BasePart") then
		addChest(visual, upperTorso)
	end

	local lowerTorso = character:FindFirstChild("LowerTorso") or upperTorso
	if lowerTorso and lowerTorso:IsA("BasePart") then
		addTatters(visual, lowerTorso)
	end

	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if rightHand and rightHand:IsA("BasePart") then
		addClaws(visual, rightHand, 1)
	end
	if leftHand and leftHand:IsA("BasePart") then
		addClaws(visual, leftHand, -1)
	end

	local aura = Instance.new("Highlight")
	aura.Name = "DarkAura"
	aura.Adornee = visual
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.FillColor = Color3.fromRGB(3, 2, 5)
	aura.FillTransparency = 0.88
	aura.OutlineColor = Color3.fromRGB(125, 25, 18)
	aura.OutlineTransparency = 0.22
	aura.Parent = visual
end

return MonsterAppearance
