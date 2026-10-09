-- Motor6D.Transform does not replicate: render shared playback state locally.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local rig = workspace:WaitForChild("blender666"):WaitForChild("AshenOathPreview")
local library = game:GetService("ReplicatedStorage"):WaitForChild("blender666"):WaitForChild("MannequinPreviewClips")
local animator = rig:WaitForChild("AnimationController"):WaitForChild("Animator")
-- Replicated models and clips can arrive before their children.
-- Wait for the complete skeleton and authored poses before caching them.
local expectedClips = library:GetAttribute("ExpectedClips")
while not expectedClips or #library:GetChildren() < expectedClips do
    task.wait()
    expectedClips = library:GetAttribute("ExpectedClips")
end
local motors, clips = {}, {}
repeat
    motors = {}
    for _, m in ipairs(rig:GetDescendants()) do
        if m:IsA("Motor6D") and m.Part0 and m.Part1 then motors[m.Name] = m end
    end
    local count = 0
    for _ in pairs(motors) do count += 1 end
    if count == 15 then break end
    task.wait()
until false
for _, m in ipairs(rig:GetDescendants()) do if m:IsA("Motor6D") then motors[m.Name] = m end end
for _, sequence in ipairs(library:GetChildren()) do
    if sequence:IsA("KeyframeSequence") then
        local expected = sequence:GetAttribute("ExpectedDescendants")
        while not expected or #sequence:GetDescendants() < expected do
            task.wait()
            expected = sequence:GetAttribute("ExpectedDescendants")
        end
        local frames = {}
        for _, key in ipairs(sequence:GetKeyframes()) do
            local poses = {}
            for _, p in ipairs(key:GetDescendants()) do
                if p:IsA("Pose") and motors[p.Name] then poses[p.Name] = p.CFrame end
            end
            if next(poses) then table.insert(frames, {time = key.Time, poses = poses}) end
        end
        table.sort(frames, function(a, b) return a.time < b.time end)
        if #frames > 0 then clips[sequence.Name] = {frames = frames, duration = frames[#frames].time, loop = sequence.Loop} end
    end
end
local state, previous, blendStart = nil, {}, 0
local function receive()
    local encoded = rig:GetAttribute("PreviewState")
    if typeof(encoded) ~= "string" then return end
    local ok, nextState = pcall(HttpService.JSONDecode, HttpService, encoded)
    if not ok or not clips[nextState.name] then return end
    if state and nextState.revision == state.revision then return end
    previous = {}
    for name, m in pairs(motors) do previous[name] = m.Transform end
    state, blendStart = nextState, workspace:GetServerTimeNow()
end
rig:GetAttributeChangedSignal("PreviewState"):Connect(receive)
receive()
RunService.PreSimulation:Connect(function()
    if not state or not rig.Parent then return end
    -- Native AnimationTracks and Animation Editor keep their existing priority.
    if #animator:GetPlayingAnimationTracks() > 0 then return end
    local clip, now = clips[state.name], workspace:GetServerTimeNow()
    local t = math.max(0, now - state.started)
    if clip.loop then t %= math.max(clip.duration, .001) else t = math.min(t, clip.duration) end
    local frames = clip.frames
    local a, b = frames[1], frames[#frames]
    for i = 1, #frames - 1 do
        if t >= frames[i].time and t <= frames[i + 1].time then a, b = frames[i], frames[i + 1]; break end
    end
    local alpha = b.time > a.time and math.clamp((t - a.time) / (b.time - a.time), 0, 1) or 0
    local blend = math.clamp((now - blendStart) / .12, 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    for name, m in pairs(motors) do
        local cf = (a.poses[name] or CFrame.identity):Lerp(b.poses[name] or CFrame.identity, alpha)
        m.Transform = (previous[name] or CFrame.identity):Lerp(cf, blend)
    end
end)
