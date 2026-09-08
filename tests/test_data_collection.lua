-- luacheck: globals time UnitName GetNormalizedRealmName GetRealmName
-- luacheck: globals GetSpecialization GetSpecializationInfo UnitClass UnitLevel
-- luacheck: globals GetMaxLevelForPlayerExpansion UnitGUID RequestRatedInfo
-- luacheck: globals GetPersonalRatedInfo GetBattlefieldWinner GetBattlefieldTeamInfo
-- luacheck: globals C_PvP

local now = 1000
local rating = 1500
local seasonBest = 0
local weeklyBest = 0
local seasonPlayed = 10
local weeklyPlayed = 0
local weeklyWon = 0
local roundsSeasonPlayed = 60
local roundsWeeklyPlayed = 0
local roundsWeeklyWon = 0
local currentName = "Tester"
local currentRealm = "Realm"
local scoreInfo = {
    faction = 0,
    prematchMMR = 1550,
}
local recorded
local recordCount = 0
local enriched
local savedMMR
local savedMMRDelta
local savedMMRBracket
local seasonActive = true
local teamMMRByFaction = { [0] = 1600, [1] = 1500 }

time = function() return now end
UnitName = function() return currentName end
GetNormalizedRealmName = function() return currentRealm end
GetRealmName = function() return currentRealm end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 71 end
UnitClass = function() return "Warrior", "WARRIOR", 1 end
UnitLevel = function() return 90 end
GetMaxLevelForPlayerExpansion = function() return 90 end
UnitGUID = function() return "Player-1" end
RequestRatedInfo = function() end
GetPersonalRatedInfo = function()
    return rating, seasonBest, weeklyBest, seasonPlayed, 0, weeklyPlayed, weeklyWon, 0, 0, 0, 0,
        roundsSeasonPlayed, 0, roundsWeeklyPlayed, roundsWeeklyWon
end
GetBattlefieldWinner = function() return 0 end
GetBattlefieldTeamInfo = function(faction)
    return nil, nil, nil, teamMMRByFaction[faction]
end

C_PvP = {
    IsRatedSoloShuffle = function() return true end,
    IsSoloRBG = function() return false end,
    IsRatedBattleground = function() return false end,
    IsRatedArena = function() return false end,
    GetScoreInfoByPlayerGuid = function() return scoreInfo end,
    GetPersonalRatedSoloShuffleSpecStats = function()
        return {}
    end,
}

local specColumn = { key = "soloShuffle", bracketIndex = 7 }
local globalColumn = { key = "arena3v3", bracketIndex = 2 }
local ns = {
    Season = {
        GetContentSeasonKey = function() return "pvp-42" end,
        GetPreviousSeasonKey = function(seasonKey)
            return seasonKey == "pvp-42" and "pvp-41" or nil
        end,
        IsRatedSeasonActive = function() return seasonActive end,
    },
    Utils = {
        CharKey = function(name, realm)
            return name .. "-" .. realm
        end,
        IsEmptyRating = function(value)
            return not value or value == 0
        end,
    },
    Database = {
        HELIOTROPE_ITEM_ID = 253307,
        GLOBAL_COLUMNS = { globalColumn },
        GetGlobalColumns = function() return { globalColumn } end,
        SPEC_COLUMNS = { specColumn },
        IsSpecColumn = function(col)
            return col == specColumn
        end,
        GetPVPColumnByBracketIndex = function(bracketIndex)
            if bracketIndex == 7 then return specColumn end
            if bracketIndex == 1 or bracketIndex == 2 then return globalColumn end
        end,
        IsValidSeasonKey = function(seasonKey)
            return seasonKey == "pvp-42" or seasonKey == "pvp-41"
        end,
        GetSeasonCharacters = function(seasonKey)
            local season = WarbandRatingsDB.seasons[seasonKey]
            return season and season.characters or {}
        end,
        SaveCharacter = function(seasonKey, data)
            WarbandRatingsDB.seasons[seasonKey] = WarbandRatingsDB.seasons[seasonKey] or {
                seasonKey = seasonKey,
                characters = {},
            }
            data.seasonKey = seasonKey
            WarbandRatingsDB.seasons[seasonKey].characters[data.name .. "-" .. data.realm] = data
            return true
        end,
        SaveLastMMR = function(_, _, _, _, bracketIndex, mmr, mmrDelta)
            savedMMRBracket = bracketIndex
            savedMMR = mmr
            savedMMRDelta = mmrDelta
            return true
        end,
    },
    History = {
        ArchiveSeason = function(seasonKey)
            WarbandRatingsDB.seasons[seasonKey].archived = true
            return true
        end,
        RecordDiagnostic = function() end,
        EnrichPendingMMR = function(_, _, _, _, _, mmr, matchSequence)
            enriched = {
                mmr = mmr,
                matchSequence = matchSequence,
            }
            return true
        end,
        RecordMatch = function(...)
            recordCount = recordCount + 1
            recorded = { ... }
            return true
        end,
    },
}

