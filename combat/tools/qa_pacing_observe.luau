-- Client Play: observe normal game input for 18s; do not substitute test tracks.
local player = game.Players.LocalPlayer
local root = game.ReplicatedStorage.CombatFoundation
local Config = require(root.Shared.CombatConfig)
local result = player.PlayerGui:FindFirstChild("CombatPacingObservation")
if result then result:Destroy() end
result = Instance.new("StringValue")
result.Name, result.Parent = "CombatPacingObservation", player.PlayerGui
task.spawn(function()
    local report = {version = Config.PacingVersion, actions = {}, inputs = {}, missingRollFrames = 0, competingRollFrames = 0}
    local current, finishAt = nil, os.clock() + 18
    local function finish(reason)
        if not current then return end
        local c = player.Character
        current.observedDuration = game.Workspace:GetServerTimeNow() - current.started
        current.endedBy = reason
        current.displacement = (c.HumanoidRootPart.Position - current.origin).Magnitude
        current.origin = nil
        current.started = nil
        table.insert(report.actions, current)
        current = nil
    end
    local connection = root.CombatRemote.OnClientEvent:Connect(function(kind, owner, name, started)
        if kind ~= "Started" or owner ~= player then return end
        finish("Started:" .. name)
        current = {name = name, started = started, origin = player.Character.HumanoidRootPart.Position,
            frames = 0, peakHorizontalVelocity = 0, maximumTrackTime = 0, expectedDuration = Config.Actions[name].duration}
    end)
    local controller = player.PlayerScripts.CombatClient
    local inputConnection = controller:GetAttributeChangedSignal("LastBoundInput"):Connect(function()
        table.insert(report.inputs, {input = controller:GetAttribute("LastBoundInput"),
            action = current and current.name,
            elapsed = current and (workspace:GetServerTimeNow() - current.started) or nil})
    end)
    while os.clock() < finishAt do
        game.RunService.Heartbeat:Wait()
        if not current then continue end
        local c = player.Character
        local state = c:GetAttribute("CombatState")
        if state == "Idle" or state == "Moving" then finish(state); continue end
        current.frames += 1
        local velocity = c.HumanoidRootPart.AssemblyLinearVelocity
        current.peakHorizontalVelocity = math.max(current.peakHorizontalVelocity, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
        local found = false
        for _, track in c.Humanoid.Animator:GetPlayingAnimationTracks() do
            if track.Name == current.name then
                found = true
                current.speed, current.length = track.Speed, track.Length
                current.maximumTrackTime = math.max(current.maximumTrackTime, track.TimePosition)
            elseif current.name:sub(1, 4) == "Roll" and track.WeightCurrent > .01
                and track.Priority ~= Enum.AnimationPriority.Core
                and track.Priority.Value >= Enum.AnimationPriority.Action.Value then
                report.competingRollFrames += 1
            end
        end
        if current.name:sub(1, 4) == "Roll" and not found then report.missingRollFrames += 1 end
    end
    connection:Disconnect()
    inputConnection:Disconnect()
    if current then finish("ObservationEnded") end
    result.Value = game.HttpService:JSONEncode(report)
end)
return "18-second native input observation started"
