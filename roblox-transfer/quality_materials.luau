-- Apply native surface detail with stable texel density to large architecture.
-- The original atlases are kept in ServerStorage for a future UV repack.
local store=game.ServerStorage.blender666
local backup=store:FindFirstChild("MapPBRAppearances") or Instance.new("Folder")
backup.Name="MapPBRAppearances";backup.Parent=store
local palette={
    trim={Enum.Material.Limestone,196,186,160},dark={Enum.Material.Slate,49,60,65},
    floor={Enum.Material.Concrete,127,132,127},sand={Enum.Material.Sandstone,170,159,131},
    metal={Enum.Material.Metal,128,96,53},gold={Enum.Material.Metal,183,140,61},
    rock={Enum.Material.Slate,77,89,97},red={Enum.Material.Fabric,88,23,32},
    blue={Enum.Material.Fabric,31,73,95},green={Enum.Material.Grass,82,105,61},
    leaf={Enum.Material.Grass,40,64,49},wood={Enum.Material.Wood,84,62,42},
    water={Enum.Material.Glass,55,126,140},ember={Enum.Material.Basalt,94,69,60},
    fire={Enum.Material.Neon,255,122,33},core={Enum.Material.Neon,255,216,116},
    rune={Enum.Material.Neon,100,190,216},
}
for _,p in ipairs(workspace.blender666.AshenColiseum:GetDescendants()) do if p:IsA("MeshPart") then
    local key=p:GetAttribute("SourceObject"):match("• (.+)$");local color=palette[key]
    if key:match("^stone%d$") then local i=tonumber(key:sub(-1));color={Enum.Material.Slate,106+i*4,117+i*4,125+i*3} end
    assert(color,"Unknown authored material: "..key)
    local appearance=p:FindFirstChildWhichIsA("SurfaceAppearance")
    if appearance then appearance.Name=p:GetAttribute("SourceMeshKey");appearance.Parent=backup end
    p:SetAttribute("QualityMaterial",key);p.Material=color[1];p.Color=Color3.fromRGB(color[2],color[3],color[4])
    p.CastShadow=not(key=="fire" or key=="core" or key=="rune")
    if key=="water" then p.Transparency=.2;p.Reflectance=.12 end
end end
game.Lighting.ClockTime=16.25
game.Lighting.Ambient=Color3.fromRGB(67,73,85)
game.Lighting.OutdoorAmbient=Color3.fromRGB(103,115,130)
return {architectureSurfaces=183,palette="Basalt, limestone, bronze, oxblood, dusk blue"}
