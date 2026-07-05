local _, ns = ...
ns.Mailbox = {}
local Mailbox = ns.Mailbox
local Database = ns.Database
local Utils = ns.Utils
local HelperPanel = ns.HelperPanel

local PANEL_WIDTH = 220
local PANEL_HEIGHT = 114
local ICON_SIZE = 28
local PANEL_BELOW_OFFSET_Y = -42
local FALLBACK_ATTACHMENT_LIMIT = 12
local SAVED_RECIPIENT_KEY = "galacticEquipmentMailRecipient"

local eventFrame
local panel
local hookedMailFrames = {}
local UpdatePanel

local function FormatNumber(value)
    value = tonumber(value) or 0
    if Utils and Utils.FormatNumber and value > 0 then
        return Utils.FormatNumber(value)
    end
    return tostring(math.floor(value + 0.5))
end

local function ApplyPanelTheme()
    if not panel then return end

    local theme = HelperPanel.ApplyShellTheme(panel)
    HelperPanel.SetTextureColor(panel.iconBg, theme.surfaceRaised)
    HelperPanel.SetTextureColor(panel.iconBorderTop, theme.accent, 0.85)
    HelperPanel.SetTextureColor(panel.iconBorderBottom, theme.accent, 0.85)
    HelperPanel.SetTextureColor(panel.iconBorderLeft, theme.accent, 0.85)
    HelperPanel.SetTextureColor(panel.iconBorderRight, theme.accent, 0.85)
    HelperPanel.SetFontColor(panel.body, theme.text)
    HelperPanel.SetFontColor(panel.detail, theme.muted)
end

Mailbox.ApplyTheme = ApplyPanelTheme

local function RefreshSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, UpdatePanel)
    else
        UpdatePanel()
    end
end

local function HookRefreshScript(frame, key, scriptType)
    if not frame or not frame.HookScript or hookedMailFrames[key] then return end

    frame:HookScript(scriptType, RefreshSoon)
    hookedMailFrames[key] = true
end

local function HookMailFrameRefreshes()
    HookRefreshScript(_G.MailFrameTab1, "MailFrameTab1OnClick", "OnClick")
    HookRefreshScript(_G.MailFrameTab2, "MailFrameTab2OnClick", "OnClick")
    HookRefreshScript(_G.InboxFrame, "InboxFrameOnShow", "OnShow")
    HookRefreshScript(_G.InboxFrame, "InboxFrameOnHide", "OnHide")
    HookRefreshScript(_G.SendMailFrame, "SendMailFrameOnShow", "OnShow")
    HookRefreshScript(_G.SendMailFrame, "SendMailFrameOnHide", "OnHide")
end

local function GetChestIcon()
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(Database.GALACTIC_EQUIPMENT_CHEST_ITEM_ID)
    elseif C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(Database.GALACTIC_EQUIPMENT_CHEST_ITEM_ID)
        return icon
    end
end

local function GetContainerItemID(itemInfo)
    if not itemInfo then return nil end
    if itemInfo.itemID then return itemInfo.itemID end
    return itemInfo.hyperlink and tonumber(itemInfo.hyperlink:match("item:(%d+)"))
end

local function GetContainerItemName(itemInfo)
    if not itemInfo then return nil end
    if itemInfo.itemName then return itemInfo.itemName end
    if itemInfo.name then return itemInfo.name end
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

local function IsGalacticEquipmentChest(itemInfo)
    local itemID = GetContainerItemID(itemInfo)
    if itemID == Database.GALACTIC_EQUIPMENT_CHEST_ITEM_ID then
        return true
    end

    return GetContainerItemName(itemInfo) == Database.GALACTIC_EQUIPMENT_CHEST_NAME
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

local function ScanGalacticEquipmentChests()
    local state = {
        count = 0,
        locations = {},
    }

    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
        return state
    end

    for _, bagID in ipairs(GetPlayerBagIDs()) do
        local slots = tonumber(C_Container.GetContainerNumSlots(bagID)) or 0
        for slot = 1, slots do
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
            if IsGalacticEquipmentChest(itemInfo) then
                local stackCount = tonumber(itemInfo.stackCount) or 1
                state.count = state.count + stackCount
                if not itemInfo.isLocked then
                    state.locations[#state.locations + 1] = {
                        bagID = bagID,
                        slot = slot,
                        stackCount = stackCount,
                    }
                end
            end
        end
    end

    return state
