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
local PreviewRetarget = require(shared:WaitForChild("R15PreviewRetarget"))
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

local function disconnectTracks()
    for _, connection in trackConnections do connection:Disconnect() end
    table.clear(trackConnections)
    for _, track in tracks do track:Stop(0); track:Destroy() end
    table.clear(tracks)
    for _, sequence in previewSequences do sequence:Destroy() end
    table.clear(previewSequences)
    actionTrack = nil
    predicted = nil
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

local function playAction(semantic)
    local track = loadTrack(semantic)
    if not track then return end
    if actionTrack and actionTrack ~= track then actionTrack:Stop(0.12) end
    actionTrack = track
    if not track.IsPlaying then track:Play(0.10, 1, 1) end
end

local function send(kind, direction, predictedName, moveDirection)
    inputSequence += 1
    remote:FireServer({kind = kind, direction = direction, moveDirection = moveDirection, sequence = inputSequence})
    if predictedName then
        predicted = {name = predictedName, deadline = os.clock() + 0.38}
        playAction(predictedName)
    end
end

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
    characterVersion += 1
    local version = characterVersion
    if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
    disconnectTracks()
    setLock(nil)
    character = newCharacter
    humanoid, root, animator = nil, nil, nil
    -- Appearance application can rebuild the joints/Animator after CharacterAdded.
    -- Preview geometry and tracks must be cached on the completed avatar.
    local deadline = os.clock() + 8
    while player.Character == newCharacter and not player:HasAppearanceLoaded()
        and os.clock() < deadline do RunService.Heartbeat:Wait() end
    if version ~= characterVersion or player.Character ~= newCharacter then return end
    humanoid = character:WaitForChild("Humanoid")
    root = character:WaitForChild("HumanoidRootPart")
    animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
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
    if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
    if not humanoid or humanoid.Health <= 0 then return Enum.ContextActionResult.Sink end
    if actionName == "CombatR1" and inputState == Enum.UserInputState.Begin then
        local current = character:GetAttribute("CombatState")
        local predictedName = current == "AttackRecovery" and "SwordR1_2" or "SwordR1_1"
        send("R1", nil, predictedName)
    elseif actionName == "CombatR2" and inputState == Enum.UserInputState.Begin then
        send("R2", nil, "SwordR2")
    elseif actionName == "CombatRoll" and inputState == Enum.UserInputState.Begin then
        local name, worldDirection = rollDirection()
        send("Roll", name, name, worldDirection)
    elseif actionName == "CombatBlock" then
        if inputState == Enum.UserInputState.Begin then send("BlockStart")
        elseif inputState == Enum.UserInputState.End then send("BlockEnd") end
    elseif actionName == "CombatParry" and inputState == Enum.UserInputState.Begin then
        send("Parry", nil, "Parry")
    elseif actionName == "CombatSprint" then
        if inputState == Enum.UserInputState.Begin then send("SprintStart")
        elseif inputState == Enum.UserInputState.End then send("SprintEnd") end
    elseif actionName == "CombatLock" and inputState == Enum.UserInputState.Begin then
        setLock(target and nil or chooseTarget())
    end
    return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("CombatR1", handleInput, false, Enum.UserInputType.MouseButton1)
ContextActionService:BindAction("CombatR2", handleInput, false, Enum.UserInputType.MouseButton2)
ContextActionService:BindAction("CombatRoll", handleInput, false, Enum.KeyCode.Space)
ContextActionService:BindAction("CombatBlock", handleInput, false, Enum.KeyCode.F)
ContextActionService:BindAction("CombatParry", handleInput, false, Enum.KeyCode.E)
ContextActionService:BindAction("CombatSprint", handleInput, false, Enum.KeyCode.LeftShift)
ContextActionService:BindAction("CombatLock", handleInput, false, Enum.KeyCode.Q)

remote.OnClientEvent:Connect(function(kind, owner, semantic)
    if kind == "Started" and owner == player then
        predicted = nil
        playAction(semantic)
    end
end)

RunService:BindToRenderStep("CombatFoundationController", Enum.RenderPriority.Character.Value + 1, function(dt)
    if not humanoid or humanoid.Health <= 0 or not root then return end
    camera = workspace.CurrentCamera or camera
    if predicted and os.clock() >= predicted.deadline then
        if actionTrack then actionTrack:Stop(0.10) end
        predicted = nil
    end
    if target then
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
                facingAlign.MaxAngularVelocity = math.rad(action and 75 or 180)
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

player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end
