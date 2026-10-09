-- MCP sets firstClip and lastClip before this code. Source .blend baked frames are authoritative.
local Http=game:GetService("HttpService")
local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local project=Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/project.json"))
    local rig=Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/rig.json"))
    local destination=game:GetService("ServerStorage").blender666.Animations.AshenOath
    local results={}
    for index=firstClip,lastClip do
        local name=project.animations[index]
        assert(not destination:FindFirstChild(name),"Animation already exists: "..name)
        local d=Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/animation_"..name..".json"))
        local sequence=Instance.new("KeyframeSequence");sequence.Name=name;sequence.Loop=d.loop
        sequence.Priority=d.kind=="idle" and Enum.AnimationPriority.Idle or
            (string.find(d.kind,"walk") or d.kind=="run") and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Action
        sequence:SetAttribute("SourceRelativePath","AshenColiseum/Weapons/AshenGreatsword/exports/animations/"..name..".fbx")
        sequence:SetAttribute("Duration",d.duration);sequence:SetAttribute("FPS",30)
        sequence:SetAttribute("LocalOnly",true);sequence.Parent=destination
        local keys={}
        local propFrames={}
        for frameIndex,frame in ipairs(d.frames) do
            local key=Instance.new("Keyframe");key.Name=string.format("Frame_%04d",frameIndex);key.Time=frame.time
            local root=Instance.new("Pose");root.Name="HumanoidRootPart";root.CFrame=CFrame.identity;root.Parent=key
            local poses={HumanoidRootPart=root}
            for _,joint in ipairs(rig.joints) do
                local p=Instance.new("Pose");p.Name=joint.name;p.CFrame=CFrame.new(unpack(frame.poses[joint.name]))
                p.EasingStyle=Enum.PoseEasingStyle.Linear;p.EasingDirection=Enum.PoseEasingDirection.InOut
                poses[joint.name]=p
            end
            for _,joint in ipairs(rig.joints) do poses[joint.name].Parent=poses[joint.parent] end
            key.Parent=sequence;keys[frameIndex]=key
            table.insert(propFrames,{time=frame.time,cframe=frame.prop})
            if frameIndex%20==0 then task.wait() end
        end
        local eventCount=0
        for markerName,time in pairs(d.events) do
            local key
            for _,candidate in ipairs(keys) do if math.abs(candidate.Time-time)<.000001 then key=candidate;break end end
            if not key then key=Instance.new("Keyframe");key.Name="Event_"..markerName;key.Time=time;key.Parent=sequence end
            local marker=Instance.new("KeyframeMarker");marker.Name=markerName;marker.Value="";marker.Parent=key;eventCount+=1
        end
        local prop=Instance.new("StringValue");prop.Name="PairedPropMotion";prop.Value=Http:JSONEncode(propFrames);prop.Parent=sequence
        table.insert(results,{name=name,frames=#d.frames,markers=eventCount})
        task.wait()
    end
    return results
end)
Http.HttpEnabled=oldHttp
return Http:JSONEncode({ok=ok,result=ok and result or tostring(result),httpRestored=Http.HttpEnabled==oldHttp})
