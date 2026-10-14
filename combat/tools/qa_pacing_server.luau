-- Server Play: isolated real CombatService methods, generated standard R15 rigs.
-- No real player's profile or health is modified. All test instances are removed.
local Players = game:GetService("Players")
local root = game.ReplicatedStorage.CombatFoundation
local Config = require(root.Shared.CombatConfig)
local Service = require(game.ServerScriptService.CombatFoundation.CombatService)
local BladeTrajectory = require(game.ServerScriptService.CombatFoundation.BladeTrajectory)
local Timeline = require(root.Shared.ActionTimeline)
local area = Instance.new("Folder")
area.Name, area.Parent = "CombatPacingQA", workspace
local function actor(name, position)
    local description = Instance.new("HumanoidDescription")
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
    end)
    description:Destroy()
    if not ok then error(model) end
    model.Name, model.Parent = name, area
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            item.Anchored, item.CanCollide, item.CanTouch = true, false, false
            item.CanQuery = item.Name ~= "HumanoidRootPart"
        elseif item:IsA("ForceField") then
            item:Destroy()
        end
    end
    local h = assert(model:FindFirstChildOfClass("Humanoid"))
    h.BreakJointsOnDeath = false
    h.MaxHealth, h.Health = 100, 100
    model:PivotTo(CFrame.new(position))
    return model, h
end
local attacker, hum, target, targetHum
local player = {}
local rejected, starts = 0, {}
local remote = {
    FireAllClients = function(_, _, _, action) table.insert(starts, action) end,
    FireClient = function(_, _, kind) if kind == "Rejected" then rejected += 1 end end,
}
local profile = {player = player, alive = true, stamina = 100,
    lastSpend = 0, lastSequence = 0, rateWindow = 0, rateCount = 0, hit = {},
    comboQueued = false, blocking = false, sprinting = false}
local service = setmetatable({remote = remote, profiles = {[player] = profile}}, Service)
local report = {checks = {}, started = starts, hitPlacement = {}}
local function placeOnBlade(actionName, contactTime, partName, placementKey)
    local action = Config.Actions[actionName]
    local source = assert(root.Animations:FindFirstChild(actionName), "Missing source " .. actionName)
    profile.bladeCache = profile.bladeCache or {}
    local path = profile.bladeCache[actionName] or BladeTrajectory.build(attacker, source)
    profile.bladeCache[actionName] = path
    local time = contactTime or (action.active[1] + action.active[2]) / 2
    local base, tip = BladeTrajectory.sample(path, time)
    local part = assert(target:FindFirstChild(partName or "UpperTorso"), "Target needs R15 hurtbox")
    local attackerRoot = assert(attacker:FindFirstChild("HumanoidRootPart"))
    local frame = CFrame.lookAt(attackerRoot.Position, attackerRoot.Position + attackerRoot.CFrame.LookVector)
    local contact = frame:PointToWorldSpace(base:Lerp(tip, .70))
    target:PivotTo(CFrame.new(contact - part.Position) * target:GetPivot())
    report.hitPlacement[placementKey or actionName] = {time = time, bladeFraction = .70, part = part.Name,
        targetRootDistance = (target.HumanoidRootPart.Position - attackerRoot.Position).Magnitude}
    return time
end
local function advance(elapsed)
    profile.started = workspace:GetServerTimeNow() - elapsed
    service:update(1 / Config.HitSampleRate)
