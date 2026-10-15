local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CombatFoundation"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CombatConfig"))
local Timeline = require(Shared:WaitForChild("ActionTimeline"))
local BladeTrajectory = require(script.Parent:WaitForChild("BladeTrajectory"))

local CombatService = {}
CombatService.__index = CombatService

local ROLL_DIRECTIONS = {RollForward = true, RollBackward = true, RollLeft = true, RollRight = true}
local ATTACKS = {SwordR1_1 = true, SwordR1_2 = true, SwordR2 = true}

local function living(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return humanoid and humanoid.Health > 0 and root and humanoid, root
end

local function horizontalUnit(vector)
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 1e-4 and flat.Unit or Vector3.new(0, 0, -1)
end

local function planarMotion(root, name, maxForce)
    local attachment = Instance.new("Attachment")
    attachment.Name = name .. "Attachment"
    attachment.Parent = root
    local velocity = Instance.new("LinearVelocity")
    velocity.Name = name .. "Velocity"
    velocity.Attachment0 = attachment
    velocity.MaxForce = maxForce
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
    velocity.PrimaryTangentAxis = Vector3.xAxis
    velocity.SecondaryTangentAxis = Vector3.zAxis
    velocity.PlaneVelocity = Vector2.zero
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.Parent = root
    return attachment, velocity
end

local function velocityFactor(progress)
    return math.max(0, math.min(progress / 0.15, 1, (1 - progress) / 0.25))
end

function CombatService.new(remote)
    local self = setmetatable({remote = remote, profiles = {}, connections = {}}, CombatService)
    table.insert(self.connections, remote.OnServerEvent:Connect(function(player, request)
        self:request(player, request)
    end))
    table.insert(self.connections, Players.PlayerAdded:Connect(function(player)
        self:bindPlayer(player)
    end))
    table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
        self:removePlayer(player)
    end))
    for _, player in Players:GetPlayers() do self:bindPlayer(player) end
    local accumulator = 0
    table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
        accumulator += math.min(dt, 0.1)
        local step = 1 / Config.HitSampleRate
        while accumulator >= step do
            accumulator -= step
            self:update(step)
        end
    end))
    return self
end

function CombatService:bindPlayer(player)
    if self.profiles[player] then return end
    local profile = {
        player = player, character = nil, action = nil, started = 0,
        stamina = Config.MaxStamina, lastSpend = 0, lastSequence = 0,
        rateWindow = 0, rateCount = 0, hit = {}, comboQueued = false,
        sweepTime = nil, motionVelocity = nil, motionAttachment = nil, motionDirection = nil,
        facing = nil,
        alive = false, blocking = false, sprinting = false,
        characterConnections = {},
    }
    self.profiles[player] = profile
    profile.playerConnection = player.CharacterAdded:Connect(function(character)
        self:bindCharacter(profile, character)
    end)
    profile.appearanceConnection = player.CharacterAppearanceLoaded:Connect(function(character)
        if profile.character == character then self:prepareBladePaths(profile, character) end
    end)
    if player.Character then self:bindCharacter(profile, player.Character) end
end

function CombatService:bindCharacter(profile, character)
    self:clearCharacter(profile)
    profile.character = character
    profile.bladeCache = {}
    local humanoid = character:WaitForChild("Humanoid", 5)
    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not humanoid or not root then return end
    profile.alive = humanoid.Health > 0
    profile.stamina = Config.MaxStamina
    profile.lastSpend = 0
    profile.blocking = false
    profile.sprinting = false
    profile.action = nil
    profile.hit = {}
    humanoid.WalkSpeed = Config.WalkSpeed
    character:SetAttribute("CombatState", "Idle")
    character:SetAttribute("Stamina", profile.stamina)
    character:SetAttribute("MaxStamina", Config.MaxStamina)
    table.insert(profile.characterConnections, humanoid.Died:Connect(function()
        profile.alive = false
        self:finish(profile)
        character:SetAttribute("CombatState", "Dead")
    end))
    if typeof(profile.player) == "Instance" and profile.player:IsA("Player") and profile.player:HasAppearanceLoaded() then
        self:prepareBladePaths(profile, character)
    end
end

