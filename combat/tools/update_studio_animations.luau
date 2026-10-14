-- Studio Edit command: refresh only this foundation's eight preview clips.
-- Start an HTTP server rooted at combat/ on 127.0.0.1:8766 first.
-- Existing sequences are moved into a dated backup folder.
local Http = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local root = assert(ReplicatedStorage:FindFirstChild("CombatFoundation"), "CombatFoundation missing")
local folder = assert(root:FindFirstChild("Animations"), "Animation folder missing")
local names = {"CombatIdle", "SwordR1_1", "SwordR1_2", "SwordR2",
    "RollForward", "RollBackward", "RollLeft", "RollRight", "Block", "Parry", "Stagger", "GuardBroken"}
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
    sequence.AuthoredHipHeight = data.authoredHipHeight
    local height = Instance.new("NumberValue")
    height.Name, height.Value, height.Parent = "SourceAuthoredHipHeight", data.authoredHipHeight, sequence
    sequence.Priority = Enum.AnimationPriority[data.priority]
    sequence:SetAttribute("SourceBlend", data.sourceBlend)
    sequence:SetAttribute("Status", data.status)
    for index, frame in data.frames do
        local key = Instance.new("Keyframe")
        key.Name = string.format("Frame_%03d", index - 1)
        key.Time = frame.time
        local clearance = Instance.new("NumberValue")
        clearance.Name = "SourceGroundClearance"
        clearance.Value = frame.groundClearance
        clearance.Parent = key
        poseTree("HumanoidRootPart", frame.poses, joints, key)
        key.Parent = sequence
        if index % 10 == 0 then task.wait() end
    end
    for markerName, time in data.markers do
        local index = math.clamp(math.round(time * data.sampleRate) + 1, 1, #data.frames)
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
    local visual = Instance.new("ModuleScript")
    visual.Name = "WeaponVisualConfig"
    visual.Source = Http:GetAsync(host .. "src/shared/WeaponVisualConfig.luau")
    local retarget = Instance.new("ModuleScript")
    retarget.Name = "R15PreviewRetarget"
    retarget.Source = Http:GetAsync(host .. "src/shared/R15PreviewRetarget.luau")
    local client = Instance.new("LocalScript")
    client.Name = "CombatClient"
    client.Source = Http:GetAsync(host .. "src/client/CombatClient.client.luau")
    local extras = {}
    for _, name in {"InputBindings", "BladeClearance", "AvatarGroundClearance", "AnimationRegistry", "CombatConfig", "ActionTimeline"} do
        local item = Instance.new("ModuleScript")
        item.Name, item.Source = name, Http:GetAsync(host .. "src/shared/" .. name .. ".luau")
        table.insert(extras, {item = item, parent = root.Shared})
    end
    local settings = Instance.new("LocalScript")
    settings.Name, settings.Source = "CombatSettings", Http:GetAsync(host .. "src/client/CombatSettings.client.luau")
    table.insert(extras, {item = settings, parent = game.StarterPlayer.StarterPlayerScripts})
    local serverFolder = assert(game.ServerScriptService:FindFirstChild("CombatFoundation"))
    for _, name in {"CombatService", "CombatSettings.server", "WeaponVisual.server"} do
        local item = Instance.new(name == "CombatService" and "ModuleScript" or "Script")
        item.Name = name:gsub("%.server$", "")
        item.Source = Http:GetAsync(host .. "src/server/" .. name .. ".luau")
        table.insert(extras, {item = item, parent = serverFolder})
    end
    local clearanceClient = Instance.new("LocalScript")
    clearanceClient.Name = "AvatarWeaponClearance"
    clearanceClient.Source = Http:GetAsync(host .. "src/client/AvatarWeaponClearance.client.luau")
    table.insert(extras, {item = clearanceClient, parent = game.StarterPlayer.StarterPlayerScripts})
    local backup = Instance.new("Folder")
    backup.Name = "AnimationBackup_" .. os.date("!%Y%m%d_%H%M%S")
    backup.Parent = root
    for _, entry in extras do
        local old = entry.parent:FindFirstChild(entry.item.Name)
        if old then old.Parent = backup end
        entry.item.Parent = entry.parent
    end
    for _, name in names do
        local previous = folder:FindFirstChild(name)
        if previous then previous.Parent = backup end
        staged[name].Parent = folder
    end
    local shared = assert(root:FindFirstChild("Shared"))
    local previousVisual = shared:FindFirstChild("WeaponVisualConfig")
    if previousVisual then previousVisual.Parent = backup end
    visual.Parent = shared
    local previousRetarget = shared:FindFirstChild("R15PreviewRetarget")
    if previousRetarget then previousRetarget.Parent = backup end
    retarget.Parent = shared
    local playerScripts = game:GetService("StarterPlayer").StarterPlayerScripts
    local previousClient = playerScripts:FindFirstChild("CombatClient")
    if previousClient then previousClient.Parent = backup end
    client.Parent = playerScripts
    return "Updated " .. tostring(#names) .. " sequences; backup: " .. backup:GetFullName()
end)
Http.HttpEnabled = oldHttpEnabled
if not ok then error(result) end
return result
