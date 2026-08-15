-- luacheck: globals WarbandRatingsDB WarbandRatingsCharacterDB time

time = function() return 2200 end

local ns = {
    Utils = {
        CharKey = function(name, realm) return name .. "-" .. realm end,
        IsEmptyRating = function(value) return not value or value == 0 end,
        FormatNumber = function(value) return tostring(value) end,
    },
    Season = {
        GetCrests = function() return {} end,
        GetContentSeasonKey = function() return "pvp-42" end,
        GetSeasonInfo = function(seasonKey)
            return { key = seasonKey, expansionKey = "midnight", expansionName = "Midnight", number = 2 }
        end,
    },
}

WarbandRatingsDB = {
    schemaVersion = 2,
    settings = { hideArenaQueueHelper = true },
    seasons = {
        ["pvp-42"] = {
            seasonKey = "pvp-42",
            characters = {
                ["Tester-Realm"] = {
            name = "Tester",
            realm = "Realm",
            classFilename = "MONK",
            classID = 10,
            level = 90,
            currentSpecID = 270,
            seasonKey = "pvp-42",
            ratings = { arena2v2 = 1500 },
            pvpStats = {
                arena2v2 = {
                    rating = 1500,
                    seasonBest = 1600,
                    seasonPlayed = 30,
                    seasonWon = 18,
                    weeklyPlayed = 8,
                    weeklyWon = 5,
                },
            },
            specRatings = { [270] = { soloShuffle = 1700 } },
            specPVPStats = {
                [270] = {
                    soloShuffle = {
                        rating = 1700,
                        seasonBest = 1750,
                        seasonPlayed = 9,
                        seasonWon = 5,
                        roundsSeasonPlayed = 55,
                        roundsSeasonWon = 31,
                        roundsWeeklyPlayed = 12,
                        roundsWeeklyWon = 7,
                    },
                },
            },
            specLastMMR = {},
            lastMMR = {},
            itemCounts = {},
            series = { global = {}, specs = {} },
                },
            },
        },
    },
}
WarbandRatingsCharacterDB = nil

assert(loadfile("Database.lua"))("WarbandRatings", ns)
local Database = ns.Database
Database.Init()

assert(Database.GetCharacterSetting("hideArenaQueueHelper") == true,
    "the former account-wide queue-helper choice was not migrated to the character")
assert(WarbandRatingsDB.settings.hideArenaQueueHelper == nil,
    "the queue-helper choice should no longer remain in account-wide settings")
Database.SetCharacterSetting("hideArenaQueueHelper", false)
assert(Database.GetCharacterSetting("hideArenaQueueHelper") == false,
    "the character-specific queue-helper choice was not saved")
assert(WarbandRatingsDB.characterSettingsDefaults.hideArenaQueueHelper == true,
    "changing one character should not alter the migration default for other characters")

assert(WarbandRatingsDB.settings.hiddenColumns.mythicPlus
        and WarbandRatingsDB.settings.hiddenColumns.crests,
    "new table filters should hide PvE columns by default")
assert(WarbandRatingsDB.settings.honorAlertThreshold == 12000,
    "the default Honor alert threshold should be 12,000")
assert(WarbandRatingsDB.settings.hideHonorAlertIcon == false,
    "the bouncing Honor alert icon should be visible by default")
assert(Database.NormalizeHonorAlertThreshold("13500") == 13500,
    "a custom Honor alert threshold was not normalized")
assert(Database.NormalizeHonorAlertThreshold(0) == 12000,
    "an invalid Honor alert threshold should use the default")

Database.SaveCharacter("pvp-42", {
    name = "Tester",
    realm = "Realm",
    classFilename = "MONK",
    classID = 10,
    level = 90,
    currentSpecID = 270,
    ratings = { arena2v2 = 1510 },
    pvpStats = {
        arena2v2 = {
            rating = 1510,
            seasonBest = 0,
            seasonPlayed = 0,
            seasonWon = 0,
            weeklyPlayed = 2,
            weeklyWon = 1,
        },
    },
    itemCounts = {},
    lastMMR = {},
    specRatings = { [270] = { soloShuffle = 1710 } },
    specPVPStats = {
        [270] = {
            soloShuffle = {
                rating = 1710,
                seasonBest = 0,
                seasonPlayed = 0,
                seasonWon = 0,
                roundsSeasonPlayed = 0,
                roundsSeasonWon = 0,
                roundsWeeklyPlayed = 3,
                roundsWeeklyWon = 2,
            },
        },
    },
    specLastMMR = { [270] = {} },
    currentSpecRatings = { soloShuffle = 1710 },
    lastUpdated = 2000,
})

