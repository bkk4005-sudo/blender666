-- Temporary Studio-only participant for two real client DataModels.
-- All combat input uses Roblox VirtualInput through the production bindings.
-- QA transport carries schedules/observations only, never damage or i-frames.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Players = game:GetService("Players")
local UserInput = game:GetService("UserInputService")
local player = Players.LocalPlayer
local qa = game.ReplicatedStorage:WaitForChild("CombatPvPQA",30)
if not qa then return end
local foundation = game.ReplicatedStorage:WaitForChild("CombatFoundation")
local remote = foundation:WaitForChild("CombatRemote")
local controller = player.PlayerScripts:WaitForChild("CombatClient",30)
local deadline = os.clock()+60
repeat task.wait(.1) until (controller and controller:GetAttribute("PreviewAnimationCount")==12) or os.clock()>deadline
local inputOK, virtual = pcall(function() return UserInput:CreateVirtualInput() end)
local function ready()
    local character=player.Character
    local ending=os.clock()+60
    Run.Heartbeat:Wait()
    while player.Character==character and os.clock()<ending
        and (controller:GetAttribute("PreviewAnimationCount")~=12 or not player:HasAppearanceLoaded()
            or character:GetAttribute("CombatHitReady")~=true) do task.wait(.1) end
    if player.Character~=character then return end
    -- The production observer was added after the initial before-fix probes.
    -- Wait for its actual local preview cache when this version exposes it.
    while player.Character==character and os.clock()<ending
        and controller:GetAttribute("ObserverAnimationCount")~=nil
        and controller:GetAttribute("ObserverAnimationCount")<12 do task.wait(.1) end
    qa:FireServer("Ready",{player=player.Name,userId=player.UserId,tracks=controller:GetAttribute("PreviewAnimationCount"),count=controller:GetAttribute("PreviewAnimationCount"),observerTracks=controller:GetAttribute("ObserverAnimationCount"),virtualInput=inputOK,virtualInputAvailable=inputOK,error=not inputOK and tostring(virtual) or nil})
end
player.CharacterAdded:Connect(function() task.spawn(ready) end)
controller:GetAttributeChangedSignal("ObserverAnimationCount"):Connect(function()
    if controller:GetAttribute("ObserverAnimationCount")==12 then task.spawn(ready) end
end)
ready()
if not inputOK then return end

local function now() return workspace:GetServerTimeNow() end
local function vector(v) return {v.X,v.Y,v.Z} end
local function press(action,report,hold)
    local viewport=workspace.CurrentCamera.ViewportSize
    local position=Vector2.new(viewport.X*.55,viewport.Y*.65)
    local buttons={R1=Enum.UserInputType.MouseButton1,R2=Enum.UserInputType.MouseButton2}
    local keys={Roll=Enum.KeyCode.Space,Parry=Enum.KeyCode.E,Block=Enum.KeyCode.F,Sprint=Enum.KeyCode.LeftShift,
        W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,D=Enum.KeyCode.D,Lock=Enum.KeyCode.Q}
    local time=now()
    local ok,err=pcall(function()
        if buttons[action] then
            virtual:SendMouseButton(position,buttons[action],true)
            task.wait(.025)
            virtual:SendMouseButton(position,buttons[action],false)
        elseif keys[action] then
            virtual:SendKey(true,keys[action],false)
            task.wait(hold or .025)
            virtual:SendKey(false,keys[action],false)
        elseif action=="RollBackward" or action=="RollLeft" or action=="RollRight" then
            local key=action=="RollBackward" and Enum.KeyCode.S or (action=="RollLeft" and Enum.KeyCode.A or Enum.KeyCode.D)
            virtual:SendKey(true,key,false)
            Run.Heartbeat:Wait()
            virtual:SendKey(true,Enum.KeyCode.Space,false)
            task.wait(.025)
            virtual:SendKey(false,Enum.KeyCode.Space,false)
            virtual:SendKey(false,key,false)
        else error("Unknown QA input "..tostring(action)) end
    end)
    table.insert(report.inputs,{action=action,at=time,released=now(),hold=hold,ok=ok,error=not ok and tostring(err) or nil})
end
local Visual=require(foundation.Shared.WeaponVisualConfig)
local Config=require(foundation.Shared.CombatConfig)
local function segmentBox(a,b,part)
    a,b=part.CFrame:PointToObjectSpace(a),part.CFrame:PointToObjectSpace(b)
    local d,lo,hi=b-a,0,1
    for _,axis in {"X","Y","Z"} do
        local edge=part.Size[axis]/2+.18
        if math.abs(d[axis])<1e-8 then if math.abs(a[axis])>edge then return nil end
        else
            local x,y=(-edge-a[axis])/d[axis],(edge-a[axis])/d[axis]
            if x>y then x,y=y,x end
            lo,hi=math.max(lo,x),math.min(hi,y)
            if lo>hi then return nil end
        end
    end
    return part.CFrame:PointToWorldSpace(a+d*lo)
