-- luacheck: globals time GetCurrentArenaSeason GetBuildInfo WarbandRatingsDB

time = function() return 2000 end
local detectedSeasonID = 41
GetCurrentArenaSeason = function() return detectedSeasonID end
local interfaceVersion = 120007
GetBuildInfo = function()
    return "12.x", "build", "Aug 10 2026", interfaceVersion, "", ""
end

local soloColumn = { key = "soloShuffle", label = "Solo Shuffle", bracketIndex = 7 }
local soloBGColumn = { key = "soloBG", label = "Solo BG", bracketIndex = 9 }
local arenaColumn = { key = "arena2v2", label = "2v2", bracketIndex = 1 }
local ns = {
    Utils = {
        CharKey = function(name, realm)
            return name .. "-" .. realm
        end,
    },
    Database = {
        SPEC_COLUMNS = { soloColumn, soloBGColumn },
        GLOBAL_COLUMNS = { arenaColumn },
        RATING_COLUMNS = { soloColumn, soloBGColumn, arenaColumn },
        IsSpecColumn = function(column)
            return column == soloColumn or column == soloBGColumn
        end,
        IsPVPColumn = function(column)
            return column and column.bracketIndex ~= nil
        end,
        GetPVPColumnByBracketIndex = function(bracketIndex)
            if bracketIndex == 7 then return soloColumn end
            if bracketIndex == 9 then return soloBGColumn end
            if bracketIndex == 1 then return arenaColumn end
        end,
        IsValidSeasonKey = function(seasonKey)
            return type(seasonKey) == "string" and seasonKey ~= ""
        end,
        IsStorageReady = function()
            return WarbandRatingsDB
                and WarbandRatingsDB.schemaVersion == 2
                and not WarbandRatingsDB.storageMigrationError
        end,
        EnsureSeason = function(seasonKey)
            WarbandRatingsDB.seasons = WarbandRatingsDB.seasons or {}
            WarbandRatingsDB.seasons[seasonKey] = WarbandRatingsDB.seasons[seasonKey] or {
                seasonKey = seasonKey,
                characters = {},
            }
            local season = WarbandRatingsDB.seasons[seasonKey]
            local seasonNumber = tonumber(seasonKey:match("^pvp%-(%d+)$")) or 0
            season.seasonKey = seasonKey
            season.expansionKey = (seasonNumber == 41 or seasonNumber == 42) and "midnight" or "legacy"
            season.expansionName = season.expansionKey == "midnight" and "Midnight" or "Legacy"
            season.seasonNumber = seasonNumber == 41 and 1 or seasonNumber == 42 and 2 or seasonNumber
            return season
        end,
        GetSeasonCharacters = function(seasonKey)
            local season = WarbandRatingsDB.seasons and WarbandRatingsDB.seasons[seasonKey]
            return season and season.characters or {}
        end,
        Migrate = function() end,
    },
}

WarbandRatingsDB = {
    characters = {
        ["Tester-Realm"] = {
            name = "Tester",
            realm = "Realm",
            classFilename = "WARRIOR",
            level = 90,
            currentSpecID = 71,
            ratings = {
                arena2v2 = 1800,
                conquest = 900,
                mythicPlus = 2200,
                crest_myth = 12,
                honor = 14000,
                hk = 500,
                hk_world = 100,
            },
            pvpStats = { arena2v2 = { seasonPlayed = 20 } },
            lastMMR = { arena2v2 = 1850 },
            specRatings = { [71] = { soloShuffle = 1750 } },
            specPVPStats = { [71] = { soloShuffle = { seasonPlayed = 10 } } },
            specLastMMR = { [71] = { soloShuffle = 1780 } },
            itemCounts = { [253307] = 4 },
        },
    },
    history = {
        version = 2,
        currentSeasonKey = "pvp-41",
        seasons = {
            ["pvp-41"] = {
                archived = false,
                characters = {
                    ["Tester-Realm"] = {
                        global = {
                            arena2v2 = {
                                points = { { 1900, 1790, 1840, 0, 0, 1, true, 19, "postmatch", 71 } },
                                archived = false,
                            },
                        },
                        specs = {},
                    },
                },
            },
        },
    },
}

