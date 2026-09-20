-- ==================================================
-- YOKUDO HUB | FEATURE | Manual Fast Click
-- Enable Click Egg Fast by hand
-- Button "Click" → Start (No Loop)
-- ==================================================

local ProximityPromptService = game:GetService("ProximityPromptService")

-- ==================================================
-- STATE
-- ==================================================
local PromptConnection = nil
local IsRunning = false

-- ==================================================
-- SET HOLD DURATION = 0
-- ==================================================
local function ApplyHoldDuration(prompt)
    if not prompt then return end
    pcall(function()
        prompt.HoldDuration = 0
    end)
end

-- ==================================================
-- SCAN ALL EXISTING PROMPTS (ម្តងពេល Start)
-- ==================================================
local function ScanAllPrompts()
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            ApplyHoldDuration(descendant)
        end
    end

    local Player = game.Players.LocalPlayer
    if Player then
        local PlayerGui = Player:FindFirstChild("PlayerGui")
        if PlayerGui then
            for _, descendant in ipairs(PlayerGui:GetDescendants()) do
                if descendant:IsA("ProximityPrompt") then
                    ApplyHoldDuration(descendant)
                end
            end
        end
    end
end

-- ==================================================
-- START (ចុច Click ម្តង → Start ម្តង)
-- ==================================================
local function StartManualFastClick()
    IsRunning = true

    -- 1. Apply ភ្លាមទៅ prompt ដែលមានស្រាប់
    ScanAllPrompts()

    -- 2. ចាប់ព្រឹត្តិការណ៍ PromptShown សម្រាប់ prompt ថ្មី
    if PromptConnection then
        PromptConnection:Disconnect()
        PromptConnection = nil
    end
    PromptConnection = ProximityPromptService.PromptShown:Connect(function(prompt)
        ApplyHoldDuration(prompt)
    end)

    print("[YOKUDO] Manual Fast Click: START")
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ManualFastClick = {
    Start = StartManualFastClick,
    IsRunning = function() return IsRunning end,
    ScanAllPrompts = ScanAllPrompts,
    ApplyHoldDuration = ApplyHoldDuration
}

print("✅ ManualFastClick Feature Loaded")
