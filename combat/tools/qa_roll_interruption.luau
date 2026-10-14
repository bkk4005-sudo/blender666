-- Client Play: start this monitor, then send Space + repeated attacks, parry,
-- extra rolls and direction keys through the normal input tools within 10s.
local p = game.Players.LocalPlayer
local deadline = os.clock() + 8
while p.PlayerScripts.CombatClient:GetAttribute("PreviewAnimationCount") ~= 12 do
    if os.clock() > deadline then error("Combat tracks not ready") end
    task.wait(.1)
end
local old = p.PlayerGui:FindFirstChild("RollInterruptionQA")
if old then old:Destroy() end
local result = Instance.new("StringValue")
result.Name, result.Parent = "RollInterruptionQA", p.PlayerGui
task.spawn(function()
    local report = {rolls = {}, missingRollFrames = 0, competingActionFrames = 0, samples = 0}
    local ending = os.clock() + 10
    while os.clock() < ending do
        game:GetService("RunService").Heartbeat:Wait()
        report.samples += 1
        local c = p.Character
        if not c or c:GetAttribute("CombatState") ~= "Rolling" then continue end
        local found = false
        for _, track in c.Humanoid.Animator:GetPlayingAnimationTracks() do
            if track.Name:sub(1, 4) == "Roll" then
                found = true
                local item = report.rolls[track.Name] or {frames = 0, maximumTime = 0, priority = track.Priority.Name}
                item.frames += 1
                item.maximumTime = math.max(item.maximumTime, track.TimePosition)
                report.rolls[track.Name] = item
            elseif track.WeightCurrent > .01 and track.Priority ~= Enum.AnimationPriority.Core
                and track.Priority.Value >= Enum.AnimationPriority.Action.Value then
                report.competingActionFrames += 1
            end
        end
        if not found then report.missingRollFrames += 1 end
    end
    result.Value = game:GetService("HttpService"):JSONEncode(report)
end)
return "10-second interruption monitor started"
