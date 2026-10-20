-- luacheck: globals WarbandRatingsDB CreateFrame GetBuildInfo GetCurrentArenaSeason
-- luacheck: globals GetPersonalRatedInfo GetAchievementCriteriaInfo UnitGUID

local seasonID = 42
local rating = 2434
local wins, required = 0, 100
local gladiatorWins = 0
local events = {}
local eventFrame
local playerGUID = "Player-123"
UnitGUID = function() return playerGUID end
WarbandRatingsDB = { settings = {} }
GetBuildInfo = function() return "12.1.5", nil, nil, 120105 end
GetCurrentArenaSeason = function() return seasonID end
GetPersonalRatedInfo = function() return rating end
GetAchievementCriteriaInfo = function(achievementID, criteriaIndex)
    if achievementID == 62930 then
        assert(criteriaIndex == 1, "read the seasonal Gladiator win counter")
        return "Qualifying matches", nil, gladiatorWins == 50, gladiatorWins, 50
    end
    assert(achievementID == 62932 and criteriaIndex == 1, "read the current seasonal Legend round counter")
    return "Qualifying rounds", nil, wins == required, wins, required
end
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent(event) events[event] = true end
    function frame:RegisterUnitEvent() end
    function frame:SetScript(script, handler)
        if script == "OnEvent" then
            self.onEvent = handler
            eventFrame = self
        end
    end
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
assert(State().titleProgress == nil, "Elite rating alone must not show progress before a qualifying win")
wins = 1
assert(State().titleProgress == "Legend: 1/100", "the first qualifying round should start tracking")
rating = 2200
assert(State().titleProgress == "Legend: 1/100", "falling below Elite must not hide existing progress")
wins = 12
assert(State().titleProgress == "Legend: 12/100", "display Blizzard's count, independent of sampled rating")

