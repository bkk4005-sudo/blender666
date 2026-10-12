-- Run in Roblox Studio Edit mode after starting a local HTTP server at 127.0.0.1:8766
-- rooted at the combat directory. Refuses to replace an existing installation.
local Http = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
assert(not ReplicatedStorage:FindFirstChild("CombatFoundation"), "CombatFoundation already installed")
assert(not ServerScriptService:FindFirstChild("CombatFoundation"), "Server installation already exists")
assert(not StarterPlayer.StarterPlayerScripts:FindFirstChild("CombatClient"), "Client installation already exists")

local oldHttpEnabled = Http.HttpEnabled
local host = "http://127.0.0.1:8766/"
local staged = {}

local function source(path)
    return Http:GetAsync(host .. path)
end

local function folder(name, parent)
    local value = Instance.new("Folder")
    value.Name = name
    value.Parent = parent
    return value
end

local function scriptOf(className, name, path, parent)
    local value = Instance.new(className)
    value.Name = name
    value.Source = source(path)
    value.Parent = parent
    return value
end

local rig = Http:JSONDecode(source("assets/blender/rig/R15_joint_schema.json"))
local joints = rig.joints

local function poseTree(name, transforms, parent)
    local value = Instance.new("Pose")
    value.Name = name
    value.CFrame = name == "HumanoidRootPart" and CFrame.identity or CFrame.new(unpack(transforms[name]))
    value.EasingStyle = Enum.PoseEasingStyle.Linear
    value.EasingDirection = Enum.PoseEasingDirection.InOut
    value.Parent = parent
    for _, joint in joints do
        if joint.parent == name then poseTree(joint.name, transforms, value) end
    end
end

local function animationOf(name, parent)
    local data = Http:JSONDecode(source("assets/animations/r15/baked/" .. name .. ".json"))
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
        poseTree("HumanoidRootPart", frame.poses, key)
        key.Parent = sequence
        if index % 10 == 0 then task.wait() end
    end
    for markerName, time in data.markers do
        local index = math.clamp(math.round(time * 30) + 1, 1, #data.frames)
        local key = sequence:FindFirstChild(string.format("Frame_%03d", index - 1))
        local marker = Instance.new("KeyframeMarker")
        marker.Name = markerName
        marker.Value = ""
        marker.Parent = key
    end
    sequence.Parent = parent
    return sequence
end

local ok, outcome = pcall(function()
    Http.HttpEnabled = true
    local root = folder("CombatFoundation", nil)
    local server = folder("CombatFoundation", nil)
    local client = Instance.new("LocalScript")
    client.Name = "CombatClient"
    table.insert(staged, root)
    table.insert(staged, server)
    table.insert(staged, client)
    local shared = folder("Shared", root)
    local animations = folder("Animations", root)
    for _, name in {"CombatConfig", "ActionTimeline", "AnimationRegistry"} do
        scriptOf("ModuleScript", name, "src/shared/" .. name .. ".luau", shared)
    end
    for _, name in {"CombatIdle", "SwordR1_1", "SwordR1_2", "SwordR2", "RollForward", "RollBackward", "RollLeft", "RollRight"} do
        animationOf(name, animations)
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = "CombatRemote"
    remote.Parent = root
    scriptOf("ModuleScript", "CombatService", "src/server/CombatService.luau", server)
    scriptOf("Script", "CombatBootstrap", "src/server/CombatBootstrap.server.luau", server)
    client.Source = source("src/client/CombatClient.client.luau")
    root.Parent = ReplicatedStorage
    server.Parent = ServerScriptService
    client.Parent = StarterPlayer.StarterPlayerScripts
    return {animations = #animations:GetChildren(), sharedModules = #shared:GetChildren(), serverScripts = #server:GetChildren()}
end)
Http.HttpEnabled = oldHttpEnabled
if not ok then
    for _, item in staged do item:Destroy() end
    error(outcome)
end
return Http:JSONEncode(outcome)
