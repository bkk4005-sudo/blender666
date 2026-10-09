local Http=game:GetService("HttpService")
local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local function fetch(n) return Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/"..n)) end
    local project=fetch("project.json")
    local rig=workspace.blender666.AshenOathPreview
    local animator=rig.AnimationController.Animator
    local motors={}
    for _,m in ipairs(rig:GetDescendants()) do if m:IsA("Motor6D") then motors[m.Name]=m end end
    local sequences=game:GetService("ServerStorage").blender666.Animations.AshenOath
    local provider=game:GetService("KeyframeSequenceProvider")
    local report={clips={},issues={},mode="Studio Server Play Test"}
    for _,name in ipairs(project.animations) do
        local data=fetch("animation_"..name..".json")
        local animation=Instance.new("Animation");animation.Name="TransferTest_"..name
        animation.AnimationId=provider:RegisterKeyframeSequence(sequences[name])
        local track=animator:LoadAnimation(animation);track:Play(0,1,0)
        task.wait(.08)
        local sample=data.frames[math.max(1,math.floor(#data.frames/2))]
        track.TimePosition=sample.time
        task.wait(.08)
        local maxError=0
        for poseName,components in pairs(sample.poses) do
            local actual={motors[poseName].Transform:GetComponents()}
            for i,value in ipairs(components) do maxError=math.max(maxError,math.abs(actual[i]-value)) end
        end
        local expectedLength=data.duration
        for _,time in pairs(data.events) do expectedLength=math.max(expectedLength,time) end
        local valid=track.IsPlaying and math.abs(track.Length-expectedLength)<.001 and maxError<.002
        table.insert(report.clips,{name=name,length=track.Length,expectedLength=expectedLength,sampleTime=sample.time,isPlaying=track.IsPlaying,weight=track.WeightCurrent,maxMotorError=maxError,passed=valid})
        if not valid then table.insert(report.issues,name) end
        track:Stop(0);track:Destroy();animation:Destroy()
        task.wait()
    end
    local name="Light_01";local data=fetch("animation_"..name..".json")
    local animation=Instance.new("Animation");animation.AnimationId=provider:RegisterKeyframeSequence(sequences[name])
    local track=animator:LoadAnimation(animation);local received={};local connections={}
    for marker,time in pairs(data.events) do
        table.insert(connections,track:GetMarkerReachedSignal(marker):Connect(function() received[marker]=true end))
    end
    track:Play(0);task.wait(data.duration+.15)
    local missed={};for marker in pairs(data.events) do if not received[marker] then table.insert(missed,marker) end end
    for _,connection in ipairs(connections) do connection:Disconnect() end
    report.markerTest={clip=name,received=received,missed=missed}
    track:Stop(0);track:Destroy();animation:Destroy()
    local players=game:GetService("Players"):GetPlayers()
    if players[1] and players[1].Character then players[1].Character:PivotTo(CFrame.new(0,36,-8)) end
    Http:PostAsync("http://127.0.0.1:8766/save/playtest.json",Http:JSONEncode(report),Enum.HttpContentType.ApplicationJson)
    return {clips=#report.clips,issues=report.issues,markerTest=report.markerTest}
end)
Http.HttpEnabled=oldHttp
if not ok then error(result) end
return result
