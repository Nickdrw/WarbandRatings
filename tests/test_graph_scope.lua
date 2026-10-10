-- luacheck: globals time date CreateFrame UIParent UISpecialFrames GameTooltip tinsert
-- luacheck: globals GetCursorPosition
-- luacheck: globals UnitName GetNormalizedRealmName GetRealmName

local now = os.time({ year = 2026, month = 10, day = 6, hour = 15 })
time = function(parts) return parts and os.time(parts) or now end
date = os.date
tinsert = table.insert

local ns = { Database = {}, DataCollection = {}, History = {}, Utils = {} }
ns.Utils.CharKey = function(name, realm) return name .. "-" .. realm end
UnitName = function() return "Tester" end
GetNormalizedRealmName = function() return "Realm" end
GetRealmName = function() return "Realm" end
local characterSettings = {}
local savedSessions = {}
ns.History.GetLastSession = function(charKey)
    local session = savedSessions[charKey]
    return session and session.endTime <= now and session or nil
end
ns.History.SaveLastSession = function(charKey, startTime, endTime)
    savedSessions[charKey] = { startTime = startTime, endTime = endTime }
    return true
end
ns.Database.GetCharacterSetting = function(key) return characterSettings[key] end
ns.Database.SetCharacterSetting = function(key, value) characterSettings[key] = value end
assert(loadfile("UI.lua"))("WarbandRatings", ns)
local UI = ns.UI
local midnight = os.time({ year = 2026, month = 10, day = 6, hour = 0 })
local points = {
    { midnight - 1, 1400, 1500, 0, 0, 1, true },
    { midnight, 1420, 1520, 20, 20, 1, true },
    { now - 3600, 1440, 1540, 20, 20, 1, true },
    { now - 60, 1460, 1560, 20, 20, 1, true },
    { now, 1480, 1580, 20, 20, 1, true },
}
ns.History.GetAvailableSeasonKeys = function() return { "pvp-42" } end
ns.History.GetSeasonCharacters = function()
    return { ["Tester-Realm"] = { series = { global = { arena2v2 = { points = points } } } } }
end
now = now - 3600
UI.StartHistorySession()
now = now + 3600
local reloadedNS = { Database = ns.Database, DataCollection = {}, History = ns.History, Utils = ns.Utils }
assert(loadfile("UI.lua"))("WarbandRatings", reloadedNS)
reloadedNS.UI.StartHistorySession(true)
assert(reloadedNS.UI.GraphScope.sessionStart == UI.GraphScope.sessionStart,
    "a UI reload should restore the original session boundary from saved character settings")
assert(#reloadedNS.UI.GraphScope.GetPoints(points, "session") == 3,
    "matches played before reloading should remain in the session curve")
reloadedNS.UI.StartHistorySession(false)
assert(reloadedNS.UI.GraphScope.sessionStart == now,
    "a fresh login should replace the saved session boundary")
for _, invalidStart in ipairs({ "invalid", -1, 0, now + 1 }) do
    characterSettings.historyGraphSessionStart = invalidStart
    reloadedNS.UI.StartHistorySession(true)
    assert(reloadedNS.UI.GraphScope.sessionStart == now,
        "a reload without a valid saved boundary should start a new session")
end
characterSettings.historyGraphSessionStart = nil
reloadedNS.UI.StartHistorySession(true)
assert(reloadedNS.UI.GraphScope.sessionStart == now,
    "the first reload after upgrading should initialize a missing session boundary")
characterSettings.historyGraphSessionStart = UI.GraphScope.sessionStart
local scoped = UI.GraphScope.GetPoints(points, "session")
assert(#scoped == 3 and scoped[1] == points[3] and scoped[3] == points[5],
    "session scope should include its exact start and retain the complete match metadata")
scoped = UI.GraphScope.GetPoints(points, "day")
assert(#scoped == 4 and scoped[1] == points[2],
    "today should include midnight and exclude the previous day's last second")
