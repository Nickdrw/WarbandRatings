-- luacheck: globals time UnitName GetNormalizedRealmName GetRealmName
-- luacheck: globals GetSpecialization GetSpecializationInfo UnitClass UnitLevel
-- luacheck: globals GetMaxLevelForPlayerExpansion UnitGUID RequestRatedInfo
-- luacheck: globals GetPersonalRatedInfo GetBattlefieldWinner GetBattlefieldTeamInfo
-- luacheck: globals C_PvP IsInInstance

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
local currentSpecID = 71
local contentSeasonKey = "pvp-42"
local scoreInfo = {
    faction = 0,
    prematchMMR = 1550,
}
local recorded
local recordCount = 0
local enriched
local postmatchEnriched
local savedMMR
local savedMMRDelta
local savedMMRBracket
local seasonActive = true
local teamMMRByFaction = { [0] = 1600, [1] = 1500 }
local inInstance = false
local instanceType = "none"

time = function() return now end
UnitName = function() return currentName end
GetNormalizedRealmName = function() return currentRealm end
GetRealmName = function() return currentRealm end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return currentSpecID end
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
IsInInstance = function()
    return inInstance, instanceType
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
        GetContentSeasonKey = function() return contentSeasonKey end,
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
        EnrichMatchPostMMR = function(_, _, _, _, bracketIndex, mmr, matchSequence)
            postmatchEnriched = {
                bracketIndex = bracketIndex,
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
WarbandRatingsDB.seasons["pvp-42"].characters["Stale-Realm"] = {
    seasonKey = "pvp-42",
    ratings = {
        conquest_totalEarned = 750,
        conquest_maxQuantity = 750,
    },
}
WarbandRatingsDB.seasons["pvp-42"].characters["AlreadyCurrent-Realm"] = {
    seasonKey = "pvp-42",
    ratings = {
        conquest_totalEarned = 1500,
        conquest_maxQuantity = 1500,
    },
}
WarbandRatingsDB.seasons["pvp-41"] = {
    seasonKey = "pvp-41",
    characters = {
        ["Previous-Realm"] = {
            seasonKey = "pvp-41",
            ratings = { conquest_maxQuantity = 750 },
        },
    },
}
assert(DataCollection.RefreshWarbandConquestCap("pvp-42", 900),
    "a weekly Conquest-cap increase did not refresh the current season")
assert(WarbandRatingsDB.seasons["pvp-42"].characters["Stale-Realm"].ratings.conquest_maxQuantity == 900,
    "an unlogged character retained the previous week's Conquest cap")
assert(WarbandRatingsDB.seasons["pvp-42"].characters["Stale-Realm"].ratings.conquest_totalEarned == 750,
    "refreshing the Conquest cap changed an unlogged character's earned amount")
assert(WarbandRatingsDB.seasons["pvp-42"].characters["AlreadyCurrent-Realm"].ratings.conquest_maxQuantity == 1500,
    "the live Conquest cap refresh moved a newer saved cap backward")
assert(WarbandRatingsDB.seasons["pvp-41"].characters["Previous-Realm"].ratings.conquest_maxQuantity == 750,
    "the live Conquest cap refresh modified a previous season")
DataCollection.RequestRatedInfo()
assert(DataCollection.MarkRatedStatsUpdated())
assert(DataCollection.BeginRatedMatch())
assert(DataCollection.CaptureActiveMatchMMR())
assert(enriched and enriched.matchSequence == 10, "next-lobby prematch MMR was not aligned")
assert(DataCollection.MarkRatedMatchComplete(0, 120),
    "match completion was not retained while post-match MMR was unavailable")
assert(DataCollection.CollectLastMatchMMR(true))
assert(recorded == nil, "unchanged season game counter recorded an intermediate round")

now = 1090
local delayedRatingGeneration = DataCollection.GetActiveMatchGeneration()
assert(DataCollection.MarkRatedMatchComplete(0, 120),
    "a repeated completion event discarded the unrecorded match")
assert(DataCollection.GetActiveMatchGeneration() == delayedRatingGeneration,
    "a repeated completion event replaced the match context")
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

local retainedGenerationAfterExit = DataCollection.GetActiveMatchGeneration()
inInstance = false
instanceType = "none"
assert(not DataCollection.HandlePlayerEnteringWorld(),
    "leaving a completed match invalidated legitimate late MMR enrichment")
assert(DataCollection.GetActiveMatchGeneration() == retainedGenerationAfterExit,
    "the retained match changed while entering a non-PvP destination")

scoreInfo = { faction = 0, postmatchMMR = 1575 }
assert(DataCollection.CaptureActiveMatchMMR(), "late post-match MMR was not accepted")
assert(postmatchEnriched and postmatchEnriched.mmr == 1575
        and postmatchEnriched.matchSequence == 11,
    "late post-match MMR was not applied to the recorded match")
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "completed match context was not released after late MMR enrichment")

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
assert(DataCollection.RequestRatedInfo())
assert(DataCollection.MarkRatedStatsUpdated())
scoreInfo = { faction = 0, prematchMMR = 1700 }
savedMMR = nil
savedMMRDelta = nil
assert(DataCollection.BeginRatedMatch(true), "Solo Shuffle match tracking did not start")
assert(DataCollection.CaptureActiveMatchMMR())
scoreInfo = { faction = 0, postmatchMMR = 1722 }
assert(DataCollection.MarkRatedMatchComplete(0, 120), "Solo Shuffle completion did not capture MMR")
assert(savedMMR == 1722 and savedMMRDelta == 22,
    "MMR change was not derived from the same match's pre/post values")