WarbandRatingsDB = {
    seasons = {
        ["pvp-42"] = {
            seasonKey = "pvp-42",
            characters = {
                ["Tester-Realm"] = {
                    seasonKey = "pvp-42",
                    specRatings = {
                        [71] = {
                            soloShuffle = rating,
                        },
                    },
                    ratings = {},
                },
            },
        },
    },
}

assert(loadfile("DataCollection.lua"))("WarbandRatings", ns)
local DataCollection = ns.DataCollection
DataCollection.RequestRatedInfo()
assert(DataCollection.MarkRatedStatsUpdated())
assert(DataCollection.BeginRatedMatch())
assert(DataCollection.CaptureActiveMatchMMR())
assert(enriched and enriched.matchSequence == 10, "next-lobby prematch MMR was not aligned")
assert(DataCollection.CollectLastMatchMMR(true))
assert(recorded == nil, "unchanged season game counter recorded an intermediate round")

rating = 1520
seasonPlayed = 11
roundsSeasonPlayed = 66
now = 1100

assert(DataCollection.CollectLastMatchMMR(true))
assert(recorded, "fresh rating was not recorded")
assert(recorded[1] == "pvp-42", "match history was not bound to its season")
assert(recorded[6] == 1520, "wrong post-lobby rating")
assert(recorded[7] == nil, "prematch MMR was incorrectly stored as post-match MMR")
assert(recorded[8] == nil, "Solo Shuffle should not invent a binary lobby result")
assert(recorded[11] == 11, "season game counter was not used as the match sequence")
assert(recorded[12] == "pending", "missing post-match MMR was not marked pending")
assert(savedMMR == 1550, "latest readable MMR was not retained for the character")
assert(not DataCollection.CollectLastMatchMMR(true), "untracked stats refresh should not finalize history")

local storedCharacter = WarbandRatingsDB.seasons["pvp-42"].characters["Tester-Realm"]
storedCharacter.ratings.arena3v3 = 1816
seasonActive = false
rating = 1964
local frozenCharacter = DataCollection.CollectCurrentCharacter()
assert(frozenCharacter == storedCharacter, "offseason collection did not return the frozen snapshot")
assert(frozenCharacter.ratings.arena3v3 == 1816, "offseason collection changed the table rating")
local backfilledCharacter, backfilledSeasonKey = DataCollection.CollectPreseasonCharacter()
assert(backfilledSeasonKey == "pvp-41", "preseason API data was bound to the wrong season")
assert(backfilledCharacter and backfilledCharacter.seasonKey == "pvp-41",
    "preseason API data did not create a previous-season character")
assert(backfilledCharacter.ratings.arena3v3 == 1964,
    "preseason API rating was not saved in the previous season")
assert(backfilledCharacter.pvpStats.arena3v3.ownerCharacterKey == "Tester-Realm",
    "preseason global totals lost their character ownership")
assert(backfilledCharacter.specPVPStats[71].soloShuffle.ownerSpecID == 71,
    "preseason specialization totals lost their specialization ownership")
assert(WarbandRatingsDB.seasons["pvp-41"].archived,
    "the backfilled previous season was not archived")
assert(storedCharacter.ratings.arena3v3 == 1816,
    "preseason backfill contaminated the upcoming-season character")
