local _, ns = ...
ns.HonorAlert = {}
local HonorAlert = ns.HonorAlert
local Database = ns.Database
local Utils = ns.Utils

local HONOR_CURRENCY_ID = 1792
local ICON_SIZE = 64
local CHAT_ALERT_DEBOUNCE = 0.75

local eventFrame
local iconFrame
local initialized = false
local previousHonor
local currentHonor = 0
local chatAlertPending = false
local pendingChatNotice
local deferredPVPNotice

local function GetThreshold()
    local settings = WarbandRatingsDB and WarbandRatingsDB.settings
    return Database.NormalizeHonorAlertThreshold(settings and settings.honorAlertThreshold)
end

local function GetHonorInfo()
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    return C_CurrencyInfo.GetCurrencyInfo(HONOR_CURRENCY_ID)
end

local function FormatExactNumber(value)
    local formatted = tostring(math.floor((tonumber(value) or 0) + 0.5))
    while true do
        local updated, replacements = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        formatted = updated
        if replacements == 0 then return formatted end
    end
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

local function IsPlayerInInstancedPVP()
    if not _G.IsInInstance then return false end
    local inInstance, instanceType = _G.IsInInstance()
    return inInstance and (instanceType == "arena" or instanceType == "pvp")
end

local function SetPosition(frame)
    local settings = WarbandRatingsDB and WarbandRatingsDB.settings
    local position = settings and settings.honorAlertPosition

    frame:ClearAllPoints()
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        frame:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function SavePosition(frame)
    local centerX, centerY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    if not centerX or not centerY or not parentCenterX or not parentCenterY then return end

    Database.SetSetting("honorAlertPosition", {
        x = math.floor(centerX - parentCenterX + 0.5),
        y = math.floor(centerY - parentCenterY + 0.5),
    })
    SetPosition(frame)
end

