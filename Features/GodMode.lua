--==================================================
-- YOKUDO HUB | FEATURE | God Mode
-- Humanoid Replace + Anti Death
-- FIXED: Handle PlayerModule error
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

--==================================================
-- VARIABLES
--==================================================
local GodModeEnabled = false
local GodModeConnection = nil
local GodMode = true

--==================================================
-- RUN HUMANOID REPLACE + ANTI DEATH
--==================================================
local function RunGodMode()
    local Character = Player.Character
    if not Character then return end

    local OldHumanoid = Character:FindFirstChildOfClass("Humanoid")
    if not OldHumanoid then
        warn("[YOKUDO] Humanoid not found")
        return
    end

    print("========================================")
    print("[YOKUDO] START HUMANOID REPLACE")
    print("========================================")

    -- Save jump properties
    local SavedJumpProperties = {}

    local function SaveJumpProperty(Property)
        local Success, Value = pcall(function()
            return OldHumanoid[Property]
        end)
        if Success then
            SavedJumpProperties[Property] = Value
        end
    end

    SaveJumpProperty("JumpPower")
    SaveJumpProperty("JumpHeight")
    SaveJumpProperty("UseJumpPower")

    -- Save state machine
    local SavedEvaluateStateMachine
    pcall(function()
        SavedEvaluateStateMachine = OldHumanoid.EvaluateStateMachine
    end)

    -- Save all humanoid state settings
    local SavedStates = {}
    local States = {
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Running,
        Enum.HumanoidStateType.RunningNoPhysics,
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.StrafingNoPhysics,
        Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.GettingUp,
        Enum.HumanoidStateType.Jumping,
        Enum.HumanoidStateType.Landed,
        Enum.HumanoidStateType.Flying,
        Enum.HumanoidStateType.Freefall,
        Enum.HumanoidStateType.Seated,
        Enum.HumanoidStateType.PlatformStanding,
        Enum.HumanoidStateType.Dead,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.Physics,
    }

    for _, State in ipairs(States) do
        local Success, Enabled = pcall(function()
            return OldHumanoid:GetStateEnabled(State)
        end)
        if Success then
            SavedStates[State] = Enabled
        end
    end

    -- Clone humanoid
    local NewHumanoid = OldHumanoid:Clone()
    if not NewHumanoid then
        warn("[YOKUDO] Failed to clone Humanoid")
        return
    end
    NewHumanoid.Name = OldHumanoid.Name

    -- Move children
    for _, Child in ipairs(OldHumanoid:GetChildren()) do
        local ExistingCloneChild = NewHumanoid:FindFirstChild(Child.Name)
        if ExistingCloneChild then
            pcall(function()
                ExistingCloneChild:Destroy()
            end)
        end
        pcall(function()
            Child.Parent = NewHumanoid
        end)
    end

    -- Replace
    OldHumanoid:Destroy()
    task.wait()
    NewHumanoid.Parent = Character
    task.wait()

    if not NewHumanoid.Parent then
        warn("[YOKUDO] New Humanoid was removed")
        return
    end

    print("[YOKUDO] New Humanoid:", NewHumanoid)

    -- Restore jump properties
    pcall(function()
        NewHumanoid.UseJumpPower = SavedJumpProperties.UseJumpPower
    end)
    pcall(function()
        NewHumanoid.JumpPower = SavedJumpProperties.JumpPower
    end)
    pcall(function()
        NewHumanoid.JumpHeight = SavedJumpProperties.JumpHeight
    end)

    -- Restore state machine
    pcall(function()
        if SavedEvaluateStateMachine ~= nil then
            NewHumanoid.EvaluateStateMachine = SavedEvaluateStateMachine
        end
    end)

    -- Restore states
    for State, Enabled in pairs(SavedStates) do
        pcall(function()
            NewHumanoid:SetStateEnabled(State, Enabled)
        end)
    end

    -- Ensure animator
    local Animator = NewHumanoid:FindFirstChildOfClass("Animator")
    if not Animator then
        Animator = Instance.new("Animator")
        Animator.Parent = NewHumanoid
    end
    print("[YOKUDO] Animator:", Animator)

    -- Restart animate
    local Animate = Character:FindFirstChild("Animate")
    if Animate then
        print("[YOKUDO] Restarting Animate...")
        pcall(function()
            Animate.Disabled = true
        end)
        task.wait()
        pcall(function()
            Animate.Disabled = false
        end)
        print("[YOKUDO] Animate restarted")
    end

    task.wait(0.15)

    -- Anti-death
    local function LockHealth()
        if GodMode and NewHumanoid and NewHumanoid.Parent then
            pcall(function()
                NewHumanoid.MaxHealth = math.huge
                NewHumanoid.Health = math.huge
            end)
        end
    end

    local function BlockDeathState()
        if not NewHumanoid or not NewHumanoid.Parent then return end
        pcall(function()
            NewHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end)
        pcall(function()
            NewHumanoid.BreakJointsOnDeath = false
        end)
        pcall(function()
            NewHumanoid.RequiresNeck = false
        end)
    end

    local function BindAntiDeath(Humanoid)
        if not Humanoid then return end
        Humanoid.HealthChanged:Connect(function(Health)
            if GodMode and Humanoid and Humanoid.Parent then
                if Health < Humanoid.MaxHealth then
                    pcall(function()
                        Humanoid.Health = Humanoid.MaxHealth
                    end)
                end
            end
        end)
        Humanoid.Died:Connect(function()
            if GodMode and Humanoid and Humanoid.Parent then
                pcall(function()
                    Humanoid.Health = Humanoid.MaxHealth
                end)
            end
        end)
    end

    LockHealth()
    BlockDeathState()
    BindAntiDeath(NewHumanoid)

    --==================================================
    -- CONTROL MODULE (FIXED)
    --==================================================
    local function RefreshControls()
        local PlayerScripts = Player:FindFirstChild("PlayerScripts")
        if not PlayerScripts then return end
        local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
        if not PlayerModule then return end

        -- ✅ Use pcall to catch errors
        local Success, Module = pcall(function()
            return require(PlayerModule)
        end)

        if not Success then
            warn("[YOKUDO] Failed to require PlayerModule: " .. tostring(Module))
            return
        end

        if not Module then return end

        -- ✅ Use pcall for GetControls
        local ControlsSuccess, Controls = pcall(function()
            return Module:GetControls()
        end)

        if not ControlsSuccess or not Controls then return end

        -- ✅ Use pcall for OnCharacterAdded
        pcall(function()
            Controls:OnCharacterAdded(Character)
        end)

        task.wait()

        -- ✅ Use pcall for UpdateActiveControlModuleEnabled
        pcall(function()
            Controls:UpdateActiveControlModuleEnabled()
        end)
    end

    RefreshControls()

    -- Camera
    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then
            Camera.CameraSubject = NewHumanoid
        end
    end)

    task.wait(0.25)

    if not Character.Parent then return end

    local CurrentHumanoid = Character:FindFirstChildOfClass("Humanoid")
    if CurrentHumanoid ~= NewHumanoid then return end

    -- Final restore
    pcall(function()
        NewHumanoid.UseJumpPower = SavedJumpProperties.UseJumpPower
    end)
    pcall(function()
        NewHumanoid.JumpPower = SavedJumpProperties.JumpPower
    end)
    pcall(function()
        NewHumanoid.JumpHeight = SavedJumpProperties.JumpHeight
    end)
    pcall(function()
        if SavedEvaluateStateMachine ~= nil then
            NewHumanoid.EvaluateStateMachine = SavedEvaluateStateMachine
        end
    end)

    for State, Enabled in pairs(SavedStates) do
        pcall(function()
            NewHumanoid:SetStateEnabled(State, Enabled)
        end)
    end

    LockHealth()
    BlockDeathState()
    RefreshControls()

    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then
            Camera.CameraSubject = NewHumanoid
        end
    end)

    -- Final animate restart
    local CurrentAnimate = Character:FindFirstChild("Animate")
    if CurrentAnimate then
        pcall(function()
            CurrentAnimate.Disabled = true
        end)
        task.wait()
        pcall(function()
            CurrentAnimate.Disabled = false
        end)
    end

    -- Start God Mode Loop
    if GodModeConnection then
        GodModeConnection:Disconnect()
        GodModeConnection = nil
    end

    GodModeConnection = RunService.Heartbeat:Connect(function()
        if not GodModeEnabled then return end

        local Char = Player.Character
        if not Char then return end

        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Hum then return end

        pcall(function()
            if Hum.Health < Hum.MaxHealth then
                Hum.Health = Hum.MaxHealth
            end
            Hum.MaxHealth = math.huge
            Hum.Health = math.huge
            Hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            Hum.BreakJointsOnDeath = false
            Hum.RequiresNeck = false
        end)
    end)

    print("========================================")
    print("[YOKUDO] HUMANOID REPLACE + ANTI DEATH COMPLETE")
    print("========================================")
end

--==================================================
-- ENABLE / DISABLE / TOGGLE
--==================================================
local function EnableGodMode()
    GodModeEnabled = true
    task.spawn(RunGodMode)
    print("[YOKUDO] God Mode: ON")
end

local function DisableGodMode()
    GodModeEnabled = false
    if GodModeConnection then
        GodModeConnection:Disconnect()
        GodModeConnection = nil
    end
    print("[YOKUDO] God Mode: OFF")
end

local function ToggleGodMode()
    if GodModeEnabled then
        DisableGodMode()
    else
        EnableGodMode()
    end
end

--==================================================
-- EXPORT
--==================================================
_G.YOKUDO_GodMode = {
    Toggle = ToggleGodMode,
    Enable = EnableGodMode,
    Disable = DisableGodMode,
    IsEnabled = function() return GodModeEnabled end
}

print("✅ GodMode Feature Loaded")
