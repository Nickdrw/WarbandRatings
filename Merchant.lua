local _, ns = ...
ns.Merchant = {}
local Merchant = ns.Merchant
local Database = ns.Database
local DataCollection = ns.DataCollection

local HONOR_CURRENCY_ID = 1792
local CONQUEST_CURRENCY_ID = 1602
local PANEL_WIDTH = 220
local PANEL_HEIGHT = 114
local ICON_SIZE = 28

local CURRENCY_DUMP_ITEMS = {
    {
        itemID = Database.HELIOTROPE_ITEM_ID,
        name = Database.HELIOTROPE_NAME,
        currencyID = HONOR_CURRENCY_ID,
        fallbackCost = Database.HELIOTROPE_FALLBACK_HONOR_COST,
    },
    {
        itemID = Database.GALACTIC_EQUIPMENT_CHEST_ITEM_ID,
        name = Database.GALACTIC_EQUIPMENT_CHEST_NAME,
        currencyID = CONQUEST_CURRENCY_ID,
        fallbackCost = Database.GALACTIC_EQUIPMENT_CHEST_FALLBACK_CONQUEST_COST,
        confirmEachPurchase = true,
    },
}

local fallbackTheme = {
    surface = { 0.055, 0.064, 0.078, 0.96 },
    surfaceRaised = { 0.080, 0.092, 0.110, 0.98 },
    border = { 0.250, 0.285, 0.330, 0.88 },
    text = { 0.900, 0.930, 0.960, 1 },
    title = { 0.970, 0.820, 0.450, 1 },
    muted = { 0.560, 0.600, 0.650, 1 },
    accent = { 0.960, 0.720, 0.320, 1 },
}

local eventFrame
local panel

