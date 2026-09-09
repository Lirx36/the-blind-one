--!strict
-- The imported monster is intentionally a single high-detail shell rather
-- than a skinned Roblox rig. This adds weight and gait motion to that shell so
-- it breathes while idle and no longer looks frozen while moving.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type MotionState = {
	phase: number,
	transform: CFrame,
	baseC0: CFrame,
}

local states: { [Motor6D]: MotionState } = {}
type LimpState = {
	phase: number,
	poses: { [Motor6D]: CFrame },
	bases: { [Motor6D]: CFrame },
}
local limpStates: { [Model]: LimpState } = {}
local disabledAnimateScripts: { [LocalScript]: boolean } = {}

local function suppressDefaultAnimations(character: Model, suppressed: boolean)
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		if suppressed then
			if disabledAnimateScripts[animate] == nil then
				disabledAnimateScripts[animate] = animate.Enabled
			end
			animate.Enabled = false
		elseif disabledAnimateScripts[animate] ~= nil then
			animate.Enabled = disabledAnimateScripts[animate]
			disabledAnimateScripts[animate] = nil
		end
	end
	if not suppressed then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		-- The stock Roblox walk visibly fights the procedural injured-leg pose.
		-- Stop it locally on every viewer; the limp below becomes the only gait.
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.12)
		end
	end
end

local function findJoint(character: Model, name: string): Motor6D?
	local joint = character:FindFirstChild(name, true)
	return if joint and joint:IsA("Motor6D") then joint else nil
end

local function poseJoint(state: LimpState, joint: Motor6D?, target: CFrame, alpha: number)
	if not joint then
		return
	end
	local current = state.poses[joint] or target
	current = current:Lerp(target, alpha)
	state.poses[joint] = current
	if state.bases[joint] == nil then
		state.bases[joint] = joint.C0
	end
	-- C0 is not touched by Roblox's Animator, unlike Transform. Applying the
	-- procedural offset here makes every imported segment reliably follow it.
	joint.Transform = CFrame.identity
	joint.C0 = state.bases[joint] * current
end

