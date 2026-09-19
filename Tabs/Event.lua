-- ==================================================
-- YOKUDO HUB | TAB | Event
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager

local EventTab, EventPage = TabsManager:RegisterTab("Event", 5, "EVENT")

-- ==================================================
-- EVENT CONTENT
-- ==================================================
CreateSectionTitle(EventPage, "Event", 1)

local EventLabel = Instance.new("TextLabel")
EventLabel.Size = UDim2.new(1, 0, 0, 30)
EventLabel.BackgroundTransparency = 1
EventLabel.Text = "Coming Soon..."
EventLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
EventLabel.TextSize = 12
EventLabel.TextXAlignment = Enum.TextXAlignment.Left
EventLabel.Font = Enum.Font.GothamMedium
EventLabel.LayoutOrder = 2
EventLabel.Parent = EventPage

print("✅ Event Tab Loaded")
