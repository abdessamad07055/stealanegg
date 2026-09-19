-- ==================================================
-- YOKUDO HUB | TAB | Hop Server
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager

local HopServerTab, HopServerPage = TabsManager:RegisterTab("Hop Server", 6, "HOP_SERVER")

-- ==================================================
-- HOP SERVER CONTENT
-- ==================================================
CreateSectionTitle(HopServerPage, "Hop Server", 1)

local HopServerLabel = Instance.new("TextLabel")
HopServerLabel.Size = UDim2.new(1, 0, 0, 30)
HopServerLabel.BackgroundTransparency = 1
HopServerLabel.Text = "Coming Soon..."
HopServerLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
HopServerLabel.TextSize = 12
HopServerLabel.TextXAlignment = Enum.TextXAlignment.Left
HopServerLabel.Font = Enum.Font.GothamMedium
HopServerLabel.LayoutOrder = 2
HopServerLabel.Parent = HopServerPage

print("✅ Hop Server Tab Loaded")