assert(UI.GraphScope.GetPoints(points, "season") == points and #points == 5,
    "filtering must preserve the stored season history")
assert(#UI.GraphScope.GetPoints(nil, "session") == 0,
    "missing history should produce an empty scope")
assert(#UI.GraphScope.GetPoints({ points[1] }, "day") == 0,
    "a historical season must not substitute its last played day for today")
assert(#UI.GraphScope.GetPoints({ { now + 1, 1500 } }, "session") == 0,
    "session scope should exclude future timestamps")
assert(#UI.GraphScope.GetPoints({ { "invalid", 1500 } }, "day") == 0,
    "invalid timestamps should not enter a time-filtered curve")

-- Run in Europe/Paris as well as UTC to exercise both daylight-saving transitions.
for _, transition in ipairs({ { month = 3, day = 29 }, { month = 10, day = 25 } }) do
    local endOfDay = os.time({ year = 2026, month = transition.month, day = transition.day, hour = 23, min = 59 })
    local startOfDay = os.time({ year = 2026, month = transition.month, day = transition.day, hour = 0 })
    local transitionPoints = { { startOfDay - 1, 1400 }, { startOfDay, 1420 }, { endOfDay, 1440 } }
    scoped = UI.GraphScope.GetPoints(transitionPoints, "day", endOfDay)
    assert(#scoped == 2 and scoped[1] == transitionPoints[2],
        "today should use local midnight even when the day's UTC offset changes")
end

local methods = {}
local function NewRegion(parent)
    return setmetatable({ parent = parent, shown = true, scripts = {}, width = 780, height = 210 }, { __index = methods })
end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetLeft() return self.left end
function methods:GetTop() return self.top end
function methods:GetEffectiveScale() return 1 end
function methods:GetRight() return nil end
function methods:GetFrameLevel() return 1 end
function methods:GetRegions() end
function methods:GetStringWidth() return #(self.text or "") * 6 end
function methods:SetText(text) self.text = text end
function methods:CreateTexture() return NewRegion(self) end
function methods:CreateFontString() return NewRegion(self) end
function methods:CreateLine() return NewRegion(self) end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:Show() self.shown = true end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:SetChecked(checked) self.checked = checked end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetValue(value)
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
for _, name in ipairs({
    "SetFrameStrata", "SetFrameLevel", "SetMovable", "SetClampedToScreen",
    "EnableMouse", "RegisterForDrag", "SetJustifyH", "SetAllPoints", "SetColorTexture", "SetThickness",
    "SetStartPoint", "SetEndPoint", "EnableMouseWheel", "SetMinMaxValues", "SetValueStep", "SetAlpha",
    "SetTextColor", "SetWordWrap", "SetNonSpaceWrap", "SetJustifyV",
}) do methods[name] = function() end end
CreateFrame = function(_, _, parent) return NewRegion(parent) end
UIParent = NewRegion()
UISpecialFrames = {}
GetCursorPosition = function() return 60, 150 end
GameTooltip = {
    IsOwned = function(self, owner) return self.owner == owner end,
    SetOwner = function(self, owner) self.owner = owner end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    ClearLines = function() end,
    AddLine = function() end,
    AddDoubleLine = function() end,
}
ns.Utils.GetClassColor = function() return 0.5, 0.6, 0.7 end
assert(UI.GraphScope.IsCurrentCharacter("Tester-Realm"), "the live session should belong to the logged-in character")
assert(not UI.GraphScope.IsCurrentCharacter("Other-Realm") and not UI.GraphScope.IsCurrentCharacter("Tester-OtherRealm"),
    "another character, including a namesake on another realm, should use its own saved session")
