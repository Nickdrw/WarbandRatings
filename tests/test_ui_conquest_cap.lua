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