end

local function IsMailboxShown()
    local mailFrame = _G.MailFrame
    return mailFrame and mailFrame:IsShown()
end

local function IsInboxFrameShown()
    local inboxFrame = _G.InboxFrame
    return inboxFrame and inboxFrame:IsShown()
end

local function IsSendMailFrameShown()
    if IsInboxFrameShown() then return false end

    local mailFrame = _G.MailFrame
    if _G.PanelTemplates_GetSelectedTab and mailFrame then
        local selectedTab = _G.PanelTemplates_GetSelectedTab(mailFrame)
        if selectedTab then return selectedTab == 2 end
    end
    if mailFrame and mailFrame.selectedTab then
        return mailFrame.selectedTab == 2
    end

    local sendMailFrame = _G.SendMailFrame
    return sendMailFrame and sendMailFrame:IsShown()
end

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function GetSavedRecipient()
    local settings = WarbandRatingsDB and WarbandRatingsDB.settings
    return settings and settings[SAVED_RECIPIENT_KEY] or ""
end

local function SaveRecipient(recipient)
    recipient = Trim(recipient)
    if recipient == "" then return end

    if Database and Database.SetSetting then
        Database.SetSetting(SAVED_RECIPIENT_KEY, recipient)
    elseif WarbandRatingsDB and WarbandRatingsDB.settings then
        WarbandRatingsDB.settings[SAVED_RECIPIENT_KEY] = recipient
    end
end

local function GetRecipientEditBox()
    local sendMailFrame = _G.SendMailFrame
    return _G.SendMailNameEditBox
        or (sendMailFrame and (
            sendMailFrame.NameEditBox
            or sendMailFrame.nameEditBox
            or sendMailFrame.RecipientEditBox
            or sendMailFrame.recipientEditBox
        ))
end

local function GetRecipientText()
    local editBox = GetRecipientEditBox()
    return editBox and editBox.GetText and Trim(editBox:GetText()) or ""
end

local function RestoreSavedRecipientIfEmpty()
    if not IsSendMailFrameShown() then return end

    local editBox = GetRecipientEditBox()
    if not editBox or not editBox.GetText or not editBox.SetText then return end
    if Trim(editBox:GetText()) ~= "" then return end

    local recipient = GetSavedRecipient()
    if recipient ~= "" then
        editBox:SetText(recipient)
    end
end

local function SaveRecipientFromField()
    SaveRecipient(GetRecipientText())
end

local function HookRecipientEditBox()
    local editBox = GetRecipientEditBox()
    if not editBox or hookedMailFrames.SendMailRecipientEditBox then return end

    if editBox.HookScript then
        editBox:HookScript("OnTextChanged", function()
            SaveRecipientFromField()
            RefreshSoon()
        end)
    end
    hookedMailFrames.SendMailRecipientEditBox = true
end

local function IsMailboxHelperHidden()
    local settings = WarbandRatingsDB and WarbandRatingsDB.settings
    return settings and settings.hideGalacticEquipmentMailHelper
end

local function GetAttachmentLimit()
    return tonumber(_G.ATTACHMENTS_MAX_SEND or _G.MAX_SEND_MAIL_ITEMS) or FALLBACK_ATTACHMENT_LIMIT
end

local function HasSendMailAttachment(index)
    if _G.HasSendMailItem then
        return _G.HasSendMailItem(index)
    end

    if _G.GetSendMailItem then
        local name = _G.GetSendMailItem(index)
        return name ~= nil
    end

    if _G.C_Mail and _G.C_Mail.GetSendMailItem then
        local item = _G.C_Mail.GetSendMailItem(index)
        return item ~= nil
    end

    return false
end