local function EnsureIconFrame()
    if iconFrame then return iconFrame end

    local frame = CreateFrame("Button", "WarbandRatingsHonorAlertFrame", UIParent)
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("RightButtonUp")
    frame:Hide()

    local bounceFrame = CreateFrame("Frame", nil, frame)
    bounceFrame:SetAllPoints(frame)

    frame.icon = bounceFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(bounceFrame)

    frame.amount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.amount:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.amount:SetTextColor(1, 0.08, 0.08)
    frame.amount:SetShadowColor(0, 0, 0, 1)
    frame.amount:SetShadowOffset(1, -1)

    frame.bounce = bounceFrame:CreateAnimationGroup()
    local bounceUp = frame.bounce:CreateAnimation("Translation")
    bounceUp:SetOffset(0, 9)
    bounceUp:SetDuration(0.34)
    bounceUp:SetSmoothing("OUT")
    bounceUp:SetOrder(1)
    local bounceDown = frame.bounce:CreateAnimation("Translation")
    bounceDown:SetOffset(0, -9)
    bounceDown:SetDuration(0.34)
    bounceDown:SetSmoothing("IN")
    bounceDown:SetOrder(2)
    frame.bounce:SetLooping("REPEAT")

    frame:SetScript("OnDragStart", function(self)
        if not IsPlayerInCombat() and not IsPlayerInInstance() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" then return end
        Database.SetSetting("hideHonorAlertIcon", true)
        HonorAlert.Refresh()
        local UI = ns.UI
        if UI and UI.RefreshSettingsCheckboxes then
            UI.RefreshSettingsCheckboxes()
        end
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Honor alert", 1, 0.15, 0.15)
        GameTooltip:AddLine(
            "Current: " .. tostring(currentHonor) .. " / Threshold: " .. tostring(GetThreshold()),
            1,
            1,
            1
        )
        GameTooltip:AddLine("Drag to move", 0.65, 0.65, 0.65)
        GameTooltip:AddLine("Right-click to hide", 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    SetPosition(frame)
    iconFrame = frame
    return frame
end

local function GetAlertLevel(quantity, threshold)
    if quantity >= threshold then
        return 3
    elseif threshold > 1000 and quantity >= threshold - 1000 then
        return 2
    elseif threshold > 2000 and quantity >= threshold - 2000 then
        return 1
    end
    return 0
end

local function GetThemedAddonName()
    local UI = ns.UI
    local theme = UI and UI.GetActiveTheme and UI.GetActiveTheme()
    local color = theme and theme.title
    if type(color) ~= "table" then return ns.DISPLAY_NAME end

    local red = math.floor(math.max(0, math.min(1, color[1] or 1)) * 255 + 0.5)
    local green = math.floor(math.max(0, math.min(1, color[2] or 1)) * 255 + 0.5)
    local blue = math.floor(math.max(0, math.min(1, color[3] or 1)) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", red, green, blue, ns.DISPLAY_NAME)
end

local function ShowChatNotice(quantity, threshold, level)
    local quantityText = FormatExactNumber(quantity)
    local thresholdText = Utils.FormatNumber(threshold)
    local addonName = GetThemedAddonName()
    local honorInfo = GetHonorInfo()
    local iconFileID = honorInfo and honorInfo.iconFileID
    local honorIcon = iconFileID and ("|T" .. tostring(iconFileID) .. ":16:16:0:0|t ") or ""
    local message
    local red, green, blue

    if level == 1 then
        message = honorIcon
            .. addonName
            .. ": "
            .. "You're approaching your "
            .. thresholdText
            .. " Honor limit. Consider spending Honor soon to avoid overcapping (currently: "
            .. quantityText
            .. ")."
        red, green, blue = 1, 0.9, 0.1
    elseif level == 2 then
        message = honorIcon
            .. addonName
            .. ": "
            .. "You're approaching your "
            .. thresholdText
            .. " Honor limit. Consider spending Honor soon to avoid overcapping (currently: "
            .. quantityText
            .. ")."
        red, green, blue = 1, 0.45, 0.05
    else
        message = honorIcon
            .. addonName
            .. ": "
            .. "You've reached your "
            .. thresholdText
            .. " Honor limit. Consider spending Honor to avoid overcapping (currently: "
            .. quantityText
            .. ")."
        red, green, blue = 1, 0.08, 0.08
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message, red, green, blue)
    elseif print then
        print(message)
    end
end

local function FinishChatAlert()
    chatAlertPending = false
    if pendingChatNotice then
        ShowChatNotice(
            pendingChatNotice.quantity,
            pendingChatNotice.threshold,
            pendingChatNotice.level
        )
        pendingChatNotice = nil
    end
end

local function QueueChatAlert(quantity, threshold, level)
    pendingChatNotice = {
        quantity = quantity,
        threshold = threshold,
        level = level,
    }

    if chatAlertPending then return end
    chatAlertPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(CHAT_ALERT_DEBOUNCE, FinishChatAlert)
    else
        FinishChatAlert()
    end
end

function HonorAlert.Refresh(event)
    if not initialized or not WarbandRatingsDB or not WarbandRatingsDB.settings then return end

    local info = GetHonorInfo()
    local quantity = tonumber(info and info.quantity)
    if quantity == nil then
        if iconFrame then
            if iconFrame.bounce then iconFrame.bounce:Stop() end
            iconFrame:Hide()
        end
        return
    end

    currentHonor = quantity
    local threshold = GetThreshold()
    local newAlertLevel = GetAlertLevel(currentHonor, threshold)
    local gainedHonor = previousHonor == nil or currentHonor > previousHonor
    local inInstancedPVP = IsPlayerInInstancedPVP()

    if inInstancedPVP and newAlertLevel > 0 and gainedHonor then
        deferredPVPNotice = {
            quantity = currentHonor,
            threshold = threshold,
            level = newAlertLevel,
        }
    elseif deferredPVPNotice then
        if newAlertLevel > 0 and gainedHonor then
            deferredPVPNotice = {
                quantity = currentHonor,
                threshold = threshold,
                level = newAlertLevel,
            }
        end
        if event == "PLAYER_ENTERING_WORLD" and not inInstancedPVP then
            QueueChatAlert(
                deferredPVPNotice.quantity,
                deferredPVPNotice.threshold,
                deferredPVPNotice.level
            )
            deferredPVPNotice = nil
        end
    elseif newAlertLevel > 0 and gainedHonor then
        QueueChatAlert(currentHonor, threshold, newAlertLevel)
    end
    previousHonor = currentHonor

    local settings = Database.GetSettings()
    if newAlertLevel < 3 or settings.hideHonorAlertIcon or IsPlayerInCombat() or IsPlayerInInstance() then
        if iconFrame then
            if iconFrame.bounce then iconFrame.bounce:Stop() end
            iconFrame:Hide()
        end
        return
    end

    local frame = EnsureIconFrame()
    if info and info.iconFileID then
        frame.icon:SetTexture(info.iconFileID)
    end
    frame.amount:SetText(FormatExactNumber(currentHonor))
    SetPosition(frame)
    frame:Show()
    if frame.bounce and not frame.bounce:IsPlaying() then
        frame.bounce:Play()
    end
end

function HonorAlert.Init()
    if initialized then return end
    initialized = true

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function(_, event)
        HonorAlert.Refresh(event)
    end)

    HonorAlert.Refresh()
end

function HonorAlert.GetThreshold()
    return GetThreshold()
end