local function FormatNumber(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    local sign = value < 0 and "-" or ""
    local text = tostring(math.abs(value))
    local left, num, right = text:match("^([^%d]*%d)(%d*)(.-)$")
    if not left then return sign .. text end
    return sign .. left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function GetTheme()
    if ns.UI and ns.UI.GetActiveTheme then
        return ns.UI.GetActiveTheme()
    end
    return fallbackTheme
end

local function SetTextureColor(texture, color, alpha)
    if texture and texture.SetColorTexture and color then
        texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
    end
end

local function SetFontColor(fontString, color, alpha)
    if fontString and fontString.SetTextColor and color then
        fontString:SetTextColor(color[1], color[2], color[3], alpha or color[4] or 1)
    end
end

local function CreateBorder(parent, key, point, relativePoint, x, y, width, height)
    local border = parent[key]
    if not border then
        border = parent:CreateTexture(nil, "BORDER")
        parent[key] = border
    end

    border:ClearAllPoints()
    border:SetPoint(point, parent, relativePoint, x, y)
    border:SetSize(width, height)
    return border
end

local function ApplyPanelTheme()
    if not panel then return end

    local theme = GetTheme()
    SetTextureColor(panel.bg, theme.surface)
    SetTextureColor(panel.headerBg, theme.surfaceRaised)
    SetTextureColor(panel.accentLine, theme.accent, 0.75)
    SetTextureColor(panel.iconBg, theme.surfaceRaised)
    SetTextureColor(panel.iconBorderTop, theme.accent, 0.85)
    SetTextureColor(panel.iconBorderBottom, theme.accent, 0.85)
    SetTextureColor(panel.iconBorderLeft, theme.accent, 0.85)
    SetTextureColor(panel.iconBorderRight, theme.accent, 0.85)
    SetFontColor(panel.title, theme.title)
    SetFontColor(panel.body, theme.text)
    SetFontColor(panel.detail, theme.muted)

    SetTextureColor(CreateBorder(panel, "borderTop", "TOPLEFT", "TOPLEFT", 0, 0, PANEL_WIDTH, 1), theme.border)
    SetTextureColor(CreateBorder(panel, "borderBottom", "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, PANEL_WIDTH, 1), theme.border)
    SetTextureColor(CreateBorder(panel, "borderLeft", "TOPLEFT", "TOPLEFT", 0, 0, 1, PANEL_HEIGHT), theme.border)
    SetTextureColor(CreateBorder(panel, "borderRight", "TOPRIGHT", "TOPRIGHT", 0, 0, 1, PANEL_HEIGHT), theme.border)
end

Merchant.ApplyTheme = ApplyPanelTheme

local function GetCurrencyInfo(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        return C_CurrencyInfo.GetCurrencyInfo(currencyID)
    end
end

local function GetCurrencyQuantity(currencyID)
    local info = GetCurrencyInfo(currencyID)
    return tonumber(info and info.quantity) or 0
end

local function GetCurrencyName(currencyID)
    local info = GetCurrencyInfo(currencyID)
    return info and info.name or "Currency"
end

local function GetItemInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(index)
        if info then return info end
    end
    if not GetMerchantItemInfo then return nil end

    local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost, currencyID, spellID = GetMerchantItemInfo(index)
    if not name then return nil end

    return {
        name = name,
        texture = texture,
        price = price,
        stackCount = stackCount,
        numAvailable = numAvailable,
        isPurchasable = isPurchasable,
        isUsable = isUsable,
        hasExtendedCost = hasExtendedCost,
        currencyID = currencyID,
        spellID = spellID,
    }
end

local function GetItemID(index)
    if GetMerchantItemID then
        local itemID = GetMerchantItemID(index)
        if itemID then return itemID end
    end

    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    return link and tonumber(link:match("item:(%d+)"))
end

local function GetCurrencyCost(index, itemInfo, currencyID)
    if itemInfo and tonumber(itemInfo.currencyID) == currencyID then
        return tonumber(itemInfo.price) or 0
    end

    local currencyName = GetCurrencyName(currencyID)
    local costCount = GetMerchantItemCostInfo and GetMerchantItemCostItem and GetMerchantItemCostInfo(index) or 0
    for costIndex = 1, costCount do
        local _, amount, itemLink, costCurrencyName = GetMerchantItemCostItem(index, costIndex)
        if not itemLink and costCurrencyName == currencyName then
            return tonumber(amount) or 0
        end
    end

    return 0
end

local function FindCurrencyDumpItem()
    local numItems = GetMerchantNumItems and GetMerchantNumItems() or 0
    for index = 1, numItems do
        local itemInfo = GetItemInfo(index)
        local itemID = itemInfo and GetItemID(index)
        for _, dumpItem in ipairs(CURRENCY_DUMP_ITEMS) do
            if itemInfo and (itemID == dumpItem.itemID or itemInfo.name == dumpItem.name) then
                local currencyCost = GetCurrencyCost(index, itemInfo, dumpItem.currencyID)
                return {
                    index = index,
                    itemID = dumpItem.itemID,
                    name = itemInfo.name or dumpItem.name,
                    currencyID = dumpItem.currencyID,
                    cost = currencyCost > 0 and currencyCost or dumpItem.fallbackCost,
                    costDetected = currencyCost > 0,
                    confirmEachPurchase = dumpItem.confirmEachPurchase,
                    texture = itemInfo.texture,
                    available = tonumber(itemInfo.numAvailable) or -1,
                    purchasable = itemInfo.isPurchasable ~= false,
                }
            end
        end
    end
end

local function GetPurchaseState()
    if not MerchantFrame or not MerchantFrame:IsShown() then return nil end

    local item = FindCurrencyDumpItem()
    if not item or not item.cost or item.cost <= 0 then return nil end

    local currencyAmount = GetCurrencyQuantity(item.currencyID)
    local quantity = math.floor(currencyAmount / item.cost)
    if item.available >= 0 then
        quantity = math.min(quantity, item.available)
    end

    item.affordableQuantity = math.max(quantity, 0)
    if item.confirmEachPurchase then
        quantity = math.min(quantity, 1)
    end

    item.currencyAmount = currencyAmount
    item.currencyName = GetCurrencyName(item.currencyID)
    item.quantity = math.max(quantity, 0)
    item.spend = item.quantity * item.cost
    item.totalSpend = item.affordableQuantity * item.cost
    return item
end

local UpdatePanel

local function RefreshSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, UpdatePanel)
    else
        UpdatePanel()
    end
end

local function RefreshCharacterData()
    if DataCollection and DataCollection.CollectCurrentCharacter then
        DataCollection.CollectCurrentCharacter()
    end
    if ns.UI and ns.UI.RefreshTable then
        ns.UI.RefreshTable()
    end
    UpdatePanel()
end

local function BuyMaxCurrencyDumpItem()
    local state = GetPurchaseState()
    if not state or state.quantity <= 0 or not BuyMerchantItem then return end

    if state.confirmEachPurchase then
        BuyMerchantItem(state.index)
    else
        BuyMerchantItem(state.index, state.quantity)
    end
    RefreshSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, RefreshCharacterData)
    else
        RefreshCharacterData()
    end
end

local function ShowTooltip(self)
    local state = GetPurchaseState()
    if not state then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Warband Ratings")
    if state.confirmEachPurchase then
        GameTooltip:AddLine("Requests one copy of " .. state.name .. " per click.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Buys as many copies of " .. state.name .. " as your " .. state.currencyName .. " allows.", 1, 1, 1, true)
    end
    GameTooltip:AddDoubleLine(state.currencyName .. ":", FormatNumber(state.currencyAmount), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Cost each:", FormatNumber(state.cost), 1, 0.82, 0, 1, 1, 1)
    if state.confirmEachPurchase then
        GameTooltip:AddDoubleLine("Can spend:", FormatNumber(state.totalSpend), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Remaining:", FormatNumber(state.affordableQuantity), 1, 0.82, 0, 1, 1, 1)
    else
        GameTooltip:AddDoubleLine("Will buy:", FormatNumber(state.quantity), 1, 0.82, 0, 1, 1, 1)
    end
    if not state.costDetected then
        GameTooltip:AddLine("Using the current vendor price fallback.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:Show()
end

local function EnsurePanel()
    if panel or not MerchantFrame then return end

    panel = CreateFrame("Frame", "WarbandRatingsMerchantDumpFrame", UIParent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel((MerchantFrame:GetFrameLevel() or 0) + 10)
    panel:EnableMouse(true)
    panel:SetScript("OnEnter", ShowTooltip)
    panel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    panel:Hide()

    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()

    panel.headerBg = panel:CreateTexture(nil, "BORDER")
    panel.headerBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.headerBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.headerBg:SetHeight(22)

    panel.accentLine = panel:CreateTexture(nil, "BORDER")
    panel.accentLine:SetPoint("TOPLEFT", panel.headerBg, "BOTTOMLEFT", 0, 0)
    panel.accentLine:SetPoint("TOPRIGHT", panel.headerBg, "BOTTOMRIGHT", 0, 0)
    panel.accentLine:SetHeight(1)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.title:SetPoint("LEFT", panel.headerBg, "LEFT", 8, 0)
    panel.title:SetText("Warband Ratings")

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(ICON_SIZE, ICON_SIZE)
    panel.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -34)
    panel.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    panel.iconBg = panel:CreateTexture(nil, "BORDER")
    panel.iconBg:SetPoint("TOPLEFT", panel.icon, "TOPLEFT", -2, 2)
    panel.iconBg:SetPoint("BOTTOMRIGHT", panel.icon, "BOTTOMRIGHT", 2, -2)

    panel.iconBorderTop = panel:CreateTexture(nil, "OVERLAY")
    panel.iconBorderTop:SetPoint("TOPLEFT", panel.iconBg, "TOPLEFT", 0, 0)
    panel.iconBorderTop:SetPoint("TOPRIGHT", panel.iconBg, "TOPRIGHT", 0, 0)
    panel.iconBorderTop:SetHeight(1)

    panel.iconBorderBottom = panel:CreateTexture(nil, "OVERLAY")
    panel.iconBorderBottom:SetPoint("BOTTOMLEFT", panel.iconBg, "BOTTOMLEFT", 0, 0)
    panel.iconBorderBottom:SetPoint("BOTTOMRIGHT", panel.iconBg, "BOTTOMRIGHT", 0, 0)
    panel.iconBorderBottom:SetHeight(1)

    panel.iconBorderLeft = panel:CreateTexture(nil, "OVERLAY")
    panel.iconBorderLeft:SetPoint("TOPLEFT", panel.iconBg, "TOPLEFT", 0, 0)
    panel.iconBorderLeft:SetPoint("BOTTOMLEFT", panel.iconBg, "BOTTOMLEFT", 0, 0)
    panel.iconBorderLeft:SetWidth(1)

    panel.iconBorderRight = panel:CreateTexture(nil, "OVERLAY")
    panel.iconBorderRight:SetPoint("TOPRIGHT", panel.iconBg, "TOPRIGHT", 0, 0)
    panel.iconBorderRight:SetPoint("BOTTOMRIGHT", panel.iconBg, "BOTTOMRIGHT", 0, 0)
    panel.iconBorderRight:SetWidth(1)

    panel.body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.body:SetPoint("TOPLEFT", panel.icon, "TOPRIGHT", 8, -1)
    panel.body:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -32)
    panel.body:SetJustifyH("LEFT")
    panel.body:SetJustifyV("TOP")

    panel.detail = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.detail:SetPoint("TOPLEFT", panel.body, "BOTTOMLEFT", 0, -4)
    panel.detail:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    panel.detail:SetJustifyH("LEFT")

    panel.button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 7)
    panel.button:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 7)
    panel.button:SetHeight(22)
    panel.button:SetScript("OnClick", BuyMaxCurrencyDumpItem)
    panel.button:SetScript("OnEnter", ShowTooltip)
    panel.button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ApplyPanelTheme()
end

UpdatePanel = function()
    if not panel then return end

    local state = GetPurchaseState()
    panel.state = state
    if not state then
        panel:Hide()
        return
    end

    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 8, -28)
    panel:SetFrameLevel((MerchantFrame:GetFrameLevel() or 0) + 10)
    panel.icon:SetTexture(state.texture)

    if state.quantity <= 0 or not state.purchasable then
        panel:Hide()
        return
    end

    panel:Show()
    ApplyPanelTheme()
    if state.confirmEachPurchase then
        panel.body:SetText("Can spend " .. FormatNumber(state.totalSpend) .. " " .. state.currencyName .. " on " .. state.name .. ".")
        panel.detail:SetText(FormatNumber(state.cost) .. " " .. state.currencyName .. " each. Confirms one purchase at a time.")
        panel.button:SetText(FormatNumber(state.affordableQuantity) .. " remaining")
    else
        panel.body:SetText("Dump " .. FormatNumber(state.spend) .. " " .. state.currencyName .. " into " .. state.name .. ".")
        panel.detail:SetText("Buys " .. FormatNumber(state.quantity) .. " at " .. FormatNumber(state.cost) .. " " .. state.currencyName .. " each.")
        panel.button:SetText("Buy " .. FormatNumber(state.quantity))
    end
    panel.button:Enable()
end

function Merchant.Attach()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_UPDATE")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then
            if panel then panel:Hide() end
            return
        end

        EnsurePanel()
        RefreshSoon()
    end)
end

Merchant.Attach()
