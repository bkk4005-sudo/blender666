-- Server-owned authored blade path. Never reads client joint Transform,
-- AnimationTrack time, hit reports or damage requests.
local Shared = game.ReplicatedStorage.CombatFoundation.Shared
local Retarget = require(Shared.R15PreviewRetarget)
local Visual = require(Shared.WeaponVisualConfig)
local Trajectory = {}
local order = {"LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot"}

function Trajectory.build(character, source, yieldEvery)
    local joints = {}
    for _, joint in character:GetDescendants() do
        if joint:IsA("Motor6D") then
            local p0,p1=joint.Part0,joint.Part1
            if p0 and p1 then joints[p1.Name]={parent=p0.Name,c0=joint.C0,c1=joint.C1} end
        elseif joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
            local a0,a1=joint.Attachment0,joint.Attachment1
            joints[a1.Parent.Name]={parent=a0.Parent.Name,c0=a0.CFrame,c1=a1.CFrame}
        end
    end
    for _, name in order do assert(joints[name], "Blade trajectory requires R15 joint "..name) end
    local sequence = Retarget.bakeForRig(source, character, yieldEvery)
    local height = sequence.SourceAuthoredHipHeight.Value
    local scale = height>.01 and character.Humanoid.HipHeight/height or 1
    local grip = Visual.forCharacter(character) * CFrame.new(Visual.SourceGrip.Position*Visual.MeshScale):Inverse()
    local samples={}
    local keys=sequence:GetKeyframes()
    table.sort(keys,function(a,b) return a.Time<b.Time end)
    for _, key in keys do
        local poses={}
        for _, item in key:GetDescendants() do if item:IsA("Pose") then poses[item.Name]=item.CFrame end end
        local frames={HumanoidRootPart=CFrame.new()}
        for _, name in order do
            local j, pose = joints[name], poses[name]
            if name=="LowerTorso" then pose=CFrame.new(pose.Position*scale)*pose.Rotation end
            frames[name]=frames[j.parent]*j.c0*pose*j.c1:Inverse()
        end
        local sword=frames.RightHand*grip
        table.insert(samples,{time=key.Time,
            base=sword:PointToWorldSpace(Vector3.new(0,-.635*Visual.MeshScale.Y,0)),
            tip=sword:PointToWorldSpace(Vector3.new(0,2.355*Visual.MeshScale.Y,0))})
    end
    sequence:Destroy()
    return samples
end

function Trajectory.sample(samples,time)
    if time<=samples[1].time then return samples[1].base,samples[1].tip end
    if time>=samples[#samples].time then return samples[#samples].base,samples[#samples].tip end
    local lo,hi=1,#samples
    while hi-lo>1 do
        local mid=math.floor((lo+hi)/2)
        if samples[mid].time<=time then lo=mid else hi=mid end
    end
    local a,b=samples[lo],samples[hi]
    local alpha=(time-a.time)/(b.time-a.time)
    return a.base:Lerp(b.base,alpha),a.tip:Lerp(b.tip,alpha)
end

local function intersection(a,b,cf,size,radius)
    a,b=cf:PointToObjectSpace(a),cf:PointToObjectSpace(b)
    local d,lo,hi=b-a,0,1
    for _, axis in {"X","Y","Z"} do
        local e=size[axis]/2+radius
        if math.abs(d[axis])<1e-8 then
            if math.abs(a[axis])>e then return nil end
        else
            local x,y=(-e-a[axis])/d[axis],(e-a[axis])/d[axis]
            if x>y then x,y=y,x end
            lo,hi=math.max(lo,x),math.min(hi,y)
            if lo>hi then return nil end
        end
    end
    return cf:PointToWorldSpace(a+d*lo)
end

function Trajectory.query(character,a,b,previousA,previousB,radius)
    previousA,previousB=previousA or a,previousB or b
    local low=Vector3.new(math.min(a.X,b.X,previousA.X,previousB.X),math.min(a.Y,b.Y,previousA.Y,previousB.Y),math.min(a.Z,b.Z,previousA.Z,previousB.Z))
    local high=Vector3.new(math.max(a.X,b.X,previousA.X,previousB.X),math.max(a.Y,b.Y,previousA.Y,previousB.Y),math.max(a.Z,b.Z,previousA.Z,previousB.Z))
    local params=OverlapParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={character}
    local found={}
    local midA,midB=previousA:Lerp(a,.5),previousB:Lerp(b,.5)
    -- Tip travel is a swept contact test, but visibility still originates at
    -- the blade base. A zero-length tip sample inside a body must not bypass
    -- cover by tracing only from the character root directly to that tip.
    local segments={{a,b},{previousA,previousB},{midA,midB},{previousA,a},{previousB,b,previousA}}
    for _, part in workspace:GetPartBoundsInBox(CFrame.new((low+high)/2),high-low+Vector3.one*(radius*2),params) do
        -- Ignore accessories, weapons and invisible root collision proxies.
        local model=part.Parent
        if not model or not model:IsA("Model") or part.Name=="HumanoidRootPart" then continue end
        local humanoid=model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health>0 then
            for _, segment in segments do
                local contact=intersection(segment[1],segment[2],part.CFrame,part.Size,radius)
                if contact then
                    found[humanoid]=found[humanoid] or {}
                    table.insert(found[humanoid],{part=part,origin=segment[3] or segment[1],contact=contact})
                end
            end
        end
    end
    return found
end
return Trajectory
