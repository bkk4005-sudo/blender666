-- Server Play: isolated real CombatService methods, synthetic test characters.
-- No real player's profile or health is modified. All test instances are removed.
local root = game.ReplicatedStorage.CombatFoundation
local Config = require(root.Shared.CombatConfig)
local Service = require(game.ServerScriptService.CombatFoundation.CombatService)
local Timeline = require(root.Shared.ActionTimeline)
local area = Instance.new("Folder")
area.Name, area.Parent = "CombatPacingQA", workspace
local function actor(name, position)
    local model = Instance.new("Model")
    model.Name, model.Parent = name, area
    local part = Instance.new("Part")
    part.Name, part.Anchored, part.CanCollide = "HumanoidRootPart", true, false
    part.Size, part.CFrame, part.Parent = Vector3.new(2, 2, 1), CFrame.new(position), model
    local h = Instance.new("Humanoid")
    h.MaxHealth, h.Health, h.Parent = 100, 100, model
    return model, h
end
local attacker, hum = actor("Attacker", Vector3.new(0, 5000, 0))
local target, targetHum = actor("Target", Vector3.new(0, 5000, -4))
local player = {}
local rejected, starts = 0, {}
local remote = {
    FireAllClients = function(_, _, _, action) table.insert(starts, action) end,
    FireClient = function(_, _, kind) if kind == "Rejected" then rejected += 1 end end,
}
local profile = {player = player, character = attacker, alive = true, stamina = 100,
    lastSpend = 0, lastSequence = 0, rateWindow = 0, rateCount = 0, hit = {},
    comboQueued = false, blocking = false, sprinting = false}
local service = setmetatable({remote = remote, profiles = {[player] = profile}}, Service)
local report = {checks = {}, started = starts}
local function advance(elapsed)
    profile.started = workspace:GetServerTimeNow() - elapsed
    service:update(1 / Config.HitSampleRate)
end
local ok, failure = pcall(function()
    service:request(player, {kind = "R1", sequence = 1})
    assert(profile.action == "SwordR1_1" and profile.stamina == 82)
    advance(.31)
    assert(attacker:GetAttribute("CombatState") == "AttackStartup" and targetHum.Health == 100)
    advance(.6)
    assert(attacker:GetAttribute("CombatState") == "AttackActive" and targetHum.Health == 78)
    advance(.68)
    assert(targetHum.Health == 78, "Duplicate R1 damage")
    advance(.85)
    assert(attacker:GetAttribute("CombatState") == "AttackRecovery")
    service:request(player, {kind = "R2", sequence = 2})
    assert(rejected == 1 and profile.action == "SwordR1_1", "Recovery cancelled")
    service:request(player, {kind = "R1", sequence = 3})
    assert(profile.comboQueued and profile.action == "SwordR1_1")
    advance(Config.Actions.SwordR1_1.chainAt + .001)
    assert(profile.action == "SwordR1_2" and profile.stamina == 62)
    advance(Config.Actions.SwordR1_2.duration + .01)
    assert(profile.action == nil and profile.motionVelocity == nil)
    report.checks.r1StartupDamageComboRecovery = true

    targetHum.Health = 100
    service:start(profile, "SwordR2", workspace:GetServerTimeNow())
    advance(.65)
    assert(attacker:GetAttribute("CombatState") == "AttackStartup" and targetHum.Health == 100)
    advance(1.1)
    assert(targetHum.Health == 57 and attacker:GetAttribute("CombatState") == "AttackActive")
    advance(1.7)
    assert(profile.action == "SwordR2" and attacker:GetAttribute("CombatState") == "AttackRecovery")
    advance(Config.Actions.SwordR2.duration + .01)
    assert(profile.action == nil)
    report.checks.r2LongStartupAndRecovery = true

    for _, name in {"RollForward", "RollBackward", "RollLeft", "RollRight"} do
        profile.stamina = 100
        service:start(profile, name, workspace:GetServerTimeNow())
        advance(.85)
        assert(profile.action == name and attacker:GetAttribute("CombatState") == "Rolling")
        assert(not Timeline.inWindow(name, "iframes", .85), "Overlong invulnerability")
        advance(1.05)
        assert(profile.action == name and profile.motionVelocity.PlaneVelocity.Magnitude == 0)
        service:request(player, {kind = "R1", sequence = profile.lastSequence + 1})
        assert(profile.action == name, "Roll interrupted by attack")
        advance(Config.Actions[name].duration + .01)
        assert(profile.action == nil and profile.motionVelocity == nil and profile.motionAttachment == nil)
    end
    report.checks.allRollRecoveryAndCleanup = true
    report.rejectedBusyRequests = rejected
end)
service:finish(profile)
area:Destroy()
if not ok then error(failure) end
return game.HttpService:JSONEncode(report)
