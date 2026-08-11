-- luacheck: globals time GetCurrentArenaSeason GetBuildInfo

local now = 1000
time = function() return now end
GetCurrentArenaSeason = function() return 41 end
GetBuildInfo = function() return "12.0.7", "", "", 120007 end

local specColumn = { key = "soloShuffle", bracketIndex = 7 }
local specBGColumn = { key = "soloBG", bracketIndex = 9 }
local globalColumn = { key = "arena2v2", bracketIndex = 1 }
local global3v3Column = { key = "arena3v3", bracketIndex = 2 }
local ns = {
    Utils = {
        CharKey = function(name, realm)
            return name .. "-" .. realm
        end,
    },
    Database = {
        SPEC_COLUMNS = { specColumn, specBGColumn },
        GLOBAL_COLUMNS = { globalColumn, global3v3Column },
        RATING_COLUMNS = { specColumn, specBGColumn, globalColumn, global3v3Column },
        IsSpecColumn = function(col)
            return col == specColumn or col == specBGColumn
        end,
        GetPVPColumnByBracketIndex = function(bracketIndex)
            if bracketIndex == 7 then return specColumn end
            if bracketIndex == 9 then return specBGColumn end
            if bracketIndex == 1 then return globalColumn end
            if bracketIndex == 2 then return global3v3Column end
        end,
        IsPVPColumn = function(col)
            return col and col.bracketIndex ~= nil
        end,
        IsValidSeasonKey = function(seasonKey)
            return type(seasonKey) == "string" and seasonKey ~= ""
        end,
        EnsureSeason = function(seasonKey)
            WarbandRatingsDB.seasons = WarbandRatingsDB.seasons or {}
            WarbandRatingsDB.seasons[seasonKey] = WarbandRatingsDB.seasons[seasonKey] or {
                seasonKey = seasonKey,
                characters = {},
            }
            return WarbandRatingsDB.seasons[seasonKey]
        end,
        GetSeasonCharacters = function(seasonKey)
            local season = WarbandRatingsDB.seasons and WarbandRatingsDB.seasons[seasonKey]
            return season and season.characters or {}
        end,
        Migrate = function() end,
    },
}

WarbandRatingsDB = {
    characters = {},
}

assert(loadfile("Season.lua"))("WarbandRatings", ns)
assert(loadfile("History.lua"))("WarbandRatings", ns)
local History = ns.History
History.Init()

assert(History.RecordMatch(
    "pvp-41",
    "Tester",
    "Realm",
    71,
    7,
    1500,
    nil,
    1,
    100,
    false,
    10,
    "pending"
))

