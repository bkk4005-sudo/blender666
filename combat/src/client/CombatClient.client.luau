local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local rootFolder = ReplicatedStorage:WaitForChild("CombatFoundation")
local shared = rootFolder:WaitForChild("Shared")
local Config = require(shared:WaitForChild("CombatConfig"))
local Registry = require(shared:WaitForChild("AnimationRegistry"))
local Bindings = require(shared:WaitForChild("InputBindings"))
local PreviewRetarget = require(shared:WaitForChild("R15PreviewRetarget"))
local Observer = require(shared:WaitForChild("CombatObserver"))
local remote = rootFolder:WaitForChild("CombatRemote")
local sources = rootFolder:WaitForChild("Animations")

local character, humanoid, root, animator
local tracks = {}
local previewSequences = {}
local trackConnections = {}
local predicted = nil
local actionTrack = nil
local target = nil
local occludedSince = nil
local facingAttachment = nil
local facingAlign = nil
local inputSequence = 0
local moveVector = Vector3.zero
local camera = workspace.CurrentCamera
local controls = nil
local lastPosition = nil
local deathConnection = nil
local characterVersion = 0
local localAction = nil
local comboSubmitted = false
local firstR1Input = nil
local comboBuffer = nil
local comboRequest = nil
local confirmedAction = nil
local lastAcceptedSerial = 0
local learnedAckRTT = .25
local destroyed = false
local lifetimeConnections = {}
local function connectLifetime(signal, callback)
    local connection = signal:Connect(function(...)
        if not destroyed then callback(...) end
    end)
    table.insert(lifetimeConnections, connection)
    return connection
end
local observer = Observer.new(rootFolder, function(count)
    if not destroyed and script.Parent then script:SetAttribute("ObserverAnimationCount", count) end
end)

local function rolling()
    return character and (character:GetAttribute("CombatState") == "Rolling"
        or (localAction and localAction.name:sub(1, 4) == "Roll" and os.clock() < localAction.ends))
end

local function canStart()
    if not character or predicted or rolling() then return false end
    local state = character:GetAttribute("CombatState")
    return (state == "Idle" or state == "Moving" or state == "Sprinting")
        and (not localAction or os.clock() >= localAction.ends)
end

local function disconnectTracks()
    for _, connection in trackConnections do connection:Disconnect() end
    table.clear(trackConnections)
    for _, track in tracks do track:Stop(0); track:Destroy() end
    table.clear(tracks)
    for _, sequence in previewSequences do sequence:Destroy() end
    table.clear(previewSequences)
    actionTrack = nil
    predicted = nil
    localAction = nil
    comboSubmitted = false
    firstR1Input, comboBuffer, comboRequest = nil, nil, nil
    confirmedAction = nil
end

local function loadTrack(semantic)
    if tracks[semantic] then return tracks[semantic] end
    local entry = Registry.get("R15", semantic)
    if not entry or not animator then return nil end
    local assetId = entry.assetId
    if not assetId and RunService:IsStudio() then
        local sequence = sources:FindFirstChild(semantic)
        if sequence and sequence:IsA("KeyframeSequence") then
            local ok, temporaryId = pcall(function()
                local preview = PreviewRetarget.forCharacter(sequence, character)
                table.insert(previewSequences, preview)
                return KeyframeSequenceProvider:RegisterKeyframeSequence(preview)
            end)
            if ok then assetId = temporaryId end
            if not ok then warn("Combat preview retarget failed:", semantic, temporaryId) end
        end
    end
    if not assetId then return nil end
    local animation = Instance.new("Animation")
    animation.Name = semantic
    animation.AnimationId = assetId
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    animation:Destroy()
    if not ok then warn("Combat animation failed:", semantic, track); return nil end
    track.Name = semantic
    track.Priority = entry.priority
    track.Looped = entry.loop == true
    tracks[semantic] = track
    local lastReached = {}
    local markers = {"AttackStart", "HitStart", "HitEnd", "ComboOpen", "ComboClose", "RecoveryEnd", "IFrameStart", "IFrameEnd", "FootstepLeft", "FootstepRight", "ParryActiveStart", "ParryActiveEnd"}
    for _, marker in markers do
        table.insert(trackConnections, track:GetMarkerReachedSignal(marker):Connect(function()
            local now = os.clock()
            local previous = lastReached[marker]
            if previous and now - previous.at < 1 / 15
                and math.abs(track.TimePosition - previous.position) < 1 / 120 then return end
            lastReached[marker] = {at = now, position = track.TimePosition}
            -- Observable for sound/VFX integration only. Combat authority stays on server.
            if script.Parent then
                script:SetAttribute("LastAnimationMarker", semantic .. ":" .. marker)
                script:SetAttribute("AnimationCueSerial", (script:GetAttribute("AnimationCueSerial") or 0) + 1)
            end
        end))
    end
    return track
