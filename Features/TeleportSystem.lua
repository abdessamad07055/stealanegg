--==================================================
-- YOKUDO HUB - TELEPORT SYSTEM (ROUND 2 - WAIT AT GUARD)
-- Round 1: First Egg → Collect → Fly to Guard → Wait
-- Round 2: Egg back to Spawn → Fly Target → Collect
--          → Fly Safe → Auto Stop
-- TARGET_ID: From Auto Farming Tab
-- Safe Zone: (533, 70, -366)
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local Container = workspace:WaitForChild("AreaEggSlotsClient")

--==================================================
-- GUARD
--==================================================

local function GetGuard()
    local Guard = nil
    pcall(function()
        Guard = workspace.__OBJECTS.Areas.GuardAreas.Forest.Guard
    end)
    return Guard
end

--==================================================
-- REMOTE
--==================================================

local CollectEvent = nil

pcall(function()
    CollectEvent = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

if not CollectEvent then
    warn("[YOKUDO] CollectEvent not found")
    return
end

print("[YOKUDO] CollectEvent OK")

--==================================================
-- SETTINGS
--==================================================

local TARGET_UID = nil
local SAFE_ZONE = Vector3.new(533, 70, -366)

local FLY_SPEED = 1000
local RETURN_SPEED = 1000 -- កែពី 350 ទៅ 1000
local FLY_OFFSET = 3
local SHOT_DISTANCE = 30
local ARRIVE_DISTANCE = 2
local SAFE_LOCK_DISTANCE = 3

local COLLECT_INTERVAL = 0.2
local SEARCH_PREFIX = "FirstAreaEgg"

--==================================================
-- STATE
--==================================================

local Running = false
local CurrentStep = "idle"

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local ActiveHeartbeat = nil

local FirstEggList = {}
local FirstEggUid = nil
local FirstEggSlotKey = nil

local CollectAttempts = 0
local CollectTime = 0

local FlyTargetStarted = false
local CollectDone = false
local TargetCollected = false
local GuardReached = false

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

    if SavedWalkSpeed == nil then SavedWalkSpeed = Hum.WalkSpeed end
    if SavedJumpPower == nil then SavedJumpPower = Hum.JumpPower end
    if SavedJumpHeight == nil then SavedJumpHeight = Hum.JumpHeight end
    if SavedUseJumpPower == nil then SavedUseJumpPower = Hum.UseJumpPower end

    print("[YOKUDO] Saved | WalkSpeed:", SavedWalkSpeed)
end

local function RestoreStats()
    local Hum = GetHumanoid()
    if not Hum then return end

    if SavedWalkSpeed ~= nil then pcall(function() Hum.WalkSpeed = SavedWalkSpeed end) end
    if SavedJumpPower ~= nil then pcall(function() Hum.JumpPower = SavedJumpPower end) end
    if SavedJumpHeight ~= nil then pcall(function() Hum.JumpHeight = SavedJumpHeight end) end
    if SavedUseJumpPower ~= nil then pcall(function() Hum.UseJumpPower = SavedUseJumpPower end) end

    print("[YOKUDO] Restored | WalkSpeed:", SavedWalkSpeed)
end

--==================================================
-- CLEANUP
--==================================================

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
        pcall(function()
            BodyGyro.MaxTorque = Vector3.zero
        end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end

    local Hum, Root = GetHumanoid()
    if Root then
        for _, Child in ipairs(Root:GetChildren()) do
            if Child.Name == "YokudoBV" or Child.Name == "YokudoBG" then
                pcall(function() Child:Destroy() end)
            end
        end
    end

    if Hum then
        pcall(function()
            Hum.PlatformStand = false
            Hum.Sit = false
        end)
    end

    if Root then
        pcall(function()
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

--==================================================
-- GET POSITION
--==================================================

local function GetPosition(Object)
    if not Object then return nil end
    if Object:IsA("Model") then
        if Object.PrimaryPart then return Object.PrimaryPart.Position end
        local Part = Object:FindFirstChildWhichIsA("BasePart")
        if Part then return Part.Position end
        for _, Desc in ipairs(Object:GetDescendants()) do
            if Desc:IsA("BasePart") then return Desc.Position end
        end
    elseif Object:IsA("BasePart") then
        return Object.Position
    end
    return nil
end

--==================================================
-- SEARCH FIRST EGGS
--==================================================

local function SearchFirstEggs()
    FirstEggList = {}
    if not Container then return end

    for _, Slot in ipairs(Container:GetChildren()) do
        if string.find(Slot.Name, SEARCH_PREFIX) then
            local SlotNum = string.match(Slot.Name, "Slot_(%d+)")
            if SlotNum then
                table.insert(FirstEggList, {
                    Slot = Slot,
                    Uid = Slot.Name,
                    SlotKey = "Forest:Slot_" .. SlotNum,
                    SlotNum = tonumber(SlotNum)
                })
            end
        end
    end
end

local function FindClosestEgg()
    local Hum, Root = GetHumanoid()
    if not Root then return nil end

    local Closest = nil
    local ClosestDistance = 9999

    for _, Egg in ipairs(FirstEggList) do
        local Pos = GetPosition(Egg.Slot)
        if Pos then
            local Dist = (Pos - Root.Position).Magnitude
            if Dist < ClosestDistance then
                ClosestDistance = Dist
                Closest = Egg
            end
        end
    end

    if Closest then
        FirstEggUid = Closest.Uid
        FirstEggSlotKey = Closest.SlotKey
    end

    return Closest
end

--==================================================
-- FLY TP
--==================================================

local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)
    local LockCFrame = CFrame.new(Destination)

    Hum.PlatformStand = true

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

        if IsSafeZone and HorizDist <= SAFE_LOCK_DISTANCE then
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            if Callback then Callback() end
            return
        end

        if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= SHOT_DISTANCE then
            ShotDone = true
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            if Callback then Callback() end
            return
        end

        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > 15 then
            CleanupMovers()
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
-- REMOTE COLLECT
--==================================================

local function RemoteCollectFirst()
    if not CollectEvent or not FirstEggSlotKey or not FirstEggUid then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            FirstAreaSlotKey = FirstEggSlotKey,
            Uid = FirstEggUid
        })
    end)
    return success