local function animateLimp(character: Model, humanoid: Humanoid, root: BasePart, dt: number, now: number, forcedSpeed: number?)
	local state = limpStates[character]
	if not state then
		state = { phase = 0, poses = {}, bases = {} }
		limpStates[character] = state
	end

	local velocity = root.AssemblyLinearVelocity
	local measuredSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local horizontalSpeed = forcedSpeed or measuredSpeed
	local moving = horizontalSpeed > 0.65 and (forcedSpeed ~= nil or humanoid.MoveDirection.Magnitude > 0.05)
	local speedWeight = math.clamp(horizontalSpeed / 15, 0, 1)
	if moving then
		-- One deliberately slow cycle: the healthy leg carries the body, then the
		-- injured leg drags forward late. All curves are continuous at the loop.
		state.phase += dt * (2.65 + horizontalSpeed * 0.13)
	end

	local cycle = math.sin(state.phase)
	local halfWave = 0.5 - 0.5 * math.cos(state.phase)
	local injuredLoad = halfWave * halfWave * (3 - 2 * halfWave)
	local healthyLoad = 1 - injuredLoad
	local dragLift = math.max(0, -cycle)
	local alpha = 1 - math.exp(-(if moving then 8.5 else 4.5) * dt)

	local rootJoint = findJoint(character, "Root")
	local waist = findJoint(character, "Waist")
	local neck = findJoint(character, "Neck")
	local leftHip = findJoint(character, "LeftHip")
	local rightHip = findJoint(character, "RightHip")
	local leftKnee = findJoint(character, "LeftKnee")
	local rightKnee = findJoint(character, "RightKnee")
	local leftAnkle = findJoint(character, "LeftAnkle")
	local rightAnkle = findJoint(character, "RightAnkle")
	local leftShoulder = findJoint(character, "LeftShoulder")
	local rightShoulder = findJoint(character, "RightShoulder")
	local leftElbow = findJoint(character, "LeftElbow")
	local rightElbow = findJoint(character, "RightElbow")

	if moving then
		local hardPlant = injuredLoad * injuredLoad
		local torsoDrop = injuredLoad * (0.18 + speedWeight * 0.08)
		local torsoRoll = math.rad(3.5 + injuredLoad * 9 - healthyLoad * 1.5)
		local lurchForward = injuredLoad * 0.055
		-- The entire creature buckles onto its damaged right leg once per cycle.
		-- This remains obvious even at a distance, while the limbs sell the drag.
		poseJoint(state, rootJoint, CFrame.new(-hardPlant * 0.11, -hardPlant * 0.22, -hardPlant * 0.045)
			* CFrame.Angles(math.rad(-hardPlant * 3.5), 0, math.rad(hardPlant * 7.5)), alpha)
		poseJoint(state, waist, CFrame.new(0, -torsoDrop, -lurchForward)
			* CFrame.Angles(math.rad(-9.5 - injuredLoad * 5), cycle * math.rad(1.5), torsoRoll), alpha)
		poseJoint(state, neck, CFrame.Angles(math.rad(5.5 + injuredLoad * 1.5), 0, -torsoRoll * 0.48), alpha)

		-- Healthy left leg takes the full stride. The hurt right leg remains
		-- flexed, takes only a quarter stride, and catches up late with a toe drag.
		poseJoint(state, leftHip, CFrame.Angles(cycle * math.rad(31), 0, math.rad(-2)), alpha)
		poseJoint(state, leftKnee, CFrame.Angles(math.max(0, cycle) * math.rad(30), 0, 0), alpha)
		poseJoint(state, leftAnkle, CFrame.Angles(-math.max(0, cycle) * math.rad(9), 0, 0), alpha)
		poseJoint(state, rightHip, CFrame.Angles(math.rad(13) - cycle * math.rad(6), 0, math.rad(8)), alpha)
		poseJoint(state, rightKnee, CFrame.Angles(math.rad(28) + dragLift * math.rad(16), 0, 0), alpha)
		poseJoint(state, rightAnkle, CFrame.Angles(math.rad(-15) + dragLift * math.rad(5), 0, math.rad(-4)), alpha)

		-- Long arms counterbalance the limp; the right side hangs heavier.
		poseJoint(state, leftShoulder, CFrame.Angles(-cycle * math.rad(12), 0, math.rad(-5)), alpha)
		poseJoint(state, rightShoulder, CFrame.Angles(cycle * math.rad(6) + math.rad(5), 0, math.rad(8)), alpha)
		poseJoint(state, leftElbow, CFrame.Angles(math.rad(8) + injuredLoad * math.rad(4), 0, 0), alpha)
		poseJoint(state, rightElbow, CFrame.Angles(math.rad(19) + dragLift * math.rad(3), 0, 0), alpha)
	else
		local breath = math.sin(now * 1.45)
		poseJoint(state, rootJoint, CFrame.new(0, breath * 0.012, 0) * CFrame.Angles(0, 0, math.rad(1.5)), alpha)
		poseJoint(state, waist, CFrame.new(0, breath * 0.018, 0)
			* CFrame.Angles(math.rad(-7 + breath * 0.5), 0, math.rad(4.5)), alpha)
		poseJoint(state, neck, CFrame.Angles(math.rad(4 - breath * 0.35), 0, math.rad(-2.5)), alpha)
		poseJoint(state, leftHip, CFrame.Angles(math.rad(-2), 0, math.rad(-1)), alpha)
		poseJoint(state, rightHip, CFrame.Angles(math.rad(11), 0, math.rad(6)), alpha)
		poseJoint(state, leftKnee, CFrame.identity, alpha)
		poseJoint(state, rightKnee, CFrame.Angles(math.rad(24), 0, 0), alpha)
		poseJoint(state, leftAnkle, CFrame.identity, alpha)
		poseJoint(state, rightAnkle, CFrame.Angles(math.rad(-11), 0, math.rad(-3)), alpha)
		poseJoint(state, leftShoulder, CFrame.Angles(math.rad(-3 + breath), 0, math.rad(-4)), alpha)
		poseJoint(state, rightShoulder, CFrame.Angles(math.rad(7 - breath), 0, math.rad(8)), alpha)
		poseJoint(state, leftElbow, CFrame.Angles(math.rad(7), 0, 0), alpha)
		poseJoint(state, rightElbow, CFrame.Angles(math.rad(18), 0, 0), alpha)
	end
end