local saved = WarbandRatingsDB.seasons["pvp-42"].characters["Tester-Realm"]
local arena = saved.pvpStats.arena2v2
assert(arena.rating == 1510, "current global rating was not refreshed")
assert(arena.seasonBest == 1600, "season-best rating was erased by an unloaded response")
assert(arena.seasonPlayed == 30 and arena.seasonWon == 18,
    "global cumulative season counters were erased by an unloaded response")
assert(arena.weeklyPlayed == 2 and arena.weeklyWon == 1,
    "weekly global counters should follow the latest response")

local shuffle = saved.specPVPStats[270].soloShuffle
assert(shuffle.rating == 1710, "current spec rating was not refreshed")
assert(shuffle.roundsSeasonPlayed == 55 and shuffle.roundsSeasonWon == 31,
    "Solo Shuffle cumulative round counters were erased by an unloaded response")
assert(shuffle.roundsWeeklyPlayed == 3 and shuffle.roundsWeeklyWon == 2,
    "weekly Shuffle counters should follow the latest response")

Database.SaveCharacter("pvp-42", {
    name = "Tester",
    realm = "Realm",
    classFilename = "MONK",
    classID = 10,
    level = 90,
    currentSpecID = 270,
    ratings = { arena2v2 = 1510 },
    pvpStats = {
        arena2v2 = {
            rating = 1510,
            seasonBest = 1550,
            seasonPlayed = 15,
            seasonWon = 10,
            weeklyPlayed = 15,
            weeklyWon = 10,
            ownerCharacterKey = "Tester-Realm",
        },
    },
    itemCounts = {},
    lastMMR = {},
    specRatings = { [270] = { soloShuffle = 1710 } },
    specPVPStats = {
        [270] = {
            soloShuffle = {
                rating = 1710,
                seasonBest = 1720,
                seasonPlayed = 3,
                seasonWon = 2,
                roundsSeasonPlayed = 18,
                roundsSeasonWon = 11,
                roundsWeeklyPlayed = 18,
                roundsWeeklyWon = 11,
                ownerCharacterKey = "Tester-Realm",
                ownerSpecID = 270,
            },
        },
    },
    specLastMMR = { [270] = {} },
    currentSpecRatings = { soloShuffle = 1710 },
    lastUpdated = 2100,
})

arena = saved.pvpStats.arena2v2
assert(arena.seasonBest == 1550 and arena.seasonPlayed == 15,
    "verified global statistics did not replace unowned legacy totals")
assert(arena.ownerCharacterKey == "Tester-Realm",
    "verified global statistics lost their character owner")
shuffle = saved.specPVPStats[270].soloShuffle
assert(shuffle.seasonBest == 1720 and shuffle.roundsSeasonPlayed == 18,
    "verified spec statistics did not replace unowned legacy totals")
assert(shuffle.ownerCharacterKey == "Tester-Realm" and shuffle.ownerSpecID == 270,
    "verified spec statistics lost their character/spec owner")
assert(Database.SaveLastMMR("pvp-42", "Tester", "Realm", 270, 7, 1805),
    "season-bound specialization MMR was not saved")
assert(saved.specLastMMR[270].soloShuffle == 1805,
    "specialization MMR was written to the wrong character record")
assert(not Database.SaveLastMMR("pvp-41", "Tester", "Realm", 270, 7, 1900),
    "MMR was allowed to cross its season boundary")
assert(not Database.SaveCharacter("pvp-41", saved),
    "a character already bound to another season should be rejected")
assert(Database.SaveCharacter("pvp-41", {
    name = "Historical",
    realm = "Realm",
    level = 90,
    currentSpecID = 270,
    ratings = { arena2v2 = 1400 },
    pvpStats = {},
    lastMMR = {},
    specRatings = {},
    specPVPStats = {},
    specLastMMR = {},
    itemCounts = {},
}), "an explicitly season-bound historical API record was rejected")
assert(WarbandRatingsDB.seasons["pvp-41"].characters["Historical-Realm"].seasonKey == "pvp-41",
    "historical API data was written under the wrong season")

print("database tests passed")
