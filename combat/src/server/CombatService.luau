local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CombatFoundation"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CombatConfig"))
local Timeline = require(Shared:WaitForChild("ActionTimeline"))

local CombatService = {}
CombatService.__index = CombatService

local ROLL_DIRECTIONS = {RollForward = true, RollBackward = true, RollLeft = true, RollRight = true}
local ATTACKS = {SwordR1_1 = true, SwordR1_2 = true, SwordR2 = true}

local function living(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return humanoid and humanoid.Health > 0 and root and humanoid, root
end

local function clamp01(x)
    return math.clamp(x, 0, 1)
end

local function yawFor(name, u)
    if name == "SwordR1_1" then return math.rad(-52 + 104 * u) end
    if name == "SwordR1_2" then return math.rad(52 - 104 * u) end
    return math.rad(-10 + 20 * u)
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
    if player.Character then self:bindCharacter(profile, player.Character) end
end

function CombatService:bindCharacter(profile, character)
    self:clearCharacter(profile)
    profile.character = character
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
end

function CombatService:clearCharacter(profile)
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
    profile.sweepTime = nil
    profile.hit = {}
    local humanoid = profile.character and profile.character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = profile.blocking and Config.BlockWalkSpeed or Config.WalkSpeed
        self:setState(profile, profile.blocking and "Blocking" or "Idle")
    end
end

function CombatService:start(profile, actionName, now, rollVector)
    local action = Config.Actions[actionName]
    if not action or not self:spend(profile, action.cost or 0, now) then return false end
    local humanoid, root = living(profile.character)
    if not humanoid then return false end
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
    self.remote:FireAllClients("Started", profile.player, actionName, now)
    return true
end

function CombatService:request(player, request)
    local profile = self.profiles[player]
    if not profile or not profile.alive or type(request) ~= "table" then return end
    local sequence = request.sequence
    if type(sequence) ~= "number" or sequence % 1 ~= 0 or sequence <= profile.lastSequence then return end
    if sequence > profile.lastSequence + 100 then return end
    profile.lastSequence = sequence
    local now = workspace:GetServerTimeNow()
    if now - profile.rateWindow >= 1 then profile.rateWindow, profile.rateCount = now, 0 end
    profile.rateCount += 1
    if profile.rateCount > Config.MaxRequestRate then return end
    local humanoid, root = living(profile.character)
    if not humanoid then return end
    local kind = request.kind
    if type(kind) ~= "string" then return end
    local function rejected() self.remote:FireClient(player, "Rejected", sequence) end
    if kind == "R1" then
        if profile.action == "SwordR1_1" and now - profile.started >= Config.Actions.SwordR1_1.bufferOpen and now - profile.started <= Config.Actions.SwordR1_1.combo[2] then
            profile.comboQueued = true
            return
        end
        if profile.action or profile.blocking or not self:start(profile, "SwordR1_1", now) then rejected() end
    elseif kind == "R2" then
        if profile.action or profile.blocking or not self:start(profile, "SwordR2", now) then rejected() end
    elseif kind == "Roll" then
        local name = request.direction
        if not profile.action and not profile.blocking and ROLL_DIRECTIONS[name] then
            local vector = request.moveDirection
            if vector ~= nil then
                if typeof(vector) ~= "Vector3" then return end
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
            if not self:start(profile, name, now, vector) then rejected() end
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
        if not profile.action then humanoid.WalkSpeed = Config.WalkSpeed; self:setState(profile, "Idle") end
    elseif kind == "Parry" then
        if profile.action or profile.blocking or not self:start(profile, "Parry", now) then rejected() end
    elseif kind == "SprintStart" then
        if not profile.action and not profile.blocking and profile.stamina > 0 then profile.sprinting = true; humanoid.WalkSpeed = Config.SprintSpeed end
    elseif kind == "SprintEnd" then
        profile.sprinting = false
        if not profile.action then humanoid.WalkSpeed = Config.WalkSpeed end
    end
end

function CombatService:damage(attacker, targetHumanoid, actionName, now)
    local character = targetHumanoid.Parent
    if character == attacker.character or targetHumanoid.Health <= 0 then return false end
    local targetPlayer = Players:GetPlayerFromCharacter(character)
    local defender = targetPlayer and self.profiles[targetPlayer]
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
            attacker.action = "Stagger"
            attacker.started = now
            local staggerHumanoid = attacker.character and attacker.character:FindFirstChildOfClass("Humanoid")
            if staggerHumanoid then staggerHumanoid.WalkSpeed = 0 end
            self:setState(attacker, "Staggered")
            self.remote:FireAllClients("Started", attacker.player, "Stagger", now)
            return true
        end
        if defender.blocking and facing then
            local action = Config.Actions[actionName]
            local drain = action.damage * Config.Block.staminaPerDamage
            local paid = self:spend(defender, drain, now)
            if paid then
                targetHumanoid:TakeDamage(action.damage * (1 - Config.Block.absorb))
                return true
            end
            defender.blocking = false
            self:finish(defender)
            defender.action = "GuardBroken"
            defender.started = now
            targetHumanoid.WalkSpeed = 0
            self:setState(defender, "GuardBroken")
            self.remote:FireAllClients("Started", defender.player, "GuardBroken", now)
        end
    end
    local damage = Config.Actions[actionName].damage
    if character:GetAttribute("CombatDummy") == true then
        damage = math.min(damage, math.max(0, targetHumanoid.Health - 1))
    end
    targetHumanoid:TakeDamage(damage)
    if character:GetAttribute("CombatDummy") == true then
        task.delay(1.5, function()
            if targetHumanoid.Parent == character and targetHumanoid.Health > 0 then
                targetHumanoid.Health = targetHumanoid.MaxHealth
            end
        end)
    end
    return true
end

function CombatService:sweep(profile, actionName, elapsed, now)
    local action = Config.Actions[actionName]
    local humanoid, root = living(profile.character)
    if not humanoid then return end
    local active = action.active
    local u = clamp01((elapsed - active[1]) / (active[2] - active[1]))
    local old = profile.sweepTime or math.max(active[1], elapsed - 1 / Config.HitSampleRate)
    local oldU = clamp01((old - active[1]) / (active[2] - active[1]))
    profile.sweepTime = elapsed
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {profile.character}
    params.MaxParts = 100
    -- Three boxes bridge the previous and current authored arc sample. Server root
    -- position and action time define the query; client never supplies hit targets.
    for i = 0, 2 do
        local sampleU = oldU + (u - oldU) * i / 2
        local facing = profile.facing or horizontalUnit(root.CFrame.LookVector)
        local frame = CFrame.lookAt(root.Position, root.Position + facing) * CFrame.Angles(0, yawFor(actionName, sampleU), 0)
        local center = frame * CFrame.new(0, 0, -action.reach * 0.52)
        for _, part in workspace:GetPartBoundsInBox(center, Vector3.new(action.width, 4.5, action.reach), params) do
            local model = part:FindFirstAncestorOfClass("Model")
            while model and not model:FindFirstChildOfClass("Humanoid") do
                local parent = model.Parent
                model = parent and (parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model"))
            end
            local target = model and model:FindFirstChildOfClass("Humanoid")
            if target and not profile.hit[target] then
                local targetRoot = model:FindFirstChild("HumanoidRootPart")
                if targetRoot and (targetRoot.Position - root.Position).Magnitude <= action.reach + 2 then
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    rayParams.FilterDescendantsInstances = {profile.character}
                    local displacement = targetRoot.Position - root.Position
                    local obstruction = workspace:Raycast(root.Position, displacement, rayParams)
                    if (not obstruction or obstruction.Instance:IsDescendantOf(model))
                        and self:damage(profile, target, actionName, now) then
                        profile.hit[target] = true
                    end
                end
            end
        end
    end
end

function CombatService:update(dt)
    local now = workspace:GetServerTimeNow()
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
        if profile.action then
            local actionName = profile.action
            local action = Config.Actions[actionName]
            local elapsed = now - profile.started
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
            if actionName == "SwordR1_1" and profile.comboQueued and elapsed >= action.chainAt then
                self:finish(profile)
                self:start(profile, "SwordR1_2", now)
                continue
            end
            if ATTACKS[actionName] and Timeline.inWindow(actionName, "active", elapsed) then
                self:sweep(profile, actionName, elapsed, now)
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
