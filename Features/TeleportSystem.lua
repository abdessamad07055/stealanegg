--==================================================
-- YOKUDO HUB - EGG COLLECT (Y CHANGE 2 ROUNDS)
-- Round 1: Fly TP + Lock Behind 3 + Save Y + Collect
-- Y Change (1) -> Save YChanged -> Wait Y Return
-- Round 2: Y Return -> Fly TP + Lock Behind 3 + Collect
-- Y Change (2) -> Fly TP Safe Zone
-- Uid: 26f67a4a6dcc48dda9880599bafc6f76
-- Safe Zone: (533, 70, -366)
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Container = workspace:WaitForChild("AreaEggSlotsClient")

--==================================================
-- EVENT
--==================================================

local Event = nil

local success, result = pcall(function()
    return ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

if not success or not result then
    warn("[YOKUDO] Event not found")
    return
end

Event = result
print("[YOKUDO] Event found:", Event.ClassName)

--==================================================
-- SETTINGS
--==================================================

local TARGET_UID = "26f67a4a6dcc48dda9880599bafc6f76"
local SAFE_ZONE = Vector3.new(533, 70, -366)

local FLY_SPEED = 500
local RETURN_SPEED = 350
local FLY_OFFSET = 3
local SHOT_DISTANCE = 30
local ARRIVE_DISTANCE = 2
local SAFE_LOCK_DISTANCE = 3

local MIN_FLY_DISTANCE = 4
local LOCK_BEHIND = 3
local Y_CHANGE_THRESHOLD = 1
local Y_RETURN_THRESHOLD = 1

local LOOP_INTERVAL = 0.05
local COLLECT_INTERVAL = 0.01

-- TARGET
local TargetEgg = nil
local YOriginal = nil
local YChanged = nil
local ConfirmCount = 0
local IsGoingSafe = false
local IsWaitingReturn = false
local LockedCFrame = nil
local IsLocked = false

--==================================================
-- STATE
--==================================================

local Running = false
local CurrentStep = "idle"
local FlyConnection = nil
local LockConnection = nil
local CollectConnection = nil
local HeartbeatConnection = nil
local BodyVelocity = nil
local BodyGyro = nil

local SavedWalkSpeed = nil
local SavedJumpPower = nil
local SavedJumpHeight = nil
local SavedUseJumpPower = nil

--==================================================
-- GET HUMANOID
--==================================================

local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

--==================================================
-- SAVE / RESTORE
--==================================================

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

--==================================================
-- CLEANUP
--==================================================

local function CleanupMovers()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    if LockConnection then
        LockConnection:Disconnect()
        LockConnection = nil
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
    IsLocked = false
end

--==================================================
-- FIND EGG
--==================================================

local function FindEggInContainer()
    if not Container then return nil end
    local Direct = Container:FindFirstChild(TARGET_UID)
    if Direct then return Direct end
    for _, Desc in ipairs(Container:GetDescendants()) do
        if Desc.Name == TARGET_UID then return Desc end
    end
    return nil
end

local function FindEggInWorkspace()
    local WSEgg = workspace:FindFirstChild(TARGET_UID)
    if WSEgg then return WSEgg end
    for _, Desc in ipairs(workspace:GetChildren()) do
        if Desc.Name == TARGET_UID then return Desc end
    end
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

--==================================================
-- GET LOCK POSITION (Behind Egg 3)
--==================================================

local function GetLockCFrame(EggPos)
    local Hum, Root = GetHumanoid()
    if not Root then return CFrame.new(EggPos + Vector3.new(0, FLY_OFFSET, 0)) end

    local Dir = (EggPos - Root.Position)
    local FlatDir = Vector3.new(Dir.X, 0, Dir.Z)

    if FlatDir.Magnitude > 0.1 then
        FlatDir = FlatDir.Unit
    else
        FlatDir = Vector3.new(0, 0, 1)
    end

    local LockPos = EggPos - (FlatDir * LOCK_BEHIND) + Vector3.new(0, FLY_OFFSET, 0)

    return CFrame.new(LockPos, EggPos)
end

--==================================================
-- REMOTE COLLECT
--==================================================

local function RemoteCollectEgg()
    if not Event then return false end

    local success, result = pcall(function()
        return Event:InvokeServer({
            Uid = TARGET_UID
        })
    end)

    if success then
        return true
    else
        return false
    end
end

--==================================================
-- LOCK AT EGG (Behind 3)
--==================================================

local function StartLock(TargetCFrame)
    IsLocked = true
    LockedCFrame = TargetCFrame

    if LockConnection then
        LockConnection:Disconnect()
    end

    LockConnection = RunService.Heartbeat:Connect(function()
        if not IsLocked then return end
        if not Running then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end

        local Hum, Root = GetHumanoid()
        if not Root then return end

        Root.CFrame = LockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function StopLock()
    IsLocked = false
    LockedCFrame = nil

    if LockConnection then
        LockConnection:Disconnect()
        LockConnection = nil
    end
end

--==================================================
-- FLY TP
--==================================================

local function FlyTP(Destination, Speed, UseShotTP, LockAfter, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)
    local LockCFrame = CFrame.new(FlyPos)

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

            if LockAfter then
                StartLock(LockCFrame)
            end

            if Callback then Callback() end
            return
        end

        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            CleanupMovers()

            Hum2.PlatformStand = false
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            if LockAfter then
                StartLock(LockCFrame)
            end

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

--==================================================
-- AUTO COLLECT (Heartbeat 0.01s)
--==================================================

local function StartAutoCollect()
    if CollectConnection then
        CollectConnection:Disconnect()
    end

    CollectConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            if CollectConnection then CollectConnection:Disconnect() CollectConnection = nil end
            return
        end
        if IsGoingSafe then return end
        if IsWaitingReturn then return end

        RemoteCollectEgg()
    end)
end

local function StopAutoCollect()
    if CollectConnection then
        CollectConnection:Disconnect()
        CollectConnection = nil
    end
end

--==================================================
-- HEARTBEAT - CHECK Y
--==================================================

local function StartHeartbeat()
    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
    end

    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not Running then return end
        if IsGoingSafe then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        local CurrentEgg = workspace:FindFirstChild(TARGET_UID) or (Container and Container:FindFirstChild(TARGET_UID))
        local CurrentY = nil

        if CurrentEgg then
            CurrentY = GetEggY(CurrentEgg)
        end

        -- WAIT Y RETURN (Round 2)
        if IsWaitingReturn then
            if CurrentY and YOriginal then
                local YDiff = math.abs(CurrentY - YOriginal)

                if YDiff <= Y_RETURN_THRESHOLD then
                    IsWaitingReturn = false

                    TargetEgg = CurrentEgg
                    YChanged = nil

                    CurrentStep = "to_egg_2"

                    local EggPos = GetEggPosition(CurrentEgg)
                    if EggPos then
                        local LockCF = GetLockCFrame(EggPos)
                        FlyTP(EggPos, FLY_SPEED, false, false, function()
                            StartLock(LockCF)
                            StartAutoCollect()
                        end)
                    end
                end
            end
            return
        end

        -- CHECK Y CHANGE (Confirm)
        if CurrentY and YOriginal and not IsGoingSafe then
            local YDiff = math.abs(CurrentY - YOriginal)

            if YDiff >= Y_CHANGE_THRESHOLD then
                if ConfirmCount == 0 then
                    ConfirmCount = 1
                    YChanged = CurrentY

                    StopAutoCollect()
                    StopLock()

                    IsWaitingReturn = true
                    TargetEgg = nil
                    CurrentStep = "idle"

                elseif ConfirmCount == 1 then
                    ConfirmCount = 2

                    StopAutoCollect()
                    StopLock()

                    IsGoingSafe = true

                    FlyTP(SAFE_ZONE, RETURN_SPEED, false, false, function()
                        IsGoingSafe = false
                        FullReset()
                    end)
                end
            end
        end
    end)
