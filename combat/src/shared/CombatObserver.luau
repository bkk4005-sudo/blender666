-- Client-side opponent presentation. Studio preview hashes must be registered
-- on the observing client. Registration can also resolve native replica tracks;
-- keep one owned preview and suppress only those matching Studio replicas.
-- Published assets use native
-- replication; this module aligns that existing track without duplicating it.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Provider=game:GetService("KeyframeSequenceProvider")
local Registry=require(script.Parent.AnimationRegistry)
local Retarget=require(script.Parent.R15PreviewRetarget)
local Config=require(script.Parent.CombatConfig)
local Observer={}
Observer.__index=Observer
local function dispose(record)
    record.cancelled=true
    record.ready=false
    record.pending,record.action=nil,nil
    for _,connection in record.connections do connection:Disconnect() end
    for _,track in record.tracks do track:Stop(0); track:Destroy() end
    for _,sequence in record.sequences do sequence:Destroy() end
end
function Observer.new(folder,onCount)
    assert(Run:IsClient(),"Opponent presentation requires a client")
    local self=setmetatable({folder=folder,records={},connections={},playerConnections={},onCount=onCount},Observer)
    local function bindPlayer(player)
        if self.destroyed or player==Players.LocalPlayer or self.playerConnections[player] then return end
        self.playerConnections[player]={
            player.CharacterAdded:Connect(function(character) self:bind(player,character) end),
            player.CharacterRemoving:Connect(function(character)
                local record=self.records[player]
                if record and record.character==character then dispose(record); self.records[player]=nil; self:count() end
            end),
        }
        if player.Character then self:bind(player,player.Character) end
    end
    table.insert(self.connections,Players.PlayerAdded:Connect(bindPlayer))
    table.insert(self.connections,Players.PlayerRemoving:Connect(function(player)
        if self.records[player] then dispose(self.records[player]); self.records[player]=nil end
        if self.playerConnections[player] then for _,connection in self.playerConnections[player] do connection:Disconnect() end; self.playerConnections[player]=nil end
        self:count()
    end))
    for _,player in Players:GetPlayers() do bindPlayer(player) end
    table.insert(self.connections,Run.PreAnimation:Connect(function()
        local now=workspace:GetServerTimeNow()
        for _,record in self.records do
            local action=record.action
            if record.cancelled then continue end
            local humanoid=record.character:FindFirstChildOfClass("Humanoid")
            if Run:IsStudio() and record.ready and humanoid and humanoid.Health>0 then
                -- Registering the peer's hash may make its native replica load
                -- too. Its generic name is not a reliable identity. Stop only
                -- known cached preview IDs on this non-owner client, before
                -- animation evaluation, to avoid blending the same clip twice.
                for _,replica in record.animator:GetPlayingAnimationTracks() do
                    local animation=replica.Animation
                    local owned=animation and record.previewById[animation.AnimationId]
                    if owned and replica~=owned then replica:Stop(0) end
                end
                local idle,block=record.tracks.CombatIdle,record.tracks.Block
                local state=record.character:GetAttribute("CombatState")
                local root=record.character:FindFirstChild("HumanoidRootPart")
                local velocity=root and root.AssemblyLinearVelocity or Vector3.zero
                local standing=Vector3.new(velocity.X,0,velocity.Z).Magnitude<1
                if idle then
                    if standing and not idle.IsPlaying then idle:Play(.15)
                    elseif not standing and idle.IsPlaying then idle:Stop(.15) end
                end
                if block then
                    if state=="Blocking" and not block.IsPlaying then block:Play(.10)
                    elseif state~="Blocking" and block.IsPlaying then block:Stop(.10) end
                end
            end
            if not action then continue end
            local duration=Config.Actions[action.name].duration
            local elapsed=math.max(0,now-action.started)
            if not humanoid or humanoid.Health<=0 or elapsed>=duration then
                if action.track and action.preview then action.track:Stop(.035) end
                record.action=nil
                continue
            end
            if (not action.track or not action.track.IsPlaying) and record.animator and not action.preview then
                action.track=nil
                local entry=Registry.get("R15",action.name)
                for _,track in record.animator:GetPlayingAnimationTracks() do
                    if entry and entry.assetId and track.Animation and track.Animation.AnimationId==entry.assetId then action.track=track; break end
                end
            end
            if action.track and action.track.IsPlaying then
                action.track:AdjustSpeed(1)
                -- TimePosition is not replicated; each observer follows the
                -- server action clock on its own existing/local preview track.
                action.track.TimePosition=elapsed
            end
        end
    end))
    return self
