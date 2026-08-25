-- luacheck: globals WarbandRatingsDB CreateFrame GetNumGroupMembers GetServerTime GetTime C_UnitAuras C_Spell C_PvP HonorFrame HonorFrameQueueButton

local epoch = 100000
local monotonic = 5000
local activeAura
local activeAuraSpellID = 1311694

WarbandRatingsDB = { settings = {} }
GetServerTime = function() return epoch end
GetTime = function() return monotonic end
GetNumGroupMembers = function() return 0 end
C_Spell = {
    GetSpellTexture = function() return 9876 end,
}
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        if spellID == activeAuraSpellID then return activeAura end
    end,
}

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:RegisterUnitEvent() end
    function frame:SetScript() end
    return frame
end

local ns = {}
assert(loadfile("ArenaQueue.lua"))("WarbandRatings", ns)

local function FindUpvalue(root, targetName, visited)
    if type(root) ~= "function" then return nil end
    visited = visited or {}
    if visited[root] then return nil end
    visited[root] = true

    for upvalueIndex = 1, 100 do
        local name, value = debug.getupvalue(root, upvalueIndex)
        if not name then break end
        if name == targetName then return value end
        if type(value) == "function" then
            local found = FindUpvalue(value, targetName, visited)
            if found then return found end
        end
    end
end

local noShow = FindUpvalue(ns.ArenaQueue.Attach, "NoShow")
local buildCardState = FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState")
assert(noShow, "No-Show tracker should be available to the queue helper")
assert(buildCardState, "queue card state builder should be reachable")

activeAura = {
    duration = 10 * 60,
    expirationTime = monotonic + 10 * 60,
    icon = 1234,
}
assert(noShow.ScanActivePenalty(), "missed-queue aura should be detected")
assert(WarbandRatingsDB.settings.arenaQueueNoShowPenalty.appliedAt == epoch,
    "aura application time should be persisted")
assert(WarbandRatingsDB.settings.arenaQueueNoShowPenalty.duration == 10 * 60,
    "observed penalty tier should be persisted")
assert(noShow.GetActiveText():find("|T1234", 1, true),
    "active message should use the aura icon")
assert(noShow.GetActiveText():find("No-Show penalty active", 1, true),
    "missed-queue aura should retain the No-Show label")
assert(not noShow.GetActiveText():find("10:00", 1, true),
    "active message should not duplicate the button countdown")
assert(noShow.GetActiveButtonText() == "10:00",
    "active button should contain only the countdown")
monotonic = monotonic + 1
assert(noShow.GetActiveButtonText() == "9:59",
    "active button countdown should update each second")
monotonic = monotonic - 1
assert(not noShow.GetWarning(), "warning should stay hidden while the debuff is active")

epoch = epoch + 10 * 60
monotonic = monotonic + 10 * 60
activeAura = nil
assert(not noShow.ScanActivePenalty(), "expired aura should no longer block queueing")

activeAuraSpellID = 368798
activeAura = {
    duration = 15 * 60,
    expirationTime = monotonic + 15 * 60,
    icon = 4321,
}
assert(noShow.ScanActivePenalty(), "match-leaving aura should be detected")
assert(noShow.GetActiveText():find("Match-leaving penalty active", 1, true),
    "match-leaving aura should use a distinct penalty label")
assert(not noShow.GetActiveText():find("No-Show penalty active", 1, true),
    "match-leaving aura should not use the missed-queue label")
activeAura = nil
activeAuraSpellID = 1311694
noShow.ScanActivePenalty()

activeAuraSpellID = 158263
activeAura = {
    duration = 60,
    expirationTime = monotonic + 29,
    icon = 2468,
}
local savedRecord = WarbandRatingsDB.settings.arenaQueueNoShowPenalty
assert(noShow.ScanActivePenalty(), "Craven aura should be detected")
assert(noShow.GetActiveText():find("Craven penalty active", 1, true),
    "Craven aura should use a distinct penalty label")
assert(noShow.GetActiveButtonText() == "0:29",
    "Craven penalty should expose its remaining duration")
assert(noShow.IsActiveForBracket({ key = "arenaSkirmish" }),
    "Craven should block Arena Skirmish")
assert(noShow.IsActiveForBracket({ key = "soloShuffle" }),
    "Craven should block Solo Shuffle")
assert(noShow.IsActiveForBracket({ key = "arena2v2" }),
    "Craven should block rated arenas")
assert(not noShow.IsActiveForBracket({ key = "ratedBGBlitz" }),
    "Craven should not block Battleground Blitz")
assert(not noShow.IsActiveForBracket({ key = "randomBattleground" }),
    "Craven should not block unrated battlegrounds")
assert(WarbandRatingsDB.settings.arenaQueueNoShowPenalty == savedRecord,
    "Craven should not alter the cumulative rated No-Show record")

HonorFrame = { BonusFrame = { Arena1Button = {} } }
HonorFrameQueueButton = {}
C_PvP = {
    GetSkirmishInfo = function()
        return { minPlayers = 1, maxPlayers = 3 }
    end,
}
local skirmishState = buildCardState(1, {
    key = "arenaSkirmish",
    category = "unrated",
    targetKey = "Arena1Button",
}, nil, nil, 1)
assert(skirmishState.failureKind == "noShow"
        and skirmishState.failureReason:find("Craven penalty active", 1, true),
    "Arena Skirmish card should show the active Craven penalty")
