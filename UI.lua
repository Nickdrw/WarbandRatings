local _, ns = ...
ns.UI = {}
local UI = ns.UI
local Database = ns.Database
local DataCollection = ns.DataCollection
local History = ns.History
local Utils = ns.Utils

local WINDOW_WIDTH = 780 -- initial size, resized dynamically in RefreshTable
local WINDOW_HEIGHT = 450
local WINDOW_MIN_WIDTH = 400
local WINDOW_MIN_HEIGHT = 260
local WINDOW_SCREEN_MARGIN = 20
local RESIZE_GRIP_WIDTH = 72
local RESIZE_GRIP_HEIGHT = 10
local SURFACE_INSET_X = 0
local TABLE_CONTENT_PADDING_X = 8
local CONTENT_TOP_OFFSET = 26
local CONTENT_BOTTOM_INSET = 2
local TITLE_BAR_TOP_INSET = 1
local TITLE_BAR_HEIGHT = 22
local SUBROW_HEIGHT = 30
local HEADER_HEIGHT = 28
local ICON_SIZE = 22
local SPEC_ICON_SIZE = 20
local COL_NAME_WIDTH = 220
local COL_RATING_WIDTH = 80
local SETTINGS_WIDTH = 220
local SETTINGS_HEIGHT = WINDOW_HEIGHT
local SETTINGS_WINDOW_OFFSET = 8
local SETTINGS_TAB_WIDTH = 92
local SETTINGS_TAB_HEIGHT = 24
local FILTER_PRESET_BUTTON_WIDTH = 60
local FILTER_PRESET_BUTTON_HEIGHT = 22
local COL_SPEC_RATING_WIDTH = 100
local RATING_TEXT_HEIGHT = 14
local GRAPH_PANEL_HEIGHT = 210
local GRAPH_MARGIN_LEFT = 44
local GRAPH_MARGIN_RIGHT = 44
local GRAPH_MARGIN_TOP = 34
local GRAPH_MARGIN_BOTTOM = 48
local GRAPH_GAMES_LABEL_WIDTH = 126
local GRAPH_GAMES_LABEL_GAP = 12
local GRAPH_DETACHED_WIDTH = 980
local GRAPH_DETACHED_HEIGHT = 420
local GRAPH_POINT_SIZE = 5
local GRAPH_HOVER_POINT_SIZE = 7
local GRAPH_DEFAULT_VISIBLE_POINT_COUNT = 50
local GRAPH_MIN_VISIBLE_POINT_COUNT = 20
local GRAPH_MAX_VISIBLE_POINT_COUNT = 200
local GRAPH_VISIBLE_POINT_STEP = 5
local GRAPH_SCROLL_STEP = 5
local GRAPH_Y_AXIS_STEP = 500
local GRAPH_Y_AXIS_MINOR_STEP = GRAPH_Y_AXIS_STEP / 2
local HISTORY_GRAPH_ICON_SIZE = 14
local HISTORY_GRAPH_ICON_PADDING = 4
local HISTORY_SELECTED_ALPHA = 0.16
local MMR_GRAPH_R = 0.82
local MMR_GRAPH_G = 0.82
local MMR_GRAPH_B = 0.82
local THEME_BUTTON_WIDTH = 184
local THEME_BUTTON_HEIGHT = 26
local DEFAULT_THEME_KEY = "obsidian"
local HONOR_WARNING_THRESHOLD = 13000
local HONOR_CAP_THRESHOLD = 15000
local HONOR_WARNING_COLOR = { 1.000, 0.560, 0.120, 1 }
local HONOR_CAP_COLOR = { 1.000, 0.180, 0.140, 1 }

local THEME_PRESETS = {
    {
        key = "obsidian",
        label = "Obsidian",
        bg = { 0.035, 0.040, 0.050, 0.98 },
        surface = { 0.055, 0.064, 0.078, 0.96 },
        surfaceRaised = { 0.080, 0.092, 0.110, 0.98 },
        header = { 0.105, 0.120, 0.145, 0.95 },
        border = { 0.250, 0.285, 0.330, 0.88 },
        rowOdd = { 0.000, 0.000, 0.000, 0.18 },
        rowEven = { 1.000, 1.000, 1.000, 0.045 },
        rowHover = { 0.950, 0.720, 0.280, 0.13 },
        text = { 0.900, 0.930, 0.960, 1 },
        title = { 0.970, 0.820, 0.450, 1 },
        headerText = { 0.780, 0.840, 0.900, 1 },
        muted = { 0.560, 0.600, 0.650, 1 },
        grid = { 0.360, 0.400, 0.460, 0.25 },
        axis = { 0.620, 0.670, 0.740, 0.42 },
        accent = { 0.960, 0.720, 0.320, 1 },
        mmr = { 0.760, 0.800, 0.860, 1 },
    },
    {
        key = "stormglass",
        label = "Stormglass",
        bg = { 0.035, 0.048, 0.055, 0.98 },
        surface = { 0.055, 0.075, 0.086, 0.96 },
        surfaceRaised = { 0.075, 0.105, 0.120, 0.98 },
        header = { 0.095, 0.140, 0.155, 0.95 },
        border = { 0.220, 0.340, 0.380, 0.88 },
        rowOdd = { 0.000, 0.000, 0.000, 0.16 },
        rowEven = { 0.720, 0.920, 1.000, 0.035 },
        rowHover = { 0.300, 0.760, 0.900, 0.14 },
        text = { 0.890, 0.940, 0.955, 1 },
        title = { 0.500, 0.860, 0.960, 1 },
        headerText = { 0.760, 0.880, 0.920, 1 },
        muted = { 0.520, 0.640, 0.680, 1 },
        grid = { 0.300, 0.460, 0.500, 0.24 },
        axis = { 0.550, 0.720, 0.770, 0.42 },
        accent = { 0.380, 0.820, 0.930, 1 },
        mmr = { 0.800, 0.860, 0.900, 1 },
    },
    {
        key = "verdant",
        label = "Verdant",
        bg = { 0.035, 0.052, 0.045, 0.98 },
        surface = { 0.055, 0.080, 0.066, 0.96 },
        surfaceRaised = { 0.075, 0.105, 0.084, 0.98 },
        header = { 0.100, 0.145, 0.110, 0.95 },
        border = { 0.230, 0.360, 0.280, 0.88 },
        rowOdd = { 0.000, 0.000, 0.000, 0.17 },
        rowEven = { 0.710, 1.000, 0.780, 0.035 },
        rowHover = { 0.500, 0.850, 0.500, 0.13 },
        text = { 0.900, 0.955, 0.915, 1 },
        title = { 0.640, 0.920, 0.620, 1 },
        headerText = { 0.780, 0.900, 0.790, 1 },
        muted = { 0.560, 0.660, 0.580, 1 },
        grid = { 0.330, 0.500, 0.380, 0.24 },
        axis = { 0.570, 0.760, 0.610, 0.42 },
        accent = { 0.620, 0.900, 0.540, 1 },
        mmr = { 0.820, 0.860, 0.800, 1 },
    },
    {
        key = "ember",
        label = "Ember",
        bg = { 0.055, 0.040, 0.038, 0.98 },
        surface = { 0.080, 0.058, 0.052, 0.96 },
        surfaceRaised = { 0.112, 0.078, 0.066, 0.98 },
        header = { 0.150, 0.092, 0.072, 0.95 },
        border = { 0.390, 0.250, 0.190, 0.88 },
        rowOdd = { 0.000, 0.000, 0.000, 0.17 },
        rowEven = { 1.000, 0.740, 0.520, 0.035 },
        rowHover = { 0.940, 0.490, 0.300, 0.13 },
        text = { 0.960, 0.910, 0.870, 1 },
        title = { 0.980, 0.650, 0.420, 1 },
        headerText = { 0.920, 0.780, 0.670, 1 },
        muted = { 0.680, 0.570, 0.510, 1 },
        grid = { 0.520, 0.350, 0.280, 0.24 },
        axis = { 0.780, 0.560, 0.450, 0.42 },
        accent = { 0.960, 0.520, 0.330, 1 },
        mmr = { 0.880, 0.800, 0.740, 1 },
    },
}

local THEME_BY_KEY = {}
for _, theme in ipairs(THEME_PRESETS) do
    THEME_BY_KEY[theme.key] = theme
end

local HISTORY_FIELD_TIME = 1
local HISTORY_FIELD_RATING = 2
local HISTORY_FIELD_MMR = 3
local HISTORY_FIELD_RATING_DELTA = 4
local HISTORY_FIELD_MMR_IS_POSTMATCH = 7

local mainDockFrame, mainFrame, settingsPanel, scrollFrame, scrollChild, headerRow, graphPanel
local selectedGraph
local heliotropeCounter
local rowFrames = {}
local minimapButton
local themeButtons = {}
local RefreshHistoryCellAffordances
local movingMainFrame
local resizingMainFrame
local mainWindowNeedsInitialCenter
local UpdateMainDockFrameSize
local UpdateSettingsTabs
local UpdateFilterPresetButtons
UI.TableSort = UI.TableSort or { key = "character", direction = "asc" }

local function GetActiveTheme()
    local key = WarbandRatingsDB and WarbandRatingsDB.settings and WarbandRatingsDB.settings.themeKey or DEFAULT_THEME_KEY
    return THEME_BY_KEY[key] or THEME_BY_KEY[DEFAULT_THEME_KEY] or THEME_PRESETS[1]
end

function UI.GetActiveTheme()
    return GetActiveTheme()
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

local function GetGlobalColumnTextColor(col, value, theme)
    if col.key == "honor" then
        local honor = tonumber(value) or 0
        if honor >= HONOR_CAP_THRESHOLD then
            return HONOR_CAP_COLOR
        elseif honor >= HONOR_WARNING_THRESHOLD then
            return HONOR_WARNING_COLOR
        end
    end
    return Utils.IsEmptyRating(value) and theme.muted or theme.text
end

local function GetDockedGraphHeight()
    if graphPanel and graphPanel:IsShown() and not graphPanel.detached then
        return math.max(graphPanel:GetHeight() - 1, 0)
    end
    return 0
end

local function GetWindowMaxHeight()
    local parentHeight = UIParent and UIParent:GetHeight()
    if parentHeight and parentHeight > 0 then
        local maxHeight = parentHeight - WINDOW_SCREEN_MARGIN * 2
        if mainFrame then
            local top = mainFrame:GetTop()
            if top and top > 0 then
                maxHeight = math.min(maxHeight, top - WINDOW_SCREEN_MARGIN - GetDockedGraphHeight())
            end
        end
        return math.max(WINDOW_MIN_HEIGHT, maxHeight)
    end
    return WINDOW_MIN_HEIGHT
end

local function ClampWindowHeight(height)
    local value = tonumber(height) or WINDOW_HEIGHT
    return math.max(WINDOW_MIN_HEIGHT, math.min(value, GetWindowMaxHeight()))
end

local function ClampTableScroll()
    if not scrollFrame or not scrollChild then return end

    local maxScroll = math.max(scrollChild:GetHeight() - scrollFrame:GetHeight(), 0)
    if scrollFrame:GetVerticalScroll() > maxScroll then
        scrollFrame:SetVerticalScroll(maxScroll)
    end
end

local function SaveMainFrameHeight()
    if not mainFrame or not WarbandRatingsDB or not WarbandRatingsDB.settings then return end

    local height = math.floor(ClampWindowHeight(mainFrame:GetHeight()) + 0.5)
    if WarbandRatingsDB.settings.windowHeight ~= height then
        Database.SetSetting("windowHeight", height)
    end
end

local function ApplyMainFrameResizeBounds()
    if not mainFrame then return end

    local maxHeight = GetWindowMaxHeight()
    if mainFrame.SetResizeBounds then
        mainFrame:SetResizeBounds(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT, 10000, maxHeight)
    else
        mainFrame:SetMinResize(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)
        if mainFrame.SetMaxResize then
            mainFrame:SetMaxResize(10000, maxHeight)
        end
    end
end

local function RefreshScrollAreaLayout()
    if not scrollFrame then return end

    if scrollFrame.SetClipsChildren then
        scrollFrame:SetClipsChildren(true)
    end
    if scrollChild then
        scrollChild:SetWidth(scrollFrame:GetWidth())
    end
    if scrollFrame.UpdateScrollChildRect then
        scrollFrame:UpdateScrollChildRect()
    end

    ClampTableScroll()
end

local function SetMainDockFrameTopLeft(left, top)
    if not mainDockFrame then return end

    mainDockFrame:ClearAllPoints()
    mainDockFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function ClampMainDockFrameToScreen()
    if not mainDockFrame or not UIParent then return end

    local parentWidth = UIParent:GetWidth()
    local parentHeight = UIParent:GetHeight()
    if not parentWidth or not parentHeight or parentWidth <= 0 or parentHeight <= 0 then return end

    local width = mainDockFrame:GetWidth()
    local height = mainDockFrame:GetHeight()
    local left = mainDockFrame:GetLeft() or ((parentWidth - width) / 2)
    local top = mainDockFrame:GetTop() or ((parentHeight + height) / 2)

    if width <= parentWidth then
        left = math.max(0, math.min(left, parentWidth - width))
    else
        left = 0
    end

    if height <= parentHeight then
        top = math.max(height, math.min(top, parentHeight))
    else
        top = parentHeight
    end

    SetMainDockFrameTopLeft(left, top)
    RefreshScrollAreaLayout()
end

local function CenterMainDockFrameOnScreen()
    if not mainDockFrame or not UIParent then return end

    local parentWidth = UIParent:GetWidth()
    local parentHeight = UIParent:GetHeight()
    local width = mainDockFrame:GetWidth()
    local height = mainDockFrame:GetHeight()
    if not parentWidth or not parentHeight or not width or not height
        or parentWidth <= 0 or parentHeight <= 0 or width <= 0 or height <= 0 then
        return
    end

    SetMainDockFrameTopLeft((parentWidth - width) / 2, (parentHeight + height) / 2)
    ClampMainDockFrameToScreen()
end

local function CenterMainDockFrameAfterInitialLayout()
    if not mainWindowNeedsInitialCenter then return end

    UpdateMainDockFrameSize()
    CenterMainDockFrameOnScreen()
    mainWindowNeedsInitialCenter = nil
end

UpdateMainDockFrameSize = function()
    if not mainDockFrame or not mainFrame then return end

    local left = mainDockFrame:GetLeft()
    local top = mainDockFrame:GetTop()
    mainDockFrame:SetSize(
        mainFrame:GetWidth(),
        mainFrame:GetHeight() + GetDockedGraphHeight()
    )
    if left and top then
        SetMainDockFrameTopLeft(left, top)
    end
    ClampMainDockFrameToScreen()
    RefreshScrollAreaLayout()
end

local function PositionSettingsPanelNearMain(panel)
    if not panel or not UIParent then return end

    local parentWidth = UIParent:GetWidth()
    local parentHeight = UIParent:GetHeight()
    local panelWidth = panel:GetWidth() or SETTINGS_WIDTH
    local panelHeight = (panel:GetHeight() or SETTINGS_HEIGHT) + SETTINGS_TAB_HEIGHT

    panel:ClearAllPoints()

    if not mainFrame or not parentWidth or not parentHeight or parentWidth <= 0 or parentHeight <= 0 then
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    local mainLeft = mainFrame:GetLeft()
    local mainRight = mainFrame:GetRight()
    local mainTop = mainFrame:GetTop()
    if not mainLeft or not mainRight or not mainTop then
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    local margin = WINDOW_SCREEN_MARGIN
    local canOpenRight = mainRight + SETTINGS_WINDOW_OFFSET + panelWidth + margin <= parentWidth
    local canOpenLeft = mainLeft - SETTINGS_WINDOW_OFFSET - panelWidth >= margin
    local left

    if canOpenRight then
        left = mainRight + SETTINGS_WINDOW_OFFSET
    elseif canOpenLeft then
        left = mainLeft - SETTINGS_WINDOW_OFFSET - panelWidth
    elseif (parentWidth - mainRight) >= mainLeft then
        left = mainRight + SETTINGS_WINDOW_OFFSET
    else
        left = mainLeft - SETTINGS_WINDOW_OFFSET - panelWidth
    end

    local minLeft = margin
    local maxLeft = math.max(minLeft, parentWidth - panelWidth - margin)
    left = math.max(minLeft, math.min(left, maxLeft))

    local top = mainTop
    if panelHeight + margin * 2 <= parentHeight then
        local minTop = panelHeight + margin
        local maxTop = parentHeight - margin
        top = math.max(minTop, math.min(top, maxTop))
    else
        top = parentHeight - margin
    end

    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function GetScaledCursorPosition()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    return cursorX / scale, cursorY / scale
