local _, ns = ...
ns.BagOpener = {}
local BagOpener = ns.BagOpener
local Database = ns.Database
local Utils = ns.Utils
local HelperPanel = ns.HelperPanel
local Season = ns.Season

local PANEL_WIDTH = 252
local PANEL_TOP_OFFSET = 72
local BUTTON_HEIGHT = 28
local BUTTON_GAP = 6
local CONTENT_TOP_OFFSET = 34
local FIRST_BUTTON_TOP_OFFSET = 54
local BUTTON_ICON_SIZE = 20
local BUTTON_ICON_SLOT_WIDTH = 32
local OPENING_BAR_FALLBACK_DURATION = 5
local OPENING_BAR_HEIGHT = 3
local OPENING_CAST_START_TIMEOUT = 1.25
local OPENING_CAST_MIN_DURATION = 1.5
local OPENING_CAST_SYNC_DELAYS = { 0.05, 0.15, 0.30 }
local OPENING_REBIND_DELAY = 0.375
local OPENING_REBIND_MAX_DELAY = 0.875
local CAST_TIME_EPSILON = 0.02

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
local pendingOpeningButton
local pendingPanelHide = false
local bagUpdateSerial = 0
local isPanelMoving = false
local UpdatePanel
local UpdateOpeningBar
local RefreshSoon
local SyncOpeningButtonToPlayerCast
local ScheduleOpeningCastSync
local CreateBoxButton

