-- luacheck: globals Screenshot

local _, ns = ...

ns.SeasonUI = {}
local SeasonUI = ns.SeasonUI
local Database = ns.Database
local History = ns.History
local Season = ns.Season
local Utils = ns.Utils

local SELECTOR_BAR_HEIGHT = 32
local SELECTOR_BUTTON_HEIGHT = 22
local SELECTOR_OPTION_GAP = 4
local REWIND_CARD_WIDTH = 900
local REWIND_CARD_MIN_HEIGHT = 450
local REWIND_CONTENT_WIDTH = REWIND_CARD_WIDTH - 40
local REWIND_METRIC_COUNT = 5
local REWIND_METRIC_GAP = 10
local MVSPEC_ACTIVE_RULE_TEXT = "Rating above 1,000\nMore than 10 games or Shuffle rounds\nAt least 3 active brackets across the warband"
local MVSPEC_SCOPE_TEXT = "Grouped across every character of the same spec. Only Solo Shuffle and Solo BG contribute; team brackets stay spec-agnostic."
local REWIND_TILE_GAP = 12
local REWIND_COLUMN_COUNT = 3
local REWIND_SPEC_ROW_HEIGHT = 21
local REWIND_NON_SOLO_TILE_HEIGHT = 94
local REWIND_EMPTY_TILE_HEIGHT = 64
local REWIND_NON_SOLO_VALUE_WIDTH = 110
local REWIND_CONTENT_TOP = 173
local REWIND_BOTTOM_INSET = 49
local REWIND_ART_BACKGROUND_TEXTURE =
    "Interface\\AddOns\\WarbandRatings\\media\\rewind-card-background-generated.png"
local REWIND_ART_BACKGROUND_ALPHA = 0.32
local REWIND_ART_BACKGROUND_ASPECT_RATIO = 1717 / 916
local REWIND_ART_BACKGROUND_ZOOM = 1.18
local REWIND_ART_BACKGROUND_FOCUS_Y = 0.535
local REWIND_CARD_BACKGROUND_COLOR = { 0.020, 0.034, 0.046, 1 }
local REWIND_METRIC_BACKGROUND_ALPHA = 0.76
local REWIND_TILE_BACKGROUND_ALPHA = 0.70
local SCREENSHOT_CAPTURE_TIMEOUT = 5

local mainFrame
local seasonBar
local expansionSelector
local seasonSelector
local seasonStatus
local summaryButton
local rewindCard
local rewindContent
local mvpTooltip
local selectedExpansionKey
local selectedSeasonKey
local rewindTiles = {}
local activeTheme
local captureBackdrop
local captureInputBlocker
local captureController
local captureState

local CreateRewindCard
local RestoreScreenshotCapture

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

local function GetCropBounds(visibleFraction, focus)
    visibleFraction = math.max(0, math.min(1, visibleFraction))
    local maximumStart = 1 - visibleFraction
    local start = math.max(0, math.min(maximumStart, focus - (visibleFraction / 2)))
    return start, start + visibleFraction
end

local function EnsurePanelArtwork(frame)
    if frame.seasonUIBackground then return end

    frame.seasonUIBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.seasonUIBackground:SetAllPoints()
    frame.seasonUIBorders = {
        frame:CreateTexture(nil, "BORDER"),
        frame:CreateTexture(nil, "BORDER"),
        frame:CreateTexture(nil, "BORDER"),
        frame:CreateTexture(nil, "BORDER"),
    }
    frame.seasonUIBorders[1]:SetPoint("TOPLEFT")
    frame.seasonUIBorders[1]:SetPoint("TOPRIGHT")
    frame.seasonUIBorders[1]:SetHeight(1)
    frame.seasonUIBorders[2]:SetPoint("BOTTOMLEFT")
    frame.seasonUIBorders[2]:SetPoint("BOTTOMRIGHT")
    frame.seasonUIBorders[2]:SetHeight(1)
    frame.seasonUIBorders[3]:SetPoint("TOPLEFT")
    frame.seasonUIBorders[3]:SetPoint("BOTTOMLEFT")
    frame.seasonUIBorders[3]:SetWidth(1)
    frame.seasonUIBorders[4]:SetPoint("TOPRIGHT")
    frame.seasonUIBorders[4]:SetPoint("BOTTOMRIGHT")
    frame.seasonUIBorders[4]:SetWidth(1)
end

local function ApplyPanelTheme(frame, fill, border, fillAlpha)
    if not frame or not activeTheme then return end
    EnsurePanelArtwork(frame)
    SetTextureColor(frame.seasonUIBackground, fill, fillAlpha)
    for _, texture in ipairs(frame.seasonUIBorders) do
        SetTextureColor(texture, border)
    end
end

local function GetAvailableSeasonSet()
    local set = {}
    for _, seasonKey in ipairs(History.GetAvailableSeasonKeys()) do
        set[seasonKey] = true
    end
    return set
end

local function EnsureSelection()
    local settings = Database.GetSettings()
    local available = GetAvailableSeasonSet()
    local contentSeasonKey = History.GetContentSeasonKey()
    local preferredSeasonKey = selectedSeasonKey or settings.selectedSeasonKey

    if settings.selectionContentSeasonKey ~= contentSeasonKey then
        preferredSeasonKey = contentSeasonKey
        settings.selectionContentSeasonKey = contentSeasonKey
    end

    if not preferredSeasonKey or not available[preferredSeasonKey] then
        preferredSeasonKey = contentSeasonKey
    end

    selectedSeasonKey = preferredSeasonKey
    selectedExpansionKey = Season.GetSeasonInfo(preferredSeasonKey).expansionKey
    settings.selectedSeasonKey = selectedSeasonKey
    settings.selectedExpansionKey = selectedExpansionKey
end

local function CreateChoiceButton(parent, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, SELECTOR_BUTTON_HEIGHT)
    button.hovered = false

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.hover = button:CreateTexture(nil, "BORDER")
    button.hover:SetAllPoints()
    button.selectedBar = button:CreateTexture(nil, "OVERLAY")
    button.selectedBar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -3)
    button.selectedBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 3)
    button.selectedBar:SetWidth(3)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button, "LEFT", 11, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -23, 0)
    button.label:SetJustifyH("LEFT")
    button.arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.arrow:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.arrow:SetWidth(10)
    button.arrow:SetJustifyH("CENTER")

    button:SetScript("OnEnter", function(self)
        self.hovered = true
        SeasonUI.ApplyTheme()
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered = false
        SeasonUI.ApplyTheme()
    end)
    return button
end

local function ApplyChoiceButtonStyle(button, selected, emphasized)
    if not button or not activeTheme then return end

    SetTextureColor(button.bg, (selected or emphasized) and activeTheme.header or activeTheme.surfaceRaised)
    SetTextureColor(button.hover, activeTheme.rowHover)
    SetTextureColor(button.selectedBar, activeTheme.accent)
    SetFontColor(button.label, (selected or emphasized) and activeTheme.title or activeTheme.text)
    if button.arrow then
        SetFontColor(button.arrow, activeTheme.text)
    end
    button.selectedBar:SetShown(selected or emphasized)
    button.hover:SetShown(button.hovered and not selected)
end

local function HideMenus(exceptSelector)
    for _, selector in ipairs({ expansionSelector, seasonSelector }) do
        if selector and selector ~= exceptSelector then
            selector.menu:Hide()
            selector.button.arrow:SetText("v")
        end
    end
end

local function GetSelectorSelection(selector)
    return selector == expansionSelector and selectedExpansionKey or selectedSeasonKey
end