end

local function StopMainFrameResize()
    if not resizingMainFrame then return end

    resizingMainFrame = nil
    if mainFrame then
        mainFrame:SetScript("OnUpdate", nil)
        SaveMainFrameHeight()
    end
    RefreshScrollAreaLayout()
    UpdateMainDockFrameSize()
end

local function StopMainWindowMove()
    if not movingMainFrame then return end

    if mainFrame then
        mainFrame:SetScript("OnUpdate", nil)
    end
    movingMainFrame = nil
    ClampMainDockFrameToScreen()
    RefreshScrollAreaLayout()
end

local function UpdateMainWindowMove()
    if not movingMainFrame or not mainDockFrame then return end

    if not IsMouseButtonDown("LeftButton") then
        StopMainWindowMove()
        return
    end

    local cursorX, cursorY = GetScaledCursorPosition()
    SetMainDockFrameTopLeft(
        movingMainFrame.left + cursorX - movingMainFrame.cursorX,
        movingMainFrame.top + cursorY - movingMainFrame.cursorY
    )
    ClampMainDockFrameToScreen()
end

local function UpdateMainFrameResize()
    if not resizingMainFrame or not mainFrame then return end

    if not IsMouseButtonDown("LeftButton") then
        StopMainFrameResize()
        return
    end

    local _, cursorY = GetScaledCursorPosition()
    local delta = resizingMainFrame.cursorY - cursorY
    mainFrame:SetHeight(ClampWindowHeight(resizingMainFrame.height + delta))
end

local function StartMainWindowMove()
    if not mainDockFrame or not mainFrame then return end

    StopMainFrameResize()
    UpdateMainDockFrameSize()

    local cursorX, cursorY = GetScaledCursorPosition()
    movingMainFrame = {
        cursorX = cursorX,
        cursorY = cursorY,
        left = mainDockFrame:GetLeft() or 0,
        top = mainDockFrame:GetTop() or 0,
    }
    mainFrame:SetScript("OnUpdate", UpdateMainWindowMove)
end

local function StartMainFrameResize()
    if not mainFrame then return end

    StopMainWindowMove()
    local _, cursorY = GetScaledCursorPosition()
    resizingMainFrame = {
        cursorY = cursorY,
        height = mainFrame:GetHeight(),
    }
    ApplyMainFrameResizeBounds()
    mainFrame:SetScript("OnUpdate", UpdateMainFrameResize)
end

local TEMPLATE_ARTWORK_KEYS = {
    "Bg",
    "TitleBg",
    "PortraitFrame",
    "TopTileStreaks",
    "Inset",
    "InsetBg",
    "NineSlice",
    "Border",
    "BlackBg",
}

local function HideTemplateArtwork(frame)
    if not frame then return end
    for _, key in ipairs(TEMPLATE_ARTWORK_KEYS) do
        local region = frame[key]
        if region and region.Hide then
            region:Hide()
        end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end
end

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
-- Theme
------------------------------------------------------------
local function EnsureFillTexture(frame, key, layer, subLevel, inset)
    if not frame[key] then
        local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 1)
        texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset or 0, -(inset or 0))
        texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset or 0), inset or 0)
        frame[key] = texture
    end
    return frame[key]
end

local function EnsureBorderTextures(frame)
    if frame.themeBorders then return frame.themeBorders end

    local borders = {
        top = frame:CreateTexture(nil, "BORDER", nil, 2),
        bottom = frame:CreateTexture(nil, "BORDER", nil, 2),
        left = frame:CreateTexture(nil, "BORDER", nil, 2),
        right = frame:CreateTexture(nil, "BORDER", nil, 2),
    }

    borders.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borders.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borders.top:SetHeight(1)

    borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borders.bottom:SetHeight(1)

    borders.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borders.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borders.left:SetWidth(1)

    borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borders.right:SetWidth(1)

    frame.themeBorders = borders
    return borders
end

local function SetBorderColor(frame, color)
    local borders = EnsureBorderTextures(frame)
    for _, border in pairs(borders) do
        SetTextureColor(border, color)
    end
end

local function ApplyPanelTheme(frame, fillColor, borderColor)
    if not frame then return end
    SetTextureColor(EnsureFillTexture(frame, "themeBg", "BACKGROUND", 1, 0), fillColor)
    SetBorderColor(frame, borderColor)
end

local function CreateThemeChoiceButton(parent, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, THEME_BUTTON_HEIGHT)
    button.hovered = false

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()

    button.hover = button:CreateTexture(nil, "BORDER")
    button.hover:SetAllPoints()
    button.hover:Hide()

    button.selectedBar = button:CreateTexture(nil, "OVERLAY")
    button.selectedBar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -3)
    button.selectedBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 3)
    button.selectedBar:SetWidth(3)

    button.swatches = {}
    for i = 1, 3 do
        local swatch = button:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(10, 10)
        swatch:SetPoint("LEFT", button, "LEFT", 12 + (i - 1) * 12, 0)
        button.swatches[i] = swatch
    end

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button, "LEFT", 54, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.label:SetJustifyH("LEFT")

    return button
end

local function SetThemeChoiceButtonPreset(button, preset)
    if not button or not preset then return end

    button.themeKey = preset.key
    button.label:SetText(preset.label)

    local swatches = { preset.header, preset.surfaceRaised, preset.accent }
    for i, color in ipairs(swatches) do
        SetTextureColor(button.swatches[i], color)
    end
end

local function ApplyThemeChoiceButtonStyle(button, selected, activeTheme)
    if not button then return end

    SetTextureColor(button.bg, selected and activeTheme.header or activeTheme.surfaceRaised)
    SetTextureColor(button.hover, activeTheme.rowHover)
    SetTextureColor(button.selectedBar, activeTheme.accent)
    SetFontColor(button.label, selected and activeTheme.title or activeTheme.text)
    button.selectedBar:SetShown(selected)
    button.hover:SetShown(button.hovered and not selected)
end

local function UpdateThemeSelector()
    local activeTheme = GetActiveTheme()
    local activeKey = activeTheme.key

    if settingsPanel and settingsPanel.themeDropdown then
        local dropdown = settingsPanel.themeDropdown
        SetThemeChoiceButtonPreset(dropdown.selectedButton, activeTheme)
        ApplyThemeChoiceButtonStyle(dropdown.selectedButton, true, activeTheme)
        if dropdown.arrow then
            dropdown.arrow:SetText(dropdown.menu:IsShown() and "^" or "v")
            SetFontColor(dropdown.arrow, activeTheme.text)
        end
        if dropdown.menu then
            ApplyPanelTheme(dropdown.menu, activeTheme.surface, activeTheme.border)
        end
    end

    for _, button in ipairs(themeButtons) do
        local selected = button.themeKey == activeKey
        ApplyThemeChoiceButtonStyle(button, selected, activeTheme)
    end
end

local function GetHiddenColumns()
    local settings = Database.GetSettings()
    settings.hiddenColumns = settings.hiddenColumns or {}
    return settings.hiddenColumns
end

local function IsFilterPVPColumn(col)
    return Database.IsPVPColumn(col)
        or col.key == "honor"
        or col.key == "conquest"
        or col.key == "hk"
end

local function IsFilterPVEColumn(col)
    return col.key == "mythicPlus" or col.key == "crests"
end

local function ShouldShowColumnForFilterPreset(col, presetKey)
    if presetKey == "pvp" then
        return IsFilterPVPColumn(col)
    elseif presetKey == "pve" then
        return IsFilterPVEColumn(col)
    end
    return not GetHiddenColumns()[col.key]
end

local function DoesFilterMatchPreset(presetKey)
    local hiddenColumns = GetHiddenColumns()
    for _, col in ipairs(Database.RATING_COLUMNS) do
        local visible = not hiddenColumns[col.key]
        if visible ~= ShouldShowColumnForFilterPreset(col, presetKey) then
            return false
        end
    end
    return true
end

local function GetActiveFilterPreset()
    if DoesFilterMatchPreset("pvp") then
        return "pvp"
    elseif DoesFilterMatchPreset("pve") then
        return "pve"
    end
    return "custom"
end

local function RefreshSettingsFilterCheckboxes()
    if not settingsPanel or not settingsPanel.filterCheckboxes then return end

    local hiddenColumns = GetHiddenColumns()
    for _, cb in ipairs(settingsPanel.filterCheckboxes) do
        cb:SetChecked(not hiddenColumns[cb.columnKey])
    end
    if UpdateFilterPresetButtons then
        UpdateFilterPresetButtons()
    end
end

local function ApplyFilterPreset(presetKey)
    if presetKey == "custom" then
        if UpdateFilterPresetButtons then
            UpdateFilterPresetButtons()
        end
        return
    end

    local hiddenColumns = GetHiddenColumns()
    for _, col in ipairs(Database.RATING_COLUMNS) do
        if ShouldShowColumnForFilterPreset(col, presetKey) then
            hiddenColumns[col.key] = nil
        else
            hiddenColumns[col.key] = true
        end
    end

    RefreshSettingsFilterCheckboxes()
    UI.RefreshTable()
end

local function SetSettingsTab(tabKey)
    if not settingsPanel then return end

    settingsPanel.activeTab = tabKey
    if settingsPanel.themeDropdown and settingsPanel.themeDropdown.menu then
        settingsPanel.themeDropdown.menu:Hide()
    end
    if settingsPanel.settingsPage then
        settingsPanel.settingsPage:SetShown(tabKey == "settings")
    end
    if settingsPanel.filtersPage then
        settingsPanel.filtersPage:SetShown(tabKey == "filters")
    end
    if tabKey == "filters" then
        RefreshSettingsFilterCheckboxes()
    end
    if UpdateSettingsTabs then
        UpdateSettingsTabs()
    end
end

UpdateSettingsTabs = function()
    if not settingsPanel or not settingsPanel.tabs then return end

    local theme = GetActiveTheme()
    local activeTab = settingsPanel.activeTab or "settings"
    for _, tab in ipairs(settingsPanel.tabs) do
        local selected = tab.key == activeTab
        SetTextureColor(tab.bg, selected and theme.header or theme.surfaceRaised)
        SetTextureColor(tab.hover, theme.rowHover)
        SetTextureColor(tab.accent, selected and theme.accent or theme.border, selected and 1 or 0.55)
        SetFontColor(tab.label, selected and theme.title or theme.text)
        tab.hover:SetShown(tab.hovered and not selected)
    end
end

UpdateFilterPresetButtons = function()
    if not settingsPanel or not settingsPanel.filterPresetButtons then return end

    local theme = GetActiveTheme()
    local activePreset = GetActiveFilterPreset()
    for _, button in ipairs(settingsPanel.filterPresetButtons) do
        local selected = button.key == activePreset
        SetTextureColor(button.bg, selected and theme.header or theme.surfaceRaised)
        SetTextureColor(button.hover, theme.rowHover)
        SetTextureColor(button.accent, selected and theme.accent or theme.border, selected and 1 or 0.55)
        SetFontColor(button.label, selected and theme.title or theme.text)
        button.hover:SetShown(button.hovered and not selected)
    end
end

function UI.ApplyTheme()
    local theme = GetActiveTheme()

    if mainFrame then
        SetTextureColor(EnsureFillTexture(mainFrame, "themeBg", "BACKGROUND", 1, 0), theme.bg)
        if not mainFrame.themeTitleBg then
            mainFrame.themeTitleBg = mainFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
            mainFrame.themeTitleBg:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", TITLE_BAR_TOP_INSET, -TITLE_BAR_TOP_INSET)
            mainFrame.themeTitleBg:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -TITLE_BAR_TOP_INSET, -TITLE_BAR_TOP_INSET)
            mainFrame.themeTitleBg:SetHeight(TITLE_BAR_HEIGHT)
        end
        SetTextureColor(mainFrame.themeTitleBg, theme.surfaceRaised)
        if not mainFrame.themeAccentLine then
            mainFrame.themeAccentLine = mainFrame:CreateTexture(nil, "BORDER", nil, 3)
            mainFrame.themeAccentLine:SetHeight(1)
        end
        mainFrame.themeAccentLine:ClearAllPoints()
        mainFrame.themeAccentLine:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", SURFACE_INSET_X, -25)
        mainFrame.themeAccentLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -SURFACE_INSET_X, -25)
        SetTextureColor(mainFrame.themeAccentLine, theme.accent, 0.65)
        SetBorderColor(mainFrame, theme.border)
        SetFontColor(mainFrame.TitleText, theme.title)
        if mainFrame.resizeGrip then
            SetTextureColor(mainFrame.resizeGrip.line, theme.border, 0.9)
            SetTextureColor(mainFrame.resizeGrip.hoverLine, theme.accent, 0.95)
        end
    end

    if scrollFrame then
        SetTextureColor(EnsureFillTexture(scrollFrame, "themeBg", "BACKGROUND", 0, 0), theme.surface)
    end

    if headerRow then
        SetTextureColor(EnsureFillTexture(headerRow, "themeBg", "BACKGROUND", 1, 0), theme.header)
        if not headerRow.themeLine then
            headerRow.themeLine = headerRow:CreateTexture(nil, "BORDER", nil, 2)
            headerRow.themeLine:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 0, 0)
            headerRow.themeLine:SetPoint("BOTTOMRIGHT", headerRow, "BOTTOMRIGHT", 0, 0)
            headerRow.themeLine:SetHeight(1)
        end
        SetTextureColor(headerRow.themeLine, theme.border)
    end

    if settingsPanel then
        ApplyPanelTheme(settingsPanel, theme.surface, theme.border)
        SetFontColor(settingsPanel.title, theme.title)
        SetFontColor(settingsPanel.themeLabel, theme.headerText)
        if settingsPanel.checkboxes then
            for _, cb in ipairs(settingsPanel.checkboxes) do
                SetFontColor(cb.Text, theme.text)
            end
        end
        if settingsPanel.filterLabel then
            SetFontColor(settingsPanel.filterLabel, theme.headerText)
        end
        if settingsPanel.filterPresetLabel then
            SetFontColor(settingsPanel.filterPresetLabel, theme.headerText)
        end
        if UpdateSettingsTabs then
            UpdateSettingsTabs()
        end
        if UpdateFilterPresetButtons then
            UpdateFilterPresetButtons()
        end
    end

    if heliotropeCounter then
        SetFontColor(heliotropeCounter.text, theme.text)
    end

    if graphPanel then
        ApplyPanelTheme(graphPanel, theme.surface, theme.border)
        if selectedGraph and graphPanel.characterTitle then
            local cr, cg, cb = Utils.GetClassColor(selectedGraph.classFilename)
            graphPanel.characterTitle:SetTextColor(cr, cg, cb)
        elseif graphPanel.characterTitle then
            SetFontColor(graphPanel.characterTitle, theme.title)
        end
        SetFontColor(graphPanel.title, theme.title)
        SetFontColor(graphPanel.emptyText, theme.muted)
        SetFontColor(graphPanel.maxLabel, theme.muted)
        SetFontColor(graphPanel.midLabel, theme.muted)
        SetFontColor(graphPanel.minLabel, theme.muted)
        if graphPanel.yAxisLabels then
            for _, label in ipairs(graphPanel.yAxisLabels) do
                SetFontColor(label, theme.muted)
            end
        end
        if graphPanel.yAxisRightLabels then
            for _, label in ipairs(graphPanel.yAxisRightLabels) do
                SetFontColor(label, theme.muted)
            end
        end
        SetFontColor(graphPanel.gamesLabel, theme.muted)
        SetFontColor(graphPanel.zoomLabel, theme.muted)
        SetFontColor(graphPanel.zoomValueLabel, theme.muted)
    end

    for _, row in ipairs(rowFrames) do
        if row.hoverBg then
            SetTextureColor(row.hoverBg, theme.rowHover)
        end
    end

    UpdateThemeSelector()
    RefreshHistoryCellAffordances()
    if ns.Merchant and ns.Merchant.ApplyTheme then
        ns.Merchant.ApplyTheme()
    end
end

