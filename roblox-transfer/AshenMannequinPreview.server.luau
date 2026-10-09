-- Server owns prompts and playback state; each client renders the joint poses.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local rig = workspace:WaitForChild("blender666"):WaitForChild("AshenOathPreview")
local source = game:GetService("ServerStorage").blender666.Animations.AshenOath
local project = game:GetService("ReplicatedStorage"):WaitForChild("blender666")
local library = Instance.new("Folder")
library.Name = "MannequinPreviewClips"
local clips = {}
for index, sequence in ipairs(source:GetChildren()) do
    if sequence:IsA("KeyframeSequence") then
        local copy = sequence:Clone()
        copy:SetAttribute("ExpectedDescendants", #copy:GetDescendants())
        copy.Parent = library
        local duration = 0
        for _, key in ipairs(sequence:GetKeyframes()) do duration = math.max(duration, key.Time) end
        clips[sequence.Name] = {duration = duration, loop = sequence.Loop}
    end
    if index % 8 == 0 then task.wait() end
end
library:SetAttribute("ExpectedClips", #source:GetChildren())
library.Parent = project
local current, started, revision = "Idle", 0, 0
local function play(name)
    if not clips[name] then return end
    current, started, revision = name, workspace:GetServerTimeNow(), revision + 1
    rig:SetAttribute("PreviewAnimation", name)
    rig:SetAttribute("PreviewState", HttpService:JSONEncode({name = name, started = started, revision = revision}))
end
local function prompt(name, key, text, choices)
    local attachment = Instance.new("Attachment")
    attachment.Name = name .. "Attachment"
    attachment.Position = Vector3.new(0, 1, 0)
    attachment.Parent = rig.HumanoidRootPart
    local p = Instance.new("ProximityPrompt")
    p.Name, p.ActionText, p.ObjectText = name, text, "Ashen Oath — манекен"
    p.KeyboardKeyCode, p.HoldDuration = key, 0
    p.MaxActivationDistance, p.RequiresLineOfSight = 12, false
    p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
    p.UIOffset = Vector2.new(0, key == Enum.KeyCode.E and -35 or 35)
    p.ClickablePrompt = true
    p.Parent = attachment
    local index, lastTrigger = 0, 0
    p.Triggered:Connect(function(player)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then return end
        if (root.Position - attachment.WorldPosition).Magnitude > p.MaxActivationDistance + 2 then return end
        local now = workspace:GetServerTimeNow()
        if now - lastTrigger < .1 then return end
        lastTrigger, index = now, index % #choices + 1
        rig:SetAttribute("LastPreviewAction", choices[index])
        play(choices[index])
    end)
end
prompt("AttackPreview", Enum.KeyCode.E, "Показать следующий удар", {"Light_01", "Light_02", "Light_03", "Heavy_Release", "Running_Attack", "Thrust"})
prompt("DefensePreview", Enum.KeyCode.F, "Показать защиту / парирование", {"Guard_Enter", "Guard_Impact", "Parry", "Riposte", "Guard_Break"})
rig:GetAttributeChangedSignal("RequestedPreviewAnimation"):Connect(function()
    local name = rig:GetAttribute("RequestedPreviewAnimation")
    if typeof(name) == "string" then play(name) end
end)
play("Idle")
RunService.Heartbeat:Connect(function()
    local clip = clips[current]
    if not clip.loop and workspace:GetServerTimeNow() - started > clip.duration then play("Idle") end
end)
