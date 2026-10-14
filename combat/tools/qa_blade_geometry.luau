-- Studio Server Play. Real standard R15 rigs and authored KeyframeSequences.
-- Exercises production BladeTrajectory + CombatService.sweep on an isolated
-- instance. No real player profile, health, input or map objects are changed.
-- This is server FK/contact QA, not rendered Animator or network-latency QA.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), "Run in Studio Server Play")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local foundation = game.ReplicatedStorage:WaitForChild("CombatFoundation")
local server = game.ServerScriptService:WaitForChild("CombatFoundation")
local Config = require(foundation.Shared.CombatConfig)
local Trajectory = require(server.BladeTrajectory)
local Service = require(server.CombatService)
local clips = {"SwordR1_1", "SwordR1_2", "SwordR2"}
local origin = Vector3.new(16000, 7000, 16000)
local area = Instance.new("Folder")
area.Name, area.Parent = "CombatBladeQA_" .. HttpService:GenerateGUID(false), workspace
local service = setmetatable({profiles = {}, connections = {}, remote = {
    FireAllClients = function() end, FireClient = function() end,
}}, Service)
local report = {scope = "Authored KeyframeSequence -> real standard R15 FK -> production blade query/sweep. Isolated server fixtures; no visual playback, real clients or latency assertions.",
    pacingVersion = Config.PacingVersion, cases = {}, passed = 0, failed = 0}
local fixtures, originalParts, transient = {}, {}, {}
local attacker, target, profile, extras

local function near(a, b, message)
    assert(math.abs(a - b) < 1e-3, (message or "Unexpected value") .. ": " .. tostring(a) .. " expected " .. tostring(b))
end
local function vector(v) return {v.X, v.Y, v.Z} end
local function moveRoot(model, cf)
    local root = assert(model:FindFirstChild("HumanoidRootPart"))
    model:PivotTo(cf * root.CFrame:Inverse() * model:GetPivot())
end
local function makeR15(name, position)
    local description = Instance.new("HumanoidDescription")
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
    end)
    description:Destroy()
    if not ok then error(model) end
    model.Name, model.Parent = name, area
    table.insert(fixtures, model)
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, true
        elseif item:IsA("ForceField") then item:Destroy() end
    end
    local h = assert(model:FindFirstChildOfClass("Humanoid"))
    h.BreakJointsOnDeath, h.RequiresNeck = false, false
    h.MaxHealth, h.Health = 100, 100
    moveRoot(model, CFrame.new(position))
    local snapshot = {}
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then snapshot[part] = {frame = part.CFrame, query = part.CanQuery, size = part.Size} end
    end
    originalParts[model] = snapshot
    return model
end
local function reset()
    service:finish(profile)
    service.profileForCharacter = nil
    for _, item in transient do if item.Parent then item:Destroy() end end
    table.clear(transient)
    profile.alive, profile.stamina, profile.lastSpend = true, Config.MaxStamina, 0
    profile.blocking, profile.sprinting = false, false
    for model, parts in originalParts do
        for part, data in parts do
            part.CFrame, part.CanQuery, part.Size = data.frame, data.query, data.size
        end
        model.Humanoid.Health = 100
    end
    if extras then extras:Destroy() end
    extras = Instance.new("Folder")
    extras.Name, extras.Parent = "CaseObjects", area
end
local function run(name, fn)
    local ok, evidence = xpcall(function() reset(); return fn() end, debug.traceback)
    table.insert(report.cases, {name = name, status = ok and "PASS" or "FAIL",
        evidence = ok and evidence or nil, failure = not ok and tostring(evidence) or nil})
    if ok then report.passed += 1 else report.failed += 1 end