rating = 2107
weeklyBest = 2107
weeklyPlayed = 1
weeklyWon = 1
roundsWeeklyPlayed = 6
roundsWeeklyWon = 3
local refreshedBackfill = DataCollection.CollectPreseasonCharacter()
assert(refreshedBackfill.ratings.arena3v3 == 1964,
    "a later preseason API refresh changed an imported global rating")
assert(refreshedBackfill.specRatings[71].soloShuffle == 1964,
    "a later preseason API refresh changed an imported specialization rating")
assert(refreshedBackfill.specPVPStats[71].soloShuffle.weeklyPlayed == 0
        and refreshedBackfill.specPVPStats[71].soloShuffle.roundsWeeklyPlayed == 0,
    "preseason weekly counters leaked into a completed season")

WarbandRatingsDB.seasons["pvp-41"] = nil
seasonBest = 2200
local contaminatedBackfill = DataCollection.CollectPreseasonCharacter()
assert(contaminatedBackfill.ratings.arena3v3 == 2200
        and contaminatedBackfill.specRatings[71].soloShuffle == 2200,
    "a first import after preseason activity did not fall back to season best")
assert(contaminatedBackfill.pvpStats.arena3v3.preseasonRatingIsSeasonBest
        and contaminatedBackfill.specPVPStats[71].soloShuffle.preseasonRatingIsSeasonBest,
    "the season-best fallback source was not recorded")
assert(contaminatedBackfill.pvpStats.arena3v3.weeklyBest == 0
        and contaminatedBackfill.pvpStats.arena3v3.weeklyPlayed == 0
        and contaminatedBackfill.specPVPStats[71].soloShuffle.roundsWeeklyPlayed == 0,
    "a contaminated first import retained preseason weekly statistics")
assert(not DataCollection.BeginRatedMatch(true), "offseason match tracking should not start")
assert(not DataCollection.CollectLastMatchMMR(true), "offseason match history should not be recorded")
assert(recordCount == 1, "offseason collection added a graph point")
seasonActive = true
assert(recordCount == 1, "untracked stats refresh manufactured a history point")

scoreInfo = { faction = 0 }
enriched = nil
savedMMR = nil
assert(DataCollection.BeginRatedMatch(true))
assert(not DataCollection.CaptureActiveMatchMMR())
assert(enriched == nil, "team-average MMR should not enrich a personal history point")
assert(savedMMR == nil, "team MMR should not be used for a personal-MMR bracket")

scoreInfo = {
    faction = 0,
    prematchMMR = 1500,
}
rating = 0
seasonPlayed = 0
assert(DataCollection.BeginRatedMatch(true))
DataCollection.CollectLastMatchMMR(true)
assert(recordCount == 1, "first-lobby intermediate stats manufactured a history point")

rating = 100
seasonPlayed = 1
DataCollection.CollectLastMatchMMR(true)
assert(recordCount == 2, "first completed lobby was not recorded")
assert(recorded[11] == 1, "first completed lobby did not use its season game counter")

local testerData = DataCollection.CollectCurrentCharacter()
assert(testerData.seasonKey == "pvp-42", "collected character data was not bound to its season")
assert(testerData.pvpStats.arena3v3.ownerCharacterKey == "Tester-Realm",
    "fresh global statistics were not bound to their character")
assert(testerData.specPVPStats[71].soloShuffle.ownerSpecID == 71,
    "fresh specialization statistics were not bound to their specialization")

currentName = "Other"
local staleCharacterData = DataCollection.CollectCurrentCharacter()
assert(staleCharacterData.pvpStats.arena3v3 == nil,
    "a different character received cached global season statistics")
assert(staleCharacterData.currentSpecRatings == nil,
    "a different character received cached specialization ratings")

assert(DataCollection.RequestRatedInfo())
currentName = "Tester"
assert(not DataCollection.MarkRatedStatsUpdated(),
    "a rated-stats response was accepted for the wrong character")
currentName = "Other"
assert(DataCollection.RequestRatedInfo())
assert(DataCollection.MarkRatedStatsUpdated())
local otherData = DataCollection.CollectCurrentCharacter()
assert(otherData.pvpStats.arena3v3.ownerCharacterKey == "Other-Realm",
    "the refreshed character did not receive owned global statistics")