end

local function playAction(semantic, restart)
    local track = loadTrack(semantic)
    if not track then return nil end
    local isRoll = semantic:sub(1, 4) == "Roll"
    if isRoll then
        -- Full-body exclusive track: remove residual combat weights at takeoff.
        for name, other in tracks do if name ~= semantic and name ~= "CombatIdle" then other:Stop(.035) end end
        track.Priority = Enum.AnimationPriority.Action4
    elseif actionTrack and actionTrack ~= track then
        actionTrack:Stop(actionTrack.Name:sub(1, 4) == "Roll" and .035 or .12)
    end
    actionTrack = track
    if restart or not track.IsPlaying then track:Play(isRoll and .035 or .10, 1, 1) end
    return track
end

local function phaseDiagnostic(state, elapsed, track, mode)
    if not script.Parent then return end
    script:SetAttribute("ConfirmedActionSerial", state.serial)
    script:SetAttribute("AnimationServerElapsed", elapsed)
    script:SetAttribute("AnimationPhaseError", elapsed - track.TimePosition)
    script:SetAttribute("AnimationPhaseCorrection", mode)
end

local function alignConfirmed(state)
    local action = Config.Actions[state.name]
    if not action then return end
    local elapsed = math.max(0, workspace:GetServerTimeNow() - state.started)
    local track = state.track
    local isRoll = state.name:sub(1, 4) == "Roll"
    if elapsed >= action.duration then
        -- A roll can finish its remaining rise instead of being truncated when
        -- clock correction leaves the presentation slightly behind the server.
        if isRoll and track and track.IsPlaying and track.TimePosition < action.duration - .02
            and elapsed < action.duration + .35 then
            track:AdjustSpeed(1.35)
            localAction = {name = state.name, serial = state.serial,
                ends = os.clock() + math.min(.35, (action.duration - track.TimePosition) / 1.35 + .03)}
            phaseDiagnostic(state, elapsed, track, "RollFinish")
            return
        end
        if track and track.IsPlaying and actionTrack == track then track:Stop(isRoll and .035 or .08) end
        if localAction and localAction.serial == state.serial then localAction = nil end
        if confirmedAction == state then confirmedAction = nil end
        return
    end
    if not track then
        track = playAction(state.name, true)
        state.track, state.seekInitial = track, true
    end
    if not track then return end
    if state.finished then
        phaseDiagnostic(state, elapsed, track, "NaturalEnd")
        return
    end
    if not track.IsPlaying then
        -- Animator can finish one frame before the smoothed server clock.
        -- Replaying that final frame emits a second AnimationPlayed event.
        -- Keep the server input deadline while letting the ended clip fade;
        -- unexpected stops earlier in the action still recover below.
        if action.duration - elapsed <= 1 / 30 then
            state.finished = true
            phaseDiagnostic(state, elapsed, track, "NaturalEnd")
            return
        end
        track:Play(isRoll and .035 or .10, 1, 1)
        state.seekInitial = true
    end
    -- New authoritative clips start at their present phase. Matching an active
    -- prediction keeps its pose and slows an ahead track instead of rewinding.
    local error = elapsed - track.TimePosition
    if track.Length > 0 and (state.seekInitial or error > .20) then
        track.TimePosition = math.min(elapsed, track.Length)
        state.seekInitial = false
        track:AdjustSpeed(1)
        phaseDiagnostic(state, elapsed, track, "ForwardAlign")
    else
        local speed = math.abs(error) <= .025 and 1 or math.clamp(1 + error * 6, .35, 1.35)
        if error < -.35 then speed = 0 end
        track:AdjustSpeed(speed)
        phaseDiagnostic(state, elapsed, track, speed == 1 and "Aligned" or speed < 1 and "SlowAhead" or "CatchUp")
    end
