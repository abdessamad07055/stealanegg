-- ==================================================
-- YOKUDO HUB | FEATURE | Anti AFK
-- Bypass Game Anti-AFK ដោយប្រើ VirtualInputManager
-- បញ្ជូន Input រាល់ 10 នាទី (600 វិនាទី)
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local INPUT_INTERVAL = 600         -- ✅ រាល់ 10 នាទី (600 វិនាទី)
local INPUT_VARIATION = 60         -- Random បន្ថែម 0-60s
local USE_MOUSE_MOVE = true
local USE_MOUSE_CLICK = true
local USE_KEYBOARD = true

-- ==================================================
-- STATE
-- ==================================================
local AntiAFKEnabled = true
local InputThread = nil
local LastInputTime = tick()

-- ==================================================
-- SEND MOUSE MOVE
-- ==================================================
local function SendMouseMove()
    pcall(function()
        local ViewportSize = workspace.CurrentCamera.ViewportSize
        local RandomX = math.random(1, math.floor(ViewportSize.X))
        local RandomY = math.random(1, math.floor(ViewportSize.Y))

        VirtualInputManager:SendMouseMoveEvent(RandomX, RandomY, game)
    end)
end

-- ==================================================
-- SEND MOUSE CLICK
-- ==================================================
local function SendMouseClick()
    pcall(function()
        local ViewportSize = workspace.CurrentCamera.ViewportSize
        local RandomX = math.random(1, math.floor(ViewportSize.X))
        local RandomY = math.random(1, math.floor(ViewportSize.Y))

        VirtualInputManager:SendMouseButtonEvent(RandomX, RandomY, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(RandomX, RandomY, 0, false, game, 1)
    end)
end

-- ==================================================
-- SEND KEYBOARD PRESS
-- ==================================================
local function SendKeyboardPress()
    pcall(function()
        local KeyCode = Enum.KeyCode.Space
        VirtualInputManager:SendKeyEvent(true, KeyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, KeyCode, false, game)
    end)
end

-- ==================================================
-- MAIN INPUT LOOP
-- ==================================================
local function StartInputLoop()
    if InputThread then
        pcall(function() task.cancel(InputThread) end)
        InputThread = nil
    end

    InputThread = task.spawn(function()
        while AntiAFKEnabled do
            local WaitTime = INPUT_INTERVAL + math.random(0, INPUT_VARIATION)
            print("[AntiAFK] Next Input in", WaitTime, "seconds")
            task.wait(WaitTime)

            if not AntiAFKEnabled then break end

            print("[AntiAFK] Sending Real Input...")

            if USE_MOUSE_MOVE then
                SendMouseMove()
                task.wait(0.1)
            end

            if USE_MOUSE_CLICK then
                SendMouseClick()
                task.wait(0.1)
            end

            if USE_KEYBOARD then
                SendKeyboardPress()
            end

            LastInputTime = tick()
        end
    end)
end

-- ==================================================
-- PLAYER IDLED EVENT (Backup)
-- ==================================================
local IdleConnection = Player.Idled:Connect(function()
    if not AntiAFKEnabled then return end

    print("[AntiAFK] Player Idled! Sending Input...")

    SendMouseMove()
    task.wait(0.1)
    SendMouseClick()
    task.wait(0.1)
    SendKeyboardPress()

    LastInputTime = tick()
end)

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableAntiAFK()
    AntiAFKEnabled = true
    StartInputLoop()
    print("[AntiAFK] Anti AFK: ON (Every 10 minutes)")
end

local function DisableAntiAFK()
    AntiAFKEnabled = false

    if InputThread then
        pcall(function() task.cancel(InputThread) end)
        InputThread = nil
    end

    print("[AntiAFK] Anti AFK: OFF")
end

-- ==================================================
-- AUTO-START ON LOAD
-- ==================================================
EnableAntiAFK()

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AntiAFK = {
    Enable = EnableAntiAFK,
    Disable = DisableAntiAFK,
    IsEnabled = function() return AntiAFKEnabled end,
    GetLastInputTime = function() return LastInputTime end,
    SendMouseMove = SendMouseMove,
    SendMouseClick = SendMouseClick,
    SendKeyboardPress = SendKeyboardPress,
}

print("✅ AntiAFK Feature Loaded (Every 10 minutes)")
