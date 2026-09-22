-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone
-- គ្រប់គ្រង Event → ហៅ Attack ឬ AFK
-- ✅ ប្រើ ExperimentTimer + NightTimer
-- ✅ ពេល Event ចេញ → Jump → Safe → Wait 10s → Attack
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local EVENT_CHECK_INTERVAL = 1
local EVENT_SKIP_THRESHOLD = 4
local NIGHT_ZONE_THRESHOLD = 10
local AFK_JUMP_WAIT = 0.5
local SAFE_WAIT_BEFORE_ATTACK = 10   -- ✅ រង់ចាំ 10s នៅ Safe Zone មុន Attack

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local LastExpSec = 0
local LastNightSec = 0
local LastExpText = ""
local LastNightText = ""
local ManagerThread = nil

-- ==================================================
-- GET TIMER INFO
-- ==================================================
local function GetTimerInfo(TimerName)
    local Success, Value = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui
            .HUD.GameHUD.BottomRight[TimerName].Value.Text
    end)
    if not Success or not Value then
        return 0, "", false
    end

    local Text = tostring(Value)
    local HasEventEnds = string.find(Text, "Event ends") ~= nil
    local M = tonumber(string.match(Text, "(%d+)m")) or 0
    local S = tonumber(string.match(Text, "(%d+)s")) or 0
    local TotalSec = M * 60 + S

    return TotalSec, Text, HasEventEnds
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
        -- ✅ អានទាំង 2 Timers
        local ExpSec, ExpText, ExpActive = GetTimerInfo("ExperimentTimer")
        local NightSec, NightText = GetTimerInfo("NightTimer")

        -- ✅ Logic:
        -- ExpActive = true → Event កំពុងដំណើរការ
        -- ExpSec > 4 → Event នៅសល់ច្រើន
        -- ExpSec <= 4 → Event ជិតចប់
        -- NightSec <= 10 → Server Zone ជិតបិទ

        local ServerZoneClosed = NightSec <= NIGHT_ZONE_THRESHOLD
        local EventNotActive = not ExpActive
        local EventEndingSoon = ExpActive and ExpSec > 0 and ExpSec <= EVENT_SKIP_THRESHOLD
        local EventActive = ExpActive and ExpSec > EVENT_SKIP_THRESHOLD

        print("[ManagerDrone] ExpSec:", ExpSec, "| NightSec:", NightSec, "| ExpActive:", ExpActive, "| ServerZoneClosed:", ServerZoneClosed, "| EventActive:", EventActive)

        -- ==================================================
        -- Event មិនទាន់ចេញ (ExpActive = false) → AFK System
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
        -- Event ជិតចប់ (ExpSec <= 4) ឬ Server Zone ជិតបិទ (NightSec <= 10)
        -- → Stop Attack → AFK
        -- ==================================================
        elseif EventEndingSoon or ServerZoneClosed then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Ending or Zone Closed → Stop Attack → AFK System")
                _G.YOKUDO_AttackDrone.Stop()
            end

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event កំពុងដំណើរការ (ExpSec > 4) និង Server Zone បើក
        -- → Jump → Safe → Wait 10s → Attack
        -- ==================================================
        elseif EventActive then
            -- បើ AFK System កំពុងដំណើរការ → Jump ចេញ → Safe → Wait 10s → Attack
            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Active → Jump Out → Safe → Wait 10s → Attack")

                local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
                _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
                    task.wait(AFK_JUMP_WAIT)
                    _G.YOKUDO_AFKSystem.Disable()

                    -- ✅ Fly ទៅ Safe Zone មុន
                    _G.YOKUDO_AFKSystem.FlyTP(Vector3.new(533, 70, -366), function()
                        print("[ManagerDrone] Safe Zone Reached → Wait 10s...")
                        task.wait(SAFE_WAIT_BEFORE_ATTACK)  -- ✅ រង់ចាំ 10s
                        print("[ManagerDrone] Wait Done → Start Attack Drone")

                        if _G.YOKUDO_AttackDrone then
                            _G.YOKUDO_AttackDrone.Start()
                        end
                    end)
                end)
            -- បើ AFK System មិន Enabled → Attack ភ្លាម
            elseif _G.YOKUDO_AttackDrone and not _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Active → Attack Drone")
                _G.YOKUDO_AttackDrone.Start()
            end
        end

        LastExpSec = ExpSec
        LastNightSec = NightSec
        LastExpText = ExpText
        LastNightText = NightText
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
    GetTimerInfo = GetTimerInfo,
    ForceStopAll = ForceStopAll,
}

print("✅ ManagerDrone Feature Loaded (Jump → Safe → Wait 10s → Attack)")