ns.Database.IsPVPColumn = function() return true end
ns.Database.IsSpecColumn = function() return false end
ns.History.GetContentSeasonKey = function() return "pvp-42" end
local otherPoints, specPoints = points, {}
ns.History.GetAvailableSeasonKeys = function() return { "pvp-42", "pvp-41" } end
ns.History.GetSeasonCharacters = function(seasonKey)
    if seasonKey ~= "pvp-42" then return {} end
    return {
        ["Tester-Realm"] = { series = {
            global = { arena2v2 = { points = points } },
            specs = { [71] = { soloShuffle = { points = specPoints } } },
        } },
        ["Other-Realm"] = { series = { global = { arena2v2 = { points = otherPoints } } } },
    }
end
ns.History.GetSeriesForSeason = function(seasonKey, charKey)
    if seasonKey == "pvp-42" then return { points = charKey == "Other-Realm" and otherPoints or points } end
    return { points = { { os.time({ year = 2026, month = 3, day = 20, hour = 15 }), 1400 } } }
end
ns.Season = {
    GetContentSeasonKey = ns.History.GetContentSeasonKey,
    GetPreviousSeasonKey = function() return "pvp-41" end,
    GetPVPSeasonStartTime = function(seasonKey)
        return seasonKey == "pvp-42"
            and os.time({ year = 2026, month = 8, day = 19, hour = 0 })
            or os.time({ year = 2026, month = 3, day = 18, hour = 0 })
    end,
}

local panel = UI.CreateHistoryGraphPanel()
UI.ShowHistoryGraph({ name = "Tester", realm = "Realm", classFilename = "WARRIOR" }, 0,
    { key = "arena2v2", label = "2v2" })
assert(panel.graphData.pointCount == 5 and panel.historyScope == "season", "graphs should default to the full season")
panel:SetWidth(400)
UI.RefreshHistoryGraph()
assert(panel.zoomSlider:GetWidth() == 108, "moving scope into the header should restore the full zoom slider width")
panel:SetWidth(780)
UI.RefreshHistoryGraph()
panel.canvas.left, panel.canvas.top = 0, 200
local function UpdateHover() panel.hoverFrame.scripts.OnUpdate(panel.hoverFrame) end
UpdateHover()
assert(panel.hoverLine:IsShown() and GameTooltip:IsOwned(panel.canvas), "curve hover should work before opening the menu")
panel.scopeButton.scripts.OnEnter(panel.scopeButton)
UpdateHover()
assert(not panel.hoverLine:IsShown() and not panel.hoverDot:IsShown()
    and GameTooltip:IsOwned(panel.scopeButton) and GameTooltip.shown,
    "hovering the selector should clear the curve marker and preserve the selector's tooltip")
panel.scopeButton.scripts.OnClick(panel.scopeButton)
panel.scopeButton.scripts.OnLeave(panel.scopeButton)
UpdateHover()
assert(not panel.hoverLine:IsShown() and not panel.hoverDot:IsShown() and not GameTooltip.shown,
    "an open scope menu should block the graph's per-frame hover update over its options")
panel.scopeMenu:Hide()
UpdateHover()
assert(panel.hoverLine:IsShown() and GameTooltip:IsOwned(panel.canvas) and GameTooltip.shown,
    "curve hover should resume when the dropdown closes")
panel.modeSwitch.scripts.OnClick(panel.modeSwitch)
UpdateHover()
panel.scopeButton.scripts.OnClick(panel.scopeButton)
UpdateHover()
assert(not panel.hoverLine:IsShown() and not panel.hoverDot:IsShown() and not GameTooltip.shown,
    "the open dropdown should also suppress day-curve hover")
panel.scopeMenu:Hide()
panel.modeSwitch.scripts.OnClick(panel.modeSwitch)
panel.title.left, panel.mmrToggle.left = 100, 350
UI.RefreshHistoryGraph()
local scopeAnchor, titleWidth = panel.scopeButton.point, panel.title:GetWidth()
local function ChooseScope(index)
    panel.scopeButton.scripts.OnClick(panel.scopeButton)
    assert(panel.scopeMenu:IsShown(), "the selector should open its options")
    local button = panel.scopeMenu.buttons[index]
    button.scripts.OnClick(button)
    assert(not panel.scopeMenu:IsShown(), "choosing a scope should close the menu")
    assert(panel.scopeButton.point == scopeAnchor and panel.title:GetWidth() == titleWidth,
        "the scope selector should retain its anchor and title spacing when the axis controls are hidden")