end

local function send(kind, direction, predictedName, moveDirection)
    if destroyed then return end
    if predictedName then
        local action = Config.Actions[predictedName]
        local stamina = character and character:GetAttribute("Stamina")
        if action and action.cost and type(stamina) == "number" and stamina < action.cost then return end
    end
    inputSequence += 1
    script:SetAttribute("LastInputRequest", kind)
    local sentServer = workspace:GetServerTimeNow()
    remote:FireServer({kind = kind, direction = direction, moveDirection = moveDirection, sequence = inputSequence})
    if predictedName then
        -- canStart has already admitted this new action. An expired tracker
        -- must not later stop a reused AnimationTrack during its new request.
        confirmedAction = nil
        local action = Config.Actions[predictedName]
        local now = os.clock()
        predicted = {name = predictedName, sequence = inputSequence, sent = now, sentServer = sentServer,
            deadline = now + math.max((action and action.duration or 0) + .5, learnedAckRTT * 2 + .5)}
        localAction = {name = predictedName, ends = os.clock() + (action and action.duration or .38)}
        predicted.localAction = localAction
        comboSubmitted = false
        comboBuffer, comboRequest = nil, nil
        firstR1Input = predictedName == "SwordR1_1" and {
            sequence = inputSequence, sentServer = sentServer, character = character, version = characterVersion,
        } or nil
        predicted.track = playAction(predictedName, true)
        script:SetAttribute("PredictionStatus", "Pending")
    end
    return inputSequence
end

local function dispatchCombo()
    local queued = comboBuffer
    if not queued then return end
    local first, action = firstR1Input, Config.Actions.SwordR1_1
    local now = workspace:GetServerTimeNow()
    if player:GetAttribute("CombatSettingsOpen") or UserInputService:GetFocusedTextBox()
        or not first or first.character ~= character or first.version ~= characterVersion
        or first.sequence ~= queued.firstSequence or not localAction or localAction.name ~= "SwordR1_1"
        or now > queued.expires or now - first.sentServer > action.combo[2] then
        comboBuffer = nil
        script:SetAttribute("ComboInputStatus", "Expired")
        return
    end
    -- Both native requests traverse the same link. Their expected receipt
    -- interval is their send interval, including before the first ack arrives.
    -- This estimate schedules input only; the server still checks its window.
    local receiptPhase = now - first.sentServer
    if receiptPhase < action.bufferOpen + 1 / Config.HitSampleRate then return end
    comboBuffer = nil
    local sequence = send("R1")
    if not sequence then return end
    comboSubmitted = true
    comboRequest = {sequence = sequence, firstSequence = first.sequence,
        character = character, version = characterVersion}
    script:SetAttribute("ComboInputStatus", "Submitted")
    script:SetAttribute("ComboRequestSequence", sequence)
    script:SetAttribute("ComboEstimatedReceiptPhase", receiptPhase)
end

local function bufferCombo()
    if comboSubmitted or comboBuffer or not firstR1Input then return end
    local action = Config.Actions.SwordR1_1
    local now = workspace:GetServerTimeNow()
    if now - firstR1Input.sentServer > action.combo[2] then return end
    comboBuffer = {firstSequence = firstR1Input.sequence,
        expires = now + math.min(.20, action.combo[2] - action.bufferOpen)}
    script:SetAttribute("ComboInputStatus", "Buffered")
    dispatchCombo()
