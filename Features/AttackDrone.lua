-- ==================================================
-- YOKUDO HUB | FEATURE | Attack Drone
-- Check Player Position → Fly to Safe Zone or Mob Spawn → Attack
-- Farthest Mob from Spawn (Higher Price)
-- Save/Restore WalkSpeed & Jump (Live)
-- Compatible with Humanoid Replace
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local ATTACK_RANGE = 16
local ATTACK_INTERVAL = 0.02
local FOLLOW_SPEED = 300
local FOLLOW_BEHIND_DISTANCE = 3
local SHORT_TP_DISTANCE = 20
local SPAWN_POSITION = Vector3.new(2255, 75, -370)
local SAFE_ZONE = Vector3.new(533, 70, -366)
local DISTANCE_THRESHOLD = 100
local SAFE_WAIT_TIME = 1
local CONTAINER_NAME = "ScrambleLocalVisuals"
local SEARCH_PREFIXES = { "DroneVisual_", "PersonalDrone_" }

-- ==================================================
-- STATE
-- ==================================================
local AttackDroneEnabled = false
local AttackConnection = nil
local FollowConnection = nil
local LockConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local CurrentTarget = nil
local LastFire = 0
local TraceSequence = 0
local IsLocked = false
local LockCFrame = nil
local Phase = "idle"

-- Live Saved Stats
local SavedStats = {
    WalkSpeed = nil,
    JumpPower = nil,
    JumpHeight = nil,
    UseJumpPower = nil,
    Humanoid = nil,
}

-- ==================================================
-- FORWARD DECLARATIONS
-- ==================================================
local StartFollow
local FlyTPToPosition
local StartAttackLoop

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
-- GET BAT SWING REMOTE
-- ==================================================
local function GetBatSwingRemote()
    local Success, Remote = pcall(function()
        return ReplicatedStorage.Packages.Networking["RE/BatSwing/Trigger"]
    end)
    if Success and Remote then
        return Remote
    end
    return nil
end

-- ==================================================
-- SAVE LIVE STATS
-- ==================================================
local function SaveLiveStats()
    local Hum = GetHumanoid()
    if not Hum then return end

    SavedStats.Humanoid = Hum
    SavedStats.WalkSpeed = Hum.WalkSpeed
    SavedStats.JumpPower = Hum.JumpPower
    SavedStats.JumpHeight = Hum.JumpHeight
    SavedStats.UseJumpPower = Hum.UseJumpPower
end

-- ==================================================
-- RESTORE LIVE STATS
-- ==================================================
local function RestoreLiveStats()
    local Hum = GetHumanoid()
    if not Hum then return end

    if SavedStats.WalkSpeed ~= nil then
        pcall(function() Hum.WalkSpeed = SavedStats.WalkSpeed end)
    end
    if SavedStats.JumpPower ~= nil then
        pcall(function() Hum.JumpPower = SavedStats.JumpPower end)
    end
    if SavedStats.JumpHeight ~= nil then
        pcall(function() Hum.JumpHeight = SavedStats.JumpHeight end)
    end
    if SavedStats.UseJumpPower ~= nil then
        pcall(function() Hum.UseJumpPower = SavedStats.UseJumpPower end)
    end
end

-- ==================================================
-- RE-SAVE STATS IF HUMANOID REPLACED
-- ==================================================
local function EnsureStatsAlive()
    local Hum = GetHumanoid()
    if not Hum then return end

    if SavedStats.Humanoid ~= Hum then
        SavedStats.Humanoid = Hum
        SavedStats.WalkSpeed = Hum.WalkSpeed
        SavedStats.JumpPower = Hum.JumpPower
        SavedStats.JumpHeight = Hum.JumpHeight
        SavedStats.UseJumpPower = Hum.UseJumpPower
    end
end

-- ==================================================
-- CLEANUP MOVERS
-- ==================================================
local function CleanupMovers()
    if FollowConnection then
        FollowConnection:Disconnect()
        FollowConnection = nil
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

    IsLocked = false
    LockCFrame = nil
end

-- ==================================================
-- GET POSITION
-- ==================================================
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