end
local ok, failure = pcall(function()
    attacker, hum = actor("Attacker", Vector3.new(0, 5000, 0))
    target, targetHum = actor("Target", Vector3.new(0, 5000, -12))
    profile.character = attacker
    local r1Contact = placeOnBlade("SwordR1_1")
    service:request(player, {kind = "R1", sequence = 1})
    assert(profile.action == "SwordR1_1" and profile.stamina == 82)
    advance(.31)
    assert(attacker:GetAttribute("CombatState") == "AttackStartup" and targetHum.Health == 100)
    advance(r1Contact)
    assert(attacker:GetAttribute("CombatState") == "AttackActive" and targetHum.Health == 78)
    advance((r1Contact + Config.Actions.SwordR1_1.active[2]) / 2)
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
    local r2Contact = placeOnBlade("SwordR2")
    service:start(profile, "SwordR2", workspace:GetServerTimeNow())
    advance(.65)
    assert(attacker:GetAttribute("CombatState") == "AttackStartup" and targetHum.Health == 100)
    advance(r2Contact)
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

    -- A queued combo may cross chainAt in a single server step. Its first
    -- attack must still test the real remaining active path before switching.
    local first = Config.Actions.SwordR1_1
    local tailTime = first.active[2] - .01
    local targetHand = assert(target:FindFirstChild("RightHand"))
    -- Isolate one real R15 hurtbox so nearby torso/leg boxes do not substitute
    -- for the authored tail contact. Do not resize/add fake hitbox geometry.
    for _, item in target:GetDescendants() do
        if item:IsA("BasePart") then item.CanQuery = item == targetHand end
    end
    local function queueFirstBeforeJump()
        service:finish(profile)
        profile.stamina, profile.rateWindow, profile.rateCount = 100, 0, 0
        targetHum.Health = 100
        placeOnBlade("SwordR1_1", tailTime, "RightHand", "QueuedR1Tail")
        service:request(player, {kind = "R1", sequence = profile.lastSequence + 1})
        assert(profile.action == "SwordR1_1" and profile.stamina == 82)
        advance(first.active[1] - .01)
        assert(targetHum.Health == 100, "Tail fixture was damaged during startup")
        profile.started = workspace:GetServerTimeNow() - first.bufferOpen - .005
        service:request(player, {kind = "R1", sequence = profile.lastSequence + 1})
        assert(profile.comboQueued and profile.action == "SwordR1_1", "Legitimate combo buffer was not queued")
        assert(targetHum.Health == 100, "Input request itself dealt damage")
    end
    queueFirstBeforeJump()
    advance(first.chainAt + .01)
    assert(targetHum.Health == 100 - first.damage, "Queued combo skipped untested first-attack tail")
    assert(profile.action == "SwordR1_2" and profile.stamina == 62, "Tail contact prevented a valid combo chain")
    report.checks.queuedComboJumpProcessesFirstAttackTail = true

    -- Reuse the genuine tail contact, now against an active front parry.
    -- Only the isolated instance's existing character-lookup seam is changed.
    -- Production damage/sweep/start/finish/update remain unmodified.
    local targetRoot, attackerRoot = target.HumanoidRootPart, attacker.HumanoidRootPart
    for _ = 1, 4 do
        local delta = attackerRoot.Position - targetRoot.Position
        local flat = Vector3.new(delta.X, 0, delta.Z)
        assert(flat.Magnitude > .1, "Parry fixture overlaps attacker root")
        local pivot = target:GetPivot()
        target:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + flat.Unit))
        placeOnBlade("SwordR1_1", tailTime, "RightHand", "QueuedR1ParryTail")
    end
    local direction = attackerRoot.Position - targetRoot.Position
    assert(targetRoot.CFrame.LookVector:Dot(direction.Unit) > .25, "Parry fixture must face attacker")
    local defender = {player = {}, character = target, alive = true, stamina = 100,
        lastSpend = 0, started = 0, hit = {}, comboQueued = false, blocking = false, sprinting = false}
    local baseLookup = service.profileForCharacter
    service.profileForCharacter = function(self, character)
        if character == target then return defender end
        return baseLookup(self, character)
    end
    queueFirstBeforeJump()
    local eventStart = #starts
    assert(service:start(defender, "Parry", workspace:GetServerTimeNow()))
    defender.started = workspace:GetServerTimeNow() - (Config.Actions.Parry.parry[1] + Config.Actions.Parry.parry[2]) / 2
    advance(first.chainAt + .01)
    assert(targetHum.Health == 100, "Active parry took tail damage")
    assert(profile.action == "Stagger" and attacker:GetAttribute("CombatState") == "Staggered", "Combo overwrote the parry's stagger")
    assert(profile.stamina == 82 and not profile.comboQueued, "Parried combo spent/retained its second attack")
    assert(profile.motionVelocity == nil and profile.motionAttachment == nil, "Parried combo leaked attack advance")
    for index = eventStart + 1, #starts do
        assert(starts[index] ~= "SwordR1_2", "Second R1 started after parry")
    end
    service:finish(defender)
    service.profileForCharacter = nil
    report.checks.queuedComboJumpParryStopsChainAndKeepsStagger = true
    report.rejectedBusyRequests = rejected
end)
service:finish(profile)
area:Destroy()
if not ok then error(failure) end
return game.HttpService:JSONEncode(report)
