-- Temporary Studio multiplayer QA. Requires TWO real Player/client DataModels.
-- Combat uses the participant's native VirtualInput -> production bindings ->
-- CombatRemote. QA RemoteEvent transports schedules and observations only.
-- Explicit test setup resets real players' HP/stamina and optionally anchors
-- roots for reproducible contact; it does not fabricate attacks or damage.
local Run = game:GetService("RunService")
if not Run:IsStudio() or not Run:IsServer() then return end
local Test = game:GetService("StudioTestService")
local args = Test:GetTestArgs()
if type(args) ~= "table" or args.runToken ~= "CombatPvPQA" then return end
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local foundation = game.ReplicatedStorage:WaitForChild("CombatFoundation", 20)
local server = game.ServerScriptService:WaitForChild("CombatFoundation", 20)
local qa = game.ReplicatedStorage:WaitForChild("CombatPvPQA", 20)
local report = {kind = "RealTwoClientCombatQA", lagLabel = args.lagLabel or "unlabelled", testedRevision = args.testedRevision,
    configuredNetwork = args.networkSettings, appliedNetwork = args.appliedNetwork,
    realPlayers = {}, ready = {}, cases = {}, errors = {}, pings = {},
    scope = "Two actual Players. Native client input, actual server acceptance/damage and owner/observer Animator telemetry. Anchored contact fixtures explicitly labelled; free-roll case uses normal character motion.",
    authority = "Production methods delegate without changing returns; setup alone resets HP/stamina/position. No fake Player, combat FireServer or defender-profile override."}
local connections, originalRoots = {}, {}
local Service, Config, Timeline, Trajectory, instance, active, selected
local ready, clientReports = {}, {}
local pendingPings, casesById = {}, {}
local frameNumber, currentFrame = 0, nil
local movingCenter
local closed = false
local originalUpdate, originalStart, originalDamage
local wrappedUpdate, wrappedStart, wrappedDamage
local function now() return workspace:GetServerTimeNow() end
local function vector(v) return {v.X, v.Y, v.Z} end
local function add(list, value) if #list < 3000 then table.insert(list, value) end end
local function restore()
    for _, c in connections do c:Disconnect() end
    table.clear(connections)
    if Service then
        if Service.update == wrappedUpdate then Service.update = originalUpdate end
        if Service.start == wrappedStart then Service.start = originalStart end
        if Service.damage == wrappedDamage then Service.damage = originalDamage end
    end
    for root, data in originalRoots do
        if root.Parent then
            root.Anchored = data.anchored
            if not root.Anchored and data.owner then pcall(function() root:SetNetworkOwner(data.owner) end) end
        end
    end
end
local function finish(errorMessage)
    if closed then return end
    closed = true
    if errorMessage then table.insert(report.errors, tostring(errorMessage)) end
    local restored, restoreFailure = pcall(restore)
    if not restored then table.insert(report.errors, "QA cleanup failed: " .. tostring(restoreFailure)) end
    report.finishedAt = now()
    report.completed = #report.errors == 0
    local ok, encoded = pcall(Http.JSONEncode, Http, report)
    Test:EndTest(ok and encoded or Http:JSONEncode({completed = false, error = tostring(encoded)}))
end
task.delay(210, function() finish("QA hard timeout; no multiplayer completion claim") end)
local function await(predicate, seconds, failure)
    local deadline = os.clock() + seconds
    repeat
        if closed then error("QA already closed") end
        if predicate() then return end
        Run.Heartbeat:Wait()
    until os.clock() > deadline
    error(failure)
end
local function trackHealth(player)
    local function bind(character)
        local h = character:WaitForChild("Humanoid", 10)
        if not h or closed then return end
        local previous = h.Health
        table.insert(connections, h.HealthChanged:Connect(function(health)
            if active and now() >= active.t0 then
                add(active.healthEvents, {at = now(), userId = player.UserId, before = previous, after = health})
            end
            previous = health
        end))
        table.insert(connections, h.Died:Connect(function()
            if active then add(active.deaths, {at = now(), userId = player.UserId}) end
        end))
    end
    table.insert(connections, player.CharacterAdded:Connect(function(character)
        ready[player.UserId] = nil -- Old avatar's cached-track Ready is not valid after respawn.
        bind(character)
    end))
    if player.Character then task.spawn(bind, player.Character) end
end
local function characterReady(player)
    local c = player.Character
    local h, root = c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
    local data = ready[player.UserId]
    return c and h and h.Health > 0 and root and h.RigType == Enum.HumanoidRigType.R15
        and player:HasAppearanceLoaded() and data and (data.tracks or data.count) == 12
        and c:GetAttribute("CombatHitReady") == true
        and (data.virtualInput == true or data.virtualInputAvailable == true)
        and instance and instance.profiles[player] and instance.profiles[player].character == c
end
local function resetCase(case)
    active = nil
    for _, p in selected do
        await(function() return characterReady(p) end, 50, "Real player/appearance/native input not ready: " .. p.Name)
    end
    local center
    if type(args.center) == "table" then center = Vector3.new(args.center[1], args.center[2], args.center[3])
    else center = selected[1].Character.HumanoidRootPart.Position end
    if case.moving then movingCenter=movingCenter or center; center=movingCenter end
    local params = RaycastParams.new()
    params.FilterType, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, true
    params.FilterDescendantsInstances = {selected[1].Character, selected[2].Character}
    local floor = workspace:Raycast(center + Vector3.new(0, 12, 0), Vector3.new(0, -50, 0), params)
    assert(floor and floor.Normal.Y > .85, "Multiplayer fixture needs actual flat arena ground")
    local distance=case.distance or 3.2
    case.setup = {anchored = case.anchored ~= false, rootDistance = distance, moving=case.moving, health = case.hp or 100,
        floor = vector(floor.Position), resets = "Real profile finish + stamina100/lastSpend; HP/pose test fixture reset, no action or damage override",
        lethalHealthFixture = case.expect == "lethal" and "HP1 rather than HP22: ordinary Humanoid regeneration remains enabled; actual pre-frame HP must still be <= the opposing hit damage" or nil}
    for slot, p in selected do
        local c, profile = p.Character, instance.profiles[p]
        local h, root = c.Humanoid, c.HumanoidRootPart
        if not originalRoots[root] then
            local ok, owner = pcall(root.GetNetworkOwner, root)
            originalRoots[root] = {anchored = root.Anchored, owner = ok and owner or nil}
        end
        profile.blocking, profile.sprinting = false, false
        instance:finish(profile)
        profile.stamina, profile.lastSpend = Config.MaxStamina, now()
        c:SetAttribute("Stamina", profile.stamina)
        h.Health = case.hp or h.MaxHealth
        for _, child in c:GetChildren() do if child:IsA("ForceField") then child:Destroy() end end
        local side = slot == 1 and -1 or 1
        if case.roleFlip then side = -side end
        local y = floor.Position.Y + h.HipHeight + root.Size.Y / 2 + .03
        local position = Vector3.new(center.X + side * distance/2, y, center.Z)
        local wanted = CFrame.lookAt(position, Vector3.new(center.X - side * distance/2, y, center.Z))
        root.Anchored = case.setup.anchored
        c:PivotTo(wanted * root.CFrame:Inverse() * c:GetPivot())
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        if not root.Anchored then pcall(function() root:SetNetworkOwner(p) end) end
        case.setup[tostring(p.UserId)] = {rootPosition = vector(root.Position), health = h.Health,
            rootAnchored = root.Anchored, avatarReady = p:HasAppearanceLoaded()}
    end
    task.wait(.20) -- setup replication settles before the future input schedule.