end
local function bladeView(attacker,target)
    local weapon=attacker and attacker:FindFirstChild("CombatTestSword")
    local blade=weapon and weapon:FindFirstChildWhichIsA("MeshPart",true)
    local root=attacker and attacker:FindFirstChild("HumanoidRootPart")
    if not blade or not root or not target then return nil end
    local a=blade.CFrame:PointToWorldSpace(Vector3.new(0,-.635*Visual.MeshScale.Y,0))
    local b=blade.CFrame:PointToWorldSpace(Vector3.new(0,2.355*Visual.MeshScale.Y,0))
    local ray=RaycastParams.new()
    ray.FilterType,ray.FilterDescendantsInstances,ray.RespectCanCollide=Enum.RaycastFilterType.Exclude,{attacker,target},true
    local result={a=vector(a),b=vector(b),parts={},visible=false}
    for _,part in target:GetChildren() do
        if not part:IsA("BasePart") or part.Name=="HumanoidRootPart" then continue end
        local contact=segmentBox(a,b,part)
        if contact then
            table.insert(result.parts,part.Name)
            if not workspace:Raycast(root.Position,a-root.Position,ray) and not workspace:Raycast(a,contact-a,ray) then result.visible=true end
        end
    end
    return result
end
local function tracks(character)
    local h=character and character:FindFirstChildOfClass("Humanoid")
    local a=h and h:FindFirstChildOfClass("Animator")
    local result={}
    if a then
        for _,t in a:GetPlayingAnimationTracks() do
            if t.Priority~=Enum.AnimationPriority.Core and t.Priority.Value>=Enum.AnimationPriority.Action.Value then
                table.insert(result,{name=t.Name,id=t.Animation.AnimationId,time=t.TimePosition,weight=t.WeightCurrent,speed=t.Speed,priority=t.Priority.Name})
            end
        end
    end
    return result
end