function CombatService:prepareBladePaths(profile, character)
    profile.bladeGeneration = (profile.bladeGeneration or 0) + 1
    local generation = profile.bladeGeneration
    profile.bladeCache = {}
    character:SetAttribute("CombatHitReady", false)
    task.spawn(function()
        for _, name in {"SwordR1_1", "SwordR1_2", "SwordR2"} do
            if profile.character ~= character or profile.bladeGeneration ~= generation or not profile.alive then return end
            local source = ReplicatedStorage.CombatFoundation.Animations:FindFirstChild(name)
            local ok, path = pcall(BladeTrajectory.build, character, source, 8)
            if profile.character ~= character or profile.bladeGeneration ~= generation or not profile.alive then return end
            if not ok then character:SetAttribute("CombatHitRigError", tostring(path)); return end
            profile.bladeCache[name] = path
        end
        character:SetAttribute("CombatHitRigError", nil)
        character:SetAttribute("CombatHitReady", true)
    end)
end

function CombatService:clearCharacter(profile)
    profile.bladeGeneration = (profile.bladeGeneration or 0) + 1
    for _, connection in profile.characterConnections do connection:Disconnect() end
    table.clear(profile.characterConnections)
    self:finish(profile)
    profile.character = nil
end

function CombatService:removePlayer(player)
    local profile = self.profiles[player]
    if not profile then return end
    self:clearCharacter(profile)
    if profile.playerConnection then profile.playerConnection:Disconnect() end
    if profile.appearanceConnection then profile.appearanceConnection:Disconnect() end
    self.profiles[player] = nil
end

function CombatService:setState(profile, state)
    local character = profile.character
    if character and character:GetAttribute("CombatState") ~= state then
        character:SetAttribute("CombatState", state)
    end
end

function CombatService:spend(profile, amount, now)
    if profile.stamina + 1e-4 < amount then return false end
    profile.stamina = math.max(0, profile.stamina - amount)
    profile.lastSpend = now
    profile.character:SetAttribute("Stamina", profile.stamina)
    return true
end

function CombatService:finish(profile)
    if profile.motionVelocity then profile.motionVelocity:Destroy(); profile.motionVelocity = nil end
    if profile.motionAttachment then profile.motionAttachment:Destroy(); profile.motionAttachment = nil end
    profile.motionDirection = nil
    profile.facing = nil
    profile.action = nil
    profile.comboQueued = false
    profile.comboSequence = nil
    profile.sweepTime = nil
    profile.sweepRoot = nil
    profile.hit = {}
    local humanoid = profile.character and profile.character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = profile.blocking and Config.BlockWalkSpeed or Config.WalkSpeed
        self:setState(profile, profile.blocking and "Blocking" or "Idle")
    end
end

function CombatService:broadcastStarted(profile, actionName, now, requestSequence)
    profile.actionSerial = (profile.actionSerial or 0) + 1
    self.remote:FireAllClients("Started", profile.player, actionName, now,
        {character = profile.character, serial = profile.actionSerial, sequence = requestSequence})
end

function CombatService:start(profile, actionName, now, rollVector, requestSequence)
    local action = Config.Actions[actionName]
    if not action or not profile.alive or profile.action then return false end
    if type(now) ~= "number" or now ~= now or math.abs(now) == math.huge then return false end
    local humanoid, root = living(profile.character)
    if not humanoid or not root:IsA("BasePart") then return false end
    if ATTACKS[actionName] and typeof(profile.player) == "Instance" and profile.player:IsA("Player")
        and profile.character:GetAttribute("CombatHitReady") ~= true then return false end
    if rollVector ~= nil then
        if not ROLL_DIRECTIONS[actionName] or typeof(rollVector) ~= "Vector3" then return false end
        for _, component in {rollVector.X, rollVector.Y, rollVector.Z} do
            if component ~= component or math.abs(component) == math.huge then return false end
        end
        local flat = Vector3.new(rollVector.X, 0, rollVector.Z)
        if flat.Magnitude < 0.8 or flat.Magnitude > 1.2 then return false end
        rollVector = flat.Unit
    end
    if not self:spend(profile, action.cost or 0, now) then return false end
    profile.action = actionName
    profile.started = now
    profile.comboQueued = false
    profile.hit = {}
    profile.sweepTime = nil
    profile.blocking = false
    profile.sprinting = false
    humanoid.WalkSpeed = 0
    humanoid.AutoRotate = false
    self:setState(profile, Timeline.phase(actionName, 0))
    if ATTACKS[actionName] then
        profile.facing = horizontalUnit(root.CFrame.LookVector)
        profile.sweepTime = 0
        profile.sweepRoot = CFrame.lookAt(root.Position, root.Position + profile.facing)
        profile.motionDirection = profile.facing
        profile.motionAttachment, profile.motionVelocity = planarMotion(root, "CombatAdvance", 22000)
    end
    if ROLL_DIRECTIONS[actionName] then
        local direction
        if actionName == "RollBackward" then direction = -root.CFrame.LookVector
        elseif actionName == "RollLeft" then direction = -root.CFrame.RightVector
        elseif actionName == "RollRight" then direction = root.CFrame.RightVector
        else direction = root.CFrame.LookVector end
        profile.motionAttachment, profile.motionVelocity = planarMotion(root, "CombatRoll", 35000)
        profile.motionDirection = horizontalUnit(rollVector or direction)
    end
    self:broadcastStarted(profile, actionName, now, requestSequence)
    return true