rating = 125
seasonPlayed = 2
assert(DataCollection.CollectLastMatchMMR(true),
    "rating was not finalized when post-match MMR was already available")
assert(recordCount == 3, "post-match finalization recorded the match more than once")
assert(recorded[7] == 1722, "confirmed post-match MMR was not recorded")
assert(recorded[10] == true, "confirmed post-match MMR lost its provenance")
assert(not DataCollection.CollectLastMatchMMR(true),
    "duplicate finalization created another history point")

scoreInfo = { faction = 0, matchMakingRating = 1800 }
savedMMR = nil
savedMMRDelta = nil
assert(DataCollection.BeginRatedMatch(true), "second Solo Shuffle match tracking did not start")
assert(DataCollection.CaptureActiveMatchMMR())
scoreInfo = { faction = 0, matchMakingRating = 1824 }
assert(DataCollection.MarkRatedMatchComplete(0, 120), "generic final MMR sample was not captured")
assert(DataCollection.MarkRatedMatchComplete(0, 120),
    "a repeated completion event invalidated the match context")
assert(savedMMR == 1824 and savedMMRDelta == nil,
    "an unlabeled prematch MMR sample was promoted to a post-match delta")

rating = 140
seasonPlayed = 3
assert(DataCollection.CollectLastMatchMMR(true),
    "rating was not recorded while post-match MMR remained unavailable")
assert(recordCount == 4 and recorded[7] == nil and recorded[12] == "pending",
    "a match without post-match MMR was not retained as pending")
assert(not DataCollection.CollectLastMatchMMR(true),
    "repeated events duplicated a pending-MMR history point")

postmatchEnriched = nil
C_PvP.IsRatedSoloShuffle = function() return false end
C_PvP.IsSoloRBG = function() return true end
C_PvP.GetActiveMatchBracket = function() return 8 end -- Solo BG.
scoreInfo = { faction = 0, postmatchMMR = 2222 }
DataCollection.UpdateActivePVPContext()
assert(not DataCollection.CaptureActiveMatchMMR(),
    "Solo BG data was accepted for retained Solo Shuffle history")
assert(postmatchEnriched == nil,
    "Solo BG MMR enriched the old Solo Shuffle sequence")
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "incompatible bracket did not invalidate retained context")

C_PvP.IsRatedSoloShuffle = function() return true end
C_PvP.IsSoloRBG = function() return false end
C_PvP.GetActiveMatchBracket = function() return 6 end

local function RecordPendingShuffle(nextRating, nextSequence, prematchMMR)
    scoreInfo = { faction = 0, matchMakingRating = prematchMMR }
    assert(DataCollection.BeginRatedMatch(true))
    assert(DataCollection.CaptureActiveMatchMMR())
    assert(DataCollection.MarkRatedMatchComplete(0, 120))
    rating = nextRating
    seasonPlayed = nextSequence
    assert(DataCollection.CollectLastMatchMMR(true))
    assert(recorded[7] == nil and recorded[12] == "pending")
end