qa.OnClientEvent:Connect(function(kind,case)
    if kind=="Ping" then qa:FireServer("Pong",case,now()); return end
    if kind~="Case" then return end
    task.spawn(function()
        local report={player=player.Name,userId=player.UserId,received=now(),t0=case.t0,inputs={},events={},samples={},healthEvents={},playEvents={},logs={},bindingEvents={},visualFrames={},
            animationFrames={scope="Every PreSimulation after animation evaluation; Action priority and above",own={frames=0,duplicateFrames=0,maxPerId=0},peer={frames=0,duplicateFrames=0,maxPerId=0},examples={}}}
        local character=player.Character
        local h=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local camera=workspace.CurrentCamera
        local savedType,savedFrame=camera.CameraType,camera.CFrame
        local savedRotate=h and h.AutoRotate
        local binding="CombatPvPQA_Camera"
        local connections={}
        local alive=true
        local ok,err=xpcall(function()
            assert(h and root,"QA character missing")
            table.insert(connections,Run.PreSimulation:Connect(function()
                if now()<case.t0-.1 or now()>case.t0+case.duration then return end
                local other=Players:FindFirstChild(case.other)
                for _,side in {"own","peer"} do
                    local stats=report.animationFrames[side]
                    local list=tracks(side=="own" and player.Character or other and other.Character)
                    local counts,duplicate={},false
                    stats.frames+=1
                    for _,track in list do
                        if track.id and track.id~="" and track.weight>.05 then
                            counts[track.id]=(counts[track.id] or 0)+1
                            stats.maxPerId=math.max(stats.maxPerId,counts[track.id])
                            if counts[track.id]>1 then duplicate=true end
                        end
                    end
                    if case.moving and #report.visualFrames<1200 then
                        local attacker=side=="own" and player.Character or other and other.Character
                        local target=side=="own" and other and other.Character or player.Character
                        for _,track in list do
                            local action=Config.Actions[track.name]
                            if action and action.active and track.weight>.05
                                and track.time>=action.active[1]-1/60 and track.time<=action.active[2]+1/60 then
                                local actorRoot=attacker and attacker:FindFirstChild("HumanoidRootPart")
                                local targetRoot=target and target:FindFirstChild("HumanoidRootPart")
                                table.insert(report.visualFrames,{at=now(),view=side,action=track.name,time=track.time,
                                    actorPosition=actorRoot and vector(actorRoot.Position),targetPosition=targetRoot and vector(targetRoot.Position),
                                    blade=bladeView(attacker,target)})
                            end
                        end
                    end
                    if duplicate then
                        stats.duplicateFrames+=1
                        if #report.animationFrames.examples<8 then table.insert(report.animationFrames.examples,{at=now(),side=side,tracks=list}) end
                    end
                end
            end))
            table.insert(connections,controller:GetAttributeChangedSignal("LastBoundInput"):Connect(function()
                table.insert(report.bindingEvents,{at=now(),input=controller:GetAttribute("LastBoundInput"),
                    state=player.Character and player.Character:GetAttribute("CombatState")})
            end))
            table.insert(connections,game:GetService("LogService").MessageOut:Connect(function(message,type)
                if type==Enum.MessageType.MessageError or message:find("Combat") or message:find("Opponent preview") then
                    if #report.logs<40 then table.insert(report.logs,{at=now(),kind=type.Name,message=message}) end
                end
            end))
            report.startPosition=vector(root.Position)
            local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z).Unit
            if case.moving then
                -- Native PlayerModule/lock-on owns the camera and facing.
                -- Only initialize the view before the future input schedule.
                camera.CameraType=Enum.CameraType.Custom
                camera.CameraSubject=h
                camera.CFrame=CFrame.lookAt(root.Position-forward*9+Vector3.new(0,4,0),root.Position+Vector3.new(0,1,0))
            else
                Run:BindToRenderStep(binding,Enum.RenderPriority.Last.Value+2,function()
                    if character.Parent then
                        h.AutoRotate=false
                        camera.CFrame=CFrame.lookAt(root.Position-forward*9+Vector3.new(0,4,0),root.Position+Vector3.new(0,1,0))
                    end
                end)
            end
            table.insert(connections,remote.OnClientEvent:Connect(function(event,owner,name,started,metadata)
                table.insert(report.events,{event=event,owner=typeof(owner)=="Instance" and owner.Name or owner,name=name,started=started,at=now(),
                    serial=type(metadata)=="table" and metadata.serial,sequence=type(metadata)=="table" and metadata.sequence,
                    character=type(metadata)=="table" and metadata.character and metadata.character.Name})
            end))
            table.insert(connections,h.HealthChanged:Connect(function(health) table.insert(report.healthEvents,{at=now(),health=health}) end))
            table.insert(connections,h.Animator.AnimationPlayed:Connect(function(t)
                if t.Priority~=Enum.AnimationPriority.Core and t.Priority.Value>=Enum.AnimationPriority.Action.Value then
                    table.insert(report.playEvents,{at=now(),name=t.Name,id=t.Animation.AnimationId})
                end
            end))
            local commands=case.inputs and (case.inputs[tostring(player.UserId)] or case.inputs) or {}
            for _,command in commands do
                task.spawn(function()
                    while alive and now()<case.t0+command.at do Run.Heartbeat:Wait() end
                    if alive then press(command.action,report,command.hold) end
                end)
            end
            local nextSample=case.t0-.1
            while now()<case.t0+case.duration do
                Run.Heartbeat:Wait()
                if now()>=nextSample then
                    nextSample=now()+.05
                    local own=player.Character
                    local ownRoot=own and own:FindFirstChild("HumanoidRootPart")
                    local other=Players:FindFirstChild(case.other)
                    local peer=other and other.Character
                    local peerRoot=peer and peer:FindFirstChild("HumanoidRootPart")
                    table.insert(report.samples,{at=now(),own=tracks(own),peer=tracks(peer),state=own and own:GetAttribute("CombatState"),
                        health=own and own:FindFirstChildOfClass("Humanoid") and own.Humanoid.Health,
                        peerState=peer and peer:GetAttribute("CombatState"),position=ownRoot and vector(ownRoot.Position),
                        phaseError=controller:GetAttribute("AnimationPhaseError"),phaseCorrection=controller:GetAttribute("AnimationPhaseCorrection"),
                        prediction=controller:GetAttribute("PredictionStatus"),ackRTT=controller:GetAttribute("PredictionAckRTT"),
                        peerPosition=case.moving and peerRoot and vector(peerRoot.Position),
                        velocity=case.moving and ownRoot and vector(ownRoot.AssemblyLinearVelocity),
                        peerVelocity=case.moving and peerRoot and vector(peerRoot.AssemblyLinearVelocity),
                        facing=case.moving and ownRoot and vector(ownRoot.CFrame.LookVector),
                        peerFacing=case.moving and peerRoot and vector(peerRoot.CFrame.LookVector),
                        anchored=case.moving and ownRoot and ownRoot.Anchored,
                        peerAnchored=case.moving and peerRoot and peerRoot.Anchored,
                        walkSpeed=case.moving and h.WalkSpeed,moveDirection=case.moving and vector(h.MoveDirection),
                        autoRotate=case.moving and h.AutoRotate,
                        facingMaxAngular=case.moving and root:FindFirstChildWhichIsA("AlignOrientation") and root:FindFirstChildWhichIsA("AlignOrientation").MaxAngularVelocity,
                        movementSuppressed=case.moving and controller:GetAttribute("MovementPredictionSuppressed"),
                        lockActive=case.moving and ownRoot and ownRoot:FindFirstChild("CombatLockFacing")~=nil,
                        ownBlade=case.moving and bladeView(own,peer),peerBlade=case.moving and bladeView(peer,own)})
                end
            end
            report.endPosition=vector(root.Position)
            report.finalState=player.Character and player.Character:GetAttribute("CombatState")
        end,debug.traceback)
        alive=false
        for _,c in connections do c:Disconnect() end
        Run:UnbindFromRenderStep(binding)
        if case.moving and root and root:FindFirstChild("CombatLockFacing") then pcall(function() press("Lock",report) end) end
        camera.CameraType,camera.CFrame=savedType,savedFrame
        if h and h.Parent then h.AutoRotate=savedRotate end
        for _,key in {Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Space,Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.LeftShift} do pcall(function() virtual:SendKey(false,key,false) end) end
        if not ok then report.error=tostring(err) end
        report.restored=true
        qa:FireServer("Report",case.id,report)
    end)
end)
