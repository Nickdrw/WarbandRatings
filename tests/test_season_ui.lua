-- luacheck: globals CreateFrame UIParent UISpecialFrames GetSpecializationInfoByID GameTooltip
-- luacheck: globals WarbandRatingsRewindCard CLASS_ICON_TCOORDS LOCALIZED_CLASS_NAMES_MALE
-- luacheck: globals Screenshot

local frames = {}
local regions = {}

local function NewRegion(name, parent)
    local region = {
        name = name,
        parent = parent,
        shown = true,
        width = 0,
        height = 0,
        verticalScroll = 0,
        scale = 1,
        frameStrata = "MEDIUM",
        clampedToScreen = false,
        events = {},
        scripts = {},
        points = {},
        mouseEnabled = true,
    }
    local methods = {}

    function methods:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function methods:SetWidth(width) self.width = width end
    function methods:SetHeight(height) self.height = height end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:CreateTexture() return NewRegion(nil, self) end
    function methods:CreateFontString(_, _, fontTemplate)
        local fontString = NewRegion(nil, self)
        fontString.fontTemplate = fontTemplate
        return fontString
    end
    function methods:SetText(value) self.text = value end
    function methods:GetText() return self.text end
    function methods:SetTexture(value) self.texture = value end
    function methods:SetAlpha(value) self.alpha = value end
    function methods:SetColorTexture(red, green, blue, alpha)
        self.color = { red, green, blue, alpha }
    end
    function methods:SetTextColor(red, green, blue, alpha)
        self.textColor = { red, green, blue, alpha }
    end
    function methods:SetTexCoord(...) self.texCoords = { ... } end
    function methods:SetScript(scriptType, callback) self.scripts[scriptType] = callback end
    function methods:HookScript(scriptType, callback) self.scripts[scriptType] = callback end
    function methods:Show()
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:SetShown(shown)
        if shown then self:Show() else self:Hide() end
    end
    function methods:IsShown() return self.shown end
    function methods:SetFrameLevel(level) self.frameLevel = level end
    function methods:GetFrameLevel() return rawget(self, "frameLevel") or 1 end
    function methods:SetFrameStrata(strata) self.frameStrata = strata end
    function methods:GetFrameStrata() return self.frameStrata end
    function methods:SetScale(scale) self.scale = scale end
    function methods:GetScale() return self.scale end
    function methods:SetClampedToScreen(clamped) self.clampedToScreen = clamped end
    function methods:IsClampedToScreen() return self.clampedToScreen end
    function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:SetVerticalScroll(value) self.verticalScroll = value end
    function methods:GetVerticalScroll() return self.verticalScroll end
    function methods:SetScrollChild(child) self.scrollChild = child end
    function methods:Raise() self.raised = true end
    function methods:SetPoint(...)
        self.points[#self.points + 1] = { ... }
    end
    function methods:ClearAllPoints() self.points = {} end
    function methods:GetNumPoints() return #self.points end
    function methods:GetPoint(index)
        local point = self.points[index]
        if point then return unpack(point) end
    end

    for _, methodName in ipairs({
        "SetAllPoints",
        "SetJustifyH",
        "SetJustifyV",
        "SetMovable",
        "RegisterForDrag",
        "StartMoving",
        "StopMovingOrSizing",
        "EnableMouseWheel",
        "SetFontColor",
    }) do
        methods[methodName] = function() end
    end

    setmetatable(region, {
        __index = methods,
    })
    regions[#regions + 1] = region
    return region
end

UIParent = NewRegion("UIParent")
UIParent:SetSize(1920, 1080)
UISpecialFrames = {}
GameTooltip = {
    shown = false,
    points = {},
    SetOwner = function(self, owner, anchor)
        self.owner = owner
        self.anchor = anchor
    end,
    ClearAllPoints = function(self) self.points = {} end,
    SetPoint = function(self, ...)
        self.points[#self.points + 1] = { ... }
    end,
    SetText = function(self, value) self.text = value end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}

CreateFrame = function(_, name, parent)
    local frame = NewRegion(name, parent)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

GetSpecializationInfoByID = function(specID)
    return specID, "Arms", "", 132355, "DAMAGER", "WARRIOR", "Warrior"
end
local screenshotCount = 0
Screenshot = function()
    screenshotCount = screenshotCount + 1
end
CLASS_ICON_TCOORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 },
}
LOCALIZED_CLASS_NAMES_MALE = {
    WARRIOR = "Warrior",
}

local settings = {}
local selectedSeasonKey = "pvp-42"
local seasonActive = true
local seasonHasData = true
local theme = {
    bg = { 0.03, 0.04, 0.05, 1 },
    surface = { 0.05, 0.06, 0.08, 1 },
    surfaceRaised = { 0.08, 0.09, 0.11, 1 },
    header = { 0.10, 0.12, 0.15, 1 },
    border = { 0.25, 0.28, 0.33, 1 },
    rowOdd = { 0, 0, 0, 0.18 },
    rowEven = { 1, 1, 1, 0.04 },
    rowHover = { 0.95, 0.72, 0.28, 0.13 },
    text = { 0.9, 0.93, 0.96, 1 },
    title = { 0.97, 0.82, 0.45, 1 },
    headerText = { 0.78, 0.84, 0.9, 1 },
    muted = { 0.56, 0.6, 0.65, 1 },
    accent = { 0.96, 0.72, 0.32, 1 },
}

local ns = {
    DISPLAY_NAME = "Warband PvP Companion",
    Database = {
        GetSettings = function() return settings end,
        SetSetting = function(key, value) settings[key] = value end,
    },
    History = {
        GetAvailableSeasonKeys = function() return { "pvp-42", "pvp-41" } end,
        GetContentSeasonKey = function() return "pvp-42" end,
        GetSeasonMVSpec = function()
            return {
                specID = 71,
                classFilename = "WARRIOR",
                activeBracketCount = 3,
                ratingTotal = 5289,
                averageRating = 1762.5,
                ratingsByBracket = {
                    soloShuffle = 1875,
                    soloBG = 1694,
                    arena2v2 = 1720,
                },
            }
        end,
        GetSeasonStatistics = function()
            if not seasonHasData then return {} end
            return {
                {
                    key = "arena2v2",
                    label = "2v2",
                    perSpec = false,
                    unit = "games",
                    maxRating = 1720,
                    maxRatingSpecID = 71,
                    maxRatingClassFilename = "WARRIOR",
                    mostPlayedGames = 8,
                    mostPlayedClassFilename = "WARRIOR",
                    total = { games = 10, wins = 6, losses = 4 },
                    classes = { "WARRIOR" },
                    specs = {},
                },
                {
                    key = "arena3v3",
                    label = "3v3",
                    perSpec = false,
                    unit = "games",
                    maxRating = 1810,
                    maxRatingSpecID = 71,
                    maxRatingClassFilename = "WARRIOR",
                    mostPlayedGames = 7,
                    mostPlayedClassFilename = "WARRIOR",
                    total = { games = 7, wins = 4, losses = 3 },
                    classes = { "WARRIOR" },
                    specs = {},
                },
                {
                    key = "rbg10v10",
                    label = "10v10",
                    perSpec = false,
                    unit = "games",
                    maxRating = 0,
                    total = { games = 0, wins = 0, losses = 0 },
                    classes = {},
                    specs = {},
                },
                {
                    key = "soloShuffle",
                    label = "Solo Shuffle",
                    perSpec = true,
                    unit = "rounds",
                    maxRating = 1875,
                    total = { games = 1103, wins = 620, losses = 483 },
                    classes = { "WARRIOR" },
                    specs = {
                        {
                            specID = 71,
                            classFilename = "WARRIOR",
                            maxRating = 1875,
                            games = 1103,
                            wins = 620,
                            losses = 483,
                        },
                    },
                },
                {
                    key = "soloBG",
                    label = "Solo Battleground",
                    perSpec = true,
                    unit = "games",
                    maxRating = 1642,
                    total = { games = 4, wins = 3, losses = 1 },
                    classes = { "WARRIOR" },
                    specs = {
                        {
                            specID = 71,
                            classFilename = "WARRIOR",
                            maxRating = 1642,
                            games = 4,
                            wins = 3,
                            losses = 1,
                        },
                    },
                },
            }
        end,
    },
    Season = {
        IsRatedSeasonActive = function() return seasonActive end,
        GetSeasonInfo = function(seasonKey)
            return {
                key = seasonKey,
                expansionKey = "midnight",
                expansionName = "Midnight",
                number = seasonKey == "pvp-42" and 2 or 1,
                label = seasonKey == "pvp-42" and "Season 2" or "Season 1",
            }
        end,
        GetExpansionInfo = function()
            return {
                key = "midnight",
                name = "Midnight",
                icon = "Interface\\AddOns\\WarbandRatings\\media\\midnight-logo.png",
            }
        end,
        GetExpansionOptions = function()
            return { { key = "midnight", label = "Midnight" } }
        end,
        GetSeasonOptions = function()
            return {
                { key = "pvp-42", label = "Season 2", number = 2 },
                { key = "pvp-41", label = "Season 1", number = 1 },
            }
        end,
    },
    Utils = {
        FormatNumber = function(value) return tostring(value) end,
        GetClassIcon = function(classFilename)
            local coords = CLASS_ICON_TCOORDS[classFilename]
            if not coords then return nil, nil end
            return "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes", coords
        end,
    },
    UI = {
        GetActiveTheme = function() return theme end,
        SetHistorySeason = function(seasonKey) selectedSeasonKey = seasonKey end,
        RefreshTable = function() end,
    },
}

assert(loadfile("SeasonUI.lua"))("WarbandRatings", ns)
local mainFrame = CreateFrame("Frame", "TestMainFrame", UIParent)
mainFrame:SetSize(780, 450)
local seasonBar = ns.SeasonUI.Create(mainFrame)
assert(seasonBar.statusText.text == "Season active", "active-season status is missing")

local summaryButton
for _, frame in ipairs(frames) do
    if frame.label and frame.label.text == "View Statistics" then
        summaryButton = frame
        break
    end
end
assert(summaryButton and summaryButton.scripts.OnClick, "season statistics button was not created")
assert(summaryButton.height == 22, "season toolbar buttons should use the compact height")
summaryButton.scripts.OnClick(summaryButton)

assert(WarbandRatingsRewindCard and WarbandRatingsRewindCard:IsShown(), "Rewind card did not open")
assert(WarbandRatingsRewindCard.title.text == "Season 2 Statistics", "current-season title is incorrect")
assert(WarbandRatingsRewindCard.expansionIcon.texture
        == "Interface\\AddOns\\WarbandRatings\\media\\midnight-logo.png",
    "expansion icon is incorrect")
assert(WarbandRatingsRewindCard.expansionIcon:IsShown(), "known expansion icon should be visible")
assert(WarbandRatingsRewindCard.expansionIcon.width == 72
        and WarbandRatingsRewindCard.expansionIcon.height == 60,
    "expansion logo should preserve its 6:5 aspect ratio")
assert(WarbandRatingsRewindCard.footer.text == "Warband PvP Companion", "footer should contain only the addon name")
assert(WarbandRatingsRewindCard.seasonUIBackground.color[4] == 1,
    "Rewind card background should be fully opaque")
assert(not WarbandRatingsRewindCard.headerWash:IsShown(),
    "Rewind header should reveal the card-wide logo background")
assert(WarbandRatingsRewindCard.metrics[1].seasonUIBackground.color[4] == 0.76,
    "Rewind metric backgrounds should be slightly transparent")
assert(WarbandRatingsRewindCard.artBackground.texture
        == "Interface\\AddOns\\WarbandRatings\\media\\rewind-card-background-generated.png",
    "Rewind card should use the generated seamless logo background")
assert(WarbandRatingsRewindCard.artBackground.width == 900
        and WarbandRatingsRewindCard.artBackground.height == WarbandRatingsRewindCard.height,
    "Rewind artwork should cover the full card without side extensions")
local generatedArtAspectRatio = 1717 / 916
local generatedArtZoom = 1.18
local generatedArtFocusY = 0.535
local cardAspectRatio = 900 / WarbandRatingsRewindCard.height
local visibleArtWidth = 1
local visibleArtHeight = 1
if cardAspectRatio < generatedArtAspectRatio then
    visibleArtWidth = cardAspectRatio / generatedArtAspectRatio
else
    visibleArtHeight = generatedArtAspectRatio / cardAspectRatio
end
visibleArtWidth = visibleArtWidth / generatedArtZoom
visibleArtHeight = visibleArtHeight / generatedArtZoom
local expectedArtLeft = 0.5 - (visibleArtWidth / 2)
local expectedArtTop = generatedArtFocusY - (visibleArtHeight / 2)
local expectedTexCoords = {
    expectedArtLeft,
    expectedArtLeft + visibleArtWidth,
    expectedArtTop,
    expectedArtTop + visibleArtHeight,
}
local actualTexCoords = WarbandRatingsRewindCard.artBackground.texCoords
assert(math.abs(actualTexCoords[1] - expectedTexCoords[1]) < 0.0001
        and math.abs(actualTexCoords[2] - expectedTexCoords[2]) < 0.0001
        and math.abs(actualTexCoords[3] - expectedTexCoords[3]) < 0.0001
        and math.abs(actualTexCoords[4] - expectedTexCoords[4]) < 0.0001,
    "Rewind artwork should be center-cropped without distorting its aspect ratio")
assert(actualTexCoords[3] > 0,
    "Rewind artwork should be zoomed and vertically focused to keep the shield near the header")
assert(WarbandRatingsRewindCard.artBackground.alpha == 0.32,
    "Rewind card artwork opacity is incorrect")
for _, border in ipairs(WarbandRatingsRewindCard.seasonUIBorders) do
    assert(not border:IsShown(), "Rewind card should not display an outer border")
end
assert(WarbandRatingsRewindCard.captureButton
        and WarbandRatingsRewindCard.captureButton.width == 32
        and WarbandRatingsRewindCard.captureButton.height == 32
        and WarbandRatingsRewindCard.captureButton.icon.width == 24
        and WarbandRatingsRewindCard.captureButton.icon.height == 24
        and not WarbandRatingsRewindCard.captureButton.hover:IsShown()
        and WarbandRatingsRewindCard.captureButton.icon.texture
            == "Interface\\AddOns\\WarbandRatings\\media\\camera-icon.png",
    "Rewind card should use the background-free camera capture button")
local capturePoint = WarbandRatingsRewindCard.captureButton.points[1]
local periodPoint = WarbandRatingsRewindCard.period.points[1]
assert(capturePoint[1] == "BOTTOMRIGHT"
        and capturePoint[2] == WarbandRatingsRewindCard
        and capturePoint[3] == "BOTTOMRIGHT",
    "capture control should be anchored in the card's bottom-right corner")
assert(periodPoint[1] == "RIGHT"
        and periodPoint[2] == WarbandRatingsRewindCard.closeButton
        and periodPoint[3] == "LEFT",
    "season status and close control should share the same header line")
local normalScale = WarbandRatingsRewindCard:GetScale()
local normalPoint = { WarbandRatingsRewindCard:GetPoint(1) }
GameTooltip.shown = true
WarbandRatingsRewindCard.captureButton.scripts.OnClick(WarbandRatingsRewindCard.captureButton)
assert(WarbandRatingsRewindCard.captureBackdrop:IsShown(),
    "screenshot capture should cover the game with an opaque backdrop")
assert(WarbandRatingsRewindCard.captureInputBlocker:IsShown()
        and WarbandRatingsRewindCard.captureInputBlocker.mouseEnabled
        and not GameTooltip.shown,
    "screenshot capture should block mouseovers and hide active tooltips")
assert(WarbandRatingsRewindCard:GetFrameStrata() == "DIALOG"
        and WarbandRatingsRewindCard:GetFrameLevel()
            > WarbandRatingsRewindCard.captureBackdrop:GetFrameLevel()
        and WarbandRatingsRewindCard:GetScale() > normalScale,
    "screenshot capture should enlarge the card without changing its input layer")
assert(not WarbandRatingsRewindCard.captureBackdrop.mouseEnabled,
    "screenshot backdrop should never capture mouse input")
assert(not WarbandRatingsRewindCard.closeButton:IsShown()
        and not WarbandRatingsRewindCard.captureButton:IsShown(),
    "screenshot capture controls should not appear in the captured card")
WarbandRatingsRewindCard.captureController.scripts.OnUpdate(
    WarbandRatingsRewindCard.captureController,
    0.016
)
assert(screenshotCount == 0, "screenshot should wait for the enlarged card to render")
WarbandRatingsRewindCard.captureController.scripts.OnUpdate(
    WarbandRatingsRewindCard.captureController,
    0.016
)
assert(screenshotCount == 1, "screenshot was not triggered after the render delay")
WarbandRatingsRewindCard.captureController.scripts.OnEvent(
    WarbandRatingsRewindCard.captureController,
    "SCREENSHOT_SUCCEEDED"
)
local restoredPoint = { WarbandRatingsRewindCard:GetPoint(1) }
assert(not WarbandRatingsRewindCard.captureBackdrop:IsShown()
        and not WarbandRatingsRewindCard.captureInputBlocker:IsShown()
        and not WarbandRatingsRewindCard.captureInputBlocker.mouseEnabled
        and WarbandRatingsRewindCard:GetScale() == normalScale
        and WarbandRatingsRewindCard:GetFrameStrata() == "DIALOG",
    "successful screenshot capture should restore the normal card presentation")
assert(restoredPoint[1] == normalPoint[1] and restoredPoint[2] == normalPoint[2]
        and restoredPoint[3] == normalPoint[3] and restoredPoint[4] == normalPoint[4]
        and restoredPoint[5] == normalPoint[5],
    "successful screenshot capture should restore the card position")
assert(WarbandRatingsRewindCard.closeButton:IsShown()
        and WarbandRatingsRewindCard.captureButton:IsShown()
        and WarbandRatingsRewindCard.closeButton.mouseEnabled
        and WarbandRatingsRewindCard.captureButton.mouseEnabled,
    "successful screenshot capture should restore the card controls")
WarbandRatingsRewindCard.captureButton.scripts.OnClick(WarbandRatingsRewindCard.captureButton)
WarbandRatingsRewindCard.captureController.scripts.OnUpdate(
    WarbandRatingsRewindCard.captureController,
    0.016
)
WarbandRatingsRewindCard.captureController.scripts.OnUpdate(
    WarbandRatingsRewindCard.captureController,
    0.016
)
assert(screenshotCount == 2, "second screenshot was not triggered")
WarbandRatingsRewindCard.captureController.scripts.OnUpdate(
    WarbandRatingsRewindCard.captureController,
    0.016
)
assert(not WarbandRatingsRewindCard.captureBackdrop:IsShown()
        and WarbandRatingsRewindCard:GetScale() == normalScale,
    "screenshot capture should restore on the next frame without waiting for the result event")
WarbandRatingsRewindCard.captureButton.scripts.OnClick(WarbandRatingsRewindCard.captureButton)
WarbandRatingsRewindCard.captureController.scripts.OnEvent(
    WarbandRatingsRewindCard.captureController,
    "SCREENSHOT_FAILED"
)
assert(not WarbandRatingsRewindCard.captureBackdrop:IsShown()
        and WarbandRatingsRewindCard:GetScale() == normalScale,
    "failed screenshot capture should restore the normal card presentation")
WarbandRatingsRewindCard.captureButton.scripts.OnClick(WarbandRatingsRewindCard.captureButton)
WarbandRatingsRewindCard.captureController.scripts.OnUpdate(
    WarbandRatingsRewindCard.captureController,
    5.1
)
assert(not WarbandRatingsRewindCard.captureBackdrop:IsShown()
        and WarbandRatingsRewindCard:GetScale() == normalScale
        and screenshotCount == 2,
    "timed-out screenshot capture should restore without triggering a late screenshot")
assert(WarbandRatingsRewindCard.metrics[1].value.text == "1124", "rated-game headline total should include Shuffle rounds")
assert(WarbandRatingsRewindCard.metrics[2].label.text == "PEAK RATING", "peak-rating headline label is incorrect")
assert(WarbandRatingsRewindCard.metrics[2].value.text == "1875", "peak-rating headline total is incorrect")
assert(WarbandRatingsRewindCard.metrics[3].label.text == "MOST VALUABLE SPEC"
        and WarbandRatingsRewindCard.metrics[3].value.text
            == "|T132355:18:18:0:0|t",
    "Most Valuable Spec headline should show only the specialization icon")
assert(WarbandRatingsRewindCard.metrics[3].value.scale == 1.25,
    "MV Spec should use the same value scale as the other headline metrics")
local mvSpecLabelHitbox = WarbandRatingsRewindCard.metrics[3].labelHitbox
assert(mvSpecLabelHitbox and mvSpecLabelHitbox.scripts.OnEnter and mvSpecLabelHitbox.scripts.OnLeave,
    "MV Spec formula tooltip handlers are missing")
mvSpecLabelHitbox.scripts.OnEnter(mvSpecLabelHitbox)
local mvSpecTooltip = WarbandRatingsRewindCard.mvpTooltip
assert(mvSpecTooltip:IsShown()
        and mvSpecTooltip.title.text == "MOST VALUABLE SPEC"
        and mvSpecTooltip.score.text == "1763"
        and mvSpecTooltip.ratingRows[1]:IsShown()
        and mvSpecTooltip.ratingRows[1].label.text == "Solo Shuffle"
        and mvSpecTooltip.ratingRows[1].value.text == "1875"
        and mvSpecTooltip.ratingRows[2]:IsShown()
        and mvSpecTooltip.ratingRows[2].label.text == "Solo BG"
        and mvSpecTooltip.ratingRows[2].value.text == "1694"
        and mvSpecTooltip.ratingRows[3]:IsShown()
        and mvSpecTooltip.ratingRows[3].label.text == "2v2"
        and mvSpecTooltip.ratingRows[3].value.text == "1720"
        and not mvSpecTooltip.ratingRows[4]:IsShown()
        and not mvSpecTooltip.ratingRows[5]:IsShown()
        and mvSpecTooltip.ratingRows[2].points[1][5]
            - mvSpecTooltip.ratingRows[1].points[1][5] == -17
        and mvSpecTooltip.ratingRows[3].points[1][5]
            - mvSpecTooltip.ratingRows[2].points[1][5] == -17
        and mvSpecTooltip.calculation.text == "5289 rating  /  3 brackets  =  1763"
        and mvSpecTooltip.eligibility.text:find("in at least 3 distinct brackets", 1, true)
        and mvSpecTooltip.eligibilityLabel.fontTemplate == "GameFontHighlightExtraSmall"
        and mvSpecTooltip.eligibility.fontTemplate == "GameFontHighlightExtraSmall"
        and mvSpecTooltip.scope.fontTemplate == "GameFontHighlightExtraSmall"
        and mvSpecTooltip.scope.text:find("Best qualifying rating per bracket", 1, true)
        and mvSpecTooltip.scope.text:find("Each bracket counts once", 1, true),
    "MV Spec panel should list the ratings used by the cross-character calculation")
local mvSpecTooltipPoint = mvSpecTooltip.points[#mvSpecTooltip.points]
assert(mvSpecTooltipPoint[1] == "LEFT"
        and mvSpecTooltipPoint[2] == WarbandRatingsRewindCard
        and mvSpecTooltipPoint[3] == "RIGHT"
        and mvSpecTooltipPoint[4] == 12,
    "MV Spec panel should appear just outside the right edge of the card")
mvSpecLabelHitbox.scripts.OnLeave(mvSpecLabelHitbox)
assert(not mvSpecTooltip:IsShown(), "MV Spec panel should hide on mouse leave")
assert(WarbandRatingsRewindCard.metrics[4].value.text == "1", "played-class headline total is incorrect")
assert(WarbandRatingsRewindCard.metrics[5].value.text == "1", "played-spec headline total is incorrect")
assert(#WarbandRatingsRewindCard.metrics == 5
        and WarbandRatingsRewindCard.metrics[1].width == 164,
    "Rewind headline should fit five evenly sized metric cards")
for _, metric in ipairs(WarbandRatingsRewindCard.metrics) do
    local valuePoint = metric.value.points[#metric.value.points]
    assert(metric.height == 54, "metric cards should be tightened from the bottom")
    assert(valuePoint[1] == "CENTER" and valuePoint[3] == "CENTER" and valuePoint[5] == -8,
        "metric values should retain their spacing from the labels")
end
assert(WarbandRatingsRewindCard.height > 450, "Rewind card did not grow to show all bracket content")
assert(WarbandRatingsRewindCard.height == 498,
    "Rewind card should not retain a trailing tile gap above the footer")

local rewindTilesByTitle = {}
for _, frame in ipairs(frames) do
    if frame.title and frame.title.text then
        rewindTilesByTitle[frame.title.text] = frame
    end
    assert(not frame.scripts.OnMouseWheel, "Rewind card should not register mouse-wheel scrolling")
end

local shuffleTile = rewindTilesByTitle["SOLO SHUFFLE"]
assert(shuffleTile.seasonUIBackground.color[4] == 0.70,
    "Rewind bracket backgrounds should reveal the opaque card surface")
assert(shuffleTile.recordHeader.text == "Record", "solo record header should use sentence case")
assert(shuffleTile.winRateHeader.text == "Win %", "solo win-rate header should use sentence case")
assert(shuffleTile.maxRatingHeader.text == "Best", "solo best-rating header should use sentence case")
assert(shuffleTile.games.text == "1103 Rounds", "Solo Shuffle unit should use sentence case")
assert(shuffleTile.rate.text == "56% win rate", "Solo Shuffle win rate is incorrect")
assert(shuffleTile.record.text == "620W  /  483L", "Solo Shuffle win/loss record is incorrect")
assert(shuffleTile.rate.fontTemplate == shuffleTile.record.fontTemplate,
    "bracket win rates and win/loss records should use the same font size")
local shuffleRatePoint = shuffleTile.rate.points[#shuffleTile.rate.points]
local shuffleRecordPoint = shuffleTile.record.points[#shuffleTile.record.points]
assert(shuffleRatePoint[1] == "LEFT" and shuffleRatePoint[3] == "TOPLEFT",
    "Solo Shuffle win rate should be aligned on the left")
assert(shuffleRecordPoint[1] == "RIGHT" and shuffleRecordPoint[3] == "TOPRIGHT",
    "Solo Shuffle win/loss record should be aligned on the right")
assert(shuffleTile and not shuffleTile.specRows[1].label,
    "solo rows should not display a class-name label")
assert(shuffleTile.specRows[1].record.text == "1103R 620W 483L",
    "four-digit Solo Shuffle records should use the compact single-line format")
assert(shuffleTile.specRows[1].record.width == 110, "solo record column should fit four-digit totals")
assert(shuffleTile.specRows[1].winRate.text == "56%", "solo row win rate is incorrect")
assert(shuffleTile.specRows[1].maxRating.text == "1875", "solo max rating is incorrect")
assert(shuffleTile.specRows[1].maxRating.textColor[1] == shuffleTile.title.textColor[1]
        and shuffleTile.specRows[1].maxRating.textColor[2] == shuffleTile.title.textColor[2]
        and shuffleTile.specRows[1].maxRating.textColor[3] == shuffleTile.title.textColor[3]
        and shuffleTile.specRows[1].maxRating.textColor[4] == shuffleTile.title.textColor[4],
    "solo best-rating values should use the golden rating color")
local iconHitbox = shuffleTile.specRows[1].iconHitbox
assert(iconHitbox and iconHitbox.scripts.OnEnter and iconHitbox.scripts.OnLeave,
    "solo spec icon tooltip handlers are missing")
iconHitbox.scripts.OnEnter(iconHitbox)
assert(GameTooltip.shown and GameTooltip.text == "Warrior - Arms",
    "solo spec icon tooltip should identify the class and specialization")
iconHitbox.scripts.OnLeave(iconHitbox)
assert(not GameTooltip.shown, "solo spec icon tooltip should hide on mouse leave")

local arena2v2Tile = rewindTilesByTitle["2V2"]
local arena3v3Tile = rewindTilesByTitle["3V3"]
local rbgTile = rewindTilesByTitle["10V10"]
assert(arena2v2Tile.games.text == "10 Games", "2v2 unit should use sentence case")
assert(arena2v2Tile.rate.text == "60% win rate", "2v2 win rate is incorrect")
assert(arena2v2Tile.record.text == "6W  /  4L", "2v2 win/loss record is incorrect")
assert(arena2v2Tile.bracketBestLabel.text == "Best rating", "2v2 best-rating label is incorrect")
assert(arena2v2Tile.bracketMaxRating.text == "1720", "2v2 best rating is incorrect")
assert(arena2v2Tile.bracketBestLabel.fontTemplate == arena2v2Tile.rate.fontTemplate,
    "non-solo Best rating labels should match the win-rate font size")
assert(arena2v2Tile.bracketMaxRating.fontTemplate == arena2v2Tile.record.fontTemplate,
    "non-solo rating values should match the win/loss font size")
assert(arena2v2Tile.rate.fontTemplate == shuffleTile.specRows[1].record.fontTemplate
        and arena2v2Tile.record.fontTemplate == shuffleTile.specRows[1].record.fontTemplate,
    "non-solo summaries should use the solo table-data font size")
assert(arena3v3Tile.bracketMaxRating.text == "1810", "3v3 best rating is incorrect")
assert(arena2v2Tile.mostPlayedLabel.text == "Most played", "most-played label is incorrect")
assert(arena2v2Tile.mostPlayedGames.text == "8 Games", "most-played class total is incorrect")
assert(arena2v2Tile.bracketMaxRating.textColor[1] == shuffleTile.specRows[1].maxRating.textColor[1]
        and arena2v2Tile.bracketMaxRating.textColor[2] == shuffleTile.specRows[1].maxRating.textColor[2]
        and arena2v2Tile.bracketMaxRating.textColor[3] == shuffleTile.specRows[1].maxRating.textColor[3]
        and arena2v2Tile.bracketMaxRating.textColor[4] == shuffleTile.specRows[1].maxRating.textColor[4],
    "non-solo rating values should use the solo golden rating color")
assert(arena2v2Tile.bracketBestLabel.textColor[1] == shuffleTile.specRows[1].record.textColor[1]
        and arena2v2Tile.bracketBestLabel.textColor[2] == shuffleTile.specRows[1].record.textColor[2]
        and arena2v2Tile.bracketBestLabel.textColor[3] == shuffleTile.specRows[1].record.textColor[3]
        and arena2v2Tile.bracketBestLabel.textColor[4] == shuffleTile.specRows[1].record.textColor[4],
    "non-solo Best labels should retain their muted color")
local arenaRatePoint = arena2v2Tile.rate.points[#arena2v2Tile.rate.points]
local arenaRecordPoint = arena2v2Tile.record.points[#arena2v2Tile.record.points]
local arenaBestPoint = arena2v2Tile.bracketBestLabel.points[#arena2v2Tile.bracketBestLabel.points]
local arenaRatingPoint = arena2v2Tile.bracketMaxRating.points[#arena2v2Tile.bracketMaxRating.points]
assert(arenaRatePoint[1] == "LEFT" and arenaRatePoint[3] == "TOPLEFT" and arenaRatePoint[4] == 11,
    "non-solo win rate should be aligned on the left")
assert(arenaBestPoint[1] == "LEFT" and arenaBestPoint[3] == "TOPLEFT"
        and arenaBestPoint[4] == arenaRatePoint[4],
    "non-solo Best rating label should align with the win rate")
assert(arenaRecordPoint[1] == "RIGHT" and arenaRecordPoint[3] == "TOPRIGHT" and arenaRecordPoint[4] == -10,
    "non-solo win/loss record should be aligned on the right")
assert(arenaRatingPoint[1] == "LEFT" and arenaRatingPoint[2] == arena2v2Tile
        and arenaRatingPoint[3] == "TOPRIGHT" and arenaRatingPoint[4] == -120,
    "non-solo rating should use the fixed value-column cut")
local arena3v3RecordPoint = arena3v3Tile.record.points[#arena3v3Tile.record.points]
local arena3v3RatingPoint = arena3v3Tile.bracketMaxRating.points[#arena3v3Tile.bracketMaxRating.points]
assert(arena2v2Tile.record.width == arena3v3Tile.record.width
        and arenaRecordPoint[4] == arena3v3RecordPoint[4]
        and arenaRatingPoint[4] == arena3v3RatingPoint[4],
    "2v2 and 3v3 values should share the same fixed column")
assert(arena2v2Tile.bracketClassIcon:IsShown()
        and arena2v2Tile.bracketClassIcon.texture
            == "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes",
    "non-solo best rating should display its class icon")
local arenaClassIconPoint = arena2v2Tile.bracketClassIcon.points[#arena2v2Tile.bracketClassIcon.points]
assert(arenaClassIconPoint[1] == "LEFT" and arenaClassIconPoint[2] == arena2v2Tile.bracketMaxRating
        and arenaClassIconPoint[3] == "RIGHT" and arenaClassIconPoint[4] == 4,
    "non-solo class icon should appear immediately after the best rating")
arena2v2Tile.bracketClassIconHitbox.scripts.OnEnter(arena2v2Tile.bracketClassIconHitbox)
assert(GameTooltip.shown and GameTooltip.text == "Warrior",
    "non-solo best-rating icon tooltip should identify the class")
arena2v2Tile.bracketClassIconHitbox.scripts.OnLeave(arena2v2Tile.bracketClassIconHitbox)
assert(rbgTile.noData:IsShown() and rbgTile.noData.text == "No data",
    "an empty 10v10 bracket should display only No data")
local noDataPoint = rbgTile.noData.points[#rbgTile.noData.points]
assert(noDataPoint[1] == "CENTER" and noDataPoint[3] == "CENTER"
        and noDataPoint[4] == 0 and noDataPoint[5] == 0,
    "No data should be centered horizontally and vertically in its bracket card")
assert(not rbgTile.games:IsShown() and not rbgTile.rate:IsShown() and not rbgTile.record:IsShown()
        and not rbgTile.bracketBestLabel:IsShown() and not rbgTile.bracketMaxRating:IsShown()
        and not rbgTile.mostPlayedLabel:IsShown() and not rbgTile.mostPlayedGames:IsShown(),
    "an empty 10v10 bracket should hide all empty statistics")
assert(rbgTile.noData.textColor[1] == arena2v2Tile.bracketBestLabel.textColor[1]
        and rbgTile.noData.textColor[2] == arena2v2Tile.bracketBestLabel.textColor[2]
        and rbgTile.noData.textColor[3] == arena2v2Tile.bracketBestLabel.textColor[3],
    "No data should use the Best rating label color")
assert(arena2v2Tile.bracketMaxRating:IsShown()
        and arena3v3Tile.bracketMaxRating:IsShown(),
    "non-empty spec-agnostic brackets should show their maximum ratings")
assert(not shuffleTile.bracketMaxRating:IsShown(),
    "solo brackets should use their per-spec maximum-rating column")
local arena2v2Point = arena2v2Tile.points[#arena2v2Tile.points]
local arena3v3Point = arena3v3Tile.points[#arena3v3Tile.points]
local rbgPoint = rbgTile.points[#rbgTile.points]
assert(arena2v2Point[4] == arena3v3Point[4] and arena3v3Point[4] == rbgPoint[4],
    "2v2, 3v3, and 10v10 should share the far-right column")
assert(arena2v2Tile.height == arena3v3Tile.height,
    "populated non-solo cards should use the same height and internal cut")
assert(rbgTile.height == 64 and rbgTile.height < arena3v3Tile.height,
    "empty bracket cards should collapse around their No data message")
assert(arena2v2Point[5] > arena3v3Point[5] and arena3v3Point[5] > rbgPoint[5],
    "10v10 should be positioned below 2v2 and 3v3")

seasonActive = false
ns.SeasonUI.Refresh()
assert(seasonBar.statusText.text == "Season ended", "ended-season status is missing")
assert(summaryButton.label.text == "View Rewind", "ended current season should open Rewind")
assert(WarbandRatingsRewindCard.title.text == "Season 2 Rewind",
    "ended current season should use the Rewind title")

seasonHasData = false
ns.SeasonUI.Refresh()
assert(ns.SeasonUI.GetSelectedSeasonState() == "inactive",
    "the selected preseason state was not exposed to the table UI")
assert(seasonBar.statusText.text == "Season not active", "preseason status is missing")
assert(summaryButton.label.text == "View Statistics", "an upcoming season should not be a Rewind")
assert(WarbandRatingsRewindCard.period.text == "SEASON NOT ACTIVE",
    "upcoming-season card should explain its inactive state")
seasonHasData = true

for _, region in ipairs(regions) do
    assert(region.text ~= "Expansion", "expansion caption should not be displayed")
    assert(region.text ~= "Season", "season caption should not be displayed")
    assert(region.text ~= "Season summary", "statistics caption should not be displayed")
    assert(region.text ~= "Mouse wheel to see more", "scroll hint should not be displayed")
    assert(region.text ~= "WARBAND PVP COMPANION", "addon name should not be displayed above the title")
end

local seasonOneButton
for _, frame in ipairs(frames) do
    if frame.optionKey == "pvp-41" then
        seasonOneButton = frame
        break
    end
end
assert(seasonOneButton and seasonOneButton.scripts.OnClick, "past-season dropdown option was not created")
seasonOneButton.scripts.OnClick(seasonOneButton)
assert(selectedSeasonKey == "pvp-41", "past season selection was not propagated")
assert(WarbandRatingsRewindCard.title.text == "Season 1 Rewind", "past-season Rewind title is incorrect")

print("season UI tests passed")
