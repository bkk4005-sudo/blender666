local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local root = ReplicatedStorage:WaitForChild("CombatFoundation")
local Bindings = require(root.Shared:WaitForChild("InputBindings"))
local remote = root:FindFirstChild("CombatSettingsRemote") or Instance.new("RemoteEvent")
remote.Name, remote.Parent = "CombatSettingsRemote", root
local storeOk, store = pcall(function() return DataStoreService:GetDataStore("CombatInputBindings_v1") end)
if not storeOk then store = nil end
local sessions = {}
local function save(player, session)
    if session.saving or not session.dirty then return end
    session.saving = true
    local snapshot, version = table.clone(session.values), session.version
    local ok = store ~= nil and pcall(function() store:UpdateAsync(tostring(player.UserId), function() return snapshot end) end)
    session.saving = false
    if ok and session.version == version then session.dirty = false end
    if player.Parent then
        if not ok then remote:FireClient(player, "Unavailable")
        elseif session.version == version then remote:FireClient(player, "Saved") end
    end
    if ok and session.dirty then task.defer(save, player, session) end
end
remote.OnServerEvent:Connect(function(player, kind, values)
    if kind ~= "Load" and kind ~= "Save" then return end
    local session = sessions[player]
    if not session then session = {values = table.clone(Bindings.Defaults), version = 0, dirty = false, nextRequest = 0}; sessions[player] = session end
    local now = os.clock()
    if now < session.nextRequest then return end
    session.nextRequest = now + .2
    if kind == "Load" then
        if session.loading or session.loaded then return end
        session.loading = true
        local version = session.version
        local ok, stored = false, nil
        if store then ok, stored = pcall(function() return store:GetAsync(tostring(player.UserId)) end) end
        session.loading, session.loaded = false, true
        if session.version == version then session.values = Bindings.validate(stored) or session.values end
        if player.Parent then
            remote:FireClient(player, "Loaded", session.values)
            if not ok then remote:FireClient(player, "Unavailable") end
        end
    else
        local valid = Bindings.validate(values)
        if not valid then return end
        session.values, session.version, session.dirty = valid, session.version + 1, true
        -- Coalesce edits; datastore calls run independently of combat.
        if session.scheduled then return end
        session.scheduled = true
        task.delay(3, function()
            session.scheduled = false
            save(player, session)
        end)
    end
end)
Players.PlayerRemoving:Connect(function(player)
    local session = sessions[player]
    if session then
        local deadline = os.clock() + 8
        while session.saving and os.clock() < deadline do task.wait(.1) end
        save(player, session)
    end
    sessions[player] = nil
end)
game:BindToClose(function()
    for player, session in sessions do task.spawn(save, player, session) end
    local deadline = os.clock() + 8
    repeat
        local pending = false
        for _, session in sessions do if session.saving then pending = true end end
        if not pending then break end
        task.wait(.1)
    until os.clock() >= deadline
end)