local function RefreshSelectorStyle(selector)
    if not selector then return end

    ApplyChoiceButtonStyle(selector.button, true)
    selector.button.arrow:SetText(selector.menu:IsShown() and "^" or "v")
    ApplyPanelTheme(selector.menu, activeTheme.surface, activeTheme.border)

    local selectedKey = GetSelectorSelection(selector)
    for _, button in ipairs(selector.optionButtons or {}) do
        if button:IsShown() then
            ApplyChoiceButtonStyle(button, button.optionKey == selectedKey)
        end
    end
end

local function RefreshSelectorMenu(selector, options, onSelect)
    selector.optionButtons = selector.optionButtons or {}

    for index, option in ipairs(options or {}) do
        local button = selector.optionButtons[index]
        if not button then
            button = CreateChoiceButton(selector.menu, selector.menuWidth - 8)
            button.arrow:Hide()
            selector.optionButtons[index] = button
        end

        local optionKey = option.key
        button.optionKey = optionKey
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            selector.menu,
            "TOPLEFT",
            4,
            -4 - ((index - 1) * (SELECTOR_BUTTON_HEIGHT + SELECTOR_OPTION_GAP))
        )
        button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button.label:SetText(option.label)
        button:SetScript("OnClick", function()
            selector.menu:Hide()
            onSelect(optionKey)
        end)
        button:Show()
    end

    for index = #(options or {}) + 1, #selector.optionButtons do
        selector.optionButtons[index]:Hide()
    end

    local optionCount = #(options or {})
    local height = 8 + (optionCount * SELECTOR_BUTTON_HEIGHT)
        + (math.max(optionCount - 1, 0) * SELECTOR_OPTION_GAP)
    selector.menu:SetHeight(math.max(height, 34))
    RefreshSelectorStyle(selector)
end

local function CreateSelector(parent, width)
    local selector = CreateFrame("Frame", nil, parent)
    selector:SetSize(width, SELECTOR_BUTTON_HEIGHT)
    selector.menuWidth = width

    selector.button = CreateChoiceButton(selector, width)
    selector.button:SetPoint("TOPLEFT", selector, "TOPLEFT", 0, 0)

    selector.menu = CreateFrame("Frame", nil, mainFrame)
    selector.menu:SetPoint("TOPLEFT", selector.button, "BOTTOMLEFT", 0, -4)
    selector.menu:SetSize(width, 34)
    selector.menu:SetFrameStrata("DIALOG")
    selector.menu:SetFrameLevel(mainFrame:GetFrameLevel() + 40)
    selector.menu:EnableMouse(true)
    selector.menu:Hide()
    EnsurePanelArtwork(selector.menu)

    selector.button:SetScript("OnClick", function()
        local shouldShow = not selector.menu:IsShown()
        HideMenus(selector)
        selector.menu:SetShown(shouldShow)
        RefreshSelectorStyle(selector)
    end)
    return selector
end

local function GetSpecDisplay(specID, classFilename)
    specID = tonumber(specID) or 0

    if GetSpecializationInfoByID then
        local _, specName, _, icon, _, apiClassFilename, className = GetSpecializationInfoByID(specID)
        if className and className ~= "" then
            local tooltip = specName and specName ~= "" and (className .. " - " .. specName) or className
            return icon, tooltip
        end
        classFilename = classFilename or apiClassFilename
    end

    local localizedNames = _G.LOCALIZED_CLASS_NAMES_MALE or {}
    local className = localizedNames[classFilename] or classFilename or "Unknown class"
    return nil, specID > 0 and (className .. " - Spec " .. specID) or className
end

local function SetClassIcon(texture, classFilename)
    local icon, coords = Utils.GetClassIcon(classFilename)
    texture:SetTexture(icon)
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
    local localizedNames = _G.LOCALIZED_CLASS_NAMES_MALE or {}
    return icon, localizedNames[classFilename] or classFilename or "Unknown class"
end

local function FormatNumber(value)
    return Utils.FormatNumber(tonumber(value) or 0)
end

local function RefreshMVSpecTooltip(mvSpec)
    if not mvpTooltip then return end

    if mvSpec then
        local total = tonumber(mvSpec.ratingTotal) or 0
        local count = tonumber(mvSpec.activeBracketCount) or 0
        local score = math.floor((tonumber(mvSpec.averageRating) or 0) + 0.5)
        mvpTooltip.score:SetText(FormatNumber(score))
        mvpTooltip.calculation:SetText(
            FormatNumber(total) .. " rating  /  " .. FormatNumber(count)
                .. " brackets  =  " .. FormatNumber(score)
        )
    else
        mvpTooltip.score:SetText("--")
        mvpTooltip.calculation:SetText("No specialization has three active brackets yet")
    end
end

local function GetMVSpecIcon(mvSpec)
    local specID = tonumber(mvSpec and mvSpec.specID) or 0
    if GetSpecializationInfoByID and specID > 0 then
        local _, _, _, icon = GetSpecializationInfoByID(specID)
        return icon
    end
    return nil
end

local function GetWinRate(counts)
    local wins = tonumber(counts and counts.wins) or 0
    local losses = tonumber(counts and counts.losses) or 0
    local decidedGames = wins + losses
    if decidedGames <= 0 then return 0 end
    return math.floor(((wins / decidedGames) * 100) + 0.5)
end

local function GetSelectedSeasonState()
    if selectedSeasonKey ~= History.GetContentSeasonKey() then
        return "ended"
    end

    local isActive = Season.IsRatedSeasonActive and Season.IsRatedSeasonActive()
    if isActive == true then return "active" end
    if isActive ~= false then return "unknown" end

    for _, bracket in ipairs(History.GetSeasonStatistics(selectedSeasonKey) or {}) do
        if (tonumber(bracket.total and bracket.total.games) or 0) > 0
            or (tonumber(bracket.maxRating) or 0) > 0
        then
            return "ended"
        end
    end
    return "inactive"
end

local function IsSelectedSeasonRewind()
    return GetSelectedSeasonState() == "ended"
end

local function ApplySeasonStatusStyle(state)
    if not seasonStatus or not activeTheme then return end
    if state == "active" then
        SetFontColor(seasonStatus, { 0.38, 0.86, 0.52, 1 })
    elseif state == "ended" then
        SetFontColor(seasonStatus, activeTheme.accent)
    else
        SetFontColor(seasonStatus, activeTheme.muted)
    end
end

local function GetRewindTitle()
    local info = Season.GetSeasonInfo(selectedSeasonKey)
    local state = GetSelectedSeasonState()
    if state ~= "ended" then
        local period = state == "inactive" and "SEASON NOT ACTIVE" or "SEASON IN PROGRESS"
        if info.isLegacy then
            return info.label .. " Statistics", period
        end
        return "Season " .. info.number .. " Statistics", period
    elseif info.isLegacy then
        return info.label .. " Rewind", "SEASON RECAP"
    end
    return "Season " .. info.number .. " Rewind", "SEASON RECAP"
end

local function CreateMetric(parent, index, label, valueScale)
    local width = (
        REWIND_CONTENT_WIDTH - (REWIND_METRIC_GAP * (REWIND_METRIC_COUNT - 1))
    ) / REWIND_METRIC_COUNT
    local metric = CreateFrame("Frame", nil, parent)
    metric:SetSize(width, 54)
    metric:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        20 + ((index - 1) * (width + REWIND_METRIC_GAP)),
        -80
    )
    EnsurePanelArtwork(metric)

    metric.label = metric:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    metric.label:SetPoint("TOP", metric, "TOP", 0, -9)
    metric.label:SetText(label)
    metric.value = metric:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    metric.value:SetPoint("CENTER", metric, "CENTER", 0, -8)
    metric.value:SetScale(valueScale or 1.25)
    return metric
end

