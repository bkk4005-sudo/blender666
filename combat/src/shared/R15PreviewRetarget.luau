-- Studio-only preview bake. Published animations must be approved for their
-- intended RigProfile; this module never changes HumanoidRootPart at runtime.
local RunService = game:GetService("RunService")
local Visual = require(script.Parent.WeaponVisualConfig)
local Clearance = require(script.Parent.BladeClearance)
local Retarget = {}
local names = {"LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm",
    "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg",
    "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
local supported = {}
for _, name in names do supported[name] = true end

local function boxFloor(frame: CFrame, size: Vector3): number
    local low = math.huge
    for _, x in {-1, 1} do
        for _, y in {-1, 1} do
            for _, z in {-1, 1} do
                low = math.min(low, frame:PointToWorldSpace(size * Vector3.new(x, y, z) / 2).Y)
            end
        end
    end
    return low
end

local function skeleton(character: Model)
    local joints = {}
    for _, joint in character:GetDescendants() do
        local part0, part1, c0, c1
        if joint:IsA("Motor6D") then
            part0, part1, c0, c1 = joint.Part0, joint.Part1, joint.C0, joint.C1
        elseif joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
            part0, part1 = joint.Attachment0.Parent, joint.Attachment1.Parent
            c0, c1 = joint.Attachment0.CFrame, joint.Attachment1.CFrame
        end
        if part0 and part1 and supported[part1.Name] and part1:IsA("BasePart") then
            joints[part1.Name] = {parent = part0.Name, c0 = c0, c1 = c1, size = part1.Size}
        end
    end
    local rest = {HumanoidRootPart = CFrame.new()}
    local ground = math.huge
    for _, name in names do
        local joint = assert(joints[name], "R15 preview joint missing: " .. name)
        rest[name] = assert(rest[joint.parent]) * joint.c0 * joint.c1:Inverse()
        ground = math.min(ground, boxFloor(rest[name], joint.size))
    end
    return joints, ground
end

function Retarget.forCharacter(source: KeyframeSequence, character: Model): KeyframeSequence
    assert(RunService:IsStudio(), "Avatar preview retarget is Studio-only")
    local joints, ground = skeleton(character)
    local sequence = source:Clone()
    -- AuthoredHipHeight cannot be written by a game script (Plugin security).
    -- Compensate the Animator's root translation scaling in the baked poses.
    local height = character:FindFirstChildOfClass("Humanoid").HipHeight
    ground = -(height + character.HumanoidRootPart.Size.Y / 2)
    local metadata = assert(sequence:FindFirstChild("SourceAuthoredHipHeight"), "Authored height metadata missing")
    local translationScale = if height > .01 and metadata.Value > .01
        then height / metadata.Value else 1
    sequence:SetAttribute("PreviewRig", character.Name)
    local keys = sequence:GetKeyframes()
    table.sort(keys, function(a, b) return a.Time < b.Time end)
    local duration = keys[#keys].Time
    local previous, unresolved, maxCorrection = nil, 0, 0
    for _, key in keys do
        local poses = {}
        for _, pose in key:GetDescendants() do
            if pose:IsA("Pose") then poses[pose.Name] = pose end
        end
        local clearance = key:FindFirstChild("SourceGroundClearance")
        assert(clearance and clearance:IsA("NumberValue"), "Source grounding metadata missing")
        local frames = {HumanoidRootPart = CFrame.new()}
        local minimum = math.huge
        for _, name in names do
            local joint, pose = joints[name], assert(poses[name], name)
            -- Canonical R15 export uses identity joint rotation frames.
            local rotation = joint.c0.Rotation:Inverse() * pose.CFrame.Rotation * joint.c1.Rotation
            local position = if name == "LowerTorso"
                then joint.c0.Rotation:VectorToObjectSpace(pose.CFrame.Position) else Vector3.zero
            pose.CFrame = CFrame.new(position) * rotation
            frames[name] = frames[joint.parent] * joint.c0 * pose.CFrame * joint.c1:Inverse()
            minimum = math.min(minimum, boxFloor(frames[name], joint.size))
        end
        previous = Clearance.correct(poses, joints, frames, previous)
        unresolved += previous.unresolved
        maxCorrection = math.max(maxCorrection, math.abs(previous.yaw), math.abs(previous.tilt))
        -- Recompute arm clearance after changing its rotations.
        for _, name in {"RightUpperArm", "RightLowerArm", "RightHand"} do
            minimum = math.min(minimum, boxFloor(frames[name], joints[name].size))
        end
        local swordFrame = frames.RightHand * Visual.HandToHilt
            * CFrame.new(0, 1.195 * Visual.MeshScale.Y, 0)
        local swordSize = Vector3.new(1.51340294, 4.71, 0.37736732) * Visual.MeshScale
        local swordMinimum = boxFloor(swordFrame, swordSize)
        -- Small bounding-box clearance absorbs interpolation and physical
        -- AnimationConstraint settling between the sampled poses.
        -- The inverted root swings body corners between samples. Fade the
        -- extra margin smoothly so the first/last standing poses stay identical.
        local guard = .07
        if source.Name:sub(1, 4) == "Roll" and duration > 0 then
            guard += .17 * math.sin(math.pi * key.Time / duration)^2
        end
        local adjustment = math.max(ground + math.max(clearance.Value, guard) - minimum,
            ground + guard - swordMinimum)
        local rootPose = poses.LowerTorso
        local offset = joints.LowerTorso.c0.Rotation:VectorToObjectSpace(Vector3.new(0, adjustment, 0))
        rootPose.CFrame = CFrame.new((rootPose.CFrame.Position + offset) / translationScale) * rootPose.CFrame.Rotation
    end
    sequence:SetAttribute("UnresolvedBladeSamples", unresolved)
    sequence:SetAttribute("MaximumArmCorrectionDegrees", maxCorrection)
    return sequence
end

return Retarget