assert(loadfile("Season.lua"))("WarbandRatings", ns)
assert(loadfile("History.lua"))("WarbandRatings", ns)

local Season = ns.Season
local History = ns.History
assert(Season.GetContentSeasonKey() == "pvp-41", "12.0.7 should remain on the Season 1 content model")
local knownSeasonKeys = Season.GetKnownSeasonKeys()
assert(#knownSeasonKeys == 2 and knownSeasonKeys[1] == "pvp-41" and knownSeasonKeys[2] == "pvp-42",
    "the catalog should contain Midnight seasons only")
interfaceVersion = 120100
History.Init()

assert(Season.GetContentSeasonKey() == "pvp-42", "12.1 should use the Season 2 content model")
assert(Season.GetFeature("conquestEquipmentChest", "pvp-41"), "Season 1 chest definition was lost")
assert(not Season.GetFeature("conquestEquipmentChest", "pvp-42"), "Season 1 chest leaked into Season 2")
local chestDefinition = Season.GetFeatureDefinition("conquestEquipmentChest", "pvp-42")
assert(chestDefinition.expectedName == "Venomous Equipment Chest", "Season 2 chest prefix was not anticipated")
local detectedChest = Season.RememberFeature("conquestEquipmentChest", {
    itemID = 299999,
    name = "Venomous Equipment Chest",
    fallbackCost = 375,
    hasOpeningCast = true,
}, "pvp-42")
assert(detectedChest and detectedChest.itemID == 299999, "detected Season 2 chest was not activated")
assert(WarbandRatingsDB.seasonFeatures["pvp-42"].conquestEquipmentChest.name == "Venomous Equipment Chest",
    "detected Season 2 chest was not persisted with season ownership")

assert(WarbandRatingsDB.schemaVersion == 2, "season storage schema was not upgraded")
assert(WarbandRatingsDB.characters == nil, "legacy live-character storage was not removed")
assert(WarbandRatingsDB.history.seasons == nil, "history still duplicates season storage")
assert(WarbandRatingsDB.legacySchemaBackup.characters["Tester-Realm"].ratings.arena2v2 == 1800,
    "the one-release legacy backup was not retained")

local current = WarbandRatingsDB.seasons["pvp-42"].characters["Tester-Realm"]
assert(current.seasonKey == "pvp-42", "current character was not moved to the new season")
assert(current.ratings.arena2v2 == nil, "PvP rating leaked across seasons")
assert(current.ratings.conquest == nil, "Conquest leaked across seasons")
assert(current.ratings.mythicPlus == nil, "Mythic+ score leaked across seasons")
assert(current.ratings.crest_myth == nil, "old crests leaked across seasons")
assert(current.ratings.honor == 14000, "persistent Honor was not preserved")
assert(current.ratings.hk == 500, "lifetime HK was not preserved")
assert(next(current.specRatings) == nil, "per-spec ratings leaked across seasons")
assert(next(current.lastMMR) == nil, "MMR leaked across seasons")

local seasonOneCharacters = History.GetSeasonCharacters("pvp-41")
local seasonTwoCharacters = History.GetSeasonCharacters("pvp-42")
assert(seasonOneCharacters["Tester-Realm"].ratings.arena2v2 == 1800, "Season 1 data was not retained")
assert(seasonOneCharacters["Tester-Realm"].specRatings[71].soloShuffle == 1750, "Season 1 spec data was not retained")
assert(#seasonOneCharacters["Tester-Realm"].series.global.arena2v2.points == 1,
    "Season 1 graph points were not merged into the canonical character record")
assert(seasonTwoCharacters["Tester-Realm"].ratings.arena2v2 == nil, "Season 2 baseline is not clean")
assert(WarbandRatingsDB.seasons["pvp-41"].expansionKey == "midnight", "Season 1 expansion ownership is missing")
assert(WarbandRatingsDB.seasons["pvp-42"].seasonNumber == 2, "Season 2 metadata is missing")