end
panel.viewportStart, panel.viewportAtLatest = 1, false
ChooseScope(1)
assert(panel.historyScope == "session" and panel.graphData.pointCount == 3
    and panel.graphData.points[1] == points[3] and panel.viewportAtLatest,
    "selecting Session should redraw only session matches and reset the viewport")
assert(panel.graphData.mmrValues[1] == 1540 and panel.graphData.mmrValues[3] == 1580,
    "the MMR curve should follow the same scoped matches as the rating curve")
assert(not panel.modeSwitch:IsShown(), "session curves should use games rather than season days")
ChooseScope(2)
assert(panel.historyScope == "day" and panel.graphData.pointCount == 4, "Today should redraw the calendar day's matches")
assert(panel.compareToggle.enabled, "season comparison should remain available from a shorter scope")
panel.compareToggle:SetChecked(true)
panel.compareToggle.scripts.OnClick(panel.compareToggle)
assert(panel.historyScope == "season" and panel.graphData.pointCount == 5
    and panel.graphData.dayComparisonActive and panel.comparePrevious,
    "comparison should restore the full season and use the existing elapsed-day curves")
ChooseScope(1)
assert(not panel.comparePrevious and not panel.graphData.dayComparisonActive,
    "choosing Session should leave season comparison and restore the game axis")
local column = { key = "arena2v2", label = "2v2" }
savedSessions["Other-Realm"] = { startTime = midnight, endTime = now - 3600 }
UI.ShowHistoryGraph({ name = "Other", realm = "Realm", classFilename = "WARRIOR" }, 0, column)
assert(panel.historyScope == "session" and panel.graphData.pointCount == 2
    and panel.graphData.points[1] == otherPoints[2] and panel.graphData.points[2] == otherPoints[3]
    and panel.viewportAtLatest and panel.scopeMenu.buttons[1]:IsShown(),
    "switching characters should retain Session and filter by the other character's saved start and end")
assert(panel.showingLastSession and panel.sessionLabel.text == "Last session from 06/10/2026",
    "another character's saved session should display its own date")
assert(panel.scopeMenu:GetHeight() == 80 and panel.scopeMenu.buttons[2].point[3] == -29,
    "every character should have all three scope options")
UI.ShowHistoryGraph({ name = "Tester", realm = "OtherRealm", classFilename = "WARRIOR" }, 0, column)
assert(panel.historyScope == "session" and panel.graphData == nil and not panel.sessionLabel:IsShown()
    and panel.emptyText.text == "No saved session for this character yet.",
    "a namesake without a saved session should not show the logged-in character's games or date")
ChooseScope(2)
assert(panel.historyScope == "day", "Today should remain available for another character")
ChooseScope(3)
UI.ShowHistoryGraph({ name = "Tester", realm = "Realm", classFilename = "WARRIOR" }, 0, column)
assert(panel.scopeMenu.buttons[1]:IsShown() and panel.scopeMenu:GetHeight() == 80,
    "returning to the logged-in character should keep the Session option")
ChooseScope(1)
now = now + 86400
UI.StartHistorySession()
UI.RefreshHistoryGraph()
assert(panel.graphData.pointCount == 3 and panel.graphData.points[1] == points[3],
    "a new login without matches should retain the previous played session")
assert(panel.sessionLabel:IsShown() and panel.sessionLabel.text == "Last session from 06/10/2026",
    "the saved session should display its starting date above the plot")