end

connectLifetime(RunService.PreAnimation, function(dt)
    local pending = predicted
    if not pending or not pending.track or pending.track ~= actionTrack then return end
    if confirmedAction and confirmedAction.track == pending.track then return end
    local action = Config.Actions[pending.name]
    -- Roll presentation always completes. Unconfirmed sword contact waits at
    -- the end of anticipation; markers never grant damage or invulnerability.
    if not action or not action.active or not pending.track.IsPlaying then return end
    local holdAt = math.max(0, action.active[1] - 1 / 30)
    local remaining = holdAt - pending.track.TimePosition
    pending.track:AdjustSpeed(math.clamp(remaining / math.max(dt, 1 / 240), 0, 1))
end)

local function validTarget(model)
    if model == character or not model:IsA("Model") then return false end
    local enemyHumanoid = model:FindFirstChildOfClass("Humanoid")
    local enemyRoot = model:FindFirstChild("HumanoidRootPart")
    if not enemyHumanoid or enemyHumanoid.Health <= 0 or not enemyRoot or not root then return false end
    local distance = (enemyRoot.Position - root.Position).Magnitude
    if distance > Config.LockRange then return false end
    local direction = enemyRoot.Position - camera.CFrame.Position
    if camera.CFrame.LookVector:Dot(direction.Unit) < 0.25 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    local ray = workspace:Raycast(camera.CFrame.Position, direction, params)
    return not ray or ray.Instance:IsDescendantOf(model)
end

local function targetVisible(model)
    local enemyRoot = model:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    local ray = workspace:Raycast(camera.CFrame.Position, enemyRoot.Position - camera.CFrame.Position, params)
    return not ray or ray.Instance:IsDescendantOf(model)
end

local function chooseTarget()
    local best, bestScore = nil, math.huge
    for _, model in workspace:GetDescendants() do
        if model:IsA("Model") and validTarget(model) then
            local enemyRoot = model.HumanoidRootPart
            local offset = enemyRoot.Position - root.Position
            local direction = offset.Unit
            local score = offset.Magnitude + (1 - camera.CFrame.LookVector:Dot(direction)) * 18
            if score < bestScore then best, bestScore = model, score end
        end
    end
    return best
end

local function clearFacing()
    if facingAlign then facingAlign:Destroy(); facingAlign = nil end
    if facingAttachment then facingAttachment:Destroy(); facingAttachment = nil end
    if humanoid and humanoid.Health > 0 then humanoid.AutoRotate = true end
end

local function ensureFacing()
    if facingAlign or not root then return end
    facingAttachment = Instance.new("Attachment")
    facingAttachment.Name = "CombatLockFacing"
    facingAttachment.Parent = root
    facingAlign = Instance.new("AlignOrientation")
    facingAlign.Name = "CombatLockFacing"
    facingAlign.Attachment0 = facingAttachment
    facingAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
    facingAlign.Responsiveness = 8
    facingAlign.MaxTorque = 18000
    facingAlign.MaxAngularVelocity = math.rad(180)
    facingAlign.Parent = root
end

local function setLock(newTarget)
    target = newTarget
    occludedSince = nil
    if not target then
        clearFacing()
        camera.CameraType = Enum.CameraType.Custom
        return
    end
    ensureFacing()
    camera.CameraType = Enum.CameraType.Scriptable
end

