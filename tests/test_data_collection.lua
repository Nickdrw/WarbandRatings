-- luacheck: globals time UnitName GetNormalizedRealmName GetRealmName
-- luacheck: globals GetSpecialization GetSpecializationInfo UnitClass UnitLevel
-- luacheck: globals GetMaxLevelForPlayerExpansion UnitGUID RequestRatedInfo
-- luacheck: globals GetPersonalRatedInfo GetBattlefieldWinner GetBattlefieldTeamInfo C_PvP

local now = 1000
local rating = 1500
local seasonPlayed = 10
local roundsSeasonPlayed = 60
local scoreInfo = {
    faction = 0,
    prematchMMR = 1550,
}
local recorded
local recordCount = 0
local enriched
local savedMMR

time = function() return now end
UnitName = function() return "Tester" end
GetNormalizedRealmName = function() return "Realm" end
GetRealmName = function() return "Realm" end
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
local ns = {
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
        GLOBAL_COLUMNS = {},
        SPEC_COLUMNS = { specColumn },
        IsSpecColumn = function(col)
            return col == specColumn
        end,
        GetPVPColumnByBracketIndex = function(bracketIndex)
            if bracketIndex == 7 then return specColumn end
        end,
        SaveCharacter = function(data)
            WarbandRatingsDB.characters["Tester-Realm"] = data
        end,
        SaveLastMMR = function(_, _, _, _, mmr)
            savedMMR = mmr
            return true
        end,
    },
    History = {
        RecordDiagnostic = function() end,
        EnrichPendingMMR = function(_, _, _, _, mmr, matchSequence)
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
    characters = {
        ["Tester-Realm"] = {
            specRatings = {
                [71] = {
                    soloShuffle = rating,
                },
            },
            ratings = {},
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
assert(recorded[5] == 1520, "wrong post-lobby rating")
assert(recorded[6] == nil, "prematch MMR was incorrectly stored as post-match MMR")
assert(recorded[7] == nil, "Solo Shuffle should not invent a binary lobby result")
assert(recorded[10] == 11, "season game counter was not used as the match sequence")
assert(recorded[11] == "pending", "missing post-match MMR was not marked pending")
assert(savedMMR == 1550, "latest readable MMR was not retained for the character")
assert(not DataCollection.CollectLastMatchMMR(true), "untracked stats refresh should not finalize history")
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
assert(recorded[10] == 1, "first completed lobby did not use its season game counter")

print("data collection tests passed")
