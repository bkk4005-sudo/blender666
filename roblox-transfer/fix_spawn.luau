-- Run in Studio Edit after the map import. Uses the existing SpawnLocation.
local spawn=assert(workspace:FindFirstChild("SpawnLocation"),"SpawnLocation missing")
local map=assert(workspace:FindFirstChild("blender666"),"Project missing"):FindFirstChild("AshenColiseum")
local floor=assert(map and map:FindFirstChild("01 / Coliseum / ceremonial floor"),"Arena floor missing")
local colliders=workspace.blender666:FindFirstChild("ArchitectureColliders")
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Include
params.FilterDescendantsInstances={colliders or floor}
local z=colliders and -20 or -12
local hit=assert(workspace:Raycast(Vector3.new(0,37,z),Vector3.new(0,-15,0),params),"Floor surface missing")
assert(hit.Normal.Y>.95 and hit.Instance.CanCollide,"Unsafe floor")
if spawn:GetAttribute("BeforeArenaSpawnCFrame")==nil then
    spawn:SetAttribute("BeforeArenaSpawnCFrame",spawn.CFrame)
    spawn:SetAttribute("BeforeArenaSpawnTransparency",spawn.Transparency)
    spawn:SetAttribute("BeforeArenaSpawnCanCollide",spawn.CanCollide)
end
spawn.Size=Vector3.new(6,.2,6)
local position=hit.Position+Vector3.new(0,spawn.Size.Y/2+.15,0)
spawn.CFrame=CFrame.lookAt(position,Vector3.new(0,position.Y,0))
spawn.Anchored=true;spawn.Enabled=true;spawn.Neutral=true
spawn.CanCollide=false;spawn.Transparency=1
for _,object in ipairs(spawn:GetChildren()) do
    if object:IsA("Decal") or object:IsA("Texture") then
        if object:GetAttribute("BeforeArenaSpawnTransparency")==nil then
            object:SetAttribute("BeforeArenaSpawnTransparency",object.Transparency)
        end
        object.Transparency=1
    end
end
spawn:SetAttribute("SpawnSurface",hit.Instance:GetFullName())
return {position=spawn.Position,floor=hit.Instance:GetFullName()}
