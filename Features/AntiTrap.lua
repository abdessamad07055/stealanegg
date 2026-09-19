-- ==================================================
-- YOKUDO HUB | FEATURE | Anti Trap
-- Auto Remove Children in workspace.__DEBRIS
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

-- ==================================================
-- VARIABLES
-- ==================================================
local AntiTrapEnabled = false
local Connection = nil
local DebrisFolder = nil

-- ==================================================
-- GET DEBRIS FOLDER
-- ==================================================
local function GetDebrisFolder()
    if DebrisFolder and DebrisFolder.Parent then
        return DebrisFolder
    end
    DebrisFolder = workspace:FindFirstChild("__DEBRIS")
    return DebrisFolder
end

-- ==================================================
-- REMOVE CHILDREN
-- ==================================================
local function RemoveDebrisChildren()
    local Folder = GetDebrisFolder()
    if not Folder then return end
    
    for _, child in ipairs(Folder:GetChildren()) do
        pcall(function()
            child:Destroy()
        end)
    end
end

-- ==================================================
-- ANTI TRAP FUNCTION
-- ==================================================
local function EnableAntiTrap()
    AntiTrapEnabled = true
    
    -- លុបភ្លាមម្តង
    RemoveDebrisChildren()
    
    -- លុបរាល់ 1 វិនាទី
    if Connection then
        Connection:Disconnect()
    end
    
    Connection = task.spawn(function()
        while AntiTrapEnabled do
            task.wait(1)
            if AntiTrapEnabled then
                RemoveDebrisChildren()
            end
        end
    end)
    
    print("[YOKUDO] Anti Trap: ON")
end

local function DisableAntiTrap()
    AntiTrapEnabled = false
    
    if Connection then
        Connection:Disconnect()
        Connection = nil
    end
    
    print("[YOKUDO] Anti Trap: OFF")
end

-- ==================================================
-- TOGGLE FUNCTION
-- ==================================================
local function ToggleAntiTrap()
    if AntiTrapEnabled then
        DisableAntiTrap()
    else
        EnableAntiTrap()
    end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AntiTrap = {
    Toggle = ToggleAntiTrap,
    Enable = EnableAntiTrap,
    Disable = DisableAntiTrap,
    IsEnabled = function() return AntiTrapEnabled end
}

print("✅ AntiTrap Feature Loaded")
