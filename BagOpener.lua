local _, ns = ...
ns.BagOpener = {}
local BagOpener = ns.BagOpener
local Database = ns.Database
local Utils = ns.Utils
local HelperPanel = ns.HelperPanel

local PANEL_WIDTH = 252
local PANEL_HEIGHT = 122
local PANEL_TOP_OFFSET = 72
local BUTTON_HEIGHT = 28
local BUTTON_GAP = 6
local CONTENT_TOP_OFFSET = 34
local FIRST_BUTTON_TOP_OFFSET = 54
local BUTTON_ICON_SIZE = 20
local BUTTON_ICON_SLOT_WIDTH = 32

local OPENABLE_BOXES = {
    {
        key = "fieldMedic",
        itemIDs = Database.FIELD_MEDIC_HAZARD_PAYOUT_ITEM_IDS,
        name = Database.FIELD_MEDIC_HAZARD_PAYOUT_NAME,
        buttonLabel = "Field Medic Payout",
    },
    {
        key = "illustriousStrongbox",
        itemIDs = { Database.ILLUSTRIOUS_CONTENDER_STRONGBOX_ITEM_ID },
        name = Database.ILLUSTRIOUS_CONTENDER_STRONGBOX_NAME,
        buttonLabel = "Contender Strongbox",
    },
}

local eventFrame
local panel
local boxByItemID = {}
local isPanelMoving = false
local UpdatePanel
local RefreshSoon

for _, box in ipairs(OPENABLE_BOXES) do
    for _, itemID in ipairs(box.itemIDs or {}) do
        boxByItemID[itemID] = box
    end
end

local function FormatNumber(value)
    if Utils and Utils.FormatNumber then
        return Utils.FormatNumber(value)
    end
    return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function FormatCount(value)
    value = tonumber(value) or 0
    if value <= 0 then
        return "0"
    end
    return FormatNumber(value)
end

local function GetBoxIcon(box)
    local itemID = box and box.itemIDs and box.itemIDs[1]
    if not itemID then return nil end

    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    elseif C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
        return icon
    end
    return nil
end

