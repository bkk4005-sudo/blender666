-- Studio Edit/plugin context. Install the temporary QA scripts/RemoteEvent
-- first; load this source as a function and call it with a profile table.
-- The asynchronous result is chunked below ServerStorage.CombatPvPQA_Outputs
-- because a Roblox StringValue cannot retain a full multiplayer trace >200KB.
return function(options)
    local Test=game:GetService("StudioTestService")
    assert(Test.EditModeActive,"Launch from the original Edit DataModel")
    assert(game.ReplicatedStorage:FindFirstChild("CombatPvPQA"),"QA RemoteEvent missing")
    local root=game.ServerStorage:FindFirstChild("CombatPvPQA_Outputs")
    if not root then root=Instance.new("Folder"); root.Name="CombatPvPQA_Outputs"; root.Parent=game.ServerStorage end
    local network=settings().Network
    local keys={"InboundNetworkMinDelayMs","OutboundNetworkMinDelayMs","InboundNetworkJitterMs","OutboundNetworkJitterMs",
        "InboundNetworkLossPercent","OutboundNetworkLossPercent","IncomingReplicationLag"}
    if not root:GetAttribute("OriginalNetwork") then
        local original={}
        for _,key in keys do original[key]=network[key] end
        -- Preserve the original session settings from the first probe when present.
        local initial=game.ServerStorage:FindFirstChild("CombatPvPQA_Result")
        root:SetAttribute("OriginalNetwork",initial and initial:GetAttribute("OriginalNetwork") or game.HttpService:JSONEncode(original))
    end
    assert(not root:FindFirstChild(options.lagLabel or "Unlabelled"),"QA report label already exists; choose a new lagLabel")
    local applied={}
    for _,key in keys do
        network[key]=(options.networkSettings or {})[key] or 0
        applied[key]=network[key]
    end
    options.appliedNetwork=applied
    local output=Instance.new("Folder")
    output.Name=options.lagLabel or "Unlabelled"
    output:SetAttribute("Status","Running")
    output:SetAttribute("ConfiguredNetwork",game.HttpService:JSONEncode(options.networkSettings or {}))
    output:SetAttribute("AppliedNetwork",game.HttpService:JSONEncode(applied))
    output.Parent=root
    task.spawn(function()
        local ok,result=pcall(function() return Test:ExecuteMultiplayerTestAsync(2,options) end)
        local restored,restoreError=pcall(function()
            local original=game.HttpService:JSONDecode(root:GetAttribute("OriginalNetwork"))
            for _,key in keys do network[key]=original[key] end
        end)
        output:SetAttribute("NetworkRestored",restored)
        if not restored then output:SetAttribute("NetworkRestoreError",tostring(restoreError)) end
        if ok and result==nil then ok=false; result="Test session ended without returning QA evidence" end
        local value=ok and tostring(result) or game.HttpService:JSONEncode({completed=false,launchError=tostring(result)})
        for from=1,#value,60000 do
            local chunk=Instance.new("StringValue")
            chunk.Name=string.format("Chunk_%04d",math.floor((from-1)/60000)+1)
            chunk.Value=value:sub(from,from+59999)
            chunk.Parent=output
        end
        output:SetAttribute("Bytes",#value)
        output:SetAttribute("Status",ok and "Done" or "Error")
    end)
    return output:GetFullName()
end
