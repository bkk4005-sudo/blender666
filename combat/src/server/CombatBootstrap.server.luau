local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = ReplicatedStorage:WaitForChild("CombatFoundation")
local remote = root:FindFirstChild("CombatRemote")
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = "CombatRemote"
    remote.Parent = root
end

local service = require(script.Parent:WaitForChild("CombatService")).new(remote)
script.Destroying:Connect(function() service:destroy() end)