assert(not skirmishState.buttonEnabled and skirmishState.statusText == "UNAVAILABLE",
    "Arena Skirmish queue action should be disabled while Craven is active")

activeAura = nil
activeAuraSpellID = 1311694
noShow.ScanActivePenalty()

local warning = noShow.GetWarning()
assert(warning and warning.remainingSeconds == 50 * 60,
    "reset countdown should run from aura application")
assert(warning.nextPenaltySeconds == 15 * 60,
    "10-minute penalty should predict the 15-minute tier")
local warningText = noShow.FormatWarning(warning, false)
assert(warningText:find("50:00", 1, true) and warningText:find("15 min", 1, true),
    "warning should show reset time and predicted tier")
assert(warningText:find("Next missed queue", 1, true)
        and not warningText:find("Warning", 1, true),
    "warning copy should stay concise and rely on the alert icon")
assert(noShow.FormatWarningSentence(warning)
        == "Next missed queue within 50:00 triggers a 15 min penalty.",
    "queue warning tooltip should contain the complete sentence without an inline icon")

local warningButton = { shown = false }
function warningButton:Show() self.shown = true end
function warningButton:Hide() self.shown = false end
local tooltipTextArguments
_G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, ...) tooltipTextArguments = { ... } end,
    Show = function() end,
    Hide = function() end,
    IsOwned = function() return false end,
}
warningButton.tooltipText = noShow.FormatWarningSentence(warning)
noShow.ShowQueueWarningTooltip(warningButton)
assert(tooltipTextArguments[5] == 1 and tooltipTextArguments[6] == true,
    "tooltip text should pass alpha before the wrapping flag")
_G.GameTooltip = nil
local actionButton = {}
function actionButton:SetShown(shown) self.shown = shown end
local actionBlocker = {}
function actionBlocker:SetShown(shown) self.shown = shown end
local queueText = { points = {} }
function queueText:ClearAllPoints() self.points = {} end
function queueText:SetPoint(...) self.points[#self.points + 1] = { ... } end
function queueText:SetAllPoints(target) self.allPointsTarget = target end
function queueText:SetJustifyH(justify) self.justify = justify end
function queueText:SetShown(shown) self.shown = shown end
local compactRating = {}
function compactRating:SetShown(shown) self.shown = shown end
local compactDelta = {}
function compactDelta:SetShown(shown) self.shown = shown end
local warningCard = {
    minimizedLayout = false,
    noShowWarningButton = warningButton,
    actionButton = actionButton,
    actionBlocker = actionBlocker,
    queueText = queueText,
    compactRating = compactRating,
    compactDelta = compactDelta,
}
local queuedState = {
    queue = {},
    buttonVisible = false,
    buttonEnabled = false,
}
noShow.UpdateQueueWarningDisplay(warningCard, queuedState, warning)
assert(warningButton.shown and warningButton.tooltipText == noShow.FormatWarningSentence(warning),
    "queued warning icon should expose the complete sentence as its tooltip")
assert(actionButton.shown == false and actionBlocker.shown,
    "warning icon should occupy the unavailable action-button area")
assert(queueText.points[2] and queueText.points[2][2] == warningButton,
    "normal expanded queue text should stop before the warning icon")
noShow.UpdateQueueWarningDisplay(warningCard, queuedState, nil)
assert(not warningButton.shown, "queued warning icon should hide when the reset window ends")
warningCard.minimizedLayout = true
queuedState.buttonVisible = true
queuedState.isRated = true
noShow.UpdateQueueWarningDisplay(warningCard, queuedState, warning)
assert(queueText.shown and compactRating.shown and compactDelta.shown,
    "minimized ready countdown and rating should remain visible beside the warning icon")

epoch = 100000 + 60 * 60 - 1
warning = noShow.GetWarning()
assert(warning and warning.remainingSeconds == 1,
    "warning should remain until the full hour has elapsed")

epoch = epoch + 1
assert(not noShow.GetWarning(), "warning should clear one hour after application")
assert(WarbandRatingsDB.settings.arenaQueueNoShowPenalty == nil,
    "expired tracker state should be discarded")

epoch = 200000
monotonic = 8000
activeAura = {
    duration = 20 * 60,
    expirationTime = monotonic + 20 * 60,
    icon = 1234,
}
noShow.ScanActivePenalty()
epoch = epoch + 20 * 60
monotonic = monotonic + 20 * 60
activeAura = nil
noShow.ScanActivePenalty()
warning = noShow.GetWarning()
assert(warning.nextPenaltySeconds == 20 * 60,
    "20-minute penalty should remain capped at 20 minutes")

epoch = 300180
monotonic = 1000
activeAura = {
    duration = 5 * 60,
    expirationTime = monotonic + 2 * 60,
    icon = 1234,
}
noShow.ScanActivePenalty()
assert(WarbandRatingsDB.settings.arenaQueueNoShowPenalty.appliedAt == 300000,
    "late aura scans should reconstruct the original application time")

print("arena queue No-Show tests passed")