------------------------------------------------------------
-- Main Window
------------------------------------------------------------
local function CreateMainResizeGrip()
    local grip = CreateFrame("Button", nil, mainFrame)
    grip:SetSize(RESIZE_GRIP_WIDTH, RESIZE_GRIP_HEIGHT)
    grip:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 1)
    grip:SetFrameLevel(mainFrame:GetFrameLevel() + 20)
    grip:EnableMouse(true)

    grip.line = grip:CreateTexture(nil, "OVERLAY")
    grip.line:SetSize(RESIZE_GRIP_WIDTH - 20, 2)
    grip.line:SetPoint("CENTER", grip, "CENTER", 0, 0)

    grip.hoverLine = grip:CreateTexture(nil, "OVERLAY")
    grip.hoverLine:SetSize(RESIZE_GRIP_WIDTH - 20, 2)
    grip.hoverLine:SetPoint("CENTER", grip, "CENTER", 0, 0)
    grip.hoverLine:Hide()

    grip:SetScript("OnEnter", function(self)
        self.hoverLine:Show()
    end)
    grip:SetScript("OnLeave", function(self)
        self.hoverLine:Hide()
    end)
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end

        StartMainFrameResize()
    end)
    grip:SetScript("OnMouseUp", function()
        StopMainFrameResize()
    end)
    grip:SetScript("OnHide", function()
        StopMainFrameResize()
    end)

    mainFrame.resizeGrip = grip
end

local function GetHeliotropeIcon()
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(Database.HELIOTROPE_ITEM_ID)
    elseif C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(Database.HELIOTROPE_ITEM_ID)
        return icon
    end
    return nil
end

local function ShowHeliotropeTooltip(owner)
    local total, entries = Database.GetItemWarbandSummary(Database.HELIOTROPE_ITEM_ID)

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine("Warband total", Utils.FormatNumber(total), 1, 0.82, 0, 1, 1, 1)

    for _, entry in ipairs(entries) do
        if entry.classFilename then
            local r, g, b = Utils.GetClassColor(entry.classFilename)
            GameTooltip:AddDoubleLine(entry.label, Utils.FormatNumber(entry.quantity), r, g, b, 1, 1, 1)
        else
            GameTooltip:AddDoubleLine(entry.label, Utils.FormatNumber(entry.quantity), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end

    GameTooltip:Show()
end

function UI.RefreshHeliotropeCounter()
    if not heliotropeCounter then return end

    local total = Database.GetItemWarbandSummary(Database.HELIOTROPE_ITEM_ID)
    heliotropeCounter.text:SetText(Utils.FormatNumber(total))
    heliotropeCounter.icon:SetTexture(GetHeliotropeIcon())
end

local function CreateHeliotropeCounter(settingsBtn)
    if heliotropeCounter then return end

    heliotropeCounter = CreateFrame("Frame", "WarbandRatingsHeliotropeCounter", mainFrame)
    heliotropeCounter:SetSize(74, 20)
    heliotropeCounter:SetPoint("RIGHT", settingsBtn, "LEFT", -6, 0)
    heliotropeCounter:EnableMouse(true)
    heliotropeCounter:SetScript("OnEnter", ShowHeliotropeTooltip)
    heliotropeCounter:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    heliotropeCounter.icon = heliotropeCounter:CreateTexture(nil, "ARTWORK")
    heliotropeCounter.icon:SetSize(16, 16)
    heliotropeCounter.icon:SetPoint("RIGHT", heliotropeCounter, "RIGHT", 0, 0)
    heliotropeCounter.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    heliotropeCounter.text = heliotropeCounter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heliotropeCounter.text:SetPoint("RIGHT", heliotropeCounter.icon, "LEFT", -4, 0)
    heliotropeCounter.text:SetWidth(54)
    heliotropeCounter.text:SetJustifyH("RIGHT")

    UI.RefreshHeliotropeCounter()
end

function UI.CreateMainFrame()
    if mainFrame then return mainFrame end

    local settings = WarbandRatingsDB and WarbandRatingsDB.settings
    UI.TableSort.LoadSettings()
    mainWindowNeedsInitialCenter = true
    mainDockFrame = CreateFrame("Frame", "WarbandRatingsDockFrame", UIParent)
    mainDockFrame:SetSize(WINDOW_WIDTH, ClampWindowHeight(settings and settings.windowHeight))
    mainDockFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainDockFrame:SetMovable(true)
    mainDockFrame:SetClampedToScreen(true)
    mainDockFrame:SetFrameStrata("HIGH")

    mainFrame = CreateFrame("Frame", "WarbandRatingsMainFrame", mainDockFrame, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(WINDOW_WIDTH, ClampWindowHeight(settings and settings.windowHeight))
    mainFrame:SetPoint("TOPLEFT", mainDockFrame, "TOPLEFT", 0, 0)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    ApplyMainFrameResizeBounds()
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", StartMainWindowMove)
    mainFrame:SetScript("OnDragStop", StopMainWindowMove)
    mainFrame:SetScript("OnSizeChanged", function(self, _, height)
        local clampedHeight = ClampWindowHeight(height)
        if math.abs(height - clampedHeight) > 0.5 then
            self:SetHeight(clampedHeight)
            return
        end

        if not resizingMainFrame then
            SaveMainFrameHeight()
        end
        ClampTableScroll()
        UpdateMainDockFrameSize()
    end)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetClampedToScreen(false)
    mainFrame:Hide()
    HideTemplateArtwork(mainFrame)

    mainFrame.TitleText:SetText("Warband Ratings")
    mainFrame.TitleText:ClearAllPoints()
    mainFrame.TitleText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, -TITLE_BAR_TOP_INSET)
    mainFrame.TitleText:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, -TITLE_BAR_TOP_INSET)
    mainFrame.TitleText:SetHeight(TITLE_BAR_HEIGHT)
    mainFrame.TitleText:SetJustifyH("CENTER")
    mainFrame.TitleText:SetJustifyV("MIDDLE")

    -- Close with Escape: insert into the special frames table
    tinsert(UISpecialFrames, "WarbandRatingsMainFrame")

    local settingsBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    settingsBtn:SetSize(76, 20)
    settingsBtn:SetPoint("RIGHT", mainFrame.CloseButton, "LEFT", -4, 0)
    settingsBtn:SetText("Settings")
    settingsBtn:SetScript("OnClick", function()
        UI.ToggleSettings()
    end)
    CreateHeliotropeCounter(settingsBtn)

    UI.CreateScrollArea()
    UI.CreateSettingsPanel()
    UI.CreateHistoryGraphPanel()
    CreateMainResizeGrip()
    UI.ApplyTheme()

    return mainFrame
end

------------------------------------------------------------
-- Scroll Area
------------------------------------------------------------
function UI.CreateScrollArea()
    -- Header row (above scroll)
    headerRow = CreateFrame("Frame", nil, mainFrame)
    headerRow:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", SURFACE_INSET_X, -CONTENT_TOP_OFFSET)
    headerRow:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -SURFACE_INSET_X, -CONTENT_TOP_OFFSET)
    headerRow:SetHeight(HEADER_HEIGHT)

    scrollFrame = CreateFrame("ScrollFrame", "WarbandRatingsScrollFrame", mainFrame)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -SURFACE_INSET_X, CONTENT_BOTTOM_INSET)
    if scrollFrame.SetClipsChildren then
        scrollFrame:SetClipsChildren(true)
    end

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
        RefreshScrollAreaLayout()
    end)
end

------------------------------------------------------------
-- Settings Panel
------------------------------------------------------------
function UI.CreateThemeSelector(parent, yOffset)
    themeButtons = {}
    local owner = parent.settingsWindow or parent

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 14, yOffset)
    label:SetText("Theme")
    owner.themeLabel = label

    local buttonY = yOffset - 22
    local dropdown = CreateFrame("Frame", nil, parent)
    dropdown:SetPoint("TOPLEFT", 12, buttonY)
    dropdown:SetSize(THEME_BUTTON_WIDTH, THEME_BUTTON_HEIGHT)
    dropdown:SetFrameLevel(parent:GetFrameLevel() + 5)
    owner.themeDropdown = dropdown

    dropdown.selectedButton = CreateThemeChoiceButton(dropdown, THEME_BUTTON_WIDTH)
    dropdown.selectedButton:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
    dropdown.selectedButton.label:SetPoint("RIGHT", dropdown.selectedButton, "RIGHT", -24, 0)
    dropdown.arrow = dropdown.selectedButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdown.arrow:SetPoint("RIGHT", dropdown.selectedButton, "RIGHT", -8, 0)
    dropdown.arrow:SetWidth(12)
    dropdown.arrow:SetJustifyH("CENTER")

    dropdown.menu = CreateFrame("Frame", nil, dropdown)
    dropdown.menu:SetPoint("TOPLEFT", dropdown.selectedButton, "BOTTOMLEFT", 0, -4)
    dropdown.menu:SetSize(THEME_BUTTON_WIDTH, (#THEME_PRESETS * THEME_BUTTON_HEIGHT) + ((#THEME_PRESETS - 1) * 6) + 8)
    dropdown.menu:SetFrameLevel(dropdown:GetFrameLevel() + 10)
    dropdown.menu:Hide()

    dropdown.selectedButton:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateThemeSelector()
    end)
    dropdown.selectedButton:SetScript("OnLeave", function(self)
        self.hovered = false
        UpdateThemeSelector()
    end)
    dropdown.selectedButton:SetScript("OnClick", function()
        dropdown.menu:SetShown(not dropdown.menu:IsShown())
        UpdateThemeSelector()
    end)

    local optionY = -4
    for _, preset in ipairs(THEME_PRESETS) do
        local button = CreateThemeChoiceButton(dropdown.menu, THEME_BUTTON_WIDTH - 8)
        button:SetPoint("TOPLEFT", dropdown.menu, "TOPLEFT", 4, optionY)
        SetThemeChoiceButtonPreset(button, preset)

        button:SetScript("OnEnter", function(self)
            self.hovered = true
            UpdateThemeSelector()
        end)
        button:SetScript("OnLeave", function(self)
            self.hovered = false
            UpdateThemeSelector()
        end)
        button:SetScript("OnClick", function(self)
            dropdown.menu:Hide()
            if GetActiveTheme().key ~= self.themeKey then
                Database.SetSetting("themeKey", self.themeKey)
                UI.ApplyTheme()
                UI.RefreshTable()
                UI.RefreshHistoryGraph()
            else
                UpdateThemeSelector()
            end
        end)

        themeButtons[#themeButtons + 1] = button
        optionY = optionY - (THEME_BUTTON_HEIGHT + 6)
    end

    UpdateThemeSelector()
    return buttonY - THEME_BUTTON_HEIGHT - 8
end

local function CreateSettingsTabButton(parent, key, label, index)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(SETTINGS_TAB_WIDTH, SETTINGS_TAB_HEIGHT)
    tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 10 + (index - 1) * (SETTINGS_TAB_WIDTH + 4), 1)
    tab.key = key
    tab.hovered = false

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()

    tab.hover = tab:CreateTexture(nil, "BORDER")
    tab.hover:SetAllPoints()
    tab.hover:Hide()

    tab.accent = tab:CreateTexture(nil, "OVERLAY")
    tab.accent:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.accent:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    tab.accent:SetHeight(2)

    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.label:SetText(label)

    tab:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateSettingsTabs()
    end)
    tab:SetScript("OnLeave", function(self)
        self.hovered = false
        UpdateSettingsTabs()
    end)
    tab:SetScript("OnClick", function(self)
        SetSettingsTab(self.key)
    end)

    return tab
end

local function CreateFilterPresetButton(parent, key, label, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(FILTER_PRESET_BUTTON_WIDTH, FILTER_PRESET_BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 12 + (index - 1) * (FILTER_PRESET_BUTTON_WIDTH + 4), -60)
    button.key = key
    button.hovered = false

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()

    button.hover = button:CreateTexture(nil, "BORDER")
    button.hover:SetAllPoints()
    button.hover:Hide()

    button.accent = button:CreateTexture(nil, "OVERLAY")
    button.accent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.accent:SetWidth(3)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.label:SetText(label)

    button:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateFilterPresetButtons()
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered = false
        UpdateFilterPresetButtons()
    end)
    button:SetScript("OnClick", function(self)
        ApplyFilterPreset(self.key)
    end)

    return button
end

