--!strict
-- Roblox-native analog-horror appearance shared by the solo AI and the
-- player-controlled Blind One. It intentionally uses only Parts, WedgeParts,
-- native materials, lights, and welds: no Blender mesh or uploaded asset.
-- The player's catalog avatar is hidden rather than destroyed so it can be
-- restored if their role changes.

local MonsterAppearance = {}

local VISUAL_NAME = "BlindOneVisual"
local ORIGINAL_TRANSPARENCY = "BlindOneOriginalTransparency"
local ORIGINAL_CAST_SHADOW = "BlindOneOriginalCastShadow"
local ORIGINAL_SCALE = "BlindOneOriginalScale"

local CLOTH = Color3.fromRGB(29, 29, 31)
local CLOTH_LIGHT = Color3.fromRGB(42, 41, 42)
local CLOTH_DEEP = Color3.fromRGB(8, 8, 10)
local SKIN = Color3.fromRGB(24, 24, 25)
local MASK = Color3.fromRGB(172, 168, 154)
local MASK_SHADOW = Color3.fromRGB(116, 114, 106)
local SEAM = Color3.fromRGB(12, 12, 14)
local EYE = Color3.fromRGB(230, 245, 255)

local BODY_SCALES: { [string]: Vector3 } = {
	UpperTorso = Vector3.new(0.82, 1.14, 0.84),
	LowerTorso = Vector3.new(0.68, 1.12, 0.78),
	Torso = Vector3.new(0.82, 1.12, 0.84),
	LeftUpperArm = Vector3.new(0.7, 1.18, 0.72),
	RightUpperArm = Vector3.new(0.7, 1.18, 0.72),
	LeftLowerArm = Vector3.new(0.68, 1.28, 0.7),
	RightLowerArm = Vector3.new(0.68, 1.28, 0.7),
	["Left Arm"] = Vector3.new(0.7, 1.2, 0.72),
	["Right Arm"] = Vector3.new(0.7, 1.2, 0.72),
	LeftHand = Vector3.new(0.72, 1.2, 0.78),
	RightHand = Vector3.new(0.72, 1.2, 0.78),
	LeftUpperLeg = Vector3.new(0.76, 1.16, 0.8),
	RightUpperLeg = Vector3.new(0.76, 1.16, 0.8),
	LeftLowerLeg = Vector3.new(0.72, 1.2, 0.76),
	RightLowerLeg = Vector3.new(0.72, 1.2, 0.76),
	["Left Leg"] = Vector3.new(0.74, 1.16, 0.78),
	["Right Leg"] = Vector3.new(0.74, 1.16, 0.78),
	LeftFoot = Vector3.new(0.84, 1.02, 0.96),
	RightFoot = Vector3.new(0.84, 1.02, 0.96),
}

local SCALE_TARGETS: { [string]: number } = {
	BodyHeightScale = 1.28,
	BodyWidthScale = 0.72,
	BodyDepthScale = 0.78,
	HeadScale = 0.82,
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
	weld.Name = "AnalogVisualWeld"
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
	color: Color3,
	material: Enum.Material
): Part
	local fromWorld = anchor.CFrame:PointToWorldSpace(fromLocal)
	local toWorld = anchor.CFrame:PointToWorldSpace(toLocal)
	local midpoint = (fromWorld + toWorld) / 2
	local length = math.max((toWorld - fromWorld).Magnitude, 0.05)
	local part = Instance.new("Part")
	configurePart(part, name, color, material)
	part.Size = Vector3.new(math.max(thickness, 0.05), math.max(thickness, 0.05), length)
	part.CFrame = CFrame.lookAt(midpoint, toWorld)
	part.Parent = visual
	local weld = Instance.new("WeldConstraint")
	weld.Name = "AnalogVisualWeld"
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function findPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local candidate = character:FindFirstChild(name)
		if candidate and candidate:IsA("BasePart") then
			return candidate
		end
	end
	return nil
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
			local isHand = string.find(bodyName, "Hand") ~= nil
			local isFoot = string.find(bodyName, "Foot") ~= nil
			local color = if isHand then SKIN else CLOTH
			local material = if isHand or isFoot then Enum.Material.Slate else Enum.Material.Fabric
			weldedPart(
				visual,
				bodyPart,
				"AnalogBodySegment",
				Vector3.new(bodyPart.Size.X * scale.X, bodyPart.Size.Y * scale.Y, bodyPart.Size.Z * scale.Z),
				CFrame.identity,
				color,
				material
			)
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

