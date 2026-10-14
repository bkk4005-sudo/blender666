-- Asset IDs are intentionally empty until the owner publishes and verifies them.
-- Local Studio previews resolve KeyframeSequences through RegisterKeyframeSequence.
local Registry = {}

Registry.Profiles = {
    R15 = {
        CombatIdle = {assetId = nil, source = "combat/assets/animations/r15/combat_idle/CombatIdle.rbxmx", loop = true, priority = Enum.AnimationPriority.Idle},
        SwordR1_1 = {assetId = nil, source = "combat/assets/animations/r15/straight_sword/SwordR1_1.rbxmx", priority = Enum.AnimationPriority.Action},
        SwordR1_2 = {assetId = nil, source = "combat/assets/animations/r15/straight_sword/SwordR1_2.rbxmx", priority = Enum.AnimationPriority.Action},
        SwordR2 = {assetId = nil, source = "combat/assets/animations/r15/straight_sword/SwordR2.rbxmx", priority = Enum.AnimationPriority.Action},
        RollForward = {assetId = nil, source = "combat/assets/animations/r15/dodge/RollForward.rbxmx", status = "ITERATED_REQUIRES_AVATAR_QA", priority = Enum.AnimationPriority.Action4},
        RollBackward = {assetId = nil, source = "combat/assets/animations/r15/dodge/RollBackward.rbxmx", status = "ITERATED_REQUIRES_AVATAR_QA", priority = Enum.AnimationPriority.Action4},
        RollLeft = {assetId = nil, source = "combat/assets/animations/r15/dodge/RollLeft.rbxmx", status = "ITERATED_REQUIRES_AVATAR_QA", priority = Enum.AnimationPriority.Action4},
        RollRight = {assetId = nil, source = "combat/assets/animations/r15/dodge/RollRight.rbxmx", status = "ITERATED_REQUIRES_AVATAR_QA", priority = Enum.AnimationPriority.Action4},
        Block = {assetId = nil, source = "combat/assets/animations/r15/defensive/Block.rbxmx", loop = true, priority = Enum.AnimationPriority.Action},
        Parry = {assetId = nil, source = "combat/assets/animations/r15/defensive/Parry.rbxmx", priority = Enum.AnimationPriority.Action},
        Stagger = {assetId = nil, source = "combat/assets/animations/r15/reactions/Stagger.rbxmx", priority = Enum.AnimationPriority.Action},
        GuardBroken = {assetId = nil, source = "combat/assets/animations/r15/reactions/GuardBroken.rbxmx", priority = Enum.AnimationPriority.Action},
    },
}

function Registry.get(profileName, semanticName)
    local profile = Registry.Profiles[profileName]
    return profile and profile[semanticName]
end

function Registry.registerProfile(profileName, entries)
    assert(type(profileName) == "string" and profileName ~= "", "Profile name required")
    assert(type(entries) == "table", "Profile entries required")
    assert(not Registry.Profiles[profileName], "Profile already registered")
    Registry.Profiles[profileName] = entries
end

return Registry
