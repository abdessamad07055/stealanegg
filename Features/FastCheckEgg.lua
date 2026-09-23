-- ==================================================
-- YOKUDO HUB | FEATURE | Fast Check & Rarest Auto Select
-- File: FastCheckEgg.lua
-- ==================================================

local workspace = game:GetService("Workspace")
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- تصفية الندرة المطلوب تحديدها تلقائياً
local TargetRarities = {
    ["secret"] = true,
    ["eternal"] = true,
    ["divine"] = true
}

local function FastCheckAndSelect()
    if not _G.YOKUDO_AutoFarm then 
        return 
    end

    -- فحص سريع وقوائم البيض
    local EggList = _G.YOKUDO_AutoFarm.ScanEggs()
    local BestEgg = nil

    for _, eggData in ipairs(EggList) do
        local rarity = string.lower(eggData.Rarity or "secret")
        
        -- التصفية واختيار الأعلى دخلاً وضمن الندرات المحددة
        if TargetRarities[rarity] or rarity == "secret" then
            if not BestEgg or eggData.EarningRate > BestEgg.EarningRate then
                BestEgg = eggData
            end
        end
    end

    -- الاختيار التلقائي لأفضل بيضة
    if BestEgg then
        local currentSelected = _G.YOKUDO_AutoFarm.GetSelectedEgg()
        if not currentSelected or currentSelected.Id ~= BestEgg.Id then
            _G.YOKUDO_AutoFarm.SelectEgg(BestEgg)
            print("✨ [YOKUDO] Auto Selected Rarest Egg: " .. BestEgg.DisplayName .. " ($" .. _G.YOKUDO_AutoFarm.FormatMoney(BestEgg.EarningRate) .. "/s)")
        end
    end
end

-- فحص سريع دوري كل 0.15 ثانية
task.spawn(function()
    while task.wait(0.15) do
        pcall(FastCheckAndSelect)
    end
end)

-- الاستجابة الفورية عند إضافة أو إزالة أي بيضة
Container.ChildAdded:Connect(function()
    task.wait(0.02)
    pcall(FastCheckAndSelect)
end)

Container.ChildRemoved:Connect(function()
    task.wait(0.02)
    pcall(FastCheckAndSelect)
end)

print("✅ [YOKUDO] Fast Check & Auto Select Rarest Egg Active")