local function addFace(visual: Model, head: BasePart)
	local tilt = CFrame.Angles(math.rad(-3), math.rad(2), math.rad(-7))
	weldedPart(
		visual,
		head,
		"BlackHeadShroud",
		Vector3.new(1.42, 1.92, 1.28),
		CFrame.new(0, 0.06, 0.02) * tilt,
		CLOTH_DEEP,
		Enum.Material.Fabric,
		Enum.PartType.Ball
	)
	weldedPart(
		visual,
		head,
		"PaleMaskUpper",
		Vector3.new(0.9, 0.92, 0.2),
		CFrame.new(-0.02, 0.13, -0.69) * tilt,
		MASK,
		Enum.Material.Concrete,
		Enum.PartType.Ball
	)
	weldedPart(
		visual,
		head,
		"PaleMaskLower",
		Vector3.new(0.62, 1.05, 0.18),
		CFrame.new(0.02, -0.45, -0.68) * tilt,
		MASK_SHADOW,
		Enum.Material.Concrete,
		Enum.PartType.Ball
	)

	for index, data in {
		{ 0.24, -8 },
		{ 0.13, 5 },
		{ 0.03, -3 },
	} do
		local band = weldedPart(
			visual,
			head,
			"BlindfoldLayer",
			Vector3.new(1.18 + index * 0.045, 0.18, 0.12),
			CFrame.new(0, data[1], -0.82) * CFrame.Angles(0, 0, math.rad(data[2])),
			CLOTH_DEEP,
			Enum.Material.Fabric
		)
		band.CastShadow = false
	end

	for _, side in { -1, 1 } do
		weldedPart(
			visual,
			head,
			"BlindfoldWrap",
			Vector3.new(0.2, 0.52, 0.82),
			CFrame.new(0.65 * side, 0.12, -0.02) * CFrame.Angles(0, 0, math.rad(8 * side)),
			CLOTH,
			Enum.Material.Fabric
		)
	end

	for _, x in { -0.2, 0.2 } do
		local eye = weldedPart(
			visual,
			head,
			"PinpointBlindEye",
			Vector3.new(0.075, 0.038, 0.035),
			CFrame.new(x, 0.17, -0.9),
			EYE,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		eye.CastShadow = false
		local halo = weldedPart(
			visual,
			head,
			"EyeLeak",
			Vector3.new(0.16, 0.075, 0.025),
			CFrame.new(x, 0.17, -0.914),
			EYE,
			Enum.Material.Neon
		)
		halo.Transparency = 0.74
		halo.CastShadow = false
		local light = Instance.new("PointLight")
		light.Name = "ColdEyeGlow"
		light.Color = EYE
		light.Brightness = 0.28
		light.Range = 2.6
		light.Shadows = false
		light.Parent = eye
	end

	weldedPart(
		visual,
		head,
		"ClosedFaceSeam",
		Vector3.new(0.04, 0.5, 0.03),
		CFrame.new(0.025, -0.47, -0.79) * CFrame.Angles(0, 0, math.rad(-3)),
		SEAM,
		Enum.Material.SmoothPlastic
	)

	for _, x in { -0.43, 0.46 } do
		weldedRod(
			visual,
			head,
			"HangingHeadThread",
			Vector3.new(x, -0.52, 0.22),
			Vector3.new(x * 1.08, -1.18, 0.28),
			0.05,
			CLOTH_DEEP,
			Enum.Material.Fabric
		)
	end
end

local function addUpperGarment(visual: Model, torso: BasePart)
	local front = -(torso.Size.Z / 2 + 0.12)
	local back = torso.Size.Z / 2 + 0.12
	weldedPart(
		visual,
		torso,
		"RobeChest",
		Vector3.new(torso.Size.X * 1.03, torso.Size.Y * 1.12, torso.Size.Z * 1.12),
		CFrame.new(0, -0.05, 0),
		CLOTH,
		Enum.Material.Fabric
	)

	for _, data in {
		{ 0.62, 2.18, -7 },
		{ 0.43, 2.02, 4 },
		{ 0.24, 1.88, -2 },
	} do
		weldedPart(
			visual,
			torso,
			"CowlFold",
			Vector3.new(data[2], 0.23, 0.22),
			CFrame.new(0, data[1], front - 0.03) * CFrame.Angles(0, 0, math.rad(data[3])),
			CLOTH_LIGHT,
			Enum.Material.Fabric
		)
	end

	for _, side in { -1, 1 } do
		weldedPart(
			visual,
			torso,
			"DroopingShoulderCloth",
			Vector3.new(0.78, if side < 0 then 0.72 else 0.52, torso.Size.Z * 1.2),
			CFrame.new((torso.Size.X / 2 + 0.22) * side, if side < 0 then 0.28 else 0.39, 0.02)
				* CFrame.Angles(0, 0, math.rad(11 * side)),
			if side < 0 then CLOTH_LIGHT else CLOTH,
			Enum.Material.Fabric
		)
	end

	local backDrape = weldedPart(
		visual,
		torso,
		"BackDrape",
		Vector3.new(torso.Size.X * 0.92, torso.Size.Y * 1.45, 0.2),
		CFrame.new(0.08, -0.3, back) * CFrame.Angles(math.rad(2), 0, math.rad(4)),
		CLOTH_LIGHT,
		Enum.Material.Fabric
	)
	backDrape.CastShadow = true

	for _, x in { -0.47, -0.17, 0.18, 0.48 } do
		local fold = weldedPart(
			visual,
			torso,
			"FrontClothFold",
			Vector3.new(0.05, torso.Size.Y * 0.8, 0.05),
			CFrame.new(x * torso.Size.X * 0.72, -0.12, front - 0.135),
			CLOTH_DEEP,
			Enum.Material.SmoothPlastic
		)
		fold.Transparency = 0.18
		fold.CastShadow = false
	end

	weldedPart(
		visual,
		torso,
		"BackCenterSeam",
		Vector3.new(0.05, torso.Size.Y * 1.18, 0.05),
		CFrame.new(0.08, -0.28, back + 0.12),
		CLOTH_DEEP,
		Enum.Material.SmoothPlastic
	)
end

local function addLongRobe(visual: Model, character: Model, lowerTorso: BasePart, root: BasePart)
	local floorY = characterFloorY(character, root)
	local drop = math.clamp(lowerTorso.Position.Y - floorY - 0.12, 2.7, 3.7)
	local panelWidth = math.max(0.62, lowerTorso.Size.X * 0.56)
	local panelDepth = math.max(0.32, lowerTorso.Size.Z * 0.48)
	local xOffset = panelWidth * 0.54
	local front = -(lowerTorso.Size.Z / 2 + panelDepth * 0.36)
	local back = lowerTorso.Size.Z / 2 + panelDepth * 0.36
	local centerY = -(drop / 2 - 0.32)

	for _, side in { -1, 1 } do
		weldedPart(
			visual,
			lowerTorso,
			"FrontRobePanel",
			Vector3.new(panelWidth, drop, panelDepth),
			CFrame.new(xOffset * side, centerY, front) * CFrame.Angles(math.rad(-1), 0, math.rad(-2.5 * side)),
			if side < 0 then CLOTH else CLOTH_LIGHT,
			Enum.Material.Fabric
		)
		weldedPart(
			visual,
			lowerTorso,
			"BackRobePanel",
			Vector3.new(panelWidth, drop * 0.98, panelDepth),
			CFrame.new(xOffset * side, centerY + 0.04, back) * CFrame.Angles(math.rad(1), 0, math.rad(2 * side)),
			CLOTH,
			Enum.Material.Fabric
		)
	end

	for _, side in { -1, 1 } do
		weldedPart(
			visual,
			lowerTorso,
			"SideRobePanel",
			Vector3.new(0.2, drop * 0.9, lowerTorso.Size.Z * 1.18),
			CFrame.new((panelWidth + 0.18) * side, centerY + 0.08, 0),
			CLOTH_DEEP,
			Enum.Material.Fabric
		)
	end

	for index, x in { -0.72, -0.36, 0, 0.34, 0.7 } do
		local length = 0.26 + (index % 3) * 0.12
		weldedPart(
			visual,
			lowerTorso,
			"FrayedHem",
			Vector3.new(0.2, length, 0.22),
			CFrame.new(x, 0.3 - drop - length / 2, front - 0.04) * CFrame.Angles(0, 0, math.rad((index - 3) * 3)),
			CLOTH_DEEP,
			Enum.Material.Fabric
		)
	end

	for _, x in { -0.48, -0.16, 0.2, 0.52 } do
		local fold = weldedPart(
			visual,
			lowerTorso,
			"LongRobeFold",
			Vector3.new(0.05, drop * 0.74, 0.05),
			CFrame.new(x, centerY - 0.08, front - panelDepth / 2 - 0.025),
			CLOTH_DEEP,
			Enum.Material.SmoothPlastic
		)
		fold.Transparency = 0.16
		fold.CastShadow = false
	end

	weldedPart(visual, lowerTorso, "ClothBeltFront", Vector3.new(1.72, 0.16, 0.18), CFrame.new(0, 0.34, front - 0.08), CLOTH_LIGHT, Enum.Material.Fabric)
	weldedPart(visual, lowerTorso, "ClothBeltBack", Vector3.new(1.72, 0.16, 0.18), CFrame.new(0, 0.34, back + 0.08), CLOTH_LIGHT, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		weldedPart(visual, lowerTorso, "ClothBeltSide", Vector3.new(0.16, 0.16, lowerTorso.Size.Z * 1.2), CFrame.new(0.86 * side, 0.34, 0), CLOTH_LIGHT, Enum.Material.Fabric)
	end
	weldedPart(visual, lowerTorso, "BeltKnot", Vector3.new(0.28, 0.24, 0.2), CFrame.new(0.2, 0.3, back + 0.18), CLOTH_LIGHT, Enum.Material.Fabric, Enum.PartType.Ball)
	for _, x in { 0.1, 0.31 } do
		weldedPart(
			visual,
			lowerTorso,
			"BackSashTail",
			Vector3.new(0.17, drop * 0.63, 0.12),
			CFrame.new(x, -(drop * 0.34), back + 0.16) * CFrame.Angles(math.rad(2), 0, math.rad(if x < 0.2 then -4 else 5)),
			CLOTH_LIGHT,
			Enum.Material.Fabric
		)
	end
end

local function addLimbWraps(visual: Model, limb: BasePart, prefix: string)
	for index, y in { -0.22, 0.14 } do
		weldedPart(
			visual,
			limb,
			prefix .. "Wrap",
			Vector3.new(limb.Size.X * 0.92, 0.11, limb.Size.Z * 0.92),
			CFrame.new(0, y * limb.Size.Y, 0) * CFrame.Angles(0, 0, math.rad(if index == 1 then -6 else 5)),
			CLOTH_LIGHT,
			Enum.Material.Fabric
		)
	end
end

local function addHand(visual: Model, hand: BasePart, side: number)
	local palmHeight = math.clamp(hand.Size.Y * 0.9, 0.7, 1)
	local palmCenterY = -(hand.Size.Y / 2 + palmHeight / 2 - 0.2)
	weldedPart(
		visual,
		hand,
		"LongPalm",
		Vector3.new(0.46, palmHeight, 0.3),
		CFrame.new(0, palmCenterY, -0.02) * CFrame.Angles(math.rad(3), 0, math.rad(2 * side)),
		SKIN,
		Enum.Material.Slate
	)

	local fingerTop = palmCenterY - palmHeight / 2 + 0.12
	for index, x in { -0.18, -0.06, 0.06, 0.18 } do
		local outer = math.abs(index - 2.5) / 1.5
		weldedRod(
			visual,
			hand,
			"LongFinger",
			Vector3.new(x, fingerTop, -0.03),
			Vector3.new(x + (index - 2.5) * 0.055 * side, fingerTop - 0.62 - outer * 0.12, -0.08),
			0.055,
			SKIN,
			Enum.Material.Slate
		)
	end
end

local function addLimbDetails(visual: Model, character: Model)
	local leftLowerArm = findPart(character, { "LeftLowerArm", "Left Arm" })
	local rightLowerArm = findPart(character, { "RightLowerArm", "Right Arm" })
	local leftLowerLeg = findPart(character, { "LeftLowerLeg", "Left Leg" })
	local rightLowerLeg = findPart(character, { "RightLowerLeg", "Right Leg" })
	if leftLowerArm then
		addLimbWraps(visual, leftLowerArm, "LeftCuff")
	end
	if rightLowerArm then
		addLimbWraps(visual, rightLowerArm, "RightCuff")
	end
	if leftLowerLeg then
		addLimbWraps(visual, leftLowerLeg, "LeftAnkle")
	end
	if rightLowerLeg then
		addLimbWraps(visual, rightLowerLeg, "RightAnkle")
	end

	local leftHand = findPart(character, { "LeftHand", "Left Arm" })
	local rightHand = findPart(character, { "RightHand", "Right Arm" })
	if leftHand then
		addHand(visual, leftHand, -1)
	end
	if rightHand then
		addHand(visual, rightHand, 1)
	end
end

function MonsterAppearance.Apply(character: Model)
	MonsterAppearance.Clear(character)
	hideAvatar(character)

	local visual = Instance.new("Model")
	visual.Name = VISUAL_NAME
	visual:SetAttribute("Articulated", true)
	visual:SetAttribute("DesignVersion", "AnalogNativeV1")
	visual:SetAttribute("UsesImportedAsset", false)
	visual.Parent = character

	addBodyShell(visual, character)

	local head = findPart(character, { "Head" })
	if head then
		addFace(visual, head)
	end

	local upperTorso = findPart(character, { "UpperTorso", "Torso" })
	if upperTorso then
		addUpperGarment(visual, upperTorso)
	end

	local lowerTorso = findPart(character, { "LowerTorso", "Torso" })
	local root = findPart(character, { "HumanoidRootPart" })
	if lowerTorso and root then
		addLongRobe(visual, character, lowerTorso, root)
	end

	addLimbDetails(visual, character)

	local aura = Instance.new("Highlight")
	aura.Name = "DarkAura"
	aura.Adornee = visual
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.FillColor = Color3.fromRGB(0, 0, 0)
	aura.FillTransparency = 0.93
	aura.OutlineColor = Color3.fromRGB(62, 64, 68)
	aura.OutlineTransparency = 0.62
	aura.Parent = visual
end

return MonsterAppearance