local function AcquireSpecRow(tile, index)
    tile.specRows = tile.specRows or {}
    local row = tile.specRows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, tile)
    row:SetHeight(REWIND_SPEC_ROW_HEIGHT)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(15, 15)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconHitbox = CreateFrame("Button", nil, row)
    row.iconHitbox:SetSize(20, REWIND_SPEC_ROW_HEIGHT)
    row.iconHitbox:SetPoint("LEFT", row, "LEFT", -2, 0)
    row.iconHitbox:SetScript("OnEnter", function(self)
        if not self.tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText)
        GameTooltip:Show()
    end)
    row.iconHitbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.record = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.record:SetPoint("RIGHT", row, "RIGHT", -124, 0)
    row.record:SetWidth(110)
    row.record:SetJustifyH("RIGHT")
    row.winRate = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.winRate:SetPoint("RIGHT", row, "RIGHT", -78, 0)
    row.winRate:SetWidth(38)
    row.winRate:SetJustifyH("RIGHT")
    row.maxRating = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.maxRating:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.maxRating:SetWidth(70)
    row.maxRating:SetJustifyH("RIGHT")
    for _, fontString in ipairs({ row.record, row.winRate, row.maxRating }) do
        if fontString.SetWordWrap then fontString:SetWordWrap(false) end
        if fontString.SetMaxLines then fontString:SetMaxLines(1) end
    end
    tile.specRows[index] = row
    return row
end

local function AcquireRewindTile(index)
    local tile = rewindTiles[index]
    if tile then return tile end

    tile = CreateFrame("Frame", nil, rewindContent)
    EnsurePanelArtwork(tile)
    tile.accent = tile:CreateTexture(nil, "ARTWORK")
    tile.accent:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
    tile.accent:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -1, -1)
    tile.accent:SetHeight(3)
    tile.title = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tile.title:SetPoint("TOPLEFT", tile, "TOPLEFT", 11, -11)
    tile.title:SetPoint("RIGHT", tile, "RIGHT", -105, 0)
    tile.title:SetJustifyH("LEFT")
    tile.games = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.games:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -10, -12)
    tile.games:SetWidth(92)
    tile.games:SetJustifyH("RIGHT")
    tile.record = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.record:SetPoint("TOPLEFT", tile.title, "BOTTOMLEFT", 0, -9)
    tile.rate = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.rate:SetPoint("LEFT", tile.record, "RIGHT", 12, 0)
    tile.bracketMaxRating = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.bracketMaxRating:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -10, -39)
    tile.bracketMaxRating:SetJustifyH("RIGHT")
    if tile.bracketMaxRating.SetWordWrap then tile.bracketMaxRating:SetWordWrap(false) end
    if tile.bracketMaxRating.SetMaxLines then tile.bracketMaxRating:SetMaxLines(1) end
    tile.bracketBestLabel = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.bracketBestLabel:SetPoint("RIGHT", tile.bracketMaxRating, "LEFT", -4, 0)
    tile.bracketBestLabel:SetText("Best rating")
    tile.bracketClassIcon = tile:CreateTexture(nil, "ARTWORK")
    tile.bracketClassIcon:SetSize(15, 15)
    tile.bracketClassIcon:SetPoint("LEFT", tile.bracketMaxRating, "RIGHT", 4, 0)
    tile.bracketClassIconHitbox = CreateFrame("Button", nil, tile)
    tile.bracketClassIconHitbox:SetSize(20, 20)
    tile.bracketClassIconHitbox:SetPoint("CENTER", tile.bracketClassIcon, "CENTER", 0, 0)
    tile.bracketClassIconHitbox:SetScript("OnEnter", function(self)
        if not self.tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText)
        GameTooltip:Show()
    end)
    tile.bracketClassIconHitbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    tile.mostPlayedLabel = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.mostPlayedLabel:SetText("Most played")
    tile.mostPlayedGames = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.mostPlayedClassIcon = tile:CreateTexture(nil, "ARTWORK")
    tile.mostPlayedClassIcon:SetSize(15, 15)
    tile.mostPlayedClassIconHitbox = CreateFrame("Button", nil, tile)
    tile.mostPlayedClassIconHitbox:SetSize(20, 20)
    tile.mostPlayedClassIconHitbox:SetPoint("CENTER", tile.mostPlayedClassIcon, "CENTER", 0, 0)
    tile.mostPlayedClassIconHitbox:SetScript("OnEnter", function(self)
        if not self.tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText)
        GameTooltip:Show()
    end)
    tile.mostPlayedClassIconHitbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    tile.noData = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.noData:SetPoint("CENTER", tile, "CENTER", 0, 0)
    tile.noData:SetText("No data")
    tile.separator = tile:CreateTexture(nil, "ARTWORK")
    tile.separator:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -61)
    tile.separator:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -8, -61)
    tile.separator:SetHeight(1)
    tile.recordHeader = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.recordHeader:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -132, -68)
    tile.recordHeader:SetWidth(110)
    tile.recordHeader:SetJustifyH("RIGHT")
    tile.recordHeader:SetText("Record")
    tile.winRateHeader = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.winRateHeader:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -86, -68)
    tile.winRateHeader:SetWidth(38)
    tile.winRateHeader:SetJustifyH("RIGHT")
    tile.winRateHeader:SetText("Win %")
    tile.maxRatingHeader = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.maxRatingHeader:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -8, -68)
    tile.maxRatingHeader:SetWidth(70)
    tile.maxRatingHeader:SetJustifyH("RIGHT")
    tile.maxRatingHeader:SetText("Best")
    rewindTiles[index] = tile
    return tile
end