local backup = WarbandRatingsDB.legacySchemaBackup
assert(History.Init(), "the schema migration is not idempotent")
assert(WarbandRatingsDB.legacySchemaBackup == backup, "a repeated initialization replaced the migration backup")
assert(WarbandRatingsDB.seasons["pvp-41"].characters["Tester-Realm"].ratings.arena2v2 == 1800,
    "a repeated initialization changed archived data")

assert(History.RecordMatch("pvp-42", "Tester", "Realm", 71, 1, 1500, 1550, 1, 2100, true, 1, "postmatch"))
assert(History.RecordMatch("pvp-42", "Tester", "Realm", 72, 1, 1510, 1560, 0, 2200, true, 2, "postmatch"))
assert(History.RecordMatch("pvp-42", "Tester", "Realm", 72, 7, 1600, 1650, 1, 2300, true, 3, "postmatch"))
assert(History.GetCurrentSeries("Tester-Realm", "arena2v2").points[2][10] == 72,
    "global brackets should retain the specialization active at each rating point")

current.currentSpecID = 72
current.pvpStats.arena2v2 = { seasonBest = 1950, seasonPlayed = 12, seasonWon = 7 }
current.specRatings[72] = { soloShuffle = 1725, soloBG = 1850 }
current.specPVPStats[72] = {
    soloShuffle = {
        seasonBest = 1800,
        seasonPlayed = 9,
        seasonWon = 5,
        roundsSeasonPlayed = 55,
        roundsSeasonWon = 31,
    },
    soloBG = {
        seasonBest = 1900,
        seasonPlayed = 14,
        seasonWon = 9,
        roundsSeasonPlayed = 0,
        roundsSeasonWon = 0,
    },
}
local stats = History.GetSeasonStatistics("pvp-42")
local byKey = {}
for _, bracket in ipairs(stats) do byKey[bracket.key] = bracket end
assert(byKey.arena2v2.total.games == 12, "global bracket did not use the authoritative season total")
assert(byKey.arena2v2.total.wins == 7 and byKey.arena2v2.total.losses == 5, "global outcomes are incorrect")
assert(byKey.arena2v2.maxRating == 1950, "global bracket season-best rating is incorrect")
assert(byKey.arena2v2.maxRatingSpecID == 72, "global bracket peak-holder specialization is missing")
assert(byKey.arena2v2.maxRatingClassFilename == "WARRIOR",
    "global bracket peak-holder class is missing")
assert(byKey.arena2v2.mostPlayedGames == 12
        and byKey.arena2v2.mostPlayedClassFilename == "WARRIOR",
    "global bracket most-played class total is incorrect")