local function animateCharacter(character: Model, dt: number, now: number, forcedSpeed: number?)
	local visual = character:FindFirstChild("BlindOneVisual")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not visual or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	if visual:GetAttribute("Articulated") == true then
		animateLimp(character, humanoid, root, dt, now, forcedSpeed)
		return
	end

	local motor = visual:FindFirstChild("BlindOneVisualMotor", true)
	if not motor or not motor:IsA("Motor6D") then
		return
	end

	local state = states[motor]
	if not state then
		state = { phase = 0, transform = CFrame.identity, baseC0 = motor.C0 }
		states[motor] = state
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = horizontalSpeed > 0.75 and humanoid.MoveDirection.Magnitude > 0.05
	local sprintWeight = math.clamp((horizontalSpeed - 10) / 8, 0, 1)
	local target: CFrame

	if moving then
		state.phase += dt * (3.35 + horizontalSpeed * 0.18)
		local step = math.sin(state.phase)
		local injuredPlant = math.max(0, step) ^ 2
		local bob = math.abs(step) * 0.055 - injuredPlant * (0.19 + sprintWeight * 0.05)
		local sway = step * 0.035 - injuredPlant * 0.12
		local roll = math.rad(2) + injuredPlant * math.rad(9)
		local pitch = math.rad(5) + injuredPlant * math.rad(4)
		local localVelocity = root.CFrame:VectorToObjectSpace(velocity)
		local directionalLean = math.clamp(-localVelocity.X / 22, -1, 1) * math.rad(2.2)
		target = CFrame.new(sway, bob, 0) * CFrame.Angles(-pitch, 0, roll + directionalLean)
	else
		local breath = math.sin(now * 1.7)
		local slowSway = math.sin(now * 0.72)
		target = CFrame.new(slowSway * 0.018, breath * 0.025, 0)
			* CFrame.Angles(math.rad(breath * 0.42), 0, math.rad(slowSway * 0.35))
	end

	local responsiveness = if moving then 13 else 5
	local alpha = 1 - math.exp(-responsiveness * dt)
	state.transform = state.transform:Lerp(target, alpha)
	motor.Transform = CFrame.identity
	motor.C0 = state.baseC0 * state.transform
end

-- Roblox's Animator writes Motor6D.Transform before PreSimulation. Applying the
-- limp here makes it the final authoritative pose instead of letting the normal
-- walk animation overwrite it on the following frame.
RunService.PreSimulation:Connect(function(dt)
	local now = time()
	local seen: { [Motor6D]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and player:GetAttribute("Role") == "BlindOne" then
			suppressDefaultAnimations(character, true)
			animateCharacter(character, dt, now)
			local visual = character:FindFirstChild("BlindOneVisual")
			local motor = visual and visual:FindFirstChild("BlindOneVisualMotor", true)
			if motor and motor:IsA("Motor6D") then
				seen[motor] = true
			end
		elseif character then
			suppressDefaultAnimations(character, false)
		end
	end
	local aiMonster = workspace:FindFirstChild("TheBlindOne")
	if aiMonster and aiMonster:IsA("Model") then
		suppressDefaultAnimations(aiMonster, true)
		local visualSpeed = aiMonster:GetAttribute("VisualMoveSpeed")
		animateCharacter(aiMonster, dt, now, if typeof(visualSpeed) == "number" then visualSpeed else 0)
	end

	for motor in states do
		if not seen[motor] or not motor.Parent then
			local oldState = states[motor]
			if motor.Parent then
				motor.C0 = oldState.baseC0
				motor.Transform = CFrame.identity
			end
			states[motor] = nil
		end
	end
	for character in limpStates do
		local player = Players:GetPlayerFromCharacter(character)
		local isAiMonster = character.Name == "TheBlindOne" and character.Parent == workspace
		local visual = character:FindFirstChild("BlindOneVisual")
		local shouldRemove = not character.Parent
			or (not isAiMonster and (not player or player:GetAttribute("Role") ~= "BlindOne"))
			or not visual
			or visual:GetAttribute("Articulated") ~= true
		if shouldRemove then
			local oldState = limpStates[character]
			for joint, baseC0 in oldState.bases do
				if joint.Parent then
					joint.C0 = baseC0
					joint.Transform = CFrame.identity
				end
			end
			limpStates[character] = nil
		end
	end
	for animate, originalEnabled in disabledAnimateScripts do
		local character = animate:FindFirstAncestorOfClass("Model")
		local owner = character and Players:GetPlayerFromCharacter(character)
		local isAiMonster = character ~= nil and character.Name == "TheBlindOne" and character.Parent == workspace
		local shouldRemainDisabled = isAiMonster or (owner ~= nil and owner:GetAttribute("Role") == "BlindOne")
		if not animate.Parent or not shouldRemainDisabled then
			if animate.Parent then
				animate.Enabled = originalEnabled
			end
			disabledAnimateScripts[animate] = nil
		end
	end
end)
