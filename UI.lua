local _, ns = ...
ns.UI = {}
local UI = ns.UI
local Database = ns.Database
local Utils = ns.Utils

local WINDOW_WIDTH = 780
local WINDOW_HEIGHT = 450
local SUBROW_HEIGHT = 30
local HEADER_HEIGHT = 28
local ICON_SIZE = 22
local SPEC_ICON_SIZE = 20
local COL_NAME_WIDTH = 220
local COL_RATING_WIDTH = 80
local SETTINGS_WIDTH = 220
local COL_SPEC_RATING_WIDTH = 100

local mainFrame, settingsPanel, scrollFrame, scrollChild, headerRow
local rowFrames = {}
local minimapButton

------------------------------------------------------------
-- Minimap Button
------------------------------------------------------------
local MINIMAP_ICON = 2022761 -- Achievement_RankedPvP_06 (Elite)

local function UpdateMinimapButtonPosition(btn)
    local angle = math.rad(Database.GetSettings().minimapPos or 220)
    local radius = (Minimap:GetWidth() / 2) + 10
    local x = radius * math.cos(angle)
    local y = radius * math.sin(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function UI.CreateMinimapButton()
    if minimapButton then return end

    minimapButton = CreateFrame("Button", "WarbandRatingsMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetMovable(true)
    minimapButton:SetClampedToScreen(true)

    local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local background = minimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("CENTER", 0, 1)

    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture(MINIMAP_ICON)
    icon:SetPoint("CENTER", 0, 1)

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    minimapButton:SetScript("OnClick", function()
        UI.Toggle()
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Warband Ratings")
        GameTooltip:AddLine("Click to toggle window", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Dragging around minimap
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(btn)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            Database.SetSetting("minimapPos", angle)
            UpdateMinimapButtonPosition(btn)
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    UpdateMinimapButtonPosition(minimapButton)

    if Database.GetSettings().hideMinimapIcon then
        minimapButton:Hide()
    end
end

function UI.UpdateMinimapVisibility()
    if not minimapButton then return end
    if Database.GetSettings().hideMinimapIcon then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
end

local compartmentRegistered = false

function UI.UpdateCompartmentVisibility()
    if not AddonCompartmentFrame then return end
    if Database.GetSettings().hideCompartmentIcon then
        if compartmentRegistered then
            local addons = AddonCompartmentFrame.registeredAddons
            if addons then
                for i = #addons, 1, -1 do
                    if addons[i].text == "Warband Ratings" then
                        table.remove(addons, i)
                    end
                end
            end
            AddonCompartmentFrame:UpdateDisplay()
            compartmentRegistered = false
        end
    else
        if not compartmentRegistered then
            AddonCompartmentFrame:RegisterAddon({
                text = "Warband Ratings",
                icon = 2022761,
                func = WarbandRatings_OnAddonCompartmentClick,
                funcOnEnter = WarbandRatings_OnAddonCompartmentEnter,
                funcOnLeave = WarbandRatings_OnAddonCompartmentLeave,
            })
            compartmentRegistered = true
        end
    end
end

------------------------------------------------------------
-- Main Window
------------------------------------------------------------
function UI.CreateMainFrame()
    if mainFrame then return mainFrame end

    mainFrame = CreateFrame("Frame", "WarbandRatingsMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetClampedToScreen(true)
    mainFrame:Hide()

    mainFrame.TitleText:SetText("Warband Ratings")

    -- Close with Escape: insert into the special frames table
    tinsert(UISpecialFrames, "WarbandRatingsMainFrame")

    -- Cogwheel button for settings
    local cogBtn = CreateFrame("Button", nil, mainFrame)
    cogBtn:SetSize(24, 24)
    cogBtn:SetPoint("RIGHT", mainFrame.CloseButton, "LEFT", -4, 0)
    cogBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    cogBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    cogBtn:SetScript("OnClick", function()
        UI.ToggleSettings()
    end)

    UI.CreateScrollArea()
    UI.CreateSettingsPanel()

    return mainFrame
end

------------------------------------------------------------
-- Scroll Area
------------------------------------------------------------
function UI.CreateScrollArea()
    -- Header row (above scroll)
    headerRow = CreateFrame("Frame", nil, mainFrame)
    headerRow:SetPoint("TOPLEFT", mainFrame.InsetBg or mainFrame, "TOPLEFT", 8, -8)
    headerRow:SetPoint("TOPRIGHT", mainFrame.InsetBg or mainFrame, "TOPRIGHT", -8, -8)
    headerRow:SetHeight(HEADER_HEIGHT)

    scrollFrame = CreateFrame("ScrollFrame", "WarbandRatingsScrollFrame", mainFrame)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -8, 10)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1) -- dynamically resized
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = math.max(scrollChild:GetHeight() - self:GetHeight(), 0)
        local newScroll = math.max(0, math.min(current - delta * SUBROW_HEIGHT, maxScroll))
        self:SetVerticalScroll(newScroll)
    end)

    -- Resize scrollChild width when scrollFrame changes size
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        scrollChild:SetWidth(w)
    end)
end

------------------------------------------------------------
-- Settings Panel
------------------------------------------------------------
function UI.CreateSettingsPanel()
    settingsPanel = CreateFrame("Frame", nil, mainFrame, "InsetFrameTemplate3" )
    settingsPanel:SetWidth(SETTINGS_WIDTH)
    settingsPanel:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", -1, 0)
    settingsPanel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", -1, 0)
    settingsPanel:Hide()

    local title = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("Settings")

    local yOffset = -38
    UI.CreateCheckbox(settingsPanel, "Max level only", "hideNonMaxLevel", yOffset)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPanel, "Hide characters with no rating", "hideNoRating", yOffset)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPanel, "Hide brackets with no rating", "hideEmptyColumns", yOffset)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPanel, "Hide minimap icon", "hideMinimapIcon", yOffset, function()
        UI.UpdateMinimapVisibility()
    end)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPanel, "Hide compartment icon", "hideCompartmentIcon", yOffset, function()
        UI.UpdateCompartmentVisibility()
    end)
