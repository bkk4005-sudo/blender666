local Http=game:GetService("HttpService")
local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local project=Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/project.json"))
    local model=assert(workspace:FindFirstChild("AshenColiseum_PBR_Studio"),"Map import has not finished")
    assert(not workspace.blender666:FindFirstChild("AshenColiseum"),"Map destination exists")
    local parts={}
    for _,o in ipairs(model:GetDescendants()) do if o:IsA("MeshPart") then parts[o.Name]=o end end
    local expected=0
    for _,e in ipairs(project.meshes) do if e.category=="Map" then
        expected+=1;assert(parts[e.id] and parts[e.id].MeshId~="","Missing imported mesh: "..e.id)
    end end
    local actual=0;for _ in pairs(parts) do actual+=1 end
    assert(actual==expected,"Unexpected imported mesh count")
    model:PivotTo(CFrame.new(0,32,0)*CFrame.Angles(0,math.pi,0))
    model.Name="AshenColiseum";model:SetAttribute("SourceRelativePath","AshenColiseum/AshenColiseum.blend")
    model:SetAttribute("SourceMeshObjects",158);model:SetAttribute("ImportedMeshParts",expected)
    model:SetAttribute("ImportOffset",Vector3.new(0,32,0));model.Parent=workspace.blender666
    local folders,records={},{}
    for _,e in ipairs(project.meshes) do if e.category=="Map" then
        local p=parts[e.id];local f=folders[e.collection]
        if not f then f=Instance.new("Folder");f.Name=e.collection;f.Parent=model;folders[e.collection]=f end
        p.Name=e.name..(e.chunk>1 and " ["..e.chunk.."]" or "")
        p:SetAttribute("SourceMeshKey",e.id);p:SetAttribute("SourceObject",e.name)
        p:SetAttribute("SourceCollection",e.collection);p:SetAttribute("SourceTriangles",e.triangles)
        p.Anchored=true
        -- Retain importer collision settings. Bulk convex decomposition can block Studio.
        local collisionOk,collisionError=true,nil
        local material={}
        for _,v in ipairs(p:GetChildren()) do if v:IsA("SurfaceAppearance") then
            if v.ColorMap=="" and v.NormalMap=="" and v.MetalnessMap=="" and v.RoughnessMap=="" then v:Destroy()
            else material={color=v.ColorMap,normal=v.NormalMap,metalness=v.MetalnessMap,roughness=v.RoughnessMap} end
        end end
        assert(material.color and material.color~="","Missing PBR color map: "..e.id)
        p.Parent=f
        table.insert(records,{key=e.id,name=p.Name,path=p:GetFullName(),meshId=p.MeshId,size={p.Size.X,p.Size.Y,p.Size.Z},position={p.Position.X,p.Position.Y,p.Position.Z},pbr=material,collision=collisionOk and p.CollisionFidelity.Name or tostring(collisionError)})
        if #records%20==0 then task.wait() end
    end end
    local cf,size=model:GetBoundingBox()
    local output={meshes=records,parts=expected,bounds={size.X,size.Y,size.Z},center={cf.Position.X,cf.Position.Y,cf.Position.Z}}
    Http:PostAsync("http://127.0.0.1:8766/save/map_import.json",Http:JSONEncode(output),Enum.HttpContentType.ApplicationJson)
    return {parts=expected,bounds=output.bounds,center=output.center}
end)
Http.HttpEnabled=oldHttp
if not ok then error(result) end
return result
