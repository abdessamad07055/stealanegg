-- ==================================================
-- YOKUDO HUB | FEATURE | Auto Hit Egg Thief
-- File: AutoHitThief.lua
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Backpack = Player:WaitForChild("Backpack")

local ATTACK_RANGE = 25
local FIRE_INTERVAL = 0.01

local LastFire = 0
local TraceSequence = 0

local function GetBatSwingRemote()
    local Success, Remote = pcall(function()
        return ReplicatedStorage.Packages.Networking["RE/BatSwing/Trigger"]
    end)
    return Success and Remote or nil
end

local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
end

local function FindBatTool()
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Bat" or tool.Name:find("Bat")) then
            return tool
        end
    end
    local Char = Player.Character
    if Char then
        for _, tool in ipairs(Char:GetChildren()) do
            if tool:IsA("Tool") and (tool.ToolTip == "Bat" or tool.Name:find("Bat")) then
                return tool
            end
        end
    end
    return nil
end

local function EquipBat()
    local Bat = FindBatTool()
    if not Bat then return false end
    if Bat.Parent == Backpack then
        local Hum = GetHumanoid()
        if Hum then
            Hum:EquipTool(Bat)
            return true
        end
    end
    return true
end

local function FindClosestPlayer()
    local _, Root = GetHumanoid()
    if not Root then return nil end
    
    local Closest = nil
    local ClosestDist = ATTACK_RANGE
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= Player and otherPlayer.Character then
            local otherHum = otherPlayer.Character:FindFirstChildOfClass("Humanoid")
            local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if otherHum and otherRoot and otherHum.Health > 0 then
                local Dist = (otherRoot.Position - Root.Position).Magnitude
                if Dist < ClosestDist then
                    ClosestDist = Dist
                    Closest = otherPlayer
                end
            end
        end
    end
    return Closest
end

RunService.Heartbeat:Connect(function()
    EquipBat()
    
    local now = tick()
    if now - LastFire < FIRE_INTERVAL then return end
    
    local Target = FindClosestPlayer()
    local Remote = GetBatSwingRemote()
    
    if Target and Remote then
        LastFire = now
        TraceSequence = TraceSequence + 1
        local TraceId = tostring(Player.UserId) .. ":" .. tostring(TraceSequence) .. ":" .. tostring(math.floor(workspace:GetServerTimeNow() * 1000))
        
        pcall(function()
            Remote:FireServer(Target, TraceId)
        end)
    end
end)

print("✅ [YOKUDO] Auto Hit Egg Thief Script Loaded")