end

function CombatService:request(player, request)
    local profile = self.profiles[player]
    if not profile or not profile.alive or type(request) ~= "table" then return end
    local sequence = request.sequence
    if type(sequence) ~= "number" or sequence ~= sequence or math.abs(sequence) == math.huge
        or sequence % 1 ~= 0 or sequence <= profile.lastSequence then return end
    if sequence > profile.lastSequence + 100 then return end
    profile.lastSequence = sequence
    local now = workspace:GetServerTimeNow()
    if now - profile.rateWindow >= 1 then profile.rateWindow, profile.rateCount = now, 0 end
    profile.rateCount += 1
    -- Releasing a held control must remain possible after a burst. These two
    -- idempotent requests cannot start actions, deal damage or spend stamina.
    local release = request.kind == "BlockEnd" or request.kind == "SprintEnd"
    if profile.rateCount > Config.MaxRequestRate and not release then
        if request.kind == "R1" or request.kind == "R2" or request.kind == "Roll" or request.kind == "Parry"
            or request.kind == "BlockStart" or request.kind == "SprintStart" then
            self.remote:FireClient(player, "Rejected", sequence)
        end
        return
    end
    local humanoid, root = living(profile.character)
    if not humanoid or not root:IsA("BasePart") then return end
    local kind = request.kind
    if type(kind) ~= "string" then return end
    local function rejected() self.remote:FireClient(player, "Rejected", sequence) end
    if kind == "R1" then
        if profile.action == "SwordR1_1" and now - profile.started >= Config.Actions.SwordR1_1.bufferOpen and now - profile.started <= Config.Actions.SwordR1_1.combo[2] then
            if profile.stamina + 1e-4 < Config.Actions.SwordR1_2.cost then rejected(); return end
            profile.comboQueued = true
            profile.comboSequence = sequence
            return
        end
        if profile.action or profile.blocking or not self:start(profile, "SwordR1_1", now, nil, sequence) then rejected() end
    elseif kind == "R2" then
        if profile.action or profile.blocking or not self:start(profile, "SwordR2", now, nil, sequence) then rejected() end
    elseif kind == "Roll" then
        local name = request.direction
        if not profile.action and not profile.blocking and ROLL_DIRECTIONS[name] then
            local vector = request.moveDirection
            if vector ~= nil then
                if typeof(vector) ~= "Vector3" then return end
                for _, component in {vector.X, vector.Y, vector.Z} do
                    if component ~= component or math.abs(component) == math.huge then return end
                end
                local flat = Vector3.new(vector.X, 0, vector.Z)
                if flat.Magnitude < 0.8 or flat.Magnitude > 1.2 then return end
                local expected
                if name == "RollBackward" then expected = -root.CFrame.LookVector
                elseif name == "RollLeft" then expected = -root.CFrame.RightVector
                elseif name == "RollRight" then expected = root.CFrame.RightVector
                else expected = root.CFrame.LookVector end
                if horizontalUnit(expected):Dot(flat.Unit) < 0.5 then return end
                vector = flat.Unit
            end
            if not self:start(profile, name, now, vector, sequence) then rejected() end
        else
            rejected()
        end
    elseif kind == "BlockStart" then
        if not profile.action and profile.stamina > 0 then
            profile.sprinting = false
            profile.blocking = true
            humanoid.WalkSpeed = Config.BlockWalkSpeed
            self:setState(profile, "Blocking")
        end
    elseif kind == "BlockEnd" then
        profile.blocking = false
        if not profile.action then
            humanoid.WalkSpeed = profile.sprinting and Config.SprintSpeed or Config.WalkSpeed
            self:setState(profile, profile.sprinting and "Sprinting" or "Idle")
        end
    elseif kind == "Parry" then
        if profile.action or profile.blocking or not self:start(profile, "Parry", now, nil, sequence) then rejected() end
    elseif kind == "SprintStart" then
        if not profile.action and not profile.blocking and profile.stamina > 0 then profile.sprinting = true; humanoid.WalkSpeed = Config.SprintSpeed end
    elseif kind == "SprintEnd" then
        profile.sprinting = false
        if not profile.action then humanoid.WalkSpeed = profile.blocking and Config.BlockWalkSpeed or Config.WalkSpeed end
    end
