-- Client Play-mode diagnostic: real Animator, normal speed, physical joints.
-- Temporarily anchors only the test player's root, then restores it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Provider = game:GetService("KeyframeSequenceProvider")
local root = game.ReplicatedStorage.CombatFoundation
local Retarget = require(root.Shared.R15PreviewRetarget)
local Registry = require(root.Shared.AnimationRegistry)
local character = Players.LocalPlayer.Character
local humanoid, hrp = character.Humanoid, character.HumanoidRootPart
local animator = humanoid.Animator
local hand = character.RightHand
local motor = hand:FindFirstChild("CombatTestSwordGrip")
assert(motor and motor.Part1, "Rigid sword missing")
local blade = motor.Part1
local palm = assert(hand:FindFirstChild("RightGripAttachment"), "Avatar palm attachment missing")
local hilt = assert(blade:FindFirstChild("RightGrip"), "Weapon hilt attachment missing")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {character}
params.RespectCanCollide = true
local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -12, 0), params)
assert(ray, "No test floor")
local floor = ray.Position.Y
local anchored = hrp.Anchored
local report, track, sequence = {}, nil, nil
local function minimum(part)
    local size, cf, low = part.Size / 2, part.CFrame, math.huge
    for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
        low = math.min(low, cf:PointToWorldSpace(size * Vector3.new(x, y, z)).Y)
    end end end
    return low - floor
end
local ok, failure = pcall(function()
    hrp.Anchored = true
    for _, name in {"CombatIdle", "SwordR1_1", "SwordR1_2", "SwordR2", "RollForward", "RollBackward", "RollLeft", "RollRight", "Block", "Parry", "Stagger", "GuardBroken"} do
        sequence = Retarget.forCharacter(root.Animations[name], character)
        local animation = Instance.new("Animation")
        animation.AnimationId = Provider:RegisterKeyframeSequence(sequence)
        track = animator:LoadAnimation(animation)
        animation:Destroy()
        track.Name, track.Priority, track.Looped = "QA_" .. name, Enum.AnimationPriority.Action4, false
        local markers = {}
        local connections = {}
        for _, key in sequence:GetKeyframes() do for _, marker in key:GetMarkers() do
            table.insert(connections, track:GetMarkerReachedSignal(marker.Name):Connect(function() markers[marker.Name] = (markers[marker.Name] or 0) + 1 end))
        end end
        local duration = 0
        for _, key in sequence:GetKeyframes() do duration = math.max(duration, key.Time) end
        track:Play(0, 1, 1)
        local data = {samples = 0, bodyFloor = math.huge, swordFloor = math.huge, gripError = 0,
            palmHiltError = 0, palmHiltAngleDegrees = 0, unresolved = 0, markers = markers}
        local deadline = os.clock() + duration + .1
        while os.clock() < deadline do
            RunService.Heartbeat:Wait()
            if track.IsPlaying then
                data.samples += 1
                for _, part in character:GetChildren() do
                    if part:IsA("BasePart") and part ~= hrp then data.bodyFloor = math.min(data.bodyFloor, minimum(part)) end
                end
                data.swordFloor = math.min(data.swordFloor, minimum(blade))
                data.gripError = math.max(data.gripError, ((hand.CFrame * motor.C0).Position - blade.Position).Magnitude)
                local delta = palm.WorldCFrame:ToObjectSpace(hilt.WorldCFrame)
                local _, angle = delta:ToAxisAngle()
                data.palmHiltError = math.max(data.palmHiltError, delta.Position.Magnitude)
                data.palmHiltAngleDegrees = math.max(data.palmHiltAngleDegrees, math.deg(angle))
                data.unresolved = math.max(data.unresolved, character:GetAttribute("VisualBladeUnresolved") or 0)
            end
        end
        for _, connection in connections do connection:Disconnect() end
        report[name] = data
        track:Stop(0); track:Destroy(); track = nil
        sequence:Destroy(); sequence = nil
        task.wait(.15)
    end
end)
if track then track:Stop(0); track:Destroy() end
if sequence then sequence:Destroy() end
hrp.Anchored = anchored
if not ok then error(failure) end
return game:GetService("HttpService"):JSONEncode(report)
