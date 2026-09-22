--==================================================
-- YOKUDO HUB | FEATURE | Anti AFK
-- Prevent AFK Kick/Hop using Mouse Move
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

--==================================================
-- STATE
--==================================================

local AntiAFKEnabled = false
local AntiAFKConnection = nil

--==================================================
-- ENABLE / DISABLE
--==================================================

local function EnableAntiAFK()
    if AntiAFKEnabled then return end
    AntiAFKEnabled = true

    AntiAFKConnection = task.spawn(function()
        while AntiAFKEnabled do
            task.wait(math.random(30, 90))

            if not AntiAFKEnabled then break end

            -- ✅ Mouse Move Method
            local Mouse = Player:GetMouse()
            if Mouse then
                pcall(function()
                    mousemoverel(math.random(-10, 10), math.random(-10, 10))
                end)
            end
        end
    end)

    print("[YOKUDO] Anti AFK: ON")
end

local function DisableAntiAFK()
    if not AntiAFKEnabled then return end
    AntiAFKEnabled = false

    print("[YOKUDO] Anti AFK: OFF")
end

local function ToggleAntiAFK()
    if AntiAFKEnabled then
        DisableAntiAFK()
    else
        EnableAntiAFK()
    end
end

--==================================================
-- EXPORT
--==================================================

_G.YOKUDO_AntiAFK = {
    Enable = EnableAntiAFK,
    Disable = DisableAntiAFK,
    Toggle = ToggleAntiAFK,
    IsEnabled = function() return AntiAFKEnabled end
}

print("✅ AntiAFK Feature Loaded (Mouse Move)")