local function rollDirection()
    local f = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
    local r = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
    if not root then return "RollForward", Vector3.new(0, 0, -1) end
    if f == 0 and r == 0 then return "RollForward", Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit end
    local cameraForward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
    local cameraRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
    local forward = cameraForward.Magnitude > 1e-4 and cameraForward.Unit or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
    local right = cameraRight.Magnitude > 1e-4 and cameraRight.Unit or Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z).Unit
    local world = forward * f + right * r
    if world.Magnitude < 1e-4 then world = root.CFrame.LookVector end
    world = Vector3.new(world.X, 0, world.Z).Unit
    local forwardScore = world:Dot(root.CFrame.LookVector)
    local rightScore = world:Dot(root.CFrame.RightVector)
    if math.abs(rightScore) > math.abs(forwardScore) then
        return rightScore > 0 and "RollRight" or "RollLeft", world
    end
    return forwardScore < 0 and "RollBackward" or "RollForward", world
end

local function bindCharacter(newCharacter)
    if destroyed then return end
    characterVersion += 1
    local version = characterVersion
    if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
    disconnectTracks()
    script:SetAttribute("PreviewAnimationCount", 0)
    setLock(nil)
    character = newCharacter
    humanoid, root, animator = nil, nil, nil
    -- Appearance application can rebuild the joints/Animator after CharacterAdded.
    -- Preview geometry and tracks must be cached on the completed avatar.
    local deadline = os.clock() + 8
    while not destroyed and player.Character == newCharacter and not player:HasAppearanceLoaded()
        and os.clock() < deadline do RunService.Heartbeat:Wait() end
    if destroyed or version ~= characterVersion or player.Character ~= newCharacter then return end
    local nextHumanoid = newCharacter:WaitForChild("Humanoid", 8)
    local nextRoot = newCharacter:WaitForChild("HumanoidRootPart", 8)
    if destroyed or version ~= characterVersion or player.Character ~= newCharacter or not nextHumanoid or not nextRoot then return end
    local nextAnimator = nextHumanoid:FindFirstChildOfClass("Animator") or nextHumanoid:WaitForChild("Animator", 8)
    if destroyed or version ~= characterVersion or player.Character ~= newCharacter or not nextAnimator then return end
    humanoid, root, animator = nextHumanoid, nextRoot, nextAnimator
    table.insert(trackConnections, animator.AnimationPlayed:Connect(function(track)
        if rolling() and track ~= actionTrack and track.Priority ~= Enum.AnimationPriority.Core
            and track.Priority.Value >= Enum.AnimationPriority.Action.Value then track:Stop(0) end
    end))
    moveVector = Vector3.zero
    lastPosition = root.Position
    for name in Registry.Profiles.R15 do loadTrack(name) end
    local idle = tracks.CombatIdle
    if idle then
        idle.Priority = Enum.AnimationPriority.Movement
        idle:Play(0.20)
    end
    local count = 0
    for _ in tracks do count += 1 end
    script:SetAttribute("PreviewAnimationCount", count)
    deathConnection = humanoid.Died:Connect(function()
        if character == newCharacter then
            disconnectTracks()
            setLock(nil)
        end
    end)
end

local function handleInput(actionName, inputState, inputObject)
    if destroyed then return Enum.ContextActionResult.Pass end
    script:SetAttribute("LastBoundInput", actionName .. ":" .. inputState.Name)
    -- Held actions must release even if chat/menu focus changed after Begin.
    if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
        if actionName == "CombatBlock" then send("BlockEnd"); return Enum.ContextActionResult.Sink end
        if actionName == "CombatSprint" then send("SprintEnd"); return Enum.ContextActionResult.Sink end
    end
    if player:GetAttribute("CombatSettingsOpen") then return Enum.ContextActionResult.Sink end
    if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
    if not humanoid or humanoid.Health <= 0 then return Enum.ContextActionResult.Sink end
    if rolling() and actionName ~= "CombatLock" then return Enum.ContextActionResult.Sink end
    if actionName == "CombatR1" and inputState == Enum.UserInputState.Begin then
        if localAction and os.clock() < localAction.ends and localAction.name == "SwordR1_1" then
            bufferCombo() -- Only the server's Started event switches clips.
        elseif canStart() then send("R1", nil, "SwordR1_1") end
    elseif actionName == "CombatR2" and inputState == Enum.UserInputState.Begin then
        if canStart() then send("R2", nil, "SwordR2") end
    elseif actionName == "CombatRoll" and inputState == Enum.UserInputState.Begin then
        local name, worldDirection = rollDirection()
        if canStart() then send("Roll", name, name, worldDirection) end
    elseif actionName == "CombatBlock" then
        if inputState == Enum.UserInputState.Begin and canStart() then send("BlockStart")
        elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then send("BlockEnd") end
    elseif actionName == "CombatParry" and inputState == Enum.UserInputState.Begin then
        if canStart() then send("Parry", nil, "Parry") end
    elseif actionName == "CombatSprint" then
        if inputState == Enum.UserInputState.Begin and canStart() then send("SprintStart")
        elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then send("SprintEnd") end
    elseif actionName == "CombatLock" and inputState == Enum.UserInputState.Begin then
        setLock(target and nil or chooseTarget())
    end
    return Enum.ContextActionResult.Sink
