-- Rebuild in detached state; never move individual parts of a connected assembly.
local Http=game:GetService("HttpService")
local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local function fetch(n) return Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/"..n)) end
    local project,definition,idle=fetch("project.json"),fetch("rig.json"),fetch("animation_Idle.json")
    local store=game:GetService("ServerStorage").blender666
    assert(not store:FindFirstChild("BeforeRigCorrection"),"Correction already applied")
    local backup=Instance.new("Folder");backup.Name="BeforeRigCorrection";backup.Parent=store
    local template=store.Assets.AshenOath_R15
    template:Clone().Parent=backup
    local sequences=store.Animations.AshenOath
    sequences:Clone().Parent=backup
    local originalPreview=workspace.blender666.AshenOathPreview
    originalPreview:Clone().Parent=backup
    local corrected=template:Clone();corrected.Parent=nil
    local body={}
    for _,p in ipairs(corrected:GetDescendants()) do
        if p:IsA("JointInstance") then p:Destroy()
        elseif p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.Massless=true end
    end
    for _,e in ipairs(project.meshes) do if e.category=="Mannequin" then
        body[e.name]=assert(corrected:FindFirstChild(e.name));body[e.name].CFrame=CFrame.new(unpack(e.cframe))
    end end
    local root=corrected.HumanoidRootPart;body.HumanoidRootPart=root
    root.CFrame=CFrame.new(unpack(definition.rootRest));corrected.PrimaryPart=root
    local basis,pose,motors={},{HumanoidRootPart=root.CFrame},{}
    for _,j in ipairs(definition.joints) do
        basis[j.name]=CFrame.new(unpack(idle.frames[1].poses[j.name]))
        local c0=CFrame.new(unpack(j.c0))*basis[j.name];local c1=CFrame.new(unpack(j.c1))
        pose[j.name]=pose[j.parent]*c0*c1:Inverse();body[j.name].CFrame=pose[j.name]
        local m=Instance.new("Motor6D");m.Name=j.name;m.C0=c0;m.C1=c1
        m.Part0=body[j.parent];m.Part1=body[j.name];m.Parent=body[j.parent];motors[j.name]=m
    end
    -- Fold the standing guard into C0. Every clip is rebased to preserve its exact world motion.
    for _,sequence in ipairs(sequences:GetChildren()) do if sequence:IsA("KeyframeSequence") then
        for _,p in ipairs(sequence:GetDescendants()) do if p:IsA("Pose") and basis[p.Name] then p.CFrame=basis[p.Name]:Inverse()*p.CFrame end end
        sequence:SetAttribute("RigBasis","IdleGuard_v2")
    end end
    local sword=corrected.AshenOath_Greatsword;local blade=sword.PrimaryPart
    local swordOffset=CFrame.new(0,1.195,0)
    local grip=pose.RightHand:Inverse()*CFrame.new(unpack(idle.frames[1].prop))*swordOffset
    blade.CFrame=pose.RightHand*grip
    local weld=Instance.new("Weld");weld.Name="RightGrip";weld.Part0=body.RightHand;weld.Part1=blade
    weld.C0=grip;weld.C1=CFrame.identity;weld.Parent=body.RightHand
    for _,a in ipairs(blade:GetChildren()) do if a:IsA("Attachment") then
        local positions={RightGrip=Vector3.zero,LeftGrip=Vector3.new(0,-.53,0),BladeBase=Vector3.new(0,.56,0),BladeTip=Vector3.new(0,3.55,0)}
        if positions[a.Name] then a.CFrame=swordOffset:Inverse()*CFrame.new(positions[a.Name]) end
    end end
    local footMin=math.huge;local footMins={}
    for _,e in ipairs(project.meshes) do if e.name=="LeftFoot" or e.name=="RightFoot" then
        local data=fetch(e.id..".json");local minimum=math.huge
        for _,v in ipairs(data.vertices) do minimum=math.min(minimum,(pose[e.name]*Vector3.new(unpack(v))).Y) end
        footMins[e.name]=minimum;footMin=math.min(footMin,minimum)
    end end
    corrected:SetAttribute("RigBasis","IdleGuard_v2");corrected:SetAttribute("StandingFootMin",footMin)
    corrected:SetAttribute("Purpose","Training mannequin with corrected R15 joints and standing guard")
    for _,p in ipairs(corrected:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=p==root end end
    template.Parent=backup;corrected.Name="AshenOath_R15";corrected.Parent=store.Assets
    local preview=corrected:Clone();preview.Name="AshenOathPreview"
    preview:PivotTo(CFrame.new(0,32.17-footMin,0)*CFrame.new(unpack(definition.rootRest)))
    preview.Parent=workspace.blender666;originalPreview.Parent=backup
    return {joints=15,clips=34,footMin=footMin,feet=footMins,root={preview.HumanoidRootPart.CFrame:GetComponents()},basis="IdleGuard_v2"}
end)
Http.HttpEnabled=oldHttp
if not ok then error(result) end
return result
