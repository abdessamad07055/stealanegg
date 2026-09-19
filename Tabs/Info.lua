-- ==================================================
-- YOKUDO HUB | TAB | Info
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager

local InfoTab, InfoPage = TabsManager:RegisterTab("Info", 1, "INFO")

-- ==================================================
-- INFO CONTENT
-- ==================================================
CreateSectionTitle(InfoPage, "YOKUDO HUB | Steal An Egg", 1)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 30)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Telegram : @maibigber"
InfoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
InfoLabel.TextSize = 14
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Font = Enum.Font.GothamMedium
InfoLabel.LayoutOrder = 2
InfoLabel.Parent = InfoPage

local InfoLabel2 = Instance.new("TextLabel")
InfoLabel2.Size = UDim2.new(1, 0, 0, 30)
InfoLabel2.BackgroundTransparency = 1
InfoLabel2.Text = "Version : 1.0"
InfoLabel2.TextColor3 = Color3.fromRGB(150, 150, 170)
InfoLabel2.TextSize = 12
InfoLabel2.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel2.Font = Enum.Font.GothamMedium
InfoLabel2.LayoutOrder = 3
InfoLabel2.Parent = InfoPage

print("✅ Info Tab Loaded")