end
local function preFrameSnapshot(self)
    local snapshot = {number = frameNumber, at = now(), players = {},
        geometryScope = "Read-only cached authored current blade segments against actual peer body parts and both visibility rays; no generated hit or production profile mutation"}
    for _, p in selected do
        local profile, character = self.profiles[p], p.Character
        local h = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local action = profile and profile.action
        local row = {userId = p.UserId, health = h and h.Health or 0,
            alive = profile and profile.alive == true and h ~= nil and root ~= nil and h.Health > 0 or false,
            action = action, elapsed = profile and action and snapshot.at - profile.started or nil,
            started = profile and profile.started, rootPosition = root and vector(root.Position), visibleContact = false}
        if active.moving and root then
            local ok,owner=pcall(root.GetNetworkOwner,root)
            row.velocity,row.facing=vector(root.AssemblyLinearVelocity),vector(root.CFrame.LookVector)
            row.anchored,row.networkOwner=root.Anchored,ok and owner and owner.UserId or 0
        end
        snapshot.players[tostring(p.UserId)] = row
    end
    if active.expect ~= "lethal" and not args.capturePreFrameContacts then return snapshot end
    for slot, p in selected do
        local other = selected[3 - slot]
        local profile, targetProfile = self.profiles[p], self.profiles[other]
        local row = snapshot.players[tostring(p.UserId)]
        local targetRow = snapshot.players[tostring(other.UserId)]
        local action = row.action and Config.Actions[row.action]
        row.damage = action and action.damage
        if row.alive and targetRow.alive and action and action.active then
            row.active = Timeline.inWindow(row.action, "active", row.elapsed)
            row.windowUnconsumed = (profile.sweepTime or 0) < action.active[2]
            local targetHumanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
            row.targetHitConsumed = targetHumanoid and profile.hit[targetHumanoid] == true or false
            local path = profile.bladeCache and profile.bladeCache[row.action]
            row.cachedPathAvailable = path ~= nil
            if row.active and row.windowUnconsumed and not row.targetHitConsumed and path then
                local ok, evidence = pcall(function()
                    local root, targetRoot = profile.character.HumanoidRootPart, other.Character.HumanoidRootPart
                    local facing = profile.facing or root.CFrame.LookVector
                    local frame = CFrame.lookAt(root.Position, root.Position + facing)
                    local localA, localB = Trajectory.sample(path, row.elapsed)
                    local a, b = frame:PointToWorldSpace(localA), frame:PointToWorldSpace(localB)
                    local contacts = Trajectory.query(profile.character, a, b, nil, nil, .18)[targetHumanoid] or {}
                    local params = RaycastParams.new()
                    params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, {profile.character, other.Character}, true
                    local distance, visible = (targetRoot.Position - root.Position).Magnitude, false
                    if distance <= action.reach + 2 then
                        for _, candidate in contacts do
                            local bodyRay = workspace:Raycast(frame.Position, candidate.origin - frame.Position, params)
                            local contactRay = workspace:Raycast(candidate.origin, candidate.contact - candidate.origin, params)
                            if not bodyRay and not contactRay then visible = true; break end
                        end
                    end
                    return {count = #contacts, visible = visible, distance = distance}
                end)
                if ok then
                    row.contactCandidates, row.visibleContact, row.distanceToPeer = evidence.count, evidence.visible, evidence.distance
                else row.geometryError = tostring(evidence) end
            end
        end
        row.peerIframeActive = targetProfile and targetProfile.action and Timeline.inWindow(targetProfile.action, "iframes", snapshot.at - targetProfile.started) or false
        row.peerBlocking = targetProfile and targetProfile.blocking == true or false
    end
    return snapshot
end
local function recordLethalFrame(case, snapshot)
    if case.expect ~= "lethal" then return end
    local a = snapshot.players[tostring(selected[1].UserId)]
    local b = snapshot.players[tostring(selected[2].UserId)]
    local eligible = a.alive and b.alive and a.action and a.action == b.action and a.active and b.active
        and a.visibleContact and b.visibleContact and a.windowUnconsumed and b.windowUnconsumed
        and not a.targetHitConsumed and not b.targetHitConsumed and not a.peerIframeActive and not b.peerIframeActive
        and not a.peerBlocking and not b.peerBlocking and a.damage and b.damage and a.health <= b.damage and b.health <= a.damage
    if not eligible then return end
    local damaged, died = {}, {}
    for _, row in case.damageAttempts do
        if row.frameNumber == snapshot.number and row.targetUserId ~= nil and row.before > row.after then
            damaged[row.targetUserId] = true
            if row.before > 0 and row.after <= 0 then died[row.targetUserId] = true end
        end
    end
    local bothDamaged = damaged[selected[1].UserId] and damaged[selected[2].UserId] or false
    local bothDied = died[selected[1].UserId] and died[selected[2].UserId] or false
    add(case.lethalFrames, {frameNumber = snapshot.number, at = snapshot.at, preFrame = snapshot.players,
        bothGeometricallyEligible = true, bothDamaged = bothDamaged, bothDied = bothDied,
        unfairOneSidedResult = not bothDamaged or not bothDied})
end
local function commanded(case, userId)
    for _, command in case.inputs[tostring(userId)] or {} do if command.action == "R1" or command.action == "R2" or command.action:sub(1, 4) == "Roll" then return true end end
    return false
end
local function checkRollInputs(case, checks, failures, inconclusive)
    if not case.checkRollInputs then return end
    local p, other = selected[2], selected[1]
    local owner, observer = case.clients[tostring(p.UserId)], case.clients[tostring(other.UserId)]
    if not owner or not observer then return end
    local roll, rollInput, interrupts = nil, nil, {}
    for _, row in case.started do if row.userId == p.UserId and row.action:sub(1, 4) == "Roll" then roll = row; break end end
    for _, input in owner.inputs or {} do
        if input.action:sub(1, 4) == "Roll" and input.ok then rollInput = input
        elseif (input.action == "R1" or input.action == "R2") and input.ok then table.insert(interrupts, input) end
    end
    checks.realRollInterruptInputs = #interrupts
    if not roll or not rollInput or #interrupts ~= 2 then table.insert(failures, "Expected one actual roll and both native interrupt commands"); return end
    local duration = Config.Actions[roll.action].duration
    local acceptedAttacks, delivered = 0, {}
    for _, row in case.started do
        if row.userId == p.UserId and row.action:sub(1, 5) == "Sword"
            and row.started >= roll.started and row.started < roll.started + duration then acceptedAttacks += 1 end
    end
    checks.attacksAcceptedDuringRoll = acceptedAttacks
    if acceptedAttacks > 0 then table.insert(failures, "Native R1/R2 cancelled or entered during the real server roll") end
    for _, input in interrupts do
        local binding = input.action == "R1" and "CombatR1:Begin" or "CombatR2:Begin"
        for _, event in owner.bindingEvents or {} do
            if event.input == binding and event.at >= input.at - .04 and event.at <= input.at + .30
                and event.at >= rollInput.at and event.at < rollInput.at + duration then delivered[input.action] = true end
        end
    end
    checks.rollInterruptBindingsDelivered = delivered.R1 == true and delivered.R2 == true
    if not checks.rollInterruptBindingsDelivered then table.insert(failures, "Both real interruption commands did not reach the production CAS binding during roll") end
    local lastInput = math.max(interrupts[1].at, interrupts[2].at)
    local ownerFrom, ownerTo = rollInput.at + .12, math.min(lastInput + .12, rollInput.at + duration - .12)
    local reactionAt
    for _, event in owner.events or {} do
        if event.event == "Started" and event.owner == p.Name and (event.name == "Stagger" or event.name == "GuardBroken") then
            reactionAt = reactionAt and math.min(reactionAt, event.at) or event.at
        end
    end
    if reactionAt then ownerTo = math.min(ownerTo, reactionAt - .05); table.insert(inconclusive, "An explicit server reaction shortened the input-exclusivity observation interval") end
    local function continuity(samples, trackField, from, to)
        local count, missing, competing, rewinds, previousTime = 0, 0, 0, 0, nil
        for _, sample in samples or {} do
            if sample.at >= from and sample.at <= to then
                count += 1
                local found
                for _, track in sample[trackField] or {} do
                    if (track.weight or 0) > .05 then
                        if track.name == roll.action then found = track
                        elseif track.name ~= "Stagger" and track.name ~= "GuardBroken" then competing += 1 end
                    end
                end
                if not found then missing += 1
                else
                    if previousTime and found.time < previousTime - 1 / 15 then rewinds += 1 end
                    previousTime = found.time
                end
            end
        end
        return {samples = count, missingRoll = missing, competingActions = competing, backwardsTimeJumps = rewinds, from = from, to = to}
    end
    checks.ownerRollContinuity = continuity(owner.samples, "own", ownerFrom, ownerTo)
    local peerFirst
    for _, sample in observer.samples or {} do
        for _, track in sample.peer or {} do
            if track.name == roll.action and (track.weight or 0) > .05 then peerFirst = sample.at; break end
        end
        if peerFirst then break end
    end
    checks.peerRollContinuity = peerFirst and continuity(observer.samples, "peer", peerFirst + .05, roll.started + duration - .12) or {samples = 0}
    for _, key in {"ownerRollContinuity", "peerRollContinuity"} do
        local result = checks[key]
        if result.samples < 2 then table.insert(inconclusive, "Too few actual weighted roll frames for " .. key)
        elseif result.missingRoll > 0 or result.competingActions > 0 or result.backwardsTimeJumps > 0 then
            table.insert(failures, "Roll interruption/competitor/rewind in sampled native " .. key)
        end
    end
end
local function motionSnapshot(profile, character)
    local names = {CombatAdvanceVelocity = true, CombatAdvanceAttachment = true, CombatRollVelocity = true, CombatRollAttachment = true}
    local found = {}
    if character and character.Parent then
        for _, item in character:GetDescendants() do if names[item.Name] then table.insert(found, item.Name) end end
    end
    return {action = profile and profile.action, alive = profile and profile.alive,
        state = character and character:GetAttribute("CombatState"), characterRemoved = not character or character.Parent == nil,
        motionVelocity = profile and profile.motionVelocity ~= nil or false,
        motionAttachment = profile and profile.motionAttachment ~= nil or false, motionInstances = found}
end
local function inspectLethalLifecycle(case, characters)
    if case.expect ~= "lethal" then return end
    case.lifecycle = {}
    local killed = {}
    for _, row in case.damageAttempts do if row.targetUserId and row.before > 0 and row.after <= 0 then killed[row.targetUserId] = true end end
    for _, p in selected do
        if killed[p.UserId] then
            local fixture = characters[p.UserId]
            local old = fixture.character
            local profile = instance.profiles[p]
            local oldIsCurrent = profile.character == old
            local entry = {userId = p.UserId, death = motionSnapshot(oldIsCurrent and profile or nil, old), oldWasCurrentAtCapture = oldIsCurrent}
            entry.deathClean = #entry.death.motionInstances == 0 and (not oldIsCurrent or
                (profile.alive == false and profile.action == nil and not entry.death.motionVelocity and not entry.death.motionAttachment
                    and (entry.death.state == "Dead" or entry.death.characterRemoved)))
            local readyOK, readyFailure = pcall(function()
                await(function() return p.Character ~= old and characterReady(p) end, 35, "Actual new R15 avatar did not become ready after death: " .. p.Name)
            end)
            entry.ready = readyOK
            if not readyOK then entry.error = tostring(readyFailure)
            else
                profile = instance.profiles[p]
                entry.respawn = motionSnapshot(profile, p.Character)
                entry.respawn.health, entry.respawn.stamina = p.Character.Humanoid.Health, profile.stamina
                entry.respawn.identityChanged = p.Character ~= old
                entry.respawn.hitReady = p.Character:GetAttribute("CombatHitReady")
                entry.respawn.clientReady = ready[p.UserId]
                entry.oldConnectionsDisconnected = true
                for _, connection in fixture.connections do if connection.Connected then entry.oldConnectionsDisconnected = false end end
                entry.respawnClean = entry.respawn.identityChanged and entry.respawn.health > 0 and profile.alive
                    and profile.action == nil and #entry.respawn.motionInstances == 0 and not entry.respawn.motionVelocity
                    and not entry.respawn.motionAttachment and entry.oldConnectionsDisconnected
            end
            add(case.lifecycle, entry)
        end
    end