local function GetPanelHeight()
    return FIRST_BUTTON_TOP_OFFSET
        + (#OPENABLE_BOXES * BUTTON_HEIGHT)
        + (math.max(#OPENABLE_BOXES - 1, 0) * BUTTON_GAP)
        + 8
end

for _, box in ipairs(OPENABLE_BOXES) do
    for _, itemID in ipairs(box.itemIDs or {}) do
        boxByItemID[itemID] = box
    end
end

local function RefreshConquestEquipmentChestBox()
    local feature = Season.GetFeature("conquestEquipmentChest")
    if not feature then return false end

    local box
    local boxIndex
    for index, candidate in ipairs(OPENABLE_BOXES) do
        if candidate.key == "conquestEquipmentChest" then
            box = candidate
            boxIndex = index
            break
        end
    end

    if not box then
        box = { key = "conquestEquipmentChest" }
        OPENABLE_BOXES[#OPENABLE_BOXES + 1] = box
        boxIndex = #OPENABLE_BOXES
    else
        for _, oldItemID in ipairs(box.itemIDs or {}) do
            if boxByItemID[oldItemID] == box then
                boxByItemID[oldItemID] = nil
            end
        end
    end

    box.itemIDs = { feature.itemID }
    box.name = feature.name
    box.buttonLabel = feature.name
    box.hasOpeningCast = feature.hasOpeningCast
    boxByItemID[feature.itemID] = box

    if panel then
        panel:SetHeight(GetPanelHeight())
        panel.buttons = panel.buttons or {}
        if not panel.buttons[box.key] and CreateBoxButton then
            panel.buttons[box.key] = CreateBoxButton(panel, box, boxIndex)
        elseif panel.buttons[box.key] then
            panel.buttons[box.key].box = box
        end
    end
    return true
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
    HelperPanel.SetTextureColor(button.openingBarBg, theme.surface, 0.95)
    HelperPanel.SetTextureColor(button.openingBar, theme.accent, 0.95)
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

local function GetTimeNow()
    return _G.GetTime and _G.GetTime() or 0
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
    RefreshConquestEquipmentChestBox()
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

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        pendingPanelHide = true
        return
    end

    pendingPanelHide = false
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
    RefreshConquestEquipmentChestBox()
    RefreshSoon()
end

function BagOpener.Hide()
    if Database and Database.SetSetting then
        Database.SetSetting("hideBoxesHelper", true)
    elseif GetSettings() then
        GetSettings().hideBoxesHelper = true
    end
    if ns.UI and ns.UI.RefreshSettingsCheckboxes then
        ns.UI.RefreshSettingsCheckboxes()
    end
    HidePanel()
end

local function GetStaticPopupText(dialogName)
    local dialog = _G[dialogName]
    local text = dialog and dialog.text
    return text and text.GetText and text:GetText()
end

local function GetStaticPopupItemName(dialogName)
    local itemName = _G[dialogName .. "ItemFrameName"]
    if itemName and itemName.GetText then
        return itemName:GetText()
    end

    local itemFrame = _G[dialogName .. "ItemFrame"]
    itemName = itemFrame and itemFrame.Name
    return itemName and itemName.GetText and itemName:GetText()
end

local function IsOpenableBoxRefundPopup(dialogName, box)
    local text = GetStaticPopupText(dialogName)
    text = text and string.lower(text) or ""
    if not text:find("non-refundable", 1, true) then
        return false
    end

    local itemName = GetStaticPopupItemName(dialogName)
    if not itemName or itemName == "" then
        return box ~= nil
    end

    if box and itemName == box.name then
        return true
    end

    for _, candidate in ipairs(OPENABLE_BOXES) do
        if itemName == candidate.name then
            return true
        end
    end
    return false
end

local function ConfirmOpenableBoxRefundPopup(box)
    local dialogCount = tonumber(_G.STATICPOPUP_NUMDIALOGS) or 4
    for index = 1, dialogCount do
        local dialogName = "StaticPopup" .. index
        local dialog = _G[dialogName]
        if dialog and dialog:IsShown() and IsOpenableBoxRefundPopup(dialogName, box) then
            local button = _G[dialogName .. "Button1"]
            if button and (not button.IsEnabled or button:IsEnabled()) then
                button:Click()
                return true
            end
        end
    end
    return false
end

local function GetUseMacroText(location, box)
    if not location then return nil end

    if IsMerchantShown() and box and box.name then
        return "/stopcasting\n/use " .. box.name
    end

    return "/stopcasting\n/use " .. tostring(location.bagID) .. " " .. tostring(location.slot)
end

local function SetButtonUseAction(button, location, box)
    if not button or (_G.InCombatLockdown and _G.InCombatLockdown()) then return end

    local macroText = GetUseMacroText(location, box)
    if macroText then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", macroText)
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", macroText)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("macrotext", nil)
        button:SetAttribute("type1", nil)
        button:SetAttribute("macrotext1", nil)
    end
end

local function SetOpeningBarProgress(button, progress)
    if not button or not button.openingBar or not button.openingBarBg then return end

    progress = math.max(0, math.min(tonumber(progress) or 0, 1))
    local width = (button:GetWidth() or (PANEL_WIDTH - 20)) - 4
    button.openingBar:SetWidth(math.max(1, math.floor(width * progress + 0.5)))
    button.openingBarBg:Show()
    button.openingBar:Show()
end

local function BuildCastInfo(source, name, startTimeMS, endTimeMS, castID, spellID)
    if not startTimeMS or not endTimeMS or endTimeMS <= startTimeMS then
        return nil
    end

    local startTime = startTimeMS / 1000
    local endTime = endTimeMS / 1000
    return {
        source = source,
        name = name,
        startTime = startTime,
        endTime = endTime,
        duration = endTime - startTime,
        castID = castID,
        spellID = spellID,
    }
end

local function GetActivePlayerCastInfo()
    if _G.UnitCastingInfo then
        local name, _, _, startTimeMS, endTimeMS, _, castID, _, spellID = _G.UnitCastingInfo("player")
        local info = BuildCastInfo("cast", name, startTimeMS, endTimeMS, castID, spellID)
        if info then return info end
    end

    if _G.UnitChannelInfo then
        local name, _, _, startTimeMS, endTimeMS, _, _, spellID = _G.UnitChannelInfo("player")
        local info = BuildCastInfo("channel", name, startTimeMS, endTimeMS, nil, spellID)
        if info then return info end
    end
end

local function AreCastTimesEqual(leftStart, leftEnd, rightStart, rightEnd)
    return leftStart
        and leftEnd
        and rightStart
        and rightEnd
        and math.abs(leftStart - rightStart) <= CAST_TIME_EPSILON
        and math.abs(leftEnd - rightEnd) <= CAST_TIME_EPSILON
end

local function IsPreClickCast(button, info)
    if not info then return false end
    if info.castID and button.openingIgnoredCastID and info.castID == button.openingIgnoredCastID then
        return true
    end
    return AreCastTimesEqual(info.startTime, info.endTime, button.openingIgnoredCastStart, button.openingIgnoredCastEnd)
end

local function IsOpeningCastCandidate(info)
    return info and (info.duration or 0) >= OPENING_CAST_MIN_DURATION
end

local function IsAcceptedOpeningCast(button, info, castGUID, spellID)
    if not button or not info or not button.openingCastAccepted then return false end
    if button.openingCastGUID and castGUID then
        return button.openingCastGUID == castGUID
    end
    if button.openingCastID and info.castID then
        return button.openingCastID == info.castID
    end
    if button.openingCastSpellID and spellID and button.openingCastSpellID ~= spellID then
        return false
    end
    return AreCastTimesEqual(info.startTime, info.endTime, button.openingStartedAt, button.openingUntil)
end

local function GetButtonOpeningCastInfo(button, castGUID, spellID)
    if not button then return nil end

    local info = GetActivePlayerCastInfo()
    if not info then return nil end

    if button.openingCastAccepted then
        if IsAcceptedOpeningCast(button, info, castGUID, spellID) then
            return info
        end
        return nil
    end

    if IsPreClickCast(button, info) then return nil end
    if not IsOpeningCastCandidate(info) then return nil end

    local clickTime = button.openingClickTime or button.openingStartedAt
    if clickTime and info.startTime < (clickTime - CAST_TIME_EPSILON) then
        return nil
    end

    return info
end

local function CapturePreClickCast(button)
    if not button then return end

    local info = GetActivePlayerCastInfo()
    button.openingClickTime = GetTimeNow()
    button.openingIgnoredCastStart = info and info.startTime
    button.openingIgnoredCastEnd = info and info.endTime
    button.openingIgnoredCastID = info and info.castID
end

local function IsAcceptedOpeningCastActive(button)
    if not button or not button.openingCastAccepted then return false end

    local info = GetActivePlayerCastInfo()
    return IsAcceptedOpeningCast(button, info)
end

local function IsAcceptedOpeningCastEvent(button, castGUID, spellID)
    if not button or not button.openingCastAccepted then return false end
    if button.openingCastGUID and castGUID then
        return button.openingCastGUID == castGUID
    end
    if button.openingCastID and castGUID then
        return button.openingCastID == castGUID
    end
    if button.openingCastSpellID and spellID then
        if button.openingCastSpellID ~= spellID then
            return false
        end
        return not IsAcceptedOpeningCastActive(button)
    end
    return not castGUID and not spellID and not IsAcceptedOpeningCastActive(button)
end

local function ClearButtonOpening(button, refresh)
    if not button then return end

    if pendingOpeningButton == button then
        pendingOpeningButton = nil
    end
    button.openingStartedAt = nil
    button.openingUntil = nil
    button.openingCastAccepted = nil
    button.openingCastDeadline = nil
    button.openingClickTime = nil
    button.openingIgnoredCastStart = nil
    button.openingIgnoredCastEnd = nil
    button.openingIgnoredCastID = nil
    button.openingCastID = nil
    button.openingCastGUID = nil
    button.openingCastSpellID = nil
    button:SetScript("OnUpdate", nil)
    if button.openingBarBg then button.openingBarBg:Hide() end
    if button.openingBar then button.openingBar:Hide() end

    if refresh then
        RefreshSoon()
    end
end

local function LockButtonAfterOpening(button)
    if not button then return end

    local now = GetTimeNow()
    button.openingRebindAfter = now + OPENING_REBIND_DELAY
    button.openingRebindFallbackAfter = now + OPENING_REBIND_MAX_DELAY
    button.openingRebindBagUpdateSerial = button.openingBagUpdateSerial or bagUpdateSerial
    button.openingBagUpdateSerial = nil
    SetButtonUseAction(button, nil, button.box)
    button:Disable()

    if C_Timer and C_Timer.After then
        C_Timer.After(OPENING_REBIND_DELAY, UpdatePanel)
        C_Timer.After(OPENING_REBIND_MAX_DELAY, UpdatePanel)
    end
end

local function ClearButtonRebindLock(button)
    if not button then return end

    button.openingRebindAfter = nil
    button.openingRebindFallbackAfter = nil
    button.openingRebindBagUpdateSerial = nil
end

local function SetButtonOpeningCast(button, info, castGUID, spellID)
    if not button or not info or not info.startTime or not info.endTime or info.endTime <= info.startTime then return end

    button.openingCastAccepted = true
    button.openingCastDeadline = nil
    button.openingCastID = info.castID
    button.openingCastGUID = castGUID
    button.openingCastSpellID = spellID or info.spellID
    button.openingStartedAt = info.startTime
    button.openingUntil = info.endTime
    button:SetScript("OnUpdate", UpdateOpeningBar)
    UpdateOpeningBar(button)
end

local function IsButtonTemporarilyLocked(button)
    if not button then return false end

    local now = GetTimeNow()
    if button.openingUntil then
        if not button.openingCastAccepted and button.openingCastDeadline and now >= button.openingCastDeadline then
            ClearButtonOpening(button, false)
            return false
        end

        if now < button.openingUntil then
            return true
        end

        local wasOpeningCast = button.openingCastAccepted
        ClearButtonOpening(button, false)
        if wasOpeningCast then
            LockButtonAfterOpening(button)
        end
    end

    if button.openingRebindAfter then
        local gotBagUpdate = bagUpdateSerial > (button.openingRebindBagUpdateSerial or bagUpdateSerial)
        local minimumPassed = now >= button.openingRebindAfter
        local fallbackPassed = now >= (button.openingRebindFallbackAfter or button.openingRebindAfter)
        if fallbackPassed or (minimumPassed and gotBagUpdate) then
            ClearButtonRebindLock(button)
            return false
        end

        return true
    end

    return false
end

UpdateOpeningBar = function(button)
    if not button or not button.openingUntil or not button.openingStartedAt then return end

    local now = GetTimeNow()
    if not button.openingCastAccepted and button.openingCastDeadline and now >= button.openingCastDeadline then
        ClearButtonOpening(button, true)
        return
    end

    local elapsed = now - button.openingStartedAt
    local duration = button.openingUntil - button.openingStartedAt
    local progress = duration > 0 and (elapsed / duration) or 1
    SetOpeningBarProgress(button, progress)

    if progress >= 1 then
        local wasOpeningCast = button.openingCastAccepted
        ClearButtonOpening(button, true)
        if wasOpeningCast then
            LockButtonAfterOpening(button)
        end
    end
end

SyncOpeningButtonToPlayerCast = function(castGUID, spellID)
    if not pendingOpeningButton then return end

    local info = GetButtonOpeningCastInfo(pendingOpeningButton, castGUID, spellID)
    if info then
        SetButtonOpeningCast(pendingOpeningButton, info, castGUID, spellID)
    end
end

ScheduleOpeningCastSync = function()
    SyncOpeningButtonToPlayerCast()
    if not (C_Timer and C_Timer.After) then return end

    for _, delay in ipairs(OPENING_CAST_SYNC_DELAYS) do
        C_Timer.After(delay, SyncOpeningButtonToPlayerCast)
    end
end

local function StartButtonOpening(button)
    if not button then return end

    local now = GetTimeNow()
    SetButtonUseAction(button, nil, button.box)
    pendingOpeningButton = button
    button.openingBagUpdateSerial = bagUpdateSerial
    button.openingClickTime = button.openingClickTime or now
    button.openingCastAccepted = false
    button.openingCastDeadline = now + OPENING_CAST_START_TIMEOUT
    ClearButtonRebindLock(button)
    button.openingStartedAt = now
    button.openingUntil = button.openingStartedAt + OPENING_BAR_FALLBACK_DURATION
    SetOpeningBarProgress(button, 0)
    button:Disable()
    button:SetScript("OnUpdate", UpdateOpeningBar)
    ScheduleOpeningCastSync()
end

CreateBoxButton = function(parent, box, index)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -FIRST_BUTTON_TOP_OFFSET - ((index - 1) * (BUTTON_HEIGHT + BUTTON_GAP)))
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -FIRST_BUTTON_TOP_OFFSET - ((index - 1) * (BUTTON_HEIGHT + BUTTON_GAP)))
    button:SetHeight(BUTTON_HEIGHT)
    if button.RegisterForClicks then
        button:RegisterForClicks((_G.GetCVarBool and _G.GetCVarBool("ActionButtonUseKeyDown")) and "AnyDown" or "AnyUp")
    end
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

    button.openingBarBg = button:CreateTexture(nil, "ARTWORK")
    button.openingBarBg:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    button.openingBarBg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.openingBarBg:SetHeight(OPENING_BAR_HEIGHT)
    button.openingBarBg:Hide()

    button.openingBar = button:CreateTexture(nil, "OVERLAY")
    button.openingBar:SetPoint("LEFT", button.openingBarBg, "LEFT", 0, 0)
    button.openingBar:SetHeight(OPENING_BAR_HEIGHT)
    button.openingBar:Hide()

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

    button:SetScript("PreClick", function(self, mouseButton)
        if mouseButton and mouseButton ~= "LeftButton" then return end

        if self.box and self.box.hasOpeningCast then
            CapturePreClickCast(self)
        end
    end)
    button:SetScript("PostClick", function(self, mouseButton)
        if mouseButton and mouseButton ~= "LeftButton" then return end

        local hasOpeningCast = self.box and self.box.hasOpeningCast
        if hasOpeningCast then
            StartButtonOpening(self)
        else
            ClearButtonOpening(self, false)
            ClearButtonRebindLock(self)
        end
        ConfirmOpenableBoxRefundPopup(self.box)
        RefreshSoon()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                ConfirmOpenableBoxRefundPopup(self.box)
            end)
            C_Timer.After(0.3, UpdatePanel)
            C_Timer.After(0.8, UpdatePanel)
            if hasOpeningCast then
                C_Timer.After(OPENING_BAR_FALLBACK_DURATION, UpdatePanel)
            end
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not self.IsEnabled or self:IsEnabled() then
            self.hover:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        button.hover:Hide()
        button.pushed:Hide()
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
    RefreshConquestEquipmentChestBox()
    if panel then return end

    panel = HelperPanel.CreateShell(
        "WarbandRatingsBagOpenerFrame",
        PANEL_WIDTH,
        GetPanelHeight(),
        ns.DISPLAY_NAME .. " - Rewards"
    )
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", StartPanelMove)
    panel:SetScript("OnDragStop", StopPanelMove)

    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.closeButton:SetSize(20, 20)
    panel.closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.closeButton:SetFrameLevel(panel:GetFrameLevel() + 5)
    panel.closeButton:SetScript("OnClick", function()
        BagOpener.Hide()
    end)

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

    pendingPanelHide = false
    panel:SetFrameLevel(1000)
    panel:Show()
    ApplyPanelTheme()

    for _, box in ipairs(OPENABLE_BOXES) do
        local itemState = state[box.key]
        local button = panel.buttons[box.key]
        local count = itemState and itemState.count or 0
        button.icon:SetTexture(GetBoxIcon(box))
        button.label:SetText(box.buttonLabel .. " (" .. FormatCount(count) .. ")")
        if IsButtonTemporarilyLocked(button) then
            SetButtonUseAction(button, nil, box)
            button:Disable()
        elseif count > 0 and itemState and itemState.location then
            SetButtonUseAction(button, itemState.location, box)
            button:Enable()
        else
            SetButtonUseAction(button, nil, box)
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
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingPanelHide then
                pendingPanelHide = false
            end
            RefreshSoon()
            return
        elseif event == "MERCHANT_SHOW" then
            RefreshSoon()
            return
        elseif event == "MERCHANT_CLOSED" then
            RefreshSoon()
            return
        elseif event == "BAG_UPDATE_DELAYED" then
            bagUpdateSerial = bagUpdateSerial + 1
            RefreshSoon()
            return
        elseif unit == "player" and (
            event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_DELAYED"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        ) then
            SyncOpeningButtonToPlayerCast(castGUID, spellID)
            return
        elseif unit == "player" and (
            event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
        ) then
            if pendingOpeningButton and IsAcceptedOpeningCastEvent(pendingOpeningButton, castGUID, spellID) then
                local button = pendingOpeningButton
                SetOpeningBarProgress(button, 1)
                ClearButtonOpening(button, true)
                LockButtonAfterOpening(button)
            end
            return
        end
        RefreshSoon()
    end)
end

BagOpener.Attach()