end
function Observer:count()
    local count=0
    for _,record in self.records do if record.ready and not record.cancelled then for _ in record.tracks do count+=1 end end end
    if self.onCount then self.onCount(count) end
end
function Observer:bind(player,character)
    if self.destroyed then return nil end
    local previous=self.records[player]
    if previous and previous.character==character then return previous end
    if previous then dispose(previous) end
    local record={character=character,tracks={},previewById={},sequences={},connections={},lastSerial=0,cancelled=false}
    self.records[player]=record
    self:count()
    task.spawn(function()
        local deadline=os.clock()+40
        while not record.cancelled and player.Character==character and os.clock()<deadline
            and (not character:FindFirstChild("HumanoidRootPart") or character:GetAttribute("CombatHitReady")~=true) do task.wait(.1) end
        if record.cancelled or player.Character~=character or not character.Parent then return end
        if not character:FindFirstChild("HumanoidRootPart") or character:GetAttribute("CombatHitReady")~=true then return end
        local h=character:FindFirstChildOfClass("Humanoid")
        local animator=h and h:FindFirstChildOfClass("Animator")
        if not animator or h.Health<=0 then return end
        record.animator=animator
        table.insert(record.connections,h.Died:Connect(function()
            dispose(record)
            self:count()
        end))
        if Run:IsStudio() then
            for name in Registry.Profiles.R15 do
                if record.cancelled or player.Character~=character then return end
                if Registry.get("R15",name).assetId then continue end
                local source=self.folder.Animations:FindFirstChild(name)
                if not source then continue end
                local ok,value=pcall(function()
                    local sequence=Retarget.bakeForRig(source,character,8)
                    if record.cancelled then sequence:Destroy(); return nil end
                    table.insert(record.sequences,sequence)
                    local animation=Instance.new("Animation")
                    animation.Name,animation.AnimationId=name,Provider:RegisterKeyframeSequence(sequence)
                    local track=animator:LoadAnimation(animation)
                    record.previewById[animation.AnimationId]=track
                    animation:Destroy()
                    track.Name,track.Priority,track.Looped=name,Registry.get("R15",name).priority,Registry.get("R15",name).loop==true
                    if name=="CombatIdle" then track.Priority=Enum.AnimationPriority.Movement end
                    return track
                end)
                if ok and value then record.tracks[name]=value elseif not ok then warn("Opponent preview failed:",name,value) end
            end
        end
        if record.cancelled then return end
        record.ready=true
        self:count()
        local pending=record.pending
        record.pending=nil
        if pending then self:play(record,pending.name,pending.started) end
    end)
    return record
end
function Observer:play(record,name,started)
    if self.destroyed or record.cancelled then return end
    local action=Config.Actions[name]
    if not action or workspace:GetServerTimeNow()-started>=action.duration then return end
    if record.action and record.action.track and record.action.preview then record.action.track:Stop(.035) end
    local track=record.tracks[name]
    record.action={name=name,started=started,track=track,preview=track~=nil}
    if track then
        track:Play(.035,1,1)
        track.TimePosition=math.max(0,workspace:GetServerTimeNow()-started)
    end
end
function Observer:started(owner,name,started,metadata)
    if self.destroyed or typeof(owner)~="Instance" or not owner:IsA("Player") or owner==Players.LocalPlayer or not Config.Actions[name]
        or type(started)~="number" or type(metadata)~="table" then return end
    if metadata.character~=owner.Character then return end
    local humanoid=owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health<=0 then return end
    local record=self:bind(owner,metadata.character)
    if type(metadata.serial)~="number" or metadata.serial<=record.lastSerial then return end
    record.lastSerial=metadata.serial
    if workspace:GetServerTimeNow()-started>=Config.Actions[name].duration then return end
    if record.ready then self:play(record,name,started)
    else record.pending={name=name,started=started} end
end
function Observer:destroy()
    self.destroyed=true
    for _,connection in self.connections do connection:Disconnect() end
    for _,connections in self.playerConnections do for _,connection in connections do connection:Disconnect() end end
    for _,record in self.records do dispose(record) end
    table.clear(self.records)
end
return Observer
