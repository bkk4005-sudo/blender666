-- Run in Studio Edit. Deterministic FK checks, not rendered mesh or clothing QA.
local Players = game:GetService("Players")
local root = game.ReplicatedStorage.CombatFoundation
local Retarget = require(root.Shared.R15PreviewRetarget)
local Visual = require(root.Shared.WeaponVisualConfig)
local order = {"LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
local checked = {"LowerTorso", "UpperTorso", "Head", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "LeftUpperArm", "LeftLowerArm", "LeftHand"}
local function intersects(a, b, cf, size)
    a, b = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
    local delta, lo, hi = b - a, 0, 1
    for _, axis in {"X", "Y", "Z"} do
        local extent = size[axis] / 2 + .025
        if math.abs(delta[axis]) < 1e-8 then
            if math.abs(a[axis]) > extent then return false end
        else
            local x, y = (-extent - a[axis]) / delta[axis], (extent - a[axis]) / delta[axis]
            if x > y then x, y = y, x end
            lo, hi = math.max(lo, x), math.min(hi, y)
            if lo > hi then return false end
        end
    end
    return true
end
local cases = {
    {name = "Default", height = 1, width = 1, depth = 1, head = 1},
    {name = "TallNarrow", height = 1.05, width = .7, depth = .7, head = .95},
    {name = "ShortWide", height = .9, width = 1, depth = 1, head = 1},
    {name = "ProjectAvatar", height = 1, width = 1, depth = 1, head = 1, project = true},
    {name = "ProjectTallNarrow", height = 1.05, width = .7, depth = .7, head = .95, project = true},
}
local report = {}
for _, case in cases do
    local description = Instance.new("HumanoidDescription")
    description.HeightScale, description.WidthScale, description.DepthScale, description.HeadScale = case.height, case.width, case.depth, case.head
    if case.project then
        -- Body IDs read from the current player's applied description in Studio.
        description.Head, description.Torso = 10725826963, 86500008
        description.RightArm, description.LeftArm = 86500036, 86500054
        description.RightLeg, description.LeftLeg = 86500078, 86500064
    end
    local rig = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
    description:Destroy()
    local joints = {}
    for _, joint in rig:GetDescendants() do
        local p0, p1, c0, c1
        if joint:IsA("Motor6D") then p0, p1, c0, c1 = joint.Part0, joint.Part1, joint.C0, joint.C1
        elseif joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
            p0, p1, c0, c1 = joint.Attachment0.Parent, joint.Attachment1.Parent, joint.Attachment0.CFrame, joint.Attachment1.CFrame
        end
        if p0 and p1 then joints[p1.Name] = {parent = p0.Name, c0 = c0, c1 = c1, size = p1.Size} end
    end
    local results = {}
    for _, original in root.Animations:GetChildren() do
        if not original:IsA("KeyframeSequence") or not require(root.Shared.AnimationRegistry).get("R15", original.Name) then continue end
        local sequence = Retarget.forCharacter(original, rig)
        local collisions, first, total = 0, nil, 0
        local keys = sequence:GetKeyframes()
        table.sort(keys, function(a, b) return a.Time < b.Time end)
        local samples = {}
        for _, key in keys do
            local poses = {}
            for _, item in key:GetDescendants() do if item:IsA("Pose") then poses[item.Name] = item.CFrame end end
            table.insert(samples, {time = key.Time, poses = poses})
        end
        local function evaluate(poses, time)
            local fk = {HumanoidRootPart = CFrame.new()}
            for _, name in order do
                local j = joints[name]
                fk[name] = fk[j.parent] * j.c0 * poses[name] * j.c1:Inverse()
            end
            local sword = fk.RightHand * Visual.HandToHilt * CFrame.new(Visual.SourceGrip.Position * Visual.MeshScale):Inverse()
            local base, tip = sword:PointToWorldSpace(Vector3.new(0, -.635 * Visual.MeshScale.Y, 0)), sword:PointToWorldSpace(Vector3.new(0, 2.355 * Visual.MeshScale.Y, 0))
            for _, name in checked do
                if intersects(base, tip, fk[name], joints[name].size) then
                    collisions += 1
                    first = first or {time = time, part = name}
                end
            end
            total += 1
        end
        for index, sample in samples do
            evaluate(sample.poses, sample.time)
            local nextSample = samples[index + 1]
            if nextSample then
                for _, alpha in {.25, .5, .75} do
                    local interpolated = {}
                    for name, cf in sample.poses do interpolated[name] = cf:Lerp(nextSample.poses[name], alpha) end
                    evaluate(interpolated, sample.time + (nextSample.time - sample.time) * alpha)
                end
            end
        end
        results[original.Name] = {samples = total, bladeBodyIntersections = collisions, first = first,
            maximumCorrection = sequence:GetAttribute("MaximumArmCorrectionDegrees")}
        sequence:Destroy()
        task.wait()
    end
    report[case.name] = results
    rig:Destroy()
end
return game:GetService("HttpService"):JSONEncode(report)