end
local function begin(name)
    profile.stamina = Config.MaxStamina
    assert(service:start(profile, name, workspace:GetServerTimeNow()), "Could not start test " .. name)
    local path = assert(service:bladePath(profile, name), "Cannot bake actual R15 " .. name)
    assert(#path > 2, "Authored blade path has too few samples")
    return path
end
local function frame()
    local root = attacker.HumanoidRootPart
    return CFrame.lookAt(root.Position, root.Position + (profile.facing or root.CFrame.LookVector))
end
local function worldBlade(path, time, cf)
    local a, b = Trajectory.sample(path, time)
    cf = cf or frame()
    return cf:PointToWorldSpace(a), cf:PointToWorldSpace(b)
end
local function contactCandidates(path, time)
    local oldA, oldB = worldBlade(path, time - 1e-5)
    local a, b = worldBlade(path, time)
    local candidates = {}
    -- Include both samples made by stationary sweep, not just its final pose.
    for _, query in {
        Trajectory.query(attacker, oldA, oldB, nil, nil, .18),
        Trajectory.query(attacker, a, b, oldA, oldB, .18),
    } do
        for _, candidate in query[target.Humanoid] or {} do
            assert(candidate.part and candidate.origin and candidate.contact, "Expected contact-aware BladeTrajectory candidates")
            table.insert(candidates, candidate)
        end
    end
    assert(#candidates > 0, "Fixture has no actual authored blade contact")
    return candidates
end
local function visibilityParams()
    local params = RaycastParams.new()
    params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, {attacker, target}, true
    return params
end
local function pathVisibility(candidates, params, wall)
    local root = frame().Position
    local result = {count = #candidates, rootBlocked = 0, rootFree = 0, contactBlocked = 0, contactFree = 0, centerFree = 0}
    for _, candidate in candidates do
        local rootRay = workspace:Raycast(root, candidate.origin - root, params)
        local contactRay = workspace:Raycast(candidate.origin, candidate.contact - candidate.origin, params)
        local centerRay = workspace:Raycast(candidate.origin, candidate.part.Position - candidate.origin, params)
        if not rootRay then result.rootFree += 1 elseif rootRay.Instance == wall then result.rootBlocked += 1 end
        if not contactRay then result.contactFree += 1 elseif contactRay.Instance == wall then result.contactBlocked += 1 end
        if not centerRay then result.centerFree += 1 end
    end
    return result
end
local function placeTorso(point)
    target:PivotTo(CFrame.new(point - target.UpperTorso.Position) * target:GetPivot())
    near((target.UpperTorso.Position - point).Magnitude, 0, "Torso fixture did not reach sampled blade")
end
local function sweep(name, time, stationary)
    -- A real sweep processes a nonzero elapsed interval. Preserve a fixed root
    -- while sampling a tiny authored interval around this contact pose.
    if stationary then profile.sweepTime, profile.sweepRoot = time - 1e-5, frame() end
    service:sweep(profile, name, time, workspace:GetServerTimeNow())
end
local function fullActive(name)
    local active = Config.Actions[name].active
    local time = active[1]
    while time < active[2] do
        sweep(name, time, false)
        time += 1 / 60
    end
    sweep(name, active[2], false)
end

local setupOK, setupFailure = xpcall(function()
    attacker = makeR15("AttackerR15", origin)
    target = makeR15("TargetR15", origin + Vector3.new(0, 0, -40))
    local player = {Name = "QA_BladeAttacker"}
    profile = {player = player, characterConnections = {}, alive = false, stamina = Config.MaxStamina,
        lastSpend = 0, lastSequence = 0, rateCount = 0, rateWindow = 0, hit = {},
        comboQueued = false, blocking = false, sprinting = false}
    service.profiles[player] = profile
    service:bindCharacter(profile, attacker)

    for _, name in clips do
        run(name .. "_sampled_contact_and_no_double_damage", function()
            local path, action = begin(name), Config.Actions[name]
            local time = (action.active[1] + action.active[2]) / 2
            local a, b = worldBlade(path, time)
            local contact = a:Lerp(b, .70)
            placeTorso(contact)
            sweep(name, time, true)
            near(target.Humanoid.Health, 100 - action.damage, "Authored contact failed")
            assert(profile.hit[target.Humanoid] == true, "Contact not recorded for this action")
            sweep(name, time, true)
            sweep(name, math.min(time + 1 / 60, action.active[2]), false)
            near(target.Humanoid.Health, 100 - action.damage, "Repeated sweep dealt duplicate damage")
            return {sampleTime = time, bladeContact = vector(contact), health = target.Humanoid.Health,
                targetRootDistance = (target.HumanoidRootPart.Position - attacker.HumanoidRootPart.Position).Magnitude}
        end)
        run(name .. "_startup_and_recovery_cannot_hit_contact_fixture", function()
            local path, action = begin(name), Config.Actions[name]
            local time = (action.active[1] + action.active[2]) / 2
            local a, b = worldBlade(path, time)
            placeTorso(a:Lerp(b, .70))
            -- Positive precondition proves this fixture really overlaps a blade.
            assert(Trajectory.query(attacker, a, b, nil, nil, .18)[target.Humanoid], "No positive contact precondition")
            sweep(name, action.active[1] - .001, true)
            sweep(name, action.active[2] + .001, true)
            near(target.Humanoid.Health, 100, "Inactive action dealt damage")
            assert(not profile.hit[target.Humanoid])
            return {beforeActive = action.active[1] - .001, afterActive = action.active[2] + .001, health = 100}
        end)
        run(name .. "_tail_interval_is_processed_after_active_end", function()
            local path, action = begin(name), Config.Actions[name]
            local previous = action.active[2] - 1 / 30
            local contactTime = action.active[2] - 1 / 60
            local a, b = worldBlade(path, contactTime)
            placeTorso(a:Lerp(b, .70))
            assert(Trajectory.query(attacker, a, b, nil, nil, .18)[target.Humanoid], "No actual tail-contact fixture")
            profile.sweepTime, profile.sweepRoot = previous, frame()
            local elapsed = action.active[2] + .01
            sweep(name, elapsed, false)
            near(target.Humanoid.Health, 100 - action.damage, "Final active interval was lost at recovery boundary")
            -- Forgetting hit memory deliberately isolates the processed-window
            -- guard: already-consumed recovery time must not damage a new target.
            target.Humanoid.Health, profile.hit = 100, {}
            sweep(name, elapsed + .10, false)
            near(target.Humanoid.Health, 100, "Processed tail interval was sampled again during recovery")
            assert(not profile.hit[target.Humanoid])
            return {previousElapsed = previous, contactTime = contactTime, currentElapsed = elapsed,
                tailDamage = action.damage, healthAfterProcessedWindow = 100}
        end)
        run(name .. "_whole_active_window_survives_one_update_hitch", function()
            local path, action = begin(name), Config.Actions[name]
            local contactTime = (action.active[1] + action.active[2]) / 2
            local a, b = worldBlade(path, contactTime)
            placeTorso(a:Lerp(b, .70))
            local previous, elapsed = action.active[1] - .10, action.active[2] + .02
            profile.sweepTime, profile.sweepRoot = previous, frame()
            sweep(name, elapsed, false)
            near(target.Humanoid.Health, 100 - action.damage, "Hitch skipped the complete active window")
            assert(profile.hit[target.Humanoid])
            target.Humanoid.Health, profile.hit = 100, {}
            sweep(name, elapsed, false)
            sweep(name, elapsed + .10, false)
            near(target.Humanoid.Health, 100, "Already-processed hitch interval dealt damage again")
            assert(not profile.hit[target.Humanoid])
            return {previousElapsed = previous, currentElapsed = elapsed, contactTime = contactTime,
                hitchDamage = action.damage, healthAfterProcessedWindow = 100}
        end)
        run(name .. "_processed_exact_endpoint_cannot_hit_after_iframes", function()
            local path, action = begin(name), Config.Actions[name]
            local a, b = worldBlade(path, action.active[2])
            placeTorso(a:Lerp(b, .70))
            assert(Trajectory.query(attacker, a, b, nil, nil, .18)[target.Humanoid], "Endpoint fixture has no positive blade contact")
            local iframe = Config.Actions.RollForward.iframes
            local defender = {alive = true, character = target, action = "RollForward",
                started = workspace:GetServerTimeNow() - (iframe[1] + iframe[2]) / 2}
            function service:profileForCharacter(character)
                if character == target then return defender end
                return Service.profileForCharacter(self, character)
            end
            sweep(name, action.active[2], true)
            near(target.Humanoid.Health, 100, "Roll iframe did not reject the first endpoint contact")
            assert(not profile.hit[target.Humanoid], "Iframe rejection consumed a damage hit")
            near(profile.sweepTime, action.active[2], "Exact endpoint was not recorded as processed")
            defender.action = nil
            sweep(name, action.active[2] + .05, false)
            near(target.Humanoid.Health, 100, "Processed exact endpoint was replayed after target iframe ended")
            assert(not profile.hit[target.Humanoid])
            return {processedEndpoint = action.active[2], healthAfterIframeEnded = 100,
                fixture = "Real R15 authored endpoint; isolated defender lookup supplies server roll iframe state"}
        end)
    end

    for _, placement in {
        {name = "far_forward_8_2", offset = Vector3.new(0, 0, -8.2)},
        {name = "behind_attacker", offset = Vector3.new(0, 0, 5)},
        {name = "far_lateral", offset = Vector3.new(8.2, 0, 0)},
    } do
        run(placement.name .. "_all_three_clips_miss", function()
            local health = {}
            for _, name in clips do
                service:finish(profile)
                target.Humanoid.Health = 100
                moveRoot(target, CFrame.new(attacker.HumanoidRootPart.Position + placement.offset))
                begin(name)
                fullActive(name)
                near(target.Humanoid.Health, 100, name .. " hit a negative-position fixture")
                health[name] = target.Humanoid.Health
            end
            return {rootOffset = vector(placement.offset), health = health}
        end)
    end

    run("collidable_wall_blocks_actual_blade_contact", function()
        local name, action = "SwordR1_1", Config.Actions.SwordR1_1
        local path = begin(name)
        local time = (action.active[1] + action.active[2]) / 2
        local a, b = worldBlade(path, time)
        placeTorso(a:Lerp(b, .90))
        -- Restrict this occlusion fixture to one real R15 body part so the ray
        -- cannot choose an alternate exposed hand/head. Other tests use all parts.
        for _, part in target:GetDescendants() do if part:IsA("BasePart") then part.CanQuery = part == target.UpperTorso end end
        sweep(name, time, true)
        near(target.Humanoid.Health, 100 - action.damage, "Unobstructed wall-test precondition failed")
        target.Humanoid.Health, profile.hit = 100, {}
        local candidates = contactCandidates(path, time)
        local reference = candidates[1]
        local displacement = reference.contact - reference.origin
        assert(displacement.Magnitude > .25, "Actual contact ray has insufficient length for the wall fixture")
        local wall = Instance.new("Part")
        wall.Name, wall.Size = "OcclusionWall", Vector3.new(.6, .6, .08)
        wall.Anchored, wall.CanCollide, wall.CanTouch, wall.CanQuery = true, true, false, true
        wall.Parent = extras
        local params, chosen, visibility = visibilityParams(), nil, nil
        -- Isolate the second LOS leg. A large wall can also obstruct root->base,
        -- hiding a broken base->part check behind the first LOS rejection.
        for _, fraction in {.25, .50, .75} do
            local center = reference.origin + displacement * fraction
            wall.CFrame = CFrame.lookAt(center, center + displacement)
            visibility = pathVisibility(candidates, params, wall)
            if visibility.contactBlocked == visibility.count and visibility.rootFree == visibility.count then
                chosen = fraction
                break
            end
        end
        assert(chosen, "Could not isolate contact-ray wall cover while all candidate root-to-origin rays remain clear")
        sweep(name, time, true)
        near(target.Humanoid.Health, 100, "Blade damaged target through a collidable wall")
        assert(not profile.hit[target.Humanoid])
        wall:Destroy()
        sweep(name, time, true)
        near(target.Humanoid.Health, 100 - action.damage, "Removed wall retained damage protection")
        return {blockedHealth = 100, unobstructedHealth = target.Humanoid.Health,
            panelFractionAlongContactRay = chosen, rootToOriginObstructed = false, originToContactObstructed = true,
            candidateVisibility = visibility,
            fixture = "Real UpperTorso only; all actual contact rays blocked and all root-to-origin rays clear are independently verified"}
    end)

    run("blade_base_behind_wall_cannot_attack_visible_target", function()
        local name, action = "SwordR1_1", Config.Actions.SwordR1_1
        local path = begin(name)
        local time = (action.active[1] + action.active[2]) / 2
        local a, b = worldBlade(path, time)
        placeTorso(a:Lerp(b, .70))
        sweep(name, time, true)
        near(target.Humanoid.Health, 100 - action.damage, "Unobstructed hilt-wall precondition failed")
        target.Humanoid.Health, profile.hit = 100, {}
        local candidates = contactCandidates(path, time)
        local body = frame().Position
        local bodyToBase = candidates[1].origin - body
        assert(bodyToBase.Magnitude > .25, "Root-to-blade-base ray is too short for a wall fixture")
        local params = visibilityParams()
        local wall = Instance.new("Part")
        wall.Name, wall.Size = "RootToHiltWallPanel", Vector3.new(.6, .6, .08)
        wall.Anchored, wall.CanCollide, wall.CanTouch, wall.CanQuery = true, true, false, true
        wall.Parent = extras
        local chosen, visibility
        -- Position a real collidable panel across root->base while verifying
        -- base->UpperTorso is unobstructed. This isolates the new first LOS leg.
        for _, fraction in {.25, .50, .75} do
            local center = body + bodyToBase * fraction
            wall.CFrame = CFrame.lookAt(center, center + bodyToBase)
            visibility = pathVisibility(candidates, params, wall)
            if visibility.rootBlocked == visibility.count and visibility.contactFree == visibility.count then
                chosen = fraction
                break
            end
        end
        assert(chosen, "Could not construct a root-blocked/base-visible wall fixture from this actual blade pose")
        sweep(name, time, true)
        near(target.Humanoid.Health, 100, "Hilt beyond a wall attacked a target through the root-to-blade obstruction")
        assert(not profile.hit[target.Humanoid])
        wall:Destroy()
        sweep(name, time, true)
        near(target.Humanoid.Health, 100 - action.damage, "Removing the hilt-wall did not restore contact")
        return {blockedHealth = 100, panelFractionAlongRootRay = chosen, restoredHealth = target.Humanoid.Health,
            rootToOriginObstructed = true, originToContactObstructed = false,
            candidateVisibility = visibility,
            fixture = "Actual R15 blade pose; all root-to-origin rays blocked and all contact rays clear are independently verified"}
    end)

    run("low_wall_blocks_contact_even_when_large_torso_center_is_visible", function()
        local name, action = "SwordR1_1", Config.Actions.SwordR1_1
        local path = begin(name)
        local time = (action.active[1] + action.active[2]) / 2
        local a, b = worldBlade(path, time)
        -- An explicit oversized R15 torso fixture isolates the visible-center /
        -- hidden-contact difference. It is not a claim about a catalog body.
        target.UpperTorso.Size = Vector3.new(2.2, 4.0, 2.2)
        placeTorso(a:Lerp(b, .90) + Vector3.new(0, 1.6, 0))
        for _, part in target:GetDescendants() do if part:IsA("BasePart") then part.CanQuery = part == target.UpperTorso end end
        local candidates = contactCandidates(path, time)
        local reference = candidates[1]
        local displacement = reference.contact - reference.origin
        assert(displacement.Magnitude > .25, "Large torso fixture contains blade origin; no exposed contact-ray segment")
        sweep(name, time, true)
        near(target.Humanoid.Health, 100 - action.damage, "Unobstructed large-torso fixture did not receive real blade contact")
        target.Humanoid.Health, profile.hit = 100, {}
        local wall = Instance.new("Part")
        wall.Name = "LowContactCover"
        wall.Anchored, wall.CanCollide, wall.CanTouch, wall.CanQuery = true, true, false, true
        wall.Parent = extras
        local params, chosen, visibility = visibilityParams(), nil, nil
        for _, height in {.25, .50, 1.0} do
            wall.Size = Vector3.new(4.0, height, .08)
            for _, fraction in {.25, .50, .75} do
                local center = reference.origin + displacement * fraction
                local flat = Vector3.new(displacement.X, 0, displacement.Z)
                assert(flat.Magnitude > .1, "Contact ray is vertical; unsuitable low-wall fixture")
                wall.CFrame = CFrame.lookAt(center, center + flat)
                visibility = pathVisibility(candidates, params, wall)
                if visibility.contactBlocked == visibility.count and visibility.rootFree == visibility.count
                    and visibility.centerFree == visibility.count then
                    chosen = {height = height, fraction = fraction}
                    break
                end
            end
            if chosen then break end
        end
        assert(chosen, "Could not create low cover blocking every actual contact ray while root and torso-center rays stay clear")
        sweep(name, time, true)
        near(target.Humanoid.Health, 100, "Visible torso center bypassed cover hiding the actual blade contact")
        assert(not profile.hit[target.Humanoid])
        wall:Destroy()
        sweep(name, time, true)
        near(target.Humanoid.Health, 100 - action.damage, "Removing low cover did not restore blade contact")
        return {blockedHealth = 100, restoredHealth = target.Humanoid.Health, panel = chosen,
            candidateVisibility = visibility,
            fixture = "Explicit oversized R15 torso; all contact rays blocked, all root/part-center rays clear"}
    end)

    run("accessory_weapon_and_root_proxy_are_not_hurtboxes", function()
        local name, action = "SwordR1_1", Config.Actions.SwordR1_1
        local path = begin(name)
        local time = (action.active[1] + action.active[2]) / 2
        local a, b = worldBlade(path, time)
        local contact = a:Lerp(b, .70)
        -- Intentional proxy-only fixture: the actual R15 body stays parked far
        -- away while only its invisible root, accessory and weapon touch blade.
        target.HumanoidRootPart.CFrame = CFrame.new(contact)
        target.HumanoidRootPart.CanQuery = true
        local accessory = Instance.new("Accessory")
        accessory.Name, accessory.Parent = "QA_OnlyAccessoryContact", target
        table.insert(transient, accessory)
        local handle = Instance.new("Part")
        handle.Name, handle.Size = "Handle", Vector3.one * .5
        handle.Anchored, handle.CanCollide, handle.CanQuery = true, false, true
        handle.CFrame, handle.Parent = CFrame.new(contact), accessory
        local weapon = Instance.new("Model")
        weapon.Name, weapon.Parent = "QA_OnlyWeaponContact", target
        table.insert(transient, weapon)
        local blade = handle:Clone()
        blade.Name, blade.Parent = "WeaponMeshProxy", weapon
        local found = Trajectory.query(attacker, a, b, nil, nil, .18)
        assert(not found[target.Humanoid], "Query treated root/accessory/weapon as an avatar hurtbox")
        sweep(name, time, true)
        near(target.Humanoid.Health, 100, "Proxy-only collision damaged target")
        accessory:Destroy()
        weapon:Destroy()
        return {health = 100, fixture = "Only root/accessory/weapon overlap; real avatar body remains parked away"}
    end)

    run("large_root_jump_cannot_create_damage_ribbon", function()
        local name, action = "SwordR1_1", Config.Actions.SwordR1_1
        local path = begin(name)
        local time = (action.active[1] + action.active[2]) / 2
        local oldTime = time - 1 / 30
        local oldFrame = frame()
        local oldA, oldB = worldBlade(path, oldTime, oldFrame)
        local jump = Vector3.new(12, 0, 0)
        local newFrame = oldFrame + jump
        local newA, newB = worldBlade(path, time, newFrame)
        placeTorso(oldA:Lerp(oldB, .70):Lerp(newA:Lerp(newB, .70), .5))
        -- Positive precondition: naive interpolation across the discontinuity
        -- would actually touch this real R15 body with the real authored path.
        assert(Trajectory.query(attacker, newA, newB, oldA, oldB, .18)[target.Humanoid], "Jump fixture is outside the dangerous interpolation ribbon")
        local rangeAfterJump = (target.HumanoidRootPart.Position - newFrame.Position).Magnitude
        assert(rangeAfterJump <= action.reach + 2, "Jump fixture would be rejected by range alone")
        profile.sweepTime, profile.sweepRoot = oldTime, oldFrame
        moveRoot(attacker, newFrame)
        sweep(name, time, false)
        near(target.Humanoid.Health, 100, "Large root jump created a damage ribbon")
        assert(not profile.hit[target.Humanoid])
        return {jumpDistance = jump.Magnitude, health = 100, targetRootDistanceAfterJump = rangeAfterJump,
            fixture = "Actual R15 source path; explicit discontinuous server root displacement"}
    end)

    run("missing_r15_joint_fails_closed", function()
        local model = Instance.new("Model")
        model.Name, model.Parent = "UnsupportedRig", area
        table.insert(transient, model)
        local part = Instance.new("Part")
        part.Name, part.Anchored, part.CanCollide = "HumanoidRootPart", true, false
        part.CFrame, part.Parent = CFrame.new(origin), model
        model.PrimaryPart = part
        local h = Instance.new("Humanoid")
        h.RequiresNeck, h.BreakJointsOnDeath, h.Parent = false, false, model
        local player = {Name = "QA_UnsupportedRig"}
        local missing = {player = player, characterConnections = {}, hit = {}, stamina = Config.MaxStamina, alive = false}
        service.profiles[player] = missing
        service:bindCharacter(missing, model)
        moveRoot(target, CFrame.new(origin + Vector3.new(0, 0, -4)))
        assert(service:start(missing, "SwordR1_1", workspace:GetServerTimeNow()))
        local action = Config.Actions.SwordR1_1
        service:sweep(missing, "SwordR1_1", (action.active[1] + action.active[2]) / 2, workspace:GetServerTimeNow())
        near(target.Humanoid.Health, 100, "Unsupported rig used a broad hitbox fallback")
        assert(not missing.bladeCache.SwordR1_1 and next(missing.hit) == nil)
        local failure = model:GetAttribute("CombatHitRigError")
        assert(type(failure) == "string" and string.find(failure, "R15 joint"), "Unsupported rig failure was not observable")
        service:removePlayer(player)
        model:Destroy()
        return {health = 100, observedRigError = failure}
    end)
end, debug.traceback)
if not setupOK then
    report.setupFailure = tostring(setupFailure)
    report.failed += 1
end

-- Always run cleanup, including failed async rig setup or a failing test case.
local cleanupOK, cleanupFailure = pcall(function()
    service:destroy()
    assert(next(service.profiles) == nil, "Isolated test profiles survived cleanup")
end)
area:Destroy()
report.cleanup = {status = cleanupOK and "PASS" or "FAIL", fixtureAreaRemoved = area.Parent == nil,
    failure = not cleanupOK and tostring(cleanupFailure) or nil}
if not cleanupOK then report.failed += 1 end
return HttpService:JSONEncode(report)
