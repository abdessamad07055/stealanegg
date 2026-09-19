-- ==================================================
-- YOKUDO HUB | TAB | Farming
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager

local FarmingTab, FarmingPage = TabsManager:RegisterTab("Farming", 2, "FARMING")

-- ==================================================
-- FARMING CONTENT
-- ==================================================
CreateSectionTitle(FarmingPage, "Farming", 1)

local FarmingLabel = Instance.new("TextLabel")
FarmingLabel.Size = UDim2.new(1, 0, 0, 30)
FarmingLabel.BackgroundTransparency = 1
FarmingLabel.Text = "Coming Soon..."
FarmingLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
FarmingLabel.TextSize = 12
FarmingLabel.TextXAlignment = Enum.TextXAlignment.Left
FarmingLabel.Font = Enum.Font.GothamMedium
FarmingLabel.LayoutOrder = 2
FarmingLabel.Parent = FarmingPage

print("✅ Farming Tab Loaded")
