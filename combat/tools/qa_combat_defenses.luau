-- Server Play only. Calls unmodified production methods on an isolated instance;
-- it does NOT construct CombatService.new or attach to live player profiles.
-- Minimal Humanoid fixtures exercise server rules, not R15 animation quality.
-- Required production seam: CombatService:profileForCharacter(character).
-- Only the instance's character lookup and outbound RemoteEvent are replaced.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), "Run in Studio Server Play")
local HttpService = game:GetService("HttpService")
local foundation = game.ReplicatedStorage:WaitForChild("CombatFoundation")
local Config = require(foundation.Shared.CombatConfig)
local Timeline = require(foundation.Shared.ActionTimeline)
local Service = require(game.ServerScriptService.CombatFoundation.CombatService)
assert(type(Service.profileForCharacter) == "function", "Missing production profileForCharacter seam; do not patch damage in the test")

local area = Instance.new("Folder")
area.Name, area.Parent = "CombatDefenseQA_" .. HttpService:GenerateGUID(false), workspace
local events, characters, actors = {}, {}, {}
local remote = {
    FireAllClients = function(_, kind, player, action, started)
        table.insert(events, {kind = kind, player = player.Name, action = action, started = started})
    end,
    FireClient = function(_, player, kind, sequence)
        table.insert(events, {kind = kind, player = player.Name, sequence = sequence})
    end,
}
local service = setmetatable({remote = remote, profiles = {}, connections = {}}, Service)
function service:profileForCharacter(character)
    return characters[character]
end

local origin = Vector3.new(12000, 5000, 12000)
local function newModel(name, position)
    local model = Instance.new("Model")
    model.Name = name
    model:SetAttribute("CombatQAFixture", true)
    local root = Instance.new("Part")
    root.Name, root.Size = "HumanoidRootPart", Vector3.new(2, 2, 1)
    root.Anchored, root.CanCollide, root.CanTouch = true, false, false
    root.CFrame, root.Parent = CFrame.new(position), model
    local head = Instance.new("Part")
    head.Name, head.Size = "Head", Vector3.new(2, 1, 1)
    head.Anchored, head.CanCollide, head.CanTouch = true, false, false
    head.CFrame, head.Parent = root.CFrame * CFrame.new(0, 1.5, 0), model
    model.PrimaryPart = root
    model.Parent = area
    local humanoid = Instance.new("Humanoid")
    humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
    humanoid.MaxHealth, humanoid.Health, humanoid.Parent = 100, 100, model
    return model, humanoid, root
end
local function actor(name, position)
    local model, humanoid, root = newModel(name, position)
    local player = {Name = "QA_" .. name, Character = model}
    local profile = {
        player = player, character = nil, action = nil, started = 0,
        stamina = Config.MaxStamina, lastSpend = 0, lastSequence = 0,
        rateWindow = 0, rateCount = 0, hit = {}, comboQueued = false,
        alive = false, blocking = false, sprinting = false, characterConnections = {},
    }
    service.profiles[player] = profile
    service:bindCharacter(profile, model)
    characters[model] = profile
    local result = {model = model, humanoid = humanoid, root = root, profile = profile, player = player}
    table.insert(actors, result)
    return result
end
local attacker = actor("Attacker", origin + Vector3.new(0, 0, -4))
local defender = actor("Defender", origin)
local report = {
    scope = "Production damage/start/request/update/finish/bindCharacter; isolated server Humanoids, no real player mutation. Swept-parry control-flow case uses an explicit synthetic bladeCache; it does not validate rendered R15 blade contact.",
    pacingVersion = Config.PacingVersion, cases = {}, passed = 0, failed = 0,
    animationScope = "Started semantic broadcasts only; rendered R15 animation is a separate test",
}
local function near(actual, expected, message)
    assert(math.abs(actual - expected) < 1e-3, (message or "Unexpected value") .. ": " .. tostring(actual) .. " expected " .. tostring(expected))
end
local function reset()
    table.clear(events)
    for _, a in actors do
        local p = a.profile
        p.blocking, p.sprinting = false, false
        service:finish(p)
        a.humanoid.Health = a.humanoid.MaxHealth
        p.alive, p.stamina = true, Config.MaxStamina
        p.bladeCache = {}
        p.lastSpend, p.started, p.lastSequence, p.rateCount, p.rateWindow = 0, 0, 0, 0, 0
        a.model:SetAttribute("CombatDummy", nil)
        a.model:SetAttribute("Stamina", p.stamina)
        a.model:SetAttribute("CombatState", "Idle")
    end
    -- Move the complete fixture, including its visible Head hurtbox. Moving
    -- only the root would leave the query geometry at the previous position.
    attacker.model:PivotTo(CFrame.new(origin + Vector3.new(0, 0, -4)))
    defender.model:PivotTo(CFrame.new(origin))