end
local function checkMoving(case,checks,failures,inconclusive)
    if not case.moving then return end
    checks.movingActors={}
    for _,p in selected do
        local stats={serverPath=0,clientPath=0,serverFrames=0,clientFrames=0,
            anchoredFrames=0,wrongOwnerFrames=0,lockFrames=0,maxRootRise=0}
        local previous
        for _,frame in case.motionSamples or {} do
            local row=frame.players[tostring(p.UserId)]
            if row and row.rootPosition then
                local position=Vector3.new(table.unpack(row.rootPosition))
                if previous then local delta=position-previous;stats.serverPath+=Vector3.new(delta.X,0,delta.Z).Magnitude end
                previous=position
                stats.maxRootRise=math.max(stats.maxRootRise,position.Y-case.setup[tostring(p.UserId)].rootPosition[2])
                stats.serverFrames+=1
                if row.anchored then stats.anchoredFrames+=1 end
                if row.networkOwner~=p.UserId then stats.wrongOwnerFrames+=1 end
            end
        end
        previous=nil
        local payload=case.clients[tostring(p.UserId)]
        for _,row in payload and payload.samples or {} do
            if row.at>=case.t0 and row.position then
                local position=Vector3.new(table.unpack(row.position))
                if previous then local delta=position-previous;stats.clientPath+=Vector3.new(delta.X,0,delta.Z).Magnitude end
                previous=position
                stats.clientFrames+=1
                if row.anchored then stats.anchoredFrames+=1 end
                if row.lockActive then stats.lockFrames+=1 end
            end
        end
        checks.movingActors[tostring(p.UserId)]=stats
        if stats.serverFrames<10 or stats.clientFrames<10 then table.insert(inconclusive,"Insufficient actual moving-player position telemetry: "..p.Name)
        elseif stats.anchoredFrames>0 or stats.wrongOwnerFrames>0 then table.insert(failures,"Moving player was anchored or did not retain client network ownership: "..p.Name)
        elseif stats.serverPath<1 or stats.clientPath<1 then table.insert(failures,"Both real players must actually move over one stud: "..p.Name) end
        if case.requireGrounded and stats.maxRootRise>2 then table.insert(failures,"Grounded close exchange lifted a root over two studs without jump input: "..p.Name) end
    end
    if case.expect=="miss" or case.expect=="dodge" or case.expect=="reject" then
        local damage=0
        for _,row in case.damageAttempts do if row.after<row.before then damage+=row.before-row.after end end
        checks.totalActualDamage=damage
        if damage>0 then table.insert(failures,"The scheduled moving miss/dodge took actual damage; inspect geometry and timing") end
    end
    if case.requireRoll then
        checks.realMovingRoll=false
        for _,row in case.started do
            if row.userId==selected[2].UserId and row.action:sub(1,4)=="Roll" then checks.realMovingRoll=true end
        end
        if not checks.realMovingRoll then table.insert(failures,"Moving defender's native roll was not server-approved") end
    end
    if case.expect=="reject" then
        local owner=case.clients[tostring(selected[1].UserId)]
        local sequence,rejected,resumed
        for _,row in case.received do if row.userId==selected[1].UserId and row.kind=="R1" then sequence=row.sequence end end
        for _,row in owner.events do if row.event=="Rejected" and row.owner==sequence then rejected=row.at end end
        checks.actualAttackRejected=sequence~=nil and rejected~=nil
        if not checks.actualAttackRejected then table.insert(inconclusive,"Native block/attack schedule did not establish an actual sequenced rejection") end
        for _,row in owner.samples do
            if rejected and row.at>rejected+.05 and row.walkSpeed and row.walkSpeed>0 and row.movementSuppressed==false
                and row.moveDirection and Vector3.new(table.unpack(row.moveDirection)).Magnitude>.1 then resumed=(resumed or 0)+1 end
        end
        checks.movementResumedAfterRejection=resumed or 0
        if checks.actualAttackRejected and (resumed or 0)<2 then table.insert(failures,"Server rejection left locomotion suppressed") end
    end
    checks.actualHitVisuals={}
    for _,hit in case.damageAttempts do
        if hit.after>=hit.before or not hit.targetUserId then continue end
        local proof={action=hit.action,at=hit.at,attacker=hit.attackerUserId,target=hit.targetUserId,views={}}
        for _,view in {{hit.attackerUserId,"own"},{hit.targetUserId,"peer"}} do
            local payload=case.clients[tostring(view[1])]
            local row={userId=view[1],view=view[2],frames=0,contacts=0}
            for _,frame in payload and payload.visualFrames or {} do
                if frame.action==hit.action and frame.view==view[2] and math.abs(frame.at-hit.at)<=.15 then
                    row.frames+=1
                    if frame.blade and frame.blade.visible then
                        row.contacts+=1
                        local delta=frame.at-hit.at
                        if not row.nearestDelta or math.abs(delta)<math.abs(row.nearestDelta) then row.nearestDelta=delta end
                    end
                end
            end
            table.insert(proof.views,row)
            if row.frames<2 then table.insert(inconclusive,"Insufficient actual blade/body-box frames around moving hit")
            elseif row.contacts==0 then table.insert(failures,"Moving server damage had no nearby rendered blade/body-box contact on "..row.view.." view") end
        end
        table.insert(checks.actualHitVisuals,proof)
    end
    if case.requirePredictedStop then
        local owner=case.clients[tostring(selected[1].UserId)]
        local input,ack
        for _,row in owner.inputs do if row.action=="R1" then input=row.at;break end end
        for _,row in owner.events do if row.event=="Started" and row.owner==selected[1].Name and row.name=="SwordR1_1" then ack=row.at;break end end
        local stats={samples=0,walkingSamples=0,fastFacingSamples=0}
        for _,row in owner.samples do
            if input and ack and row.at>=input+.06 and row.at<ack-.02 then
                local active=false
                for _,track in row.own do if track.name=="SwordR1_1" and track.weight>.05 then active=true end end
                if not active then continue end
                stats.samples+=1
                if (row.walkSpeed or 0)>.01 or (row.moveDirection and Vector3.new(table.unpack(row.moveDirection)).Magnitude>.01) then stats.walkingSamples+=1 end
                if row.facingMaxAngular and row.facingMaxAngular>math.rad(Config.Actions.SwordR1_1.turnRate)+.01 then stats.fastFacingSamples+=1 end
            end
        end
        checks.predictedStartupMovement=stats
        if stats.samples==0 then table.insert(inconclusive,"No sampled pre-acknowledgement startup interval")
        elseif stats.walkingSamples>0 or stats.fastFacingSamples>0 then table.insert(failures,"Predicted startup retained locomotion or the idle lock-on turn limit before acknowledgement") end
        if case.requireResume then
            local resumed=0
            for _,row in owner.samples do
                if input and row.at>input+Config.Actions.SwordR1_1.duration+.8 and row.walkSpeed and row.walkSpeed>0
                    and row.movementSuppressed==false and row.moveDirection and Vector3.new(table.unpack(row.moveDirection)).Magnitude>.1 then resumed+=1 end
            end
            checks.resumedLocomotionSamples=resumed
            if resumed<2 then table.insert(failures,"Held movement did not resume after the completed action") end
        end
    end
