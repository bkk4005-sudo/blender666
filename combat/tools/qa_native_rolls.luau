-- Client Play observer for four native roll inputs. No action is fabricated.
-- A temporary fixed camera and disabled default AutoRotate make W/A/S/D
-- select predictable relative clips; root physics remain unanchored.
-- Camera/AutoRotate and connections restore automatically after 40 seconds.
local player = game.Players.LocalPlayer
local character = player.Character
local humanoid, root = character.Humanoid, character.HumanoidRootPart
local camera = workspace.CurrentCamera
local Run = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.CombatFoundation.Shared.CombatConfig)
local oldType, oldFrame, oldRotate = camera.CameraType, camera.CFrame, humanoid.AutoRotate
local forward = Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z).Unit
local binding = "CombatQA_FixedRollCamera"
local result = player.PlayerGui:FindFirstChild("NativeRollQA")
if result then result:Destroy() end
result = Instance.new("StringValue")
result.Name, result.Parent = "NativeRollQA", player.PlayerGui
camera.CameraType = Enum.CameraType.Scriptable
Run:BindToRenderStep(binding,Enum.RenderPriority.Last.Value+2,function()
    if character.Parent then
        humanoid.AutoRotate=false
        camera.CFrame=CFrame.lookAt(root.Position-forward*10+Vector3.new(0,5,0),root.Position+Vector3.new(0,1,0))
    end
end)
task.spawn(function()
    local report={scope="Native input; fixed test camera/default AutoRotate disabled for directional selection; unanchored root",
        actions={}, inputs={}, missingRollFrames=0, competingRollFrames=0}
    local current, connections = nil, {}
    local function finish(reason)
        if not current then return end
        local delta=root.Position-current.origin
        current.displacement=delta.Magnitude
        current.delta={delta.X,delta.Y,delta.Z}
        current.observedDuration=workspace:GetServerTimeNow()-current.started
        current.endedBy=reason
        current.origin,current.started=nil,nil
        table.insert(report.actions,current)
        current=nil
    end
    local ok,failure=xpcall(function()
        table.insert(connections,game.ReplicatedStorage.CombatFoundation.CombatRemote.OnClientEvent:Connect(function(kind,owner,name,at)
            if kind~="Started" or owner~=player then return end
            finish("Started:"..name)
            current={name=name,started=at,origin=root.Position,frames=0,maximumTime=0,
                expectedDuration=Config.Actions[name].duration,peakHorizontalVelocity=0}
        end))
        local controller=player.PlayerScripts.CombatClient
        table.insert(connections,controller:GetAttributeChangedSignal("LastBoundInput"):Connect(function()
            table.insert(report.inputs,{input=controller:GetAttribute("LastBoundInput"),
                action=current and current.name,elapsed=current and workspace:GetServerTimeNow()-current.started})
        end))
        local ending=os.clock()+40
        while os.clock()<ending do
            Run.Heartbeat:Wait()
            if not current then continue end
            local found=false
            for _,track in humanoid.Animator:GetPlayingAnimationTracks() do
                if track.Name==current.name then
                    found=true
                    current.maximumTime=math.max(current.maximumTime,track.TimePosition)
                    current.priority,current.speed=track.Priority.Name,track.Speed
                elseif current.name:sub(1,4)=="Roll" and track.Priority~=Enum.AnimationPriority.Core
                    and track.Priority.Value>=Enum.AnimationPriority.Action.Value and track.WeightCurrent>.01 then
                    report.competingRollFrames+=1
                end
            end
            local state=character:GetAttribute("CombatState")
            if (state=="Idle" or state=="Moving") and current.frames>0 then finish(state); continue end
            if state=="Rolling" then
                current.frames+=1
                if not found then report.missingRollFrames+=1 end
                local velocity=root.AssemblyLinearVelocity
                current.peakHorizontalVelocity=math.max(current.peakHorizontalVelocity,Vector3.new(velocity.X,0,velocity.Z).Magnitude)
            end
        end
        finish("ObservationEnded")
    end,debug.traceback)
    for _,connection in connections do connection:Disconnect() end
    Run:UnbindFromRenderStep(binding)
    camera.CameraType,camera.CFrame,humanoid.AutoRotate=oldType,oldFrame,oldRotate
    report.restored=true
    if not ok then report.error=tostring(failure) end
    result.Value=game.HttpService:JSONEncode(report)
end)
return "40-second directional native roll observer started; camera restores automatically"