local savedSession = savedSessions["Tester-Realm"]
now = now + 86400
UI.StartHistorySession(false)
ChooseScope(1)
UI.RefreshHistoryGraph()
assert(savedSessions["Tester-Realm"] == savedSession and panel.graphData.pointCount == 3,
    "logging out and back in without playing should not overwrite the last played session")
UI.StartHistorySession(true)
UI.RefreshHistoryGraph()
assert(panel.showingLastSession and panel.graphData.pointCount == 3,
    "the saved session should survive a reload before any new games")
ChooseScope(2)
assert(panel.graphData == nil and panel.emptyText.text:find("today", 1, true),
    "an empty calendar day should clear old curves and explain the empty day")
assert(not panel.sessionLabel:IsShown(), "the session date label should be hidden outside Session scope")
ChooseScope(3)
assert(panel.graphData.pointCount == 5, "returning to Season should restore every stored match")
panel.scopeButton.scripts.OnClick(panel.scopeButton)
panel:Hide()
assert(not panel.scopeMenu:IsShown(), "closing the graph should also close its scope menu")

local overnightMidnight = os.time({ year = 2026, month = 10, day = 7, hour = 0, min = 0, sec = 0 })
points = {}
for index = 1, 6 do
    points[#points + 1] = { overnightMidnight - (36 - index * 4) * 60, 1900 + index * 10, 2100, 10, 0, 1, true }
end
for index = 1, 9 do
    points[#points + 1] = { overnightMidnight + index * 6 * 60, 1960 + index * 10, 2100, 10, 0, 1, true }
end
otherPoints = {}
for index, point in ipairs(points) do otherPoints[index] = { unpack(point) } end
specPoints = { { overnightMidnight + 20 * 60, 1500 } }
now = overnightMidnight - 40 * 60
UI.StartHistorySession()
now = overnightMidnight + 54 * 60
UI.ShowHistoryGraph({ name = "Tester", realm = "Realm", classFilename = "WARRIOR" }, 0, column)
ChooseScope(1)
assert(panel.graphData.pointCount == 15, "an overnight session should retain all six pre-midnight and nine post-midnight games")
ChooseScope(2)
assert(panel.graphData.pointCount == 15 and panel.graphData.points[1] == points[1],
    "Today should retain the entire session after it crosses midnight")
UI.StartHistorySession(true)
UI.RefreshHistoryGraph()
assert(panel.graphData.pointCount == 15, "Today's extension should survive reloading during the overnight session")
assert(points[1].playDay == nil and points[6].playDay == nil,
    "pre-midnight games should retain their natural calendar day")
assert(points[7].playDay == "2026-10-06" and points[15].playDay == "2026-10-06"
    and specPoints[1].playDay == "2026-10-06",
    "after-midnight games in both global and spec histories should persist the session's starting day")
UI.ShowHistoryGraph({ name = "Other", realm = "Realm", classFilename = "WARRIOR" }, 0, column)
assert(panel.historyScope == "day" and panel.graphData.pointCount == 9,
    "another character's Today scope should continue to use the current calendar day")
UI.ShowHistoryGraph({ name = "Tester", realm = "Realm", classFilename = "WARRIOR" }, 0, column)
local latePoint = { now + 60, 2060 }
points[#points + 1] = latePoint
now = now + 60
UI.FinishHistorySession()
assert(latePoint.playDay == "2026-10-06", "logout should assign games played since the last reload")
now = now + 60
UI.StartHistorySession(false)
UI.RefreshHistoryGraph()
assert(panel.graphData == nil,
    "a fresh login after midnight should exclude games assigned to the previous play day")
local freshNS = { Database = ns.Database, History = ns.History, DataCollection = {}, Utils = ns.Utils }
assert(loadfile("UI.lua"))("WarbandRatings", freshNS)
freshNS.UI.StartHistorySession(true)
assert(#freshNS.UI.GraphScope.GetPoints(points, "day", now, "Tester-Realm") == 0,
    "reloading the addon on the new day should retain the saved play-day assignments")
ChooseScope(1)
assert(panel.graphData.pointCount == 16 and panel.showingLastSession
    and panel.sessionLabel.text == "Last session from 06/10/2026",
    "an overnight session should remain visible under its starting date after the next login")
assert(#freshNS.UI.GraphScope.GetPoints(points, "session", now, "Tester-Realm") == 16,
    "a reloaded addon should restore the complete previous overnight session")
local todayPoint = { now, 2070 }
points[#points + 1] = todayPoint
UI.RefreshHistoryGraph()
assert(panel.graphData.pointCount == 1 and not panel.showingLastSession
    and panel.sessionLabel.text == "Session from 07/10/2026",
    "the first new game should replace the saved curve and label with the current session")
ChooseScope(2)
assert(panel.graphData.pointCount == 1 and panel.graphData.points[1] == todayPoint,
    "games from a new session today should still appear in Today")
UI.FinishHistorySession()
assert(todayPoint.playDay == nil, "a session that does not cross midnight should not reassign any games")
ChooseScope(3)
assert(panel.graphData.pointCount == 17, "Season should retain every game regardless of its assigned play day")
ChooseScope(1)
assert(panel.graphData.pointCount == 1, "Session should still filter by actual match timestamps")
assert(#UI.GraphScope.GetPoints(otherPoints, "day", now, "Other-Realm") == 9 and otherPoints[7].playDay == nil,
    "ending the player's session should not reassign another character's games")

local fallbackPoint = { now + 86400, 2080 }
points[#points + 1] = fallbackPoint
now = now + 86400 + 60
UI.StartHistorySession(false)
assert(fallbackPoint.playDay == "2026-10-07",
    "the next login should recover a previous overnight assignment if logout was not handled")
assert(#UI.GraphScope.GetPoints(points, "day", now, "Tester-Realm") == 0,
    "recovered overnight assignments should also be excluded from the new day's Today")

-- The session boundary is shared by all brackets, including spec-specific histories.
ChooseScope(1)
UI.RefreshHistoryGraph()
assert(panel.showingLastSession and panel.graphData.pointCount == 2,
    "a new login should retain the last played session across all brackets")
now = now + 60
specPoints[#specPoints + 1] = { now, 1510 }
UI.RefreshHistoryGraph()
assert(not panel.showingLastSession and panel.graphData == nil
    and panel.emptyText.text:find("in this session", 1, true),
    "a new game in another bracket should start the current session for every graph")
UI.FinishHistorySession()
assert(savedSessions["Tester-Realm"].startTime == UI.GraphScope.sessionStart
    and savedSessions["Tester-Realm"].endTime == now,
    "logout should save the played session even when the selected bracket has no new games")
now = now + 86400
UI.StartHistorySession(false)
UI.RefreshHistoryGraph()
assert(panel.showingLastSession and panel.graphData == nil
    and panel.emptyText.text:find("in the last session", 1, true),
    "an empty bracket in the last session should not fall back to an older session's games")

local lastSession = savedSessions["Tester-Realm"]
savedSessions["Tester-Realm"] = nil
characterSettings.historyGraphLastSession = lastSession
UI.StartHistorySession(true)
assert(savedSessions["Tester-Realm"].startTime == lastSession.startTime
    and savedSessions["Tester-Realm"].endTime == lastSession.endTime,
    "an existing character-specific saved session should migrate into shared history")
local altNS = { Database = ns.Database, History = ns.History, DataCollection = {}, Utils = ns.Utils }
assert(loadfile("UI.lua"))("WarbandRatings", altNS)
UnitName = function() return "Other" end
assert(#altNS.UI.GraphScope.GetPoints(specPoints, "session", now, "Tester-Realm") == 1,
    "a fresh addon instance on another character should read the saved session from shared history")
assert(altNS.UI.GraphScope.GetSessionRange(now, "Missing-Realm") == nil,
    "a character without saved metadata should have no session range")

print("graph scope tests passed")
