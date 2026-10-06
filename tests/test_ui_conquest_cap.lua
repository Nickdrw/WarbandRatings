-- luacheck: globals C_CurrencyInfo date

date = os.date

local ns = {
    Database = {},
    DataCollection = {},
    History = {},
    Utils = {},
}

function ns.Utils.IsEmptyRating(value)
    return not value or value == 0
end

function ns.Utils.FormatRating(value)
    return ns.Utils.IsEmptyRating(value) and "-" or tostring(value)
end

assert(loadfile("UI.lua"))("WarbandRatings", ns)

local function SnapshotTime(month, day)
    return os.time({ year = 2026, month = month, day = day, hour = 12 })
end

local version, inferred = ns.UI.PVPTooltip.GetMatchVersion(SnapshotTime(8, 27))
assert(version == "12.1.0" and inferred,
    "an older August 2026 match should show an inferred 12.1.0 version")
version, inferred = ns.UI.PVPTooltip.GetMatchVersion(SnapshotTime(7, 10))
assert(version == "12.0.7" and inferred, "a July match should use the Revelations patch")
version, inferred = ns.UI.PVPTooltip.GetMatchVersion(SnapshotTime(5, 10))
assert(version == "12.0.5" and inferred, "a May match should use the 12.0.5 patch")
version, inferred = ns.UI.PVPTooltip.GetMatchVersion(SnapshotTime(8, 27), "12.1.1")
assert(version == "12.1.1" and not inferred,
    "a version stored with the match should take priority over the date estimate")
version = ns.UI.PVPTooltip.GetMatchVersion(SnapshotTime(8, 11))
assert(version == nil, "the patch release day should not be guessed across regional maintenance")
version = ns.UI.PVPTooltip.GetMatchVersion(SnapshotTime(8, 12))
assert(version == nil, "the following regional release day should not be guessed")
version = ns.UI.PVPTooltip.GetMatchVersion(SnapshotTime(9, 28))
assert(version == nil, "future matches should not use an outdated patch estimate")

local matchTime = SnapshotTime(8, 25)
local matchSeries = { points = { { matchTime, 1602, 0, 0, 0, 1, false, 7, "pending", 264, "12.1.0", "69214" } } }
local recordedAt, recordedVersion, recordedBuild = ns.UI.PVPTooltip.GetRatingRecord(matchSeries, 1602)
assert(recordedAt == matchTime and recordedVersion == "12.1.0" and recordedBuild == "69214",
    "the matching graph point should supply the rating date and recorded client version")
recordedAt = ns.UI.PVPTooltip.GetRatingRecord(matchSeries, 1700)
assert(recordedAt == nil, "a graph point with a different rating must not date the displayed rating")
recordedAt = ns.UI.PVPTooltip.GetRatingRecord({
    points = {},
    summary = { finalRating = 1602, sourceLastTime = matchTime },
}, 1602)
assert(recordedAt == matchTime, "a trimmed graph should retain the final rating date from its summary")
ns.Database.IsSpecColumn = function(col) return col.spec == true end
assert(ns.UI.PVPTooltip.GetRating(
    { ratings = { arena2v2 = 1602 } }, 0, { key = "arena2v2" }, { rating = 1700 }
) == 1602, "the rating tooltip should use the value displayed in the table")

local samplePoints = {
    { SnapshotTime(3, 20), 1300 },
    { SnapshotTime(3, 21), 1450 },
    { SnapshotTime(3, 28), 1650 },
    { SnapshotTime(4, 4), 1750 },
}
local visiblePoints = ns.UI.GraphComparison.GetVisiblePoints(samplePoints, 2, 4, 50, 100)
assert(#visiblePoints == 3 and visiblePoints[1].point == samplePoints[2]
    and visiblePoints[1].x == 44 and visiblePoints[3].x == 144,
    "the ordinary graph should retain its visible game-index positions")
local shortened = ns.UI.GraphComparison.GetVisiblePoints(samplePoints, 3, 6, 25, 100)
assert(#shortened == 2 and shortened[2].point == samplePoints[4] and shortened[2].x == 69,
    "the ordinary graph should only use recorded games")