end
local function run(name, fn)
    local ok, data = xpcall(function() reset(); return fn() end, debug.traceback)
    table.insert(report.cases, {name = name, status = ok and "PASS" or "FAIL", evidence = ok and data or nil, failure = not ok and tostring(data) or nil})
    if ok then report.passed += 1 else report.failed += 1 end
end
local function hit(elapsed, actionName)
    local now = workspace:GetServerTimeNow()
    defender.profile.started = now - (elapsed or 0)
    return service:damage(attacker.profile, defender.humanoid, actionName or "SwordR1_1", now)
end
local function finished(p)
    assert(p.action == nil and p.motionVelocity == nil and p.motionAttachment == nil and p.motionDirection == nil and p.facing == nil, "Interrupted action leaked motion or state")
    assert(p.comboQueued == false and p.sweepTime == nil and p.sweepRoot == nil and next(p.hit) == nil, "Interrupted action leaked combo/hit data")
end
local function hasStart(name)
    for _, event in events do if event.kind == "Started" and event.action == name then return true end end
    return false
end
local function endAction(a)
    a.profile.started = workspace:GetServerTimeNow() - Config.Actions[a.profile.action].duration - .01
    service:update(1 / Config.HitSampleRate)
end

run("front_block_absorption_and_stamina", function()
    service:request(defender.player, {kind = "BlockStart", sequence = 1})
    assert(defender.profile.blocking and defender.model:GetAttribute("CombatState") == "Blocking")
    assert(hit())
    local damage = Config.Actions.SwordR1_1.damage
    near(defender.humanoid.Health, 100 - damage * (1 - Config.Block.absorb), "Block damage")
    near(defender.profile.stamina, Config.MaxStamina - damage * Config.Block.staminaPerDamage, "Block drain")
    assert(defender.profile.blocking and defender.profile.action == nil)
    near(defender.humanoid.WalkSpeed, Config.BlockWalkSpeed)
    service:request(defender.player, {kind = "BlockEnd", sequence = 2})
    assert(not defender.profile.blocking and defender.model:GetAttribute("CombatState") == "Idle")
    near(defender.humanoid.WalkSpeed, Config.WalkSpeed)
    return {health = defender.humanoid.Health, stamina = defender.profile.stamina, absorb = Config.Block.absorb}
end)

run("back_attack_bypasses_block", function()
    defender.profile.blocking = true
    attacker.model:PivotTo(CFrame.new(origin + Vector3.new(0, 0, 4)))
    assert(hit())
    near(defender.humanoid.Health, 100 - Config.Actions.SwordR1_1.damage)
    near(defender.profile.stamina, Config.MaxStamina, "Back attack must not charge a front block")
    return {health = defender.humanoid.Health, stamina = defender.profile.stamina}
end)

run("blocked_chip_cannot_kill_training_dummy", function()
    defender.model:SetAttribute("CombatDummy", true)
    defender.humanoid.Health = 4
    service:request(defender.player, {kind = "BlockStart", sequence = 1})
    assert(hit())
    near(defender.humanoid.Health, 1, "Block chip bypassed dummy nonlethal clamp")
    assert(defender.profile.alive and defender.profile.blocking)
    near(defender.profile.stamina, Config.MaxStamina - Config.Actions.SwordR1_1.damage * Config.Block.staminaPerDamage)
    return {health = defender.humanoid.Health, blocking = true}
end)

run("insufficient_block_guard_break_consumes_remainder", function()
    service:request(defender.player, {kind = "BlockStart", sequence = 1})
    defender.profile.stamina = 5
    assert(hit())
    near(defender.profile.stamina, 0, "Guard break must consume remaining stamina")
    near(defender.model:GetAttribute("Stamina"), 0)
    near(defender.humanoid.Health, 100 - Config.Actions.SwordR1_1.damage)
    assert(not defender.profile.blocking and defender.profile.action == "GuardBroken")
    assert(defender.model:GetAttribute("CombatState") == "GuardBroken" and hasStart("GuardBroken"))
    near(defender.humanoid.WalkSpeed, 0)
    service:request(defender.player, {kind = "R1", sequence = 2})
    assert(defender.profile.action == "GuardBroken", "Attack cancelled guard-break recovery")
    endAction(defender)
    finished(defender.profile)
    assert(defender.model:GetAttribute("CombatState") == "Idle")
    near(defender.humanoid.WalkSpeed, Config.WalkSpeed)
    return {health = defender.humanoid.Health, semanticGuardBroken = true, recovered = true}
end)

