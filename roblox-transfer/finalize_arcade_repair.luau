-- Set repairManifest from export/arcade_repair.json before execution.
local map=workspace.blender666.AshenColiseum
local district=assert(map:FindFirstChild("03 / Coliseum / double arcade"))
local model=assert(workspace:FindFirstChild("AshenArcade_Fixed"))
local backup=Instance.new("Folder");backup.Name="ArcadeBeforeRenderRepair";backup.Parent=game.ServerStorage.blender666
local old={};for _,p in ipairs(district:GetChildren()) do if p:IsA("MeshPart") then old[p:GetAttribute("SourceMeshKey")]=p end end
assert(#repairManifest==76,"Incomplete repair manifest")
for _,p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end end
model:PivotTo(CFrame.new(0,32,0)*CFrame.Angles(0,math.pi,0))
local records={}
for _,e in ipairs(repairManifest) do
    local p=assert(model:FindFirstChild(e.name,true));local source=assert(old[e.sourceKey])
    assert(p.MeshId~="" and p.Size.Magnitude<210,"Invalid repaired mesh")
    p.Name=e.sourceObject.." / "..e.name;p.Material=source.Material;p.Color=source.Color;p.CastShadow=source.CastShadow
    p.Transparency=source.Transparency;p.RenderFidelity=Enum.RenderFidelity.Precise
    p:SetAttribute("SourceMeshKey",e.name);p:SetAttribute("OriginalSourceMeshKey",e.sourceKey)
    p:SetAttribute("SourceObject",e.sourceObject);p:SetAttribute("SourceCollection",e.collection)
    p:SetAttribute("SourceTriangles",e.triangles);p:SetAttribute("QualityMaterial",source:GetAttribute("QualityMaterial"))
    p:SetAttribute("RenderRepair","Small immutable FBX batches, max 4500 triangles")
    p.Parent=district;table.insert(records,{key=e.name,sourceKey=e.sourceKey,meshId=p.MeshId,cf={p.CFrame:GetComponents()},size={p.Size.X,p.Size.Y,p.Size.Z},triangles=e.triangles})
end
for _,p in pairs(old) do p.Parent=backup end
model:Destroy()
map:SetAttribute("ImportedMeshParts",234);map:SetAttribute("ArcadeRenderRepair",true)
return {parts=#records,oldParts=25,triangles=311076,records=records}