local single = ns.UI.GraphComparison.GetVisiblePoints(samplePoints, 2, 2, 0, 100)
assert(#single == 1 and single[1].x == 94, "a single visible game should be centered")

ns.History.GetSeasonCharacters = function()
    return {
        ["Rabidfire-Archimonde"] = {
            pvpStats = { arena3v3 = { seasonPlayed = 157 } },
            specPVPStats = { [254] = { soloShuffle = { seasonPlayed = 25 } } },
        },
    }
end
local recorded, played = ns.UI.GraphComparison.GetRecordedCoverage(
    "pvp-41", "Rabidfire-Archimonde", "arena3v3", 0, samplePoints
)
assert(recorded == 4 and played == 157, "the graph should identify partial global match history")
recorded, played = ns.UI.GraphComparison.GetRecordedCoverage(
    "pvp-41", "Rabidfire-Archimonde", "soloShuffle", 254, samplePoints
)
assert(recorded == 4 and played == 25, "the graph should identify partial spec match history")
assert(ns.UI.GraphComparison.GetRecordedCoverage(
    "pvp-41", "Rabidfire-Archimonde", "arena3v3", 0, {}
) == nil, "an empty curve should not claim coverage")

local currentStart = SnapshotTime(8, 19)
local oldStart = SnapshotTime(3, 18)
local currentByDay = {
    { SnapshotTime(8, 19), 1000 },
    { SnapshotTime(8, 21), 1200 },
    { SnapshotTime(8, 21) + 3600, 1250 },
    { SnapshotTime(8, 24), 1500 },
}
local oldByDay = {
    { SnapshotTime(3, 22), 1400 },
    { SnapshotTime(3, 25), 1700 },
    { SnapshotTime(3, 28), 1800 },
}
local currentDaily = ns.UI.GraphComparison.GetDailyPoints(currentByDay, currentStart, 6, 120)
local previousDaily = ns.UI.GraphComparison.GetDailyPoints(oldByDay, oldStart, 6, 120)
assert(#currentDaily == 3 and currentDaily[1].day == 0 and currentDaily[1].x == 44
    and currentDaily[2].point == currentByDay[3]
    and currentDaily[2].day == 2 and currentDaily[2].x == 84,
    "the day graph should use the last match of each calendar day and real day spacing")
assert(#previousDaily == 1 and previousDaily[1].day == 4 and previousDaily[1].x == 124,
    "both seasons should share the same elapsed-day axis")
assert(currentDaily[#currentDaily].endX == 164 and currentDaily[#currentDaily].day == 5
    and currentDaily[#currentDaily].point == currentByDay[4],
    "the current rating should continue through the final displayed day without changing its recorded date")
assert(previousDaily[#previousDaily].endX == 164 and previousDaily[#previousDaily].point == oldByDay[1],
    "the previous rating should continue through the same day without using later-season matches")
assert(#ns.UI.GraphComparison.GetDailyPoints(oldByDay, oldStart, 3, 120) == 0,
    "a late previous-season match should not appear before the current season reaches that day")
assert(ns.UI.GraphComparison.GetSeasonDay(SnapshotTime(3, 22), oldStart) == 4,
    "day offsets should follow calendar days")
assert(ns.UI.GraphComparison.GetSeasonDay(SnapshotTime(8, 18), currentStart) == -1,
    "a match before the season start must not be included")

do
    local comparison = ns.UI.GraphComparison
    for _, endpoints in ipairs({ { 1000, 1500 }, { 1500, 1000 }, { 1000, 1000 } }) do
        local first, last = endpoints[1], endpoints[2]
        assert(comparison.GetSmoothValue(first, last, 0) == first
            and comparison.GetSmoothValue(first, last, 1) == last,
            "smoothing should preserve both recorded endpoints")
        local previous = first
        for step = 1, 100 do
            local value = comparison.GetSmoothValue(first, last, step / 100)
            assert(value >= math.min(first, last) and value <= math.max(first, last),
                "smoothing must not invent peaks or dips")
            assert((last >= first and value >= previous) or (last < first and value <= previous),
                "each smooth transition should remain monotonic")
            previous = value
        end
    end
    assert(comparison.GetSmoothDayValue(currentDaily, 1) == 1125,
        "the hover marker should follow the smoothed curve between recorded days")
    assert(comparison.GetSmoothDayValue(currentDaily, 2) == 1250,
        "a recorded day should retain its exact final rating")
    assert(comparison.GetSmoothDayValue(currentDaily, 6) == 1500,
        "the final rating should stay flat after the last recorded day")
    assert(comparison.GetSmoothDayValue(previousDaily, 3) == 0
        and comparison.GetSmoothDayValue(previousDaily, 4) == 1400,
        "smoothing must not move a late first rating into earlier days")
    assert(comparison.GetSmoothDayValue({}, 3) == nil,
        "empty season data should not produce a smooth curve")
    local mmrValues = { [1] = 1600, [3] = 1800, [4] = 1700 }
    assert(comparison.GetSmoothDayValue(currentDaily, 1, mmrValues) == 1700,
        "MMR markers should use the same interpolation as rating markers")
    mmrValues[3] = nil
    assert(comparison.GetSmoothDayValue(currentDaily, 1, mmrValues) == nil,
        "smoothing should preserve gaps in unavailable MMR")
    assert(comparison.GetSmoothDayValue(previousDaily, 3, { [1] = 1550 }) == 1550,
        "the early MMR marker should follow the faint starting guide")
    assert(currentDaily[2].point == currentByDay[3] and currentDaily[2].day == 2,
        "visual smoothing must not modify saved ratings or their dates")
end

do
    local accents = {
        { 0.96, 0.72, 0.32 }, { 0.38, 0.82, 0.93 },
        { 0.62, 0.9, 0.54 }, { 0.96, 0.52, 0.33 },
    }
    local classColors = {
        { 1, 0.96, 0.41 }, -- Rogue: close to the default comparison gold.
        { 0.25, 0.78, 0.92 }, -- Mage: close to the blue theme accent.
        { 0.67, 0.83, 0.45 }, -- Hunter: close to the green theme accent.
        { 1, 1, 1 },
    }
    for _, accent in ipairs(accents) do
        for _, current in ipairs(classColors) do
            local previous = ns.UI.GraphComparison.GetPreviousColor(current[1], current[2], current[3], accent)
            local separation = (current[1] - previous[1]) ^ 2
                + (current[2] - previous[2]) ^ 2 + (current[3] - previous[3]) ^ 2
            assert(separation >= 0.15,
                "current and previous season colors should remain distinct across classes and themes")
        end
    end
    assert(ns.UI.GraphComparison.GetPreviousColor(1, 1, 1, accents[1]) == accents[1],
        "a distinct theme accent should remain the comparison color")
    local roguePrevious = ns.UI.GraphComparison.GetPreviousColor(1, 0.96, 0.41, accents[1])
    assert(roguePrevious ~= accents[1] and accents[1][1] == 0.96 and accents[1][2] == 0.72,
        "fixing a rogue color collision must not mutate the theme accent")
end

local hoverScale = {
    minValue = 0, maxValue = 2000, plotHeight = 100,
    showRating = true, showMMR = true, comparePrevious = true,
    ratingColor = { 1, 1, 1 }, mmrColor = { 0.5, 0.5, 0.5 }, previousColor = { 1, 0.8, 0 },
}
local markerY, markerColor = ns.UI.GraphComparison.GetHoverMarker(hoverScale, 75, 1000, 1600, 1200)
assert(markerY == 74 and markerColor == hoverScale.previousColor,
    "hover should mark only the nearest curve, including the previous season")
markerY, markerColor = ns.UI.GraphComparison.GetHoverMarker(hoverScale, 54, 1000, 1600, 1200)
assert(markerY == 54 and markerColor == hoverScale.mmrColor,
    "moving vertically at the same day should select the closer MMR curve")
hoverScale.showMMR = false
markerY, markerColor = ns.UI.GraphComparison.GetHoverMarker(hoverScale, 54, 1000, 1600, 1200)
assert(markerY == 74 and markerColor == hoverScale.previousColor,
    "hidden MMR should remain in the tooltip without receiving a hover marker")
assert(ns.UI.GraphComparison.GetHoverMarker(hoverScale, 54, nil, nil, nil) == nil,
    "missing values should not create a hover marker")

local conquestColumn = { key = "conquest" }
local cappedRatings = {
    conquest_totalEarned = 1600,
    conquest_maxQuantity = 1600,
}
local cappedText = ns.UI.FormatGlobalColumnValue(conquestColumn, cappedRatings, 725)
assert(cappedText:find("ReadyCheck%-Ready", 1) and cappedText:sub(-3) == "725",
    "capped Conquest should show a checkmark before the wallet value")

local spentCappedText = ns.UI.FormatGlobalColumnValue(conquestColumn, cappedRatings, 0)
assert(spentCappedText:find("ReadyCheck%-Ready", 1),
    "spending Conquest should not remove the earned-cap marker")

C_CurrencyInfo = {
    GetCurrencyInfo = function()
        return { maxQuantity = 0 }
    end,
}
local removedCapText = ns.UI.FormatGlobalColumnValue(conquestColumn, cappedRatings, 725)
assert(removedCapText == "725",
    "removing the live Conquest cap should clear stale markers from saved characters")
C_CurrencyInfo = nil

local uncappedText = ns.UI.FormatGlobalColumnValue(conquestColumn, {
    conquest_totalEarned = 1599,
    conquest_maxQuantity = 1600,
}, 725)
assert(uncappedText == "725", "uncapped Conquest should keep the normal table value")

local unknownCapText = ns.UI.FormatGlobalColumnValue(conquestColumn, {
    conquest_totalEarned = 1600,
    conquest_maxQuantity = 0,
}, 725)
assert(unknownCapText == "725", "missing cap data should not produce a false marker")

local otherColumnText = ns.UI.FormatGlobalColumnValue({ key = "honor" }, cappedRatings, 725)
assert(otherColumnText == "725", "the Conquest cap marker should not affect other currencies")

local hoverPanel = {}
local graphData = {}
assert(not ns.UI._ShouldReuseGraphHover(hoverPanel, graphData, 3, false),
    "the first graph hover was incorrectly treated as cached")
assert(ns.UI._ShouldReuseGraphHover(hoverPanel, graphData, 3, true),
    "an unchanged graph point did not reuse its tooltip")
assert(not ns.UI._ShouldReuseGraphHover(hoverPanel, graphData, 4, true),
    "moving to another graph point reused a stale tooltip")

print("UI Conquest-cap tests passed")