end

function CombatService:profileForCharacter(character)
    local player = Players:GetPlayerFromCharacter(character)
    return player and self.profiles[player]
end

local function applyHealthDamage(targetHumanoid, damage)
    local character = targetHumanoid.Parent
    if character:GetAttribute("CombatDummy") == true then
        damage = math.min(damage, math.max(0, targetHumanoid.Health - 1))
    end
    targetHumanoid:TakeDamage(damage)
    if character:GetAttribute("CombatDummy") == true then
        local serial = (character:GetAttribute("CombatDummyHitSerial") or 0) + 1
        character:SetAttribute("CombatDummyHitSerial", serial)
        task.delay(1.5, function()
            if targetHumanoid.Parent == character and targetHumanoid.Health > 0
                and character:GetAttribute("CombatDummyHitSerial") == serial then
                targetHumanoid.Health = targetHumanoid.MaxHealth
            end
        end)
    end
end

function CombatService:damage(attacker, targetHumanoid, actionName, now)
    local character = targetHumanoid.Parent
    if character == attacker.character or targetHumanoid.Health <= 0 then return false end
    local defender = self:profileForCharacter(character)
    if defender and defender.alive then
        local elapsed = now - defender.started
        if defender.action and Timeline.inWindow(defender.action, "iframes", elapsed) then return false end
        local attackerRoot = attacker.character:FindFirstChild("HumanoidRootPart")
        local targetRoot = character:FindFirstChild("HumanoidRootPart")
        local facing = false
        if attackerRoot and targetRoot then
            local displacement = attackerRoot.Position - targetRoot.Position
            facing = displacement.Magnitude > 0 and targetRoot.CFrame.LookVector:Dot(displacement.Unit) > 0.25
        end
        if defender.action == "Parry" and Timeline.inWindow("Parry", "parry", elapsed) and facing then
            self:finish(attacker)
            local staggerHumanoid = attacker.character and attacker.character:FindFirstChildOfClass("Humanoid")
            if staggerHumanoid and staggerHumanoid.Health > 0 then
                attacker.action = "Stagger"
                attacker.started = now
                staggerHumanoid.WalkSpeed = 0
                self:setState(attacker, "Staggered")
                self:broadcastStarted(attacker, "Stagger", now)
            else
                -- A validated same-frame trade can be parried after its actor
                -- died. Deny that hit without resurrecting a reaction state.
                self:setState(attacker, "Dead")
            end
            return true
        end
        if defender.blocking and facing then
            local action = Config.Actions[actionName]
            local drain = action.damage * Config.Block.staminaPerDamage
            local paid = self:spend(defender, drain, now)
            if paid then
                applyHealthDamage(targetHumanoid, action.damage * (1 - Config.Block.absorb))
                return true
            end
            defender.blocking = false
            defender.stamina = 0
            defender.lastSpend = now
            character:SetAttribute("Stamina", 0)
            self:finish(defender)
            defender.action = "GuardBroken"
            defender.started = now
            targetHumanoid.WalkSpeed = 0
            self:setState(defender, "GuardBroken")
            self:broadcastStarted(defender, "GuardBroken", now)
        end
    end
    applyHealthDamage(targetHumanoid, Config.Actions[actionName].damage)
    return true
end

function CombatService:bladePath(profile, actionName)
    profile.bladeCache = profile.bladeCache or {}
    if profile.bladeCache[actionName] then return profile.bladeCache[actionName] end
    local source = ReplicatedStorage.CombatFoundation.Animations:FindFirstChild(actionName)
    if not source then return nil end
    local ok, path = pcall(BladeTrajectory.build, profile.character, source)
    if not ok then
        profile.character:SetAttribute("CombatHitRigError", tostring(path))
        return nil -- Unsupported/missing joints fail closed, never use a broad fallback.
    end
    profile.bladeCache[actionName] = path
    return path
end

