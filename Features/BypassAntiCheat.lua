-- ==================================================
-- YOKUDO HUB | FEATURE | Bypass Anti Cheat & Anti-Hit
-- File: BypassAntiCheat.lua
-- ==================================================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local function RunBypassAntiCheat()
    local Character = Player.Character
    if not Character then return end

    local OldHumanoid = Character:FindFirstChildOfClass("Humanoid")
    if not OldHumanoid then return end

    -- Save Jump & State Machine Properties
    local SavedJumpProperties = {
        JumpPower = pcall(function() return OldHumanoid.JumpPower end) and OldHumanoid.JumpPower or 50,
        JumpHeight = pcall(function() return OldHumanoid.JumpHeight end) and OldHumanoid.JumpHeight or 7.2,
        UseJumpPower = OldHumanoid.UseJumpPower
    }

    local SavedEvaluateStateMachine
    pcall(function() SavedEvaluateStateMachine = OldHumanoid.EvaluateStateMachine end)

    -- Clone Humanoid
    local NewHumanoid = OldHumanoid:Clone()
    if not NewHumanoid then return end
    NewHumanoid.Name = OldHumanoid.Name

    -- Transfer Children
    for _, Child in ipairs(OldHumanoid:GetChildren()) do
        local Existing = NewHumanoid:FindFirstChild(Child.Name)
        if Existing then pcall(function() Existing:Destroy() end) end
        pcall(function() Child.Parent = NewHumanoid end)
    end

    -- Replace Humanoid
    OldHumanoid:Destroy()
    task.wait()
    NewHumanoid.Parent = Character
    task.wait()

    -- Restore Properties
    pcall(function() NewHumanoid.UseJumpPower = SavedJumpProperties.UseJumpPower end)
    pcall(function() NewHumanoid.JumpPower = SavedJumpProperties.JumpPower end)
    pcall(function() NewHumanoid.JumpHeight = SavedJumpProperties.JumpHeight end)
    pcall(function()
        if SavedEvaluateStateMachine ~= nil then
            NewHumanoid.EvaluateStateMachine = SavedEvaluateStateMachine
        end
    end)

    -- Lock Health & Anti-Death
    local function ApplyGodMode()
        if NewHumanoid and NewHumanoid.Parent then
            pcall(function()
                NewHumanoid.MaxHealth = math.huge
                NewHumanoid.Health = math.huge
                NewHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                NewHumanoid.BreakJointsOnDeath = false
                NewHumanoid.RequiresNeck = false
            end)
        end
    end

    ApplyGodMode()

    NewHumanoid.HealthChanged:Connect(function(Health)
        if Health < NewHumanoid.MaxHealth then
            pcall(function() NewHumanoid.Health = NewHumanoid.MaxHealth end)
        end
    end)

    NewHumanoid.Died:Connect(function()
        pcall(function() NewHumanoid.Health = NewHumanoid.MaxHealth end)
    end)

    task.spawn(function()
        while task.wait(0.1) do
            ApplyGodMode()
        end
    end)

    -- Refresh Controls & Camera
    local function RefreshControls()
        local PlayerScripts = Player:FindFirstChild("PlayerScripts")
        if not PlayerScripts then return end
        local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
        if not PlayerModule then return end
        local Success, Module = pcall(function() return require(PlayerModule) end)
        if Success and Module then
            local Controls = Module:GetControls()
            if Controls then
                pcall(function() Controls:OnCharacterAdded(Character) end)
                pcall(function() Controls:UpdateActiveControlModuleEnabled() end)
            end
        end
    end

    RefreshControls()

    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then Camera.CameraSubject = NewHumanoid end
    end)

    print("✅ [YOKUDO] Bypass Anti Cheat & Anti-Hit Active")
end

Player.CharacterAdded:Connect(function()
    task.wait(1)
    RunBypassAntiCheat()
end)

task.spawn(function()
    task.wait(1)
    RunBypassAntiCheat()
end)
