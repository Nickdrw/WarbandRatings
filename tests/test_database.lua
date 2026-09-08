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
    settings = {
        hideArenaQueueHelper = true,
        petHealthAlertTestMode = true,
        petHealthAlertOpacity = 0.8,
        petHealthAlertSize = 80,
        petHealthAlertCollapsed = false,
        petHealthAlertEnabled = true,
        petCrowdControlAlertTestMode = true,
        petCrowdControlAlertCollapsed = false,
        petCrowdControlAlertEnabled = true,
    },
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
assert(WarbandRatingsDB.settings.petHealthAlertTestMode == nil,
    "the transient Test / Unlock state should not remain in saved settings")
assert(WarbandRatingsDB.settings.petHealthAlertEnabled == false,
    "the existing pet-health alert was not migrated to opt-in")
assert(WarbandRatingsDB.settings.petHealthAlertBouncing == true,
    "the pet-health alert should bounce by default")
assert(WarbandRatingsDB.settings.petHealthAlertCollapsed == nil,
    "the transient Pet Health Alert collapse state should not remain saved")
assert(WarbandRatingsDB.settings.petHealthWarningOpacity == 0.4
        and WarbandRatingsDB.settings.petHealthDangerOpacity == 0.8
        and WarbandRatingsDB.settings.petHealthCriticalOpacity == 0.8,
    "the shared pet-health opacity was not migrated to the three thresholds")
assert(WarbandRatingsDB.settings.petHealthWarningSize == 80
        and WarbandRatingsDB.settings.petHealthDangerSize == 80
        and WarbandRatingsDB.settings.petHealthCriticalSize == 104,
    "the shared pet-health size was not migrated to the three thresholds")
assert(WarbandRatingsDB.settings.petHealthAlertOpacity == nil
        and WarbandRatingsDB.settings.petHealthAlertSize == nil,
    "the obsolete shared pet-health settings were not removed after migration")
assert(WarbandRatingsDB.settings.petCrowdControlAlertTestMode == nil,
    "the transient pet-CC Test / Unlock state should not remain in saved settings")
assert(WarbandRatingsDB.settings.petCrowdControlAlertEnabled == false,
    "the existing pet crowd-control alert was not migrated to opt-in")
assert(WarbandRatingsDB.settings.petCrowdControlAlertBouncing == true,
    "the pet crowd-control alert should bounce by default")
assert(WarbandRatingsDB.settings.petCrowdControlAlertCollapsed == nil,
    "the transient Pet Crowd Control Alert collapse state should not remain saved")
assert(WarbandRatingsDB.settings.classModuleCollapseDefaultsVersion == nil,
    "the obsolete collapsed-module migration marker should not remain saved")
assert(WarbandRatingsDB.settings.petCrowdControlAlertOpacity == 1
        and WarbandRatingsDB.settings.petCrowdControlAlertSize == 64,
    "the pet crowd-control alert did not receive its default appearance")
assert(WarbandRatingsDB.settings.classHunterCollapsed == false,
    "the Hunter settings category should start expanded")
assert(WarbandRatingsDB.settings.classModuleOptInDefaultsVersion == 1,
    "the class-module opt-in migration was not recorded")

WarbandRatingsDB.settings.petHealthAlertEnabled = true
WarbandRatingsDB.settings.petCrowdControlAlertEnabled = true
Database.Init()
assert(WarbandRatingsDB.settings.petHealthAlertEnabled == true
        and WarbandRatingsDB.settings.petCrowdControlAlertEnabled == true,
    "explicitly enabled class modules did not remain enabled after migration")

assert(Database.NormalizeHonorAlertThreshold("13500") == 13500,
    "a custom Honor alert threshold was not normalized")
assert(Database.NormalizeHonorAlertThreshold(0) == 12000,
    "an invalid Honor alert threshold should use the default")
assert(Database.NormalizePetHealthAlertOpacity(0.63) == 0.65
        and Database.NormalizePetHealthAlertOpacity(0) == 0.10
        and Database.NormalizePetHealthAlertOpacity(2) == 1,
    "pet-health alert opacity was not clamped and stepped correctly")
