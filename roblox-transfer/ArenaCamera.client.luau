-- Start each spawn in a readable third person view instead of inheriting the editor zoom.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function onCharacter(character)
    local humanoid=character:WaitForChild("Humanoid")
    local root=character:WaitForChild("HumanoidRootPart")
    RunService.RenderStepped:Wait()
    local camera=workspace.CurrentCamera
    camera.CameraSubject=humanoid;camera.CameraType=Enum.CameraType.Custom
    player.CameraMode=Enum.CameraMode.Classic
    player.CameraMinZoomDistance=12;player.CameraMaxZoomDistance=12
    camera.CFrame=CFrame.lookAt(root.Position+Vector3.new(0,6,-10),root.Position+Vector3.new(0,1.5,0))
    RunService.RenderStepped:Wait()
    player.CameraMinZoomDistance=5;player.CameraMaxZoomDistance=24
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then task.spawn(onCharacter,player.Character) end
