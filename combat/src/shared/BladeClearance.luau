-- Geometry-only arm correction for a baked avatar preview. The weapon remains
-- rigidly attached; lengths, joint offsets, cosmetics and gameplay reach stay fixed.
local Visual = require(script.Parent.WeaponVisualConfig)
local Solver = {}
local order = {"RightUpperArm", "RightLowerArm", "RightHand"}
local body = {"LowerTorso", "UpperTorso", "Head", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "LeftUpperArm", "LeftLowerArm", "LeftHand"}
local function intersects(a, b, cf, size)
    a, b = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
    local d, lo, hi = b - a, 0, 1
    for _, axis in {"X", "Y", "Z"} do
        local e = size[axis] / 2 + .12
        if math.abs(d[axis]) < 1e-8 then
            if math.abs(a[axis]) > e then return false end
        else
            local x, y = (-e - a[axis]) / d[axis], (e - a[axis]) / d[axis]
            if x > y then x, y = y, x end
            lo, hi = math.max(lo, x), math.min(hi, y)
            if lo > hi then return false end
        end
    end
    return true
end
function Solver.correct(poses, joints, frames, previous, fast)
    local shoulder = joints.RightUpperArm
    local original = poses.RightUpperArm.CFrame
    local originalHand = poses.RightHand.CFrame
    local function handPose(wrist)
        return CFrame.new(originalHand.Position) * CFrame.Angles(0, math.rad(wrist), 0) * originalHand.Rotation
    end
    local function evaluate(yaw, tilt, wrist)
        wrist = wrist or 0
        local rotation = CFrame.Angles(0, math.rad(yaw), math.rad(tilt))
        local cf = CFrame.new(original.Position) * rotation * original.Rotation
        local arm = {}
        for _, name in order do
            local j = joints[name]
            local parent = arm[j.parent] or frames[j.parent]
            local pose = name == "RightUpperArm" and cf or name == "RightHand" and handPose(wrist) or poses[name].CFrame
            arm[name] = parent * j.c0 * pose * j.c1:Inverse()
        end
        local sword = arm.RightHand * Visual.HandToHilt * CFrame.new(Visual.SourceGrip.Position * Visual.MeshScale):Inverse()
        local a = sword:PointToWorldSpace(Vector3.new(0, -.635 * Visual.MeshScale.Y, 0))
        local b = sword:PointToWorldSpace(Vector3.new(0, 2.355 * Visual.MeshScale.Y, 0))
        local collisions = 0
        for _, name in body do if intersects(a, b, frames[name], joints[name].size) then collisions += 1 end end
        local penalty = yaw * yaw + tilt * tilt + 2 * wrist * wrist
        if previous then penalty += 4 * ((yaw - previous.yaw)^2 + (tilt - previous.tilt)^2 + (wrist - (previous.wrist or 0))^2) end
        return collisions * 1e6 + penalty, cf, arm, collisions
    end
    local best, chosen, arm, collisions = evaluate(0, 0)
    local y, t, w = 0, 0, 0
    if collisions == 0 and (not previous or math.abs(previous.yaw) + math.abs(previous.tilt) + math.abs(previous.wrist or 0) < .1) then
        return {yaw = 0, tilt = 0, wrist = 0, unresolved = 0}
    end
    if fast and previous then
        -- Most frames can retain/relax the prior safe correction. Only an
        -- obstructed pose needs the full bounded search.
        for _, factor in {.8, 1} do
            local yaw, tilt = previous.yaw * factor, previous.tilt * factor
            local wrist = (previous.wrist or 0) * factor
            local _, cf, candidateArm, count = evaluate(yaw, tilt, wrist)
            if count == 0 then
                poses.RightUpperArm.CFrame = cf
                poses.RightHand.CFrame = handPose(wrist)
                for name, frame in candidateArm do frames[name] = frame end
                return {yaw = yaw, tilt = tilt, wrist = wrist, unresolved = 0}
            end
        end
    end
    local function consider(yaw, tilt, wrist)
        wrist = wrist or 0
        local score, cf, candidateArm, count = evaluate(yaw, tilt, wrist)
        if score < best then best, chosen, arm, collisions, y, t, w = score, cf, candidateArm, count, yaw, tilt, wrist end
    end
    if previous then consider(previous.yaw, previous.tilt, previous.wrist); consider(previous.yaw * .8, previous.tilt * .8, (previous.wrist or 0) * .8) end
    -- Search small changes first; costs prefer continuity and the authored pose.
    for _, tilt in {0, -10, 10, -20, 20, -30, 30, -45, 45, -60, 60} do
        for _, yaw in {0, -10, 10, -20, 20, -30, 30, -45, 45, -60, 60} do
            consider(yaw, tilt)
        end
    end
    if collisions > 0 then
        -- A bounded wrist deflection handles thick bodies where shoulder-only
        -- correction cannot clear the blade. The hilt stays fixed in the hand.
        for _, wrist in {-15, 15, -30, 30} do
            for _, tilt in {0, -20, 20, -40, 40, -60, 60} do
                for _, yaw in {0, -20, 20, -40, 40, -60, 60} do consider(yaw, tilt, wrist) end
            end
        end
    end
    for _, step in {5, 2.5, 1.25, .625} do
        local cy, ct = y, t
        for _, dy in {-step, 0, step} do
            for _, dt in {-step, 0, step} do
                consider(math.clamp(cy + dy, -60, 60), math.clamp(ct + dt, -60, 60), w)
            end
        end
    end
    poses.RightUpperArm.CFrame = chosen
    poses.RightHand.CFrame = handPose(w)
    for name, cf in arm do frames[name] = cf end
    return {yaw = y, tilt = t, wrist = w, unresolved = collisions}
end
return Solver
