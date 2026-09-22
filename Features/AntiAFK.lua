-- ==================================================
-- YOKUDO HUB | FEATURE | Anti AFK
-- ការពារ Roblox ពីការ Kick ពេល AFK (20 នាទី)
-- ដំណើរការភ្លាមពេល Load
-- ==================================================

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- STATE
-- ==================================================
local AntiAFKEnabled = true
local IdleConnection = nil
local HeartbeatConnection = nil
local LastActivity = tick()

-- ==================================================
-- ANTI AFK METHODS
-- ==================================================

-- Method 1: Player.Idled Event (Main)
local function SetupIdledConnection()
    if IdleConnection then
        IdleConnection:Disconnect()
        IdleConnection = nil
    end

    IdleConnection = Player.Idled:Connect(function()
        if not AntiAFKEnabled then return end

        print("[AntiAFK] Idle detected! Sending VirtualUser input...")

        -- ប្រើ VirtualUser ដើម្បី "ចុច" ជំនួស Player
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)

        LastActivity = tick()
    end)
end

-- Method 2: Heartbeat Auto Click (Backup)
local function SetupHeartbeatLoop()
    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end

    local Counter = 0
    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AntiAFKEnabled then return end

        Counter = Counter + 1
        if Counter >= 300 then -- រាល់ ~5s
            Counter = 0

            -- ប្រើ VirtualUser ដើម្បីរក្សា Activity
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)

            LastActivity = tick()
        end
    end)
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableAntiAFK()
    AntiAFKEnabled = true
    SetupIdledConnection()
    SetupHeartbeatLoop()
    print("[AntiAFK] Anti AFK: ON")
end

local function DisableAntiAFK()
    AntiAFKEnabled = false

    if IdleConnection then
        IdleConnection:Disconnect()
        IdleConnection = nil
    end
    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end

    print("[AntiAFK] Anti AFK: OFF")
end

-- ==================================================
-- AUTO-START ON LOAD (✅ ដំណើរការភ្លាម)
-- ==================================================
EnableAntiAFK()

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AntiAFK = {
    Enable = EnableAntiAFK,
    Disable = DisableAntiAFK,
    IsEnabled = function() return AntiAFKEnabled end,
    GetLastActivity = function() return LastActivity end,
}

print("✅ AntiAFK Feature Loaded (Auto-Start)")