end

function UI.CreateCheckbox(parent, label, settingKey, yOffset, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, yOffset)
    cb.Text:SetText(label)
    cb.Text:SetFontObject("GameFontNormalSmall")

    cb:SetChecked(Database.GetSettings()[settingKey])
    cb:SetScript("OnClick", function(self)
        Database.SetSetting(settingKey, self:GetChecked())
        UI.RefreshTable()
        if onChange then onChange() end
    end)
end

function UI.ToggleSettings()
    if settingsPanel:IsShown() then
        settingsPanel:Hide()
    else
        settingsPanel:Show()
    end
end

------------------------------------------------------------
-- Table Rendering
------------------------------------------------------------
local function ClearRows()
    for _, row in ipairs(rowFrames) do
        row:Hide()
    end
end

local function GetOrCreateRow(index)
    if rowFrames[index] then
        rowFrames[index]:Show()
        return rowFrames[index]
    end
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetHeight(SUBROW_HEIGHT)
    rowFrames[index] = row
    return row
end

local function StripRow(row)
    -- Remove old child regions to avoid stale textures/fontstrings
    if row.cells then
        for _, cell in ipairs(row.cells) do
            cell:Hide()
        end
    end
    row.cells = {}
end

local function ColWidth(col)
    if Database.IsSpecColumn(col) then return COL_SPEC_RATING_WIDTH end
    return COL_RATING_WIDTH
end

