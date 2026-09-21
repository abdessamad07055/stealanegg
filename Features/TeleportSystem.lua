--==================================================
-- YOKUDO HUB - TELEPORT SYSTEM (MODE 2 FIXED)
-- Mode 1: Target in Container (spawn) -> Collect
-- Mode 2: Target in Workspace (Y change) -> Collect
-- First Egg: FlyTP (Normal)
-- Target Egg: Instant FlyTP + Collect (Check Y)
-- Safe Zone: FlyTP (Normal)
-- Ragdoll Bypass ON
-- No Fly to Guard
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

--==================================================
-- REMOTES
--==================================================

local CollectEvent = nil
local ForestStrike = nil

pcall(function()
    CollectEvent = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

pcall(function()
    ForestStrike = ReplicatedStorage.Packages.Networking["RE/GuardPatrol/ForestStrike"]
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
local RETURN_SPEED = 1000

local FLY_OFFSET = 3
local LOCK_ABOVE = 2
local ARRIVE_DISTANCE = 2
local SAFE_LOCK_DISTANCE = 3

local COLLECT_INTERVAL = 0.2
local SEARCH_PREFIX = "FirstAreaEgg"
local Y_CHANGE_THRESHOLD = 1  -- ✅ Y ផ្លាស់ទី > 1 គិតថា collect រួច

--==================================================
-- RAGDOLL BYPASS STATE
--==================================================

local RagdollEnabled = false
local RagdollConnection = nil
local ForceUpConnection = nil

--==================================================
-- STATE
--==================================================

local Running = false
local CurrentStep = "idle"
local CurrentMode = "none"

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local ActiveHeartbeat = nil
local LockConnection = nil
local TargetCollectConnection = nil

local FirstEggList = {}
local FirstEggUid = nil
local FirstEggSlotKey = nil

local CollectAttempts = 0
local CollectTime = 0
local TargetCollectAttempts = 0

local FlyTargetStarted = false
local CollectDone = false
local TargetCollected = false
local RemotesFired = false

local SavedTargetPosition = nil
local SavedTargetY = nil  -- ✅ Save Y position
local TargetLockedCFrame = nil

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
-- RAGDOLL BYPASS
--==================================================

local function ForceUp()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end

    pcall(function()
        if Hum:GetState() == Enum.HumanoidStateType.Physics then
            Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

        Hum.PlatformStand = false
        Hum.Sit = false

        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero

        Root.CanCollide = true

        Hum.BreakJointsOnDeath = false
        Hum.RequiresNeck = false
    end)
end

local function CleanupRagdollConstraints()
    local Char = Player.Character
    if not Char then return end

    pcall(function()
        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant.Name:find("RagdollConstraint") then
                descendant:Destroy()
            end
            if descendant.Name:find("RagdollAttachment") then
                descendant:Destroy()
            end
        end

        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                descendant.Enabled = true
            end
        end
    end)
end

local function EnableRagdollBypass()
    if RagdollEnabled then return end
    RagdollEnabled = true

    RagdollConnection = RunService.Heartbeat:Connect(function()
        if not RagdollEnabled then return end
        ForceUp()
    end)

    ForceUpConnection = task.spawn(function()
        while RagdollEnabled do
            task.wait(0.1)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[YOKUDO] Ragdoll Bypass: ON")
end

local function DisableRagdollBypass()
    if not RagdollEnabled then return end
    RagdollEnabled = false

    if RagdollConnection then
        RagdollConnection:Disconnect()
        RagdollConnection = nil
    end

    print("[YOKUDO] Ragdoll Bypass: OFF")
end

--==================================================
-- SAVE / RESTORE STATS
--==================================================

local function SaveStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if SavedWalkSpeed == nil then SavedWalkSpeed = Hum.WalkSpeed end
    if SavedJumpPower == nil then SavedJumpPower = Hum.JumpPower end
    if SavedJumpHeight == nil then SavedJumpHeight = Hum.JumpHeight end
    if SavedUseJumpPower == nil then SavedUseJumpPower = Hum.UseJumpPower end
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

local function StopTargetCollect()
    if TargetCollectConnection then
        TargetCollectConnection:Disconnect()
        TargetCollectConnection = nil
    end
end

local function CleanupMovers()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    if LockConnection then
        LockConnection:Disconnect()
        LockConnection = nil
    end

    StopTargetCollect()

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
-- LOCK AT TARGET (Y+2)
--==================================================

local function StartLock(TargetPosition)
    TargetLockedCFrame = CFrame.new(TargetPosition + Vector3.new(0, LOCK_ABOVE, 0))

    if LockConnection then
        LockConnection:Disconnect()
    end

    LockConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end

        local Hum, Root = GetHumanoid()
        if not Root then return end

        Root.CFrame = TargetLockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
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
-- FLY TP (NORMAL - FOR FIRST EGG AND SAFE ZONE)
--==================================================

local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, LOCK_ABOVE, 0))

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
            StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= 30 then
            ShotDone = true
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination)
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
-- INSTANT FLY TP (ONLY FOR TARGET EGG)
--==================================================

