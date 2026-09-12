--!strict
-- First-person camera plus a lightweight local crouch presentation. Looking down
-- shows the lower body without repeatedly walking the full character hierarchy.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character: Model? = nil
local humanoid: Humanoid? = nil
local crouchAlpha = 0
local poseApplied = false
local flashlightPoseApplied = false
local descendantAddedConnection: RBXScriptConnection? = nil
local descendantRemovingConnection: RBXScriptConnection? = nil

-- A small forward offset keeps the camera in front of the face instead of inside
-- the upper torso. Crouching lowers it less than before because the pose itself
-- also lowers the visible character.
local STANDING_CAMERA_OFFSET = Vector3.new(0, 0.3, -0.85)
local CROUCH_CAMERA_OFFSET = Vector3.new(0, -0.32, -0.85)
local CAMERA_RESPONSE = 12

local VISIBLE_BODY_PARTS = {
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local CROUCH_JOINTS = {
	Root = true,
	Waist = true,
	LeftHip = true,
	RightHip = true,
	LeftKnee = true,
	RightKnee = true,
	LeftAnkle = true,
	RightAnkle = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	["Right Shoulder"] = true,
}

local visibleParts: { [BasePart]: boolean } = {}
local hiddenFirstPersonParts: { [BasePart]: boolean } = {}
local joints: { [string]: any } = {}

local function isHeadAccessory(accessory: Accessory): boolean
	local accessoryType = accessory.AccessoryType
	if accessoryType == Enum.AccessoryType.Hat
		or accessoryType == Enum.AccessoryType.Hair
		or accessoryType == Enum.AccessoryType.Face then
		return true
	end

	-- Older catalog items are often reported as Unknown, so attachment placement
	-- is the reliable fallback for hair, hats, glasses, and other face items.
	return accessory:FindFirstChild("HatAttachment", true) ~= nil
		or accessory:FindFirstChild("HairAttachment", true) ~= nil
		or accessory:FindFirstChild("FaceFrontAttachment", true) ~= nil
		or accessory:FindFirstChild("FaceCenterAttachment", true) ~= nil
end

-- Studio's Duplicate shortcut can accidentally copy the selected avatar during
-- a playtest when Ctrl is used for crouching. Remove only local orphan copies;
-- the player's real Character is never touched.
local function removeAccidentalCharacterCopy(candidate: Instance)
	task.defer(function()
		if candidate.Parent == workspace
			and candidate:IsA("Model")
			and candidate ~= player.Character
			and candidate.Name == player.Name
			and candidate:FindFirstChildOfClass("Humanoid") then
			candidate:Destroy()
		end
	end)
end

workspace.ChildAdded:Connect(removeAccidentalCharacterCopy)

local function lockCamera()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
end

local function updateCameraMode()
	if player:GetAttribute("InMatch") == true then
		lockCamera()
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 14
	end
end

local function cacheDescendant(descendant: Instance)
	if descendant:IsA("BasePart") then
		local accessory = descendant:FindFirstAncestorOfClass("Accessory")
		if descendant.Name == "Head"
			or (accessory and accessory:IsA("Accessory") and isHeadAccessory(accessory)) then
			hiddenFirstPersonParts[descendant] = true
		elseif VISIBLE_BODY_PARTS[descendant.Name] or accessory ~= nil then
			-- Keep layered jackets, shirts, pants, shoes, and body accessories. These
			-- are what give the first-person body the dressed look in the references.
			visibleParts[descendant] = true
		end
	end
	if CROUCH_JOINTS[descendant.Name]
		and (descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint") or descendant:IsA("Bone")) then
		joints[descendant.Name] = descendant
	end
end

local function forgetDescendant(descendant: Instance)
	if descendant:IsA("BasePart") then
		visibleParts[descendant] = nil
		hiddenFirstPersonParts[descendant] = nil
	end
	if joints[descendant.Name] == descendant then
		joints[descendant.Name] = nil
	end
end

local function setCharacter(nextCharacter: Model)
	local nextHumanoid = nextCharacter:WaitForChild("Humanoid") :: Humanoid
	if descendantAddedConnection then
		descendantAddedConnection:Disconnect()
	end
	if descendantRemovingConnection then
		descendantRemovingConnection:Disconnect()
	end

	character = nextCharacter
	humanoid = nextHumanoid
	crouchAlpha = 0
	poseApplied = false
	flashlightPoseApplied = false
	visibleParts = {}
	hiddenFirstPersonParts = {}
	joints = {}
	for _, descendant in nextCharacter:GetDescendants() do
		cacheDescendant(descendant)
	end
	descendantAddedConnection = nextCharacter.DescendantAdded:Connect(cacheDescendant)
	descendantRemovingConnection = nextCharacter.DescendantRemoving:Connect(forgetDescendant)

	nextHumanoid.CameraOffset = if player:GetAttribute("InMatch") == true then STANDING_CAMERA_OFFSET else Vector3.zero
	updateCameraMode()
end

local function setJointTransform(name: string, transform: CFrame)
	local joint = joints[name]
	if joint and joint.Parent then
		joint.Transform = transform
	end
end

local function setCrouchPose(alpha: number)
	-- Absolute transforms are intentional: multiplying the previous Transform each
	-- frame compounds rotations and can destabilize upgraded avatar constraints.
	setJointTransform("Root", CFrame.new(0, -0.65 * alpha, 0))
	setJointTransform("LeftHip", CFrame.Angles(math.rad(-32 * alpha), 0, math.rad(-4 * alpha)))
	setJointTransform("RightHip", CFrame.Angles(math.rad(-32 * alpha), 0, math.rad(4 * alpha)))
	setJointTransform("LeftKnee", CFrame.Angles(math.rad(68 * alpha), 0, 0))
	setJointTransform("RightKnee", CFrame.Angles(math.rad(68 * alpha), 0, 0))
	setJointTransform("LeftAnkle", CFrame.Angles(math.rad(-34 * alpha), 0, 0))
	setJointTransform("RightAnkle", CFrame.Angles(math.rad(-34 * alpha), 0, 0))
	setJointTransform("Waist", CFrame.Angles(math.rad(10 * alpha), 0, 0))
end

local function setFlashlightArmPose()
	-- Keep the right arm extended so the hand meets the flashlight grip. Both R15
	-- and classic R6 shoulder names are supported. As the player looks down, lower
	-- the arm with the camera so it remains behind the viewmodel instead of clipping it.
	local camera = workspace.CurrentCamera
	local lookDown = if camera then math.clamp(-camera.CFrame.LookVector.Y, 0, 1) else 0
	local shoulderPitch = 112 - 52 * lookDown
	local elbowPitch = -12 + 18 * lookDown
	setJointTransform("RightShoulder", CFrame.Angles(math.rad(shoulderPitch), math.rad(-6), math.rad(10)))
	setJointTransform("RightElbow", CFrame.Angles(math.rad(elbowPitch), 0, math.rad(-3)))
	setJointTransform("RightWrist", CFrame.Angles(math.rad(-6), 0, 0))
	setJointTransform("Right Shoulder", CFrame.Angles(math.rad(shoulderPitch), 0, math.rad(10)))
end

local function clearFlashlightArmPose()
	setJointTransform("RightShoulder", CFrame.identity)
	setJointTransform("RightElbow", CFrame.identity)
	setJointTransform("RightWrist", CFrame.identity)
	setJointTransform("Right Shoulder", CFrame.identity)
end

if player.Character then
	setCharacter(player.Character)
else
	updateCameraMode()
end
player.CharacterAdded:Connect(setCharacter)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	updateCameraMode()
	if humanoid then
		humanoid.CameraOffset = if player:GetAttribute("InMatch") == true then STANDING_CAMERA_OFFSET else Vector3.zero
	end
end)

-- Run after Roblox's camera transparency pass and touch only the cached lower-body
-- parts. This is a small, constant amount of work per rendered frame.
RunService:BindToRenderStep("FirstPersonLowerBody", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local currentCharacter = character
	local currentHumanoid = humanoid
	if not currentCharacter or not currentHumanoid or currentHumanoid.Health <= 0 then
		return
	end
	if player:GetAttribute("InMatch") ~= true then
		currentHumanoid.CameraOffset = Vector3.zero
		for part in visibleParts do
			if part.Parent then part.LocalTransparencyModifier = 0 end
		end
		for part in hiddenFirstPersonParts do
			if part.Parent then part.LocalTransparencyModifier = 0 end
		end
		return
	end

	local isCrouched = player:GetAttribute("Crouched") == true
	local targetAlpha = if isCrouched then 1 else 0
	local blend = 1 - math.exp(-CAMERA_RESPONSE * dt)
	crouchAlpha += (targetAlpha - crouchAlpha) * blend
	local targetCameraOffset = if isCrouched then CROUCH_CAMERA_OFFSET else STANDING_CAMERA_OFFSET
	currentHumanoid.CameraOffset = currentHumanoid.CameraOffset:Lerp(targetCameraOffset, blend)

	for part in visibleParts do
		if part.Parent then
			part.LocalTransparencyModifier = if player:GetAttribute("PhotoModeActive") == true then 1 else 0
		end
	end
	for part in hiddenFirstPersonParts do
		if part.Parent then
			part.LocalTransparencyModifier = 1
		end
	end
end)

-- The Animator has finished before PreSimulation, so this pose layers at the final
-- safe point. Assigning absolute transforms prevents runaway accumulation.
RunService.PreSimulation:Connect(function()
	local currentHumanoid = humanoid
	if not currentHumanoid or currentHumanoid.Health <= 0 then
		return
	end

	if crouchAlpha >= 0.001 then
		setCrouchPose(crouchAlpha)
		poseApplied = true
	elseif poseApplied then
		setCrouchPose(0)
		poseApplied = false
	end
	if player:GetAttribute("InMatch") == true and player:GetAttribute("Role") ~= "BlindOne" and player:GetAttribute("PhotoModeActive") ~= true then
		setFlashlightArmPose()
		flashlightPoseApplied = true
	elseif flashlightPoseApplied then
		clearFlashlightArmPose()
		flashlightPoseApplied = false
	end
end)
