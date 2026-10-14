-- Client Play: observe real game input against CombatQA_Dummy for 8 seconds.
-- Damage is server-produced; the monitor never applies damage or moves actors.
local player = game.Players.LocalPlayer
local character = player.Character
local target = workspace:WaitForChild("CombatQA_Dummy")
local visual = require(game.ReplicatedStorage.CombatFoundation.Shared.WeaponVisualConfig)
local blade = character:WaitForChild("CombatTestSword"):FindFirstChildWhichIsA("MeshPart", true)
local result = player.PlayerGui:FindFirstChild("CombatTargetObservation")
if result then result:Destroy() end
result = Instance.new("StringValue")
result.Name, result.Parent = "CombatTargetObservation", player.PlayerGui
local function intersects(a, b, cf, size)
    a, b = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
    local d, lo, hi = b-a, 0, 1
    for _, axis in {"X", "Y", "Z"} do
        local e = size[axis]/2 + .18
        if math.abs(d[axis]) < 1e-8 then
            if math.abs(a[axis]) > e then return false end
        else
            local x, y = (-e-a[axis])/d[axis], (e-a[axis])/d[axis]
            if x > y then x,y=y,x end
            lo,hi=math.max(lo,x),math.min(hi,y)
            if lo>hi then return false end
        end
    end
    return true
end
task.spawn(function()
    local report = {healthStart = target.Humanoid.Health, damageEvents = {}, swingFrames = 0,
        visibleBladeContactFrames = 0, initialDistance = (target.HumanoidRootPart.Position-character.HumanoidRootPart.Position).Magnitude}
    local latest = nil
    local healthConnection = target.Humanoid.HealthChanged:Connect(function(health)
        table.insert(report.damageEvents, {health = health, sample = latest})
    end)
    local deadline = os.clock()+8
    while os.clock()<deadline do
        game.RunService.Heartbeat:Wait()
        local a = blade.CFrame:PointToWorldSpace(Vector3.new(0,-.635*visual.MeshScale.Y,0))
        local b = blade.CFrame:PointToWorldSpace(Vector3.new(0,2.355*visual.MeshScale.Y,0))
        local contact = false
        for _, part in target:GetChildren() do
            if part:IsA("BasePart") and part.Name~="HumanoidRootPart" and intersects(a,b,part.CFrame,part.Size) then contact=true; break end
        end
        local name,time,speed=nil,nil,nil
        for _, track in character.Humanoid.Animator:GetPlayingAnimationTracks() do
            if track.Name:sub(1,5)=="Sword" and track.WeightCurrent>.5 then name,time,speed=track.Name,track.TimePosition,track.Speed; break end
        end
        latest = {contact = contact, animation = name, time = time, speed = speed,
            state = character:GetAttribute("CombatState"), stamina = character:GetAttribute("Stamina"),
            distance = (target.HumanoidRootPart.Position-character.HumanoidRootPart.Position).Magnitude}
        if name then
            report.swingFrames += 1
            if contact then report.visibleBladeContactFrames += 1 end
        end
    end
    healthConnection:Disconnect()
    report.healthEnd=target.Humanoid.Health
    result.Value=game.HttpService:JSONEncode(report)
end)
return "8-second native target observation started"