run("parry_active_front_interrupts_attack", function()
    local now = workspace:GetServerTimeNow()
    assert(service:start(attacker.profile, "SwordR1_1", now))
    assert(service:start(defender.profile, "Parry", now))
    assert(hit((Config.Actions.Parry.parry[1] + Config.Actions.Parry.parry[2]) / 2))
    near(defender.humanoid.Health, 100)
    assert(attacker.profile.action == "Stagger" and attacker.model:GetAttribute("CombatState") == "Staggered")
    assert(attacker.profile.motionVelocity == nil and attacker.profile.motionAttachment == nil and attacker.profile.facing == nil)
    near(attacker.humanoid.WalkSpeed, 0)
    assert(hasStart("Stagger"))
    service:finish(defender.profile)
    endAction(attacker)
    finished(attacker.profile)
    near(attacker.humanoid.WalkSpeed, Config.WalkSpeed)
    return {defenderHealth = defender.humanoid.Health, semanticStagger = true, oldAttackMotionRemoved = true}
end)

for _, boundary in {{name = "before", elapsed = Config.Actions.Parry.parry[1] - .001}, {name = "after", elapsed = Config.Actions.Parry.parry[2] + .001}} do
    run("parry_" .. boundary.name .. "_window_does_not_protect", function()
        defender.profile.action = "Parry"
        assert(hit(boundary.elapsed))
        near(defender.humanoid.Health, 100 - Config.Actions.SwordR1_1.damage)
        assert(attacker.profile.action ~= "Stagger" and not hasStart("Stagger"))
        return {elapsed = boundary.elapsed, health = defender.humanoid.Health}
    end)
end
run("parry_active_from_behind_does_not_protect", function()
    defender.profile.action = "Parry"
    attacker.model:PivotTo(CFrame.new(origin + Vector3.new(0, 0, 4)))
    assert(hit((Config.Actions.Parry.parry[1] + Config.Actions.Parry.parry[2]) / 2))
    near(defender.humanoid.Health, 100 - Config.Actions.SwordR1_1.damage)
    assert(attacker.profile.action ~= "Stagger")
    return {health = defender.humanoid.Health}
end)

run("parried_sweep_stops_before_second_target_and_keeps_stagger_phase", function()
    -- Deliberately synthetic path: the blade first touches the parrier's Head,
    -- then would travel to the bystander. This tests the production query and
    -- sweep/update interruption control flow; real R15 FK/contact is separate.
    local bystander = actor("ParrySweepBystander", origin + Vector3.new(2, 0, -1))
    attacker.model:PivotTo(CFrame.lookAt(origin + Vector3.new(0, 0, -4), origin))
    defender.model:PivotTo(CFrame.new(origin + Vector3.new(-2, 0, -1)))
    bystander.model:PivotTo(CFrame.new(origin + Vector3.new(2, 0, -1)))
    local now = workspace:GetServerTimeNow()
    assert(service:start(attacker.profile, "SwordR1_1", now))
    assert(service:start(defender.profile, "Parry", now))
    local attackWindow = Config.Actions.SwordR1_1.active
    local midAttack = (attackWindow[1] + attackWindow[2]) / 2
    local frame = attacker.root.CFrame
    local function bladeSample(time, target)
        local center = target.model.Head.Position
        return {time = time,
            base = frame:PointToObjectSpace(center + Vector3.new(0, 0, -.6)),
            tip = frame:PointToObjectSpace(center + Vector3.new(0, 0, .6))}
    end
    attacker.profile.bladeCache.SwordR1_1 = {
        bladeSample(attackWindow[1], defender), bladeSample(midAttack, bystander),
    }
    attacker.profile.started = now - midAttack
    attacker.profile.sweepTime = attackWindow[1]
    defender.profile.started = now - (Config.Actions.Parry.parry[1] + Config.Actions.Parry.parry[2]) / 2
    service:update(1 / Config.HitSampleRate)
    assert(attacker.profile.action == "Stagger", "Sweep did not reach parrier fixture")
    assert(attacker.model:GetAttribute("CombatState") == "Staggered", "Old attack update overwrote stagger state after parry")
    near(defender.humanoid.Health, 100, "Parrier received attack damage")
    near(bystander.humanoid.Health, 100, "Parried sweep continued damaging a second target")
    assert(attacker.profile.motionVelocity == nil and attacker.profile.motionAttachment == nil)
    return {parrierHealth = defender.humanoid.Health, bystanderHealth = bystander.humanoid.Health,
        state = attacker.model:GetAttribute("CombatState"), geometry = "Synthetic bladeCache; defensive control flow only"}
end)