end

local function bindAction(action)
    if destroyed then return end
    if action == "CombatBlock" then send("BlockEnd") end
    if action == "CombatSprint" then send("SprintEnd") end
    ContextActionService:UnbindAction(action)
    local key = Bindings.resolve(player:GetAttribute("Binding_" .. action)) or Bindings.resolve(Bindings.Defaults[action])
    ContextActionService:BindActionAtPriority(action, handleInput, false, Enum.ContextActionPriority.High.Value + 1, key)
end
for _, action in Bindings.Order do
    bindAction(action)
    connectLifetime(player:GetAttributeChangedSignal("Binding_" .. action), function() bindAction(action) end)
end
connectLifetime(player:GetAttributeChangedSignal("CombatSettingsOpen"), function()
    if player:GetAttribute("CombatSettingsOpen") then
        comboBuffer = nil
        send("BlockEnd")
        send("SprintEnd")
    end
end)
local function releaseHeldActions()
    if destroyed then return end
    comboBuffer = nil
    send("BlockEnd")
    send("SprintEnd")
end
connectLifetime(UserInputService.WindowFocusReleased, releaseHeldActions)
connectLifetime(UserInputService.TextBoxFocused, releaseHeldActions)

connectLifetime(remote.OnClientEvent, function(kind, owner, semantic, started, metadata)
    if kind == "Rejected" and comboRequest and owner == comboRequest.sequence then
        if comboRequest.character == character and comboRequest.version == characterVersion
            and firstR1Input and comboRequest.firstSequence == firstR1Input.sequence then
            comboSubmitted = false
            script:SetAttribute("ComboInputStatus", "Rejected")
        end
        comboRequest = nil
        return -- A rejected continuation must never stop the first swing.
    end
    if kind == "Rejected" and predicted and owner == predicted.sequence then
        local pending = predicted
        if pending.track and (not confirmedAction or confirmedAction.track ~= pending.track) then pending.track:Stop(.08) end
        if localAction == pending.localAction then localAction = nil end
        predicted = nil
        comboSubmitted = false
        firstR1Input, comboBuffer, comboRequest = nil, nil, nil
        script:SetAttribute("PredictionStatus", "Rejected")
        return
    end
    if kind ~= "Started" then return end
    if owner ~= player then
        observer:started(owner, semantic, started, metadata)
        return
    end
    if type(metadata) ~= "table" or metadata.character ~= character or metadata.character ~= player.Character then return end
    local serial = metadata.serial
    if type(serial) ~= "number" or serial ~= serial or serial % 1 ~= 0
        or math.abs(serial) == math.huge or serial <= lastAcceptedSerial then return end
    if type(started) ~= "number" or started ~= started or math.abs(started) == math.huge then return end
    local action = Config.Actions[semantic]
    if not action then return end
    lastAcceptedSerial = serial
    script:SetAttribute("LastAcceptedActionSerial", serial)
    local pending = predicted
    local matched = pending and metadata.sequence == pending.sequence and semantic == pending.name
    if matched then
        local sample = math.clamp(workspace:GetServerTimeNow() - pending.sentServer, .01, 10)
        learnedAckRTT = learnedAckRTT * .75 + sample * .25
        script:SetAttribute("PredictionAckRTT", learnedAckRTT)
        predicted = nil
        script:SetAttribute("PredictionStatus", "Confirmed")
    elseif semantic == "Stagger" or semantic == "GuardBroken" then
        -- Authoritative reactions supersede a speculative input without
        -- treating an unrelated old attack ack as approval of that input.
        predicted = nil
        comboSubmitted = false
        firstR1Input, comboBuffer, comboRequest = nil, nil, nil
        script:SetAttribute("PredictionStatus", "Interrupted")
    end
    local elapsed = math.max(0, workspace:GetServerTimeNow() - started)
    if elapsed >= action.duration or not humanoid or humanoid.Health <= 0 then
        if matched and localAction == pending.localAction then localAction = nil end
        if pending and matched and pending.track and pending.track.IsPlaying then
            if pending.name:sub(1, 4) == "Roll" then pending.track:AdjustSpeed(1)
            else pending.track:Stop(.12) end
        end
        if confirmedAction and confirmedAction.serial < serial then
            if confirmedAction.track and confirmedAction.track.IsPlaying
                and (not predicted or predicted.track ~= confirmedAction.track) then
                if confirmedAction.name:sub(1, 4) == "Roll" then confirmedAction.track:AdjustSpeed(1)
                else confirmedAction.track:Stop(.08) end
            end
            confirmedAction = nil
        end
        script:SetAttribute("AnimationPhaseCorrection", "ExpiredIgnored")
        if firstR1Input and metadata.sequence == firstR1Input.sequence then
            firstR1Input, comboBuffer, comboRequest = nil, nil, nil
            comboSubmitted = false
        end
        return
    end
    local preservePrediction = matched and pending.track and pending.track.IsPlaying
    localAction = {name = semantic, serial = serial, ends = os.clock() + action.duration - elapsed}
    if semantic ~= "SwordR1_1" or not firstR1Input or metadata.sequence ~= firstR1Input.sequence then
        comboSubmitted = false
        firstR1Input, comboBuffer, comboRequest = nil, nil, nil
    end
    local track = playAction(semantic, not preservePrediction)
    confirmedAction = {name = semantic, serial = serial, started = started,
        track = track, seekInitial = not preservePrediction}
    alignConfirmed(confirmedAction)
end)

