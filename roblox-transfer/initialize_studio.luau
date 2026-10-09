local Http = game:GetService("HttpService")
local oldHttp = Http.HttpEnabled
local ok, result = pcall(function()
    Http.HttpEnabled = true
    local function fetch(name) return Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/"..name)) end
    local function folder(name, parent)
        assert(not parent:FindFirstChild(name), "Transfer destination already exists: "..parent:GetFullName().."."..name)
        local f=Instance.new("Folder"); f.Name=name; f:SetAttribute("Repository", "blender666"); f.Parent=parent; return f
    end
    local storage=folder("blender666",game:GetService("ServerStorage"))
    local replicated=folder("blender666",game:GetService("ReplicatedStorage"))
    local assets=folder("Assets",storage)
    local animations=folder("Animations",storage); folder("AshenOath",animations)
    local weapons=folder("Weapons",replicated);folder("AshenGreatsword",weapons)
    local sources=folder("SourceFiles",storage)
    local textSources=fetch("source_bundle.json")
    for _,entry in ipairs(textSources) do
        local path=string.split(entry.path,"/");local parent=sources
        for i=1,#path-1 do
            local name=path[i];local child=parent:FindFirstChild(name)
            if not child then child=Instance.new("Folder");child.Name=name;child.Parent=parent end
            parent=child
        end
        local v=Instance.new("StringValue");v.Name=path[#path];v.Value=entry.content
        v:SetAttribute("SHA256",entry.sha256);v:SetAttribute("SourceRelativePath",entry.path);v.Parent=parent
    end
    local inventory=Instance.new("StringValue");inventory.Name="RepositoryInventory";inventory.Value=Http:GetAsync("http://127.0.0.1:8766/repository_inventory.json");inventory.Parent=storage
    local metadata=Instance.new("StringValue");metadata.Name="TransferManifest";metadata.Value=Http:GetAsync("http://127.0.0.1:8766/project.json");metadata.Parent=storage
    local sword=assert(workspace:FindFirstChild("AshenOath_Greatsword"),"Imported sword missing")
    assert(sword:IsA("Model"),"Imported sword has unexpected type")
    local part=sword:FindFirstChildWhichIsA("MeshPart",true);assert(part and part.MeshId~="","Sword mesh asset missing")
    for _,v in ipairs(part:GetChildren()) do
        if v:IsA("SurfaceAppearance") and v.ColorMap=="" and v.NormalMap=="" and v.MetalnessMap=="" and v.RoughnessMap=="" then v:Destroy() end
    end
    part.Anchored=true;part.CanCollide=false;part.Massless=true
    part.CFrame=CFrame.new(0,1.195,0)*CFrame.Angles(0,math.pi,0)
    part:SetAttribute("SourceObject","AshenOath_Greatsword")
    sword.PrimaryPart=part;sword.WorldPivot=CFrame.identity
    sword:SetAttribute("SourceRelativePath","AshenColiseum/Weapons/AshenGreatsword/AshenOath_R15.blend")
    sword:SetAttribute("RightGripLocal",Vector3.zero)
    sword:SetAttribute("LeftGripLocal",Vector3.new(0,-0.53,0))
    sword:SetAttribute("BladeBaseLocal",Vector3.new(0,0.56,0))
    sword:SetAttribute("BladeTipLocal",Vector3.new(0,3.55,0))
    sword.Parent=assets
    local map=Instance.new("Model");map.Name="blender666";map:SetAttribute("Repository","blender666")
    map:SetAttribute("ImportOffset",Vector3.new(0,32,0));map.Parent=workspace
    local guides=folder("GameplayGuides",map);local cameras=folder("ReferenceCameras",map);local lights=folder("LocalLights",map)
    local mapMetadata=fetch("map_metadata.json")
    for _,v in ipairs(mapMetadata.helpers) do
        local p=Instance.new("Part");p.Name=v.name;p.Size=Vector3.new(.2,.2,.2);p.Transparency=1
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
        p.CFrame=CFrame.new(0,32,0)*CFrame.new(unpack(v.cframe));p:SetAttribute("SourceDisplaySize",v.displaySize);p.Parent=guides
        local a=Instance.new("Attachment");a.Name="Guide";a.Parent=p
    end
    for _,v in ipairs(mapMetadata.cameras) do
        local c=Instance.new("Camera");c.Name=v.name;c.CFrame=CFrame.new(0,32,0)*CFrame.new(unpack(v.cframe))
        c:SetAttribute("SourceProjection",v.type);c:SetAttribute("SourceLens",v.lens);c:SetAttribute("SourceOrthoScale",v.orthoScale);c.Parent=cameras
    end
    for _,v in ipairs(mapMetadata.lights) do
        if v.type=="POINT" then
            local p=Instance.new("Part");p.Name=v.name;p.Size=Vector3.new(.1,.1,.1);p.Transparency=1
            p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
            p.CFrame=CFrame.new(0,32,0)*CFrame.new(unpack(v.cframe));p:SetAttribute("SourceEnergyWatts",v.energy);p.Parent=lights
            local light=Instance.new("PointLight");light.Color=Color3.new(unpack(v.color))
            light.Brightness=math.min(10,v.energy/100);light.Range=math.min(60,math.max(8,math.sqrt(v.energy)*1.5));light.Shadows=true;light.Parent=p
        end
    end
    local originalLighting=Instance.new("StringValue");originalLighting.Name="BlenderLightingReference"
    originalLighting.Value=Http:JSONEncode(mapMetadata.lights);originalLighting.Parent=storage
    return {sourceFiles=#textSources,guides=#mapMetadata.helpers,cameras=#mapMetadata.cameras,localLights=#lights:GetChildren(),swordMeshId=part.MeshId}
end)
Http.HttpEnabled=oldHttp
return Http:JSONEncode({ok=ok,result=ok and result or tostring(result),httpRestored=Http.HttpEnabled==oldHttp})
