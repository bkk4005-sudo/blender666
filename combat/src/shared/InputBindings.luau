-- Client settings contain input names only; they grant no combat authority.
local Bindings = {}
Bindings.Order = {"CombatR1", "CombatR2", "CombatRoll", "CombatBlock", "CombatParry", "CombatSprint", "CombatLock"}
Bindings.Defaults = {CombatR1 = "MouseButton1", CombatR2 = "MouseButton2", CombatRoll = "Space", CombatBlock = "F", CombatParry = "E", CombatSprint = "LeftShift", CombatLock = "Q"}
Bindings.Labels = {CombatR1 = "Лёгкий удар", CombatR2 = "Тяжёлый удар", CombatRoll = "Перекат", CombatBlock = "Блок (удерживать)", CombatParry = "Парирование", CombatSprint = "Спринт (удерживать)", CombatLock = "Фиксация цели"}
local forbidden = {Unknown = true, Escape = true, Backspace = true, Return = true, Tab = true, Slash = true, BackSlash = true, Backquote = true, W = true, A = true, S = true, D = true}
function Bindings.resolve(name)
    if type(name) ~= "string" or #name > 32 or forbidden[name] then return nil end
    if name == "MouseButton1" or name == "MouseButton2" or name == "MouseButton3" then return Enum.UserInputType[name] end
    local ok, value = pcall(function() return Enum.KeyCode[name] end)
    return if ok then value else nil
end
function Bindings.validate(values)
    if type(values) ~= "table" then return nil end
    local result, used = {}, {}
    for _, action in Bindings.Order do
        local name = values[action]
        if not Bindings.resolve(name) or used[name] then return nil end
        result[action], used[name] = name, true
    end
    for key in values do if not Bindings.Defaults[key] then return nil end end
    return result
end
return Bindings
