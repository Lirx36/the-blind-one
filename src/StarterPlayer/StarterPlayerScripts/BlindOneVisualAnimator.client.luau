--!strict
-- The imported monster is intentionally a single high-detail shell rather
-- than a skinned Roblox rig. This adds weight and gait motion to that shell so
-- it breathes while idle and no longer looks frozen while moving.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type MotionState = {
	phase: number,
	transform: CFrame,
}

local states: { [Motor6D]: MotionState } = {}
type LimpState = {
	phase: number,
	poses: { [Motor6D]: CFrame },
}
local limpStates: { [Model]: LimpState } = {}

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
	joint.Transform = current
end

local function animateLimp(character: Model, humanoid: Humanoid, root: BasePart, dt: number, now: number, forcedSpeed: number?)
	local state = limpStates[character]
	if not state then
		state = { phase = 0, poses = {} }
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
		local torsoDrop = injuredLoad * (0.13 + speedWeight * 0.05)
		local torsoRoll = math.rad(2.5 + injuredLoad * 6.5 - healthyLoad * 1.2)
		local lurchForward = injuredLoad * 0.055
		poseJoint(state, waist, CFrame.new(0, -torsoDrop, -lurchForward)
			* CFrame.Angles(math.rad(-8.5 - injuredLoad * 4), cycle * math.rad(1.2), torsoRoll), alpha)
		poseJoint(state, neck, CFrame.Angles(math.rad(5.5 + injuredLoad * 1.5), 0, -torsoRoll * 0.48), alpha)

		-- Healthy left leg takes the full stride. The hurt right leg remains
		-- flexed, takes only a quarter stride, and catches up late with a toe drag.
		poseJoint(state, leftHip, CFrame.Angles(cycle * math.rad(25), 0, math.rad(-1.5)), alpha)
		poseJoint(state, leftKnee, CFrame.Angles(math.max(0, cycle) * math.rad(24), 0, 0), alpha)
		poseJoint(state, leftAnkle, CFrame.Angles(-math.max(0, cycle) * math.rad(9), 0, 0), alpha)
		poseJoint(state, rightHip, CFrame.Angles(math.rad(9) - cycle * math.rad(5.5), 0, math.rad(6.5)), alpha)
		poseJoint(state, rightKnee, CFrame.Angles(math.rad(23) + dragLift * math.rad(12), 0, 0), alpha)
		poseJoint(state, rightAnkle, CFrame.Angles(math.rad(-15) + dragLift * math.rad(5), 0, math.rad(-4)), alpha)

		-- Long arms counterbalance the limp; the right side hangs heavier.
		poseJoint(state, leftShoulder, CFrame.Angles(-cycle * math.rad(12), 0, math.rad(-5)), alpha)
		poseJoint(state, rightShoulder, CFrame.Angles(cycle * math.rad(6) + math.rad(5), 0, math.rad(8)), alpha)
		poseJoint(state, leftElbow, CFrame.Angles(math.rad(8) + injuredLoad * math.rad(4), 0, 0), alpha)
		poseJoint(state, rightElbow, CFrame.Angles(math.rad(19) + dragLift * math.rad(3), 0, 0), alpha)
	else
		local breath = math.sin(now * 1.45)
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
		state = { phase = 0, transform = CFrame.identity }
		states[motor] = state
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = horizontalSpeed > 0.75 and humanoid.MoveDirection.Magnitude > 0.05
	local sprintWeight = math.clamp((horizontalSpeed - 10) / 8, 0, 1)
	local target: CFrame

	if moving then
		state.phase += dt * (5.1 + horizontalSpeed * 0.36)
		local step = math.sin(state.phase)
		local doubleStep = math.sin(state.phase * 2)
		local bob = math.abs(step) * (0.075 + sprintWeight * 0.07)
		local sway = step * (0.045 + sprintWeight * 0.035)
		local roll = step * math.rad(1.5 + sprintWeight * 1.6)
		local pitch = math.rad(2.3 + sprintWeight * 3.2) + doubleStep * math.rad(0.7)
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
	motor.Transform = state.transform
end

RunService:BindToRenderStep("BlindOneLimpAnimator", Enum.RenderPriority.Character.Value + 5, function(dt)
	local now = time()
	local seen: { [Motor6D]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and player:GetAttribute("Role") == "BlindOne" then
			animateCharacter(character, dt, now)
			local visual = character:FindFirstChild("BlindOneVisual")
			local motor = visual and visual:FindFirstChild("BlindOneVisualMotor", true)
			if motor and motor:IsA("Motor6D") then
				seen[motor] = true
			end
		end
	end
	local aiMonster = workspace:FindFirstChild("TheBlindOne")
	if aiMonster and aiMonster:IsA("Model") then
		local visualSpeed = aiMonster:GetAttribute("VisualMoveSpeed")
		animateCharacter(aiMonster, dt, now, if typeof(visualSpeed) == "number" then visualSpeed else 0)
	end

	for motor in states do
		if not seen[motor] or not motor.Parent then
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
			for joint in oldState.poses do
				if joint.Parent then
					joint.Transform = CFrame.identity
				end
			end
			limpStates[character] = nil
		end
	end
end)