RecordPendingShuffle(150, 4, 1900)
postmatchEnriched = nil
inInstance = true
instanceType = "arena"
assert(DataCollection.HandlePlayerEnteringWorld(),
    "entering same-bracket match preparation did not invalidate retained MMR attribution")
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "same-bracket match preparation retained the previous match generation")
scoreInfo = { faction = 0, postmatchMMR = 2222 }
DataCollection.UpdateActivePVPContext()
assert(not DataCollection.CaptureActiveMatchMMR(),
    "the new match scoreboard enriched a retained same-bracket match")
assert(postmatchEnriched == nil,
    "the new match MMR was written to the previous same-bracket sequence")
inInstance = false
instanceType = "none"

RecordPendingShuffle(160, 5, 1950)
postmatchEnriched = nil
C_PvP.IsRatedSoloShuffle = function() return false end
C_PvP.GetActiveMatchBracket = function() return nil end
inInstance = true
instanceType = "pvp"
assert(DataCollection.HandlePlayerEnteringWorld(),
    "PvP entry with unavailable bracket detection retained the previous match")
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "a nil active bracket was treated as proof of retained-match attribution")
scoreInfo = { faction = 0, postmatchMMR = 2444 }
assert(not DataCollection.CaptureActiveMatchMMR(),
    "scoreboard MMR was captured after nil-bracket PvP entry")
assert(postmatchEnriched == nil,
    "nil-bracket PvP entry allowed the new activity to enrich the previous sequence")
inInstance = false
instanceType = "none"
C_PvP.IsRatedSoloShuffle = function() return true end
C_PvP.GetActiveMatchBracket = function() return 6 end

RecordPendingShuffle(170, 6, 2000)
postmatchEnriched = nil
currentSpecID = 72
scoreInfo = { faction = 0, postmatchMMR = 2020 }
assert(not DataCollection.CaptureActiveMatchMMR(),
    "MMR from another specialization was accepted")
assert(postmatchEnriched == nil,
    "another specialization enriched the retained match")
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "specialization mismatch did not invalidate retained context")
currentSpecID = 71

RecordPendingShuffle(180, 7, 2050)
postmatchEnriched = nil
contentSeasonKey = "pvp-41"
scoreInfo = { faction = 0, postmatchMMR = 2070 }
assert(not DataCollection.CaptureActiveMatchMMR(),
    "MMR from another season was accepted")
assert(postmatchEnriched == nil,
    "another season enriched the retained match")
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "season mismatch did not invalidate retained context")
contentSeasonKey = "pvp-42"

RecordPendingShuffle(190, 8, 2100)
local staleGeneration = DataCollection.GetActiveMatchGeneration()
assert(DataCollection.BeginRatedMatch(true), "replacement match tracking did not start")
local replacementGeneration = DataCollection.GetActiveMatchGeneration()
assert(replacementGeneration and replacementGeneration ~= staleGeneration,
    "new match preparation did not isolate the retained context")
assert(not DataCollection.CaptureActiveMatchMMR(staleGeneration),
    "a delayed retry captured MMR into a newer match context")
assert(DataCollection.CaptureActiveMatchMMR(),
    "the replacement match did not retain its own MMR sample")
assert(DataCollection.MarkRatedMatchComplete(0, 120),
    "the replacement match did not complete")
rating = 200
seasonPlayed = 9
assert(DataCollection.CollectLastMatchMMR(true),
    "the replacement match rating was not recorded")
assert(DataCollection.GetActiveMatchGeneration() ~= nil,
    "pending enrichment context was discarded before its retention window")
local expiringGeneration = DataCollection.GetActiveMatchGeneration()
now = now + 50
assert(DataCollection.MarkRatedMatchComplete(0, 120),
    "a repeated completion event invalidated pending enrichment")
assert(DataCollection.GetActiveMatchGeneration() == expiringGeneration,
    "a repeated completion event replaced pending enrichment context")
now = now + 11
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "a repeated completion event reset the enrichment deadline")

now = now + 1
scoreInfo = { faction = 0, matchMakingRating = 2100 }
assert(DataCollection.BeginRatedMatch(true),
    "unrecorded-context safety test did not start")
assert(DataCollection.MarkRatedMatchComplete(0, 120))
assert(DataCollection.MarkRatedMatchInactive())
now = now + 601
assert(DataCollection.GetActiveMatchGeneration() == nil,
    "an inactive unrecorded context survived its separate safety deadline")

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
