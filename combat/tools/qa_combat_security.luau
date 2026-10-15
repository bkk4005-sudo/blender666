-- Run in Server Play after importing the current CombatService/CombatConfig.
-- Calls real service methods on isolated synthetic characters; only remote
-- delivery is recorded locally. No player profile, map part or asset is edited.
-- The returned JSON contains every PASS/FAIL. All QA instances/connections are
-- destroyed even when a check fails. This is not a two-player latency test.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("CombatFoundation"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CombatConfig"))
local Service = require(game.ServerScriptService:WaitForChild("CombatFoundation"):WaitForChild("CombatService"))
local area = Instance.new("Folder")
area.Name, area.Parent = "CombatSecurityQA_" .. Http:GenerateGUID(false), workspace
local report = {suite = "combat_request_security", checks = {}, passed = 0, failed = 0}
local caseNumber = 0

local function makeFixture(realRig)
    caseNumber += 1
    local character
    if realRig then
        local description = Instance.new("HumanoidDescription")
        local ok, created = pcall(function()
            return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
        end)
        description:Destroy()
        if not ok then error(created) end
        character = created
    else
        character = Instance.new("Model")
    end
    character.Name, character.Parent = "Actor_" .. caseNumber, area
    local root = character:FindFirstChild("HumanoidRootPart") or Instance.new("Part")
    local actorFrame = CFrame.new(20000 + caseNumber * 20, 5000, 20000)
    root.Name = "HumanoidRootPart"
    if not realRig then root.Size, root.CFrame = Vector3.new(2, 2, 1), actorFrame end
    root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
    root.Parent = character
    -- A Head is required for the actual Humanoid death state / Died event.
    -- RequiresNeck=false keeps this minimal rules fixture independent of rigs.
    if not realRig then
        local head = Instance.new("Part")
        head.Name, head.Size = "Head", Vector3.new(2, 1, 1)
        head.Anchored, head.CanCollide, head.CanQuery, head.CanTouch = true, false, false, false
        head.CFrame, head.Parent = root.CFrame * CFrame.new(0, 1.5, 0), character
    else
        for _, item in character:GetDescendants() do
            if item:IsA("BasePart") then
                item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false
            elseif item:IsA("ForceField") then
                item:Destroy()
            end
        end
        character.PrimaryPart = root
        character:PivotTo(actorFrame)
    end
    character.PrimaryPart = root
    local humanoid = character:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
    humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
    humanoid.MaxHealth, humanoid.Health, humanoid.Parent = 100, 100, character
    local player = {}
    local events = {}
    local remote = {
        FireAllClients = function(_, kind, who, action, at)
            table.insert(events, {kind = kind, who = who, action = action, at = at})
        end,
        FireClient = function(_, who, kind, sequence)
            table.insert(events, {kind = kind, who = who, sequence = sequence})
        end,
    }
    local profile = {
        player = player, character = character, alive = true, stamina = Config.MaxStamina,
        lastSpend = 0, lastSequence = 0, rateWindow = 0, rateCount = 0,
        hit = {}, comboQueued = false, blocking = false, sprinting = false,
        characterConnections = {},
    }
    local service = setmetatable({remote = remote, profiles = {[player] = profile}, connections = {}}, Service)
    return {
        service = service, profile = profile, character = character,
        humanoid = humanoid, root = root, player = player, events = events,
    }
end

local function check(name, body, realRig)
    local f
    local ok, failure = pcall(function()
        f = makeFixture(realRig)
        body(f)
    end)
    local cleanupOk, cleanupFailure = pcall(function()
        if f then
            f.service:destroy()
            f.character:Destroy()
        end
    end)
    ok = ok and cleanupOk
    table.insert(report.checks, {name = name, status = ok and "PASS" or "FAIL",
        reason = not ok and tostring(failure or cleanupFailure) or nil})
    if ok then report.passed += 1 else report.failed += 1 end
end

local function send(f, kind, extras)
    local request = {kind = kind, sequence = f.profile.lastSequence + 1}
    for key, value in extras or {} do request[key] = value end
    f.service:request(f.player, request)
end

local function unchanged(f, stamina, eventCount)
    assert(f.profile.action == nil, "Rejected request started an action")
    assert(f.profile.stamina == stamina, "Rejected request spent stamina")
    assert(f.profile.motionAttachment == nil and f.profile.motionVelocity == nil, "Rejected request created motion")
    if eventCount ~= nil then assert(#f.events == eventCount, "Unexpected network event") end
end

check("malformed payloads and nonfinite / invalid sequences", function(f)
    for _, payload in {false, "R1", 10, {kind = "R1"},
        {kind = "R1", sequence = "1"}, {kind = "R1", sequence = .5},
        {kind = "R1", sequence = 0}, {kind = "R1", sequence = -1},
        {kind = "R1", sequence = 0 / 0}, {kind = "R1", sequence = math.huge},
        {kind = "R1", sequence = -math.huge}, {kind = "R1", sequence = 101}} do
        f.service:request(f.player, payload)
        unchanged(f, Config.MaxStamina, 0)
        assert(f.profile.lastSequence == 0, "Invalid sequence was consumed")
    end
    f.service:request({}, {kind = "R1", sequence = 1})
    unchanged(f, Config.MaxStamina, 0)
end)

check("repeated and out-of-order requests cannot double-spend", function(f)
    send(f, "R1")
    assert(f.profile.action == "SwordR1_1" and #f.events == 1)
    local stamina = Config.MaxStamina - Config.Actions.SwordR1_1.cost
    for _, sequence in {1, 1, 0, -1} do
        f.service:request(f.player, {kind = "R2", sequence = sequence})
        assert(f.profile.stamina == stamina and #f.events == 1)
    end
    f.service:finish(f.profile)
    f.service:request(f.player, {kind = "R2", sequence = 3})
    assert(f.profile.action == "SwordR2" and f.profile.lastSequence == 3)
    f.service:finish(f.profile)
    local before = f.profile.stamina
    f.service:request(f.player, {kind = "R1", sequence = 2})
    unchanged(f, before, 2)
end)

check("rate limit blocks new actions and resets after server window", function(f)
    for _ = 1, Config.MaxRequestRate do send(f, "UnknownAction") end
    send(f, "R1")
    unchanged(f, Config.MaxStamina, 1)
    assert(f.events[1].kind == "Rejected", "Rate-limited legitimate prediction needs a rejection")
    assert(f.profile.rateCount == Config.MaxRequestRate + 1)
    f.profile.rateWindow = workspace:GetServerTimeNow() - 1.01
    send(f, "R1")
    assert(f.profile.action == "SwordR1_1" and f.profile.rateCount == 1 and #f.events == 2)
end)

check("held controls can be released after rate-limited burst", function(f)
    send(f, "BlockStart")
    assert(f.profile.blocking and f.humanoid.WalkSpeed == Config.BlockWalkSpeed)
    for _ = 1, Config.MaxRequestRate + 1 do send(f, "UnknownAction") end
    send(f, "BlockEnd")
    assert(not f.profile.blocking and f.humanoid.WalkSpeed == Config.WalkSpeed)
    f.profile.rateWindow = workspace:GetServerTimeNow() - 1.01
    send(f, "SprintStart")
    assert(f.profile.sprinting)
    for _ = 1, Config.MaxRequestRate + 1 do send(f, "UnknownAction") end
    send(f, "SprintEnd")
    assert(not f.profile.sprinting and f.humanoid.WalkSpeed == Config.WalkSpeed)
end)

for axis = 1, 3 do
    for _, value in {0 / 0, math.huge, -math.huge} do
        check("nonfinite roll component " .. axis .. " / " .. tostring(value), function(f)
            local components = {0, 0, -1}
            components[axis] = value
            send(f, "Roll", {direction = "RollForward", moveDirection = Vector3.new(unpack(components))})
            unchanged(f, Config.MaxStamina, 0)
        end)
    end
end

check("invalid roll vectors, directions and spoofed payload fields", function(f)
    for _, vector in {Vector3.zero, Vector3.new(0, 0, -2), Vector3.new(0, 0, -.2),
        Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), "forward"} do
        f.profile.rateWindow = workspace:GetServerTimeNow() - 1.01
        send(f, "Roll", {direction = "RollForward", moveDirection = vector})
        unchanged(f, Config.MaxStamina, 0)
    end
    for _, direction in {"Teleport", false, {}} do
        send(f, "Roll", {direction = direction})
        unchanged(f, Config.MaxStamina)
    end
    send(f, "DealDamage", {damage = 99999, iframes = true, stamina = 99999, target = f.humanoid})
    unchanged(f, Config.MaxStamina)
end)

check("all four valid rolls use server cost and normalized planar direction", function(f)
    for _, item in {{"RollForward", Vector3.new(0, 0, -1)}, {"RollBackward", Vector3.new(0, 0, 1)},
        {"RollLeft", Vector3.new(-1, 0, 0)}, {"RollRight", Vector3.new(1, 0, 0)}} do
        f.profile.stamina = Config.MaxStamina
        send(f, "Roll", {direction = item[1], moveDirection = item[2], stamina = 99999, iframes = true})
        assert(f.profile.action == item[1])
        assert(f.profile.stamina == Config.MaxStamina - Config.Actions[item[1]].cost)
        assert((f.profile.motionDirection - item[2]).Magnitude < .001)
        assert(f.profile.motionVelocity and f.profile.motionAttachment)
        f.service:finish(f.profile)
        assert(not f.profile.motionVelocity and not f.profile.motionAttachment)
    end
end)

check("roll cannot be interrupted by attacks, defense or another roll", function(f)
    send(f, "Roll", {direction = "RollForward"})
    local stamina = f.profile.stamina
    local motion = f.profile.motionVelocity
    for _, kind in {"R1", "R2", "Parry", "Roll", "BlockStart", "SprintStart", "BlockEnd", "SprintEnd"} do
        send(f, kind, {direction = "RollLeft"})
        assert(f.profile.action == "RollForward" and f.profile.stamina == stamina)
        assert(f.profile.motionVelocity == motion, "Active roll actuator was replaced")
        assert(f.character:GetAttribute("CombatState") == "Rolling")
    end
end)

check("insufficient stamina rejects R1, R2, parry and all rolls", function(f)
    f.profile.stamina = 0
    for _, item in {{"R1", nil}, {"R2", nil}, {"Parry", nil}, {"Roll", "RollForward"},
        {"Roll", "RollBackward"}, {"Roll", "RollLeft"}, {"Roll", "RollRight"}} do
        send(f, item[1], {direction = item[2]})
        unchanged(f, 0)
        assert(f.events[#f.events].kind == "Rejected")
    end
    send(f, "BlockStart")
    send(f, "SprintStart")
    assert(not f.profile.blocking and not f.profile.sprinting)
end)

check("insufficient combo stamina cannot cancel first attack recovery", function(f)
    send(f, "R1")
    f.profile.stamina = Config.Actions.SwordR1_2.cost - 1
    f.profile.started = workspace:GetServerTimeNow() - Config.Actions.SwordR1_1.bufferOpen - .01
    send(f, "R1")
    assert(not f.profile.comboQueued and f.events[#f.events].kind == "Rejected")
    f.profile.started = workspace:GetServerTimeNow() - Config.Actions.SwordR1_1.chainAt - .01
    f.service:update(0)
    assert(f.profile.action == "SwordR1_1", "Rejected combo shortened recovery")
    assert(f.character:GetAttribute("CombatState") == "AttackRecovery")
end)

check("combo input only queues inside the permitted server window", function(f)
    send(f, "R1")
    local stamina = f.profile.stamina
    f.profile.started = workspace:GetServerTimeNow() - Config.Actions.SwordR1_1.bufferOpen + .05
    send(f, "R1")
    assert(not f.profile.comboQueued and f.profile.stamina == stamina)
    f.profile.started = workspace:GetServerTimeNow() - Config.Actions.SwordR1_1.bufferOpen - .01
    send(f, "R1")
    assert(f.profile.comboQueued and f.profile.stamina == stamina, "Combo cost must occur at chain, not buffer")
    f.profile.started = workspace:GetServerTimeNow() - Config.Actions.SwordR1_1.chainAt - .01
    f.service:update(0)
    assert(f.profile.action == "SwordR1_2")
    assert(f.profile.stamina == stamina - Config.Actions.SwordR1_2.cost)
    send(f, "R1")
    assert(f.profile.action == "SwordR1_2" and not f.profile.comboQueued, "Infinite third combo allowed")
end)

check("recovery rejects incompatible actions until complete", function(f)
    send(f, "R2")
    f.profile.started = workspace:GetServerTimeNow() - Config.Actions.SwordR2.active[2] - .01
    f.service:update(0)
    assert(f.character:GetAttribute("CombatState") == "AttackRecovery")
    local stamina = f.profile.stamina
    for _, kind in {"R1", "R2", "Parry", "Roll", "BlockStart", "SprintStart"} do
        send(f, kind, {direction = "RollForward"})
        assert(f.profile.action == "SwordR2" and f.profile.stamina == stamina)
    end
    f.profile.started = workspace:GetServerTimeNow() - Config.Actions.SwordR2.duration - .01
    f.service:update(0)
    assert(f.profile.action == nil and not f.profile.motionVelocity)
    send(f, "R1")
    assert(f.profile.action == "SwordR1_1")
end)

check("sprint release preserves blocking speed and vice versa", function(f)
    send(f, "SprintStart")
    send(f, "BlockStart")
    assert(f.profile.blocking and not f.profile.sprinting)
    send(f, "SprintEnd")
    assert(f.humanoid.WalkSpeed == Config.BlockWalkSpeed and f.profile.blocking)
    send(f, "BlockEnd")
    send(f, "SprintStart")
    send(f, "BlockEnd")
    assert(f.profile.sprinting and f.humanoid.WalkSpeed == Config.SprintSpeed)
end)

check("direct start rejects duplicate, invalid clock and nonfinite motion", function(f)
    assert(not f.service:start(f.profile, "NoSuchAction", workspace:GetServerTimeNow()))
    for _, now in {0 / 0, math.huge, -math.huge, "now"} do
        assert(not f.service:start(f.profile, "SwordR1_1", now))
        unchanged(f, Config.MaxStamina, 0)
    end
    assert(not f.service:start(f.profile, "RollForward", workspace:GetServerTimeNow(), Vector3.new(0 / 0, 0, -1)))
    unchanged(f, Config.MaxStamina, 0)
    assert(f.service:start(f.profile, "RollForward", workspace:GetServerTimeNow()))
    local stamina, motion = f.profile.stamina, f.profile.motionVelocity
    assert(not f.service:start(f.profile, "SwordR1_1", workspace:GetServerTimeNow()))
    assert(f.profile.stamina == stamina and f.profile.motionVelocity == motion and #f.events == 1)
end)

check("dead or absent character cannot start or spend stamina", function(f)
    f.profile.alive = false
    send(f, "R1")
    assert(not f.service:start(f.profile, "RollForward", workspace:GetServerTimeNow()))
    unchanged(f, Config.MaxStamina, 0)
    f.profile.alive = true -- Exercise stale alive flag against actual Humanoid health.
    f.humanoid.Health = 0
    send(f, "R2")
    assert(not f.service:start(f.profile, "SwordR1_1", workspace:GetServerTimeNow()))
    unchanged(f, Config.MaxStamina, 0)
    f.profile.character = nil
    assert(not f.service:start(f.profile, "SwordR1_1", workspace:GetServerTimeNow()))
    unchanged(f, Config.MaxStamina, 0)
end)

check("death cleans active roll and respawn resets action / stamina", function(f)
    f.service:bindCharacter(f.profile, f.character)
    send(f, "Roll", {direction = "RollRight"})
    local motion, attachment = f.profile.motionVelocity, f.profile.motionAttachment
    -- Let the genuine R15 Humanoid enter its initial simulation state before
    -- exercising the engine's death transition; do not invoke Died manually.
    RunService.Heartbeat:Wait()
    RunService.Heartbeat:Wait()
    f.humanoid.Health = 0
    -- Humanoid.Died is asynchronous, so wait for the actual callback.
    local timeout = os.clock() + 1
    while f.profile.alive and os.clock() < timeout do task.wait() end
    assert(not f.profile.alive, "Humanoid.Died did not reach the profile")
    assert(f.profile.action == nil and not f.profile.motionVelocity and not f.profile.motionAttachment)
    assert(motion.Parent == nil and attachment.Parent == nil)
    assert(f.character:GetAttribute("CombatState") == "Dead")
    local before = f.profile.stamina
    send(f, "R1")
    unchanged(f, before)
    -- Use a new living instance rather than reviving a dead Humanoid.
    local fresh = makeFixture(true)
    fresh.service:destroy()
    f.service:bindCharacter(f.profile, fresh.character)
    assert(f.profile.alive and f.profile.stamina == Config.MaxStamina and f.profile.action == nil)
    assert(fresh.character:GetAttribute("CombatState") == "Idle")
    send(f, "R1")
    assert(f.profile.action == "SwordR1_1")
end, true)

check("player removal clears motion, profile and character connections", function(f)
    f.service:bindCharacter(f.profile, f.character)
    send(f, "Roll", {direction = "RollForward"})
    local motion, attachment = f.profile.motionVelocity, f.profile.motionAttachment
    f.service:removePlayer(f.player)
    assert(f.service.profiles[f.player] == nil and f.profile.character == nil)
    assert(#f.profile.characterConnections == 0 and motion.Parent == nil and attachment.Parent == nil)
    f.service:request(f.player, {kind = "R1", sequence = 100})
    assert(#f.events == 1)
end)

area:Destroy()
report.status = report.failed == 0 and "PASS" or "FAIL"
return Http:JSONEncode(report)