local function ApplyButtonTheme(button)
    if not button then return end

    local theme = HelperPanel.GetTheme()
    local enabled = not button.IsEnabled or button:IsEnabled()
    HelperPanel.SetTextureColor(button.bg, enabled and theme.surfaceRaised or theme.surface, enabled and 0.94 or 0.55)
    HelperPanel.SetTextureColor(button.hover, theme.rowHover, enabled and 0.90 or 0)
    HelperPanel.SetTextureColor(button.pushed, theme.accent, enabled and 0.18 or 0)
    HelperPanel.SetTextureColor(button.iconBg, theme.surface, enabled and 0.92 or 0.52)
    HelperPanel.SetTextureColor(button.iconBorderTop, enabled and theme.accent or theme.border, enabled and 0.72 or 0.38)
    HelperPanel.SetTextureColor(button.iconBorderBottom, enabled and theme.accent or theme.border, enabled and 0.72 or 0.38)
    HelperPanel.SetTextureColor(button.iconBorderLeft, enabled and theme.accent or theme.border, enabled and 0.72 or 0.38)
    HelperPanel.SetTextureColor(button.iconBorderRight, enabled and theme.accent or theme.border, enabled and 0.72 or 0.38)
    HelperPanel.SetFontColor(button.label, enabled and theme.text or theme.muted)

    local borderAlpha = enabled and 0.88 or 0.45
    HelperPanel.SetTextureColor(
        HelperPanel.CreateBorder(button, "buttonBorderTop", "TOPLEFT", "TOPLEFT", 0, 0, PANEL_WIDTH - 20, 1),
        theme.border,
        borderAlpha
    )
    HelperPanel.SetTextureColor(
        HelperPanel.CreateBorder(button, "buttonBorderBottom", "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, PANEL_WIDTH - 20, 1),
        theme.border,
        borderAlpha
    )
    HelperPanel.SetTextureColor(
        HelperPanel.CreateBorder(button, "buttonBorderLeft", "TOPLEFT", "TOPLEFT", 0, 0, 1, BUTTON_HEIGHT),
        theme.border,
        borderAlpha
    )
    HelperPanel.SetTextureColor(
        HelperPanel.CreateBorder(button, "buttonBorderRight", "TOPRIGHT", "TOPRIGHT", 0, 0, 1, BUTTON_HEIGHT),
        theme.border,
        borderAlpha
    )

    if button.icon then
        if button.icon.SetAlpha then
            button.icon:SetAlpha(enabled and 1 or 0.42)
        end
        if button.icon.SetDesaturated then
            button.icon:SetDesaturated(not enabled)
        end
    end
end

local function ApplyPanelTheme()
    if not panel then return end

    local theme = HelperPanel.ApplyShellTheme(panel)
    HelperPanel.SetFontColor(panel.contentTitle, theme.text)
    HelperPanel.SetFontColor(panel.emptyText, theme.muted)

    if panel.buttons then
        for _, button in pairs(panel.buttons) do
            ApplyButtonTheme(button)
        end
    end
end

BagOpener.ApplyTheme = ApplyPanelTheme

local function GetContainerItemID(itemInfo)
    if not itemInfo then return nil end
    if itemInfo.itemID then return itemInfo.itemID end
    return itemInfo.hyperlink and tonumber(itemInfo.hyperlink:match("item:(%d+)"))
end

local function GetContainerItemName(itemInfo)
    if not itemInfo then return nil end
    if itemInfo.itemName then return itemInfo.itemName end
    if itemInfo.hyperlink then
        if C_Item and C_Item.GetItemInfo then
            local itemName = C_Item.GetItemInfo(itemInfo.hyperlink)
            if itemName then return itemName end
        end
        if _G.GetItemInfo then
            local itemName = _G.GetItemInfo(itemInfo.hyperlink)
            if itemName then return itemName end
        end
    end
    return nil
end

local function GetBoxForContainerItem(itemInfo)
    local itemID = GetContainerItemID(itemInfo)
    local box = itemID and boxByItemID[itemID]
    if box then return box end

    local itemName = GetContainerItemName(itemInfo)
    if not itemName then return nil end
    for _, candidate in ipairs(OPENABLE_BOXES) do
        if itemName == candidate.name then
            return candidate
        end
    end
end

local function AddBagID(bagIDs, used, bagID)
    bagID = tonumber(bagID)
    if bagID and not used[bagID] then
        used[bagID] = true
        bagIDs[#bagIDs + 1] = bagID
    end
end

local function GetPlayerBagIDs()
    local bagIDs = {}
    local used = {}
    AddBagID(bagIDs, used, _G.BACKPACK_CONTAINER or 0)

    for bagID = 1, (_G.NUM_BAG_SLOTS or 4) do
        AddBagID(bagIDs, used, bagID)
    end

    local bagIndex = Enum and Enum.BagIndex
    if bagIndex and bagIndex.ReagentBag then
        AddBagID(bagIDs, used, bagIndex.ReagentBag)
    end

    return bagIDs
end

local function ScanOpenableBoxes()
    local state = {}
    for _, box in ipairs(OPENABLE_BOXES) do
        state[box.key] = {
            box = box,
            count = 0,
            location = nil,
        }
    end

    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
        return state
    end

    for _, bagID in ipairs(GetPlayerBagIDs()) do
        local slots = tonumber(C_Container.GetContainerNumSlots(bagID)) or 0
        for slot = 1, slots do
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
            local box = GetBoxForContainerItem(itemInfo)
            if box then
                local itemState = state[box.key]
                itemState.count = itemState.count + (tonumber(itemInfo.stackCount) or 1)
                if not itemState.location and not itemInfo.isLocked then
                    itemState.location = {
                        bagID = bagID,
                        slot = slot,
                        itemID = GetContainerItemID(itemInfo),
                        itemName = GetContainerItemName(itemInfo),
                    }
                end
            end
        end
    end

    return state
end

local function HasOpenableBoxes(state)
    for _, box in ipairs(OPENABLE_BOXES) do
        if (state[box.key].count or 0) > 0 then
            return true
        end
    end
    return false
end

local function IsMerchantShown()
    return MerchantFrame and MerchantFrame:IsShown()
end

local function IsPlayerInCombat()
    return (_G.InCombatLockdown and _G.InCombatLockdown())
        or (_G.UnitAffectingCombat and _G.UnitAffectingCombat("player"))
end

local function IsPlayerInInstance()
    if not _G.IsInInstance then return false end

    local inInstance = _G.IsInInstance()
    return inInstance and true or false
end

local function IsBoxesHelperHidden()
    local settings = WarbandRatingsDB and WarbandRatingsDB.settings
    return settings and settings.hideBoxesHelper
end

local function ShouldSuppressPanel()
    return IsBoxesHelperHidden() or IsPlayerInCombat() or IsPlayerInInstance()
end

local function HidePanel()
    if not panel then return end

    if isPanelMoving then
        panel:StopMovingOrSizing()
        isPanelMoving = false
    end
    panel:Hide()
end

local function GetSettings()
    return WarbandRatingsDB and WarbandRatingsDB.settings
end

local function GetSavedPanelPosition()
    local settings = GetSettings()
    local position = settings and settings.bagOpenerPosition
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        return position
    end
    return nil
end

local function SetPanelTopPosition(x, y)
    panel:ClearAllPoints()
    panel:SetPoint("TOP", UIParent, "TOP", x, y)
end

local function ClampPanelToScreen()
    if not panel or not UIParent then return end

    local parentWidth = UIParent:GetWidth()
    local parentHeight = UIParent:GetHeight()
    if not parentWidth or not parentHeight or parentWidth <= 0 or parentHeight <= 0 then return end

    local width = panel:GetWidth()
    local height = panel:GetHeight()
    local left = panel:GetLeft()
    local top = panel:GetTop()
    if not left or not top then return end

    if width <= parentWidth then
        left = math.max(0, math.min(left, parentWidth - width))
    else
        left = (parentWidth - width) / 2
    end

    if height <= parentHeight then
        top = math.max(height, math.min(top, parentHeight))
    else
        top = parentHeight
    end

    SetPanelTopPosition(left + (width / 2) - (parentWidth / 2), top - parentHeight)
end

local function SavePanelPosition()
    local settings = GetSettings()
    if not settings or not panel or not UIParent then return end

    local parentWidth = UIParent:GetWidth()
    local parentHeight = UIParent:GetHeight()
    local left = panel:GetLeft()
    local top = panel:GetTop()
    if not parentWidth or not parentHeight or not left or not top then return end

    local position = {
        x = math.floor(left + (panel:GetWidth() / 2) - (parentWidth / 2) + 0.5),
        y = math.floor(top - parentHeight + 0.5),
    }

    if Database and Database.SetSetting then
        Database.SetSetting("bagOpenerPosition", position)
    else
        settings.bagOpenerPosition = position
    end
end

local function StartPanelMove()
    if not panel then return end

    isPanelMoving = true
    panel:StartMoving()
end

local function StopPanelMove()
    if not panel then return end

    panel:StopMovingOrSizing()
    isPanelMoving = false
    ClampPanelToScreen()
    HelperPanel.SnapFrameToPixelGrid(panel)
    SavePanelPosition()
end

local function PositionPanel()
    if not panel then return false end
    if isPanelMoving then return true end

    local position = GetSavedPanelPosition()
    if position then
        SetPanelTopPosition(position.x, position.y)
    else
        SetPanelTopPosition(0, -PANEL_TOP_OFFSET)
    end

    ClampPanelToScreen()
    HelperPanel.SnapFrameToPixelGrid(panel)
    return true
end

RefreshSoon = function()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, UpdatePanel)
    else
        UpdatePanel()
    end
end

function BagOpener.Refresh()
    RefreshSoon()
end

local function UseItemByGUID(location)
    if not location or not _G.ItemLocation or not C_Item or not C_Item.GetItemGUID or not C_Item.UseItemByGUID then
        return false
    end

    local itemLocation = _G.ItemLocation:CreateFromBagAndSlot(location.bagID, location.slot)
    if not itemLocation then
        return false
    end
    if itemLocation.IsValid and not itemLocation:IsValid() then
        return false
    end

    local itemGUID = C_Item.GetItemGUID(itemLocation)
    if not itemGUID then
        return false
    end

    C_Item.UseItemByGUID(itemGUID)
    return true
end

local function UseItemByName(location, box)
    local itemInfo = location and (location.itemID or location.itemName)
        or (box and (box.itemIDs and box.itemIDs[1] or box.name))
    if not itemInfo then
        return false
    end

    if C_Item and C_Item.UseItemByName then
        C_Item.UseItemByName(itemInfo)
        return true
    elseif _G.UseItemByName then
        _G.UseItemByName(itemInfo)
        return true
    end

    return false
end

local function CanOpenBoxAtMerchant()
    return (C_Item and C_Item.UseItemByGUID and C_Item.GetItemGUID and _G.ItemLocation)
        or (C_Item and C_Item.UseItemByName)
        or _G.UseItemByName
end

local function UseBoxItem(location, box)
    if IsMerchantShown() then
        return UseItemByGUID(location) or UseItemByName(location, box)
    end

    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(location.bagID, location.slot)
        return true
    elseif _G.UseContainerItem then
        _G.UseContainerItem(location.bagID, location.slot)
        return true
    end

    return UseItemByGUID(location) or UseItemByName(location, box)
end

local function OpenBox(boxKey)
    local state = ScanOpenableBoxes()
    local itemState = state[boxKey]
    local location = itemState and itemState.location
    if not location then
        RefreshSoon()
        return
    end

    UseBoxItem(location, itemState.box)

    RefreshSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, UpdatePanel)
        C_Timer.After(0.8, UpdatePanel)
    end