RunService:BindToRenderStep("CombatFoundationController", Enum.RenderPriority.Character.Value + 1, function(dt)
    if destroyed or not humanoid or humanoid.Health <= 0 or not root then return end
    camera = workspace.CurrentCamera or camera
    if predicted and os.clock() >= predicted.deadline then
        local pending = predicted
        -- The bounded timeout releases input. It never cuts a full roll or
        -- abruptly removes a sword pose; a held preview can finish smoothly.
        if pending.track and pending.track == actionTrack and pending.track.IsPlaying
            and (not confirmedAction or confirmedAction.track ~= pending.track) then
            pending.track:AdjustSpeed(1)
            if localAction == pending.localAction then
                local action = Config.Actions[pending.name]
                local remaining = math.max(0, (action and action.duration or 0) - pending.track.TimePosition)
                localAction = {name = pending.name, ends = os.clock() + remaining}
            end
        elseif localAction == pending.localAction then
            localAction = nil
        end
        predicted = nil
        script:SetAttribute("PredictionStatus", "TimedOut")
    end
    if confirmedAction then alignConfirmed(confirmedAction) end
    dispatchCombo()
    local state = character:GetAttribute("CombatState")
    if rolling() and actionTrack then
        -- Suppress emotes/foreign action tracks while this complete roll is playing.
        for _, other in animator:GetPlayingAnimationTracks() do
            if other ~= actionTrack and other.Priority ~= Enum.AnimationPriority.Core
                and other.Priority.Value >= Enum.AnimationPriority.Action.Value then other:Stop(0) end
        end
    end
    local block = tracks.Block
    if block then
        if state == "Blocking" and not block.IsPlaying then playAction("Block")
        elseif state ~= "Blocking" and block.IsPlaying then block:Stop(.12) end
    end
    if target and not player:GetAttribute("CombatSettingsOpen") then
        local enemyHumanoid = target:FindFirstChildOfClass("Humanoid")
        local enemyRoot = target:FindFirstChild("HumanoidRootPart")
        if not enemyHumanoid or enemyHumanoid.Health <= 0 or not enemyRoot or (enemyRoot.Position - root.Position).Magnitude > Config.TargetLossRange then
            setLock(nil)
        else
            if targetVisible(target) then
                occludedSince = nil
            else
                occludedSince = occludedSince or os.clock()
                if os.clock() - occludedSince > 0.75 then setLock(nil) end
            end
        end
        if target then
            ensureFacing()
            local delta = enemyRoot.Position - root.Position
            local flat = Vector3.new(delta.X, 0, delta.Z)
            if flat.Magnitude > 0.2 then
                local state = character:GetAttribute("CombatState")
                local action = state == "AttackStartup" or state == "AttackActive" or state == "AttackRecovery"
                facingAlign.Enabled = not rolling()
                local facingAction = localAction and Config.Actions[localAction.name]
                facingAlign.MaxAngularVelocity = math.rad(action and (facingAction and facingAction.turnRate or Config.Actions.SwordR1_1.turnRate) or 180)
                facingAlign.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
                humanoid.AutoRotate = false
                local desiredPosition = root.Position - flat.Unit * 12 + Vector3.new(0, 5, 0)
                local lookAt = root.Position:Lerp(enemyRoot.Position, 0.45) + Vector3.new(0, 2, 0)
                camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(desiredPosition, lookAt), 1 - math.exp(-dt * 7))
            end
        end
    end
    -- PlayerModule remains the sole source of movement when unlocked. Lock-on
    -- supplies directional Move() only, with gradual input magnitude changes.
    if target then
        local f = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
        local r = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
        local desired = Vector3.new(r, 0, -f)
        if desired.Magnitude > 1 then desired = desired.Unit end
        moveVector = moveVector:Lerp(desired, 1 - math.exp(-dt * (desired.Magnitude > 0 and 8 or 12)))
        if moveVector.Magnitude < 0.01 then moveVector = Vector3.zero end
        if character:GetAttribute("CombatState") == "Rolling" then moveVector = Vector3.zero end
        humanoid:Move(moveVector, true)
    end
    local idle = tracks.CombatIdle
    if idle then
        local standing = humanoid.MoveDirection.Magnitude < 0.05
            and humanoid.FloorMaterial ~= Enum.Material.Air
        if standing and not idle.IsPlaying then idle:Play(0.15)
        elseif not standing and idle.IsPlaying then idle:Stop(0.15) end
    end
end)

connectLifetime(player.CharacterAdded, bindCharacter)
connectLifetime(player.CharacterAppearanceLoaded, function(loadedCharacter)
    if player.Character == loadedCharacter then bindCharacter(loadedCharacter) end
end)
script.Destroying:Connect(function()
    if destroyed then return end
    -- Best-effort release while the owned client and its remote still exist.
    if remote.Parent then
        pcall(function()
            send("BlockEnd")
            send("SprintEnd")
        end)
    end
    destroyed = true
    characterVersion += 1
    for _, connection in lifetimeConnections do connection:Disconnect() end
    table.clear(lifetimeConnections)
    for _, name in Bindings.Order do ContextActionService:UnbindAction(name) end
    RunService:UnbindFromRenderStep("CombatFoundationController")
    if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
    disconnectTracks()
    clearFacing()
    if type(observer.destroy) == "function" then observer:destroy() end
end)
if player.Character then task.spawn(bindCharacter, player.Character) end