local function ConfigureRewindTile(tile, bracket, width)
    local visibleSpecs = {}
    for _, spec in ipairs(bracket.specs or {}) do
        if (tonumber(spec.games) or 0) > 0 or (tonumber(spec.recordedGames) or 0) > 0 then
            visibleSpecs[#visibleSpecs + 1] = spec
        end
    end

    local isSpecBracket = bracket.perSpec == true
        or bracket.key == "soloShuffle"
        or bracket.key == "soloBG"
    local hasSpecs = #visibleSpecs > 0
    local hasData = (tonumber(bracket.total.games) or 0) > 0
    local showNoData = not hasData and not hasSpecs
    local showNonSoloDetails = not isSpecBracket and hasData
    local height = showNoData and REWIND_EMPTY_TILE_HEIGHT
        or (hasSpecs and (88 + (#visibleSpecs * REWIND_SPEC_ROW_HEIGHT))
            or (not isSpecBracket and REWIND_NON_SOLO_TILE_HEIGHT or 72))
    local unitLabel = bracket.unit == "rounds" and "Rounds" or "Games"
    local partialSuffix = bracket.partial and "+" or ""
    tile:SetSize(width, height)
    tile.title:SetText(string.upper(bracket.label))
    tile.games:SetText(FormatNumber(bracket.total.games) .. partialSuffix .. " " .. unitLabel)
    tile.games:SetShown(not showNoData)

    tile.record:ClearAllPoints()
    tile.rate:ClearAllPoints()
    tile.bracketBestLabel:ClearAllPoints()
    tile.bracketMaxRating:ClearAllPoints()
    tile.bracketClassIcon:ClearAllPoints()
    tile.mostPlayedLabel:ClearAllPoints()
    tile.mostPlayedGames:ClearAllPoints()
    tile.mostPlayedClassIcon:ClearAllPoints()
    tile.rate:SetPoint("LEFT", tile, "TOPLEFT", 11, -39)
    tile.record:SetPoint("RIGHT", tile, "TOPRIGHT", -10, -39)
    tile.record:SetWidth(REWIND_NON_SOLO_VALUE_WIDTH)
    tile.record:SetJustifyH("LEFT")
    tile.bracketBestLabel:SetPoint("LEFT", tile, "TOPLEFT", 11, -59)
    tile.bracketMaxRating:SetPoint(
        "LEFT",
        tile,
        "TOPRIGHT",
        -10 - REWIND_NON_SOLO_VALUE_WIDTH,
        -59
    )
    tile.bracketMaxRating:SetJustifyH("LEFT")
    tile.bracketClassIcon:SetPoint("LEFT", tile.bracketMaxRating, "RIGHT", 4, 0)
    tile.mostPlayedLabel:SetPoint("LEFT", tile, "TOPLEFT", 11, -79)
    tile.mostPlayedGames:SetPoint(
        "LEFT",
        tile,
        "TOPRIGHT",
        -10 - REWIND_NON_SOLO_VALUE_WIDTH,
        -79
    )
    tile.mostPlayedClassIcon:SetPoint("LEFT", tile.mostPlayedGames, "RIGHT", 4, 0)

    if hasData then
        tile.record:SetText(FormatNumber(bracket.total.wins) .. "W  /  " .. FormatNumber(bracket.total.losses) .. "L")
        tile.rate:SetText(GetWinRate(bracket.total) .. "% win rate" .. (bracket.partial and "  /  partial" or ""))
    else
        tile.record:SetText(bracket.partial and "Season totals unavailable" or "0W  /  0L")
        tile.rate:SetText("")
    end
    tile.record:SetShown(not showNoData)
    tile.rate:SetShown(not showNoData)
    tile.noData:SetShown(showNoData)
    tile.separator:SetShown(hasSpecs)
    tile.recordHeader:SetShown(hasSpecs)
    tile.winRateHeader:SetShown(hasSpecs)
    tile.maxRatingHeader:SetShown(hasSpecs)
    tile.bracketBestLabel:SetShown(showNonSoloDetails)
    tile.bracketMaxRating:SetShown(showNonSoloDetails)
    tile.bracketMaxRating:SetText(
        (tonumber(bracket.maxRating) or 0) > 0 and FormatNumber(bracket.maxRating) or "--"
    )
    local bracketClassIcon, bracketClassTooltip = SetClassIcon(
        tile.bracketClassIcon,
        bracket.maxRatingClassFilename
    )
    tile.bracketClassIcon:SetShown(showNonSoloDetails and bracketClassIcon ~= nil)
    tile.bracketClassIconHitbox.tooltipText = bracketClassTooltip
    tile.bracketClassIconHitbox:SetShown(
        showNonSoloDetails and bracketClassIcon ~= nil and bracketClassTooltip ~= nil
    )
    local mostPlayedGames = tonumber(bracket.mostPlayedGames) or 0
    tile.mostPlayedLabel:SetShown(showNonSoloDetails)
    tile.mostPlayedGames:SetShown(showNonSoloDetails)
    tile.mostPlayedGames:SetText(mostPlayedGames > 0 and (FormatNumber(mostPlayedGames) .. " Games") or "--")
    local mostPlayedClassIcon, mostPlayedClassTooltip = SetClassIcon(
        tile.mostPlayedClassIcon,
        bracket.mostPlayedClassFilename
    )
    tile.mostPlayedClassIcon:SetShown(showNonSoloDetails and mostPlayedClassIcon ~= nil)
    tile.mostPlayedClassIconHitbox.tooltipText = mostPlayedClassTooltip
    tile.mostPlayedClassIconHitbox:SetShown(
        showNonSoloDetails and mostPlayedClassIcon ~= nil and mostPlayedClassTooltip ~= nil
    )

    for index, spec in ipairs(visibleSpecs) do
        local row = AcquireSpecRow(tile, index)
        local icon, tooltipText = GetSpecDisplay(spec.specID, spec.classFilename)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -84 - ((index - 1) * REWIND_SPEC_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -8, -84 - ((index - 1) * REWIND_SPEC_ROW_HEIGHT))
        row.icon:SetTexture(icon)
        row.icon:SetShown(icon ~= nil)
        row.iconHitbox.tooltipText = tooltipText
        row.iconHitbox:SetShown(icon ~= nil and tooltipText ~= nil)
        if spec.seasonTotalsUnavailable then
            row.record:SetText(FormatNumber(spec.recordedGames) .. " lobbies*")
            row.winRate:SetText("--")
        else
            local unitShort = bracket.unit == "rounds" and "R" or "G"
            row.record:SetText(
                FormatNumber(spec.games) .. unitShort .. " "
                    .. FormatNumber(spec.wins) .. "W " .. FormatNumber(spec.losses) .. "L"
            )
            row.winRate:SetText(GetWinRate(spec) .. "%")
        end
        row.maxRating:SetText((tonumber(spec.maxRating) or 0) > 0 and FormatNumber(spec.maxRating) or "--")
        row:Show()
    end
    for index = #visibleSpecs + 1, #(tile.specRows or {}) do
        tile.specRows[index]:Hide()
    end
    tile:Show()
    return height
end

local function ApplyRewindTheme()
    if not rewindCard or not activeTheme then return end

    ApplyPanelTheme(rewindCard, REWIND_CARD_BACKGROUND_COLOR, activeTheme.accent, 1)
    for _, border in ipairs(rewindCard.seasonUIBorders) do
        border:Hide()
    end
    rewindCard.artBackground:SetAlpha(REWIND_ART_BACKGROUND_ALPHA)
    rewindCard.headerWash:Hide()
    SetTextureColor(rewindCard.accentLine, activeTheme.accent)
    SetFontColor(rewindCard.period, activeTheme.headerText)
    SetFontColor(rewindCard.title, activeTheme.title)
    SetFontColor(rewindCard.subtitle, activeTheme.muted)
    SetFontColor(rewindCard.sectionTitle, activeTheme.headerText)
    SetFontColor(rewindCard.footer, activeTheme.muted)
    SetFontColor(rewindCard.closeButton.label, activeTheme.text)
    SetTextureColor(rewindCard.closeButton.hover, activeTheme.rowHover)
    rewindCard.closeButton.hover:SetShown(rewindCard.closeButton.hovered)
    if rewindCard.captureButton then
        SetTextureColor(rewindCard.captureButton.hover, activeTheme.rowHover)
        rewindCard.captureButton.hover:SetShown(rewindCard.captureButton.hovered)
    end

    for index, metric in ipairs(rewindCard.metrics or {}) do
        ApplyPanelTheme(
            metric,
            activeTheme.surfaceRaised,
            activeTheme.border,
            REWIND_METRIC_BACKGROUND_ALPHA
        )
        SetFontColor(metric.label, activeTheme.headerText)
        SetFontColor(metric.value, index <= 3 and activeTheme.title or activeTheme.text)
    end

    if mvpTooltip then
        ApplyPanelTheme(mvpTooltip, activeTheme.surfaceRaised, activeTheme.accent, 0.98)
        SetTextureColor(mvpTooltip.accent, activeTheme.accent)
        SetTextureColor(mvpTooltip.separator, activeTheme.border, 0.7)
        SetFontColor(mvpTooltip.title, activeTheme.headerText)
        SetFontColor(mvpTooltip.score, activeTheme.title)
        SetFontColor(mvpTooltip.calculationLabel, activeTheme.headerText)
        SetFontColor(mvpTooltip.calculation, activeTheme.text)
        SetFontColor(mvpTooltip.eligibilityLabel, activeTheme.headerText)
        SetFontColor(mvpTooltip.eligibility, activeTheme.text)
        SetFontColor(mvpTooltip.scope, activeTheme.muted)
    end

    for _, tile in ipairs(rewindTiles) do
        if tile:IsShown() then
            ApplyPanelTheme(tile, activeTheme.surface, activeTheme.border, REWIND_TILE_BACKGROUND_ALPHA)
            SetTextureColor(tile.accent, activeTheme.accent, 0.85)
            SetTextureColor(tile.separator, activeTheme.border, 0.55)
            SetFontColor(tile.title, activeTheme.title)
            SetFontColor(tile.games, activeTheme.headerText)
            SetFontColor(tile.record, activeTheme.text)
            SetFontColor(tile.rate, activeTheme.muted)
            SetFontColor(tile.bracketBestLabel, activeTheme.muted)
            SetFontColor(tile.bracketMaxRating, activeTheme.title)
            SetFontColor(tile.mostPlayedLabel, activeTheme.muted)
            SetFontColor(tile.mostPlayedGames, activeTheme.text)
            SetFontColor(tile.noData, activeTheme.muted)
            SetFontColor(tile.recordHeader, activeTheme.headerText)
            SetFontColor(tile.winRateHeader, activeTheme.headerText)
            SetFontColor(tile.maxRatingHeader, activeTheme.headerText)
            for rowIndex, row in ipairs(tile.specRows or {}) do
                if row:IsShown() then
                    SetTextureColor(row.bg, rowIndex % 2 == 0 and activeTheme.rowEven or activeTheme.rowOdd)
                    SetFontColor(row.record, activeTheme.muted)
                    SetFontColor(row.winRate, activeTheme.headerText)
                    SetFontColor(row.maxRating, activeTheme.title)
                end
            end
        end
    end
end

local function RefreshRewindCard()
    if not rewindCard then return end

    local statistics = History.GetSeasonStatistics(selectedSeasonKey)
    local mvSpec = History.GetSeasonMVSpec(selectedSeasonKey)
    local ratedGames = 0
    local peakRating = 0
    local ratedGamesPartial = false
    local playedClasses = {}
    local playedSpecs = {}
    for _, bracket in ipairs(statistics) do
        ratedGames = ratedGames + (tonumber(bracket.total.games) or 0)
        ratedGamesPartial = ratedGamesPartial or bracket.partial
        peakRating = math.max(peakRating, tonumber(bracket.maxRating) or 0)
        for _, classFilename in ipairs(bracket.classes or {}) do
            playedClasses[classFilename] = true
        end
        for _, spec in ipairs(bracket.specs or {}) do
            if (tonumber(spec.games) or 0) > 0 or (tonumber(spec.recordedGames) or 0) > 0 then
                playedSpecs[tonumber(spec.specID) or spec.specID] = true
                if spec.classFilename then
                    playedClasses[spec.classFilename] = true
                end
            end
        end
    end
    local specsPlayed = 0
    for _ in pairs(playedSpecs) do specsPlayed = specsPlayed + 1 end
    local classesPlayed = 0
    for _ in pairs(playedClasses) do classesPlayed = classesPlayed + 1 end

    local title, period = GetRewindTitle()
    local seasonInfo = Season.GetSeasonInfo(selectedSeasonKey)
    local expansionInfo = Season.GetExpansionInfo(seasonInfo.expansionKey)
    local expansionIcon = expansionInfo and expansionInfo.icon
    rewindCard.title:SetText(title)
    rewindCard.period:SetText(period)
    rewindCard.expansionIcon:SetTexture(expansionIcon)
    rewindCard.expansionIcon:SetShown(expansionIcon ~= nil)
    rewindCard.title:ClearAllPoints()
    if expansionIcon then
        rewindCard.title:SetPoint("LEFT", rewindCard.expansionIcon, "RIGHT", 10, 0)
    else
        rewindCard.title:SetPoint("TOPLEFT", rewindCard, "TOPLEFT", 20, -26)
    end
    rewindCard.title:SetPoint("RIGHT", rewindCard, "RIGHT", -50, 0)
    rewindCard.subtitle:SetText("Your warband's rated PvP season at a glance")
    rewindCard.metrics[1].value:SetText(FormatNumber(ratedGames) .. (ratedGamesPartial and "+" or ""))
    rewindCard.metrics[2].value:SetText(peakRating > 0 and FormatNumber(peakRating) or "--")
    if mvSpec then
        local specIcon = GetMVSpecIcon(mvSpec)
        rewindCard.metrics[3].value:SetText(
            specIcon and ("|T" .. specIcon .. ":18:18:0:0|t") or "--"
        )
    else
        rewindCard.metrics[3].value:SetText("--")
    end
    RefreshMVSpecTooltip(mvSpec)
    rewindCard.metrics[4].value:SetText(FormatNumber(classesPlayed))
    rewindCard.metrics[5].value:SetText(FormatNumber(specsPlayed))
    rewindCard.footer:SetText(ns.DISPLAY_NAME or "Warband PvP Companion")

    local tileWidth = (
        REWIND_CONTENT_WIDTH - (REWIND_TILE_GAP * (REWIND_COLUMN_COUNT - 1))
    ) / REWIND_COLUMN_COUNT
    local columnHeights = {}
    for column = 1, REWIND_COLUMN_COUNT do
        columnHeights[column] = 0
    end
    local fixedColumns = {
        soloShuffle = 1,
        soloBG = 2,
        arena2v2 = 3,
        arena3v3 = 3,
        rbg10v10 = 3,
    }
    for index, bracket in ipairs(statistics) do
        local tile = AcquireRewindTile(index)
        local column = fixedColumns[bracket.key]
        if not column then
            column = 1
            for candidate = 2, REWIND_COLUMN_COUNT do
                if columnHeights[candidate] < columnHeights[column] then
                    column = candidate
                end
            end
        end
        local x = (column - 1) * (tileWidth + REWIND_TILE_GAP)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", rewindContent, "TOPLEFT", x, -columnHeights[column])
        local tileHeight = ConfigureRewindTile(tile, bracket, tileWidth)
        columnHeights[column] = columnHeights[column] + tileHeight + REWIND_TILE_GAP
    end
    for index = #statistics + 1, #rewindTiles do
        rewindTiles[index]:Hide()
    end

    local contentHeight = 1
    for column = 1, REWIND_COLUMN_COUNT do
        local usedHeight = math.max(columnHeights[column] - REWIND_TILE_GAP, 0)
        contentHeight = math.max(contentHeight, usedHeight)
    end
    rewindContent:SetHeight(contentHeight)
    local cardHeight = math.max(
        REWIND_CARD_MIN_HEIGHT,
        REWIND_CONTENT_TOP + contentHeight + REWIND_BOTTOM_INSET
    )
    rewindCard:SetHeight(cardHeight)
    rewindCard.artBackground:SetSize(REWIND_CARD_WIDTH, cardHeight)
    local cardAspectRatio = REWIND_CARD_WIDTH / cardHeight
    local visibleArtWidth = 1
    local visibleArtHeight = 1
    if cardAspectRatio < REWIND_ART_BACKGROUND_ASPECT_RATIO then
        visibleArtWidth = cardAspectRatio / REWIND_ART_BACKGROUND_ASPECT_RATIO
    else
        visibleArtHeight = REWIND_ART_BACKGROUND_ASPECT_RATIO / cardAspectRatio
    end
    visibleArtWidth = visibleArtWidth / REWIND_ART_BACKGROUND_ZOOM
    visibleArtHeight = visibleArtHeight / REWIND_ART_BACKGROUND_ZOOM
    local artLeft, artRight = GetCropBounds(visibleArtWidth, 0.5)
    local artTop, artBottom = GetCropBounds(visibleArtHeight, REWIND_ART_BACKGROUND_FOCUS_Y)
    rewindCard.artBackground:SetTexCoord(artLeft, artRight, artTop, artBottom)
    local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or cardHeight
    rewindCard.normalScale = math.min(1, math.max(screenHeight - 40, 1) / cardHeight)
    if not captureState then
        rewindCard:SetScale(rewindCard.normalScale)
    end
    rewindCard.renderedSeasonKey = selectedSeasonKey
    ApplyRewindTheme()
end

local function SaveFramePoints(frame)
    local points = {}
    if not frame.GetNumPoints or not frame.GetPoint then return points end
    for index = 1, frame:GetNumPoints() do
        points[index] = { frame:GetPoint(index) }
    end
    return points
end

local function RestoreFramePoints(frame, points)
    frame:ClearAllPoints()
    for _, point in ipairs(points or {}) do
        frame:SetPoint(unpack(point))
    end
end

local SCREENSHOT_TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "EmbeddedItemTooltip",
    "WorldMapTooltip",
    "WorldMapCompareTooltip1",
    "WorldMapCompareTooltip2",
}

local function HideScreenshotTooltips()
    if mvpTooltip then
        mvpTooltip:Hide()
    end
    for _, tooltipName in ipairs(SCREENSHOT_TOOLTIP_NAMES) do
        local tooltip = _G[tooltipName]
        if tooltip and tooltip.Hide then
            tooltip:Hide()
        end
    end
end

local function EnsureScreenshotCaptureFrames()
    if not captureBackdrop then
        captureBackdrop = CreateFrame("Frame", nil, UIParent)
        captureBackdrop:SetAllPoints(UIParent)
        captureBackdrop:SetFrameStrata("DIALOG")
        captureBackdrop:SetFrameLevel(119)
        captureBackdrop:EnableMouse(false)
        captureBackdrop.background = captureBackdrop:CreateTexture(nil, "BACKGROUND")
        captureBackdrop.background:SetAllPoints()
        captureBackdrop.background:SetColorTexture(
            REWIND_CARD_BACKGROUND_COLOR[1],
            REWIND_CARD_BACKGROUND_COLOR[2],
            REWIND_CARD_BACKGROUND_COLOR[3],
            1
        )
        captureBackdrop:Hide()
    end

    if not captureInputBlocker then
        captureInputBlocker = CreateFrame("Frame", nil, UIParent)
        captureInputBlocker:SetAllPoints(UIParent)
        captureInputBlocker:SetFrameStrata("TOOLTIP")
        captureInputBlocker:SetFrameLevel(10000)
        captureInputBlocker:EnableMouse(false)
        captureInputBlocker:Hide()
    end

    if not captureController then
        captureController = CreateFrame("Frame", nil, UIParent)
        captureController:RegisterEvent("SCREENSHOT_SUCCEEDED")
        captureController:RegisterEvent("SCREENSHOT_FAILED")
        captureController:SetScript("OnEvent", function(_, event)
            if captureState and (event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED") then
                RestoreScreenshotCapture()
            end
        end)
    end

    rewindCard.captureBackdrop = captureBackdrop
    rewindCard.captureInputBlocker = captureInputBlocker
    rewindCard.captureController = captureController
end

RestoreScreenshotCapture = function()
    if not captureState or not rewindCard then return end
    local state = captureState
    captureState = nil

    if captureController then
        captureController:SetScript("OnUpdate", nil)
    end
    if captureBackdrop then
        captureBackdrop:EnableMouse(false)
        captureBackdrop:Hide()
    end
    if captureInputBlocker then
        captureInputBlocker:EnableMouse(false)
        captureInputBlocker:Hide()
    end

    rewindCard:SetScale(state.scale)
    rewindCard:SetClampedToScreen(state.clampedToScreen)
    RestoreFramePoints(rewindCard, state.points)
    rewindCard.closeButton:SetShown(state.closeButtonShown)
    rewindCard.captureButton:SetShown(state.captureButtonShown)
    rewindCard:EnableMouse(true)
    rewindCard.closeButton:EnableMouse(true)
    rewindCard.captureButton:EnableMouse(true)
end

local function BeginScreenshotCapture()
    if captureState or not rewindCard or not rewindCard:IsShown() then return end
    EnsureScreenshotCaptureFrames()

    local screenWidth = math.max(UIParent:GetWidth(), 1)
    local screenHeight = math.max(UIParent:GetHeight(), 1)
    local cardWidth = math.max(rewindCard:GetWidth(), 1)
    local cardHeight = math.max(rewindCard:GetHeight(), 1)
    local captureScale = math.min(screenWidth / cardWidth, screenHeight / cardHeight)

    captureState = {
        scale = rewindCard.GetScale and rewindCard:GetScale() or rewindCard.normalScale or 1,
        points = SaveFramePoints(rewindCard),
        clampedToScreen = rewindCard:IsClampedToScreen(),
        closeButtonShown = rewindCard.closeButton:IsShown(),
        captureButtonShown = rewindCard.captureButton:IsShown(),
        phase = "rendering",
        renderedFrames = 0,
        elapsed = 0,
    }

    captureBackdrop:SetFrameStrata(rewindCard:GetFrameStrata())
    captureBackdrop:SetFrameLevel(math.max(rewindCard:GetFrameLevel() - 1, 0))
    captureBackdrop:EnableMouse(false)
    captureBackdrop:Show()
    HideScreenshotTooltips()
    captureInputBlocker:EnableMouse(true)
    captureInputBlocker:Show()
    rewindCard.closeButton:Hide()
    rewindCard.captureButton:Hide()
    rewindCard:SetClampedToScreen(false)
    rewindCard:ClearAllPoints()
    rewindCard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    rewindCard:SetScale(captureScale)

    captureController:SetScript("OnUpdate", function(_, elapsed)
        if not captureState then return end
        HideScreenshotTooltips()
        captureState.elapsed = captureState.elapsed + (tonumber(elapsed) or 0)
        if captureState.elapsed >= SCREENSHOT_CAPTURE_TIMEOUT then
            RestoreScreenshotCapture()
            return
        end

        if captureState.phase == "restoreAfterScreenshot" then
            RestoreScreenshotCapture()
            return
        end

        if captureState.phase == "rendering" then
            captureState.renderedFrames = captureState.renderedFrames + 1
            if captureState.renderedFrames >= 2 then
                captureState.phase = "restoreAfterScreenshot"
                if type(Screenshot) ~= "function" then
                    RestoreScreenshotCapture()
                    return
                end
                local succeeded = pcall(Screenshot)
                if not succeeded then
                    RestoreScreenshotCapture()
                end
            end
        end
    end)
end

local function SelectSeason(seasonKey)
    if not GetAvailableSeasonSet()[seasonKey] then return end

    selectedSeasonKey = seasonKey
    selectedExpansionKey = Season.GetSeasonInfo(seasonKey).expansionKey
    Database.SetSetting("selectedSeasonKey", selectedSeasonKey)
    Database.SetSetting("selectedExpansionKey", selectedExpansionKey)
    HideMenus()
    if ns.UI and ns.UI.SetHistorySeason then
        ns.UI.SetHistorySeason(selectedSeasonKey)
    end
    SeasonUI.Refresh()
    if ns.UI and ns.UI.RefreshTable then
        ns.UI.RefreshTable()
    end
end

local function SelectExpansion(expansionKey)
    local seasons = Season.GetSeasonOptions(expansionKey, History.GetAvailableSeasonKeys())
    if seasons[1] then
        SelectSeason(seasons[1].key)
    end
end

local function OpenRewindCard()
    if not rewindCard then
        CreateRewindCard()
    end
    HideMenus()
    RefreshRewindCard()
    rewindCard:Show()
    rewindCard:Raise()
end

function SeasonUI.GetSelectedSeasonKey()
    EnsureSelection()
    return selectedSeasonKey
end

function SeasonUI.Refresh()
    if not seasonBar then return end
    EnsureSelection()

    local seasonKeys = History.GetAvailableSeasonKeys()
    local expansions = Season.GetExpansionOptions(seasonKeys)
    local seasons = Season.GetSeasonOptions(selectedExpansionKey, seasonKeys)
    local expansionInfo = Season.GetExpansionInfo(selectedExpansionKey)
    local seasonInfo = Season.GetSeasonInfo(selectedSeasonKey)
    local seasonState = GetSelectedSeasonState()
    local statusLabels = {
        active = "Season active",
        ended = "Season ended",
        inactive = "Season not active",
    }

    expansionSelector.button.label:SetText(expansionInfo and expansionInfo.name or "Expansion")
    seasonSelector.button.label:SetText(seasonInfo.label)
    seasonStatus:SetText(statusLabels[seasonState] or "")
    seasonStatus:SetShown(statusLabels[seasonState] ~= nil)
    summaryButton.label:SetText(IsSelectedSeasonRewind() and "View Rewind" or "View Statistics")
    ApplySeasonStatusStyle(seasonState)
    RefreshSelectorMenu(expansionSelector, expansions, SelectExpansion)
    RefreshSelectorMenu(seasonSelector, seasons, SelectSeason)
    RefreshRewindCard()
end

function SeasonUI.ApplyTheme(theme)
    activeTheme = theme or activeTheme
    if not activeTheme or not seasonBar then return end

    ApplyPanelTheme(seasonBar, activeTheme.surface, activeTheme.border)
    RefreshSelectorStyle(expansionSelector)
    RefreshSelectorStyle(seasonSelector)
    ApplySeasonStatusStyle(GetSelectedSeasonState())
    ApplyChoiceButtonStyle(summaryButton, false, true)
    ApplyRewindTheme()
end

CreateRewindCard = function()
    rewindCard = CreateFrame("Frame", "WarbandRatingsRewindCard", UIParent)
    rewindCard:SetSize(REWIND_CARD_WIDTH, REWIND_CARD_MIN_HEIGHT)
    rewindCard:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    rewindCard:SetFrameStrata("DIALOG")
    rewindCard:SetFrameLevel(120)
    rewindCard:SetMovable(true)
    rewindCard:SetClampedToScreen(true)
    rewindCard:EnableMouse(true)
    rewindCard:RegisterForDrag("LeftButton")
    rewindCard:SetScript("OnDragStart", function(self) self:StartMoving() end)
    rewindCard:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    rewindCard:SetScript("OnShow", RefreshRewindCard)
    rewindCard:SetScript("OnHide", function()
        RestoreScreenshotCapture()
        if mvpTooltip then mvpTooltip:Hide() end
    end)
    rewindCard:Hide()
    EnsurePanelArtwork(rewindCard)

    rewindCard.artBackground = rewindCard:CreateTexture(nil, "BACKGROUND", nil, 1)
    rewindCard.artBackground:SetSize(REWIND_CARD_WIDTH, REWIND_CARD_MIN_HEIGHT)
    rewindCard.artBackground:SetPoint("CENTER", rewindCard, "CENTER", 0, 0)
    rewindCard.artBackground:SetTexture(REWIND_ART_BACKGROUND_TEXTURE)
    rewindCard.artBackground:SetAlpha(REWIND_ART_BACKGROUND_ALPHA)

    if UISpecialFrames then
        local registered
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "WarbandRatingsRewindCard" then
                registered = true
                break
            end
        end
        if not registered then
            table.insert(UISpecialFrames, "WarbandRatingsRewindCard")
        end
    end

    rewindCard.headerWash = rewindCard:CreateTexture(nil, "BORDER")
    rewindCard.headerWash:SetPoint("TOPLEFT", rewindCard, "TOPLEFT", 1, -1)
    rewindCard.headerWash:SetPoint("TOPRIGHT", rewindCard, "TOPRIGHT", -1, -1)
    rewindCard.headerWash:SetHeight(72)
    rewindCard.accentLine = rewindCard:CreateTexture(nil, "ARTWORK")
    rewindCard.accentLine:SetPoint("TOPLEFT", rewindCard.headerWash, "BOTTOMLEFT", 0, 0)
    rewindCard.accentLine:SetPoint("TOPRIGHT", rewindCard.headerWash, "BOTTOMRIGHT", 0, 0)
    rewindCard.accentLine:SetHeight(2)

    rewindCard.period = rewindCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewindCard.period:SetPoint("TOPRIGHT", rewindCard, "TOPRIGHT", -50, -14)
    rewindCard.period:SetJustifyH("RIGHT")
    rewindCard.expansionIcon = rewindCard:CreateTexture(nil, "ARTWORK")
    rewindCard.expansionIcon:SetSize(72, 60)
    rewindCard.expansionIcon:SetPoint("TOPLEFT", rewindCard, "TOPLEFT", 20, -6)
    rewindCard.title = rewindCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rewindCard.title:SetPoint("LEFT", rewindCard.expansionIcon, "RIGHT", 10, 0)
    rewindCard.title:SetPoint("RIGHT", rewindCard, "RIGHT", -50, 0)
    rewindCard.title:SetJustifyH("LEFT")
    rewindCard.title:SetScale(1.12)
    rewindCard.subtitle = rewindCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rewindCard.subtitle:SetPoint("TOPLEFT", rewindCard.title, "BOTTOMLEFT", 1, -4)

    rewindCard.closeButton = CreateFrame("Button", nil, rewindCard)
    rewindCard.closeButton:SetSize(30, 30)
    rewindCard.closeButton:SetPoint("TOPRIGHT", rewindCard, "TOPRIGHT", -8, -8)
    rewindCard.closeButton.hovered = false
    rewindCard.closeButton.hover = rewindCard.closeButton:CreateTexture(nil, "BACKGROUND")
    rewindCard.closeButton.hover:SetAllPoints()
    rewindCard.closeButton.label = rewindCard.closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rewindCard.closeButton.label:SetPoint("CENTER", 0, 1)
    rewindCard.closeButton.label:SetText("x")
    rewindCard.closeButton:SetScript("OnEnter", function(self)
        self.hovered = true
        ApplyRewindTheme()
    end)
    rewindCard.closeButton:SetScript("OnLeave", function(self)
        self.hovered = false
        ApplyRewindTheme()
    end)
    rewindCard.closeButton:SetScript("OnClick", function() rewindCard:Hide() end)

    rewindCard.period:ClearAllPoints()
    rewindCard.period:SetPoint("RIGHT", rewindCard.closeButton, "LEFT", -8, 0)

    rewindCard.captureButton = CreateFrame("Button", nil, rewindCard)
    rewindCard.captureButton:SetSize(32, 32)
    rewindCard.captureButton:SetPoint("BOTTOMRIGHT", rewindCard, "BOTTOMRIGHT", -14, 8)
    rewindCard.captureButton.hovered = false
    rewindCard.captureButton.hover = rewindCard.captureButton:CreateTexture(nil, "BACKGROUND")
    rewindCard.captureButton.hover:SetAllPoints()
    rewindCard.captureButton.icon = rewindCard.captureButton:CreateTexture(nil, "ARTWORK")
    rewindCard.captureButton.icon:SetSize(24, 24)
    rewindCard.captureButton.icon:SetPoint("CENTER")
    rewindCard.captureButton.icon:SetTexture(
        "Interface\\AddOns\\WarbandRatings\\media\\camera-icon.png"
    )
    rewindCard.captureButton:SetScript("OnEnter", function(self)
        self.hovered = true
        ApplyRewindTheme()
    end)
    rewindCard.captureButton:SetScript("OnLeave", function(self)
        self.hovered = false
        ApplyRewindTheme()
    end)
    rewindCard.captureButton:SetScript("OnClick", BeginScreenshotCapture)

    rewindCard.metrics = {
        CreateMetric(rewindCard, 1, "RATED GAMES"),
        CreateMetric(rewindCard, 2, "PEAK RATING"),
        CreateMetric(rewindCard, 3, "MOST VALUABLE SPEC"),
        CreateMetric(rewindCard, 4, "CLASSES PLAYED"),
        CreateMetric(rewindCard, 5, "SPECS PLAYED"),
    }

    mvpTooltip = CreateFrame("Frame", nil, UIParent)
    mvpTooltip:SetSize(330, 224)
    mvpTooltip:SetPoint("LEFT", rewindCard, "RIGHT", 12, 0)
    mvpTooltip:SetFrameStrata("TOOLTIP")
    mvpTooltip:SetFrameLevel(rewindCard:GetFrameLevel() + 20)
    mvpTooltip:SetClampedToScreen(true)
    EnsurePanelArtwork(mvpTooltip)
    mvpTooltip.accent = mvpTooltip:CreateTexture(nil, "ARTWORK")
    mvpTooltip.accent:SetPoint("TOPLEFT", mvpTooltip, "TOPLEFT", 1, -1)
    mvpTooltip.accent:SetPoint("TOPRIGHT", mvpTooltip, "TOPRIGHT", -1, -1)
    mvpTooltip.accent:SetHeight(3)
    mvpTooltip.title = mvpTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mvpTooltip.title:SetPoint("TOPLEFT", mvpTooltip, "TOPLEFT", 16, -15)
    mvpTooltip.title:SetText("MOST VALUABLE SPEC")
    mvpTooltip.score = mvpTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mvpTooltip.score:SetPoint("TOPRIGHT", mvpTooltip, "TOPRIGHT", -16, -11)
    mvpTooltip.score:SetScale(1.35)
    mvpTooltip.separator = mvpTooltip:CreateTexture(nil, "ARTWORK")
    mvpTooltip.separator:SetPoint("TOPLEFT", mvpTooltip, "TOPLEFT", 16, -48)
    mvpTooltip.separator:SetPoint("TOPRIGHT", mvpTooltip, "TOPRIGHT", -16, -48)
    mvpTooltip.separator:SetHeight(1)
    mvpTooltip.calculationLabel = mvpTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mvpTooltip.calculationLabel:SetPoint("TOPLEFT", mvpTooltip, "TOPLEFT", 16, -63)
    mvpTooltip.calculationLabel:SetText("CALCULATION")
    mvpTooltip.calculation = mvpTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mvpTooltip.calculation:SetPoint("TOPLEFT", mvpTooltip.calculationLabel, "BOTTOMLEFT", 0, -6)
    mvpTooltip.calculation:SetWidth(298)
    mvpTooltip.calculation:SetJustifyH("LEFT")
    mvpTooltip.eligibilityLabel = mvpTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mvpTooltip.eligibilityLabel:SetPoint("TOPLEFT", mvpTooltip, "TOPLEFT", 16, -105)
    mvpTooltip.eligibilityLabel:SetText("ELIGIBILITY")
    mvpTooltip.eligibility = mvpTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mvpTooltip.eligibility:SetPoint("TOPLEFT", mvpTooltip.eligibilityLabel, "BOTTOMLEFT", 0, -6)
    mvpTooltip.eligibility:SetWidth(298)
    mvpTooltip.eligibility:SetJustifyH("LEFT")
    mvpTooltip.eligibility:SetText(MVSPEC_ACTIVE_RULE_TEXT)
    mvpTooltip.scope = mvpTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mvpTooltip.scope:SetPoint("BOTTOMLEFT", mvpTooltip, "BOTTOMLEFT", 16, 14)
    mvpTooltip.scope:SetWidth(298)
    mvpTooltip.scope:SetJustifyH("LEFT")
    mvpTooltip.scope:SetText(MVSPEC_SCOPE_TEXT)
    mvpTooltip:Hide()
    rewindCard.mvpTooltip = mvpTooltip

    rewindCard.metrics[3].value:SetWidth(rewindCard.metrics[3]:GetWidth() - 12)
    rewindCard.metrics[3].labelHitbox = CreateFrame("Button", nil, rewindCard.metrics[3])
    rewindCard.metrics[3].labelHitbox:SetAllPoints(rewindCard.metrics[3].label)
    rewindCard.metrics[3].labelHitbox:EnableMouse(true)
    rewindCard.metrics[3].labelHitbox:SetScript("OnEnter", function()
        mvpTooltip:Show()
    end)
    rewindCard.metrics[3].labelHitbox:SetScript("OnLeave", function()
        mvpTooltip:Hide()
    end)
    if rewindCard.metrics[3].value.SetWordWrap then
        rewindCard.metrics[3].value:SetWordWrap(false)
    end
    if rewindCard.metrics[3].value.SetMaxLines then
        rewindCard.metrics[3].value:SetMaxLines(1)
    end

    rewindCard.sectionTitle = rewindCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewindCard.sectionTitle:SetPoint("TOPLEFT", rewindCard, "TOPLEFT", 20, -150)
    rewindCard.sectionTitle:SetText("BRACKET BREAKDOWN")
    rewindContent = CreateFrame("Frame", nil, rewindCard)
    rewindContent:SetPoint("TOPLEFT", rewindCard, "TOPLEFT", 20, -REWIND_CONTENT_TOP)
    rewindContent:SetWidth(REWIND_CONTENT_WIDTH)
    rewindContent:SetHeight(1)

    rewindCard.footer = rewindCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rewindCard.footer:SetPoint("BOTTOMLEFT", rewindCard, "BOTTOMLEFT", 20, 18)
    rewindCard.footer:SetPoint("RIGHT", rewindCard, "RIGHT", -20, 0)
    rewindCard.footer:SetJustifyH("CENTER")
    RefreshRewindCard()
end

function SeasonUI.Create(parent)
    if seasonBar then return seasonBar end
    mainFrame = parent
    EnsureSelection()

    seasonBar = CreateFrame("Frame", nil, mainFrame)
    seasonBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, -26)
    seasonBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, -26)
    seasonBar:SetHeight(SELECTOR_BAR_HEIGHT)

    expansionSelector = CreateSelector(seasonBar, 145)
    expansionSelector:SetPoint("LEFT", seasonBar, "LEFT", 10, 0)
    seasonSelector = CreateSelector(seasonBar, 98)
    seasonSelector:SetPoint("TOPLEFT", expansionSelector, "TOPRIGHT", 8, 0)

    summaryButton = CreateChoiceButton(seasonBar, 112)
    summaryButton:SetPoint("RIGHT", seasonBar, "RIGHT", -10, 0)
    summaryButton.arrow:Hide()
    summaryButton.label:SetPoint("LEFT", summaryButton, "LEFT", 10, 0)
    summaryButton.label:SetPoint("RIGHT", summaryButton, "RIGHT", -8, 0)
    summaryButton.label:SetJustifyH("CENTER")
    summaryButton:SetScript("OnClick", OpenRewindCard)

    seasonStatus = seasonBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    seasonStatus:SetPoint("LEFT", seasonSelector, "RIGHT", 12, 0)
    seasonStatus:SetPoint("RIGHT", summaryButton, "LEFT", -10, 0)
    seasonStatus:SetJustifyH("LEFT")
    seasonBar.statusText = seasonStatus
    mainFrame:HookScript("OnHide", function()
        HideMenus()
    end)

    SeasonUI.ApplyTheme(ns.UI and ns.UI.GetActiveTheme and ns.UI.GetActiveTheme())
    SeasonUI.Refresh()
    return seasonBar
end
