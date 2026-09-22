-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone
-- គ្រប់គ្រង Event → ហៅ Attack ឬ AFK
-- ✅ Check Text: "in Xm Ys" → AFK, "Event ends in" → Attack
-- ✅ Stop ពេល Disable
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local EVENT_CHECK_INTERVAL = 1
local EVENT_SKIP_THRESHOLD = 4
local AFK_JUMP_WAIT = 1  -- ✅ រង់ចាំ Jump ចេញពី AFK

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local LastEventSec = 0
local LastEventText = ""
local ManagerThread = nil

-- ==================================================
-- GET EVENT INFO
-- ✅ ប្រើ ExperimentTimer.Value.Text
-- ✅ ពិនិត្យ "Event ends" vs "in"
-- ==================================================
local function GetEventInfo()
    local Success, Value = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui
            .HUD.GameHUD.BottomRight.ExperimentTimer.Value.Text
    end)
    if not Success or not Value then
        return 0, "", false
    end

    local Text = tostring(Value)  -- "Event ends in 9m 50s" ឬ "in 9m 50s"

    -- ✅ ពិនិត្យថាតើ Text មាន "Event ends"
    local HasEventEnds = string.find(Text, "Event ends") ~= nil
    local IsEventActive = HasEventEnds

    -- ញែក M និង S
    local M = tonumber(string.match(Text, "(%d+)m")) or 0
    local S = tonumber(string.match(Text, "(%d+)s")) or 0
    local TotalSec = M * 60 + S

    return TotalSec, Text, IsEventActive
end

-- ==================================================
-- FORCE STOP ALL FEATURES
-- ==================================================
local function ForceStopAll()
    print("[ManagerDrone] Force Stop All Features")

    if _G.YOKUDO_AttackDrone then
        pcall(function() _G.YOKUDO_AttackDrone.Stop() end)
    end
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    while ManagerEnabled do
        local EventSec, EventText, IsEventActive = GetEventInfo()

        local EventNotActive = not IsEventActive
        local EventEndingSoon = IsEventActive and EventSec > 0 and EventSec <= EVENT_SKIP_THRESHOLD
        local EventActive = IsEventActive and EventSec > EVENT_SKIP_THRESHOLD

        print("[ManagerDrone] Text:", EventText, "| Sec:", EventSec, "| IsActive:", IsEventActive, "| NotActive:", EventNotActive, "| EndingSoon:", EventEndingSoon, "| Active:", EventActive)

        -- ==================================================
        -- Event មិនទាន់ចេញ (Text = "in Xm Ys") → AFK System
        -- ==================================================
        if EventNotActive then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Not Active → Stop Attack")
                _G.YOKUDO_AttackDrone.Stop()
            end

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Not Active → AFK System")
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event ជិតចប់ (Event ends in Xm Ys + Sec <= 4) → Stop Attack → AFK
        -- ==================================================
        elseif EventEndingSoon then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Ending Soon (<= 4s) → Stop Attack → AFK System")
                _G.YOKUDO_AttackDrone.Stop()
            end

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event កំពុងដំណើរការ (Event ends in Xm Ys + Sec > 4) → Attack
        -- ==================================================
        elseif EventActive then
            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Active → Jump Out AFK → Attack Drone")

                -- ✅ Jump ចេញពី AFK មុន
                local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
                _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
                    task.wait(AFK_JUMP_WAIT)
                    _G.YOKUDO_AFKSystem.Disable()
                    task.wait(0.5)
                    if _G.YOKUDO_AttackDrone then
                        _G.YOKUDO_AttackDrone.Start()
                    end
                end)
            elseif _G.YOKUDO_AttackDrone and not _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Active → Attack Drone")
                _G.YOKUDO_AttackDrone.Start()
            end
        end

        LastEventSec = EventSec
        LastEventText = EventText
        task.wait(EVENT_CHECK_INTERVAL)
    end

    ForceStopAll()
    print("[ManagerDrone] MainLoop Stopped")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableManager()
    if ManagerEnabled then return end
    ManagerEnabled = true

    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    ManagerThread = task.spawn(function() MainLoop() end)

    print("[ManagerDrone] Manager Drone: ON")
end

local function DisableManager()
    if not ManagerEnabled then return end
    ManagerEnabled = false

    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    ForceStopAll()

    print("[ManagerDrone] Manager Drone: OFF")
end

local function ToggleManager()
    if ManagerEnabled then
        DisableManager()
    else
        EnableManager()
    end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ManagerDrone = {
    Enable = EnableManager,
    Disable = DisableManager,
    Toggle = ToggleManager,
    IsEnabled = function() return ManagerEnabled end,
    GetEventInfo = GetEventInfo,
    ForceStopAll = ForceStopAll,
}

print("✅ ManagerDrone Feature Loaded (Check Text: in vs Event ends)")