end

local function RemoteCollectTarget()
    if not CollectEvent or not TARGET_UID then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            Uid = TARGET_UID
        })
    end)
    return success
end

--==================================================
-- CHECK
--==================================================

local function IsFirstEggInWorkspace()
    if not FirstEggUid then return false end
    return workspace:FindFirstChild(FirstEggUid) ~= nil
end

local function IsFirstEggInContainer()
    if not FirstEggUid then return false end
    if not Container then return false end
    return Container:FindFirstChild(FirstEggUid) ~= nil
end

local function IsTargetEggInWorkspace()
    if not TARGET_UID then return false end
    return workspace:FindFirstChild(TARGET_UID) ~= nil
end

local function IsTargetEggInContainer()
    if not TARGET_UID then return false end
    if not Container then return false end
    return Container:FindFirstChild(TARGET_UID) ~= nil
end

--==================================================
-- AUTO STOP
--==================================================

local function AutoStop()
    Running = false
    CurrentStep = "done"

    CleanupMovers()
    StopActiveHeartbeat()
    RestoreStats()

    print("[YOKUDO] Auto Stop")
end

--==================================================
-- FLY TO GUARD
--==================================================

local function FlyToGuard()
    local Guard = GetGuard()

    if not Guard then
        task.spawn(function() StartFlyToTarget() end)
        return
    end

    local GuardPos = GetPosition(Guard)
    if not GuardPos then
        task.spawn(function() StartFlyToTarget() end)
        return
    end

    CurrentStep = "to_guard"

    FlyTP(GuardPos, FLY_SPEED, true, false, function()
        CurrentStep = "wait_guard"
        GuardReached = true
    end)
end

--==================================================
-- FLY TO TARGET
--==================================================