local series = History.GetCurrentSeries("Tester-Realm", "soloShuffle", 71)
assert(#series.points == 1, "rating-only match was not recorded")
assert(series.points[1][2] == 1500, "rating was not stored")
assert(series.points[1][3] == 0, "missing MMR should use the zero sentinel")
assert(series.points[1][8] == 10, "match sequence was not stored")
assert(series.points[1][9] == "pending", "missing MMR was not marked pending")
assert(series.points[1][10] == 71, "the specialization active during the match was not stored")

assert(History.RecordMatch(
    "pvp-41",
    "Tester",
    "Realm",
    71,
    7,
    1500,
    nil,
    -1,
    105,
    false,
    10,
    "pending"
))
assert(#series.points == 1, "same match sequence created a duplicate")
assert(series.points[1][6] == 1, "unknown retry replaced a known result")

assert(History.EnrichPendingMMR("pvp-41", "Tester", "Realm", 71, 7, 1540, 10))
assert(series.points[1][3] == 1540, "next-lobby MMR did not enrich the pending point")
assert(series.points[1][7] == true, "enriched MMR was not aligned to the completed match")
assert(series.points[1][9] == "nextPrematch", "MMR provenance was not stored")

assert(History.RecordMatch(
    "pvp-41",
    "Tester",
    "Realm",
    71,
    7,
    1510,
    nil,
    -1,
    110,
    false,
    11,
    "pending"
))
assert(#series.points == 2, "a distinct match sequence was incorrectly deduplicated")
assert(series.points[2][4] == 10, "rating delta was not recalculated")

assert(History.RecordMatch(
    "pvp-41",
    "Tester",
    "Realm",
    71,
    7,
    1500,
    nil,
    -1,
    115,
    false,
    10,
    "pending"
))
assert(series.points[1][3] == 1540, "a retry without MMR erased an enriched value")
assert(series.points[1][9] == "nextPrematch", "a retry erased MMR provenance")
assert(series.points[1][10] == 71, "a retry erased the match specialization")

local seasonKey = History.GetContentSeasonKey()
local function SaveSeasonCharacter(charKey, character)
    character.seasonKey = seasonKey
    character.series = character.series or { global = {}, specs = {} }
    WarbandRatingsDB.seasons[seasonKey].characters[charKey] = character
end

SaveSeasonCharacter("PeakMonk-Realm", {
    name = "PeakMonk",
    realm = "Realm",
    classFilename = "MONK",
    currentSpecID = 268,
    ratings = {
        arena2v2 = 3000,
        arena3v3 = 1967,
    },
    pvpStats = {
        arena2v2 = { seasonPlayed = 11, seasonWon = 8, seasonBest = 3000 },
        arena3v3 = { seasonPlayed = 474, seasonWon = 241, seasonBest = 2414 },
    },
    specRatings = {
        [268] = { soloShuffle = 2000, soloBG = 3000 },
    },
    specPVPStats = {
        [268] = {
            soloShuffle = { roundsSeasonPlayed = 11, roundsSeasonWon = 6, seasonBest = 2000 },
            soloBG = { seasonPlayed = 11, seasonWon = 7, seasonBest = 3000 },
        },
    },
})
SaveSeasonCharacter("PeakShaman-Realm", {
    name = "PeakShaman",
    realm = "Realm",
    classFilename = "SHAMAN",
    currentSpecID = 262,
    ratings = {
        arena2v2 = 2100,
        arena3v3 = 2414,
    },
    pvpStats = {
        arena2v2 = { seasonPlayed = 11, seasonWon = 7, seasonBest = 2100 },
        arena3v3 = { seasonPlayed = 474, seasonWon = 241, seasonBest = 2414 },
    },
    specRatings = {
        [262] = { soloShuffle = 2200, soloBG = 2300 },
    },
    specPVPStats = {
        [262] = {
            soloShuffle = { roundsSeasonPlayed = 11, roundsSeasonWon = 7, seasonBest = 2200 },
            soloBG = { seasonPlayed = 11, seasonWon = 7, seasonBest = 2300 },
        },
    },
})
SaveSeasonCharacter("SecondShaman-Realm", {
    name = "SecondShaman",
    realm = "Realm",
    classFilename = "SHAMAN",
    currentSpecID = 262,
    ratings = {},
    pvpStats = {},
    specRatings = {
        [262] = { soloShuffle = 2400 },
    },
    specPVPStats = {
        [262] = {
            soloShuffle = { roundsSeasonPlayed = 11, roundsSeasonWon = 7, seasonBest = 2400 },
        },
    },
})
SaveSeasonCharacter("Threshold-Realm", {
    name = "Threshold",
    realm = "Realm",
    classFilename = "WARRIOR",
    ratings = {
        arena2v2 = 3000,
        arena3v3 = 1000,
    },
    pvpStats = {
        arena2v2 = { seasonPlayed = 10, seasonWon = 10, seasonBest = 3000 },
        arena3v3 = { seasonPlayed = 100, seasonWon = 50, seasonBest = 1000 },
    },
    specRatings = {},
    specPVPStats = {},
})

History.AuditPVPStatOwnership()

local snapshots = History.GetSeasonCharacters(seasonKey)
assert(snapshots["PeakMonk-Realm"].pvpStats.arena3v3.seasonTotalsUntrusted,
    "copied legacy 3v3 totals were not quarantined")
assert(not snapshots["PeakShaman-Realm"].pvpStats.arena3v3.seasonTotalsUntrusted,
    "the unambiguous owner of legacy 3v3 totals was quarantined")

local arena3v3
for _, bracket in ipairs(History.GetSeasonStatistics(seasonKey)) do
    if bracket.key == "arena3v3" then arena3v3 = bracket end
end
assert(arena3v3 and arena3v3.maxRating == 2414,
    "3v3 season-best aggregation returned the wrong rating")
assert(arena3v3.maxRatingClassFilename == "SHAMAN",
    "copied season totals assigned the 3v3 peak to the wrong class")
assert(arena3v3.total.games == 574 and arena3v3.total.wins == 291,
    "copied legacy 3v3 totals were counted twice")

local mvSpec = History.GetSeasonMVSpec(seasonKey)
assert(mvSpec and mvSpec.specID == 262 and mvSpec.classFilename == "SHAMAN",
    "MV Spec selected the wrong specialization")
assert(mvSpec.activeBracketCount == 3 and mvSpec.ratingTotal == 6900,
    "MV Spec should aggregate active solo brackets across characters of the same spec")
assert(mvSpec.averageRating == 2300,
    "MV Spec average does not match rating total divided by active brackets")

assert(ns.Season.IsRatedSeasonActive(), "active rated season was not detected")
SaveSeasonCharacter("Offseason-Realm", {
    name = "Offseason",
    realm = "Realm",
    classFilename = "PRIEST",
    currentSpecID = 258,
    ratings = { arena3v3 = 1964 },
    pvpStats = {
        arena3v3 = { seasonPlayed = 2, seasonWon = 1, seasonBest = 1816 },
    },
    specRatings = {
        [258] = { soloShuffle = 1900, soloBG = 1750 },
    },
    specPVPStats = {
        [258] = {
            soloShuffle = { seasonPlayed = 2, seasonBest = 1800 },
            soloBG = { seasonPlayed = 2, seasonBest = 1700 },
        },
    },
    series = {
        global = {
            arena3v3 = {
                points = {
                    { 900, 1800 },
                    { 950, 1816 },
                },
            },
        },
        specs = {
            [258] = {
                soloShuffle = { points = { { 900, 1790 }, { 950, 1800 } } },
                soloBG = { points = { { 900, 1690 }, { 950, 1700 } } },
            },
        },
    },
})
GetCurrentArenaSeason = function() return 0 end
assert(not ns.Season.IsRatedSeasonActive(), "offseason was not detected")
local displaySnapshots = History.GetSeasonDisplayCharacters(seasonKey)
assert(displaySnapshots["Offseason-Realm"].ratings.arena3v3 == 1816,
    "offseason table did not use the last completed match rating")
assert(displaySnapshots["Offseason-Realm"].specRatings[258].soloShuffle == 1800
        and displaySnapshots["Offseason-Realm"].specRatings[258].soloBG == 1700,
    "offseason table did not preserve repaired ratings across spec brackets")
assert(History.GetSeasonCharacters(seasonKey)["Offseason-Realm"].ratings.arena3v3 == 1964,
    "display repair mutated the saved snapshot")

print("history tests passed")
