local Http=game:GetService("HttpService")
local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local function fetch(n) return Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/"..n)) end
    local project=fetch("project.json");local rig=fetch("rig.json")
    local storage=game:GetService("ServerStorage").blender666
    local root=workspace.blender666;local map=assert(root:FindFirstChild("AshenColiseum"))
    local report={place=game.Name,placeId=game.PlaceId,gameId=game.GameId,meshes={},animations={},issues={}}
    local imported={};for _,p in ipairs(map:GetDescendants()) do if p:IsA("MeshPart") then imported[p:GetAttribute("SourceMeshKey")]=p end end
    local triangles,count,objects=0,0,{}
    for _,e in ipairs(project.meshes) do if e.category=="Map" then
        local p=assert(imported[e.id],"Missing source mesh "..e.id);count+=1;triangles+=e.triangles;objects[e.name]=true
        assert(p.Anchored and p.MeshId~="","Invalid map mesh "..e.id)
        local sa=p:FindFirstChildWhichIsA("SurfaceAppearance")
        assert(sa and sa.ColorMap~="" and sa.NormalMap~="" and sa.MetalnessMap~="" and sa.RoughnessMap~="","Incomplete PBR "..e.id)
        table.insert(report.meshes,{key=e.id,meshId=p.MeshId})
    end end
    local n=0;for _ in pairs(objects) do n+=1 end
    report.map={parts=count,sourceObjects=n,sourceTriangles=triangles}
    assert(count==183 and n==158,"Incomplete map")
    for _,name in ipairs(project.animations) do
        local d=fetch("animation_"..name..".json");local sequence=assert(storage.Animations.AshenOath:FindFirstChild(name))
        assert(sequence.Loop==d.loop,"Loop mismatch "..name)
        local keyByName={};for _,key in ipairs(sequence:GetKeyframes()) do keyByName[key.Name]=key end
        local poses,markers,maxError=0,0,0
        for i,frame in ipairs(d.frames) do
            local key=assert(keyByName[string.format("Frame_%04d",i)],"Missing source frame")
            assert(math.abs(key.Time-frame.time)<0.00001,"Frame time mismatch")
            for _,j in ipairs(rig.joints) do
                local pose=assert(key:FindFirstChild(j.name,true),"Missing R15 pose")
                assert(pose.Parent.Name==j.parent,"Pose hierarchy mismatch")
                local actual={pose.CFrame:GetComponents()};for k,value in ipairs(frame.poses[j.name]) do maxError=math.max(maxError,math.abs(actual[k]-value)) end
                poses+=1
            end
            if i%50==0 then task.wait() end
        end
        assert(maxError<0.0001,"Pose data mismatch "..name)
        for markerName,time in pairs(d.events) do
            local found=false
            for _,key in ipairs(sequence:GetKeyframes()) do
                for _,m in ipairs(key:GetMarkers()) do if m.Name==markerName and math.abs(key.Time-time)<0.00001 then found=true end end
            end
            assert(found,"Missing animation event "..markerName);markers+=1
        end
        local prop=Http:JSONDecode(sequence.PairedPropMotion.Value);assert(#prop==#d.frames,"Missing prop track")
        table.insert(report.animations,{name=name,frames=#d.frames,poses=poses,markers=markers,maxPoseError=maxError})
        task.wait()
    end
    assert(#storage.Animations.AshenOath:GetChildren()==34,"Unexpected animation count")
    local combat=game:GetService("ReplicatedStorage").blender666.Weapons.AshenGreatsword.CombatTimings
    local normalized=string.gsub(combat.Source,"\r\n","\n")
    local sources=fetch("source_bundle.json")
    for _,e in ipairs(sources) do
        local current=storage.SourceFiles
        for _,segment in ipairs(string.split(e.path,"/")) do current=assert(current:FindFirstChild(segment),"Missing source file "..e.path) end
        assert(current.Value==e.content and current:GetAttribute("SHA256")==e.sha256,"Source content mismatch "..e.path)
        if string.find(e.path,"CombatTimings.luau",1,true) then assert(normalized==string.gsub(e.content,"\r\n","\n"),"Module source mismatch") end
    end
    local timings=require(combat);local timingCount=0;for _ in pairs(timings) do timingCount+=1 end
    assert(timingCount==34,"Timing table incomplete")
    report.textSources=#sources;report.combatTimingEntries=timingCount
    report.guides=#root.GameplayGuides:GetChildren();report.cameras=#root.ReferenceCameras:GetChildren();report.localLights=#root.LocalLights:GetChildren()
    assert(report.guides==12 and report.cameras==4 and report.localLights==39,"Map helper missing")
    report.originalObjects={baseplate=workspace:FindFirstChild("Baseplate")~=nil,spawn=workspace:FindFirstChild("SpawnLocation")~=nil,terrain=workspace:FindFirstChildWhichIsA("Terrain")~=nil,lighting=#game:GetService("Lighting"):GetChildren()}
    local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Include;rayParams.FilterDescendantsInstances={map}
    report.routes={};local blocked=0
    for q=0,3 do local angle=q*math.pi/2;local direction=Vector3.new(-math.cos(angle),0,math.sin(angle));local side=Vector3.new(math.sin(angle),0,math.cos(angle))
        for _,offset in ipairs({-1.4,0,1.4}) do local origin=direction*24+side*offset+Vector3.new(0,34.8,0)
            local hit=workspace:Raycast(origin,direction*36,rayParams)
            table.insert(report.routes,{quadrant=q,lateral=offset,blocked=hit~=nil,hit=hit and hit.Instance:GetFullName() or "",distance=hit and hit.Distance or 36})
            if hit then blocked+=1 end
        end
    end
    report.blockedRoutes=blocked
    Http:PostAsync("http://127.0.0.1:8766/save/verification.json",Http:JSONEncode(report),Enum.HttpContentType.ApplicationJson)
    return {map=report.map,animationClips=#report.animations,textSources=#sources,timingEntries=timingCount,guides=report.guides,cameras=report.cameras,localLights=report.localLights,blockedRoutes=blocked,originalObjects=report.originalObjects}
end)
Http.HttpEnabled=oldHttp
if not ok then error(result) end
return result