end

local function StopHeartbeat()
    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end
end

--==================================================
-- FULL RESET
--==================================================

function FullReset()
    Running = false
    CurrentStep = "idle"

    TargetEgg = nil
    YOriginal = nil
    YChanged = nil
    ConfirmCount = 0
    IsGoingSafe = false
    IsWaitingReturn = false
    LockedCFrame = nil
    IsLocked = false

    CleanupMovers()
    StopLock()
    StopAutoCollect()
    StopHeartbeat()
    RestoreStats()

    print("[YOKUDO] Full Reset")
end

--==================================================
-- MAIN LOOP
--==================================================

task.spawn(function()
    while task.wait(LOOP_INTERVAL) do
        if not Running then continue end
        if IsGoingSafe then continue end
        if IsWaitingReturn then continue end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then continue end
        if Hum.Health <= 0 then continue end

        local CachedSpawnEgg = FindEggInContainer()
        local CachedWSEgg = FindEggInWorkspace()

        local CurrentEgg = CachedWSEgg or CachedSpawnEgg

        -- ROUND 1: IDLE - Find Egg
        if CurrentStep == "idle" and ConfirmCount == 0 then
            local EggFound = CachedWSEgg or CachedSpawnEgg

            if EggFound then
                local EggPos = GetEggPosition(EggFound)
                if EggPos then
                    local Dist = GetEggDistance(EggFound)
                    if Dist > MIN_FLY_DISTANCE then
                        TargetEgg = EggFound

                        YOriginal = GetEggY(EggFound)

                        CurrentStep = "to_egg_1"

                        FlyTP(EggPos, FLY_SPEED, false, false, function()
                            local LockCF = GetLockCFrame(EggPos)
                            StartLock(LockCF)
                            StartAutoCollect()
                        end)
                    end
                end
            end
        end
    end
end)

--==================================================
-- ENABLE / DISABLE / SET TARGET
--==================================================

local function Enable()
    if Running then return end

    FullReset()
    Running = true
    CurrentStep = "idle"
    ConfirmCount = 0
    IsGoingSafe = false
    IsWaitingReturn = false
    YOriginal = nil
    YChanged = nil
    SaveStats()

    StartHeartbeat()

    print("[YOKUDO] Teleport System: ON")
end

local function Disable()
    FullReset()
    print("[YOKUDO] Teleport System: OFF")
end

local function SetTargetId(Id)
    TARGET_UID = Id
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
        ConfirmCount = ConfirmCount,
        TargetId = TARGET_UID,
        YOriginal = YOriginal,
        YChanged = YChanged
    }
end

--==================================================
-- EXPORT
--==================================================
_G.YOKUDO_TeleportSystem = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    ResetState = ResetState,
    GetState = GetState,
    IsEnabled = function() return Running end,
    GetTargetId = function() return TARGET_UID end
}

print("[YOKUDO] Remote Collect loaded (2 Rounds Y)")
print("[YOKUDO] Lock Behind:", LOCK_BEHIND)
print("[YOKUDO] Min Fly Distance:", MIN_FLY_DISTANCE)
print("[YOKUDO] Uid:", TARGET_UID)
print("[YOKUDO] Event:", Event)