function CombatService:sweep(profile, actionName, elapsed, now, frameHits)
    local action = Config.Actions[actionName]
    local humanoid, root = living(profile.character)
    if not humanoid then return end
    if profile.action ~= actionName then return end
    local old = profile.sweepTime or 0
    if elapsed <= old or old >= action.active[2] then return end
    local facing = profile.facing or horizontalUnit(root.CFrame.LookVector)
    local currentRoot = CFrame.lookAt(root.Position,root.Position+facing)
    local previousRoot = profile.sweepRoot or currentRoot
    -- A discontinuous root jump must not produce a damage ribbon through the map.
    if (currentRoot.Position-previousRoot.Position).Magnitude>2 then previousRoot=currentRoot end
    profile.sweepTime,profile.sweepRoot=elapsed,currentRoot
    local from,to=math.max(old,action.active[1]),math.min(elapsed,action.active[2])
    if from>to then return end
    local path = self:bladePath(profile, actionName)
    if not path then return end
    local hitSet = profile.hit
    local pendingTargets
    if frameHits then
        pendingTargets = frameHits.pendingTargets[hitSet]
        if not pendingTargets then
            pendingTargets = {}
            frameHits.pendingTargets[hitSet] = pendingTargets
        end
    end
    local count = math.clamp(math.ceil((to-from)*60),1,32)
    local previousA,previousB
    for index=0,count do
        local alpha=index/count
        local time=from+(to-from)*alpha
        local frame=previousRoot:Lerp(currentRoot,(time-old)/(elapsed-old))
        local localA,localB=BladeTrajectory.sample(path,time)
        local a,b=frame:PointToWorldSpace(localA),frame:PointToWorldSpace(localB)
        for target, contacts in BladeTrajectory.query(profile.character,a,b,previousA,previousB,.18) do
            if hitSet[target] or (pendingTargets and pendingTargets[target]) then continue end
            local model=target.Parent
            local targetRoot=model:FindFirstChild("HumanoidRootPart")
            if not targetRoot or (targetRoot.Position-root.Position).Magnitude>action.reach+2 then continue end
            local ray=RaycastParams.new()
            ray.FilterType=Enum.RaycastFilterType.Exclude
            ray.FilterDescendantsInstances={profile.character,model}
            ray.RespectCanCollide=true
            for _, candidate in contacts do
                -- Use the actual segment/box intersection. A ray to a torso's
                -- centre can clear low cover while the blade hits through it.
                local origin,contact=candidate.origin,candidate.contact
                local bodyObstruction=workspace:Raycast(frame.Position,origin-frame.Position,ray)
                local bladeObstruction=workspace:Raycast(origin,contact-origin,ray)
                if not bodyObstruction and not bladeObstruction then
                    if frameHits then
                        -- Geometry for this action was validated while its actor
                        -- was alive. Defer damage until every actor has swept.
                        pendingTargets[target] = true
                        table.insert(frameHits.pendingHits, {profile = profile,
                            character = profile.character, action = actionName,
                            started = profile.started, hitSet = hitSet,
                            target = target, targetCharacter = model})
                        break
                    elseif self:damage(profile,target,actionName,now) then
                        hitSet[target] = true
                        if profile.action~=actionName then return end
                        break
                    end
                end
            end
        end
        previousA,previousB=a,b
    end
end

local function resolveFrameHits(service, frameHits, now)
    local killedCharacters, cancelledActions = {}, {}
    for _, intent in frameHits.pendingHits do
        local profile, character, hitSet = intent.profile, intent.character, intent.hitSet
        if cancelledActions[hitSet] or hitSet[intent.target]
            or profile.character ~= character or not character.Parent
            or intent.target.Parent ~= intent.targetCharacter or not intent.targetCharacter.Parent then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local alive = profile.alive and humanoid and humanoid.Health > 0
        local killedHere = killedCharacters[character] == true
        -- Died may have already called finish() and replaced the live hitSet.
        -- Only a death caused by this resolution permits that captured trade;
        -- parry/guard break or a different action never permit stale intents.
        local unchanged = profile.action == intent.action and profile.hit == hitSet
        local finishedByDeath = killedHere and profile.action == nil
        if not humanoid or (not alive and not killedHere)
            or profile.started ~= intent.started or (not unchanged and not finishedByDeath) then continue end
        local actionBefore, hitsBefore, startedBefore = profile.action, profile.hit, profile.started
        local healthBefore = intent.target.Health
        if service:damage(profile, intent.target, intent.action, now) then
            hitSet[intent.target] = true
        end
        if healthBefore > 0 and intent.target.Health <= 0 then
            killedCharacters[intent.targetCharacter] = true
        end
        -- A parry can invalidate every remaining contact from the same sweep.
        -- Mark the captured action even if another hit subsequently kills it.
        if profile.action ~= actionBefore or profile.hit ~= hitsBefore or profile.started ~= startedBefore then
            cancelledActions[hitSet] = true
        end
    end
