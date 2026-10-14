-- Server-created rigid visual. No damage or reach is derived from its mesh.
-- The registered unscaled template lives in ServerStorage/CombatWeaponTemplates.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local foundation = ReplicatedStorage:WaitForChild("CombatFoundation", 8)
if not foundation then warn("CombatTestSword: CombatFoundation missing"); return end
local Visual = require(foundation:WaitForChild("Shared"):WaitForChild("WeaponVisualConfig"))

local function getTemplate(): Model?
    local templates = ServerStorage:FindFirstChild("CombatWeaponTemplates")
    local registered = templates and templates:FindFirstChild("StraightSword")
    if registered and registered:IsA("Model") then return registered end
    local direct = ServerStorage:FindFirstChild("CombatTestSwordTemplate")
    if direct and direct:IsA("Model") then return direct end
    return nil
end

local function attach(character: Model, player: Player)
    local deadline = os.clock() + 12
    while player.Character == character and not player:HasAppearanceLoaded() and os.clock() < deadline do task.wait(.1) end
    if player.Character ~= character then return end
    -- A slow appearance must not equip onto hands that Roblox will replace.
    -- CharacterAppearanceLoaded retries when those assets finally arrive.
    if not player:HasAppearanceLoaded() then return end
    local hand = character:WaitForChild("RightHand", 8)
    local template = getTemplate()
    if not hand or not hand:IsA("BasePart") or not template then
        warn("CombatTestSword: R15 RightHand or sword template unavailable")
        return
    end
    local existing = character:FindFirstChild("CombatTestSword")
    local previousGrip = hand:FindFirstChild("CombatTestSwordGrip")
    if existing and previousGrip and previousGrip:IsA("Motor6D")
        and previousGrip.Part0 == hand and previousGrip.Part1
        and previousGrip.Part1:IsDescendantOf(existing) then return end
    if existing then existing:Destroy() end
    local oldGrip = hand:FindFirstChild("CombatTestSwordGrip")
    if oldGrip then oldGrip:Destroy() end

    local swordModel = template:Clone()
    swordModel.Name = "CombatTestSword"
    local blade = swordModel:FindFirstChildWhichIsA("MeshPart", true)
    if not blade then
        swordModel:Destroy()
        warn("CombatTestSword: sword template has no MeshPart")
        return
    end
    -- This weapon profile has one rigid mesh. Reject incompatible templates
    -- rather than leave additional unconnected parts floating in the scene.
    for _, item in swordModel:GetDescendants() do
        if item:IsA("BasePart") and item ~= blade then
            swordModel:Destroy()
            warn("Combat weapon template requires a single MeshPart")
            return
        end
    end
    local originalGrip = blade:FindFirstChild("RightGrip")
    if not originalGrip or not originalGrip:IsA("Attachment") then
        -- The standalone source mesh has no attachments; its R15 donor copy
        -- records the handle at this point relative to the mesh centre.
        originalGrip = Instance.new("Attachment")
        originalGrip.Name = "RightGrip"
        originalGrip.CFrame = Visual.SourceGrip
        originalGrip.Parent = blade
    end
    blade.Size = blade.Size * Visual.MeshScale
    for _, child in blade:GetChildren() do
        if child:IsA("Attachment") then
            child.Position = child.Position * Visual.MeshScale
        end
    end
    blade.Anchored = false
    blade.CanCollide = false
    blade.CanTouch = false
    blade.CanQuery = false
    blade.Massless = true
    local grip = Instance.new("Motor6D")
    grip.Name = "CombatTestSwordGrip"
    grip.Part0 = hand
    grip.Part1 = blade
    grip.C0 = Visual.forCharacter(character) * originalGrip.CFrame:Inverse()
    grip.C1 = CFrame.new()
    blade.CFrame = hand.CFrame * grip.C0
    grip.Parent = hand
    swordModel.Parent = character
end

local function onPlayer(player: Player)
    player.CharacterAdded:Connect(function(character) attach(character, player) end)
    player.CharacterAppearanceLoaded:Connect(function(character) attach(character, player) end)
    if player.Character then task.defer(attach, player.Character, player) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do onPlayer(player) end
