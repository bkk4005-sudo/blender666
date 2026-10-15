-- Server Play regression for production frame collection/resolution.
-- Real generated R15 hurtboxes; synthetic blade paths isolate ordering.
-- No real Player profile is modified. This is not a two-Player network test.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Config = require(game.ReplicatedStorage.CombatFoundation.Shared.CombatConfig)
local Service = require(game.ServerScriptService.CombatFoundation.CombatService)
local description = Instance.new("HumanoidDescription")
local okTemplate, template = pcall(function()
    return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
end)
description:Destroy()
assert(okTemplate, template)
local area = Instance.new("Folder")
area.Name, area.Parent = "CombatSimultaneousFramesQA", workspace
local origin = Vector3.new(0, 5000, 200)
local report = {scope = "Isolated real R15 hurtboxes; synthetic bladeCache; frame ordering only",
    passed = 0, failed = 0, checks = {}}
local context
local function actor(name, offset, health)
    local model = template:Clone()
    model.Name, model.Parent = name, context.folder
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            item.Anchored, item.CanCollide, item.CanTouch = true, false, false
            item.CanQuery = item.Name == "Head"
        elseif item:IsA("ForceField") then item:Destroy() end
    end
    local humanoid, root = model.Humanoid, model.HumanoidRootPart
    humanoid.BreakJointsOnDeath = false
    humanoid.MaxHealth, humanoid.Health = 100, health or 100
    model:PivotTo(CFrame.new(origin + offset))
    local profile = {player = name, characterConnections = {}, alive = true,
        stamina = 100, lastSpend = 0, lastSequence = 0, rateWindow = 0, rateCount = 0,
        hit = {}, comboQueued = false, blocking = false, sprinting = false, started = 0}
    context.service:bindCharacter(profile, model)
    local value = {model = model, humanoid = humanoid, root = root, profile = profile}
    table.insert(context.actors, value)
    context.characters[model] = profile
    table.insert(context.service.profiles, profile)
    return value
end
local function bladeSample(attacker, target, time)
    local frame = CFrame.lookAt(attacker.root.Position,
        attacker.root.Position + attacker.root.CFrame.LookVector)
    local center = target.model.Head.Position
    return {time = time, base = frame:PointToObjectSpace(center - Vector3.new(0, 0, .5)),
        tip = frame:PointToObjectSpace(center + Vector3.new(0, 0, .5))}
end
local function attack(attacker, target, elapsed)
    local now = workspace:GetServerTimeNow()
    assert(context.service:start(attacker.profile, "SwordR1_1", now))
    local window = Config.Actions.SwordR1_1.active
    attacker.profile.started = now - (elapsed or .6)
    attacker.profile.sweepTime = window[1] - .001
    attacker.profile.bladeCache = {SwordR1_1 = {
        bladeSample(attacker, target, window[1]), bladeSample(attacker, target, window[2]),
    }}
end
local function update()
    context.service:update(1 / Config.HitSampleRate)
end
local function near(value, expected)
    assert(math.abs(value - expected) < .01, tostring(value) .. " != " .. tostring(expected))
end
local function lethal(actor)
    -- TakeDamage can expose negative HP until the next engine update clamps
    -- it to zero. The same-frame invariant is death, not synchronous clamping.
    assert(actor.humanoid.Health <= 0, "Lethal contact left its target alive")
end
local function run(name, callback)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = name, area
    context = {folder = folder, actors = {}, characters = {}, events = {}}
    local current = context
    current.service = setmetatable({profiles = {}, connections = {}, remote = {
        FireAllClients = function(_, kind, owner, action, at, metadata)
            table.insert(current.events, {kind = kind, owner = owner, action = action,
                at = at, metadata = metadata})
        end,
        FireClient = function() end,
    }}, Service)
    current.service.profileForCharacter = function(_, character) return current.characters[character] end
    local ok, value = xpcall(callback, debug.traceback)
    for _, item in current.actors do current.service:clearCharacter(item.profile) end
    folder:Destroy()
    report.checks[name] = {status = ok and "PASS" or "FAIL", result = ok and value or nil,
        failure = not ok and tostring(value) or nil}
    if ok then report.passed += 1 else report.failed += 1 end
end

