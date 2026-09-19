-- ==================================================
-- YOKUDO HUB | FEATURE | Teleport System
-- Egg Collect + Fast Return to Safe
-- Remote Collect + Distance 8 + No Hover
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- EVENT (REMOTE FOR COLLECT)
-- ==================================================
local Event = nil

local success, result = pcall(function()
    return ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

if success and result then
    Event = result
    print("[YOKUDO] Event found:", Event.ClassName)
else
    warn("[YOKUDO] Event not found")
end

-- ==================================================
-- SETTINGS
-- ==================================================
local SAFE_ZONE = Vector3.new(533, 70, -366)

local FLY_SPEED = 1000
local RETURN_SPEED = 950
local FLY_OFFSET = 15
local SHOT_DISTANCE = 30
local ARRIVE_DISTANCE = 2
local SAFE_LOCK_DISTANCE = 3

local MIN_FLY_DISTANCE = 3
local LOCK_DISTANCE = 8 -- ចម្ងាយ 8 សម្រាប់ Lock
local Y_CHANGE_THRESHOLD = 1

-- CAMERA SETTINGS (Top-Down View)
local CAMERA_HEIGHT = 3
local CAMERA_DISTANCE = 0
local CAMERA_ZOOM_STEP = 0.5
local CAMERA_MIN_HEIGHT = 1
local LOCK_WAIT = 0.2

local LOOP_INTERVAL = 0.02
local RETRY_WAIT = 2
local COLLECT_TARGET = 2

-- ==================================================
-- STATE
-- ==================================================
local TARGET_ID = nil
local CollectCount = 0

local Running = false
local CurrentStep = "idle"
local TargetEgg = nil
local LockStartTime = 0
local CurrentCameraHeight = CAMERA_HEIGHT
local SavedYBefore = nil
local CollectDone = false
local RetryStartTime = 0
local WaitingRetry = false
local GoingToSafe = false
local OriginalCameraSubject = nil
local CameraLocked = false

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local ActiveHeartbeat = nil
local MainLoop = nil
local CollectConnection = nil

local SavedWalkSpeed = nil
local SavedJumpPower = nil
local SavedJumpHeight = nil
local SavedUseJumpPower = nil

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

-- ==================================================
-- SAVE / RESTORE
-- ==================================================
local function SaveStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    SavedWalkSpeed = Hum.WalkSpeed
    SavedJumpPower = Hum.JumpPower
    SavedJumpHeight = Hum.JumpHeight
    SavedUseJumpPower = Hum.UseJumpPower
end

local function RestoreStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if SavedWalkSpeed ~= nil then pcall(function() Hum.WalkSpeed = SavedWalkSpeed end) end
    if SavedJumpPower ~= nil then pcall(function() Hum.JumpPower = SavedJumpPower end) end
    if SavedJumpHeight ~= nil then pcall(function() Hum.JumpHeight = SavedJumpHeight end) end
    if SavedUseJumpPower ~= nil then pcall(function() Hum.UseJumpPower = SavedUseJumpPower end) end
end

-- ==================================================
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    if BodyVelocity then
        pcall(function()
            BodyVelocity.Velocity = Vector3.zero
            BodyVelocity.MaxForce = Vector3.zero
        end)
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        pcall(function() BodyGyro.MaxTorque = Vector3.zero end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end
    local Hum, Root = GetHumanoid()
    if Hum then pcall(function() Hum.PlatformStand = false end) end
    if Root then
        pcall(function()
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ==================================================
-- FIND EGG (Check ទាំង Container និង Workspace)
-- ==================================================
local function FindEggAnywhere()
    if not TARGET_ID then return nil end
    
    if Container then
        local Egg = Container:FindFirstChild(TARGET_ID)
        if Egg then return Egg end
    end
    
    local Egg = workspace:FindFirstChild(TARGET_ID)
    if Egg then return Egg end
    
    return nil
end

local function GetEggPosition(Egg)
    if not Egg then return nil end
    if Egg:IsA("Model") then
        if Egg.PrimaryPart then return Egg.PrimaryPart.Position end
        local Part = Egg:FindFirstChildWhichIsA("BasePart")
        if Part then return Part.Position end
    elseif Egg:IsA("BasePart") then
        return Egg.Position
    end
    return nil
end

local function GetEggY(Egg)
    local Pos = GetEggPosition(Egg)
    if not Pos then return nil end
    return math.floor(Pos.Y)
end

local function GetEggDistance(Egg)
    local Hum, Root = GetHumanoid()
    if not Root then return 9999 end
    local EggPos = GetEggPosition(Egg)
    if not EggPos then return 9999 end
    return (EggPos - Root.Position).Magnitude
end

-- ==================================================
-- REMOTE COLLECT
-- ==================================================
local function RemoteCollectEgg()
    if not Event or not TARGET_ID then return false end

    local success, result = pcall(function()
        return Event:InvokeServer({
            Uid = TARGET_ID
        })
    end)

    return success
end

-- ==================================================
-- CAMERA FORCE (Top-Down View - មើលពីលើ)
-- ==================================================
local function ForceCameraToEgg(EggPos, Height)
    if not Camera then return end

    if OriginalCameraSubject == nil then
        OriginalCameraSubject = Camera.CameraSubject
    end

    Camera.CameraType = Enum.CameraType.Scriptable
    CameraLocked = true

    local H = Height or CAMERA_HEIGHT
    local CamPos = EggPos + Vector3.new(0, H, 0)

    Camera.CFrame = CFrame.new(CamPos, EggPos)
    Camera.Focus = CFrame.new(EggPos)
end

local function ResetCamera()
    if not Camera then return end

    Camera.CameraType = Enum.CameraType.Custom
    CameraLocked = false

    local Hum, Root = GetHumanoid()
    if Hum then
        Camera.CameraSubject = Hum
    elseif OriginalCameraSubject then
        Camera.CameraSubject = OriginalCameraSubject
    end

    OriginalCameraSubject = nil
end

-- ==================================================
-- FACE EGG
-- ==================================================
local function FaceEgg(EggPos)
    local Hum, Root = GetHumanoid()
    if not Root then return end

    local Direction = (EggPos - Root.Position)
    local FlatDir = Vector3.new(Direction.X, 0, Direction.Z)

    if FlatDir.Magnitude > 0.1 then
        Root.CFrame = CFrame.new(Root.Position, Root.Position + FlatDir.Unit)
    end
end

-- ==================================================
-- FLY TP
-- ==================================================
local function FlyTP(Destination, Speed, UseShotTP, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)
    local LockCFrame = CFrame.new(Destination)

    Hum.PlatformStand = true
    Hum.WalkSpeed = 0
    Hum.JumpPower = 0

    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Name = "YokudoBV"
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1250
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = Root

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = "YokudoBG"
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 3000
    BodyGyro.D = 500
    BodyGyro.CFrame = Root.CFrame
    BodyGyro.Parent = Root

    local StartTime = tick()
    local ShotDone = false

    FlyConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            CleanupMovers()
            return
        end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 then
            CleanupMovers()
            return
        end
        if Hum2.Health <= 0 then return end

        if not BodyVelocity or not BodyGyro then
            CleanupMovers()
            return
        end

        local CurrentPos = Root2.Position
        local Direction = (FlyPos - CurrentPos)
        local HorizDist = Vector3.new(Direction.X, 0, Direction.Z).Magnitude
        local VertDist = math.abs(Direction.Y)
        local TotalDist = Direction.Magnitude

        -- SAFE ZONE
        if Speed == RETURN_SPEED then
            if HorizDist <= SAFE_LOCK_DISTANCE then
                CleanupMovers()

                Hum2.PlatformStand = false
                Root2.CFrame = CFrame.new(SAFE_ZONE)
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero

                if Callback then Callback() end
                return
            end
        end

        if UseShotTP and HorizDist <= SHOT_DISTANCE and not ShotDone then
            ShotDone = true
            CleanupMovers()

            Hum2.PlatformStand = false
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            if Callback then Callback() end
            return
        end

        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            CleanupMovers()

            Hum2.PlatformStand = false
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            if Callback then Callback() end
            return
        end

        if tick() - StartTime > 15 then
            CleanupMovers()
            Hum2.PlatformStand = false
            if Callback then Callback() end
            return
        end

        if TotalDist > 1 then
            BodyVelocity.Velocity = Direction.Unit * Speed
        else
            BodyVelocity.Velocity = Vector3.zero
        end

        BodyGyro.CFrame = CFrame.new(CurrentPos, CurrentPos + Vector3.new(Direction.X, 0, Direction.Z))
    end)
end

-- ==================================================
-- AUTO COLLECT (REMOTE)
-- ==================================================
local function StartAutoCollect()
    if CollectConnection then
        CollectConnection:Disconnect()
    end

    CollectConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            if CollectConnection then CollectConnection:Disconnect() CollectConnection = nil end
            return
        end
        if GoingToSafe then return end
        if WaitingRetry then return end

        RemoteCollectEgg()
    end)
end

local function StopAutoCollect()
    if CollectConnection then
        CollectConnection:Disconnect()
        CollectConnection = nil
    end
end

-- ==================================================
-- FLY TO SAFE ZONE
-- ==================================================
local function FlyToSafeZone()
    GoingToSafe = true
    CurrentStep = "to_safe"

    StopAutoCollect()
    ResetCamera()

    FlyTP(SAFE_ZONE, RETURN_SPEED, false, function()
        CurrentStep = "stop"
    end)
end

-- ==================================================
-- RESET STATE RETRY (Round #1 → Round #2)
-- ==================================================
local function ResetStateRetry()
    TargetEgg = nil
    LockStartTime = 0
    SavedYBefore = nil
    CollectDone = false
    WaitingRetry = false
    RetryStartTime = 0
    GoingToSafe = false

    CleanupMovers()
    StopAutoCollect()

    CurrentStep = "idle"
    print("[YOKUDO] State Reset - Retry #" .. (CollectCount + 1))
end

-- ==================================================
-- FULL RESET (Fast)
-- ==================================================
local function FullReset()
    Running = false
    CurrentStep = "idle"

    TargetEgg = nil
    LockStartTime = 0
    CurrentCameraHeight = CAMERA_HEIGHT
    SavedYBefore = nil
    CollectDone = false
    WaitingRetry = false
    RetryStartTime = 0
    GoingToSafe = false
    CollectCount = 0

    CleanupMovers()
    StopAutoCollect()

    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end
    if MainLoop then
        MainLoop:Disconnect()
        MainLoop = nil
    end
    ResetCamera()
    RestoreStats()

    print("[YOKUDO] Full Reset")
end

-- ==================================================
-- HEARTBEAT (Active)
-- ==================================================
local function StartActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end

    ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not Running then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        -- WAIT RETRY (2s before retry)
        if WaitingRetry then
            local Elapsed = tick() - RetryStartTime

            if Elapsed >= RETRY_WAIT then
                if CollectCount >= COLLECT_TARGET then
                    WaitingRetry = false
                    FlyToSafeZone()
                else
                    ResetStateRetry()
                end
            end
            return
        end

        -- FAST Y CHECK (Confirm Collect)
        local CurrentEgg = FindEggAnywhere()
        local CurrentY = nil

        if CurrentEgg then
            CurrentY = GetEggY(CurrentEgg)
        end

        if SavedYBefore and CurrentY and not CollectDone then
            if CurrentY - SavedYBefore >= Y_CHANGE_THRESHOLD then
                CollectDone = true
                CollectCount = CollectCount + 1

                if CollectCount >= COLLECT_TARGET then
                    FlyToSafeZone()
                else
                    WaitingRetry = true
                    RetryStartTime = tick()
                end
            end
        end

        -- LOCK + FACE + CAMERA
        if CurrentStep == "lock_egg" then
            if not TargetEgg then
                CurrentStep = "idle"
                return
            end

            local EggPos = GetEggPosition(TargetEgg)
            if not EggPos then
                CurrentStep = "idle"
                TargetEgg = nil
                return
            end

            Root.CFrame = CFrame.new(EggPos)
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero

            FaceEgg(EggPos)
            ForceCameraToEgg(EggPos, CurrentCameraHeight)

            local Elapsed = tick() - LockStartTime

            if Elapsed >= LOCK_WAIT then
                local Y = GetEggY(TargetEgg)
                if Y and not SavedYBefore then
                    SavedYBefore = Y
                end
            end

        elseif CurrentStep == "to_safe" then
            -- Handled by FlyToSafeZone

        elseif CurrentStep == "stop" then
            FullReset()
        end
    end)
end

local function StopActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end
end

-- ==================================================
-- MAIN LOOP (Check Egg → Fly TP)
-- ==================================================
local function StartMainLoop()
    if MainLoop then
        MainLoop:Disconnect()
        MainLoop = nil
    end

    MainLoop = RunService.Heartbeat:Connect(function()
        if not Running then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        if WaitingRetry then return end
        if GoingToSafe then return end

        local CachedEgg = FindEggAnywhere()

        if CurrentStep == "idle" and CachedEgg then
            local EggPos = GetEggPosition(CachedEgg)
            if EggPos then
                local Dist = GetEggDistance(CachedEgg)
                if Dist > MIN_FLY_DISTANCE then
                    TargetEgg = CachedEgg
                    SavedYBefore = nil

                    CurrentStep = "to_egg"

                    FlyTP(EggPos, FLY_SPEED, true, function()
                        LockStartTime = tick()
                        CurrentStep = "lock_egg"
                        StartAutoCollect()
                    end)
                end
            end
        end
    end)
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function Enable()
    if Running then return end
    if not Event then
        warn("[YOKUDO] Event not found - Cannot start")
        return
    end
    if not TARGET_ID then
        warn("[YOKUDO] No Target ID - Cannot start")
        return
    end

    FullReset()

    Running = true
    CurrentStep = "idle"
    CollectDone = false
    SavedYBefore = nil
    WaitingRetry = false
    GoingToSafe = false
    CollectCount = 0
    SaveStats()

    StartActiveHeartbeat()
    StartMainLoop()

    print("[YOKUDO] Teleport System: ON")
end

local function Disable()
    FullReset()
    print("[YOKUDO] Teleport System: OFF")
end

local function SetTargetId(Id)
    TARGET_ID = Id
    print("[YOKUDO] Teleport System Target ID: " .. tostring(Id))
end

local function ResetState()
    FullReset()
    print("[YOKUDO] Teleport System: State Reset")
end

local function GetState()
    return {
        Running = Running,
        CurrentStep = CurrentStep,
        CollectCount = CollectCount,
        TargetId = TARGET_ID,
        CameraLocked = CameraLocked,
        CameraHeight = CurrentCameraHeight
    }
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_TeleportSystem = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    ResetState = ResetState,
    GetState = GetState,
    IsEnabled = function() return Running end,
    GetTargetId = function() return TARGET_ID end
}

print("✅ TeleportSystem Feature Loaded (Remote Collect + Distance 8 + No Hover)")