function StartFlyToTarget()
    if FlyTargetStarted then return end
    FlyTargetStarted = true

    CurrentStep = "to_target"

    local TargetEgg = nil

    if Container then
        TargetEgg = Container:FindFirstChild(TARGET_UID)
    end

    if not TargetEgg then
        TargetEgg = workspace:FindFirstChild(TARGET_UID)
    end

    if not TargetEgg then
        AutoStop()
        return
    end

    local TargetPos = GetPosition(TargetEgg)
    if not TargetPos then
        AutoStop()
        return
    end

    FlyTP(TargetPos, FLY_SPEED, true, false, function()
        CurrentStep = "collect_target"
    end)
end

--==================================================
-- FLY TO SAFE
--==================================================

local function FlyToSafeZone()
    CurrentStep = "to_safe"

    FlyTP(SAFE_ZONE, RETURN_SPEED, false, true, function()
        AutoStop()
    end)
end

--==================================================
-- HEARTBEAT
--==================================================

function StartActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end

    ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not Running then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        if CurrentStep == "collect_first" and not CollectDone then
            if IsFirstEggInWorkspace() then
                CollectDone = true
                task.spawn(function() FlyToGuard() end)
                return
            end

            if tick() - CollectTime > COLLECT_INTERVAL then
                CollectTime = tick()

                if IsFirstEggInContainer() then
                    RemoteCollectFirst()
                    CollectAttempts = CollectAttempts + 1
                else
                    if IsFirstEggInWorkspace() then
                        CollectDone = true
                        task.spawn(function() FlyToGuard() end)
                    end
                end
            end
        end

        if CurrentStep == "wait_guard" and GuardReached and not FlyTargetStarted then
            if IsFirstEggInContainer() then
                task.spawn(function() StartFlyToTarget() end)
            end
        end

        if CurrentStep == "collect_target" and not TargetCollected then
            if IsTargetEggInWorkspace() then
                TargetCollected = true
                task.spawn(function() FlyToSafeZone() end)
                return
            end

            if tick() - CollectTime > COLLECT_INTERVAL then
                CollectTime = tick()

                if IsTargetEggInContainer() then
                    RemoteCollectTarget()
                    CollectAttempts = CollectAttempts + 1
                else
                    if IsTargetEggInWorkspace() then
                        TargetCollected = true
                        task.spawn(function() FlyToSafeZone() end)
                    end
                end
            end
        end
    end)
end

function StopActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end
end

--==================================================
-- MAIN PROCESS
--==================================================

local function StartProcess()
    Running = true
    CurrentStep = "search"

    CollectAttempts = 0
    CollectTime = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    GuardReached = false

    SaveStats()

    SearchFirstEggs()

    if #FirstEggList == 0 then
        AutoStop()
        return
    end

    local Closest = FindClosestEgg()

    if not Closest then
        AutoStop()
        return
    end

    local EggPos = GetPosition(Closest.Slot)
    if not EggPos then
        AutoStop()
        return
    end

    CurrentStep = "fly_first"

    StartActiveHeartbeat()

    FlyTP(EggPos, FLY_SPEED, true, false, function()
        CurrentStep = "collect_first"
    end)
end

--==================================================
-- FULL RESET
--==================================================

local function FullReset()
    Running = false
    CurrentStep = "idle"

    FirstEggList = {}
    FirstEggUid = nil
    FirstEggSlotKey = nil
    CollectAttempts = 0
    CollectTime = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    GuardReached = false

    CleanupMovers()
    StopActiveHeartbeat()
    RestoreStats()

    print("[YOKUDO] Full Reset")
end

--==================================================
-- ENABLE / DISABLE
--==================================================

local function Enable()
    if Running then return end
    if not CollectEvent then warn("[YOKUDO] CollectEvent not found") return end
    if not TARGET_UID then warn("[YOKUDO] No Target ID") return end

    FullReset()
    StartProcess()

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

--==================================================
-- EXPORT
--==================================================

_G.YOKUDO_TeleportSystem = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    IsEnabled = function() return Running end,
    GetTargetId = function() return TARGET_UID end
}

print("✅ TeleportSystem Feature Loaded (RETURN_SPEED = 1000)")