function UI.CreateSettingsPanel()
    if settingsPanel then return settingsPanel end

    settingsPanel = CreateFrame("Frame", "WarbandRatingsSettingsWindow", UIParent, "BasicFrameTemplateWithInset")
    tinsert(UISpecialFrames, "WarbandRatingsSettingsWindow")
    settingsPanel:SetSize(SETTINGS_WIDTH, SETTINGS_HEIGHT)
    PositionSettingsPanelNearMain(settingsPanel)
    settingsPanel:Hide()
    settingsPanel:SetMovable(true)
    settingsPanel:EnableMouse(true)
    settingsPanel:RegisterForDrag("LeftButton")
    settingsPanel:SetScript("OnDragStart", settingsPanel.StartMoving)
    settingsPanel:SetScript("OnDragStop", settingsPanel.StopMovingOrSizing)
    settingsPanel:SetScript("OnHide", function(self)
        if self.themeDropdown and self.themeDropdown.menu then
            self.themeDropdown.menu:Hide()
        end
    end)
    settingsPanel:SetFrameStrata("DIALOG")
    settingsPanel:SetClampedToScreen(true)
    HideTemplateArtwork(settingsPanel)

    settingsPanel.TitleText:SetText("Settings")
    settingsPanel.TitleText:ClearAllPoints()
    settingsPanel.TitleText:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 0, -TITLE_BAR_TOP_INSET)
    settingsPanel.TitleText:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", 0, -TITLE_BAR_TOP_INSET)
    settingsPanel.TitleText:SetHeight(TITLE_BAR_HEIGHT)
    settingsPanel.TitleText:SetJustifyH("CENTER")
    settingsPanel.TitleText:SetJustifyV("MIDDLE")
    settingsPanel.title = settingsPanel.TitleText

    settingsPanel.checkboxes = {}
    settingsPanel.filterCheckboxes = {}
    settingsPanel.filterPresetButtons = {}

    local settingsPage = CreateFrame("Frame", nil, settingsPanel)
    settingsPage:SetAllPoints(settingsPanel)
    settingsPage.settingsWindow = settingsPanel
    settingsPanel.settingsPage = settingsPage

    local filtersPage = CreateFrame("Frame", nil, settingsPanel)
    filtersPage:SetAllPoints(settingsPanel)
    filtersPage.settingsWindow = settingsPanel
    filtersPage:Hide()
    settingsPanel.filtersPage = filtersPage

    local yOffset = -38
    UI.CreateCheckbox(settingsPage, "Max level only", "hideNonMaxLevel", yOffset)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPage, "Hide characters with no rating", "hideNoRating", yOffset)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPage, "Hide brackets with no rating", "hideEmptyColumns", yOffset)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPage, "Hide minimap icon", "hideMinimapIcon", yOffset, function()
        UI.UpdateMinimapVisibility()
    end)
    yOffset = yOffset - 30
    UI.CreateCheckbox(settingsPage, "Hide compartment icon", "hideCompartmentIcon", yOffset, function()
        UI.UpdateCompartmentVisibility()
    end)
    yOffset = yOffset - 42
    UI.CreateThemeSelector(settingsPage, yOffset)

    local presetLabel = filtersPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    presetLabel:SetPoint("TOPLEFT", 14, -38)
    presetLabel:SetText("Preset")
    settingsPanel.filterPresetLabel = presetLabel

    settingsPanel.filterPresetButtons = {
        CreateFilterPresetButton(filtersPage, "pvp", "PvP", 1),
        CreateFilterPresetButton(filtersPage, "pve", "PvE", 2),
        CreateFilterPresetButton(filtersPage, "custom", "Custom", 3),
    }

    local filterLabel = filtersPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", 14, -94)
    filterLabel:SetText("Visible columns")
    settingsPanel.filterLabel = filterLabel

    local yOff = -124
    local hiddenColumns = GetHiddenColumns()
    for _, col in ipairs(Database.RATING_COLUMNS) do
        local cb = CreateFrame("CheckButton", nil, filtersPage, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 12, yOff)
        cb.Text:SetText(col.label)
        cb.Text:SetFontObject("GameFontNormalSmall")
        cb:SetChecked(not hiddenColumns[col.key])
        cb.columnKey = col.key
        cb:SetScript("OnClick", function(self)
            local hidden = GetHiddenColumns()
            if self:GetChecked() then
                hidden[self.columnKey] = nil
            else
                hidden[self.columnKey] = true
            end
            UpdateFilterPresetButtons()
            UI.RefreshTable()
        end)
        settingsPanel.checkboxes[#settingsPanel.checkboxes + 1] = cb
        settingsPanel.filterCheckboxes[#settingsPanel.filterCheckboxes + 1] = cb
        yOff = yOff - 26
    end

    settingsPanel.tabs = {
        CreateSettingsTabButton(settingsPanel, "settings", "Settings", 1),
        CreateSettingsTabButton(settingsPanel, "filters", "Filters", 2),
    }
    settingsPanel.activeTab = "settings"
    SetSettingsTab("settings")

    return settingsPanel
end

function UI.CreateCheckbox(parent, label, settingKey, yOffset, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, yOffset)
    cb.Text:SetText(label)
    cb.Text:SetFontObject("GameFontNormalSmall")
    SetFontColor(cb.Text, GetActiveTheme().text)
    local owner = parent.settingsWindow or parent
    owner.checkboxes = owner.checkboxes or {}
    owner.checkboxes[#owner.checkboxes + 1] = cb

    cb:SetChecked(Database.GetSettings()[settingKey])
    cb:SetScript("OnClick", function(self)
        Database.SetSetting(settingKey, self:GetChecked())
        UI.RefreshTable()
        if onChange then onChange() end
    end)
end

function UI.ToggleSettings()
    local panel = UI.CreateSettingsPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        PositionSettingsPanelNearMain(panel)
        panel:Show()
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

local function ScrollTable(delta)
    local current = scrollFrame:GetVerticalScroll()
    local maxScroll = math.max(scrollChild:GetHeight() - scrollFrame:GetHeight(), 0)
    local newScroll = math.max(0, math.min(current - delta * SUBROW_HEIGHT, maxScroll))
    scrollFrame:SetVerticalScroll(newScroll)
end

local function SetRowHovered(row, hovered)
    if row.hoverBg then
        row.hoverBg:SetShown(hovered)
    end
end

local function ResetHistoryCellOverlay(overlay)
    if overlay.historySelection then
        overlay.historySelection:Hide()
    end
    if overlay.historyGraphIcon then
        overlay.historyGraphIcon:Hide()
    end
    overlay.historyCell = nil
    overlay.historyHovered = nil
    overlay.historyCharKey = nil
    overlay.historySpecID = nil
    overlay.historyColKey = nil
    overlay.historyClassFilename = nil
end

local function GetOrCreateRow(index)
    if rowFrames[index] then
        rowFrames[index]:Show()
        return rowFrames[index]
    end
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetHeight(SUBROW_HEIGHT)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        SetRowHovered(self, true)
    end)
    row:SetScript("OnLeave", function(self)
        SetRowHovered(self, false)
    end)
    row:SetScript("OnMouseWheel", function(_, delta)
        ScrollTable(delta)
    end)

    row.hoverBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.hoverBg:SetAllPoints()
    SetTextureColor(row.hoverBg, GetActiveTheme().rowHover)
    row.hoverBg:Hide()

    rowFrames[index] = row
    return row
end

local function ResetCell(cell)
    ResetHistoryCellOverlay(cell)
    cell:Hide()
    cell:ClearAllPoints()
    if cell.SetText then
        cell:SetText("")
    end
    if cell.SetTexture then
        cell:SetTexture(nil)
    end
    if cell.SetTexCoord then
        cell:SetTexCoord(0, 1, 0, 1)
    end
    if cell.SetScript then
        cell:SetScript("OnEnter", nil)
        cell:SetScript("OnLeave", nil)
        cell:SetScript("OnMouseUp", nil)
        cell:EnableMouse(false)
    end
end

local function ResetCells(owner)
    if owner.cells then
        for _, cell in ipairs(owner.cells) do
            ResetCell(cell)
        end
    end
    owner.cells = {}
    owner.cellPoolIndexes = {}
end

local function AcquirePooledCell(owner, key, createFn)
    owner.cellPools = owner.cellPools or {}
    owner.cellPoolIndexes = owner.cellPoolIndexes or {}

    local pool = owner.cellPools[key]
    if not pool then
        pool = {}
        owner.cellPools[key] = pool
    end

    local index = (owner.cellPoolIndexes[key] or 0) + 1
    owner.cellPoolIndexes[key] = index

    local cell = pool[index]
    if not cell then
        cell = createFn()
        pool[index] = cell
    end

    cell:ClearAllPoints()
    cell:Show()
    owner.cells[#owner.cells + 1] = cell
    return cell
end

local function AcquireFontString(owner, fontObject)
    return AcquirePooledCell(owner, "font:" .. fontObject, function()
        return owner:CreateFontString(nil, "OVERLAY", fontObject)
    end)
end

local function AcquireTexture(owner, layer)
    return AcquirePooledCell(owner, "texture:" .. layer, function()
        return owner:CreateTexture(nil, layer)
    end)
end

local function AcquireOverlay(owner)
    local overlay = AcquirePooledCell(owner, "overlay", function()
        return CreateFrame("Frame", nil, owner)
    end)
    overlay:EnableMouse(true)
    overlay:SetScript("OnMouseWheel", function(_, delta)
        ScrollTable(delta)
    end)
    return overlay
end

local function StripRow(row)
    ResetCells(row)
    SetRowHovered(row, false)
end

local function ColWidth(col)
    if Database.IsSpecColumn(col) then return COL_SPEC_RATING_WIDTH end
    return COL_RATING_WIDTH
end

function UI.TableSort.IsActive(sortKey)
    return UI.TableSort.key == sortKey
end

function UI.TableSort.LoadSettings()
    local settings = Database.GetSettings()
    local sortKey = settings.sortKey
    if type(sortKey) ~= "string" or sortKey == "" then
        sortKey = "character"
    end
    UI.TableSort.key = sortKey
    UI.TableSort.direction = settings.sortDirection == "desc" and "desc" or "asc"
end

function UI.TableSort.SaveSettings()
    Database.SetSetting("sortKey", UI.TableSort.key or "character")
    Database.SetSetting("sortDirection", UI.TableSort.direction == "desc" and "desc" or "asc")
end

function UI.TableSort.AddArrow(owner, x, direction, theme)
    local arrow = AcquirePooledCell(owner, "sortArrow", function()
        return owner:CreateTexture(nil, "OVERLAY")
    end)

    arrow:SetSize(12, 12)
    arrow:SetPoint("LEFT", owner, "LEFT", x, 0)
    arrow:SetTexture(direction == "asc" and "Interface\\Buttons\\Arrow-Up-Up" or "Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetVertexColor(theme.headerText[1], theme.headerText[2], theme.headerText[3], theme.headerText[4] or 1)
    arrow:Show()
end

function UI.TableSort.AddTextArrow(owner, sortKey, x, width, fontString, justifyH, theme)
    if not UI.TableSort.IsActive(sortKey) then return end

    local textWidth = math.min(math.ceil(fontString:GetStringWidth()), math.max(width - 14, 0))
    local arrowX
    if justifyH == "LEFT" then
        arrowX = x + textWidth + 6
    else
        arrowX = x + (width + textWidth) / 2 + 4
    end
    arrowX = math.min(arrowX, x + width - 10)
    UI.TableSort.AddArrow(owner, arrowX, UI.TableSort.direction, theme)
end

function UI.TableSort.CompareText(a, b, ascending)
    local textA = string.lower(tostring(a or ""))
    local textB = string.lower(tostring(b or ""))
    if textA ~= textB then
        if ascending then
            return textA < textB
        end
        return textA > textB
    end
    return nil
end

function UI.TableSort.CompareNumber(a, b, ascending)
    local valueA = tonumber(a)
    local valueB = tonumber(b)

    if valueA and valueB then
        if valueA ~= valueB then
            if ascending then
                return valueA < valueB
            end
            return valueA > valueB
        end
        return nil
    elseif valueA then
        return true
    elseif valueB then
        return false
    end
    return nil
end

function UI.TableSort.CompareCharacter(a, b, direction)
    if not a then return false end
    if not b then return true end

    local ascending = direction ~= "desc"
    local charA = a.charData or {}
    local charB = b.charData or {}
    local result = UI.TableSort.CompareText(charA.classFilename, charB.classFilename, ascending)
    if result ~= nil then return result end

    result = UI.TableSort.CompareText(charA.name, charB.name, ascending)
    if result ~= nil then return result end

    result = UI.TableSort.CompareText(charA.realm, charB.realm, ascending)
    if result ~= nil then return result end

    return (charA.level or 0) > (charB.level or 0)
end

function UI.TableSort.GetColumnValue(group, col)
    if not group or not col then return nil end

    local charData = group.charData or {}

    if Database.IsSpecColumn(col) then
        local bestValue
        for _, specID in ipairs(group.specs or {}) do
            local specRatings = charData.specRatings and charData.specRatings[specID]
            local value = specRatings and tonumber(specRatings[col.key])
            if value and value > 0 and (not bestValue or value > bestValue) then
                bestValue = value
            end
        end
        return bestValue
    end

    local value = charData.ratings and tonumber(charData.ratings[col.key])
    if value and value > 0 then
        return value
    end
    return nil
end

function UI.TableSort.CompareColumn(a, b, col, direction)
    local result = UI.TableSort.CompareNumber(
        UI.TableSort.GetColumnValue(a, col),
        UI.TableSort.GetColumnValue(b, col),
        direction == "asc"
    )
    if result ~= nil then return result end
    return UI.TableSort.CompareCharacter(a, b, "asc")
end

function UI.TableSort.FindVisibleColumn(columns)
    if UI.TableSort.key == "character" then return nil end

    for _, col in ipairs(columns) do
        if col.key == UI.TableSort.key and not col.crests then
            return col
        end
    end
    return nil
end

function UI.TableSort.SortGroups(groups, columns)
    local sortCol = UI.TableSort.FindVisibleColumn(columns)
    if UI.TableSort.key ~= "character" and not sortCol then
        UI.TableSort.key = "character"
        UI.TableSort.direction = "asc"
        UI.TableSort.SaveSettings()
    end

    if UI.TableSort.key == "character" then
        table.sort(groups, function(a, b)
            return UI.TableSort.CompareCharacter(a, b, UI.TableSort.direction)
        end)
    else
        table.sort(groups, function(a, b)
            return UI.TableSort.CompareColumn(a, b, sortCol, UI.TableSort.direction)
        end)
    end
end

function UI.TableSort.Set(sortKey)
    if UI.TableSort.key == sortKey then
        UI.TableSort.direction = UI.TableSort.direction == "asc" and "desc" or "asc"
    else
        UI.TableSort.key = sortKey
        UI.TableSort.direction = sortKey == "character" and "asc" or "desc"
    end
    UI.TableSort.SaveSettings()
    UI.RefreshTable()
end

function UI.TableSort.AddHeaderOverlay(x, w, sortKey)
    local overlay = AcquireOverlay(headerRow)
    overlay:SetPoint("LEFT", headerRow, "LEFT", x, 0)
    overlay:SetSize(w, HEADER_HEIGHT)
    overlay:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            UI.TableSort.Set(sortKey)
        end
    end)
end

local function GetRatingTextY(subY)
    return subY - (SUBROW_HEIGHT - RATING_TEXT_HEIGHT) / 2
end

local function SetHistoryGraphIconColor(icon, r, g, b)
    if not icon then return end
    for _, line in ipairs(icon.lines) do
        line:SetColorTexture(r, g, b, 0.95)
    end
    for _, dot in ipairs(icon.dots) do
        dot:SetColorTexture(r, g, b, 0.95)
    end
end

local function CreateHistoryGraphIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(HISTORY_GRAPH_ICON_SIZE, HISTORY_GRAPH_ICON_SIZE)
    icon.lines = {}
    icon.dots = {}

    local points = {
        { 2, 4 },
        { 5, 8 },
        { 8, 6 },
        { 12, 11 },
    }

    for i = 1, #points - 1 do
        local line = icon:CreateLine(nil, "OVERLAY")
        line:SetThickness(1.5)
        line:SetStartPoint("BOTTOMLEFT", icon, points[i][1], points[i][2])
        line:SetEndPoint("BOTTOMLEFT", icon, points[i + 1][1], points[i + 1][2])
        icon.lines[#icon.lines + 1] = line
    end

    for _, point in ipairs(points) do
        local dot = icon:CreateTexture(nil, "OVERLAY")
        dot:SetSize(2, 2)
        dot:SetPoint("CENTER", icon, "BOTTOMLEFT", point[1], point[2])
        icon.dots[#icon.dots + 1] = dot
    end

    SetHistoryGraphIconColor(icon, 1, 1, 1)
    icon:Hide()
    return icon
end

local function EnsureHistoryCellAffordance(overlay)
    if not overlay.historySelection then
        overlay.historySelection = overlay:CreateTexture(nil, "BACKGROUND")
        overlay.historySelection:SetAllPoints()
        overlay.historySelection:Hide()
    end
    if not overlay.historyGraphIcon then
        overlay.historyGraphIcon = CreateHistoryGraphIcon(overlay)
    end
end

local function IsHistoryCellSelected(overlay)
    return selectedGraph
        and overlay.historyCharKey == selectedGraph.charKey
        and overlay.historySpecID == selectedGraph.specID
        and overlay.historyColKey == selectedGraph.colKey
end

local function UpdateHistoryCellAffordance(overlay, hovered)
    if not overlay.historyCell then return end

    local cr, cg, cb = Utils.GetClassColor(overlay.historyClassFilename)
    local selected = IsHistoryCellSelected(overlay)
    if selected then
        overlay.historySelection:SetColorTexture(cr, cg, cb, HISTORY_SELECTED_ALPHA)
        overlay.historySelection:Show()
    else
        overlay.historySelection:Hide()
    end

    if hovered or selected then
        overlay.historyGraphIcon:ClearAllPoints()
        overlay.historyGraphIcon:SetPoint("RIGHT", overlay, "RIGHT", -HISTORY_GRAPH_ICON_PADDING, 0)
        SetHistoryGraphIconColor(overlay.historyGraphIcon, cr, cg, cb)
        overlay.historyGraphIcon:Show()
    else
        overlay.historyGraphIcon:Hide()
    end
end

RefreshHistoryCellAffordances = function()
    for _, row in ipairs(rowFrames) do
        if row.cells then
            for _, cell in ipairs(row.cells) do
                if cell.historyCell then
                    UpdateHistoryCellAffordance(cell, cell.historyHovered)
                end
            end
        end
    end
end

local function ClearGraphDrawings()
    if not graphPanel then return end

    if graphPanel.drawLayer then
        for _, region in ipairs({ graphPanel.drawLayer:GetRegions() }) do
            region:Hide()
        end
    end

    graphPanel.lineIndex = 0
    if graphPanel.lines then
        for _, line in ipairs(graphPanel.lines) do
            line:Hide()
            if line.ClearAllPoints then
                line:ClearAllPoints()
            end
        end
    end

    graphPanel.dotIndex = 0
    if graphPanel.dots then
        for _, dot in ipairs(graphPanel.dots) do
            dot:Hide()
            dot:ClearAllPoints()
        end
    end

    if graphPanel.hoverLine then
        graphPanel.hoverLine:Hide()
        if graphPanel.hoverLine.ClearAllPoints then
            graphPanel.hoverLine:ClearAllPoints()
        end
    end
    if graphPanel.hoverRatingDot then
        graphPanel.hoverRatingDot:Hide()
    end
    if graphPanel.hoverMMRDot then
        graphPanel.hoverMMRDot:Hide()
    end
    if graphPanel.canvas and GameTooltip:IsOwned(graphPanel.canvas) then
        GameTooltip:Hide()
    end
    if graphPanel.yAxisLabels then
        for _, label in ipairs(graphPanel.yAxisLabels) do
            label:SetText("")
            label:Hide()
        end
    end
    if graphPanel.yAxisRightLabels then
        for _, label in ipairs(graphPanel.yAxisRightLabels) do
            label:SetText("")
            label:Hide()
        end
    end
    graphPanel.graphData = nil
end

local function EnsureGraphDrawLayer()
    if not graphPanel.drawLayer then
        graphPanel.drawLayer = CreateFrame("Frame", nil, graphPanel.canvas)
        graphPanel.drawLayer:SetAllPoints(graphPanel.canvas)
        graphPanel.drawLayer:EnableMouse(false)
    end

    graphPanel.drawLayer:SetFrameLevel(graphPanel.canvas:GetFrameLevel() + 1)
    graphPanel.drawLayer:Show()
    return graphPanel.drawLayer
end

local function EnsureGraphHoverLayer()
    if not graphPanel.hoverLayer then
        graphPanel.hoverLayer = CreateFrame("Frame", nil, graphPanel.canvas)
        graphPanel.hoverLayer:SetAllPoints(graphPanel.canvas)
        graphPanel.hoverLayer:EnableMouse(false)
    end

    graphPanel.hoverLayer:SetFrameLevel(graphPanel.canvas:GetFrameLevel() + 4)
    graphPanel.hoverLayer:Show()
    return graphPanel.hoverLayer
end

local function AcquireGraphYAxisLabel(index, side)
    local drawLayer = EnsureGraphDrawLayer()
    local labels
    local width
    local justify

    if side == "right" then
        graphPanel.yAxisRightLabels = graphPanel.yAxisRightLabels or {}
        labels = graphPanel.yAxisRightLabels
        width = GRAPH_MARGIN_RIGHT - 8
        justify = "LEFT"
    else
        graphPanel.yAxisLabels = graphPanel.yAxisLabels or {}
        labels = graphPanel.yAxisLabels
        width = GRAPH_MARGIN_LEFT - 8
        justify = "RIGHT"
    end

    local label = labels[index]
    if not label then
        label = drawLayer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetWidth(width)
        label:SetJustifyH(justify)
        label:SetJustifyV("MIDDLE")
        labels[index] = label
    end

    return label
end

local function AddGraphLine(x1, y1, x2, y2, r, g, b, alpha, thickness)
    graphPanel.lines = graphPanel.lines or {}
    graphPanel.lineIndex = (graphPanel.lineIndex or 0) + 1
    local drawLayer = EnsureGraphDrawLayer()

    local line = graphPanel.lines[graphPanel.lineIndex]
    if not line then
        line = drawLayer:CreateLine(nil, "ARTWORK")
        graphPanel.lines[graphPanel.lineIndex] = line
    end

    if line.ClearAllPoints then
        line:ClearAllPoints()
    end
    line:SetColorTexture(r, g, b, alpha or 1)
    line:SetThickness(thickness or 2)
    line:SetStartPoint("TOPLEFT", drawLayer, x1, -y1)
    line:SetEndPoint("TOPLEFT", drawLayer, x2, -y2)
    line:Show()
end

local function AddGraphDot(x, y, r, g, b, alpha, size)
    graphPanel.dots = graphPanel.dots or {}
    graphPanel.dotIndex = (graphPanel.dotIndex or 0) + 1
    local drawLayer = EnsureGraphDrawLayer()

    local dot = graphPanel.dots[graphPanel.dotIndex]
    if not dot then
        dot = drawLayer:CreateTexture(nil, "OVERLAY")
        graphPanel.dots[graphPanel.dotIndex] = dot
    end

    dot:SetSize(size or GRAPH_POINT_SIZE, size or GRAPH_POINT_SIZE)
    dot:SetColorTexture(r, g, b, alpha or 1)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", drawLayer, "TOPLEFT", x, -y)
    dot:Show()
end

local function FormatGraphValue(value)
    return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function FormatTooltipNumber(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    local sign = value < 0 and "-" or ""
    local text = tostring(math.abs(value))
    local left, num, right = text:match("^([^%d]*%d)(%d*)(.-)$")

    if not left then
        return sign .. text
    end

    return sign .. left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

UI.PVPTooltip = UI.PVPTooltip or {
    titles = {
        soloShuffle = "Solo Shuffle",
        soloBG = "Solo Battlegrounds",
        arena2v2 = "2v2 Arena Battles",
        arena3v3 = "3v3 Arena Battles",
        rbg10v10 = "10v10 Rated Battlegrounds",
    },
}

function UI.PVPTooltip.GetStats(charData, specID, col)
    if Database.IsSpecColumn(col) then
        local specStats = charData.specPVPStats and charData.specPVPStats[specID]
        return specStats and specStats[col.key]
    end
    return charData.pvpStats and charData.pvpStats[col.key]
end

function UI.PVPTooltip.GetRating(charData, specID, col, stats)
    if stats and stats.rating and stats.rating > 0 then
        return stats.rating
    end

    if Database.IsSpecColumn(col) then
        local specRatings = charData.specRatings and charData.specRatings[specID]
        return specRatings and specRatings[col.key]
    end
    return charData.ratings and charData.ratings[col.key]
end

function UI.PVPTooltip.GetMMR(charData, specID, col)
    if Database.IsSpecColumn(col) then
        local specMMR = charData.specLastMMR and charData.specLastMMR[specID]
        return specMMR and specMMR[col.key]
    end
    return charData.lastMMR and charData.lastMMR[col.key]
end

function UI.PVPTooltip.GetSpecName(specID)
    specID = tonumber(specID)
    if not specID or specID <= 0 then return nil end

    local _, name = GetSpecializationInfoByID(specID)
    return name
end

function UI.PVPTooltip.ColorName(charData)
    local r, g, b = Utils.GetClassColor(charData.classFilename)
    return string.format(
        "|cff%02x%02x%02x%s|r",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5),
        charData.name or "?"
    )
end

function UI.PVPTooltip.GetTitle(charData, specID, col)
    local prefix = ""
    if Database.IsSpecColumn(col) then
        local specIcon = Utils.GetSpecIcon(specID)
        if specIcon then
            prefix = "|T" .. specIcon .. ":14:14:0:0|t "
        end
    end
    return prefix .. UI.PVPTooltip.ColorName(charData) .. "'s " .. (UI.PVPTooltip.titles[col.key] or col.label)
end

function UI.PVPTooltip.AddStatsBlock(title, best, won, played, unitLabel, mostPlayedSpecID, mostPlayedCount)
    unitLabel = unitLabel or "Games"
    GameTooltip:AddLine(title, 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Best Rating:", FormatTooltipNumber(best), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(unitLabel .. " Won:", FormatTooltipNumber(won), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(unitLabel .. " Played:", FormatTooltipNumber(played), 1, 1, 1, 1, 1, 1)

    local mostPlayedSpecName = UI.PVPTooltip.GetSpecName(mostPlayedSpecID)
    mostPlayedCount = tonumber(mostPlayedCount) or 0
    if mostPlayedSpecName and mostPlayedCount > 0 then
        GameTooltip:AddDoubleLine("Most Played:", mostPlayedSpecName .. " (" .. FormatTooltipNumber(mostPlayedCount) .. ")", 1, 1, 1, 1, 1, 1)
    end
end

function UI.PVPTooltip.Show(owner, charData, specID, col)
    if not Database.IsPVPColumn(col) then return false end

    local theme = GetActiveTheme()
    local stats = UI.PVPTooltip.GetStats(charData, specID, col)
    local rating = UI.PVPTooltip.GetRating(charData, specID, col, stats)
    local mmr = UI.PVPTooltip.GetMMR(charData, specID, col)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(UI.PVPTooltip.GetTitle(charData, specID, col), 1, 0.82, 0)

    if not Utils.IsEmptyRating(rating) then
        GameTooltip:AddDoubleLine("Current Rating:", FormatTooltipNumber(rating), 1, 1, 1, 1, 1, 1)
    end
    if not Utils.IsEmptyRating(mmr) then
        local mmrLabel = Database.IsSpecColumn(col) and "Current MMR:" or "Last MMR:"
        GameTooltip:AddDoubleLine(mmrLabel, FormatTooltipNumber(mmr), 1, 1, 1, 1, 1, 1)
    end

    if stats then
        local useRounds = col.key == "soloShuffle"
        local unitLabel = useRounds and "Rounds" or "Games"
        local weeklyWon = useRounds and stats.roundsWeeklyWon or stats.weeklyWon
        local weeklyPlayed = useRounds and stats.roundsWeeklyPlayed or stats.weeklyPlayed
        local seasonWon = useRounds and stats.roundsSeasonWon or stats.seasonWon
        local seasonPlayed = useRounds and stats.roundsSeasonPlayed or stats.seasonPlayed
        local mostPlayedWeeklySpecID = not Database.IsSpecColumn(col) and stats.weeklyMostPlayedSpecID or nil
        local mostPlayedWeeklyCount = not Database.IsSpecColumn(col) and stats.weeklyMostPlayedSpecCount or nil
        local mostPlayedSeasonSpecID = not Database.IsSpecColumn(col) and stats.seasonMostPlayedSpecID or nil
        local mostPlayedSeasonCount = not Database.IsSpecColumn(col) and stats.seasonMostPlayedSpecCount or nil

        GameTooltip:AddLine(" ")
        UI.PVPTooltip.AddStatsBlock(
            "Weekly Stats",
            stats.weeklyBest,
            weeklyWon,
            weeklyPlayed,
            unitLabel,
            mostPlayedWeeklySpecID,
            mostPlayedWeeklyCount
        )
        GameTooltip:AddLine(" ")
        UI.PVPTooltip.AddStatsBlock(
            "Season Stats",
            stats.seasonBest,
            seasonWon,
            seasonPlayed,
            unitLabel,
            mostPlayedSeasonSpecID,
            mostPlayedSeasonCount
        )
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Log in on this character to record weekly and season stats.", theme.muted[1], theme.muted[2], theme.muted[3], true)
    end

    GameTooltip:Show()
    return true
end

local function GetHistoryPointTime(point)
    return tonumber(point and point[HISTORY_FIELD_TIME])
end

local function FormatGraphTimestamp(point)
    local timestamp = GetHistoryPointTime(point)
    if not timestamp or timestamp <= 0 then
        return "Unknown"
    end
    return date("%Y-%m-%d %H:%M", timestamp)
end

local function GetHistoryPointRating(point)
    return tonumber(point and point[HISTORY_FIELD_RATING]) or 0
end

local function GetHistoryPointMMR(point)
    return tonumber(point and point[HISTORY_FIELD_MMR]) or 0
end

local function GetHistoryPointRatingDelta(point)
    return tonumber(point and point[HISTORY_FIELD_RATING_DELTA]) or 0
end

local function IsHistoryPointPostMatchMMR(point)
    return point and point[HISTORY_FIELD_MMR_IS_POSTMATCH] == true
end

local function FormatGraphDelta(delta)
    delta = tonumber(delta) or 0
    if delta > 0 then
        return " (+" .. FormatGraphValue(delta) .. ")"
    elseif delta < 0 then
        return " (" .. FormatGraphValue(delta) .. ")"
    end
    return " (+0)"
end

local function GetAlignedGraphMMR(points, index)
    local point = points and points[index]
    if IsHistoryPointPostMatchMMR(point) then
        return GetHistoryPointMMR(point)
    end

    local nextPoint = points and points[index + 1]
    if nextPoint and not IsHistoryPointPostMatchMMR(nextPoint) then
        return GetHistoryPointMMR(nextPoint)
    end

    return nil
end

local function GetGraphPointY(value, minValue, maxValue, plotHeight)
    value = tonumber(value) or 0
    if maxValue <= minValue then
        return GRAPH_MARGIN_TOP + plotHeight / 2
    end
    return GRAPH_MARGIN_TOP + ((maxValue - value) / (maxValue - minValue)) * plotHeight
end

local function DrawGraphYAxisLabels(minValue, maxValue, tickStep, plotWidth, plotHeight, theme)
    local labelIndex = 1
    local tickValue = minValue

    while tickValue <= maxValue + 0.5 do
        local y = GetGraphPointY(tickValue, minValue, maxValue, plotHeight)
        local label = AcquireGraphYAxisLabel(labelIndex)
        label:ClearAllPoints()
        label:SetPoint("RIGHT", graphPanel.drawLayer, "TOPLEFT", GRAPH_MARGIN_LEFT - 6, -y)
        label:SetText(FormatGraphValue(tickValue))
        SetFontColor(label, theme.muted)
        label:Show()

        local rightLabel = AcquireGraphYAxisLabel(labelIndex, "right")
        rightLabel:ClearAllPoints()
        rightLabel:SetPoint("LEFT", graphPanel.drawLayer, "TOPLEFT", GRAPH_MARGIN_LEFT + plotWidth + 6, -y)
        rightLabel:SetText(FormatGraphValue(tickValue))
        SetFontColor(rightLabel, theme.muted)
        rightLabel:Show()

        labelIndex = labelIndex + 1
        tickValue = tickValue + tickStep
    end

    if graphPanel.yAxisLabels then
        for i = labelIndex, #graphPanel.yAxisLabels do
            graphPanel.yAxisLabels[i]:SetText("")
            graphPanel.yAxisLabels[i]:Hide()
        end
    end
    if graphPanel.yAxisRightLabels then
        for i = labelIndex, #graphPanel.yAxisRightLabels do
            graphPanel.yAxisRightLabels[i]:SetText("")
            graphPanel.yAxisRightLabels[i]:Hide()
        end
    end
end

local function IncludeGraphScaleValue(value, scale)
    value = tonumber(value)
    if not value or value <= 0 then return end

    scale.minValue = math.min(scale.minValue, value)
    scale.maxValue = math.max(scale.maxValue, value)
    scale.hasValue = true
end

local function RoundGraphScale(_, maxValue)
    local tickStep = GRAPH_Y_AXIS_STEP
    local upperValue = math.max(tickStep, tonumber(maxValue) or 0)
    upperValue = math.ceil(upperValue / tickStep) * tickStep

    return 0, upperValue, tickStep
end

local function GetFullSeriesGraphScale(points, showRating, showMMR)
    local scale = {
        minValue = math.huge,
        maxValue = 0,
        hasValue = false,
    }

    for i = 1, points and #points or 0 do
        if showRating then
            IncludeGraphScaleValue(GetHistoryPointRating(points[i]), scale)
        end
        if showMMR then
            IncludeGraphScaleValue(GetAlignedGraphMMR(points, i), scale)
        end
    end

    if not scale.hasValue then
        return nil, nil
    end

    return RoundGraphScale(scale.minValue, scale.maxValue)
end

local function GetGraphVisiblePointLimit(pointCount)
    local settings = Database.GetSettings()
    local requested = tonumber(settings.graphVisiblePointCount) or GRAPH_DEFAULT_VISIBLE_POINT_COUNT
    requested = math.floor((requested / GRAPH_VISIBLE_POINT_STEP) + 0.5) * GRAPH_VISIBLE_POINT_STEP
    requested = math.max(GRAPH_MIN_VISIBLE_POINT_COUNT, math.min(requested, GRAPH_MAX_VISIBLE_POINT_COUNT))
    return math.min(requested, pointCount)
end

local function GetSpecLabel(specID)
    specID = tonumber(specID)
    if not specID or specID == 0 then return nil end

    local _, name = GetSpecializationInfoByID(specID)
    return name
end

local function HideGraphHover()
    if not graphPanel then return end

    if graphPanel.hoverLine then
        graphPanel.hoverLine:Hide()
        if graphPanel.hoverLine.ClearAllPoints then
            graphPanel.hoverLine:ClearAllPoints()
        end
    end
    if graphPanel.hoverRatingDot then
        graphPanel.hoverRatingDot:Hide()
    end
    if graphPanel.hoverMMRDot then
        graphPanel.hoverMMRDot:Hide()
    end
    if GameTooltip:IsOwned(graphPanel.canvas) then
        GameTooltip:Hide()
    end
end

local function GetCanvasCursorPosition(canvas)
    local cursorX, cursorY = GetCursorPosition()
    local scale = canvas:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale

    local left = canvas:GetLeft()
    local top = canvas:GetTop()
    if not left or not top then return nil, nil end

    return cursorX - left, top - cursorY
end

local function SetHoverDot(dot, x, y, r, g, b)
    local hoverLayer = EnsureGraphHoverLayer()

    dot:SetSize(GRAPH_HOVER_POINT_SIZE, GRAPH_HOVER_POINT_SIZE)
    dot:SetColorTexture(r, g, b, 1)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", hoverLayer, "TOPLEFT", x, -y)
    dot:Show()
end

local function SetHistoryGraphViewportStart(start)
    if not graphPanel then return end

    local maxStart = graphPanel.maxViewportStart or 1
    start = math.floor((tonumber(start) or maxStart) + 0.5)
    start = math.max(1, math.min(start, maxStart))
    if graphPanel.viewportStart == start then return end

    graphPanel.viewportStart = start
    graphPanel.viewportAtLatest = start == maxStart
    HideGraphHover()
    UI.RefreshHistoryGraph()
end

local function ScrollHistoryGraph(delta)
    if not graphPanel or not graphPanel.maxViewportStart then return end

    local currentStart = graphPanel.viewportStart or graphPanel.maxViewportStart
    SetHistoryGraphViewportStart(currentStart - (delta * GRAPH_SCROLL_STEP))
end

local function UpdateGraphHover()
    if not graphPanel or not graphPanel.graphData then return end

    local data = graphPanel.graphData
    local cursorX, cursorY = GetCanvasCursorPosition(graphPanel.canvas)
    if not cursorX or not cursorY then
        HideGraphHover()
        return
    end

    local plotLeft = GRAPH_MARGIN_LEFT
    local plotRight = GRAPH_MARGIN_LEFT + data.plotWidth
    local plotTop = GRAPH_MARGIN_TOP
    local plotBottom = GRAPH_MARGIN_TOP + data.plotHeight
    if cursorX < plotLeft or cursorX > plotRight or cursorY < plotTop or cursorY > plotBottom then
        HideGraphHover()
        return
    end

    local visibleIndex
    if data.visiblePointCount <= 1 then
        visibleIndex = 1
    else
        visibleIndex = math.floor(((cursorX - GRAPH_MARGIN_LEFT) / data.xStep) + 0.5) + 1
        visibleIndex = math.max(1, math.min(visibleIndex, data.visiblePointCount))
    end

    local index = data.visibleStart + visibleIndex - 1
    local point = data.points[index]
    local pointX = data.visiblePointCount > 1 and (GRAPH_MARGIN_LEFT + (visibleIndex - 1) * data.xStep)
        or (GRAPH_MARGIN_LEFT + data.plotWidth / 2)
    local ratingY = GetGraphPointY(GetHistoryPointRating(point), data.minValue, data.maxValue, data.plotHeight)
    local mmr = data.mmrValues[index]
    local mmrY = mmr and GetGraphPointY(mmr, data.minValue, data.maxValue, data.plotHeight)

    local theme = GetActiveTheme()
    local hoverLayer = EnsureGraphHoverLayer()
    SetTextureColor(graphPanel.hoverLine, theme.text, 0.55)
    graphPanel.hoverLine:SetThickness(1.5)
    if graphPanel.hoverLine.ClearAllPoints then
        graphPanel.hoverLine:ClearAllPoints()
    end
    graphPanel.hoverLine:SetStartPoint("TOPLEFT", hoverLayer, pointX, -plotTop)
    graphPanel.hoverLine:SetEndPoint("TOPLEFT", hoverLayer, pointX, -plotBottom)
    graphPanel.hoverLine:Show()

    if data.showMMR and mmrY then
        SetHoverDot(graphPanel.hoverMMRDot, pointX, mmrY, data.mmrColor[1], data.mmrColor[2], data.mmrColor[3])
    else
        graphPanel.hoverMMRDot:Hide()
    end
    if data.showRating then
        SetHoverDot(graphPanel.hoverRatingDot, pointX, ratingY, data.ratingColor[1], data.ratingColor[2], data.ratingColor[3])
    else
        graphPanel.hoverRatingDot:Hide()
    end

    GameTooltip:SetOwner(graphPanel.canvas, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(FormatGraphTimestamp(point), 1, 1, 1)
    if data.showRating then
        GameTooltip:AddDoubleLine(
            "Rating",
            FormatGraphValue(GetHistoryPointRating(point)) .. FormatGraphDelta(GetHistoryPointRatingDelta(point)),
            data.ratingColor[1], data.ratingColor[2], data.ratingColor[3],
            1, 1, 1
        )
    end

    if data.showMMR then
        local mmrValue = "Pending next game"
        if mmr then
            mmrValue = FormatGraphValue(mmr)
            local previousMMR = data.mmrValues[index - 1]
            if previousMMR then
                mmrValue = mmrValue .. FormatGraphDelta(mmr - previousMMR)
            end
        end
        GameTooltip:AddDoubleLine(
            "MMR",
            mmrValue,
            data.mmrColor[1], data.mmrColor[2], data.mmrColor[3],
            1, 1, 1
        )
    end
    GameTooltip:Show()
end

local function UpdateHistoryGraphDockButton()
    if graphPanel and graphPanel.detachButton then
        graphPanel.detachButton:SetText(graphPanel.detached and "Attach" or "Detach")
    end
end

local function CloseHistoryGraph()
    if not graphPanel then return end

    selectedGraph = nil
    HideGraphHover()
    graphPanel:Hide()
    UpdateMainDockFrameSize()
    RefreshHistoryCellAffordances()
end

local function SetHistoryGraphDetached(detached)
    if not graphPanel then return end

    local wasShown = graphPanel:IsShown()
    HideGraphHover()

    if detached then
        graphPanel.detached = true
        graphPanel:SetParent(UIParent)
        graphPanel:ClearAllPoints()
        graphPanel:SetSize(GRAPH_DETACHED_WIDTH, GRAPH_DETACHED_HEIGHT)
        graphPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        graphPanel:SetFrameStrata("DIALOG")
        graphPanel:SetClampedToScreen(true)
    else
        if mainFrame and not mainFrame:IsShown() then
            mainFrame:Show()
        end
        graphPanel.detached = false
        graphPanel:SetParent(mainFrame)
        graphPanel:ClearAllPoints()
        graphPanel:SetHeight(GRAPH_PANEL_HEIGHT)
        graphPanel:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 0, 1)
        graphPanel:SetPoint("TOPRIGHT", mainFrame, "BOTTOMRIGHT", 0, 1)
        graphPanel:SetFrameStrata("HIGH")
        graphPanel:SetClampedToScreen(false)
    end

    UpdateMainDockFrameSize()
    UpdateHistoryGraphDockButton()
    UI.ApplyTheme()
    if wasShown then
        graphPanel:Show()
        UpdateMainDockFrameSize()
        UI.RefreshHistoryGraph()
    end
end

function UI.CreateHistoryGraphPanel()
    if graphPanel then return graphPanel end

    graphPanel = CreateFrame("Frame", "WarbandRatingsHistoryGraphPanel", mainFrame, "InsetFrameTemplate3")
    graphPanel.showRating = true
    graphPanel.showMMR = true
    graphPanel.detached = false
    graphPanel:SetHeight(GRAPH_PANEL_HEIGHT)
    graphPanel:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 0, 1)
    graphPanel:SetPoint("TOPRIGHT", mainFrame, "BOTTOMRIGHT", 0, 1)
    graphPanel:SetFrameStrata("HIGH")
    graphPanel:SetMovable(true)
    graphPanel:SetClampedToScreen(false)
    graphPanel:EnableMouse(true)
    graphPanel:RegisterForDrag("LeftButton")
    graphPanel:SetScript("OnDragStart", function(self)
        if self.detached then
            self:StartMoving()
        end
    end)
    graphPanel:SetScript("OnDragStop", function(self)
        if self.detached then
            self:StopMovingOrSizing()
        end
    end)
    graphPanel:SetScript("OnHide", function()
        selectedGraph = nil
        HideGraphHover()
        UpdateMainDockFrameSize()
        RefreshHistoryCellAffordances()
    end)
    graphPanel:Hide()
    HideTemplateArtwork(graphPanel)
    tinsert(UISpecialFrames, "WarbandRatingsHistoryGraphPanel")

    graphPanel.characterTitle = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    graphPanel.characterTitle:SetPoint("TOPLEFT", graphPanel, "TOPLEFT", 12, -10)
    graphPanel.characterTitle:SetJustifyH("LEFT")

    graphPanel.title = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    graphPanel.title:SetPoint("LEFT", graphPanel.characterTitle, "RIGHT", 0, 0)
    graphPanel.title:SetJustifyH("LEFT")

    graphPanel.closeButton = CreateFrame("Button", nil, graphPanel, "UIPanelCloseButton")
    graphPanel.closeButton:SetSize(22, 22)
    graphPanel.closeButton:SetPoint("TOPRIGHT", graphPanel, "TOPRIGHT", -4, -4)
    graphPanel.closeButton:SetScript("OnClick", CloseHistoryGraph)

    graphPanel.detachButton = CreateFrame("Button", nil, graphPanel, "UIPanelButtonTemplate")
    graphPanel.detachButton:SetSize(58, 20)
    graphPanel.detachButton:SetPoint("RIGHT", graphPanel.closeButton, "LEFT", -4, 0)
    graphPanel.detachButton:SetScript("OnClick", function()
        SetHistoryGraphDetached(not graphPanel.detached)
    end)
    UpdateHistoryGraphDockButton()

    graphPanel.canvas = CreateFrame("Frame", nil, graphPanel)
    graphPanel.canvas:SetPoint("TOPLEFT", graphPanel, "TOPLEFT", 8, -8)
    graphPanel.canvas:SetPoint("BOTTOMRIGHT", graphPanel, "BOTTOMRIGHT", -8, 8)
    graphPanel.canvas:EnableMouse(false)

    EnsureGraphDrawLayer()

    graphPanel.hoverFrame = CreateFrame("Frame", nil, graphPanel.canvas)
    graphPanel.hoverFrame:SetPoint("TOPLEFT", graphPanel.canvas, "TOPLEFT", GRAPH_MARGIN_LEFT, -GRAPH_MARGIN_TOP)
    graphPanel.hoverFrame:SetPoint("BOTTOMRIGHT", graphPanel.canvas, "BOTTOMRIGHT", -GRAPH_MARGIN_RIGHT, GRAPH_MARGIN_BOTTOM)
    graphPanel.hoverFrame:SetFrameLevel(graphPanel.canvas:GetFrameLevel() + 3)
    graphPanel.hoverFrame:EnableMouse(true)
    graphPanel.hoverFrame:SetScript("OnEnter", UpdateGraphHover)
    graphPanel.hoverFrame:SetScript("OnLeave", HideGraphHover)
    graphPanel.hoverFrame:SetScript("OnUpdate", UpdateGraphHover)
    graphPanel.hoverFrame:EnableMouseWheel(true)
    graphPanel.hoverFrame:SetScript("OnMouseWheel", function(_, delta)
        ScrollHistoryGraph(delta)
    end)

    local hoverLayer = EnsureGraphHoverLayer()

    graphPanel.hoverLine = hoverLayer:CreateLine(nil, "OVERLAY")
    graphPanel.hoverLine:Hide()

    graphPanel.hoverRatingDot = hoverLayer:CreateTexture(nil, "OVERLAY")
    graphPanel.hoverRatingDot:Hide()

    graphPanel.hoverMMRDot = hoverLayer:CreateTexture(nil, "OVERLAY")
    graphPanel.hoverMMRDot:Hide()

    graphPanel.emptyText = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    graphPanel.emptyText:SetPoint("CENTER", graphPanel.canvas, "CENTER", 0, 0)

    graphPanel.maxLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    graphPanel.maxLabel:SetPoint("TOPLEFT", graphPanel.canvas, "TOPLEFT", 4, -GRAPH_MARGIN_TOP)

    graphPanel.midLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    graphPanel.midLabel:SetPoint("LEFT", graphPanel.canvas, "LEFT", 4, 0)

    graphPanel.minLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    graphPanel.minLabel:SetPoint("BOTTOMLEFT", graphPanel.canvas, "BOTTOMLEFT", 4, GRAPH_MARGIN_BOTTOM - 6)

    graphPanel.gamesLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    graphPanel.gamesLabel:SetPoint("BOTTOMRIGHT", graphPanel.canvas, "BOTTOMRIGHT", -4, 8)
    graphPanel.gamesLabel:SetWidth(GRAPH_GAMES_LABEL_WIDTH)
    graphPanel.gamesLabel:SetJustifyH("RIGHT")

    graphPanel.zoomLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    graphPanel.zoomLabel:SetText("Games")
    graphPanel.zoomLabel:SetWidth(42)
    graphPanel.zoomLabel:SetJustifyH("RIGHT")

    graphPanel.zoomValueLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    graphPanel.zoomValueLabel:SetWidth(28)
    graphPanel.zoomValueLabel:SetJustifyH("LEFT")

    graphPanel.zoomSlider = CreateFrame("Slider", nil, graphPanel, "OptionsSliderTemplate")
    graphPanel.zoomSlider:SetWidth(108)
    graphPanel.zoomSlider:SetHeight(14)
    graphPanel.zoomSlider:SetMinMaxValues(GRAPH_MIN_VISIBLE_POINT_COUNT, GRAPH_MAX_VISIBLE_POINT_COUNT)
    graphPanel.zoomSlider:SetValueStep(GRAPH_VISIBLE_POINT_STEP)
    if graphPanel.zoomSlider.SetObeyStepOnDrag then
        graphPanel.zoomSlider:SetObeyStepOnDrag(true)
    end
    if graphPanel.zoomSlider.Text then
        graphPanel.zoomSlider.Text:SetText("")
    end
    if graphPanel.zoomSlider.Low then
        graphPanel.zoomSlider.Low:SetText("")
    end
    if graphPanel.zoomSlider.High then
        graphPanel.zoomSlider.High:SetText("")
    end
    graphPanel.zoomSlider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Visible games")
        if graphPanel.zoomDisabled then
            GameTooltip:AddLine("Available from " .. GRAPH_MIN_VISIBLE_POINT_COUNT .. " recorded games.", 1, 1, 1)
            GameTooltip:AddLine("Current history: " .. (graphPanel.zoomPointCount or 0) .. " games.", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Drag to show fewer or more games in the graph window.", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    graphPanel.zoomSlider:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    graphPanel.zoomSlider:SetScript("OnValueChanged", function(_, value)
        if graphPanel.updatingZoomSlider then return end
        if graphPanel.zoomDisabled then return end
        value = math.floor((value / GRAPH_VISIBLE_POINT_STEP) + 0.5) * GRAPH_VISIBLE_POINT_STEP
        Database.SetSetting("graphVisiblePointCount", value)
        if graphPanel.viewportAtLatest then
            graphPanel.viewportStart = nil
        end
        UI.RefreshHistoryGraph()
    end)

    graphPanel.rangeSlider = CreateFrame("Slider", nil, graphPanel, "OptionsSliderTemplate")
    graphPanel.rangeSlider:SetPoint("BOTTOMLEFT", graphPanel, "BOTTOMLEFT", GRAPH_MARGIN_LEFT + 8, 12)
    graphPanel.rangeSlider:SetPoint(
        "BOTTOMRIGHT",
        graphPanel,
        "BOTTOMRIGHT",
        -GRAPH_MARGIN_RIGHT - GRAPH_GAMES_LABEL_WIDTH - GRAPH_GAMES_LABEL_GAP,
        12
    )
    graphPanel.rangeSlider:SetHeight(14)
    graphPanel.rangeSlider:SetMinMaxValues(1, 1)
    graphPanel.rangeSlider:SetValueStep(1)
    if graphPanel.rangeSlider.SetObeyStepOnDrag then
        graphPanel.rangeSlider:SetObeyStepOnDrag(true)
    end
    if graphPanel.rangeSlider.Text then
        graphPanel.rangeSlider.Text:SetText("")
    end
    if graphPanel.rangeSlider.Low then
        graphPanel.rangeSlider.Low:SetText("")
    end
    if graphPanel.rangeSlider.High then
        graphPanel.rangeSlider.High:SetText("")
    end
    graphPanel.rangeSlider:SetScript("OnValueChanged", function(_, value)
        if graphPanel.updatingRangeSlider then return end
        SetHistoryGraphViewportStart(value)
    end)
    graphPanel.rangeSlider:Hide()

    graphPanel.ratingLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    graphPanel.ratingLabel:SetWidth(44)
    graphPanel.ratingLabel:SetJustifyH("LEFT")
    graphPanel.ratingLabel:SetPoint("RIGHT", graphPanel.detachButton, "LEFT", -12, 0)

    graphPanel.ratingToggle = CreateFrame("CheckButton", nil, graphPanel, "UICheckButtonTemplate")
    graphPanel.ratingToggle:SetSize(20, 20)
    graphPanel.ratingToggle:SetPoint("RIGHT", graphPanel.ratingLabel, "LEFT", -2, 0)
    graphPanel.ratingToggle:SetChecked(true)
    graphPanel.ratingToggle:SetScript("OnClick", function(self)
        graphPanel.showRating = self:GetChecked()
        UI.RefreshHistoryGraph()
    end)

    graphPanel.mmrLabel = graphPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    graphPanel.mmrLabel:SetWidth(32)
    graphPanel.mmrLabel:SetJustifyH("LEFT")
    graphPanel.mmrLabel:SetPoint("RIGHT", graphPanel.ratingToggle, "LEFT", -18, 0)

    graphPanel.mmrToggle = CreateFrame("CheckButton", nil, graphPanel, "UICheckButtonTemplate")
    graphPanel.mmrToggle:SetSize(20, 20)
    graphPanel.mmrToggle:SetPoint("RIGHT", graphPanel.mmrLabel, "LEFT", -2, 0)
    graphPanel.mmrToggle:SetChecked(true)
    graphPanel.mmrToggle:SetScript("OnClick", function(self)
        graphPanel.showMMR = self:GetChecked()
        UI.RefreshHistoryGraph()
    end)

    graphPanel.zoomValueLabel:SetPoint("RIGHT", graphPanel.mmrToggle, "LEFT", -30, 0)
    graphPanel.zoomSlider:SetPoint("RIGHT", graphPanel.zoomValueLabel, "LEFT", -8, 0)
    graphPanel.zoomLabel:SetPoint("RIGHT", graphPanel.zoomSlider, "LEFT", -6, 0)

    graphPanel:SetScript("OnSizeChanged", function()
        UI.RefreshHistoryGraph()
    end)

    return graphPanel
end

function UI.RefreshHistoryGraph()
    if not graphPanel or not graphPanel:IsShown() or not selectedGraph then return end

    ClearGraphDrawings()
    local theme = GetActiveTheme()

    local series = History and History.GetCurrentSeries(selectedGraph.charKey, selectedGraph.colKey, selectedGraph.specID)
    local points = series and series.points
    local pointCount = points and #points or 0

    graphPanel.characterTitle:SetText(selectedGraph.characterTitle)
    graphPanel.characterTitle:SetWidth(math.ceil(graphPanel.characterTitle:GetStringWidth()))
    graphPanel.title:SetText(selectedGraph.titleSuffix)
    local titleR, titleG, titleB = Utils.GetClassColor(selectedGraph.classFilename)
    graphPanel.characterTitle:SetTextColor(titleR, titleG, titleB)
    SetFontColor(graphPanel.title, theme.title)
    graphPanel.ratingLabel:SetText("Rating")
    graphPanel.mmrLabel:SetText("MMR")
    graphPanel.gamesLabel:SetText(pointCount .. " game" .. (pointCount == 1 and "" or "s"))
    SetFontColor(graphPanel.gamesLabel, theme.muted)
    SetFontColor(graphPanel.emptyText, theme.muted)
    SetFontColor(graphPanel.maxLabel, theme.muted)
    SetFontColor(graphPanel.midLabel, theme.muted)
    SetFontColor(graphPanel.minLabel, theme.muted)
    SetFontColor(graphPanel.zoomLabel, theme.muted)
    SetFontColor(graphPanel.zoomValueLabel, theme.muted)

    local showRating = graphPanel.showRating ~= false
    local showMMR = graphPanel.showMMR ~= false
    graphPanel.ratingToggle:SetChecked(showRating)
    graphPanel.mmrToggle:SetChecked(showMMR)

    local cr, cg, cb = Utils.GetClassColor(selectedGraph.classFilename)
    local mr, mg, mb = theme.mmr[1] or MMR_GRAPH_R, theme.mmr[2] or MMR_GRAPH_G, theme.mmr[3] or MMR_GRAPH_B
    if showRating then
        graphPanel.ratingLabel:SetTextColor(cr, cg, cb)
    else
        SetFontColor(graphPanel.ratingLabel, theme.muted, 0.75)
    end
    if showMMR then
        graphPanel.mmrLabel:SetTextColor(mr, mg, mb)
    else
        SetFontColor(graphPanel.mmrLabel, theme.muted, 0.75)
    end

    if pointCount == 0 then
        graphPanel.emptyText:SetText("No games recorded for this rating yet.")
        graphPanel.emptyText:Show()
        graphPanel.maxLabel:SetText("")
        graphPanel.midLabel:SetText("")
        graphPanel.minLabel:SetText("")
        graphPanel.gamesLabel:SetText("0 games")
        graphPanel.rangeSlider:Hide()
        graphPanel.zoomLabel:Hide()
        graphPanel.zoomSlider:Hide()
        graphPanel.zoomValueLabel:SetText("")
        graphPanel.zoomValueLabel:Hide()
        return
    end

    graphPanel.emptyText:Hide()

    local visiblePointCount = GetGraphVisiblePointLimit(pointCount)
    local zoomDisabled = pointCount < GRAPH_MIN_VISIBLE_POINT_COUNT
    local zoomMax = zoomDisabled and pointCount or math.min(pointCount, GRAPH_MAX_VISIBLE_POINT_COUNT)
    local zoomMin = zoomDisabled and pointCount or math.min(GRAPH_MIN_VISIBLE_POINT_COUNT, zoomMax)
    graphPanel.zoomDisabled = zoomDisabled
    graphPanel.zoomPointCount = pointCount
    graphPanel.zoomLabel:Show()
    graphPanel.zoomSlider:Show()
    graphPanel.zoomValueLabel:Show()
    graphPanel.zoomValueLabel:SetText(tostring(visiblePointCount))
    graphPanel.zoomLabel:SetAlpha(zoomDisabled and 0.55 or 1)
    graphPanel.zoomSlider:SetAlpha(zoomDisabled and 0.45 or 1)
    graphPanel.zoomValueLabel:SetAlpha(zoomDisabled and 0.55 or 1)
    graphPanel.zoomSlider:SetMinMaxValues(zoomMin, zoomMax)
    graphPanel.zoomSlider:SetValueStep(GRAPH_VISIBLE_POINT_STEP)
    graphPanel.updatingZoomSlider = true
    graphPanel.zoomSlider:SetValue(visiblePointCount)
    graphPanel.updatingZoomSlider = false

    local maxViewportStart = math.max(1, pointCount - visiblePointCount + 1)
    graphPanel.maxViewportStart = maxViewportStart

    if graphPanel.viewportAtLatest or not graphPanel.viewportStart or graphPanel.viewportStart > maxViewportStart then
        graphPanel.viewportStart = maxViewportStart
    end

    local visibleStart = math.max(1, math.min(graphPanel.viewportStart, maxViewportStart))
    local visibleEnd = math.min(pointCount, visibleStart + visiblePointCount - 1)
    visiblePointCount = visibleEnd - visibleStart + 1
    graphPanel.viewportStart = visibleStart
    graphPanel.viewportAtLatest = visibleStart == maxViewportStart

    if pointCount > visiblePointCount then
        graphPanel.gamesLabel:SetText(visibleStart .. "-" .. visibleEnd .. " / " .. pointCount .. " games")
        graphPanel.rangeSlider:Show()
        graphPanel.rangeSlider:SetMinMaxValues(1, maxViewportStart)
        graphPanel.rangeSlider:SetValueStep(1)
        graphPanel.updatingRangeSlider = true
        graphPanel.rangeSlider:SetValue(visibleStart)
        graphPanel.updatingRangeSlider = false
    else
        graphPanel.gamesLabel:SetText(pointCount .. " game" .. (pointCount == 1 and "" or "s"))
        graphPanel.rangeSlider:Hide()
    end

    local minValue, maxValue, tickStep = GetFullSeriesGraphScale(points, true, true)
    if not minValue then
        if not showRating and not showMMR then
            graphPanel.emptyText:SetText("Select Rating or MMR to show the graph.")
        else
            graphPanel.emptyText:SetText("No visible graph data yet.")
        end
        graphPanel.emptyText:Show()
        graphPanel.maxLabel:SetText("")
        graphPanel.midLabel:SetText("")
        graphPanel.minLabel:SetText("")
        HideGraphHover()
        return
    end

    local hasVisibleValue = false
    local mmrValues = {}
    for i = visibleStart, visibleEnd do
        local point = points[i]
        local rating = GetHistoryPointRating(point)
        local mmr = GetAlignedGraphMMR(points, i)
        mmrValues[i] = mmr
        if showRating and rating > 0 then
            hasVisibleValue = true
        end
        if showMMR and mmr then
            hasVisibleValue = true
        end
    end

    if not hasVisibleValue then
        if not showRating and not showMMR then
            graphPanel.emptyText:SetText("Select Rating or MMR to show the graph.")
        elseif showMMR and not showRating then
            graphPanel.emptyText:SetText("MMR is pending until the next game.")
        else
            graphPanel.emptyText:SetText("No visible graph data yet.")
        end
        graphPanel.emptyText:Show()
        graphPanel.maxLabel:SetText("")
        graphPanel.midLabel:SetText("")
        graphPanel.minLabel:SetText("")
        HideGraphHover()
        return
    end

    graphPanel.maxLabel:SetText("")
    graphPanel.midLabel:SetText("")
    graphPanel.minLabel:SetText("")

    local canvasWidth = math.max(graphPanel.canvas:GetWidth(), 1)
    local canvasHeight = math.max(graphPanel.canvas:GetHeight(), 1)
    local plotWidth = math.max(canvasWidth - GRAPH_MARGIN_LEFT - GRAPH_MARGIN_RIGHT, 1)
    local plotHeight = math.max(canvasHeight - GRAPH_MARGIN_TOP - GRAPH_MARGIN_BOTTOM, 1)
    local xStep = visiblePointCount > 1 and (plotWidth / (visiblePointCount - 1)) or 0
    graphPanel.graphData = {
        points = points,
        pointCount = pointCount,
        visibleStart = visibleStart,
        visibleEnd = visibleEnd,
        visiblePointCount = visiblePointCount,
        minValue = minValue,
        maxValue = maxValue,
        tickStep = tickStep,
        plotWidth = plotWidth,
        plotHeight = plotHeight,
        xStep = xStep,
        mmrValues = mmrValues,
        showRating = showRating,
        showMMR = showMMR,
        ratingColor = { cr, cg, cb },
        mmrColor = { mr, mg, mb },
    }

    DrawGraphYAxisLabels(minValue, maxValue, tickStep, plotWidth, plotHeight, theme)

    local minorTickValue = minValue + GRAPH_Y_AXIS_MINOR_STEP
    while minorTickValue < maxValue - 0.5 do
        if minorTickValue % tickStep ~= 0 then
            local y = GetGraphPointY(minorTickValue, minValue, maxValue, plotHeight)
            AddGraphLine(
                GRAPH_MARGIN_LEFT,
                y,
                GRAPH_MARGIN_LEFT + plotWidth,
                y,
                theme.grid[1],
                theme.grid[2],
                theme.grid[3],
                (theme.grid[4] or 0.25) * 0.75,
                1
            )
        end
        minorTickValue = minorTickValue + GRAPH_Y_AXIS_MINOR_STEP
    end

    local tickValue = minValue
    while tickValue <= maxValue + 0.5 do
        local y = GetGraphPointY(tickValue, minValue, maxValue, plotHeight)
        AddGraphLine(GRAPH_MARGIN_LEFT, y, GRAPH_MARGIN_LEFT + plotWidth, y, theme.grid[1], theme.grid[2], theme.grid[3], theme.grid[4], 1)
        tickValue = tickValue + tickStep
    end
    AddGraphLine(
        GRAPH_MARGIN_LEFT, GRAPH_MARGIN_TOP, GRAPH_MARGIN_LEFT, GRAPH_MARGIN_TOP + plotHeight,
        theme.axis[1], theme.axis[2], theme.axis[3], theme.axis[4], 1
    )
    AddGraphLine(
        GRAPH_MARGIN_LEFT, GRAPH_MARGIN_TOP + plotHeight, GRAPH_MARGIN_LEFT + plotWidth, GRAPH_MARGIN_TOP + plotHeight,
        theme.axis[1], theme.axis[2], theme.axis[3], theme.axis[4], 1
    )

    if showMMR then
        for i = visibleStart + 1, visibleEnd do
            local visibleIndex = i - visibleStart + 1
            local x1 = GRAPH_MARGIN_LEFT + (visibleIndex - 2) * xStep
            local x2 = GRAPH_MARGIN_LEFT + (visibleIndex - 1) * xStep
            local prevMMR = mmrValues[i - 1]
            local currentMMR = mmrValues[i]

            if prevMMR and currentMMR then
                local prevMMRY = GetGraphPointY(prevMMR, minValue, maxValue, plotHeight)
                local currentMMRY = GetGraphPointY(currentMMR, minValue, maxValue, plotHeight)
                AddGraphLine(x1, prevMMRY, x2, currentMMRY, mr, mg, mb, 0.9, 2)
            end
        end
    end

    if showRating then
        for i = visibleStart + 1, visibleEnd do
            local prev = points[i - 1]
            local current = points[i]
            local visibleIndex = i - visibleStart + 1
            local x1 = GRAPH_MARGIN_LEFT + (visibleIndex - 2) * xStep
            local x2 = GRAPH_MARGIN_LEFT + (visibleIndex - 1) * xStep
            local prevRatingY = GetGraphPointY(GetHistoryPointRating(prev), minValue, maxValue, plotHeight)
            local currentRatingY = GetGraphPointY(GetHistoryPointRating(current), minValue, maxValue, plotHeight)

            AddGraphLine(x1, prevRatingY, x2, currentRatingY, cr, cg, cb, 1, 2)
        end
    end

    if showMMR then
        for i = visibleStart, visibleEnd do
            if mmrValues[i] then
                local visibleIndex = i - visibleStart + 1
                local x = visiblePointCount > 1 and (GRAPH_MARGIN_LEFT + (visibleIndex - 1) * xStep)
                    or (GRAPH_MARGIN_LEFT + plotWidth / 2)
                local y = GetGraphPointY(mmrValues[i], minValue, maxValue, plotHeight)
                AddGraphDot(x, y, mr, mg, mb, 0.95, GRAPH_POINT_SIZE - 1)
            end
        end
    end

    if showRating then
        for i = visibleStart, visibleEnd do
            local point = points[i]
            local visibleIndex = i - visibleStart + 1
            local x = visiblePointCount > 1 and (GRAPH_MARGIN_LEFT + (visibleIndex - 1) * xStep)
                or (GRAPH_MARGIN_LEFT + plotWidth / 2)
            local y = GetGraphPointY(GetHistoryPointRating(point), minValue, maxValue, plotHeight)
            AddGraphDot(x, y, cr, cg, cb, 1)
        end
    end
end

function UI.ShowHistoryGraph(charData, specID, col)
    if not History or not Database.IsPVPColumn(col) then return end

    local charKey = Utils.CharKey(charData.name, charData.realm)
    local graphSpecID = Database.IsSpecColumn(col) and specID or 0
    if graphPanel and graphPanel:IsShown() and selectedGraph
        and selectedGraph.charKey == charKey
        and selectedGraph.specID == graphSpecID
        and selectedGraph.colKey == col.key then
        return
    end

    local specLabel = GetSpecLabel(specID)
    local characterTitle = charData.name .. "-" .. charData.realm
    local titleSuffix = " - " .. col.label
    if specLabel then
        titleSuffix = titleSuffix .. " (" .. specLabel .. ")"
    end

    selectedGraph = {
        charKey = charKey,
        specID = graphSpecID,
        colKey = col.key,
        classFilename = charData.classFilename,
        characterTitle = characterTitle,
        titleSuffix = titleSuffix,
    }

    UI.CreateHistoryGraphPanel()
    graphPanel.showRating = true
    graphPanel.showMMR = col.key ~= "soloShuffle"
    graphPanel.viewportStart = nil
    graphPanel.viewportAtLatest = true
    graphPanel:Show()
    UpdateMainDockFrameSize()
    RefreshHistoryCellAffordances()
    UI.RefreshHistoryGraph()
end

local function AddHistoryClickOverlay(row, x, y, w, h, charData, specID, col)
    if not Database.IsPVPColumn(col) then return end

    local overlay = AcquireOverlay(row)
    EnsureHistoryCellAffordance(overlay)
    overlay:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
    overlay:SetSize(w, h)
    overlay.historyCell = true
    overlay.historyHovered = false
    overlay.historyCharKey = Utils.CharKey(charData.name, charData.realm)
    overlay.historySpecID = Database.IsSpecColumn(col) and specID or 0
    overlay.historyColKey = col.key
    overlay.historyClassFilename = charData.classFilename
    UpdateHistoryCellAffordance(overlay, false)

    overlay:SetScript("OnEnter", function()
        SetRowHovered(row, true)
        overlay.historyHovered = true
        UpdateHistoryCellAffordance(overlay, true)
        UI.PVPTooltip.Show(overlay, charData, specID, col)
    end)
    overlay:SetScript("OnLeave", function()
        SetRowHovered(row, false)
        overlay.historyHovered = false
        UpdateHistoryCellAffordance(overlay, false)
        if GameTooltip:IsOwned(overlay) then
            GameTooltip:Hide()
        end
    end)
    overlay:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            UI.ShowHistoryGraph(charData, specID, col)
        end
    end)
end

local function AddConquestTooltipOverlay(row, x, y, w, h, charData, col)
    if col.key ~= "conquest" then return end

    local overlay = AcquireOverlay(row)
    overlay:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
    overlay:SetSize(w, h)

    local ratings = charData.ratings or {}
    overlay:SetScript("OnEnter", function(self)
        SetRowHovered(row, true)

        local info = C_CurrencyInfo
            and C_CurrencyInfo.GetCurrencyInfo
            and C_CurrencyInfo.GetCurrencyInfo(col.currencyID)
        local iconID = info and info.iconFileID
        local title = info and info.name or col.label
        local description = info and info.description

        if iconID then
            title = "|T" .. iconID .. ":16:16:0:0|t " .. title
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(title, 0.64, 0.21, 0.93)
        if description and description ~= "" then
            GameTooltip:AddLine(description, 1, 0.82, 0, true)
        end
        GameTooltip:AddDoubleLine(
            "Total:",
            FormatTooltipNumber(ratings.conquest),
            1, 0.82, 0,
            1, 1, 1
        )

        local seasonEarned = tonumber(ratings.conquest_totalEarned) or 0
        local seasonMaximum = tonumber(ratings.conquest_maxQuantity) or 0
        if seasonMaximum > 0 then
            GameTooltip:AddDoubleLine(
                "Season Maximum:",
                FormatTooltipNumber(seasonEarned) .. "/" .. FormatTooltipNumber(seasonMaximum),
                1, 0.82, 0,
                1, 1, 1
            )
        end

        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", function()
        SetRowHovered(row, false)
        GameTooltip:Hide()
    end)
end

function UI.RefreshTable()
    if not mainFrame or not mainFrame:IsShown() then return end
    ClearRows()
    UI.RefreshHeliotropeCounter()

    local groups = Database.GetFilteredCharacterGroups()
    local columns = Database.GetVisibleColumns(groups)
    UI.TableSort.SortGroups(groups, columns)
    local theme = GetActiveTheme()
    UI.ApplyTheme()

    -- Build header
    ResetCells(headerRow)

    local hx = TABLE_CONTENT_PADDING_X + ICON_SIZE + 4
    do
        local fs = AcquireFontString(headerRow, "GameFontNormal")
        fs:SetPoint("LEFT", headerRow, "LEFT", hx, 0)
        fs:SetWidth(COL_NAME_WIDTH)
        fs:SetJustifyH("LEFT")
        fs:SetText("Class / Character")
        SetFontColor(fs, theme.headerText)
        fs:Show()
        UI.TableSort.AddTextArrow(headerRow, "character", hx, COL_NAME_WIDTH, fs, "LEFT", theme)
        UI.TableSort.AddHeaderOverlay(hx, COL_NAME_WIDTH, "character")
        hx = hx + COL_NAME_WIDTH
    end
    for _, col in ipairs(columns) do
        local w = ColWidth(col)
        if col.currencyID then
            -- Render currency icon instead of text
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(col.currencyID)
            local iconID = info and info.iconFileID
            if iconID then
                local hasArrow = UI.TableSort.IsActive(col.key)
                local iconX = hx + (w - (hasArrow and 32 or 20)) / 2
                local ico = AcquireTexture(headerRow, "OVERLAY")
                ico:SetSize(20, 20)
                ico:SetPoint("LEFT", headerRow, "LEFT", iconX, 0)
                ico:SetTexture(iconID)
                ico:Show()
                if hasArrow then
                    UI.TableSort.AddArrow(headerRow, iconX + 24, UI.TableSort.direction, theme)
                end
            else
                local fs = AcquireFontString(headerRow, "GameFontNormal")
                fs:SetPoint("LEFT", headerRow, "LEFT", hx, 0)
                fs:SetWidth(w)
                fs:SetJustifyH("CENTER")
                fs:SetText(col.label)
                SetFontColor(fs, theme.headerText)
                fs:Show()
                UI.TableSort.AddTextArrow(headerRow, col.key, hx, w, fs, "CENTER", theme)
            end
            UI.TableSort.AddHeaderOverlay(hx, w, col.key)
        elseif col.crests then
            -- Render crest icons in header (highest to lowest, skip lowest tier)
            local iconSize = 16
            local gap = 2
            local displayCrests = {}
            for i = #col.crests, 2, -1 do  -- skip index 1 (adventurer)
                displayCrests[#displayCrests + 1] = col.crests[i]
            end
            local totalW = #displayCrests * iconSize + (#displayCrests - 1) * gap
            local startX = hx + (w - totalW) / 2
            for i, crest in ipairs(displayCrests) do
                local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(crest.currencyID)
                local iconID = info and info.iconFileID
                if iconID then
                    local ico = AcquireTexture(headerRow, "OVERLAY")
                    ico:SetSize(iconSize, iconSize)
                    ico:SetPoint("LEFT", headerRow, "LEFT", startX + (i - 1) * (iconSize + gap), 0)
                    ico:SetTexture(iconID)
                    ico:Show()
                end
            end
        else
            local fs = AcquireFontString(headerRow, "GameFontNormal")
            fs:SetPoint("LEFT", headerRow, "LEFT", hx, 0)
            fs:SetWidth(w)
            fs:SetJustifyH("CENTER")
            fs:SetText(col.label)
            SetFontColor(fs, theme.headerText)
            fs:Show()
            UI.TableSort.AddTextArrow(headerRow, col.key, hx, w, fs, "CENTER", theme)
            UI.TableSort.AddHeaderOverlay(hx, w, col.key)
        end
        hx = hx + w
    end

    -- Empty state
    if #groups == 0 then
        local row = GetOrCreateRow(1)
        StripRow(row)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        row:SetHeight(SUBROW_HEIGHT)
        local fs = AcquireFontString(row, "GameFontDisable")
        fs:SetPoint("LEFT", row, "LEFT", TABLE_CONTENT_PADDING_X, 0)
        fs:SetWidth(400)
        fs:SetText("No characters recorded yet. Log in on your characters to populate data.")
        SetFontColor(fs, theme.muted)
        fs:Show()
        scrollChild:SetHeight(SUBROW_HEIGHT)
        CenterMainDockFrameAfterInitialLayout()
        UI.RefreshHistoryGraph()
        return
    end

    local rowIndex = 0
    local yOff = 0
    for charIdx, grp in ipairs(groups) do
        local charData = grp.charData

        -- Only expand to subrows if at least one spec column has rating details
        -- Build list of specs that have a rating in any spec column
        local ratedSpecs = {}
        for _, specID in ipairs(grp.specs) do
            local specRatings = charData.specRatings and charData.specRatings[specID]
            if specRatings then
                for _, col in ipairs(columns) do
                    if Database.IsSpecColumn(col)
                        and not Utils.IsEmptyRating(specRatings[col.key]) then
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
            SetTextureColor(row.bg, theme.rowEven)
        else
            SetTextureColor(row.bg, theme.rowOdd)
        end
        row.bg:Show()

        -- Class icon (vertically centered)
        local classTexture, classCoords = Utils.GetClassIcon(charData.classFilename)
        if classTexture then
            local ico = AcquireTexture(row, "ARTWORK")
            ico:SetSize(ICON_SIZE, ICON_SIZE)
            ico:SetPoint("LEFT", row, "LEFT", TABLE_CONTENT_PADDING_X, 0)
            ico:SetTexture(classTexture)
            if classCoords then ico:SetTexCoord(unpack(classCoords)) end
            ico:Show()
        end

        local nameX = TABLE_CONTENT_PADDING_X + ICON_SIZE + 4

        -- Character name-realm (vertically centered like class icon)
        local nameFs = AcquireFontString(row, "GameFontNormal")
        nameFs:SetPoint("LEFT", row, "LEFT", nameX, 0)
        nameFs:SetWidth(COL_NAME_WIDTH)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetWordWrap(false)
        nameFs:SetNonSpaceWrap(false)
        local displayName = (charData.level or "?") .. "  " .. (charData.name or "?") .. "-" .. (charData.realm or "?")
        local cr, cg, cb = Utils.GetClassColor(charData.classFilename)
        nameFs:SetTextColor(cr, cg, cb)
        nameFs:SetText(displayName)
        nameFs:Show()

        -- Rating columns
        local colX = TABLE_CONTENT_PADDING_X + ICON_SIZE + 4 + COL_NAME_WIDTH
        for _, col in ipairs(columns) do
            local w = ColWidth(col)
            if Database.IsSpecColumn(col) then
                if #ratedSpecs > 0 then
                    -- Split cell: one sub-line per rated spec only
                    for specIdx, specID in ipairs(ratedSpecs) do
                        local specRatings = charData.specRatings and charData.specRatings[specID]
                        local val = specRatings and specRatings[col.key]
                        local subY = -(specIdx - 1) * SUBROW_HEIGHT

                        -- Spec icon (only if this column has rating details)
                        if not Utils.IsEmptyRating(val) then
                            local specIcon = Utils.GetSpecIcon(specID)
                            if specIcon then
                                local ico = AcquireTexture(row, "ARTWORK")
                                ico:SetSize(SPEC_ICON_SIZE, SPEC_ICON_SIZE)
                                local icoY = subY - (SUBROW_HEIGHT - SPEC_ICON_SIZE) / 2
                                ico:SetPoint("TOPLEFT", row, "TOPLEFT", colX + 2, icoY)
                                ico:SetTexture(specIcon)
                                ico:Show()
                            end
                        end

                        -- Rating text
                        local fs = AcquireFontString(row, "GameFontHighlight")
                        fs:SetPoint("TOPLEFT", row, "TOPLEFT", colX + SPEC_ICON_SIZE + 4, GetRatingTextY(subY))
                        fs:SetWidth(w - SPEC_ICON_SIZE - 6)
                        fs:SetJustifyH("CENTER")
                        fs:SetText(Utils.FormatRating(val))
                        SetFontColor(fs, Utils.IsEmptyRating(val) and theme.muted or theme.text)
                        fs:Show()
                        AddHistoryClickOverlay(row, colX, subY, w, SUBROW_HEIGHT, charData, specID, col)
                    end
                else
                    -- No spec has a rating: show single centered hyphen (offset to align with spec rating text)
                    local fs = AcquireFontString(row, "GameFontHighlight")
                    fs:SetPoint("LEFT", row, "LEFT", colX + SPEC_ICON_SIZE + 4, 0)
                    fs:SetWidth(w - SPEC_ICON_SIZE - 6)
                    fs:SetJustifyH("CENTER")
                    fs:SetText("-")
                    SetFontColor(fs, theme.muted)
                    fs:Show()
                end
            else
                -- Global column: single value, vertically centered
                local val = charData.ratings and charData.ratings[col.key]
                if col.crests then
                    -- Find highest tier with a value and show its icon + quantity
                    local highestCrest = nil
                    for i = #col.crests, 1, -1 do
                        local c = col.crests[i]
                        if (charData.ratings and charData.ratings[c.key] or 0) > 0 then
                            highestCrest = c
                            break
                        end
                    end
                    if highestCrest then
                        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(highestCrest.currencyID)
                        local iconID = info and info.iconFileID
                        local textW = 36
                        local totalW = (iconID and (ICON_SIZE + 2) or 0) + textW
                        local startX = colX + (w - totalW) / 2
                        if iconID then
                            local ico = AcquireTexture(row, "ARTWORK")
                            ico:SetSize(ICON_SIZE, ICON_SIZE)
                            ico:SetPoint("LEFT", row, "LEFT", startX, 0)
                            ico:SetTexture(iconID)
                            ico:Show()
                            startX = startX + ICON_SIZE + 2
                        end
                        local fs = AcquireFontString(row, "GameFontHighlight")
                        fs:SetPoint("LEFT", row, "LEFT", startX, 0)
                        fs:SetWidth(textW)
                        fs:SetJustifyH("CENTER")
                        fs:SetText(tostring(val))
                        SetFontColor(fs, theme.text)
                        fs:Show()
                    else
                        local fs = AcquireFontString(row, "GameFontHighlight")
                        fs:SetPoint("LEFT", row, "LEFT", colX, 0)
                        fs:SetWidth(w)
                        fs:SetJustifyH("CENTER")
                        fs:SetText("-")
                        SetFontColor(fs, theme.muted)
                        fs:Show()
                    end
                else
                    local formatFn = col.formatFn or Utils.FormatRating
                    local fs = AcquireFontString(row, "GameFontHighlight")
                    fs:SetPoint("LEFT", row, "LEFT", colX, 0)
                    fs:SetWidth(w)
                    fs:SetJustifyH("CENTER")
                    fs:SetText(formatFn(val))
                    SetFontColor(fs, GetGlobalColumnTextColor(col, val, theme))
                    fs:Show()
                    if Database.IsPVPColumn(col) then
                        AddHistoryClickOverlay(row, colX, 0, w, rowHeight, charData, 0, col)
                    end
                end

                AddConquestTooltipOverlay(row, colX, 0, w, rowHeight, charData, col)

                -- Tooltip overlay for crest columns
                if col.crests then
                    local overlay = AcquireOverlay(row)
                    overlay:SetPoint("LEFT", row, "LEFT", colX, 0)
                    overlay:SetSize(w, SUBROW_HEIGHT)
                    local ratings = charData.ratings
                    local crestDef = col.crests
                    overlay:SetScript("OnEnter", function(self)
                        SetRowHovered(row, true)
                        local hasAny = false
                        for _, c in ipairs(crestDef) do
                            if (ratings and ratings[c.key] or 0) > 0 then hasAny = true; break end
                        end
                        if not hasAny then return end
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        for i = #crestDef, 1, -1 do
                            local c = crestDef[i]
                            local qty = ratings and ratings[c.key] or 0
                            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(c.currencyID)
                            local iconID = info and info.iconFileID
                            local line = iconID and ("|T" .. iconID .. ":14:14:0:0|t " .. c.label) or c.label
                            GameTooltip:AddDoubleLine(line, tostring(qty), 0.8, 0.8, 0.8, 1, 1, 1)
                        end
                        GameTooltip:Show()
                    end)
                    overlay:SetScript("OnLeave", function()
                        SetRowHovered(row, false)
                        GameTooltip:Hide()
                    end)
                end

                if col.details then
                    local overlay = AcquireOverlay(row)
                    overlay:SetPoint("LEFT", row, "LEFT", colX, 0)
                    overlay:SetSize(w, SUBROW_HEIGHT)
                    local ratings = charData.ratings
                    local totalKey = col.key
                    local totalLabel = col.label
                    local details = col.details
                    overlay:SetScript("OnEnter", function(self)
                        SetRowHovered(row, true)
                        local hasAny = not Utils.IsEmptyRating(ratings and ratings[totalKey])
                        for _, detail in ipairs(details) do
                            if not Utils.IsEmptyRating(ratings and ratings[detail.key]) then
                                hasAny = true
                                break
                            end
                        end
                        if not hasAny then return end

                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        GameTooltip:AddDoubleLine(totalLabel, tostring(ratings and ratings[totalKey] or 0), 0.8, 0.8, 0.8, 1, 1, 1)
                        for _, detail in ipairs(details) do
                            GameTooltip:AddDoubleLine(detail.label, tostring(ratings and ratings[detail.key] or 0), 0.8, 0.8, 0.8, 1, 1, 1)
                        end
                        GameTooltip:Show()
                    end)
                    overlay:SetScript("OnLeave", function()
                        SetRowHovered(row, false)
                        GameTooltip:Hide()
                    end)
                end
            end
            colX = colX + w
        end

        yOff = yOff + rowHeight
    end

    scrollChild:SetHeight(math.max(yOff, 1))

    -- Resize window width to fit exactly the visible columns and themed content insets.
    local framePadding = TABLE_CONTENT_PADDING_X * 2
    local contentW = ICON_SIZE + 4 + COL_NAME_WIDTH
    for _, col in ipairs(columns) do
        contentW = contentW + ColWidth(col)
    end
    mainFrame:SetWidth(math.max(contentW + framePadding, WINDOW_MIN_WIDTH))
    CenterMainDockFrameAfterInitialLayout()
    UI.RefreshHistoryGraph()
end

------------------------------------------------------------
-- Toggle / Show / Hide
------------------------------------------------------------
function UI.Toggle()
    local frame = UI.CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        DataCollection.CollectCurrentCharacter()
        frame:Show()
        UI.RefreshTable()
    end
end

function UI.Show()
    local frame = UI.CreateMainFrame()
    DataCollection.CollectCurrentCharacter()
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
    local panel = UI.CreateSettingsPanel()
    if not panel:IsShown() then
        PositionSettingsPanelNearMain(panel)
        panel:Show()
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