-- Recreate the module without addon-saved progress, as on a reload or login.
assert(loadfile("ArenaQueue.lua"))("WarbandRatings", ns)
buildCardState = assert(FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState"))
assert(State().titleProgress == "Legend: 12/100", "existing progress must appear after login below Elite")
wins = 100
assert(State().titleProgress == "Legend: 100/100", "completed progress must remain visible")
assert(State({ key = "ratedBGBlitz", category = "rated", bracketIndex = 9 }).titleProgress == nil,
    "Legend must only appear on the Solo Shuffle card")
seasonID = 43
assert(State().titleProgress == nil, "a future season must not inherit the previous Legend achievement")
seasonID = 42
wins = 0
assert(State().titleProgress == nil, "a character without qualifying wins must not inherit another character's progress")

local function StartSession(reloading)
    assert(loadfile("ArenaQueue.lua"))("WarbandRatings", ns)
    buildCardState = assert(FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState"))
    updateCard = assert(FindUpvalue(ns.ArenaQueue.Attach, "UpdateCard"))
    eventFrame.onEvent(eventFrame, "PLAYER_LOGIN")
    eventFrame.onEvent(eventFrame, "PLAYER_ENTERING_WORLD", not reloading, reloading)
end
StartSession(false)
-- No card reads before the first win: login must capture zero even when hidden.
wins = 1
assert(State().titleDelta == 1, "the first qualifying win must count from a zero baseline")
wins = 12
assert(State().titleDelta == 12, "delta must count all qualifying rounds in the current session")
eventFrame.onEvent(eventFrame, "PLAYER_ENTERING_WORLD", false, false)
assert(State().titleDelta == 12, "zone changes must not reset the session")
eventFrame.onEvent(eventFrame, "PLAYER_SPECIALIZATION_CHANGED", "player")
assert(State().titleDelta == 12, "specialization changes must retain character-wide Legend progress")
StartSession(true)
assert(State().titleDelta == 12, "UI reloads must preserve the original Legend baseline")
local savedSession = WarbandRatingsDB.settings.arenaQueueRatingSessions[playerGUID]
savedSession.legendBaselines = savedSession.titleBaselines
savedSession.titleBaselines = nil
StartSession(true)
assert(State().titleDelta == 12, "upgrading the Legend-only baseline format must preserve the session delta")
StartSession(false)
assert(State().titleDelta == 0, "fresh logins must reset the delta, just like rating")
wins = 15
assert(State().titleDelta == 3, "new sessions must measure from their login count")
WarbandRatingsDB.settings.arenaQueueRatingSessions[playerGUID].titleBaselines = nil
StartSession(true)
assert(State().titleDelta == 0, "existing rating sessions without Legend baselines must initialize safely")
wins = 18
assert(State().titleDelta == 3, "migrated sessions must track subsequent wins")
playerGUID = "Player-456"
wins = 2
StartSession(false)
assert(State().titleDelta == 0, "another character must start with its own baseline")
wins = 5
assert(State().titleDelta == 3, "another character's session must track independently")

local arena = { key = "arena3v3", category = "rated", bracketIndex = 2, label = "3v3 Arena" }
rating = 2450
assert(State(arena).titleProgress == nil, "Gladiator must stay hidden before the first qualifying win")
gladiatorWins = 1
assert(State(arena).titleProgress == "Gladiator: 1/50" and State(arena).titleDelta == 1,
    "the first Gladiator win must count even if no 3v3 card was shown at login")
rating = 2200
gladiatorWins = 7
assert(State(arena).titleProgress == "Gladiator: 7/50" and State(arena).titleDelta == 7,
    "Gladiator progress and session wins must remain visible below Elite")
assert(State().titleProgress == "Legend: 5/100" and State().titleDelta == 3,
    "Gladiator wins must not change Legend progress or its session delta")
eventFrame.onEvent(eventFrame, "PLAYER_ENTERING_WORLD", false, false)
eventFrame.onEvent(eventFrame, "PLAYER_SPECIALIZATION_CHANGED", "player")
assert(State(arena).titleDelta == 7, "Gladiator's session must survive zone and specialization changes")
StartSession(true)
assert(State(arena).titleDelta == 7, "Gladiator session wins must survive UI reloads")
StartSession(false)
assert(State(arena).titleDelta == 0, "Gladiator session wins must reset on fresh login")
gladiatorWins = 50
assert(State(arena).titleProgress == "Gladiator: 50/50" and State(arena).titleDelta == 43,
    "Gladiator completion must keep the progress and session delta visible")
assert(State({ key = "arena2v2", category = "rated", bracketIndex = 1 }).titleProgress == nil,
    "Gladiator progress must not appear on 2v2")
seasonID = 43
assert(State(arena).titleProgress == nil, "a new season must not inherit old Gladiator progress")
seasonID = 42
playerGUID = "Player-789"
gladiatorWins = 4
StartSession(false)
assert(State(arena).titleDelta == 0, "Gladiator sessions must be separate for each character")

wins, required = nil, nil
StartSession(false)
assert(State().titleProgress == nil, "missing achievement data must be safe")
wins, required = 20, 100
eventFrame.onEvent(eventFrame, "RECEIVED_ACHIEVEMENT_LIST")
wins = 23
assert(State().titleDelta == 3, "delayed achievement data must establish the baseline before further wins")
wins, required = 12, 0
assert(State().titleProgress == nil, "an unavailable target must not produce a counter")
required = 100
GetAchievementCriteriaInfo = nil
assert(State().titleProgress == nil, "an unavailable achievement API must be safe")

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
    "borderLeft", "borderRight", "modeName", "progressBg", "actionButton", "statusDot", "badgeBg", "badge", "badgeRank",
    "ratingValue", "ratingLabel", "sessionDelta", "mmrValue", "mmrLabel", "mmrDelta", "titleProgress", "statusText",
    "queuedRoleIcon", "queueText", "compactRating", "compactDelta", "readyGlow", "progressFill",
}) do
    card[key] = Widget()
end
local state = State()
state.titleProgress = "Legend: 12/100"
updateCard(card, state)
assert(card.titleProgress.shown and card.titleProgress.text == "Legend: 12/100",
    "expanded cards must show the progress text")
state.titleDelta = 5
updateCard(card, state)
assert(card.titleProgress.text == "|cff3df27a+5|r Legend: 12/100",
    "positive session rounds must precede the count in the rating gain color")
state.titleDelta = -2
updateCard(card, state)
assert(card.titleProgress.text == "|cffff5151-2|r Legend: 12/100",
    "negative adjustments must use the rating loss color")
state.titleDelta = 0
updateCard(card, state)
assert(card.titleProgress.text == "Legend: 12/100", "zero deltas must stay hidden like rating deltas")
state.titleDelta = 5
WarbandRatingsDB.settings.arenaQueueMinimized = true
updateCard(card, state)
assert(not card.titleProgress.shown, "compact cards must preserve their existing layout")
WarbandRatingsDB.settings.arenaQueueMinimized = false
updateCard(card, state)
assert(card.titleProgress.shown, "expanding the card must restore the tracker")
state.titleProgress = nil
updateCard(card, state)
assert(not card.titleProgress.shown and card.titleProgress.text == "",
    "a reused card must clear previous Legend progress")

print("arena queue Legend tests passed")