assert(Database.NormalizePetHealthAlertSize(78) == 78
        and Database.NormalizePetHealthAlertSize(12) == 32
        and Database.NormalizePetHealthAlertSize(200) == 168,
    "pet-health alert size was not clamped and stepped correctly")
assert(Database.NormalizePetCrowdControlAlertOpacity(0.63) == 0.65
        and Database.NormalizePetCrowdControlAlertOpacity(0) == 0.10
        and Database.NormalizePetCrowdControlAlertOpacity(2) == 1,
    "pet crowd-control alert opacity was not clamped and stepped correctly")
assert(Database.NormalizePetCrowdControlAlertSize(78) == 78
        and Database.NormalizePetCrowdControlAlertSize(12) == 32
        and Database.NormalizePetCrowdControlAlertSize(200) == 168,
    "pet crowd-control alert size was not clamped and stepped correctly")
assert(Database.NormalizeClassModuleEnabled(nil) == false
        and Database.NormalizeClassModuleEnabled(false) == false
        and Database.NormalizeClassModuleEnabled(true) == true,
    "class-module Enable settings were not normalized as opt-in")

WarbandRatingsDB.settings.hideNoRating = true
local filteredGroups = Database.BuildCharacterGroups({
    ["CurrencyOnly-Realm"] = {
        name = "CurrencyOnly",
        realm = "Realm",
        classFilename = "MONK",
        level = 90,
        ratings = { honor = 6935, conquest = 1600, hk = 120 },
        specRatings = {},
    },
    ["GlobalRated-Realm"] = {
        name = "GlobalRated",
        realm = "Realm",
        classFilename = "MONK",
        level = 90,
        ratings = { arena2v2 = 1053, honor = 6935 },
        specRatings = {},
    },
    ["SpecRated-Realm"] = {
        name = "SpecRated",
        realm = "Realm",
        classFilename = "MONK",
        level = 90,
        ratings = { conquest = 500 },
        specRatings = { [270] = { soloShuffle = 1001 } },
    },
}, "pvp-42")
assert(#filteredGroups == 2,
    "the no-rating filter should ignore currencies and stats")
assert(filteredGroups[1].charData.name == "GlobalRated"
        and filteredGroups[2].charData.name == "SpecRated",
    "the no-rating filter removed a character with a PvP bracket rating")
WarbandRatingsDB.settings.hideNoRating = false

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
assert(Database.SaveLastMMR("pvp-42", "Tester", "Realm", 270, 2, 1900, -12),
    "season-bound arena MMR with its change was not saved")
assert(saved.lastMMRDelta.arena3v3 == -12,
    "arena MMR change was written to the wrong character record")
assert(Database.SaveLastMMR("pvp-42", "Tester", "Realm", 270, 2, 1900),
    "arena MMR without a verified change was not saved")
assert(saved.lastMMRDelta.arena3v3 == nil,
    "stale arena MMR change was retained without a verified match pair")
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

-- Retired experimental fields must disappear without removing unrelated data,
-- including when an older character snapshot is merged back into the database.
local preservedRating, preservedSeries = saved.ratings.arena2v2, saved.series
saved.combatStats, saved.combatStatsVersion = { obsolete = true }, 4
local historical = WarbandRatingsDB.seasons["pvp-41"].characters["Historical-Realm"]
historical.combatStats, historical.combatStatsVersion = { obsolete = true }, 1
WarbandRatingsDB.characters = { Legacy = { combatStats = { obsolete = true }, combatStatsVersion = 4 } }
Database.Init()
Database.Migrate()
assert(saved.combatStats == nil and saved.combatStatsVersion == nil
    and historical.combatStats == nil and historical.combatStatsVersion == nil
    and WarbandRatingsDB.characters.Legacy.combatStats == nil
    and WarbandRatingsDB.characters.Legacy.combatStatsVersion == nil,
    "retired data survived initialization in a current, archived or legacy character")
assert(saved.ratings.arena2v2 == preservedRating and saved.series == preservedSeries,
    "retired-data cleanup changed ratings or history")
saved.combatStats, saved.combatStatsVersion = { obsolete = true }, 4
assert(Database.SaveCharacter("pvp-42", saved))
assert(saved.combatStats == nil and saved.combatStatsVersion == nil,
    "merging an old snapshot restored retired data")

print("database tests passed")
