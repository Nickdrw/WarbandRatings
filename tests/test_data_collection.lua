-- luacheck: globals time UnitName GetNormalizedRealmName GetRealmName
-- luacheck: globals GetSpecialization GetSpecializationInfo UnitClass UnitLevel
-- luacheck: globals GetMaxLevelForPlayerExpansion UnitGUID RequestRatedInfo
-- luacheck: globals GetPersonalRatedInfo GetBattlefieldWinner GetBattlefieldTeamInfo C_PvP

local now = 1000
local rating = 1500
local seasonPlayed = 10
local roundsSeasonPlayed = 60
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
local seasonActive = true

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
    return rating, 0, 0, seasonPlayed, 0, 0, 0, 0, 0, 0, 0,
        roundsSeasonPlayed, 0, 0, 0
end
GetBattlefieldWinner = function() return 0 end
GetBattlefieldTeamInfo = function()
    return nil, nil, nil, 1600
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
        end,
        IsValidSeasonKey = function(seasonKey)
            return seasonKey == "pvp-42"
        end,
        GetSeasonCharacters = function(seasonKey)
            return WarbandRatingsDB.seasons[seasonKey].characters
        end,
        SaveCharacter = function(seasonKey, data)
            data.seasonKey = seasonKey
            WarbandRatingsDB.seasons[seasonKey].characters[data.name .. "-" .. data.realm] = data
            return true
        end,
        SaveLastMMR = function(_, _, _, _, _, mmr)
            savedMMR = mmr
            return true
        end,
    },
    History = {
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
assert(not DataCollection.BeginRatedMatch(true), "offseason match tracking should not start")
assert(not DataCollection.CollectLastMatchMMR(true), "offseason match history should not be recorded")
assert(recordCount == 1, "offseason collection added a graph point")
seasonActive = true
assert(recordCount == 1, "untracked stats refresh manufactured a history point")

scoreInfo = { faction = 0 }
enriched = nil
savedMMR = nil
assert(DataCollection.BeginRatedMatch(true))
assert(DataCollection.CaptureActiveMatchMMR())
assert(enriched == nil, "team-average MMR should not enrich a personal history point")
assert(savedMMR == 1600, "team-average fallback should remain available for the character display")

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

print("data collection tests passed")
