-- Prototype balance values, authored for this project. They are not measured DS3 frames.
local Config = {}

Config.Version = 1
Config.MaxStamina = 100
Config.StaminaRegenPerSecond = 24
Config.StaminaRegenDelay = 0.75
Config.WalkSpeed = 11
Config.SprintSpeed = 17
Config.BlockWalkSpeed = 6
Config.LockRange = 48
Config.TargetLossRange = 58
Config.MaxRequestRate = 16
local function frame(n) return n / 30 end
Config.Actions = {
    SwordR1_1 = {
        duration = frame(28), cost = 18, damage = 22,
        active = {frame(9), frame(14)}, combo = {frame(16), frame(22)}, bufferOpen = frame(11), chainAt = frame(21),
        reach = 7.5, width = 4.2, advance = 2.0, advanceWindow = {frame(4), frame(12)}, turnRate = 90,
    },
    SwordR1_2 = {
        duration = frame(29), cost = 20, damage = 24,
        active = {frame(8), frame(14)}, combo = {frame(16), frame(23)},
        reach = 7.5, width = 4.2, advance = 1.8, advanceWindow = {frame(3), frame(11)}, turnRate = 90,
    },
    SwordR2 = {
        duration = frame(43), cost = 34, damage = 43,
        active = {frame(17), frame(25)}, reach = 8.0, width = 3.8,
        advance = 2.4, advanceWindow = {frame(14), frame(23)}, turnRate = 55,
    },
    RollForward = {duration = frame(25), cost = 27, iframes = {frame(5), frame(16)}, distance = 12},
    RollBackward = {duration = frame(25), cost = 27, iframes = {frame(5), frame(16)}, distance = 11},
    RollLeft = {duration = frame(25), cost = 27, iframes = {frame(5), frame(16)}, distance = 11},
    RollRight = {duration = frame(25), cost = 27, iframes = {frame(5), frame(16)}, distance = 11},
    Parry = {duration = 0.90, cost = 20, parry = {0.18, 0.34}},
    Stagger = {duration = 0.66},
    GuardBroken = {duration = 1.15},
}
Config.Block = {absorb = 0.75, staminaPerDamage = 1.1}
Config.SprintDrainPerSecond = 13
Config.HitSampleRate = 30

return table.freeze(Config)