local function GetSendMailAttachmentInfo(index)
    if _G.GetSendMailItem then
        local name, itemID, _, count = _G.GetSendMailItem(index)
        if name then
            return {
                itemID = tonumber(itemID),
                name = name,
                count = tonumber(count) or 1,
            }
        end
    end

    if _G.C_Mail and _G.C_Mail.GetSendMailItem then
        local item = _G.C_Mail.GetSendMailItem(index)
        if item then
            return {
                itemID = item.itemID,
                name = item.itemName or item.name,
                hyperlink = item.hyperlink or item.itemLink,
                count = tonumber(item.stackCount or item.count or item.quantity) or 1,
            }
        end
    end
end

local function GetEmptyAttachmentSlots()
    local emptySlots = {}
    for index = 1, GetAttachmentLimit() do
        if not HasSendMailAttachment(index) then
            emptySlots[#emptySlots + 1] = index
        end
    end
    return emptySlots
end

local function CountAttachedGalacticEquipmentChests()
    local attachedCount = 0
    local attachedSlotCount = 0
    for index = 1, GetAttachmentLimit() do
        local itemInfo = GetSendMailAttachmentInfo(index)
        if itemInfo and IsGalacticEquipmentChest(itemInfo) then
            attachedCount = attachedCount + (tonumber(itemInfo.count) or 1)
            attachedSlotCount = attachedSlotCount + 1
        end
    end
    return attachedCount, attachedSlotCount
end

local function CountAttachableBoxes(locations, slotCount)
    local count = 0
    local limit = math.min(#locations, slotCount)
    for index = 1, limit do
        count = count + (tonumber(locations[index].stackCount) or 1)
    end
    return count
end

local function CursorHasPickedUpItem()
    return _G.CursorHasItem and _G.CursorHasItem()
end

local function CanUseContainerItemForMail()
    return (C_Container and C_Container.UseContainerItem) or _G.UseContainerItem
end

local function CanClickSendMailButton()
    local button = _G.SendMailMailButton
    return button and (not button.IsEnabled or button:IsEnabled())
end

local function GetMailState()
    if IsMailboxHelperHidden() or not IsMailboxShown() then return nil end

    local chests = ScanGalacticEquipmentChests()
    local sendMailShown = IsSendMailFrameShown()
    local emptySlots = sendMailShown and GetEmptyAttachmentSlots() or {}
    local attachedCount = 0
    local attachedSlotCount = 0
    if sendMailShown then
        attachedCount, attachedSlotCount = CountAttachedGalacticEquipmentChests()
    end
    if chests.count <= 0 and attachedCount <= 0 then return nil end

    local state = {
        chests = chests,
        emptySlots = emptySlots,
        emptySlotCount = #emptySlots,
        sendMailShown = sendMailShown,
        cursorHasItem = CursorHasPickedUpItem(),
        attachedCount = attachedCount,
        attachedSlotCount = attachedSlotCount,
        recipient = GetRecipientText(),
        savedRecipient = GetSavedRecipient(),
    }

    state.attachableCount = CountAttachableBoxes(chests.locations, state.emptySlotCount)
    state.canAttach = state.sendMailShown
        and not state.cursorHasItem
        and state.emptySlotCount > 0
        and #chests.locations > 0
        and CanUseContainerItemForMail()
    state.shouldSend = state.sendMailShown
        and state.attachedCount > 0
        and (state.emptySlotCount <= 0 or state.attachableCount <= 0)
    state.canSend = state.shouldSend
        and state.recipient ~= ""
        and CanClickSendMailButton()
    return state
end

local function OpenSendMailTab()
    if IsSendMailFrameShown() then return true end

    local mailFrameTab = _G.MailFrameTab2
    local mailFrameTabOnClick = _G.MailFrameTab_OnClick
    local mailFrame = _G.MailFrame
    local sendMailFrame = _G.SendMailFrame
    local inboxFrame = _G.InboxFrame
    if mailFrameTab and mailFrameTab.Click then
        mailFrameTab:Click()
    elseif mailFrameTabOnClick and mailFrameTab then
        mailFrameTabOnClick(mailFrameTab)
    elseif mailFrame and sendMailFrame and inboxFrame then
        if _G.PanelTemplates_SetTab then
            _G.PanelTemplates_SetTab(mailFrame, 2)
        end
        inboxFrame:Hide()
        sendMailFrame:Show()
    end

    HookRecipientEditBox()
    RestoreSavedRecipientIfEmpty()
    return IsSendMailFrameShown()
end

local function GetStaticPopupText(dialogName)
    local text = _G[dialogName .. "Text"]
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

local function IsGalacticEquipmentRefundPopup(dialogName)
    local text = GetStaticPopupText(dialogName)
    text = text and string.lower(text) or ""
    if not text:find("non-refundable", 1, true) then
        return false
    end

    local itemName = GetStaticPopupItemName(dialogName)
    return not itemName or itemName == "" or itemName == Database.GALACTIC_EQUIPMENT_CHEST_NAME
end

local function ConfirmGalacticEquipmentRefundPopup()
    local dialogCount = tonumber(_G.STATICPOPUP_NUMDIALOGS) or 4
    for index = 1, dialogCount do
        local dialogName = "StaticPopup" .. index
        local dialog = _G[dialogName]
        if dialog and dialog:IsShown() and IsGalacticEquipmentRefundPopup(dialogName) then
            local button = _G[dialogName .. "Button1"]
            if button and (not button.IsEnabled or button:IsEnabled()) then
                button:Click()
                return true
            end
        end
    end
    return false
end

local function UseContainerItemForMail(location)
    if not location or CursorHasPickedUpItem() then return false end

    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(location.bagID, location.slot)
    elseif _G.UseContainerItem then
        _G.UseContainerItem(location.bagID, location.slot)
    else
        return false
    end

    ConfirmGalacticEquipmentRefundPopup()
    return true
end

local function SendCurrentMail()
    SaveRecipientFromField()

    local state = GetMailState()
    if not state or not state.canSend then
        RestoreSavedRecipientIfEmpty()
        RefreshSoon()
        return
    end

    local button = _G.SendMailMailButton
    if button and button.Click then
        button:Click()
    end
    RefreshSoon()
end

local function AttachGalacticEquipmentChests()
    if not IsSendMailFrameShown() then
        OpenSendMailTab()
        RefreshSoon()
        return
    end

    local state = GetMailState()
    if state and state.shouldSend then
        SendCurrentMail()
        return
    end

    if not state or not state.canAttach then
        RefreshSoon()
        return
    end

    local attached = 0
    for index, location in ipairs(state.chests.locations) do
        if not state.emptySlots[index] then break end

        if UseContainerItemForMail(location) then
            attached = attached + 1
        else
            break
        end
    end

    ConfirmGalacticEquipmentRefundPopup()
    RefreshSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, ConfirmGalacticEquipmentRefundPopup)
        C_Timer.After(attached > 0 and 0.35 or 0.15, UpdatePanel)
    end
end

local function ShowTooltip(self)
    local state = GetMailState()
    if not state then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Warband Ratings")
    if not state.sendMailShown then
        GameTooltip:AddLine("Opens the Send Mail tab so you can attach Galactic Equipment Chests.", 1, 1, 1, true)
    elseif state.shouldSend then
        GameTooltip:AddLine("Sends the current mail with attached Galactic Equipment Chests.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Attaches Galactic Equipment Chests from your bags to empty mail slots.", 1, 1, 1, true)
    end
    GameTooltip:AddDoubleLine("In bags:", FormatNumber(state.chests.count), 1, 0.82, 0, 1, 1, 1)
    if state.sendMailShown then
        GameTooltip:AddDoubleLine("Attached:", FormatNumber(state.attachedCount), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Empty slots:", FormatNumber(state.emptySlotCount), 1, 0.82, 0, 1, 1, 1)
    end
    if state.cursorHasItem then
        GameTooltip:AddLine("Clear your cursor before attaching boxes.", 0.8, 0.8, 0.8, true)
    elseif state.shouldSend and state.recipient == "" then
        GameTooltip:AddLine("Enter a recipient before sending.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:Show()
end

local function EnsurePanel()
    local mailFrame = _G.MailFrame
    if panel or not mailFrame then return end

    HookMailFrameRefreshes()
    HookRecipientEditBox()
    RestoreSavedRecipientIfEmpty()

    panel = HelperPanel.CreateShell("WarbandRatingsMailboxHelperFrame", PANEL_WIDTH, PANEL_HEIGHT, "Warband Ratings")
    panel:SetFrameLevel((mailFrame:GetFrameLevel() or 0) + 10)
    panel:SetScript("OnEnter", ShowTooltip)
    panel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
    panel.button:SetScript("OnClick", AttachGalacticEquipmentChests)
    panel.button:SetScript("OnEnter", ShowTooltip)
    panel.button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ApplyPanelTheme()
end

local function PositionPanel()
    local mailFrame = _G.MailFrame
    if not panel or not mailFrame then return end

    panel:ClearAllPoints()
    panel:SetPoint("TOP", mailFrame, "BOTTOM", 0, PANEL_BELOW_OFFSET_Y)
    HelperPanel.SnapFrameToPixelGrid(panel)
    panel:SetFrameLevel((mailFrame:GetFrameLevel() or 0) + 10)
end

UpdatePanel = function()
    if not panel then return end

    local state = GetMailState()
    panel.state = state
    if not state then
        panel:Hide()
        return
    end

    PositionPanel()
    panel.icon:SetTexture(GetChestIcon())
    panel:Show()
    ApplyPanelTheme()

    if state.attachedCount > 0 then
        panel.body:SetText(FormatNumber(state.chests.count) .. " in bags, " .. FormatNumber(state.attachedCount) .. " attached.")
    else
        panel.body:SetText(FormatNumber(state.chests.count) .. " " .. Database.GALACTIC_EQUIPMENT_CHEST_NAME .. " in bags.")
    end

    if not state.sendMailShown then
        panel.detail:SetText("Switch to Send Mail to attach them.")
        panel.button:SetText("Open Send Mail")
        panel.button:Enable()
    elseif state.cursorHasItem then
        panel.detail:SetText("Clear your cursor before attaching boxes.")
        panel.button:SetText("Cursor busy")
        panel.button:Disable()
    elseif state.shouldSend then
        panel.button:SetText("Send Mail")
        if state.recipient == "" then
            panel.detail:SetText("Enter a recipient before sending.")
            panel.button:Disable()
        else
            panel.detail:SetText("Ready to send " .. FormatNumber(state.attachedCount) .. " attached boxes.")
            if state.canSend then
                panel.button:Enable()
            else
                panel.button:Disable()
            end
        end
    elseif state.emptySlotCount <= 0 then
        panel.detail:SetText("Mail attachment slots are full.")
        panel.button:SetText("No empty slots")
        panel.button:Disable()
    elseif state.attachableCount <= 0 then
        panel.detail:SetText("Waiting for bags to finish updating.")
        panel.button:SetText("No unlocked boxes")
        panel.button:Disable()
    else
        panel.detail:SetText("Fills up to " .. FormatNumber(state.emptySlotCount) .. " empty attachment slots.")
        panel.button:SetText("Attach " .. FormatNumber(state.attachableCount))
        panel.button:Enable()
    end
end

function Mailbox.Refresh()
    if IsMailboxShown() then
        HookMailFrameRefreshes()
        HookRecipientEditBox()
        RestoreSavedRecipientIfEmpty()
        EnsurePanel()
    end
    RefreshSoon()
end

function Mailbox.Attach()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("MAIL_CLOSED")
    eventFrame:RegisterEvent("MAIL_SEND_INFO_UPDATE")
    eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
    eventFrame:RegisterEvent("MAIL_FAILED")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MAIL_CLOSED" then
            if panel then panel:Hide() end
            return
        end

        HookMailFrameRefreshes()
        HookRecipientEditBox()
        if event == "MAIL_SEND_SUCCESS" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, RestoreSavedRecipientIfEmpty)
                C_Timer.After(0.7, RestoreSavedRecipientIfEmpty)
            else
                RestoreSavedRecipientIfEmpty()
            end
        else
            RestoreSavedRecipientIfEmpty()
        end
        EnsurePanel()
        RefreshSoon()
    end)
end

Mailbox.Attach()
