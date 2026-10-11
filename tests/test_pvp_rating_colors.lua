-- luacheck: globals RAID_CLASS_COLORS GameTooltip GetSpecializationInfoByID date
-- luacheck: globals WarbandRatingsDB

date = os.date
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
GetSpecializationInfoByID = function() end

local ns = { Database = {}, DataCollection = {}, History = {} }
assert(loadfile("Utils.lua"))("WarbandRatings", ns)
assert(loadfile("Season.lua"))("WarbandRatings", ns)
assert(loadfile("UI.lua"))("WarbandRatings", ns)
local UI = ns.UI
local selectedSeason = "pvp-42"
ns.SeasonUI = { GetSelectedSeasonKey = function() return selectedSeason end }
ns.Database.IsPVPColumn = function(col) return col.bracketIndex ~= nil end
ns.Database.IsSpecColumn = function(col) return col.key == "soloShuffle" end

local function AssertColor(actual, expected, message)
    assert(actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3], message)
end

local unranked = { 145 / 255, 108 / 255, 92 / 255 }
local combatant = { 176 / 255, 179 / 255, 181 / 255 }
local challenger = { 188 / 255, 148 / 255, 78 / 255 }
local rival = { 158 / 255, 168 / 255, 191 / 255 }
local duelist = { 69 / 255, 118 / 255, 164 / 255 }
local elite = { 142 / 255, 69 / 255, 173 / 255 }

for _, themeName in ipairs({ "obsidian", "stormglass", "verdant", "ember" }) do
    WarbandRatingsDB = { settings = { themeKey = themeName } }
    local theme = UI.GetActiveTheme()
    assert(UI.PVPTooltip.GetRatingColor(nil, theme) == theme.muted, "missing ratings should stay muted")
    assert(UI.PVPTooltip.GetRatingColor(0, theme) == theme.muted, "zero ratings should stay muted")
    AssertColor(UI.PVPTooltip.GetRatingColor(999, theme), unranked, "unranked ratings should use the bronze badge color")
    for _, sample in ipairs({
        { 1000, combatant }, { 1199, combatant }, { 1200, combatant }, { 1399, combatant },
        { 1400, challenger }, { 1599, challenger }, { 1600, challenger }, { 1799, challenger },
        { 1800, rival }, { 1949, rival }, { 1950, rival }, { 2099, rival },
        { 2100, duelist }, { 2299, duelist }, { 2300, elite }, { 3000, elite },
    }) do
        AssertColor(UI.PVPTooltip.GetRatingColor(sample[1], theme), sample[2], "incorrect rank boundary color")
    end
end

selectedSeason = "pvp-40"
AssertColor(UI.PVPTooltip.GetRatingColor(2399), duelist, "older seasons should retain the 2400 Elite threshold")
AssertColor(UI.PVPTooltip.GetRatingColor(2400), elite, "older seasons should color 2400 as Elite")
assert(UI.PVPTooltip.FormatRating(2399) == "|T2023051:14:14:0:0|t 2,399",
    "older seasons should show the Duelist badge below 2400")
assert(UI.PVPTooltip.FormatRating(2400) == "|T2023053:14:14:0:0|t 2,400",
    "older seasons should show the Elite badge at 2400")
selectedSeason = "pvp-41"
AssertColor(UI.PVPTooltip.GetRatingColor("2311"), elite, "Midnight Season 1 should use the 2300 Elite threshold")

for _, sample in ipairs({
    { 1, 2023043 }, { 999, 2023043 },
    { 1000, 2023045 }, { 1200, 2023045 }, { 1399, 2023045 },
    { 1400, 2023047 }, { 1600, 2023047 }, { 1799, 2023047 },
    { 1800, 2023049 }, { 1950, 2023049 }, { 2099, 2023049 },
    { 2100, 2023051 }, { 2299, 2023051 }, { 2300, 2023053 },
}) do
    local texture = UI.PVPTooltip.FormatRating(sample[1]):match("^|T(%d+):14:14:0:0|t ")
    assert(tonumber(texture) == sample[2], "rating should be preceded by the matching Blizzard badge")
end
assert(UI.PVPTooltip.FormatRating(nil) == "0" and UI.PVPTooltip.FormatRating(0) == "0",
    "missing and zero ratings should retain number formatting without a badge")

local lines = {}
GameTooltip = {
    SetOwner = function() end,
    ClearLines = function() lines = {} end,
    AddLine = function() end,
    AddDoubleLine = function(_, left, right, _, _, _, r, g, b)
        lines[#lines + 1] = { label = left, text = right, color = { r, g, b } }
    end,
    Show = function() end,
}
-- The tooltip backdrop is independent of rating text colors.
UI.PVPTooltip.ApplyStyle = function() end

local function FindLine(label, occurrence)
    occurrence = occurrence or 1
    for _, line in ipairs(lines) do
        if line.label == label then
            occurrence = occurrence - 1
            if occurrence == 0 then return line end
        end
    end
    error("Missing tooltip line: " .. label)
end

local stats = { rating = 1600, weeklyBest = 1800, seasonBest = 2311 }
local character = {
    name = "Tester", realm = "Realm", classFilename = "MAGE",
    specRatings = { [64] = { soloShuffle = 2100 } },
    specLastMMR = { [64] = { soloShuffle = 2329 } },
    specPVPStats = { [64] = { soloShuffle = stats } },
}
local col = { key = "soloShuffle", bracketIndex = 7 }
assert(UI.PVPTooltip.Show({}, character, 64, col))
AssertColor(FindLine("Current Rating:").color, duelist, "current rating should use the displayed value's rank")
assert(FindLine("Current Rating:").text == "|T2023051:14:14:0:0|t 2,100",
    "current rating should show its badge before the formatted number")
AssertColor(FindLine("Best Rating:", 1).color, rival, "weekly best should use its own rank")
AssertColor(FindLine("Best Rating:", 2).color, elite, "season best should use its own rank")
assert(FindLine("Best Rating:", 1).text == "|T2023049:14:14:0:0|t 1,800",
    "weekly best should show its own rank badge")
assert(FindLine("Best Rating:", 2).text == "|T2023053:14:14:0:0|t 2,311",
    "season best should show its own rank badge")
AssertColor(FindLine("Current MMR:").color, UI.GetActiveTheme().mmr, "MMR must retain its theme color")
assert(FindLine("Current MMR:").text == "2,329", "MMR should remain a number without a rank badge")

stats.preseasonRatingIsSeasonBest = true
stats.weeklyBest = 0
UI.PVPTooltip.Show({}, character, 64, col)
AssertColor(FindLine("Season Best:").color, duelist, "preseason season-best ratings should also use rank colors")
assert(FindLine("Season Best:").text == "|T2023051:14:14:0:0|t 2,100",
    "preseason season-best ratings should also show a badge")
AssertColor(FindLine("Best Rating:", 1).color, UI.GetActiveTheme().muted, "zero best ratings should stay muted")
assert(FindLine("Best Rating:", 1).text == "0", "zero best ratings should not show a badge")

print("PvP rating color tests passed")
