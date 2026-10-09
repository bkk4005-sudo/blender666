local Http=game:GetService("HttpService");local oldHttp=Http.HttpEnabled
local ok,result=pcall(function()
    Http.HttpEnabled=true
    local function fetch(n) return Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/"..n)) end
    local project=fetch("project.json");local records=fetch("colliders.json")
    local metadata=fetch("map_metadata.json");local imported=fetch("original_map_import.json")
    local world=workspace.blender666;local map=world.AshenColiseum
    assert(not map:GetAttribute("HorizontalScale"),"World update already applied")
    local scale=2;local offset=Vector3.new(0,32,0)
    local index={};for _,e in ipairs(imported.meshes) do index[e.key]=e end
    local function point(p) return Vector3.new(-p[1]*scale,p[3]+32,p[2]*scale) end
    local meshCount=0
    for _,p in ipairs(map:GetDescendants()) do if p:IsA("MeshPart") then
        local e=assert(index[p:GetAttribute("SourceMeshKey")])
        p:SetAttribute("BeforeQualitySize",p.Size);p:SetAttribute("BeforeQualityCFrame",p.CFrame)
        p:SetAttribute("BeforeQualityCanCollide",p.CanCollide)
        p.Size=Vector3.new(p.Size.X*scale,p.Size.Y,p.Size.Z*scale)
        p.CFrame=CFrame.new(e.position[1]*scale,e.position[2],e.position[3]*scale)*CFrame.Angles(0,math.pi,0)
        p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.RenderFidelity=Enum.RenderFidelity.Automatic
        meshCount+=1;if meshCount%15==0 then task.wait() end
    end end
    local colliders=Instance.new("Folder");colliders.Name="ArchitectureColliders";colliders.Parent=world
    local colliderCount=0
    local function part(name,size,cf,shape)
        local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Anchored=true
        p.Transparency=1;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false
        p.Material=Enum.Material.Slate;p.Shape=shape or Enum.PartType.Block
        p.CFrame=CFrame.Angles(0,math.pi,0)*p.CFrame;p.Parent=colliders
        colliderCount+=1
    end
    for i,r in ipairs(records) do
        if r.kind=="box" then
            part(r.district.." / masonry",Vector3.new(r.size[1]*scale,r.size[3],r.size[2]*scale),CFrame.new(point(r.pos))*CFrame.Angles(0,r.angle,0))
        elseif r.kind=="cylinder" then
            if r.r>10 and r.depth<.31 then r.depth+=.17;r.pos[3]+=.085 end
            part(r.district.." / round platform",Vector3.new(r.depth,r.r*2*scale,r.r*2*scale),CFrame.new(point(r.pos))*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
        elseif r.kind=="ring" then
            local n=math.max(1,math.ceil((r['end']-r.start)*((r.ri+r.ro)/2)/2))
            local delta=(r['end']-r.start)/n;local radius=(r.ri+r.ro)/2
            for j=1,n do
                local a=r.start+(j-.5)*delta
                local pos={r.center[1]+radius*math.cos(a),r.center[2]+radius*math.sin(a),r.z+r.h/2}
                local tangential=2*radius*math.sin(delta/2)*scale+.04
                part(r.district.." / gallery sector",Vector3.new((r.ro-r.ri)*scale,r.h,tangential),CFrame.new(point(pos))*CFrame.Angles(0,a,0))
            end
        end
        if i%80==0 then task.wait() end
    end
    map:SetAttribute("HorizontalScale",scale);map:SetAttribute("ArenaDiameter",101.6);map:SetAttribute("CourtDiameter",52)
    map:SetAttribute("ClearCourtCombatDiameter",42);map:SetAttribute("CollisionMode","Source structural primitives")
    local function importedCF(c)
        local cf=CFrame.new(unpack(c))
        return CFrame.new(-cf.X*scale,cf.Y+32,-cf.Z*scale)*CFrame.Angles(0,math.pi,0)*cf.Rotation
    end
    for _,e in ipairs(metadata.helpers) do local p=world.GameplayGuides:FindFirstChild(e.name);if p then p.CFrame=importedCF(e.cframe) end end
    for _,e in ipairs(metadata.lights) do local p=world.LocalLights:FindFirstChild(e.name);if p then p.CFrame=importedCF(e.cframe) end end
    for _,e in ipairs(metadata.cameras) do local p=world.ReferenceCameras:FindFirstChild(e.name);if p then p.CFrame=importedCF(e.cframe) end end
    for _,p in ipairs(world.GameplayGuides:GetChildren()) do if p:IsA("BasePart") then p:SetAttribute("HorizontalScale",scale) end end
    local spawn=workspace.SpawnLocation;spawn.CFrame=CFrame.new(0,32.605,-24)*CFrame.Angles(0,math.pi,0)
    spawn:SetAttribute("SurfaceY",32.105);spawn:SetAttribute("HorizontalScale",scale)
    -- Restrained dusk light: cool slate, warm bronze and amber braziers.
    local L=game:GetService("Lighting")
    local before={};for _,name in ipairs({"ClockTime","Brightness","ExposureCompensation","Ambient","OutdoorAmbient","EnvironmentDiffuseScale","EnvironmentSpecularScale","GlobalShadows","ShadowSoftness"}) do
        local v=L[name];before[name]=typeof(v)=="Color3" and {v.R,v.G,v.B} or v
    end
    local store=game:GetService("ServerStorage").blender666
    local saved=Instance.new("StringValue");saved.Name="LightingBeforeQuality";saved.Value=Http:JSONEncode(before);saved.Parent=store
    local effectsBackup=Instance.new("Folder");effectsBackup.Name="LightingEffectsBeforeQuality";effectsBackup.Parent=store
    for _,effect in ipairs(L:GetChildren()) do effect:Clone().Parent=effectsBackup end
    L.LightingStyle=Enum.LightingStyle.Realistic;L.PrioritizeLightingQuality=true
    L.ClockTime=16.4;L.GeographicLatitude=28;L.Brightness=2.4;L.ExposureCompensation=.1
    L.Ambient=Color3.fromRGB(49,58,72);L.OutdoorAmbient=Color3.fromRGB(92,106,125)
    L.EnvironmentDiffuseScale=.65;L.EnvironmentSpecularScale=.8;L.GlobalShadows=true;L.ShadowSoftness=.3
    local atmosphere=L:FindFirstChildWhichIsA("Atmosphere") or Instance.new("Atmosphere",L)
    atmosphere.Density=.29;atmosphere.Offset=.15;atmosphere.Color=Color3.fromRGB(186,196,211)
    atmosphere.Decay=Color3.fromRGB(108,121,142);atmosphere.Glare=.15;atmosphere.Haze=1.3
    local bloom=L:FindFirstChildWhichIsA("BloomEffect") or Instance.new("BloomEffect",L)
    bloom.Intensity=.16;bloom.Size=24;bloom.Threshold=1.7
    local rays=L:FindFirstChildWhichIsA("SunRaysEffect") or Instance.new("SunRaysEffect",L)
    rays.Intensity=.035;rays.Spread=.7
    local dof=L:FindFirstChildWhichIsA("DepthOfFieldEffect");if dof then dof.Enabled=false end
    local grade=Instance.new("ColorCorrectionEffect");grade.Name="AshenColiseumGrade";grade.Brightness=0
    grade.Contrast=.08;grade.Saturation=-.06;grade.TintColor=Color3.fromRGB(248,250,255);grade.Parent=L
    for _,light in ipairs(world.LocalLights:GetDescendants()) do if light:IsA("PointLight") then
        light:SetAttribute("BeforeQualityBrightness",light.Brightness);light:SetAttribute("BeforeQualityRange",light.Range)
        light.Brightness=string.find(light.Parent.Name,"Moon") and .65 or .7
        light.Range=string.find(light.Parent.Name,"Moon") and 15 or 13
        light.Color=string.find(light.Parent.Name,"Moon") and Color3.fromRGB(114,193,224) or Color3.fromRGB(255,164,76)
        light.Shadows=true
    end end
    -- Ground the island and its distant slate outcrops in a rugged basin.
    local environment=Instance.new("Model");environment.Name="AshenBasin";environment.Parent=world
    local ground=Instance.new("Part");ground.Name="BasinFloor";ground.Size=Vector3.new(1200,4,1200)
    ground.CFrame=CFrame.new(0,18,0);ground.Anchored=true;ground.Material=Enum.Material.Slate
    ground.Color=Color3.fromRGB(61,70,73);ground.Parent=environment
    local rng=Random.new(7421)
    local terrain=workspace.Terrain
    terrain:SetMaterialColor(Enum.Material.Rock,Color3.fromRGB(76,84,92));terrain:SetMaterialColor(Enum.Material.Slate,Color3.fromRGB(59,68,75))
    terrain:SetMaterialColor(Enum.Material.Ground,Color3.fromRGB(90,85,70));terrain:SetMaterialColor(Enum.Material.Grass,Color3.fromRGB(82,96,71))
    -- Low land remains below all authored walkways; hills sit outside the fighting districts.
    terrain:FillBlock(CFrame.new(0,9,0),Vector3.new(1184,20,1184),Enum.Material.Slate)
    for i=1,64 do
        local a=(i-.5)*math.pi*2/64;local radius=rng:NextNumber(290,520)
        local x,z=math.cos(a)*radius,math.sin(a)*radius
        local hill=rng:NextNumber(30,64);terrain:FillBall(Vector3.new(x,8,z),hill,Enum.Material.Rock)
        if i%3==0 then terrain:FillBall(Vector3.new(x,9,z),hill*.72,Enum.Material.Grass) end
        if i%8==0 then task.wait() end
    end
    for i=1,24 do
        local a=(i-.5)*math.pi*2/24;local radius=rng:NextNumber(550,690)
        terrain:FillBall(Vector3.new(math.cos(a)*radius,-12,math.sin(a)*radius),rng:NextNumber(80,128),Enum.Material.Rock)
        if i%8==0 then task.wait() end
    end
    local clouds=terrain:FindFirstChildWhichIsA("Clouds") or Instance.new("Clouds",terrain)
    clouds.Cover=.38;clouds.Density=.25;clouds.Color=Color3.fromRGB(208,211,219)
    local cf,size=map:GetBoundingBox()
    return {meshes=meshCount,colliders=colliderCount,horizontalScale=scale,bounds={size.X,size.Y,size.Z},arenaDiameter=101.6,courtDiameter=52,landscapeHills=88}
end)
Http.HttpEnabled=oldHttp
if not ok then error(result) end
return result
