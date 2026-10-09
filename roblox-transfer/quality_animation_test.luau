local Http=game:GetService("HttpService");local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local function fetch(n) return Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/"..n)) end
    local project,definition,idle=fetch("project.json"),fetch("rig.json"),fetch("animation_Idle.json")
    local rig=workspace.blender666.AshenOathPreview;local animator=rig.AnimationController.Animator
    local motors={};for _,m in ipairs(rig:GetDescendants()) do if m:IsA("Motor6D") then motors[m.Name]=m end end
    local provider=game:GetService("KeyframeSequenceProvider");local report={clips={},issues={}}
    local rootBefore=rig.HumanoidRootPart.CFrame
    for _,name in ipairs(project.animations) do
        local data=fetch("animation_"..name..".json")
        local a=Instance.new("Animation");a.AnimationId=provider:RegisterKeyframeSequence(game.ServerStorage.blender666.Animations.AshenOath[name])
        local track=animator:LoadAnimation(a);track:Play(0,1,0);task.wait(.05)
        local clip={name=name,length=track.Length,maxJointError=0,maxBodyError=0,maxRotationError=0,maxRootDrift=0,samples=0}
        for _,fraction in ipairs({.05,.25,.5,.75,.95}) do
            local frame=data.frames[math.clamp(math.floor((#data.frames-1)*fraction)+1,1,#data.frames)]
            track.TimePosition=frame.time;task.wait(.055)
            local pose={HumanoidRootPart=rootBefore}
            for _,j in ipairs(definition.joints) do
                local expected=CFrame.new(unpack(idle.frames[1].poses[j.name])):Inverse()*CFrame.new(unpack(frame.poses[j.name]))
                local m=motors[j.name];pose[j.name]=pose[j.parent]*m.C0*expected*m.C1:Inverse()
                local errorPose=pose[j.name]:Inverse()*m.Part1.CFrame;local _,angle=errorPose:ToAxisAngle()
                clip.maxBodyError=math.max(clip.maxBodyError,errorPose.Position.Magnitude)
                clip.maxRotationError=math.max(clip.maxRotationError,math.abs(angle))
                clip.maxJointError=math.max(clip.maxJointError,((m.Part0.CFrame*m.C0*m.Transform).Position-(m.Part1.CFrame*m.C1).Position).Magnitude)
            end
            clip.maxRootDrift=math.max(clip.maxRootDrift,(rig.HumanoidRootPart.Position-rootBefore.Position).Magnitude)
            clip.samples+=1
        end
        clip.passed=clip.maxBodyError<.003 and clip.maxRotationError<.003 and clip.maxJointError<.003 and clip.maxRootDrift<.003
        if not clip.passed then table.insert(report.issues,name) end
        table.insert(report.clips,clip);track:Stop(0);track:Destroy();a:Destroy();task.wait()
    end
    Http:PostAsync("http://127.0.0.1:8766/save/quality_animation_test.json",Http:JSONEncode(report),Enum.HttpContentType.ApplicationJson)
    return {clips=#report.clips,samples=170,issues=report.issues,rootUp={rootBefore.UpVector.X,rootBefore.UpVector.Y,rootBefore.UpVector.Z}}
end)
Http.HttpEnabled=oldHttp;if not ok then error(result) end;return result
