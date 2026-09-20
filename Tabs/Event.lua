-- ==================================================
-- YOKUDO HUB | TAB | Event
-- Feature: Attack Drone (Checkbox)
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local EventTab, EventPage = TabsManager:RegisterTab("Event", 5, "EVENT")

-- ==================================================
-- EVENT CONTENT
-- ==================================================
CreateSectionTitle(EventPage, "Event", 1)

-- ==================================================
-- FEATURE: ATTACK DRONE (Checkbox)
-- ==================================================
local AttackDroneHolder = Instance.new("Frame")
AttackDroneHolder.Size = UDim2.new(1, 0, 0, 52)
AttackDroneHolder.BackgroundTransparency = 1
AttackDroneHolder.LayoutOrder = 2
AttackDroneHolder.Parent = EventPage

local AttackDroneLabel = Instance.new("TextLabel")
AttackDroneLabel.Size = UDim2.new(1, -50, 0, 20)
AttackDroneLabel.Position = UDim2.new(0, 0, 0, 2)
AttackDroneLabel.BackgroundTransparency = 1
AttackDroneLabel.Text = "Attack Drone"
AttackDroneLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
AttackDroneLabel.TextSize = 13
AttackDroneLabel.TextXAlignment = Enum.TextXAlignment.Left
AttackDroneLabel.TextYAlignment = Enum.TextYAlignment.Center
AttackDroneLabel.Font = Enum.Font.GothamBold
AttackDroneLabel.Parent = AttackDroneHolder

local AttackDroneSub = Instance.new("TextLabel")
AttackDroneSub.Size = UDim2.new(1, -50, 0, 18)
AttackDroneSub.Position = UDim2.new(0, 0, 0, 24)
AttackDroneSub.BackgroundTransparency = 1
AttackDroneSub.Text = "click-when-mob-spawn"
AttackDroneSub.TextColor3 = Color3.fromRGB(150, 150, 170)
AttackDroneSub.TextSize = 10
AttackDroneSub.TextXAlignment = Enum.TextXAlignment.Left
AttackDroneSub.Font = Enum.Font.Gotham
AttackDroneSub.Parent = AttackDroneHolder

local AttackDroneCheckButton = Instance.new("TextButton")
AttackDroneCheckButton.Size = UDim2.new(0, 26, 0, 26)
AttackDroneCheckButton.Position = UDim2.new(1, -26, 0.5, -13)
AttackDroneCheckButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
AttackDroneCheckButton.BorderSizePixel = 0
AttackDroneCheckButton.Text = ""
AttackDroneCheckButton.AutoButtonColor = false
AttackDroneCheckButton.Parent = AttackDroneHolder

local AttackDroneCorner = Instance.new("UICorner")
AttackDroneCorner.CornerRadius = UDim.new(0, 6)
AttackDroneCorner.Parent = AttackDroneCheckButton

local AttackDroneStroke = Instance.new("UIStroke")
AttackDroneStroke.Color = Color3.fromRGB(200, 200, 220)
AttackDroneStroke.Thickness = 1.5
AttackDroneStroke.Parent = AttackDroneCheckButton

local AttackDroneCheck = Instance.new("TextLabel")
AttackDroneCheck.Size = UDim2.new(1, 0, 1, 0)
AttackDroneCheck.BackgroundTransparency = 1
AttackDroneCheck.Text = "✓"
AttackDroneCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
AttackDroneCheck.TextSize = 18
AttackDroneCheck.Font = Enum.Font.GothamBold
AttackDroneCheck.Visible = false
AttackDroneCheck.Parent = AttackDroneCheckButton

-- ==================================================
-- TOGGLE LOGIC
-- ==================================================
local function UpdateAttackDroneUI(state)
    AttackDroneCheck.Visible = state
    if state then
        AttackDroneCheckButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        AttackDroneStroke.Color = Color3.fromRGB(135, 120, 225)
    else
        AttackDroneCheckButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        AttackDroneStroke.Color = Color3.fromRGB(200, 200, 220)
    end
end

AttackDroneCheckButton.MouseButton1Click:Connect(function()
    local newState = not (_G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled())
    UpdateAttackDroneUI(newState)

    if _G.YOKUDO_AttackDrone then
        if newState then
            _G.YOKUDO_AttackDrone.Enable()
        else
            _G.YOKUDO_AttackDrone.Disable()
        end
    else
        warn("[YOKUDO] AttackDrone feature not loaded")
    end
end)

-- ==================================================
-- SYNC STATE ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(0.5)
    if _G.YOKUDO_AttackDrone then
        UpdateAttackDroneUI(_G.YOKUDO_AttackDrone.IsEnabled())
    end
end)

print("✅ Event Tab Loaded")
