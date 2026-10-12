local Config = require(script.Parent.CombatConfig)
local Timeline = {}

function Timeline.phase(actionName, elapsed)
    local action = Config.Actions[actionName]
    if not action or elapsed < 0 or elapsed >= action.duration then return "Ended" end
    if action.active then
        if elapsed < action.active[1] then return "AttackStartup" end
        if elapsed <= action.active[2] then return "AttackActive" end
        return "AttackRecovery"
    end
    if action.iframes then return "Rolling" end
    if action.parry then return "Parrying" end
    if actionName == "Stagger" then return "Staggered" end
    return actionName
end

function Timeline.inWindow(actionName, windowName, elapsed)
    local action = Config.Actions[actionName]
    local window = action and action[windowName]
    return window ~= nil and elapsed >= window[1] and elapsed <= window[2]
end

function Timeline.markers(actionName)
    local action = Config.Actions[actionName]
    if not action then return {} end
    local markers = {{"RecoveryEnd", action.duration}}
    if action.active then
        table.insert(markers, {"AttackStart", 0})
        table.insert(markers, {"HitStart", action.active[1]})
        table.insert(markers, {"HitEnd", action.active[2]})
    end
    if action.combo then
        table.insert(markers, {"ComboOpen", action.combo[1]})
        table.insert(markers, {"ComboClose", action.combo[2]})
    end
    if action.iframes then
        table.insert(markers, {"IFrameStart", action.iframes[1]})
        table.insert(markers, {"IFrameEnd", action.iframes[2]})
    end
    if action.parry then
        table.insert(markers, {"ParryActiveStart", action.parry[1]})
        table.insert(markers, {"ParryActiveEnd", action.parry[2]})
    end
    return markers
end

return Timeline
