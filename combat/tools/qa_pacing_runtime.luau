-- Run in Studio Edit: assert the installed server timeline matches real clips.
local root = game.ReplicatedStorage.CombatFoundation
local Config = require(root.Shared.CombatConfig)
local Timeline = require(root.Shared.ActionTimeline)
local report = {version = Config.PacingVersion, actions = {}}
assert(report.version == "deliberate-1", "Stale installed combat config")
local function close(a, b) return math.abs(a - b) < 1e-5 end
for name, action in Config.Actions do
    local sequence = assert(root.Animations:FindFirstChild(name), name)
    local duration, markers = 0, {}
    for _, key in sequence:GetKeyframes() do
        duration = math.max(duration, key.Time)
        for _, marker in key:GetMarkers() do markers[marker.Name] = key.Time end
    end
    assert(close(duration, action.duration), "Duration mismatch " .. name)
    assert(close(markers.RecoveryEnd, action.duration), "Recovery mismatch " .. name)
    assert(Timeline.phase(name, action.duration + .001) == "Ended", name)
    for _, pair in {{"active", "HitStart", "HitEnd"}, {"combo", "ComboOpen", "ComboClose"},
        {"iframes", "IFrameStart", "IFrameEnd"}, {"parry", "ParryActiveStart", "ParryActiveEnd"}} do
        local window = action[pair[1]]
        if not window then continue end
        assert(close(markers[pair[2]], window[1]) and close(markers[pair[3]], window[2]), name .. " " .. pair[1])
        assert(not Timeline.inWindow(name, pair[1], window[1] - .001), name)
        assert(Timeline.inWindow(name, pair[1], (window[1] + window[2]) / 2), name)
        assert(not Timeline.inWindow(name, pair[1], window[2] + .001), name)
    end
    if action.active then
        assert(Timeline.phase(name, action.active[1] - .001) == "AttackStartup", name)
        assert(Timeline.phase(name, (action.active[1] + action.active[2]) / 2) == "AttackActive", name)
        assert(Timeline.phase(name, action.active[2] + .001) == "AttackRecovery", name)
    end
    local item = {duration = duration, markers = markers}
    if action.motionWindow then
        local span = action.motionWindow[2] - action.motionWindow[1]
        item.peakCommandSpeed = action.distance / span / .8
        local distance, dt = 0, 1 / 240
        for elapsed = 0, action.duration, dt do
            if elapsed < action.motionWindow[1] or elapsed > action.motionWindow[2] then continue end
            local u = (elapsed - action.motionWindow[1]) / span
            distance += item.peakCommandSpeed * math.max(0, math.min(u / .15, 1, (1 - u) / .25)) * dt
        end
        assert(math.abs(distance - action.distance) < .01, name .. " motion distance")
        assert(action.motionWindow[2] < action.duration and action.iframes[2] < action.motionWindow[2], name)
        item.integratedCommandDistance = distance
        item.stationaryRecovery = action.duration - action.motionWindow[2]
    end
    report.actions[name] = item
end
return game.HttpService:JSONEncode(report)