currentName = "Tester"
C_PvP.IsRatedSoloShuffle = function() return true end
C_PvP.IsRatedArena = function() return false end
C_PvP.GetActiveMatchBracket = function() return 6 end -- Blizzard's zero-based Solo Shuffle ID.
scoreInfo = { faction = 0, prematchMMR = 1700 }
savedMMR = nil
savedMMRDelta = nil
assert(DataCollection.BeginRatedMatch(true), "Solo Shuffle match tracking did not start")
assert(DataCollection.CaptureActiveMatchMMR())
scoreInfo = { faction = 0, postmatchMMR = 1722 }
assert(DataCollection.MarkRatedMatchComplete(0, 120), "Solo Shuffle completion did not capture MMR")
assert(savedMMR == 1722 and savedMMRDelta == 22,
    "MMR change was not derived from the same match's pre/post values")

scoreInfo = { faction = 0, matchMakingRating = 1800 }
savedMMR = nil
savedMMRDelta = nil
assert(DataCollection.BeginRatedMatch(true), "second Solo Shuffle match tracking did not start")
assert(DataCollection.CaptureActiveMatchMMR())
scoreInfo = { faction = 0, matchMakingRating = 1824 }
assert(DataCollection.MarkRatedMatchComplete(0, 120), "generic final MMR sample was not captured")
assert(savedMMR == 1824 and savedMMRDelta == 24,
    "final MMR sample was not paired with the same match's starting MMR")

C_PvP.IsRatedSoloShuffle = function() return false end
C_PvP.IsRatedArena = function() return true end
C_PvP.GetActiveMatchBracket = function() return 0 end -- Blizzard's zero-based 2v2 ID.
teamMMRByFaction[0] = 2200 -- Opposing team: must never be selected for this player.
teamMMRByFaction[1] = 1650
scoreInfo = { faction = 1, prematchMMR = 0, postmatchMMR = 0 }
savedMMR = nil
savedMMRDelta = nil
assert(DataCollection.BeginRatedMatch(true), "2v2 match tracking did not start")
assert(DataCollection.CaptureActiveMatchMMR())
assert(savedMMRBracket == 1, "zero-based 2v2 bracket was not normalized for MMR storage")
teamMMRByFaction[1] = 1675
assert(DataCollection.MarkRatedMatchComplete(1, 120), "2v2 completion did not capture team MMR")
assert(savedMMR == 1675 and savedMMRDelta == 25,
    "2v2 MMR was not derived from the player's own team")

scoreInfo = { prematchMMR = 1900, postmatchMMR = 1925 }
savedMMR = nil
savedMMRDelta = nil
assert(DataCollection.BeginRatedMatch(true), "2v2 match without faction did not start")
assert(not DataCollection.CaptureActiveMatchMMR(), "2v2 captured MMR without the player's faction")
assert(savedMMR == nil and savedMMRDelta == nil,
    "2v2 wrote an MMR value without a trustworthy team identity")

C_PvP.GetActiveMatchBracket = function() return 1 end -- Blizzard's zero-based 3v3 ID.
teamMMRByFaction[0] = 1800
teamMMRByFaction[1] = 2300 -- Opposing team: must never be selected for this player.
scoreInfo = { faction = 0, prematchMMR = 0, postmatchMMR = 0 }
savedMMR = nil
savedMMRDelta = nil
assert(DataCollection.BeginRatedMatch(true), "3v3 match tracking did not start")
assert(DataCollection.CaptureActiveMatchMMR())
teamMMRByFaction[0] = 1820
assert(DataCollection.MarkRatedMatchComplete(0, 120), "3v3 completion did not capture team MMR")
assert(savedMMR == 1820 and savedMMRDelta == 20,
    "3v3 MMR was not derived from the player's own team")

DataCollection.UpdateActivePVPContext()
assert(DataCollection.BeginRatedMatch(true), "zero-based 3v3 bracket did not start match tracking")
assert(DataCollection.CaptureActiveMatchMMR())
assert(savedMMRBracket == 2, "zero-based 3v3 bracket was not normalized for MMR storage")

print("data collection tests passed")
