-- luacheck: globals WarbandRatingsDB CreateFrame GetBuildInfo GetCurrentArenaSeason
-- luacheck: globals GetPersonalRatedInfo GetAchievementCriteriaInfo

local seasonID = 42
local rating = 2434
local wins, required = 0, 100
local events = {}
WarbandRatingsDB = { settings = {} }
GetBuildInfo = function() return "12.1.5", nil, nil, 120105 end
GetCurrentArenaSeason = function() return seasonID end
GetPersonalRatedInfo = function() return rating end
GetAchievementCriteriaInfo = function(achievementID, criteriaIndex)
    assert(achievementID == 62932 and criteriaIndex == 1, "read the current seasonal Legend round counter")
    return "Qualifying rounds", nil, wins == required, wins, required
end
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent(event) events[event] = true end
    function frame:RegisterUnitEvent() end
    function frame:SetScript() end
    return frame
end

local function FindUpvalue(root, targetName, visited)
    if type(root) ~= "function" then return nil end
    visited = visited or {}
    if visited[root] then return nil end
    visited[root] = true
    for index = 1, 100 do
        local name, value = debug.getupvalue(root, index)
        if not name then break end
        if name == targetName then return value end
        if type(value) == "function" then
            local found = FindUpvalue(value, targetName, visited)
            if found then return found end
        end
    end
end

local ns = {}
assert(loadfile("Season.lua"))("WarbandRatings", ns)
assert(loadfile("ArenaQueue.lua"))("WarbandRatings", ns)
local buildCardState = assert(FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState"))
local updateCard = assert(FindUpvalue(ns.ArenaQueue.Attach, "UpdateCard"))
local shuffle = { key = "soloShuffle", category = "rated", bracketIndex = 7, label = "Solo Shuffle" }
local function State(bracket)
    return buildCardState(1, bracket or shuffle, nil, "Queue unavailable", 1)
end

assert(events.CRITERIA_UPDATE and events.ACHIEVEMENT_EARNED and events.RECEIVED_ACHIEVEMENT_LIST,
    "achievement progress and initial achievement data must trigger refreshes")
assert(State().legendProgress == nil, "Elite rating alone must not show progress before a qualifying win")
wins = 1
assert(State().legendProgress == "Legend: 1/100", "the first qualifying round should start tracking")
rating = 2200
assert(State().legendProgress == "Legend: 1/100", "falling below Elite must not hide existing progress")
wins = 12
assert(State().legendProgress == "Legend: 12/100", "display Blizzard's count, independent of sampled rating")

-- Recreate the module without addon-saved progress, as on a reload or login.
assert(loadfile("ArenaQueue.lua"))("WarbandRatings", ns)
buildCardState = assert(FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState"))
assert(State().legendProgress == "Legend: 12/100", "existing progress must appear after login below Elite")
wins = 100
assert(State().legendProgress == "Legend: 100/100", "completed progress must remain visible")
assert(State({ key = "ratedBGBlitz", category = "rated", bracketIndex = 9 }).legendProgress == nil,
    "Legend must only appear on the Solo Shuffle card")
seasonID = 43
assert(State().legendProgress == nil, "a future season must not inherit the previous Legend achievement")
seasonID = 42
wins = 0
assert(State().legendProgress == nil, "a character without qualifying wins must not inherit another character's progress")
wins, required = nil, nil
assert(State().legendProgress == nil, "missing achievement data must be safe")
wins, required = 12, 0
assert(State().legendProgress == nil, "an unavailable target must not produce a counter")
required = 100
GetAchievementCriteriaInfo = nil
assert(State().legendProgress == nil, "an unavailable achievement API must be safe")

local function Widget()
    local widget = {}
    function widget:SetText(value) self.text = value end
    function widget:SetShown(value) self.shown = value end
    function widget:Show() self.shown = true end
    function widget:Hide() self.shown = false end
    for _, method in ipairs({ "SetSize", "SetHeight", "ClearAllPoints", "SetPoint", "SetTexture", "SetTexCoord", "SetEnabled" }) do
        widget[method] = function() end
    end
    return widget
end
local card = Widget()
for _, key in ipairs({
    "borderLeft", "borderRight", "modeName", "progressBg", "actionButton", "statusDot", "badgeBg", "badge",
    "ratingValue", "ratingLabel", "sessionDelta", "mmrValue", "mmrLabel", "mmrDelta", "legendProgress", "statusText",
    "queuedRoleIcon", "queueText", "compactRating", "compactDelta", "readyGlow", "progressFill",
}) do
    card[key] = Widget()
end
local state = State()
state.legendProgress = "Legend: 12/100"
updateCard(card, state)
assert(card.legendProgress.shown and card.legendProgress.text == "Legend: 12/100",
    "expanded cards must show the progress text")
WarbandRatingsDB.settings.arenaQueueMinimized = true
updateCard(card, state)
assert(not card.legendProgress.shown, "compact cards must preserve their existing layout")
WarbandRatingsDB.settings.arenaQueueMinimized = false
updateCard(card, state)
assert(card.legendProgress.shown, "expanding the card must restore the tracker")
state.legendProgress = nil
updateCard(card, state)
assert(not card.legendProgress.shown and card.legendProgress.text == "",
    "a reused card must clear previous Legend progress")

print("arena queue Legend tests passed")