end

local function ShowButtonTooltip(button)
    local itemState = panel and panel.state and panel.state[button.boxKey]
    if not itemState then return end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Warband Ratings")
    GameTooltip:AddLine("Opens one " .. itemState.box.name .. " from your bags.", 1, 1, 1, true)
    GameTooltip:AddDoubleLine("Remaining:", FormatCount(itemState.count), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

local function CreateBoxButton(parent, box, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -FIRST_BUTTON_TOP_OFFSET - ((index - 1) * (BUTTON_HEIGHT + BUTTON_GAP)))
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -FIRST_BUTTON_TOP_OFFSET - ((index - 1) * (BUTTON_HEIGHT + BUTTON_GAP)))
    button:SetHeight(BUTTON_HEIGHT)
    button.boxKey = box.key
    button.box = box

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()

    button.hover = button:CreateTexture(nil, "BORDER")
    button.hover:SetAllPoints()
    button.hover:Hide()

    button.pushed = button:CreateTexture(nil, "ARTWORK")
    button.pushed:SetAllPoints()
    button.pushed:Hide()

    button.iconBg = button:CreateTexture(nil, "BORDER")
    button.iconBg:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.iconBg:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    button.iconBg:SetWidth(BUTTON_ICON_SLOT_WIDTH)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(BUTTON_ICON_SIZE, BUTTON_ICON_SIZE)
    button.icon:SetPoint("CENTER", button.iconBg, "CENTER", 0, 0)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.iconBorderTop = button:CreateTexture(nil, "OVERLAY")
    button.iconBorderTop:SetPoint("TOPLEFT", button.iconBg, "TOPLEFT", 0, 0)
    button.iconBorderTop:SetPoint("TOPRIGHT", button.iconBg, "TOPRIGHT", 0, 0)
    button.iconBorderTop:SetHeight(1)

    button.iconBorderBottom = button:CreateTexture(nil, "OVERLAY")
    button.iconBorderBottom:SetPoint("BOTTOMLEFT", button.iconBg, "BOTTOMLEFT", 0, 0)
    button.iconBorderBottom:SetPoint("BOTTOMRIGHT", button.iconBg, "BOTTOMRIGHT", 0, 0)
    button.iconBorderBottom:SetHeight(1)

    button.iconBorderLeft = button:CreateTexture(nil, "OVERLAY")
    button.iconBorderLeft:SetPoint("TOPLEFT", button.iconBg, "TOPLEFT", 0, 0)
    button.iconBorderLeft:SetPoint("BOTTOMLEFT", button.iconBg, "BOTTOMLEFT", 0, 0)
    button.iconBorderLeft:SetWidth(1)

    button.iconBorderRight = button:CreateTexture(nil, "OVERLAY")
    button.iconBorderRight:SetPoint("TOPRIGHT", button.iconBg, "TOPRIGHT", 0, 0)
    button.iconBorderRight:SetPoint("BOTTOMRIGHT", button.iconBg, "BOTTOMRIGHT", 0, 0)
    button.iconBorderRight:SetWidth(1)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("LEFT", button.iconBg, "RIGHT", 8, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -9, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetJustifyV("MIDDLE")

    button:SetScript("OnClick", function(self)
        OpenBox(self.boxKey)
    end)
    button:SetScript("OnEnter", function(self)
        if not self.IsEnabled or self:IsEnabled() then
            self.hover:Show()
        end
        ShowButtonTooltip(self)
    end)
    button:SetScript("OnLeave", function()
        button.hover:Hide()
        button.pushed:Hide()
        GameTooltip:Hide()
    end)
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" and (not self.IsEnabled or self:IsEnabled()) then
            self.pushed:Show()
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        self.pushed:Hide()
    end)
    button:SetScript("OnEnable", ApplyButtonTheme)
    button:SetScript("OnDisable", function(self)
        self.hover:Hide()
        self.pushed:Hide()
        ApplyButtonTheme(self)
    end)
    ApplyButtonTheme(button)
    return button