end
local function assess(case)
    local checks, failures, inconclusive = {}, {}, {}
    checks.actualEchoReplies = #case.pings
    if #case.pings < 2 then table.insert(inconclusive, "Actual QA echo round trips were not recorded for both real clients") end
    if #case.instrumentationErrors > 0 then table.insert(inconclusive, "Passive pre-frame instrumentation had errors; inspect recorded observation failures") end
    local startsById, damageById = {}, {}
    for _, row in case.started do
        startsById[row.userId] = (startsById[row.userId] or 0) + 1
    end
    for _, row in case.damageAttempts do
        if row.after < row.before and row.targetUserId ~= nil then
            damageById[row.targetUserId] = (damageById[row.targetUserId] or 0) + row.before - row.after
        end
    end
    for _, p in selected do
        local payload = case.clients[tostring(p.UserId)]
        if not payload then table.insert(failures, "No actual client report: " .. p.Name)
        elseif payload.error then table.insert(failures, "Client harness: " .. p.Name .. " " .. tostring(payload.error))
        else
            for _, input in payload.inputs or {} do if not input.ok then table.insert(failures, "Native input failed: " .. p.Name .. " " .. tostring(input.error)) end end
            if case.expect~="reject" and commanded(case, p.UserId) and not startsById[p.UserId] then table.insert(failures, "Native commands produced no server-approved action: " .. p.Name) end
        end
    end
    local perAction = {}
    for _, row in case.damageAttempts do
        if row.after < row.before then
            local key = tostring(row.attackerUserId) .. ":" .. tostring(row.action) .. ":" .. tostring(row.started) .. ":" .. tostring(row.targetKey)
            perAction[key] = (perAction[key] or 0) + 1
        end
    end
    local once = true
    for _, count in perAction do if count > 1 then once = false end end
    checks.damageOncePerAction = once
    if not once then table.insert(failures, "An approved action damaged its target more than once") end
    if case.expect == "a_hits_b" or case.expect == "b_hits_a" then
        local targetPlayer = case.expect == "a_hits_b" and selected[2] or selected[1]
        checks.actualPlayerDamage = (damageById[targetPlayer.UserId] or 0) > 0
        if not checks.actualPlayerDamage then table.insert(failures, "No server-confirmed hit on the other real player") end
    elseif case.expect == "both_hit" then
        checks.twoWayDamage = (damageById[selected[1].UserId] or 0) > 0 and (damageById[selected[2].UserId] or 0) > 0
        if not checks.twoWayDamage then table.insert(failures, "Simultaneous fixture did not confirm hits in both directions") end
    elseif case.expect == "iframe" then
        local protected = 0
        for _, row in case.damageAttempts do
            if row.targetUserId == selected[2].UserId and row.defenderAction and row.defenderAction:sub(1, 4) == "Roll"
                and Timeline.inWindow(row.defenderAction, "iframes", row.defenderElapsed) then
                protected += 1
                if row.after < row.before then table.insert(failures, "Actual contact damaged during server iframe window") end
            end
        end
        checks.confirmedProtectedContacts = protected
        if protected == 0 then table.insert(inconclusive, "Roll produced no geometrically confirmed contact inside server iframes") end
    elseif case.expect == "lethal" then
        checks.actualDeaths = #case.deaths
        if #case.deaths == 0 then table.insert(failures, "No lethal contact between real players") end
        checks.confirmedSameFrameLethalContacts = #case.lethalFrames
        if #case.lethalFrames == 0 then
            table.insert(inconclusive, "No pre-frame snapshot proved both alive, active, visible/unconsumed contacts and opposing lethal damage in the same update")
        else
            for _, frame in case.lethalFrames do
                if frame.unfairOneSidedResult then
                    table.insert(failures, "Both real players had visible lethal contacts before update, but only one side damaged/died in frame " .. frame.frameNumber)
                end
            end
        end
    elseif case.expect == "free_roll" then
        local payload = case.clients[tostring(selected[2].UserId)]
        if payload and payload.startPosition and payload.endPosition then
            local a, b = payload.startPosition, payload.endPosition
            local distance = Vector3.new(b[1] - a[1], 0, b[3] - a[3]).Magnitude
            checks.realRollDistance = distance
            if distance < 2 then table.insert(failures, "Unanchored real roll did not move character") end
        else table.insert(failures, "Free-roll client movement telemetry missing") end
    end
    if case.id == "r1_combo_a" then
        local first, second = false, false
        for _, row in case.damageAttempts do
            if row.attackerUserId == selected[1].UserId and row.after < row.before then
                if row.action == "SwordR1_1" then first = true elseif row.action == "SwordR1_2" then second = true end
            end
        end
        checks.realComboBothHits = first and second
        if not checks.realComboBothHits then table.insert(failures, "Native combo did not confirm both distinct server-authoritative strikes") end
    end
    if case.id == "roll_late_b" then
        local rollTime, firstDamage
        for _, row in case.started do if row.userId == selected[2].UserId and row.action:sub(1, 4) == "Roll" then rollTime = row.started; break end end
        for _, row in case.damageAttempts do if row.targetUserId == selected[2].UserId and row.after < row.before then firstDamage = firstDamage and math.min(firstDamage, row.at) or row.at end end
        checks.rollAcceptedAfterActualDamage = rollTime and firstDamage and rollTime > firstDamage or false
        if not checks.rollAcceptedAfterActualDamage then table.insert(inconclusive, "Late-roll fixture did not prove server acceptance occurred after actual damage") end
    end
    if case.id:find("simultaneous") or case.expect == "lethal" then
        local first = {}
        for _, row in case.started do if not first[row.userId] then first[row.userId] = row.started end end
        if first[selected[1].UserId] and first[selected[2].UserId] then
            local skew = math.abs(first[selected[1].UserId] - first[selected[2].UserId])
            checks.approvedStartSkewSeconds = skew
            if skew > 1 / Config.HitSampleRate then table.insert(inconclusive, "Server-approved starts differed by more than one hit-simulation step") end
        else table.insert(inconclusive, "Both simultaneous server-approved start times were not recorded") end
    end
    -- Observer playback is proved by frames, never by a Started packet alone.
    local observer, ownerPlayback = true, true
    for slot, p in selected do
        local other = selected[3 - slot]
        if startsById[other.UserId] then
            local expected = {}
            for _, row in case.started do if row.userId == other.UserId then expected[row.action] = {} end end
            local owner = case.clients[tostring(other.UserId)]
            for _, sample in owner and owner.samples or {} do
                for _, track in sample.own or {} do
                    if expected[track.name] and (track.weight or 0) > .05 then expected[track.name][track.id] = true end
                end
            end
            for semantic, ids in expected do
                if next(ids) == nil then
                    ownerPlayback = false
                    table.insert(failures, "Approved clip had no weighted owner playback: " .. other.Name .. " " .. semantic)
                end
                local seen = false
                local payload = case.clients[tostring(p.UserId)]
                for _, sample in payload and payload.samples or {} do
                    for _, track in sample.peer or {} do
                        if (track.weight or 0) > .05 and (track.name == semantic or ids[track.id]) then seen = true end
                    end
                end
                if not seen then observer = false; table.insert(failures, "Approved opponent clip not observed as matching weighted native track: " .. p.Name .. " " .. semantic) end
            end
        end
    end
    checks.observerNativeTracks, checks.ownerNativeTracks = observer, ownerPlayback
    local duplicateSamples = {own = 0, peer = 0}
    local maxWeighted = {own = 0, peer = 0}
    local duplicateExamples = {}
    for _, p in selected do
        local payload = case.clients[tostring(p.UserId)]
        for _, sample in payload and payload.samples or {} do
            for _, group in {"own", "peer"} do
                local byId, duplicate = {}, false
                for _, track in sample[group] or {} do
                    if type(track.id) == "string" and track.id ~= "" and (track.weight or 0) > .05 then
                        byId[track.id] = (byId[track.id] or 0) + 1
                        maxWeighted[group] = math.max(maxWeighted[group], byId[track.id])
                        if byId[track.id] > 1 then duplicate = true end
                    end
                end
                if duplicate then
                    duplicateSamples[group] += 1
                    if #duplicateExamples < 8 then table.insert(duplicateExamples, {observerUserId = p.UserId, at = sample.at, group = group, weightedCountsByExactId = byId}) end
                end
            end
        end
    end
    checks.ownerDuplicateTrackSamples, checks.observerDuplicateTrackSamples = duplicateSamples.own, duplicateSamples.peer
    checks.maximumOwnerWeightedTracksPerId, checks.maximumObserverWeightedTracksPerId = maxWeighted.own, maxWeighted.peer
    checks.duplicateTrackExamples = duplicateExamples
    if duplicateSamples.own > 0 or duplicateSamples.peer > 0 then
        table.insert(failures, "Simultaneous weighted tracks share an exact nonempty asset ID; native/manual animation duplication observed")
    end
    local fullFrames = {own = 0, peer = 0, ownDuplicates = 0, peerDuplicates = 0, ownMax = 0, peerMax = 0}
    local fullFrameEvidence = true
    for _, p in selected do
        local payload = case.clients[tostring(p.UserId)]
        local animationFrames = payload and payload.animationFrames
        if not animationFrames or not animationFrames.own or not animationFrames.peer then
            fullFrameEvidence = false
        else
            for _, group in {"own", "peer"} do
                local counters = animationFrames[group]
                if type(counters.frames) ~= "number" or counters.frames <= 0
                    or type(counters.duplicateFrames) ~= "number" or type(counters.maxPerId) ~= "number"
                    or counters.duplicateFrames < 0 or counters.duplicateFrames > counters.frames or counters.maxPerId < 0 then
                    fullFrameEvidence = false
                else
                    fullFrames[group] += counters.frames
                    fullFrames[group .. "Duplicates"] += counters.duplicateFrames
                    fullFrames[group .. "Max"] = math.max(fullFrames[group .. "Max"], counters.maxPerId)
                end
            end
        end
    end
    checks.ownerAnimationFrames, checks.observerAnimationFrames = fullFrames.own, fullFrames.peer
    checks.ownerAnimationDuplicateFrames, checks.observerAnimationDuplicateFrames = fullFrames.ownDuplicates, fullFrames.peerDuplicates
    checks.maximumOwnerWeightedPerIdAllAnimationFrames, checks.maximumObserverWeightedPerIdAllAnimationFrames = fullFrames.ownMax, fullFrames.peerMax
    checks.fullAnimationFrameEvidence = fullFrameEvidence
    if not fullFrameEvidence then table.insert(inconclusive, "Every-PreSimulation owner/observer duplicate counters are missing or have no frames") end
    if fullFrames.ownDuplicates > 0 or fullFrames.peerDuplicates > 0 or fullFrames.ownMax > 1 or fullFrames.peerMax > 1 then
        table.insert(failures, "Duplicate weighted animation IDs occurred in actual owner/observer PreSimulation frames")
    end
    checkRollInputs(case, checks, failures, inconclusive)
    checkMoving(case, checks, failures, inconclusive)
    if case.expect == "lethal" then
        checks.deathRespawnCleanup = case.lifecycle and #case.lifecycle > 0 or false
        for _, entry in case.lifecycle or {} do
            if not entry.deathClean or not entry.ready or not entry.respawnClean then
                checks.deathRespawnCleanup = false
                table.insert(failures, "Actual death/respawn combat cleanup failed for user " .. entry.userId)
            end
        end
        if not checks.deathRespawnCleanup and #failures == 0 then table.insert(inconclusive, "No actual killed-player lifecycle observation available") end
    end
    case.checks, case.failures, case.inconclusive = checks, failures, inconclusive
    case.status = #failures > 0 and "FAIL" or (#inconclusive > 0 and "INCONCLUSIVE" or "PASS")
