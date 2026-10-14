-- Prototype balance values, authored for this project. They are not measured DS3 frames.
local Config = {}
local Pacing = require(script.Parent.CombatPacing)

Config.Version = 2
Config.PacingVersion = Pacing.Version
Config.MaxStamina = 100
Config.StaminaRegenPerSecond = 24
Config.StaminaRegenDelay = 0.75
Config.WalkSpeed = Pacing.Movement.WalkSpeed
Config.SprintSpeed = Pacing.Movement.SprintSpeed
Config.BlockWalkSpeed = Pacing.Movement.BlockWalkSpeed
Config.LockRange = 48
Config.TargetLossRange = 58
Config.MaxRequestRate = 16
Config.Actions = {
    SwordR1_1 = {
        cost = 18, damage = 22, reach = 7.5, width = 4.2, turnRate = 70,
    },
    SwordR1_2 = {
        cost = 20, damage = 24, reach = 7.5, width = 4.2, turnRate = 70,
    },
    SwordR2 = {
        cost = 34, damage = 43, reach = 8.0, width = 3.8, turnRate = 45,
    },
    RollForward = {cost = 27},
    RollBackward = {cost = 27},
    RollLeft = {cost = 27},
    RollRight = {cost = 27},
    Parry = {cost = 20},
    Stagger = {},
    GuardBroken = {},
}
for name, fields in Pacing.Actions do
    local action = assert(Config.Actions[name], "Unknown pacing action " .. name)
    for key, value in fields do action[key] = value end
end
Config.Block = {absorb = 0.75, staminaPerDamage = 1.1}
Config.SprintDrainPerSecond = 13
Config.HitSampleRate = 30

return table.freeze(Config)