assert(#byKey.arena2v2.specs == 0, "global bracket must remain spec-agnostic")
assert(#byKey.arena2v2.classes == 1 and byKey.arena2v2.classes[1] == "WARRIOR",
    "global bracket class participation is missing")
assert(byKey.soloShuffle.unit == "rounds", "Solo Shuffle must be expressed in rounds")
assert(byKey.soloShuffle.total.games == 55, "Solo Shuffle did not use roundsSeasonPlayed")
assert(byKey.soloShuffle.total.wins == 31 and byKey.soloShuffle.total.losses == 24,
    "Solo Shuffle round outcomes are incorrect")
assert(byKey.soloShuffle.specs[1].specID == 72, "per-spec bracket ownership is incorrect")
assert(byKey.soloShuffle.specs[1].classFilename == "WARRIOR", "solo class ownership is missing")
assert(byKey.soloShuffle.specs[1].maxRating == 1800, "Solo Shuffle season-best rating is incorrect")
assert(byKey.soloShuffle.maxRating == 1800, "Solo Shuffle bracket peak rating is incorrect")
assert(byKey.soloBG.unit == "games", "Solo BG must be expressed in games")
assert(byKey.soloBG.total.games == 14 and byKey.soloBG.total.wins == 9 and byKey.soloBG.total.losses == 5,
    "Solo BG did not use its per-spec season game counters")
assert(byKey.soloBG.specs[1].maxRating == 1900, "Solo BG season-best rating is incorrect")

assert(History.RecordMatch("pvp-42", "Tester", "Realm", 73, 7, 0, 2385, -1, 2400, true, 1, "postmatch"))
current.specRatings[73] = { soloShuffle = 0 }
current.specPVPStats[73] = {
    soloShuffle = {
        ownerCharacterKey = "Tester-Realm",
        ownerSpecID = 73,
        seasonBest = 0,
        seasonPlayed = 0,
        seasonWon = 0,
        roundsSeasonPlayed = 0,
        roundsSeasonWon = 0,
    },
}
stats = History.GetSeasonStatistics("pvp-42")
byKey = {}
for _, bracket in ipairs(stats) do byKey[bracket.key] = bracket end
local zeroTotalSpec
for _, spec in ipairs(byKey.soloShuffle.specs) do
    if spec.specID == 73 then zeroTotalSpec = spec end
end
assert(not zeroTotalSpec, "trusted zero round totals fell back to a recorded lobby")
assert(byKey.soloShuffle.total.games == 55 and not byKey.soloShuffle.partial,
    "trusted zero round totals changed the authoritative Shuffle summary")

assert(History.RecordMatch("pvp-42", "Tester", "Realm", 71, 7, 1700, 1750, -1, 2500, true, 1, "postmatch"))
stats = History.GetSeasonStatistics("pvp-42")
byKey = {}
for _, bracket in ipairs(stats) do byKey[bracket.key] = bracket end
local fallbackSpec
for _, spec in ipairs(byKey.soloShuffle.specs) do
    if spec.specID == 71 then fallbackSpec = spec end
end
assert(fallbackSpec and fallbackSpec.recordedGames == 1 and fallbackSpec.seasonTotalsUnavailable,
    "recorded-lobby fallback was lost when authoritative totals are unavailable")
assert(byKey.soloShuffle.partial, "recorded-lobby fallback did not mark the Shuffle summary partial")

local available = History.GetAvailableSeasonKeys()
assert(#available == 2 and available[1] == "pvp-42" and available[2] == "pvp-41", "season selector inventory is incorrect")

detectedSeasonID = 43
History.EnsureCurrentSeason()
History.EnsureContentSeason()
assert(#WarbandRatingsDB.seasons["pvp-41"].characters["Tester-Realm"].series.global.arena2v2.points == 1,
    "a later season transition pruned older raw graph points")
assert(History.HandleSavedVariablesTooLarge() == "pvp-41",
    "the emergency size handler did not trim the oldest archived season first")
assert(WarbandRatingsDB.seasons["pvp-41"].characters["Tester-Realm"].series.global.arena2v2.points == nil,
    "the emergency size handler retained the selected raw graph points")
assert(#WarbandRatingsDB.seasons["pvp-42"].characters["Tester-Realm"].series.global.arena2v2.points == 2,
    "the emergency size handler trimmed more than one archived season")

detectedSeasonID = 41
WarbandRatingsDB = {}
assert(History.Init(), "fresh season storage initialization failed")
available = History.GetAvailableSeasonKeys()
assert(#available == 1 and available[1] == "pvp-42",
    "a fresh 12.1 install exposed an empty previous-season table")
assert(WarbandRatingsDB.legacySchemaBackup == nil,
    "a fresh install created an unnecessary legacy backup")

local malformedCharacters = { ["Broken-Realm"] = { name = "Broken", realm = "Realm" } }
local malformedHistory = {
    seasons = {
        ["pvp-41"] = { characters = { ["Broken-Realm"] = "not-a-table" } },
    },
}
WarbandRatingsDB = {
    characters = malformedCharacters,
    history = malformedHistory,
}
local initialized = History.Init()
assert(not initialized, "an invalid legacy database passed migration validation")
assert(WarbandRatingsDB.characters == malformedCharacters and WarbandRatingsDB.history == malformedHistory,
    "a failed migration changed the legacy character/history tables")
assert(WarbandRatingsDB.schemaVersion == nil and WarbandRatingsDB.legacySchemaBackup == nil,
    "a failed migration crossed the atomic commit boundary")
assert(not History.RecordMatch(
    "pvp-42", "Broken", "Realm", 71, 1, 1200, 1250, 1, 3000, true, 1, "postmatch"
), "history recording remained enabled after a failed migration")

print("season transition tests passed")