for _, reverse in {false, true} do
    run(reverse and "lethal_trade_reverse_profile_order" or "lethal_trade", function()
        local a = actor("TradeA", Vector3.zero, 20)
        local b = actor("TradeB", Vector3.new(0, 0, 3), 20)
        local untouched = actor("NextFrameTarget", Vector3.new(3, 0, 3))
        attack(a, b)
        attack(b, a)
        if reverse then context.service.profiles = {b.profile, a.profile, untouched.profile} end
        update()
        lethal(a)
        lethal(b)
        -- Dead actors may finish only contacts collected before this resolution.
        local window = Config.Actions.SwordR1_1.active
        a.profile.bladeCache.SwordR1_1 = {bladeSample(a, untouched, window[1]), bladeSample(a, untouched, window[2])}
        b.profile.bladeCache.SwordR1_1 = {bladeSample(b, untouched, window[1]), bladeSample(b, untouched, window[2])}
        update()
        near(untouched.humanoid.Health, 100)
        return {aHealth = a.humanoid.Health, bHealth = b.humanoid.Health,
            nextFrameTargetHealth = untouched.humanoid.Health, reverseProfileOrder = reverse}
    end)
end
run("nonlethal_trade_is_deduplicated", function()
    local a = actor("NonlethalA", Vector3.zero)
    local b = actor("NonlethalB", Vector3.new(0, 0, 3))
    attack(a, b)
    attack(b, a)
    update()
    near(a.humanoid.Health, 78)
    near(b.humanoid.Health, 78)
    a.profile.started = workspace:GetServerTimeNow() - .65
    b.profile.started = workspace:GetServerTimeNow() - .65
    update()
    near(a.humanoid.Health, 78)
    near(b.humanoid.Health, 78)
    return {aHealth = a.humanoid.Health, bHealth = b.humanoid.Health, duplicateDamage = false}
end)
run("iframe_rejection_does_not_consume_swing", function()
    local a = actor("IframeAttacker", Vector3.zero)
    local b = actor("IframeDefender", Vector3.new(0, 0, 3))
    attack(a, b)
    assert(context.service:start(b.profile, "RollForward", workspace:GetServerTimeNow()))
    b.profile.started = workspace:GetServerTimeNow() - .4
    update()
    near(b.humanoid.Health, 100)
    assert(not a.profile.hit[b.humanoid], "Rejected iframe contact consumed the target")
    a.profile.started = workspace:GetServerTimeNow() - .65
    b.profile.started = workspace:GetServerTimeNow() - .65
    update()
    near(b.humanoid.Health, 78)
    assert(a.profile.hit[b.humanoid], "Successful post-iframe contact was not recorded")
    return {healthAfterIframes = b.humanoid.Health, swingRetried = true}
end)
run("direct_sweep_remains_immediate", function()
    local a = actor("ImmediateAttacker", Vector3.zero)
    local b = actor("ImmediateTarget", Vector3.new(0, 0, 3))
    attack(a, b)
    context.service:sweep(a.profile, "SwordR1_1", .6, workspace:GetServerTimeNow())
    near(b.humanoid.Health, 78)
    assert(a.profile.hit[b.humanoid])
    return {targetHealth = b.humanoid.Health}
end)
run("dead_trade_can_be_parried_without_dead_stagger_or_later_hit", function()
    local killer = actor("Killer", Vector3.zero)
    local a = actor("DyingAttacker", Vector3.new(0, 0, 3), 20)
    local parrier = actor("Parrier", Vector3.new(-3, 0, 3))
    local bystander = actor("Bystander", Vector3.new(3, 0, 3))
    parrier.model:PivotTo(CFrame.lookAt(parrier.root.Position, a.root.Position))
    attack(killer, a)
    attack(a, parrier)
    local window = Config.Actions.SwordR1_1.active
    a.profile.bladeCache.SwordR1_1 = {bladeSample(a, parrier, window[1]), bladeSample(a, bystander, .6)}
    assert(context.service:start(parrier.profile, "Parry", workspace:GetServerTimeNow()))
    parrier.profile.started = workspace:GetServerTimeNow() - .28
    update()
    lethal(a)
    near(parrier.humanoid.Health, 100)
    near(bystander.humanoid.Health, 100)
    assert(a.profile.action == nil and a.model:GetAttribute("CombatState") == "Dead",
        "Parrying a same-frame dead trade changed its Dead state")
    for _, event in context.events do
        assert(not (event.owner == a.profile.player and event.action == "Stagger"), "Dead actor broadcast Stagger")
    end
    return {deadAttackerHealth = a.humanoid.Health, parrierHealth = parrier.humanoid.Health,
        bystanderHealth = bystander.humanoid.Health, deadStaggerBroadcast = false}
end)

area:Destroy()
template:Destroy()
report.cleanup = {fixtureAreaRemoved = area.Parent == nil, templateDestroyed = template.Parent == nil}
return Http:JSONEncode(report)