local function InstantFlyToTarget()
    local TargetEgg = nil
    if Container then
        TargetEgg = Container:FindFirstChild(TARGET_UID)
    end
    if not TargetEgg then
        TargetEgg = workspace:FindFirstChild(TARGET_UID)
    end
    if not TargetEgg then
        print("[YOKUDO] Target Egg not found")
        return false
    end

    local TargetPos = GetPosition(TargetEgg)
    if not TargetPos then
        print("[YOKUDO] Target Position not found")
        return false
    end

    -- ✅ Save Target Position + Y
    if CurrentMode == "workspace" then
        SavedTargetPosition = TargetPos
        SavedTargetY = TargetPos.Y  -- ✅ Save Y
        print("[YOKUDO] Saved Target Y: " .. tostring(SavedTargetY))
    end

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return false end

    CleanupMovers()

    Root.CFrame = CFrame.new(TargetPos + Vector3.new(0, FLY_OFFSET, 0))
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero

    StartLock(TargetPos)

    print("[YOKUDO] Instant Fly to Target: " .. tostring(TargetPos))
    return true
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
-- FIRE FOREST STRIKE (INSTEAD OF GUARD)
--==================================================

local function FireForestStrike()
    if RemotesFired then return end
    RemotesFired = true

    EnableRagdollBypass()

    pcall(function()
        ForestStrike:FireServer({
            EggUid = FirstEggUid,
            GuardCFrame = CFrame.new(
                607.6259155273438, 70.57420349121094, -326.8830261230469
            )
        })
    end)

    task.spawn(function()
        for i = 1, 10 do
            task.wait(0.05)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[YOKUDO] ForestStrike Fired")
end

--==================================================
-- CHECK EGG
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

local function IsTargetInContainer()
    if not TARGET_UID or not Container then return false end
    return Container:FindFirstChild(TARGET_UID) ~= nil
end

local function IsTargetInWorkspace()
    if not TARGET_UID then return false end
    return workspace:FindFirstChild(TARGET_UID) ~= nil
end

--==================================================
-- CHECK TARGET MODE
--==================================================

local function CheckTargetMode()
    -- ✅ Step 1: ពិនិត្យថា Target Egg នៅក្នុង Container (path spawn) ឬអត់
    if IsTargetInContainer() then
        CurrentMode = "spawn"
        print("[YOKUDO] Mode 1: Target in Container (spawn)")
        return "spawn"
    end

    -- ✅ Step 2: ពិនិត្យថា Target Egg នៅក្នុង Workspace ឬអត់
    if IsTargetInWorkspace() then
        local WSEgg = workspace:FindFirstChild(TARGET_UID)
        if WSEgg then
            local CurrentPos = GetPosition(WSEgg)
            if CurrentPos then
                local Hum, Root = GetHumanoid()
                if Root then
                    local Dist = (CurrentPos - Root.Position).Magnitude
                    if Dist >= 4 then
                        CurrentMode = "workspace"
                        SavedTargetPosition = CurrentPos
                        SavedTargetY = CurrentPos.Y
                        print("[YOKUDO] Mode 2: Target in Workspace (distance: " .. tostring(Dist) .. ")")
                        return "workspace"
                    else
                        print("[YOKUDO] Target in Workspace but distance < 4 (" .. tostring(Dist) .. ")")
                        return "wait"
                    end
                end
            end
        end
    end

    return "wait"
end

--==================================================
-- AUTO STOP
--==================================================

local function AutoStop()
    Running = false
    CurrentStep = "done"

    CleanupMovers()
    StopTargetCollect()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()

    print("[YOKUDO] Auto Stop")
end

--==================================================
-- FLY TO SAFE (NORMAL FLYTP - NOT INSTANT)
--==================================================

local function FlyToSafeZone()
    CurrentStep = "to_safe"
    print("[YOKUDO] Flying to Safe Zone (Normal)")

    CleanupMovers()
    task.wait(0.05)

    FlyTP(SAFE_ZONE, RETURN_SPEED, false, true, function()
        print("[YOKUDO] At Safe Zone")
        task.wait(0.5)
        AutoStop()
    end)
end

--==================================================
-- TARGET COLLECT (SEPARATE HEARTBEAT)
--==================================================

local function StartTargetCollect()
    StopTargetCollect()

    print("[YOKUDO] Target Collect: STARTED - Mode: " .. CurrentMode)

    TargetCollectConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            StopTargetCollect()
            return
        end
        if CurrentStep ~= "collect_target" or TargetCollected then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        -- ✅ Mode 1 (spawn): ពិនិត្យ Workspace ធម្មតា
        if CurrentMode == "spawn" then
            if IsTargetInWorkspace() then
                TargetCollected = true
                StopTargetCollect()
                CleanupMovers()
                task.wait(0.05)
                FlyToSafeZone()
                return
            end

            RemoteCollectTarget()
            TargetCollectAttempts = TargetCollectAttempts + 1
            return
        end

        -- ✅ Mode 2 (workspace): ពិនិត្យ Y Position
        if CurrentMode == "workspace" then
            if IsTargetInWorkspace() then
                local WSEgg = workspace:FindFirstChild(TARGET_UID)
                if WSEgg and SavedTargetY then
                    local CurrentPos = GetPosition(WSEgg)
                    if CurrentPos then
                        local CurrentY = CurrentPos.Y
                        local DeltaY = math.abs(CurrentY - SavedTargetY)
                        
                        print("[YOKUDO] Mode 2 - Current Y: " .. tostring(CurrentY) .. " | Saved Y: " .. tostring(SavedTargetY) .. " | Delta: " .. tostring(DeltaY))
                        
                        -- ✅ បើ Y ផ្លាស់ទី > 1 → collect រួច
                        if DeltaY >= Y_CHANGE_THRESHOLD then
                            TargetCollected = true
                            StopTargetCollect()
                            CleanupMovers()
                            task.wait(0.05)
                            FlyToSafeZone()
                            return
                        end
                    end
                end
            end

            -- ✅ ហៅ Remote CollectTarget រហូត
            RemoteCollectTarget()
            TargetCollectAttempts = TargetCollectAttempts + 1
            return
        end
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

        -- STEP 1: Collect First
        if CurrentStep == "collect_first" and not CollectDone then
            if IsFirstEggInWorkspace() then
                CollectDone = true
                FireForestStrike()
                CurrentStep = "wait_spawn_back"
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
                        FireForestStrike()
                        CurrentStep = "wait_spawn_back"
                    end
                end
            end
        end

        -- STEP 2: Wait Egg Back -> Instant Fly Target
        if CurrentStep == "wait_spawn_back" then
            if IsFirstEggInContainer() then
                print("[YOKUDO] Egg Back - Instant Fly Target")

                local Success = InstantFlyToTarget()
                if Success then
                    CurrentStep = "collect_target"
                    StartTargetCollect()
                else
                    AutoStop()
                end
                return
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
    TargetCollectAttempts = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    RemotesFired = false
    SavedTargetPosition = nil
    SavedTargetY = nil
    TargetLockedCFrame = nil

    SaveStats()
    EnableRagdollBypass()

    -- ✅ Check Target Mode (OLD LOGIC)
    local Mode = CheckTargetMode()

    if Mode == "wait" then
        local WaitTime = 0
        while Running and CheckTargetMode() == "wait" do
            task.wait(0.5)
            WaitTime = WaitTime + 0.5
            if WaitTime > 60 then
                AutoStop()
                return
            end
        end
        Mode = CheckTargetMode()
    end

    if Mode == "wait" then
        AutoStop()
        return
    end

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

    -- ✅ Fly to First Egg (NORMAL FlyTP)
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
    CurrentMode = "none"

    FirstEggList = {}
    FirstEggUid = nil
    FirstEggSlotKey = nil
    CollectAttempts = 0
    CollectTime = 0
    TargetCollectAttempts = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    RemotesFired = false
    SavedTargetPosition = nil
    SavedTargetY = nil
    TargetLockedCFrame = nil

    CleanupMovers()
    StopTargetCollect()
    DisableRagdollBypass()
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

print("✅ TeleportSystem Feature Loaded (Mode 2 Fixed - Y Change)")
