-- Runs for every visible equipped avatar, so corrections are rendered by each
-- observer. Joint Transform is evaluated after Animator, per Roblox guidance.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local root = game.ReplicatedStorage:WaitForChild("CombatFoundation")
local Solver = require(root.Shared:WaitForChild("BladeClearance"))
local Ground = require(root.Shared:WaitForChild("AvatarGroundClearance"))
local order = {"LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
local models = {}
local function register(character)
    if models[character] then return end
    local pending = {ready = false}
    models[character] = pending
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 8)
        local hand = character:WaitForChild("RightHand", 8)
        if models[character] ~= pending then return end
        if not humanoid or not hand then models[character] = nil; return end
        -- Weapon appears only after the server completes appearance application.
        local sword = character:WaitForChild("CombatTestSword", 12)
        if models[character] ~= pending then return end
        if not sword or not character.Parent then models[character] = nil; return end
        local joints = {}
        for _, joint in character:GetDescendants() do
            if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
                local p0, p1 = joint.Part0, joint.Part1
                if p0 and p1 then joints[p1.Name] = {parent = p0.Name, c0 = joint.C0, c1 = joint.C1, size = p1.Size, instance = joint} end
            end
        end
        for _, name in order do if not joints[name] then models[character] = nil; return end end
        pending.joints, pending.humanoid, pending.ready = joints, humanoid, true
    end)
end
local function watch(player)
    player.CharacterAdded:Connect(register)
    player.CharacterAppearanceLoaded:Connect(function(character)
        models[character] = nil
        register(character)
    end)
    player.CharacterRemoving:Connect(function(character) models[character] = nil end)
    if player.Character then register(player.Character) end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do watch(player) end
RunService.PreAnimation:Connect(function()
    -- Remove our last overlay before Animator evaluates, including paused tracks.
    for character, data in models do
        if not character.Parent then models[character] = nil
        elseif data.ready and data.raw then
            local joint = data.joints.RightUpperArm.instance
            if joint.Parent then joint.Transform = data.raw end
            if data.rawWrist and data.joints.RightHand.instance.Parent then data.joints.RightHand.instance.Transform = data.rawWrist end
            if data.rawRoot and data.joints.LowerTorso.instance.Parent then data.joints.LowerTorso.instance.Transform = data.rawRoot end
            data.raw = nil
            data.rawWrist = nil
            data.rawRoot = nil
        end
    end
end)
RunService.PreSimulation:Connect(function()
    for character, data in models do
        if not data.ready or data.humanoid.Health <= 0 then continue end
        local animator = data.humanoid:FindFirstChildOfClass("Animator")
        if not animator or animator.EvaluationThrottled then continue end
        if not character:FindFirstChild("CombatTestSword") then continue end
        local frames, poses = {HumanoidRootPart = CFrame.new()}, {}
        local valid = true
        for _, name in order do
            local j = data.joints[name]
            if not j.instance.Parent then valid = false; break end
            j.c0, j.c1 = j.instance.C0, j.instance.C1
            j.size = character[name].Size
            poses[name] = {CFrame = j.instance.Transform}
            frames[name] = frames[j.parent] * j.c0 * poses[name].CFrame * j.c1:Inverse()
        end
        if not valid then models[character] = nil; continue end
        local original = poses.RightUpperArm.CFrame
        local originalWrist = poses.RightHand.CFrame
        data.previous = Solver.correct(poses, data.joints, frames, data.previous, true)
        data.raw = original
        data.rawWrist = originalWrist
        data.joints.RightUpperArm.instance.Transform = poses.RightUpperArm.CFrame
        data.joints.RightHand.instance.Transform = poses.RightHand.CFrame
        local state = character:GetAttribute("CombatState")
        if state ~= "Idle" and state ~= "Moving" and state ~= "Sprinting" and state ~= "Dead" then
            local lift = Ground.lift(frames, data.joints, data.humanoid.HipHeight, character.HumanoidRootPart.Size)
            local j = data.joints.LowerTorso
            data.rawRoot = j.instance.Transform
            local offset = j.c0.Rotation:VectorToObjectSpace(Vector3.new(0, lift, 0))
            j.instance.Transform = CFrame.new(data.rawRoot.Position + offset) * data.rawRoot.Rotation
        end
        if character:GetAttribute("VisualBladeUnresolved") ~= data.previous.unresolved then
            character:SetAttribute("VisualBladeUnresolved", data.previous.unresolved)
        end
    end
end)