end

function CombatService:update(dt)
    local now = workspace:GetServerTimeNow()
    local frameHits = {pendingHits = {}, pendingTargets = {}}
    local frameActors = {}
    -- First collect contacts for all living actors, before any of their hits
    -- can kill the actor visited next in the profiles table.
    for _, profile in self.profiles do
        if not profile.alive then continue end
        local humanoid = living(profile.character)
        if not humanoid then continue end
        if profile.sprinting and not profile.action then
            local drain = Config.SprintDrainPerSecond * dt
            if profile.stamina <= drain then
                profile.sprinting = false
                humanoid.WalkSpeed = Config.WalkSpeed
            else
                profile.stamina -= drain
                profile.lastSpend = now
            end
        elseif not profile.action and now - profile.lastSpend >= Config.StaminaRegenDelay then
            profile.stamina = math.min(Config.MaxStamina, profile.stamina + Config.StaminaRegenPerSecond * dt)
        end
        profile.character:SetAttribute("Stamina", math.floor(profile.stamina * 10 + 0.5) / 10)
        local actor = {profile = profile, character = profile.character,
            action = profile.action, started = profile.started}
        table.insert(frameActors, actor)
        if profile.action then
            local actionName = profile.action
            local action = Config.Actions[actionName]
            local elapsed = now - profile.started
            actor.elapsed = elapsed
            if not action then continue end
            if ATTACKS[actionName] and profile.facing then
                local _, root = living(profile.character)
                if root then
                    local wanted = horizontalUnit(root.CFrame.LookVector)
                    local current = profile.facing
                    local signedAngle = math.atan2(current.Z * wanted.X - current.X * wanted.Z, current:Dot(wanted))
                    local maxTurn = math.rad(action.turnRate) * dt
                    local step = math.clamp(signedAngle, -maxTurn, maxTurn)
                    profile.facing = CFrame.Angles(0, step, 0):VectorToWorldSpace(current)
                    profile.motionDirection = profile.facing
                end
            end
            if profile.motionVelocity and profile.motionDirection then
                local window = ROLL_DIRECTIONS[actionName] and action.motionWindow or action.advanceWindow
                if window then
                    local span = window[2] - window[1]
                    local progress = math.clamp((elapsed - window[1]) / span, 0, 1)
                    local distance = ROLL_DIRECTIONS[actionName] and action.distance or action.advance
                    local speed = distance / span / 0.80 * velocityFactor(progress)
                    if elapsed < window[1] or elapsed > window[2] then speed = 0 end
                    local horizontal = profile.motionDirection * speed
                    profile.motionVelocity.PlaneVelocity = Vector2.new(horizontal.X, horizontal.Z)
                end
            end
            if ATTACKS[actionName] then
                self:sweep(profile, actionName, elapsed, now, frameHits)
            end
        end
    end
    resolveFrameHits(self, frameHits, now)
    -- Resolve contacts before advancing combos or ending recovery. Reactions
    -- raised by resolution retain their state and cannot chain the old attack.
    for _, actor in frameActors do
        local profile = actor.profile
        if profile.character ~= actor.character or not profile.alive then continue end
        local humanoid = living(profile.character)
        if not humanoid then continue end
        if profile.action ~= actor.action or profile.started ~= actor.started then continue end
        if profile.action then
            local actionName, elapsed = actor.action, actor.elapsed
            local action = Config.Actions[actionName]
            if actionName == "SwordR1_1" and profile.comboQueued and elapsed >= action.chainAt then
                local comboSequence = profile.comboSequence
                self:finish(profile)
                self:start(profile, "SwordR1_2", now, nil, comboSequence)
                continue
            end
            if action then
                self:setState(profile, Timeline.phase(actionName, elapsed))
                if elapsed >= action.duration then
                    self:finish(profile)
                end
            else
                self:finish(profile)
            end
        elseif profile.blocking then
            self:setState(profile, "Blocking")
        elseif profile.sprinting then
            self:setState(profile, "Sprinting")
        else
            self:setState(profile, humanoid.MoveDirection.Magnitude > 0.05 and "Moving" or "Idle")
        end
    end
end

function CombatService:destroy()
    for _, connection in self.connections do connection:Disconnect() end
    for player in self.profiles do self:removePlayer(player) end
end

return CombatService