end

local function EnsurePanel()
    if panel then return end

    panel = HelperPanel.CreateShell("WarbandRatingsBagOpenerFrame", PANEL_WIDTH, PANEL_HEIGHT, "Warband Ratings")
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", StartPanelMove)
    panel:SetScript("OnDragStop", StopPanelMove)

    panel.contentTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.contentTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -CONTENT_TOP_OFFSET)
    panel.contentTitle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -CONTENT_TOP_OFFSET)
    panel.contentTitle:SetJustifyH("LEFT")
    panel.contentTitle:SetText("Open boxes")

    panel.buttons = {}
    for index, box in ipairs(OPENABLE_BOXES) do
        panel.buttons[box.key] = CreateBoxButton(panel, box, index)
    end

    panel.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.emptyText:SetPoint("BOTTOM", panel, "BOTTOM", 0, 9)
    panel.emptyText:SetText("No matching boxes in bags")
    panel.emptyText:Hide()

    ApplyPanelTheme()
end

UpdatePanel = function()
    if ShouldSuppressPanel() then
        HidePanel()
        return
    end

    EnsurePanel()
    if not panel then return end

    local state = ScanOpenableBoxes()
    panel.state = state
    if not HasOpenableBoxes(state) then
        HidePanel()
        return
    end

    if not PositionPanel() then
        HidePanel()
        return
    end

    panel:SetFrameLevel(1000)
    panel:Show()
    ApplyPanelTheme()

    for _, box in ipairs(OPENABLE_BOXES) do
        local itemState = state[box.key]
        local button = panel.buttons[box.key]
        local count = itemState and itemState.count or 0
        button.icon:SetTexture(GetBoxIcon(box))
        button.label:SetText(box.buttonLabel .. " (" .. FormatCount(count) .. ")")
        if count > 0 and itemState and itemState.location and (not IsMerchantShown() or CanOpenBoxAtMerchant()) then
            button:Enable()
        else
            button:Disable()
        end
    end
end

function BagOpener.Attach()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            RefreshSoon()
            return
        elseif event == "MERCHANT_CLOSED" then
            RefreshSoon()
            return
        end
        RefreshSoon()
    end)
end

BagOpener.Attach()
