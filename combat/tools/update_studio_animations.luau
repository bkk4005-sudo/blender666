-- Studio Edit command: refresh only this foundation's eight preview clips.
-- Start an HTTP server rooted at combat/ on 127.0.0.1:8766 first.
-- Existing sequences are moved into a dated backup folder.
local Http = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local root = assert(ReplicatedStorage:FindFirstChild("CombatFoundation"), "CombatFoundation missing")
local folder = assert(root:FindFirstChild("Animations"), "Animation folder missing")
local names = {"CombatIdle", "SwordR1_1", "SwordR1_2", "SwordR2",
    "RollForward", "RollBackward", "RollLeft", "RollRight"}
local host = "http://127.0.0.1:8766/"
local oldHttpEnabled = Http.HttpEnabled

local function get(path)
    return Http:JSONDecode(Http:GetAsync(host .. path))
end

local function poseTree(name, transforms, joints, parent)
    local pose = Instance.new("Pose")
    pose.Name = name
    pose.CFrame = name == "HumanoidRootPart" and CFrame.new() or CFrame.new(unpack(transforms[name]))
    pose.EasingStyle = Enum.PoseEasingStyle.Linear
    pose.EasingDirection = Enum.PoseEasingDirection.InOut
    pose.Parent = parent
    for _, joint in joints do
        if joint.parent == name then poseTree(joint.name, transforms, joints, pose) end
    end
end

local function build(name, joints)
    local data = get("assets/animations/r15/baked/" .. name .. ".json")
    local sequence = Instance.new("KeyframeSequence")
    sequence.Name = name
    sequence.Loop = data.loop
    sequence.Priority = data.priority == "Idle" and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Action
    sequence:SetAttribute("SourceBlend", data.sourceBlend)
    sequence:SetAttribute("Status", data.status)
    for index, frame in data.frames do
        local key = Instance.new("Keyframe")
        key.Name = string.format("Frame_%03d", index - 1)
        key.Time = frame.time
        poseTree("HumanoidRootPart", frame.poses, joints, key)
        key.Parent = sequence
        if index % 10 == 0 then task.wait() end
    end
    for markerName, time in data.markers do
        local index = math.clamp(math.round(time * 30) + 1, 1, #data.frames)
        local key = assert(sequence:FindFirstChild(string.format("Frame_%03d", index - 1)))
        local marker = Instance.new("KeyframeMarker")
        marker.Name = markerName
        marker.Parent = key
    end
    return sequence
end

local ok, result = pcall(function()
    Http.HttpEnabled = true
    local joints = get("assets/blender/rig/R15_joint_schema.json").joints
    local staged = {}
    for _, name in names do staged[name] = build(name, joints) end
    local backup = Instance.new("Folder")
    backup.Name = "AnimationBackup_" .. os.date("!%Y%m%d_%H%M%S")
    backup.Parent = root
    for _, name in names do
        local previous = folder:FindFirstChild(name)
        if previous then previous.Parent = backup end
        staged[name].Parent = folder
    end
    return "Updated " .. tostring(#names) .. " sequences; backup: " .. backup:GetFullName()
end)
Http.HttpEnabled = oldHttpEnabled
if not ok then error(result) end
return result