for _, name in {"RollForward", "RollBackward", "RollLeft", "RollRight"} do
    run(name .. "_iframe_window_and_recovery", function()
        local action = Config.Actions[name]
        assert(service:start(defender.profile, name, workspace:GetServerTimeNow()))
        assert(hit(action.iframes[1] - .001), "Pre-iframe hit was incorrectly ignored")
        near(defender.humanoid.Health, 100 - Config.Actions.SwordR1_1.damage)
        defender.humanoid.Health = 100
        assert(not hit((action.iframes[1] + action.iframes[2]) / 2), "Active iframe accepted damage")
        near(defender.humanoid.Health, 100)
        assert(hit(action.iframes[2] + .001), "Post-iframe recovery retained invulnerability")
        near(defender.humanoid.Health, 100 - Config.Actions.SwordR1_1.damage)
        assert(defender.profile.action == name, "Taking a recovery hit changed the roll unexpectedly")
        endAction(defender)
        finished(defender.profile)
        assert(hit(action.duration + .01), "Finished roll retained invulnerability")
        return {iframeDuration = action.iframes[2] - action.iframes[1], healthAfterRecoveryHits = defender.humanoid.Health, motionRemoved = true}
    end)
end

run("explicit_roll_interruption_removes_invulnerability_and_motion", function()
    assert(service:start(defender.profile, "RollForward", workspace:GetServerTimeNow()))
    local velocity, attachment = defender.profile.motionVelocity, defender.profile.motionAttachment
    assert(velocity and attachment)
    assert(not hit(.4))
    defender.profile.comboQueued = true
    defender.profile.sweepTime = .3
    defender.profile.hit[attacker.humanoid] = true
    service:finish(defender.profile)
    finished(defender.profile)
    assert(velocity.Parent == nil and attachment.Parent == nil)
    near(defender.humanoid.WalkSpeed, Config.WalkSpeed)
    assert(defender.humanoid.AutoRotate and defender.model:GetAttribute("CombatState") == "Idle")
    assert(hit(.4), "Interrupted roll retained iframe protection")
    return {health = defender.humanoid.Health, priorConstraintsDestroyed = true}
end)

-- Death/respawn runs last because a dead fixture Humanoid is replaced, not revived.
run("death_during_roll_and_respawn_clear_old_connections", function()
    assert(service:start(defender.profile, "RollForward", workspace:GetServerTimeNow()))
    local oldCharacter = defender.model
    local oldConnection = defender.profile.characterConnections[1]
    local oldVelocity, oldAttachment = defender.profile.motionVelocity, defender.profile.motionAttachment
    defender.humanoid.Health = 0
    local deadline = os.clock() + 1
    while defender.profile.alive and os.clock() < deadline do RunService.Heartbeat:Wait() end
    assert(not defender.profile.alive and oldCharacter:GetAttribute("CombatState") == "Dead", "Died callback did not clear live action")
    finished(defender.profile)
    assert(oldVelocity.Parent == nil and oldAttachment.Parent == nil)
    local model, humanoid, root = newModel("DefenderRespawn", origin)
    service:bindCharacter(defender.profile, model)
    characters[oldCharacter], characters[model] = nil, defender.profile
    defender.model, defender.humanoid, defender.root, defender.player.Character = model, humanoid, root, model
    assert(oldConnection.Connected == false, "Respawn retained old Died connection")
    assert(defender.profile.alive and not defender.profile.blocking and not defender.profile.sprinting)
    near(defender.profile.stamina, Config.MaxStamina)
    near(humanoid.WalkSpeed, Config.WalkSpeed)
    assert(model:GetAttribute("CombatState") == "Idle")
    assert(hit(.4), "Respawn inherited old roll iframe")
    oldCharacter:Destroy()
    return {oldDiedDisconnected = true, respawnHealth = humanoid.Health, respawnStamina = defender.profile.stamina}
end)

local cleanupOK, cleanupFailure = pcall(function()
    service:destroy()
    assert(next(service.profiles) == nil, "Test profiles survived destroy")
    for _, a in actors do
        assert(a.profile.character == nil and #a.profile.characterConnections == 0, "Character cleanup retained fixtures/connections")
    end
end)
area:Destroy()
report.cleanup = {status = cleanupOK and "PASS" or "FAIL", fixtureAreaRemoved = area.Parent == nil, failure = not cleanupOK and tostring(cleanupFailure) or nil}
if not cleanupOK then report.failed += 1 end
return HttpService:JSONEncode(report)