-- ==================================================
-- GET LOOK VECTOR
-- ==================================================
local function GetLookVector(Object)
    if not Object then return Vector3.new(0, 0, -1) end
    local Part = nil
    if Object:IsA("Model") then
        Part = Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart")
        if not Part then
            for _, Desc in ipairs(Object:GetDescendants()) do
                if Desc:IsA("BasePart") then
                    Part = Desc
                    break
                end
            end
        end
    elseif Object:IsA("BasePart") then
        Part = Object
    end
    if Part then
        return Part.CFrame.LookVector
    end
    return Vector3.new(0, 0, -1)
end

-- ==================================================
-- FIND ALL DRONES (តាម prefix)
-- ==================================================
local function FindAllDrones()
    local Container = workspace:FindFirstChild(CONTAINER_NAME)
    if not Container then return {} end

    local Drones = {}
    for _, obj in ipairs(Container:GetChildren()) do
        for _, prefix in ipairs(SEARCH_PREFIXES) do
            if string.sub(obj.Name, 1, #prefix) == prefix then
                table.insert(Drones, obj)
                break
            end
        end
    end
    return Drones
end

-- ==================================================
-- FIND FARTHEST DRONE FROM SPAWN POSITION
-- ==================================================
local function FindFarthestDroneFromSpawn()
    local Drones = FindAllDrones()
    if #Drones == 0 then return nil end

    local Farthest = nil
    local FarthestDist = -1

    for _, Drone in ipairs(Drones) do
        local Pos = GetPosition(Drone)
        if Pos then
            local Dist = (Pos - SPAWN_POSITION).Magnitude
            if Dist > FarthestDist then
                FarthestDist = Dist
                Farthest = Drone
            end
        end
    end

    return Farthest, FarthestDist
end

-- ==================================================
-- GET BEHIND POSITION (3 studs ពីក្រោយ)
-- ==================================================
local function GetBehindPosition(Target)
    local TargetPos = GetPosition(Target)
    if not TargetPos then return nil end

    local LookVector = GetLookVector(Target)
    local BehindPos = TargetPos - (LookVector * FOLLOW_BEHIND_DISTANCE)
    BehindPos = Vector3.new(BehindPos.X, TargetPos.Y + 1, BehindPos.Z)
    return BehindPos
end

-- ==================================================
-- START LOCK
-- ==================================================
local function StartLock(Position, LookAt)
    LockCFrame = CFrame.new(Position, LookAt or (Position + Vector3.new(0, 0, -1)))

    if LockConnection then
        LockConnection:Disconnect()
    end

    IsLocked = true

    LockConnection = RunService.Heartbeat:Connect(function()
        if not AttackDroneEnabled then
            if LockConnection then
                LockConnection:Disconnect()
                LockConnection = nil
            end
            IsLocked = false
            return
        end

        local Hum, Root = GetHumanoid()
        if not Root then return end

        if CurrentTarget and CurrentTarget.Parent then
            local NewBehind = GetBehindPosition(CurrentTarget)
            local NewTargetPos = GetPosition(CurrentTarget)
            if NewBehind and NewTargetPos then
                LockCFrame = CFrame.new(NewBehind, NewTargetPos)
            end
        end

        Root.CFrame = LockCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==================================================
-- FOLLOW BEHIND (Distance-based + Short TP 20)
-- ==================================================
function StartFollow()
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

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

    FollowConnection = RunService.Heartbeat:Connect(function()
        if not AttackDroneEnabled then
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

        if not CurrentTarget or not CurrentTarget.Parent then
            CleanupMovers()
            return
        end

        local TargetPos = GetPosition(CurrentTarget)
        if not TargetPos then
            CleanupMovers()
            return
        end

        local BehindPos = GetBehindPosition(CurrentTarget)
        if not BehindPos then
            CleanupMovers()
            return
        end

        local CurrentPos = Root2.Position
        local Direction = BehindPos - CurrentPos
        local TotalDist = Direction.Magnitude

        if TotalDist <= SHORT_TP_DISTANCE then
            CleanupMovers()

            Root2.CFrame = CFrame.new(BehindPos, TargetPos)
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            StartLock(BehindPos, TargetPos)
            return
        end

        BodyVelocity.Velocity = Direction.Unit * FOLLOW_SPEED
        BodyGyro.CFrame = CFrame.new(CurrentPos, TargetPos)
    end)
end

-- ==================================================
-- FLY TP TO POSITION
-- ==================================================
function FlyTPToPosition(Destination, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

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
    local CheckTimer = 0

    FollowConnection = RunService.Heartbeat:Connect(function()
        if not AttackDroneEnabled then
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

        -- ពេលកំពុង Teleport → Check រក Mob
        CheckTimer = CheckTimer + 1
        if CheckTimer >= 5 then
            CheckTimer = 0
            local FoundDrone = FindFarthestDroneFromSpawn()
            if FoundDrone then
                CleanupMovers()
                CurrentTarget = FoundDrone
                Phase = "following"
                StartFollow()
                return
            end
        end

        local CurrentPos = Root2.Position
        local Direction = Destination - CurrentPos
        local TotalDist = Direction.Magnitude

        if TotalDist <= 2 then
            CleanupMovers()

            Root2.CFrame = CFrame.new(Destination)
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            Phase = "locked_spawn"
            StartLock(Destination)

            if Callback then Callback() end
            return
        end

        if tick() - StartTime > 15 then
            CleanupMovers()
            if Callback then Callback() end
            return
        end

        BodyVelocity.Velocity = Direction.Unit * FOLLOW_SPEED
        BodyGyro.CFrame = CFrame.new(CurrentPos, Destination)
    end)
end

-- ==================================================
-- INITIAL FLY BASED ON PLAYER POSITION
-- ==================================================
local function InitialFly()
    local Hum, Root = GetHumanoid()
    if not Root then return end

    local PlayerPos = Root.Position
    local DistToSafe = (PlayerPos - SAFE_ZONE).Magnitude
    local DistToSpawn = (PlayerPos - SPAWN_POSITION).Magnitude

    print("[YOKUDO] Player Pos:", PlayerPos)
    print("[YOKUDO] Dist to Safe:", DistToSafe)
    print("[YOKUDO] Dist to Spawn:", DistToSpawn)

    if DistToSpawn < DISTANCE_THRESHOLD then
        -- នៅជិត Mob Spawn → Fly TP ទៅ Mob Spawn ភ្លាម
        print("[YOKUDO] Near Spawn → Fly to Spawn")
        Phase = "fly_to_spawn"
        FlyTPToPosition(SPAWN_POSITION, function()
            Phase = "locked_spawn"
        end)
    elseif DistToSafe < DISTANCE_THRESHOLD then
        -- នៅលើ Safe Zone → Fly TP ទៅ Safe Zone មុន
        print("[YOKUDO] Near Safe → Fly to Safe")
        Phase = "fly_to_safe"
        FlyTPToPosition(SAFE_ZONE, function()
            -- ពេលដល់ Safe Zone → រង់ចាំ → Fly ទៅ Spawn
            task.wait(SAFE_WAIT_TIME)
            print("[YOKUDO] Safe Reached → Fly to Spawn")
            Phase = "fly_to_spawn"
            FlyTPToPosition(SPAWN_POSITION, function()
                Phase = "locked_spawn"
            end)
        end)
    else
        -- នៅឆ្ងាយពីទាំងពីរ → Fly TP ទៅ Safe Zone មុន
        print("[YOKUDO] Far from both → Fly to Safe first")
        Phase = "fly_to_safe"
        FlyTPToPosition(SAFE_ZONE, function()
            task.wait(SAFE_WAIT_TIME)
            print("[YOKUDO] Safe Reached → Fly to Spawn")
            Phase = "fly_to_spawn"
            FlyTPToPosition(SPAWN_POSITION, function()
                Phase = "locked_spawn"
            end)
        end)
    end
end

-- ==================================================
-- FIRE REMOTE AT DRONE
-- ==================================================
local function FireAtDrone(Drone)
    if not Drone or not Drone.Parent then return end

    local isDrone = false
    for _, prefix in ipairs(SEARCH_PREFIXES) do
        if string.sub(Drone.Name, 1, #prefix) == prefix then
            isDrone = true
            break
        end
    end
    if not isDrone then return end

    local Remote = GetBatSwingRemote()
    if not Remote then return end

    local Hum, Root = GetHumanoid()
    if not Root then return end

    local DronePos = GetPosition(Drone)
    if not DronePos then return end

    local Dist = (DronePos - Root.Position).Magnitude
    if Dist > ATTACK_RANGE then return end

    TraceSequence = TraceSequence + 1
    local TraceId = tostring(Player.UserId) .. ":" .. tostring(TraceSequence) .. ":" .. tostring(math.floor(workspace:GetServerTimeNow() * 1000))

    pcall(function()
        Remote:FireServer(Drone, TraceId)
    end)
end

-- ==================================================
-- MAIN ATTACK LOOP
-- ==================================================
function StartAttackLoop()
    if AttackConnection then
        AttackConnection:Disconnect()
        AttackConnection = nil
    end

    AttackConnection = RunService.Heartbeat:Connect(function()
        if not AttackDroneEnabled then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        EnsureStatsAlive()

        -- បើគ្មាន Target ឬ Target បាត់ → រកថ្មី
        if not CurrentTarget or not CurrentTarget.Parent then
            local NewTarget = FindFarthestDroneFromSpawn()
            if NewTarget then
                CurrentTarget = NewTarget
                Phase = "following"
                StartFollow()
            else
                -- គ្មាន Mob → Lock នៅ Spawn រង់ចាំ
                if Phase == "locked_spawn" then
                    return
                elseif Phase == "fly_to_safe" or Phase == "fly_to_spawn" then
                    return
                else
                    Phase = "fly_to_spawn"
                    FlyTPToPosition(SPAWN_POSITION, function()
                        Phase = "locked_spawn"
                    end)
                end
            end
            return
        end

        -- មាន Target → Attack
        local now = tick()
        if now - LastFire >= ATTACK_INTERVAL then
            LastFire = now
            FireAtDrone(CurrentTarget)
        end
    end)
end

-- ==================================================
-- ENABLE / DISABLE / TOGGLE
-- ==================================================
local function EnableAttackDrone()
    if AttackDroneEnabled then return end
    AttackDroneEnabled = true

    SaveLiveStats()

    if _G.YOKUDO_AutoAttack then
        _G.YOKUDO_AutoAttack.EnableAutoEquip()
    end

    StartAttackLoop()

    -- Initial Fly based on Player Position
    task.spawn(function()
        InitialFly()
    end)

    print("[YOKUDO] Attack Drone: ON (Smart Position Check)")
end

local function DisableAttackDrone()
    if not AttackDroneEnabled then return end
    AttackDroneEnabled = false

    if AttackConnection then
        AttackConnection:Disconnect()
        AttackConnection = nil
    end

    CleanupMovers()
    CurrentTarget = nil
    Phase = "idle"

    RestoreLiveStats()

    if _G.YOKUDO_AutoAttack then
        _G.YOKUDO_AutoAttack.DisableAutoEquip()
    end

    print("[YOKUDO] Attack Drone: OFF")
end

local function ToggleAttackDrone()
    if AttackDroneEnabled then
        DisableAttackDrone()
    else
        EnableAttackDrone()
    end
end

-- ==================================================
-- AUTO RE-APPLY ON CHARACTER ADDED
-- ==================================================
Player.CharacterAdded:Connect(function()
    if AttackDroneEnabled then
        task.wait(1)
        SaveLiveStats()
        if _G.YOKUDO_AutoAttack then
            _G.YOKUDO_AutoAttack.EnableAutoEquip()
        end
        StartAttackLoop()
        task.spawn(function()
            InitialFly()
        end)
    end
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AttackDrone = {
    Enable = EnableAttackDrone,
    Disable = DisableAttackDrone,
    Toggle = ToggleAttackDrone,
    IsEnabled = function() return AttackDroneEnabled end,
    GetPhase = function() return Phase end,
    FindAllDrones = FindAllDrones,
    FindFarthestDroneFromSpawn = FindFarthestDroneFromSpawn,
    GetBatSwingRemote = GetBatSwingRemote,
    GetSavedStats = function() return SavedStats end,
    SPAWN_POSITION = SPAWN_POSITION,
    SAFE_ZONE = SAFE_ZONE
}

print("✅ AttackDrone Feature Loaded (Smart Position Check + Farthest from Spawn)")