function UI.RefreshTable()
    if not mainFrame or not mainFrame:IsShown() then return end
    ClearRows()

    local groups = Database.GetFilteredCharacterGroups()
    local columns = Database.GetVisibleColumns(groups)

    -- Build header
    if headerRow.cells then
        for _, c in ipairs(headerRow.cells) do c:Hide() end
    end
    headerRow.cells = {}

    local hx = ICON_SIZE + 4
    do
        local fs = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", headerRow, "LEFT", hx, 0)
        fs:SetWidth(COL_NAME_WIDTH)
        fs:SetJustifyH("LEFT")
        fs:SetText("Character")
        fs:Show()
        headerRow.cells[#headerRow.cells + 1] = fs
        hx = hx + COL_NAME_WIDTH
    end
    for _, col in ipairs(columns) do
        local w = ColWidth(col)
        local fs = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", headerRow, "LEFT", hx, 0)
        fs:SetWidth(w)
        fs:SetJustifyH("CENTER")
        fs:SetText(col.label)
        fs:Show()
        headerRow.cells[#headerRow.cells + 1] = fs
        hx = hx + w
    end

    -- Empty state
    if #groups == 0 then
        local row = GetOrCreateRow(1)
        StripRow(row)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        row:SetHeight(SUBROW_HEIGHT)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        fs:SetPoint("LEFT", row, "LEFT", 10, 0)
        fs:SetWidth(400)
        fs:SetText("No characters recorded yet. Log in on your characters to populate data.")
        fs:Show()
        row.cells[#row.cells + 1] = fs
        scrollChild:SetHeight(SUBROW_HEIGHT)
        return
    end

    local rowIndex = 0
    local yOff = 0
    for charIdx, grp in ipairs(groups) do
        local charData = grp.charData

        -- Only expand to subrows if at least one spec column has a rating
        -- Build list of specs that have a rating in any spec column
        local ratedSpecs = {}
        for _, specID in ipairs(grp.specs) do
            local specRatings = charData.specRatings and charData.specRatings[specID]
            if specRatings then
                for _, col in ipairs(columns) do
                    if Database.IsSpecColumn(col) and not Utils.IsEmptyRating(specRatings[col.key]) then
                        ratedSpecs[#ratedSpecs + 1] = specID
                        break
                    end
                end
            end
        end

        local numSpecs = math.max(#ratedSpecs, 1)
        local rowHeight = numSpecs * SUBROW_HEIGHT

        rowIndex = rowIndex + 1
        local row = GetOrCreateRow(rowIndex)
        StripRow(row)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOff)
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

        -- Alternating background per character
        if not row.bg then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
        end
        if charIdx % 2 == 0 then
            row.bg:SetColorTexture(1, 1, 1, 0.05)
        else
            row.bg:SetColorTexture(0, 0, 0, 0.15)
        end
        row.bg:Show()

        -- Class icon (vertically centered)
        local classTexture, classCoords = Utils.GetClassIcon(charData.classFilename)
        if classTexture then
            local ico = row:CreateTexture(nil, "ARTWORK")
            ico:SetSize(ICON_SIZE, ICON_SIZE)
            ico:SetPoint("LEFT", row, "LEFT", 0, 0)
            ico:SetTexture(classTexture)
            if classCoords then ico:SetTexCoord(unpack(classCoords)) end
            ico:Show()
            row.cells[#row.cells + 1] = ico
        end

        local nameX = ICON_SIZE + 4

        -- Character name-realm (vertically centered like class icon)
        local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFs:SetPoint("LEFT", row, "LEFT", nameX, 0)
        nameFs:SetWidth(COL_NAME_WIDTH)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetWordWrap(false)
        nameFs:SetNonSpaceWrap(false)
        local displayName = charData.level .. "  " .. charData.name .. "-" .. charData.realm
        local cr, cg, cb = Utils.GetClassColor(charData.classFilename)
        nameFs:SetTextColor(cr, cg, cb)
        nameFs:SetText(displayName)
        nameFs:Show()
        row.cells[#row.cells + 1] = nameFs

        -- Rating columns
        local colX = ICON_SIZE + 4 + COL_NAME_WIDTH
        for _, col in ipairs(columns) do
            local w = ColWidth(col)
            if Database.IsSpecColumn(col) then
                if #ratedSpecs > 0 then
                    -- Split cell: one sub-line per rated spec only
                    for specIdx, specID in ipairs(ratedSpecs) do
                        local specRatings = charData.specRatings and charData.specRatings[specID]
                        local val = specRatings and specRatings[col.key]
                        local subY = -(specIdx - 1) * SUBROW_HEIGHT

                        -- Spec icon (only if this column has a rating)
                        if not Utils.IsEmptyRating(val) then
                            local specIcon = Utils.GetSpecIcon(specID)
                            if specIcon then
                                local ico = row:CreateTexture(nil, "ARTWORK")
                                ico:SetSize(SPEC_ICON_SIZE, SPEC_ICON_SIZE)
                                local icoY = subY - (SUBROW_HEIGHT - SPEC_ICON_SIZE) / 2
                                ico:SetPoint("TOPLEFT", row, "TOPLEFT", colX + 2, icoY)
                                ico:SetTexture(specIcon)
                                ico:Show()
                                row.cells[#row.cells + 1] = ico
                            end
                        end

                        -- Rating text
                        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        local fsY = subY - (SUBROW_HEIGHT - 14) / 2
                        fs:SetPoint("TOPLEFT", row, "TOPLEFT", colX + SPEC_ICON_SIZE + 4, fsY)
                        fs:SetWidth(w - SPEC_ICON_SIZE - 6)
                        fs:SetJustifyH("CENTER")
                        fs:SetText(Utils.FormatRating(val))
                        fs:Show()
                        row.cells[#row.cells + 1] = fs
                    end
                else
                    -- No spec has a rating: show single centered hyphen (offset to align with spec rating text)
                    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    fs:SetPoint("LEFT", row, "LEFT", colX + SPEC_ICON_SIZE + 4, 0)
                    fs:SetWidth(w - SPEC_ICON_SIZE - 6)
                    fs:SetJustifyH("CENTER")
                    fs:SetText("-")
                    fs:Show()
                    row.cells[#row.cells + 1] = fs
                end
            else
                -- Global column: single value, vertically centered
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs:SetPoint("LEFT", row, "LEFT", colX, 0)
                fs:SetWidth(w)
                fs:SetJustifyH("CENTER")
                local val = charData.ratings and charData.ratings[col.key]
                fs:SetText(Utils.FormatRating(val))
                fs:Show()
                row.cells[#row.cells + 1] = fs
            end
            colX = colX + w
        end

        yOff = yOff + rowHeight
    end

    scrollChild:SetHeight(math.max(yOff, 1))
end

------------------------------------------------------------
-- Toggle / Show / Hide
------------------------------------------------------------
function UI.Toggle()
    local frame = UI.CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UI.RefreshTable()
    end
end

function UI.Show()
    local frame = UI.CreateMainFrame()
    frame:Show()
    UI.RefreshTable()
end

------------------------------------------------------------
-- PVP Tab Button
------------------------------------------------------------
local pvpButtonCreated = false

local function CreatePvPButton()
    if pvpButtonCreated then return end
    if not ConquestFrame then return end
    pvpButtonCreated = true

    local btn = CreateFrame("Button", "WarbandRatingsPvPButton", ConquestFrame, "UIPanelButtonTemplate")
    btn:SetSize(130, 22)
    btn:SetFrameStrata("HIGH")
    btn:SetPoint("BOTTOMRIGHT", PVPUIFrame, "BOTTOMRIGHT", -8, 4)
    btn:SetText("Warband Ratings")
    btn:SetScript("OnClick", function()
        UI.Toggle()
    end)
end

------------------------------------------------------------
-- M+ Tab Button (Mythic+ Dungeons)
------------------------------------------------------------
local mplusButtonCreated = false

local function CreateMPlusButton()
    if mplusButtonCreated then return end
    if not ChallengesFrame then return end
    mplusButtonCreated = true

    local btn = CreateFrame("Button", "WarbandRatingsMPlusButton", ChallengesFrame, "UIPanelButtonTemplate")
    btn:SetSize(130, 22)
    btn:SetFrameStrata("HIGH")
    btn:SetPoint("RIGHT", ChallengesFrame, "RIGHT", -8, -120)
    btn:SetText("Warband Ratings")
    btn:SetScript("OnClick", function()
        UI.Toggle()
    end)
end

------------------------------------------------------------
-- Attach Group Finder buttons (PvP + M+)
------------------------------------------------------------
function UI.AttachGroupFinderButtons()
    -- Try immediately if frames are already loaded
    CreatePvPButton()
    CreateMPlusButton()

    -- ADDON_LOADED fallback for load-on-demand addons
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, loadedAddon)
        if loadedAddon == "Blizzard_PVPUI" then
            CreatePvPButton()
        elseif loadedAddon == "Blizzard_ChallengesUI" then
            CreateMPlusButton()
        end
        if pvpButtonCreated and mplusButtonCreated then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)

    -- Extra fallback: hook PVEFrame show (opening Group Finder loads both)
    if PVEFrame then
        PVEFrame:HookScript("OnShow", function()
            C_Timer.After(0.1, function()
                CreatePvPButton()
                CreateMPlusButton()
            end)
        end)
    end
end

------------------------------------------------------------
-- Show with settings panel open
------------------------------------------------------------
function UI.ShowWithSettings()
    local frame = UI.CreateMainFrame()
    frame:Show()
    UI.RefreshTable()
    if not settingsPanel:IsShown() then
        settingsPanel:Show()
    end
end

------------------------------------------------------------
-- Built-in Addon Settings Panel
------------------------------------------------------------
function UI.CreateAddonSettingsPanel()
    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("Warband Ratings")
    title:SetTextColor(1, 1, 1)

    local titleDivider = panel:CreateTexture(nil, "ARTWORK")
    titleDivider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    titleDivider:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    titleDivider:SetHeight(8)
    titleDivider:SetTexture("Interface\\COMMON\\UI-TooltipDivider-Transparent")

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetPoint("TOPLEFT", titleDivider, "BOTTOMLEFT", 0, -12)
    openButton:SetSize(200, 26)
    openButton:SetText("Open Warband Ratings")
    openButton:SetScript("OnClick", function()
        UI.ShowWithSettings()
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
            InterfaceOptionsFrame:Hide()
        end
    end)

    -- URL display popup (shared between buttons)
    local urlPopup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    urlPopup:SetSize(400, 80)
    urlPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    urlPopup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    urlPopup:SetFrameStrata("DIALOG")
    urlPopup:EnableMouse(true)
    urlPopup:Hide()

    local urlPopupTitle = urlPopup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    urlPopupTitle:SetPoint("TOP", urlPopup, "TOP", 0, -16)
    urlPopupTitle:SetText("Copy this URL (Ctrl+C)")

    local urlEditBox = CreateFrame("EditBox", nil, urlPopup, "InputBoxTemplate")
    urlEditBox:SetPoint("TOP", urlPopupTitle, "BOTTOM", 0, -8)
    urlEditBox:SetSize(360, 22)
    urlEditBox:SetAutoFocus(false)
    urlEditBox:SetScript("OnEscapePressed", function(self)
        urlPopup:Hide()
    end)
    urlEditBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    local urlCloseButton = CreateFrame("Button", nil, urlPopup, "UIPanelButtonTemplate")
    urlCloseButton:SetPoint("TOP", urlEditBox, "BOTTOM", 0, -8)
    urlCloseButton:SetSize(80, 22)
    urlCloseButton:SetText("Close")
    urlCloseButton:SetScript("OnClick", function()
        urlPopup:Hide()
    end)

    local function ShowURL(url, titleText)
        urlPopupTitle:SetText(titleText or "Copy this URL (Ctrl+C)")
        urlEditBox:SetText(url)
        urlPopup:Show()
        urlEditBox:SetFocus()
        urlEditBox:HighlightText()
    end

    -- Support section (anchored to bottom)
    local supportLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    supportLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 90)
    supportLabel:SetText("Support the Developer")

    local paypalButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    paypalButton:SetPoint("TOPLEFT", supportLabel, "BOTTOMLEFT", 0, -8)
    paypalButton:SetSize(180, 26)
    paypalButton:SetText("Buy me a coffee")
    paypalButton:SetScript("OnClick", function()
        ShowURL("https://paypal.me/NickDrw", "PayPal - Buy me a coffee (Ctrl+C to copy)")
    end)

    local paypalIcon = paypalButton:CreateTexture(nil, "ARTWORK")
    paypalIcon:SetSize(16, 16)
    paypalIcon:SetPoint("LEFT", paypalButton, "LEFT", 8, 0)
    paypalIcon:SetTexture("Interface\\AddOns\\WarbandRatings\\media\\paypal")
    paypalButton.Text:SetPoint("CENTER", paypalButton, "CENTER", 8, 0)

    local patreonButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    patreonButton:SetPoint("LEFT", paypalButton, "RIGHT", 12, 0)
    patreonButton:SetSize(180, 26)
    patreonButton:SetText("Support me on Patreon")
    patreonButton:SetScript("OnClick", function()
        ShowURL("https://patreon.com/NickDrew", "Patreon - Support me (Ctrl+C to copy)")
    end)

    local patreonIcon = patreonButton:CreateTexture(nil, "ARTWORK")
    patreonIcon:SetSize(16, 16)
    patreonIcon:SetPoint("LEFT", patreonButton, "LEFT", 8, 0)
    patreonIcon:SetTexture("Interface\\AddOns\\WarbandRatings\\media\\patreon")
    patreonButton.Text:SetPoint("CENTER", patreonButton, "CENTER", 8, 0)

    local curseforgeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    curseforgeButton:SetPoint("LEFT", patreonButton, "RIGHT", 12, 0)
    curseforgeButton:SetSize(180, 26)
    curseforgeButton:SetText("View on CurseForge")
    curseforgeButton:SetScript("OnClick", function()
        ShowURL("https://www.curseforge.com/wow/addons/warband-ratings", "CurseForge - Share with friends! (Ctrl+C to copy)")
    end)

    local curseforgeIcon = curseforgeButton:CreateTexture(nil, "ARTWORK")
    curseforgeIcon:SetSize(16, 16)
    curseforgeIcon:SetPoint("LEFT", curseforgeButton, "LEFT", 8, 0)
    curseforgeIcon:SetTexture("Interface\\AddOns\\WarbandRatings\\media\\curseforge")
    curseforgeButton.Text:SetPoint("CENTER", curseforgeButton, "CENTER", 8, 0)

    local githubButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    githubButton:SetPoint("TOPLEFT", paypalButton, "BOTTOMLEFT", 0, -8)
    githubButton:SetSize(180, 26)
    githubButton:SetText("Project on GitHub")
    githubButton:SetScript("OnClick", function()
        ShowURL("https://github.com/Nickdrw/WarbandRatings", "GitHub - Project page (Ctrl+C to copy)")
    end)

    local githubIcon = githubButton:CreateTexture(nil, "ARTWORK")
    githubIcon:SetSize(16, 16)
    githubIcon:SetPoint("LEFT", githubButton, "LEFT", 8, 0)
    githubIcon:SetTexture("Interface\\AddOns\\WarbandRatings\\media\\github")
    githubButton.Text:SetPoint("CENTER", githubButton, "CENTER", 8, 0)

    return panel
end

function UI.RegisterAddonSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = UI.CreateAddonSettingsPanel()
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Warband Ratings")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        local panel = UI.CreateAddonSettingsPanel()
        panel.name = "Warband Ratings"
        InterfaceOptions_AddCategory(panel)
    end
end