end

local ok, failure = xpcall(function()
    assert(foundation and server and qa and qa:IsA("RemoteEvent"), "QA installer or production foundation missing")
    Config = require(foundation.Shared.CombatConfig)
    Timeline = require(foundation.Shared.ActionTimeline)
    Trajectory = require(server.BladeTrajectory)
    Service = require(server.CombatService)
    report.pacingVersion = Config.PacingVersion
    originalUpdate, originalStart, originalDamage = Service.update, Service.start, Service.damage
    wrappedUpdate = function(self, ...)
        instance = self
        frameNumber += 1
        local case = active
        local snapshot
        if case and selected and now() >= case.t0 then
            local snapshotOK, value = pcall(preFrameSnapshot, self)
            if snapshotOK then
                snapshot = value
                currentFrame = snapshot
                if case.expect == "lethal" or args.capturePreFrameAll then add(case.preFrames, snapshot) end
                if case.moving and frameNumber%2==0 then add(case.motionSamples,snapshot) end
            else
                currentFrame = nil
                add(case.instrumentationErrors, {at = now(), frameNumber = frameNumber, error = tostring(value)})
            end
        else currentFrame = nil end
        local result = table.pack(originalUpdate(self, ...))
        if snapshot and active == case then recordLethalFrame(case, snapshot) end
        return table.unpack(result, 1, result.n)
    end
    wrappedStart = function(self, profile, action, started, ...)
        instance = self
        local result = table.pack(originalStart(self, profile, action, started, ...))
        if active and result[1] then add(active.started, {at = now(), userId = profile.player.UserId, action = action, started = started,
            rootPosition=active.moving and vector(profile.character.HumanoidRootPart.Position)}) end
        return table.unpack(result, 1, result.n)
    end
    wrappedDamage = function(self, attackerProfile, humanoid, action, time, ...)
        local target = Players:GetPlayerFromCharacter(humanoid.Parent)
        local defender = target and self.profiles[target]
        local before, start = humanoid.Health, attackerProfile.started
        local defenderAction, elapsed = defender and defender.action, defender and (time - defender.started)
        local result = table.pack(originalDamage(self, attackerProfile, humanoid, action, time, ...))
        if active then add(active.damageAttempts, {at = now(), attackerUserId = attackerProfile.player.UserId,
            targetUserId = target and target.UserId, action = action, started = start, before = before, after = humanoid.Health,
            targetKey = target and tostring(target.UserId) or humanoid.Parent:GetFullName(),
            defenderAction = defenderAction, defenderElapsed = elapsed, returned = result[1] == true,
            frameNumber = currentFrame and currentFrame.number or frameNumber,
            attackerPosition=active.moving and vector(attackerProfile.character.HumanoidRootPart.Position),
            targetPosition=active.moving and vector(humanoid.Parent.HumanoidRootPart.Position),
            preFrame = currentFrame and currentFrame.players or nil}) end
        return table.unpack(result, 1, result.n)
    end
    Service.update, Service.start, Service.damage = wrappedUpdate, wrappedStart, wrappedDamage
    table.insert(connections, qa.OnServerEvent:Connect(function(player, kind, id, payload)
        if kind == "Ready" and type(id) == "table" then ready[player.UserId] = id; report.ready[tostring(player.UserId)] = id
        elseif kind == "Pong" and type(id) == "number" and type(payload) == "number" then
            local pending = pendingPings[player.UserId]
            local caseId = pending and pending[id]
            if caseId then
                pending[id] = nil
                local received = now()
                local ping = {userId = player.UserId, sent = id, clientReceived = payload, returned = received,
                    roundTripSeconds = received - id, caseId = caseId,
                    scope = "Actual QA RemoteEvent echo; includes engine scheduling/simulation, not claimed pure transport delay"}
                add(report.pings, ping)
                local case = casesById[caseId]
                if case then add(case.pings, ping) end
            end
        elseif kind == "Report" and type(id) == "string" and type(payload) == "table" then
            clientReports[id] = clientReports[id] or {}
            clientReports[id][tostring(player.UserId)] = payload
        end
    end))
    table.insert(connections, foundation.CombatRemote.OnServerEvent:Connect(function(player, request)
        if active and type(request) == "table" then
            add(active.received, {at = now(), userId = player.UserId, kind = request.kind,
                sequence = request.sequence, direction = request.direction})
        end
    end))
    await(function() return #Players:GetPlayers() == 2 and instance ~= nil end, 60, "Expected exactly two actual Players and running combat service")
    selected = Players:GetPlayers()
    table.sort(selected, function(a, b) return a.Name < b.Name end)
    for _, p in selected do
        trackHealth(p)
        table.insert(report.realPlayers, {name = p.Name, userId = p.UserId})
    end
    await(function()
        for _, p in selected do
            local data = ready[p.UserId]
            assert(not data or (data.virtualInput ~= false and data.virtualInputAvailable ~= false),
                "Native client VirtualInput unavailable: " .. p.Name .. " " .. tostring(data and data.error))
        end
        return characterReady(selected[1]) and characterReady(selected[2])
    end, 65, "Both real clients must report twelve tracks and native VirtualInput")
    local a, b = tostring(selected[1].UserId), tostring(selected[2].UserId)
    local function commands(first, second) return {[a] = first or {}, [b] = second or {}} end
    local cases = {
        {id = "r1_from_a", inputs = commands({{action = "R1", at = 0}}), expect = "a_hits_b"},
        {id = "r1_from_b", inputs = commands(nil, {{action = "R1", at = 0}}), expect = "b_hits_a"},
        {id = "r2_from_a", inputs = commands({{action = "R2", at = 0}}), expect = "a_hits_b"},
        {id = "r2_from_b", inputs = commands(nil, {{action = "R2", at = 0}}), expect = "b_hits_a"},
        {id = "r1_combo_a", inputs = commands({{action = "R1", at = 0}, {action = "R1", at = .84}}), expect = "a_hits_b"},
        {id = "simultaneous_r1", inputs = commands({{action = "R1", at = 0}}, {{action = "R1", at = 0}}), expect = "both_hit"},
        {id = "simultaneous_r2", inputs = commands({{action = "R2", at = 0}}, {{action = "R2", at = 0}}), expect = "both_hit"},
        {id = "simultaneous_r1_r2", inputs = commands({{action = "R1", at = 0}}, {{action = "R2", at = 0}}), expect = "both_hit"},
        {id = "roll_inside_b", inputs = commands({{action = "R1", at = 0}}, {{action = "Roll", at = .23}}), expect = "iframe"},
        {id = "roll_early_b", inputs = commands({{action = "R1", at = .40}}, {{action = "Roll", at = 0}}), expect = "a_hits_b"},
        {id = "roll_late_b", inputs = commands({{action = "R1", at = 0}}, {{action = "Roll", at = .95}}), expect = "a_hits_b"},
        {id = "free_roll_b", anchored = false, inputs = commands(nil, {{action = "Roll", at = 0}}), expect = "free_roll"},
        {id = "free_roll_backward_b", anchored = false, checkRollInputs = true,
            inputs = commands(nil, {{action = "RollBackward", at = 0}, {action = "R1", at = .32}, {action = "R2", at = .50}}), expect = "free_roll"},
        {id = "roll_inputs_b", checkRollInputs = true, inputs = commands({{action = "R1", at = 0}},
            {{action = "Roll", at = .23}, {action = "R1", at = .50}, {action = "R2", at = .73}}), expect = "iframe"},
        {id = "lethal_r1_ab", hp = 1, inputs = commands({{action = "R1", at = 0}}, {{action = "R1", at = 0}}), expect = "lethal"},
        {id = "lethal_r1_ba", hp = 1, roleFlip = true, inputs = commands({{action = "R1", at = 0}}, {{action = "R1", at = 0}}), expect = "lethal"},
    }
    if type(args.movingCases)=="table" then
        cases={}
        report.scope="Two actual moving Players, native held movement/combat inputs, native camera/lock-on, unanchored client-owned roots. Setup positions reset only before the future input schedule."
        for _,definition in args.movingCases do
            local case=table.clone(definition)
            case.moving,case.anchored=true,false
            case.inputs=commands(case.first,case.second)
            case.first,case.second=nil,nil
            table.insert(cases,case)
        end
    end
    local chosen = {}
    for _, id in type(args.cases) == "table" and args.cases or {} do chosen[id] = true end
    for _, case in cases do
        if (not args.probe or case.id == "r1_from_a") and (next(chosen) == nil or chosen[case.id]) then
            resetCase(case)
            local testCharacters = {}
            for _, p in selected do
                local fixture = {character = p.Character, connections = {}}
                for _, connection in instance.profiles[p].characterConnections do table.insert(fixture.connections, connection) end
                testCharacters[p.UserId] = fixture
            end
            case.label, case.t0, case.duration = case.id, now() + 2, case.duration or (case.id == "simultaneous_r2" and 3.6 or 3.2)
            case.started, case.received, case.damageAttempts, case.healthEvents, case.deaths = {}, {}, {}, {}, {}
            case.clients, case.preFrames, case.lethalFrames, case.pings, case.instrumentationErrors,case.motionSamples = {}, {}, {}, {}, {},{}
            casesById[case.id] = case
            active = case
            for slot, p in selected do
                local pingOK, ping = pcall(p.GetNetworkPing, p)
                case.setup[tostring(p.UserId)].networkPingSeconds = pingOK and ping or nil
                case.setup[tostring(p.UserId)].clientReady = ready[p.UserId]
                local pingTime = now()
                pendingPings[p.UserId] = pendingPings[p.UserId] or {}
                pendingPings[p.UserId][pingTime] = case.id
                qa:FireClient(p, "Ping", pingTime)
                qa:FireClient(p, "Case", {id = case.id, label = case.label, t0 = case.t0, duration = case.duration,
                    inputs = case.inputs[tostring(p.UserId)], other = selected[3 - slot].Name, setup = case.setup,moving=case.moving})
            end
            await(function()
                local rows = clientReports[case.id]
                return rows and rows[a] and rows[b]
            end, 16, "Both real client reports not received for " .. case.id)
            case.clients = clientReports[case.id]
            case.finalHealth = {[a] = selected[1].Character and selected[1].Character.Humanoid.Health,
                [b] = selected[2].Character and selected[2].Character.Humanoid.Health}
            active = nil
            inspectLethalLifecycle(case, testCharacters)
            assess(case)
            table.insert(report.cases, case)
            active = nil
        end
    end
    assert(#report.cases > 0, "No selected multiplayer cases executed")
    report.summary = {passed = 0, failed = 0, inconclusive = 0}
    for _, case in report.cases do
        local key = case.status == "PASS" and "passed" or (case.status == "FAIL" and "failed" or "inconclusive")
        report.summary[key] += 1
    end
end, debug.traceback)
finish(not ok and failure or nil)
