local Http=game:GetService("HttpService")
local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local function fetch(n) return Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/"..n)) end
    local project=fetch("project.json");local definition=fetch("rig.json");local idle=fetch("animation_Idle.json")
    local assets=game:GetService("ServerStorage").blender666.Assets
    assert(not assets:FindFirstChild("AshenOath_R15"),"Rig destination exists")
    local model=assert(workspace:FindFirstChild("AshenOath_Mannequin_Studio"),"Body import not finished")
    local parts={};for _,p in ipairs(model:GetDescendants()) do if p:IsA("MeshPart") then parts[p.Name]=p end end
    model:PivotTo(CFrame.Angles(0,math.pi,0))
    model.Name="AshenOath_R15";model:SetAttribute("SourceRelativePath","AshenColiseum/Weapons/AshenGreatsword/AshenOath_R15.blend")
    model:SetAttribute("Purpose","Original display mannequin; no gameplay controller")
    local realRest,sourceRest,body,records={},{},{},{}
    for _,e in ipairs(project.meshes) do if e.category=="Mannequin" then
        local p=assert(parts[e.id],"Missing body mesh "..e.id);assert(p.MeshId~="","Unpublished body mesh")
        p.Name=e.name;p:SetAttribute("SourceMeshKey",e.id);p.Anchored=false;p.CanCollide=false;p.Massless=true
        assert(p.Size.Magnitude<8,"Body import has incorrect scale")
        local sa=p:FindFirstChildWhichIsA("SurfaceAppearance");assert(sa and sa.ColorMap~="","Body PBR missing")
        realRest[e.name]=p.CFrame;sourceRest[e.name]=CFrame.new(unpack(e.cframe));body[e.name]=p
        table.insert(records,{name=e.name,meshId=p.MeshId,pbr={color=sa.ColorMap,normal=sa.NormalMap,metalness=sa.MetalnessMap,roughness=sa.RoughnessMap}})
    end end
    assert(#records==15,"Incomplete R15 body")
    local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(2,2,1);root.Transparency=1
    root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CFrame=CFrame.new(unpack(definition.rootRest));root.Parent=model
    realRest.HumanoidRootPart=root.CFrame;sourceRest.HumanoidRootPart=root.CFrame;body.HumanoidRootPart=root
    local controller=Instance.new("AnimationController");controller.Name="AnimationController";controller.Parent=model
    local animator=Instance.new("Animator");animator.Parent=controller
    local motors={}
    for _,j in ipairs(definition.joints) do
        local motor=Instance.new("Motor6D");motor.Name=j.name;motor.Part0=body[j.parent];motor.Part1=body[j.name]
        motor.C0=realRest[j.parent]:Inverse()*sourceRest[j.parent]*CFrame.new(unpack(j.c0))
        motor.C1=realRest[j.name]:Inverse()*sourceRest[j.name]*CFrame.new(unpack(j.c1))
        motor.Parent=body[j.parent];motors[j.name]=motor
    end
    local function forward(frame)
        local pose={HumanoidRootPart=root.CFrame}
        for _,j in ipairs(definition.joints) do local m=motors[j.name]
            pose[j.name]=pose[j.parent]*m.C0*CFrame.new(unpack(frame.poses[j.name]))*m.C1:Inverse()
        end
        return pose
    end
    local firstPose=forward(idle.frames[1])
    local propOffset=firstPose.RightHand:Inverse()*CFrame.new(unpack(idle.frames[1].prop))
    local maxPositionError,maxAngleError=0,0
    for _,clip in ipairs(project.animations) do
        local d=fetch("animation_"..clip..".json")
        for i,frame in ipairs(d.frames) do
            local pose=forward(frame);local delta=(pose.RightHand*propOffset):Inverse()*CFrame.new(unpack(frame.prop))
            local _,angle=delta:ToAxisAngle();maxPositionError=math.max(maxPositionError,delta.Position.Magnitude);maxAngleError=math.max(maxAngleError,math.abs(angle))
            if i%50==0 then task.wait() end
        end
    end
    assert(maxPositionError<0.002 and maxAngleError<0.002,"Sword prop is not rigidly attached to right hand")
    local sword=assets.AshenOath_Greatsword:Clone();sword.Name="AshenOath_Greatsword";sword.Parent=model
    local blade=sword.PrimaryPart or sword:FindFirstChildWhichIsA("MeshPart",true)
    local meshOffset=blade.CFrame
    blade.Anchored=false;blade.CanCollide=false;blade.Massless=true
    blade.CFrame=realRest.RightHand*propOffset*meshOffset
    local grip=Instance.new("Weld");grip.Name="RightGrip";grip.Part0=body.RightHand;grip.Part1=blade
    grip.C0=propOffset*meshOffset;grip.C1=CFrame.identity;grip.Parent=body.RightHand
    for name,pos in pairs({RightGrip=Vector3.zero,LeftGrip=Vector3.new(0,-0.53,0),BladeBase=Vector3.new(0,0.56,0),BladeTip=Vector3.new(0,3.55,0)}) do
        local a=Instance.new("Attachment");a.Name=name;a.CFrame=meshOffset:Inverse()*CFrame.new(pos);a.Parent=blade
    end
    model.PrimaryPart=root;model.WorldPivot=CFrame.identity;model.Parent=assets
    local rigData=Instance.new("StringValue");rigData.Name="SourceRigDefinition";rigData.Value=Http:JSONEncode(definition);rigData.Parent=model
    local preview=model:Clone();preview.Name="AshenOathPreview";preview.Parent=workspace.blender666
    for name,cf in pairs(firstPose) do
        local p=preview:FindFirstChild(name);if p and p:IsA("BasePart") then p.CFrame=CFrame.new(0,32,0)*cf end
    end
    for _,p in ipairs(preview:GetDescendants()) do if p:IsA("Motor6D") then p.Transform=CFrame.new(unpack(idle.frames[1].poses[p.Name])) end end
    preview.AshenOath_Greatsword.PrimaryPart.CFrame=CFrame.new(0,32,0)*CFrame.new(unpack(idle.frames[1].prop))*meshOffset
    local output={body=records,joints=15,maxGripPositionError=maxPositionError,maxGripAngleError=maxAngleError}
    Http:PostAsync("http://127.0.0.1:8766/save/rig_import.json",Http:JSONEncode(output),Enum.HttpContentType.ApplicationJson)
    return {body=#records,joints=15,maxGripPositionError=maxPositionError,maxGripAngleError=maxAngleError}
end)
Http.HttpEnabled=oldHttp
if not ok then error(result) end
return result
