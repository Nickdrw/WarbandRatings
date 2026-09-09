local _, ns = ...
ns.DataCollection = {}
local DataCollection = ns.DataCollection
local Database = ns.Database
local History = ns.History
local Season = ns.Season
local Utils = ns.Utils
local lastKnownRatedBracketIndex
local lastKnownRatedBracketTime
local ratedStatsSpecID
local ratedStatsRequestedSpecID
local ratedStatsCharacterKey
local ratedStatsRequestedCharacterKey
local activeRatedMatch

-- C_PvP.GetActiveMatchBracket uses zero-based bracket IDs, unlike the
-- one-based IDs accepted by GetPersonalRatedInfo and Database columns.
local ACTIVE_MATCH_BRACKET_TO_DATABASE_INDEX = {
    [0] = 1, -- 2v2
    [1] = 2, -- 3v3
    [3] = 4, -- Rated Battleground
    [6] = 7, -- Solo Shuffle
    [8] = 9, -- Battleground Blitz
}

local ACCOUNT_BANK_BAG_IDS = {
    12,
    13,
    14,
    15,
    16,
}

local function GetCurrentCharacterIdentity()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName() or GetRealmName():gsub("%s", "")
    return name, realm
end

local function GetCurrentCharacterKey()
    local name, realm = GetCurrentCharacterIdentity()
    return Utils.CharKey(name, realm)
end

local function GetCurrentSpecID()
    local specIndex = GetSpecialization()
    local specID
    if specIndex then
        specID = GetSpecializationInfo(specIndex)
    end
    return specID or 0
end

local function IsRatedSeasonInactive()
    return Season.IsRatedSeasonActive and Season.IsRatedSeasonActive() == false
end

local function CanCollectRatedStats(characterKey, specID, isMaxLevel)
    if not isMaxLevel then
        return true
    end

    return ratedStatsCharacterKey == characterKey and ratedStatsSpecID == specID
end

local function CopyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function HasSeasonPVPActivity(rating, stats)
    if (tonumber(rating) or 0) > 0 then return true end
    if type(stats) ~= "table" then return false end

    return (tonumber(stats.seasonBest) or 0) > 0
        or (tonumber(stats.seasonPlayed) or 0) > 0
        or (tonumber(stats.seasonWon) or 0) > 0
        or (tonumber(stats.roundsSeasonPlayed) or 0) > 0
        or (tonumber(stats.roundsSeasonWon) or 0) > 0
end

local function HasPreseasonWeeklyActivity(stats)
    if type(stats) ~= "table" then return false end
    return (tonumber(stats.weeklyBest) or 0) > 0
        or (tonumber(stats.weeklyPlayed) or 0) > 0
        or (tonumber(stats.weeklyWon) or 0) > 0
        or (tonumber(stats.roundsWeeklyPlayed) or 0) > 0
        or (tonumber(stats.roundsWeeklyWon) or 0) > 0
end

local function PreparePreseasonPVPStats(apiRating, apiStats, storedRating, storedStats)
    if type(storedStats) == "table" then
        return storedRating ~= nil and storedRating or storedStats.rating or apiRating, storedStats
    end
    if type(apiStats) ~= "table" then return apiRating, apiStats end

    local importedRating = storedRating ~= nil and storedRating or apiRating
    if storedRating == nil and HasPreseasonWeeklyActivity(apiStats) then
        local seasonBest = tonumber(apiStats.seasonBest) or 0
        if seasonBest > 0 then
            importedRating = seasonBest
            apiStats.preseasonRatingIsSeasonBest = true
        end
    end

    apiStats.rating = tonumber(importedRating) or 0
    apiStats.weeklyBest = 0
    apiStats.weeklyPlayed = 0
    apiStats.weeklyWon = 0
    apiStats.roundsWeeklyPlayed = 0
    apiStats.roundsWeeklyWon = 0
    apiStats.weeklyMostPlayedSpecID = 0
    apiStats.weeklyMostPlayedSpecCount = 0
    apiStats.preseasonAPIBackfilled = true
    return importedRating, apiStats
end

local function AddPVPBracketSpecStats(stats, colKey)
    local specStats
    local countField
    if colKey == "soloShuffle" and C_PvP and C_PvP.GetPersonalRatedSoloShuffleSpecStats then
        specStats = C_PvP.GetPersonalRatedSoloShuffleSpecStats()
        countField = "Rounds"
    elseif colKey == "soloBG" and C_PvP and C_PvP.GetPersonalRatedBGBlitzSpecStats then
        specStats = C_PvP.GetPersonalRatedBGBlitzSpecStats()
        countField = "Games"
    end
    if not specStats then return end

    stats.weeklyMostPlayedSpecID = tonumber(specStats.weeklyMostPlayedSpecID) or 0
    stats.seasonMostPlayedSpecID = tonumber(specStats.seasonMostPlayedSpecID) or 0
    stats.weeklyMostPlayedSpecCount = tonumber(specStats["weeklyMostPlayedSpec" .. countField]) or 0
    stats.seasonMostPlayedSpecCount = tonumber(specStats["seasonMostPlayedSpec" .. countField]) or 0
end

local function CollectPVPBracketInfo(
    bracketIndex,
    isMaxLevel,
    colKey,
    collectStats,
    characterKey,
    specID
)
    if not isMaxLevel then
        return 0, nil
    end

    local rating, seasonBest, weeklyBest, seasonPlayed, seasonWon, weeklyPlayed, weeklyWon,
        _, _, _, _, roundsSeasonPlayed, roundsSeasonWon, roundsWeeklyPlayed, roundsWeeklyWon = GetPersonalRatedInfo(bracketIndex)
    rating = tonumber(rating) or 0

    -- The current rating becomes readable before the cumulative season fields on
    -- login. Persist those fields only after PVP_RATED_STATS_UPDATE confirms the
    -- cache requested for this exact character and specialization.
    if not collectStats then
        return rating, nil
    end

    local stats = {
        rating = rating,
        seasonBest = tonumber(seasonBest) or 0,
        weeklyBest = tonumber(weeklyBest) or 0,
        seasonPlayed = tonumber(seasonPlayed) or 0,
        seasonWon = tonumber(seasonWon) or 0,
        weeklyPlayed = tonumber(weeklyPlayed) or 0,
        weeklyWon = tonumber(weeklyWon) or 0,
        roundsSeasonPlayed = tonumber(roundsSeasonPlayed) or 0,
        roundsSeasonWon = tonumber(roundsSeasonWon) or 0,
        roundsWeeklyPlayed = tonumber(roundsWeeklyPlayed) or 0,
        roundsWeeklyWon = tonumber(roundsWeeklyWon) or 0,
        ownerCharacterKey = characterKey,
        ownerSpecID = specID,
    }
    AddPVPBracketSpecStats(stats, colKey)
    return rating, stats
end

local function GetItemCount(itemID, includeBank, includeUses, includeReagentBank, includeAccountBank)
    if C_Item and C_Item.GetItemCount then
        return tonumber(C_Item.GetItemCount(itemID, includeBank, includeUses, includeReagentBank, includeAccountBank)) or 0
    elseif _G.GetItemCount then
        return tonumber(_G.GetItemCount(itemID, includeBank, includeUses)) or 0
    end
    return 0
end

local function GetCharacterHeliotropeCount()
    return GetItemCount(Database.HELIOTROPE_ITEM_ID, true, false, true, false)
end

local function GetAccountBankBagIDs()
    local bagIndex = Enum and Enum.BagIndex
    if not bagIndex or not bagIndex.AccountBankTab_1 then
        return ACCOUNT_BANK_BAG_IDS
    end

    return {
        bagIndex.AccountBankTab_1,
        bagIndex.AccountBankTab_2,
        bagIndex.AccountBankTab_3,
        bagIndex.AccountBankTab_4,
        bagIndex.AccountBankTab_5,
    }
end

local function GetContainerItemID(itemInfo)
    if not itemInfo then return nil end
    if itemInfo.itemID then return itemInfo.itemID end
    return itemInfo.hyperlink and tonumber(itemInfo.hyperlink:match("item:(%d+)"))
end

function DataCollection.ScanWarbandBankHeliotrope()
    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
        return false
    end

    local total = 0
    local scanned = false
    for _, bagID in ipairs(GetAccountBankBagIDs()) do
        if bagID then
            local slots = tonumber(C_Container.GetContainerNumSlots(bagID)) or 0
            if slots > 0 then
                scanned = true
                for slot = 1, slots do
                    local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
                    if GetContainerItemID(itemInfo) == Database.HELIOTROPE_ITEM_ID then
                        total = total + (tonumber(itemInfo.stackCount) or 1)
                    end
                end
            end
        end
    end

    if scanned then
        Database.SaveWarbandItemCount(Database.HELIOTROPE_ITEM_ID, total)
    end
    return scanned
end

function DataCollection.MarkRatedStatsStale()
    ratedStatsSpecID = nil
    ratedStatsRequestedSpecID = nil
    ratedStatsCharacterKey = nil
    ratedStatsRequestedCharacterKey = nil
    return GetCurrentSpecID()
end

function DataCollection.RequestRatedInfo(expectedSpecID)
    local specID = GetCurrentSpecID()
    local characterKey = GetCurrentCharacterKey()
    if expectedSpecID and expectedSpecID ~= specID then
        return false
    end

    ratedStatsSpecID = nil
    ratedStatsRequestedSpecID = specID
    ratedStatsCharacterKey = nil
    ratedStatsRequestedCharacterKey = characterKey

    if RequestRatedInfo then
        RequestRatedInfo()
    end

    return true
end

function DataCollection.MarkRatedStatsUpdated()
    local specID = GetCurrentSpecID()
    local characterKey = GetCurrentCharacterKey()
    if ratedStatsRequestedCharacterKey and ratedStatsRequestedCharacterKey ~= characterKey then
        return false
    end
    if ratedStatsRequestedSpecID and ratedStatsRequestedSpecID ~= specID then
        return false
    end
    if not ratedStatsRequestedSpecID and not ratedStatsSpecID then
        return false
    end
    if not ratedStatsRequestedCharacterKey and ratedStatsCharacterKey ~= characterKey then
        return false
    end

    ratedStatsCharacterKey = characterKey
    ratedStatsSpecID = specID
    ratedStatsRequestedCharacterKey = nil
    ratedStatsRequestedSpecID = nil
    return true
end

-- Conquest's seasonal cap is shared by every character, while totalEarned is
-- character-specific. When the weekly reset extends the cap, characters that
-- have not been logged in yet still hold last week's cap and would otherwise
-- incorrectly appear capped. Only move the saved cap forward: a zero or lower
-- value can be a temporarily unavailable API response, not a real reset.
function DataCollection.RefreshWarbandConquestCap(seasonKey, maximum)
    maximum = tonumber(maximum) or 0
    if maximum <= 0 then return false end

    local characters = Database.GetSeasonCharacters and Database.GetSeasonCharacters(seasonKey)
    if type(characters) ~= "table" then return false end

    local changed = false
    for _, character in pairs(characters) do
        local ratings = character and character.ratings
        local savedMaximum = tonumber(ratings and ratings.conquest_maxQuantity) or 0
        if type(ratings) == "table" and savedMaximum < maximum then
            ratings.conquest_maxQuantity = maximum
            changed = true
        end
    end
    return changed
end

function DataCollection.CollectCurrentCharacter(seasonKey)
    seasonKey = seasonKey or Season.GetContentSeasonKey()
    if not Database.IsValidSeasonKey(seasonKey) then return nil end

    local name, realm = GetCurrentCharacterIdentity()
    if seasonKey == Season.GetContentSeasonKey() and IsRatedSeasonInactive() then
        local characters = Database.GetSeasonCharacters and Database.GetSeasonCharacters(seasonKey)
        return characters and characters[Utils.CharKey(name, realm)] or nil
    end

    local _, classFilename, classID = UnitClass("player")

    local specID = GetCurrentSpecID()

    local level = UnitLevel("player")
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
    local isMaxLevel = level >= maxLevel
    local characterKey = Utils.CharKey(name, realm)
    local ratedStatsAreFresh = CanCollectRatedStats(characterKey, specID, isMaxLevel)

    -- Global ratings (not per-spec)
    local globalRatings = {}
    local globalPVPStats = {}
    for _, col in ipairs(Database.GetGlobalColumns(seasonKey)) do
        if col.bracketIndex then
            -- PvP bracket ratings are season-specific; zero out for sub-max-level characters
            local rating, stats = CollectPVPBracketInfo(
                col.bracketIndex,
                isMaxLevel,
                col.key,
                ratedStatsAreFresh,
                characterKey
            )
            globalRatings[col.key] = rating
            globalPVPStats[col.key] = stats
        elseif col.key == "mythicPlus" then
            local score = C_ChallengeMode
                and C_ChallengeMode.GetOverallDungeonScore
                and C_ChallengeMode.GetOverallDungeonScore()
            globalRatings[col.key] = score or 0
        elseif col.currencyID then
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(col.currencyID)
            globalRatings[col.key] = info and info.quantity or 0
            if col.key == "conquest" and info then
                globalRatings.conquest_totalEarned = tonumber(info.totalEarned) or 0
                globalRatings.conquest_maxQuantity = tonumber(info.maxQuantity) or 0
                globalRatings.conquest_quantityEarnedThisWeek = tonumber(info.quantityEarnedThisWeek) or 0
                globalRatings.conquest_maxWeeklyQuantity = tonumber(info.maxWeeklyQuantity) or 0
            end
        elseif col.crests then
            -- Collect each crest tier quantity; main value = highest tier with quantity > 0
            local highest = 0
            for i = #col.crests, 1, -1 do
                local crest = col.crests[i]
                local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(crest.currencyID)
                local qty = info and info.quantity or 0
                globalRatings[crest.key] = qty
                if highest == 0 and qty > 0 then
                    highest = qty
                end
            end
            globalRatings[col.key] = highest
        elseif col.statID then
            -- Stat from the Statistics panel (e.g. Honorable Kills = statID 588)
            local statStr = GetStatistic(col.statID)
            globalRatings[col.key] = (statStr and tonumber((statStr:gsub("%D", "")))) or 0
            -- Collect any detail breakdown stats defined on the column
            if col.details then
                for _, detail in ipairs(col.details) do
                    local ds = GetStatistic(detail.statID)
                    globalRatings[detail.key] = (ds and tonumber((ds:gsub("%D", "")))) or 0
                end
            end
        end
    end

    -- Per-spec ratings (Solo Shuffle, Solo BG) — zero out for sub-max-level characters
    -- GetPersonalRatedInfo() can keep returning the previous spec's solo ratings
    -- briefly after a spec swap, so spec-scoped brackets are gated by a fresh
    -- PVP_RATED_STATS_UPDATE for the active spec.
    local specRatings
    local specPVPStats
    if ratedStatsAreFresh then
        specRatings = {}
        specPVPStats = {}
        for _, col in ipairs(Database.SPEC_COLUMNS) do
            if col.bracketIndex then
                local rating, stats = CollectPVPBracketInfo(
                    col.bracketIndex,
                    isMaxLevel,
                    col.key,
                    true,
                    characterKey,
                    specID
                )
                specRatings[col.key] = rating
                specPVPStats[col.key] = stats
            end
        end
    end

    local data = {
        name = name,
        realm = realm,
        classFilename = classFilename,
        classID = classID,
        level = level,
        ratings = globalRatings,
        pvpStats = globalPVPStats,
        itemCounts = {
            [Database.HELIOTROPE_ITEM_ID] = GetCharacterHeliotropeCount(),
        },
        lastMMR = {},
        specRatings = specRatings and { [specID] = specRatings } or {},
        specPVPStats = specPVPStats and { [specID] = specPVPStats } or {},
        specLastMMR = specRatings and { [specID] = {} } or {},
        currentSpecID = specID,
        currentSpecRatings = specRatings,
        lastUpdated = time(),
    }

    if not Database.SaveCharacter(seasonKey, data) then return nil end
    DataCollection.RefreshWarbandConquestCap(seasonKey, globalRatings.conquest_maxQuantity)
    return data
end

-- During the short preseason window, the client is already using the upcoming
-- content season while GetPersonalRatedInfo() still exposes the completed
-- season. Import only those retained PvP values into the previous season. This
-- deliberately leaves currencies, Mythic+ score, HKs, items, and graph history
-- untouched because those APIs do not provide a trustworthy historical view.
function DataCollection.CollectPreseasonCharacter()
    if not IsRatedSeasonInactive() then return nil end
    if not Season.GetPreviousSeasonKey then return nil end

    local contentSeasonKey = Season.GetContentSeasonKey()
    local seasonKey = Season.GetPreviousSeasonKey(contentSeasonKey)
    if not Database.IsValidSeasonKey(seasonKey) then return nil end

    local name, realm = GetCurrentCharacterIdentity()
    local characterKey = Utils.CharKey(name, realm)
    local specID = GetCurrentSpecID()
    local level = UnitLevel("player")
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
    local isMaxLevel = level >= maxLevel
    if not CanCollectRatedStats(characterKey, specID, isMaxLevel) then return nil end

    local existing = Database.GetSeasonCharacters(seasonKey)[characterKey]
    local _, classFilename, classID = UnitClass("player")
    local ratings = CopyMap(existing and existing.ratings)
    local currentSpecRatings = CopyMap(
        existing
            and existing.specRatings
            and (existing.specRatings[specID] or existing.specRatings[tostring(specID)])
    )
    local pvpStats = {}
    local specPVPStats = {}
    local hasActivity = false

    for _, col in ipairs(Database.GetGlobalColumns(seasonKey)) do
        if col.bracketIndex then
            local apiRating, apiStats = CollectPVPBracketInfo(
                col.bracketIndex,
                isMaxLevel,
                col.key,
                true,
                characterKey
            )
            local storedStats = existing and existing.pvpStats and existing.pvpStats[col.key]
            local rating, stats = PreparePreseasonPVPStats(
                apiRating,
                apiStats,
                ratings[col.key],
                storedStats
            )
            ratings[col.key] = rating
            pvpStats[col.key] = stats
            hasActivity = HasSeasonPVPActivity(apiRating, apiStats) or hasActivity
        end
    end

    for _, col in ipairs(Database.SPEC_COLUMNS) do
        if col.bracketIndex then
            local apiRating, apiStats = CollectPVPBracketInfo(
                col.bracketIndex,
                isMaxLevel,
                col.key,
                true,
                characterKey,
                specID
            )
            local storedStats = existing
                and existing.specPVPStats
                and (existing.specPVPStats[specID] or existing.specPVPStats[tostring(specID)])
            storedStats = storedStats and storedStats[col.key]
            local rating, stats = PreparePreseasonPVPStats(
                apiRating,
                apiStats,
                currentSpecRatings[col.key],
                storedStats
            )
            currentSpecRatings[col.key] = rating
            specPVPStats[col.key] = stats
            hasActivity = HasSeasonPVPActivity(apiRating, apiStats) or hasActivity
        end
    end

    if not hasActivity then
        return existing, existing and seasonKey or nil
    end

    local data = {
        name = name,
        realm = realm,
        classFilename = classFilename,
        classID = classID,
        level = level,
        ratings = ratings,
        pvpStats = pvpStats,
        itemCounts = CopyMap(existing and existing.itemCounts),
        lastMMR = CopyMap(existing and existing.lastMMR),
        specRatings = { [specID] = currentSpecRatings },
        specPVPStats = { [specID] = specPVPStats },
        specLastMMR = {
            [specID] = CopyMap(
                existing
                    and existing.specLastMMR
                    and (existing.specLastMMR[specID] or existing.specLastMMR[tostring(specID)])
            ),
        },
        currentSpecID = specID,
        currentSpecRatings = currentSpecRatings,
        lastUpdated = time(),
    }

    if not Database.SaveCharacter(seasonKey, data) then return nil end

    local stored = Database.GetSeasonCharacters(seasonKey)[characterKey]
    if stored then stored.preseasonAPIBackfilledAt = time() end
    if History and History.ArchiveSeason then
        History.ArchiveSeason(seasonKey)
    end
    return stored or data, seasonKey
end

local function GetActiveBattlefieldID()
    local maxQueues = MAX_BATTLEFIELD_QUEUES or 8
    for i = 1, maxQueues do
        local status = GetBattlefieldStatus(i)
        if status == "active" then
            return i
        end
    end
    return nil
end

local function GetActiveArenaTeamSize()
    local battlefieldID = GetActiveBattlefieldID()
    if not battlefieldID then return nil end

    local _, _, teamSize = GetBattlefieldStatus(battlefieldID)
    return tonumber(teamSize)
end

local function GetArenaBracketIndexFromScoreboard()
    if not GetNumBattlefieldScores then return nil end

    local numScores = tonumber(GetNumBattlefieldScores())
    if not numScores or numScores <= 0 then return nil end

    local teamSize = numScores / 2
    if teamSize == 2 then
        return 1
    elseif teamSize == 3 then
        return 2
    elseif teamSize == 5 then
        return 3
    end

    return nil
end

local function GetActiveRatedBracketIndex()
    if not C_PvP then return nil end

    local isSoloShuffle = C_PvP.IsRatedSoloShuffle and C_PvP.IsRatedSoloShuffle()
    local isSoloRBG = C_PvP.IsSoloRBG and C_PvP.IsSoloRBG()
    local isRatedBattleground = C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground()
    local isRatedArena = C_PvP.IsRatedArena and C_PvP.IsRatedArena()
    if isRatedArena and IsArenaSkirmish and IsArenaSkirmish() then
        isRatedArena = false
    end
    if not isSoloShuffle and not isSoloRBG and not isRatedBattleground and not isRatedArena then
        return nil
    end

    if C_PvP.GetActiveMatchBracket then
        local ok, activeBracketIndex = pcall(C_PvP.GetActiveMatchBracket)
        activeBracketIndex = ok
            and ACTIVE_MATCH_BRACKET_TO_DATABASE_INDEX[tonumber(activeBracketIndex)]
        if activeBracketIndex and Database.GetPVPColumnByBracketIndex(activeBracketIndex) then
            return activeBracketIndex
        end
    end

    if isSoloShuffle then
        return 7
    end

    if isSoloRBG then
        return 9
    end

    if isRatedBattleground then
        return 4
    end

    if isRatedArena then
        local teamSize = GetActiveArenaTeamSize()
        if teamSize == 2 then
            return 1
        elseif teamSize == 3 then
            return 2
        end

        return GetArenaBracketIndexFromScoreboard()
    end

    return nil
end

local function RememberRatedBracketIndex(bracketIndex)
    bracketIndex = tonumber(bracketIndex)
    if not bracketIndex or bracketIndex <= 0 then return end
    lastKnownRatedBracketIndex = bracketIndex
    lastKnownRatedBracketTime = time()
end

local function GetRememberedRatedBracketIndex()
    if not lastKnownRatedBracketIndex or not lastKnownRatedBracketTime then
        return nil
    end

    if (time() - lastKnownRatedBracketTime) > 600 then
        return nil
    end

    return lastKnownRatedBracketIndex
end

function DataCollection.UpdateActivePVPContext()
    RememberRatedBracketIndex(GetActiveRatedBracketIndex())
end

local function GetPlayerScoreInfo()
    if not C_PvP then return nil end

    if C_PvP.GetScoreInfoByPlayerGuid and UnitGUID then
        local ok, info = pcall(C_PvP.GetScoreInfoByPlayerGuid, UnitGUID("player"))
        if ok and type(info) == "table" then
            return info
        end
    end

    if not C_PvP.GetScoreInfo or not GetNumBattlefieldScores then return nil end

    local playerName = UnitName("player")
    local numScores = GetNumBattlefieldScores()
    for i = 1, numScores do
        local info = C_PvP.GetScoreInfo(i)
        local scoreName = info and info.name
        if scoreName and (scoreName == playerName or scoreName:sub(1, #playerName + 1) == playerName .. "-") then
            return info
        end
    end

    return nil
end

local function GetActiveMatchPersonalRatedInfo()
    if not C_PvP or not C_PvP.GetPVPActiveMatchPersonalRatedInfo then
        return nil
    end

    local ok, info = pcall(C_PvP.GetPVPActiveMatchPersonalRatedInfo)
    if ok and type(info) == "table" then
        return info
    end

    return nil
end

local function GetSafeNumber(value)
    local ok, result = pcall(function()
        local number = tonumber(value)
        if not number then return nil end
        return number + 0
    end)
    if ok then
        return result
    end
    return nil
end

local function GetPositiveNumber(value)
    local number = GetSafeNumber(value)
    if not number then return nil end

    local ok, positive = pcall(function()
        return number > 0
    end)
    if ok and positive then
        return number
    end
    return nil
end

local function AddSafeNumbers(left, right)
    local ok, result = pcall(function()
        return left + right
    end)
    if ok then
        return result
    end
    return nil
end

local function GetBattlefieldTeamMMR(teamIndex)
    if not GetBattlefieldTeamInfo then
        return nil
    end

    local ok, _, _, _, mmr = pcall(GetBattlefieldTeamInfo, teamIndex)
    if not ok then
        return nil
    end

    return GetPositiveNumber(mmr)
end

local function IsTeamMMRBracket(bracketIndex)
    return bracketIndex == 1 or bracketIndex == 2 or bracketIndex == 4
end

local function GetPlayerTeamMMR(info)
    local faction = GetSafeNumber(type(info) == "table" and info.faction)
    if faction ~= 0 and faction ~= 1 then return nil end

    return GetBattlefieldTeamMMR(faction)
end

local function GetMMRFromInfo(info)
    if type(info) ~= "table" then return nil, nil end

    local postMatchMMR = GetPositiveNumber(info.postmatchMMR or info.postMatchMMR)
    local prematchMMR = GetPositiveNumber(info.prematchMMR or info.preMatchMMR or info.matchMakingRating)
    local mmrChange = GetSafeNumber(info.mmrChange or info.matchMakingRatingChange)
    if not postMatchMMR and prematchMMR and mmrChange then
        local adjustedMMR = GetPositiveNumber(AddSafeNumbers(prematchMMR, mmrChange))
        if adjustedMMR then
            postMatchMMR = adjustedMMR
        end
    end

    return prematchMMR, postMatchMMR
end

local function GetAvailableMMR(scoreInfo, bracketIndex)
    -- Arena score records expose zero personal MMR for 2v2 and 3v3. Their
    -- visible MMR is the player's team's MMR. Never probe arbitrary teams:
    -- after a fast exit that can select the opponent's value instead.
    if IsTeamMMRBracket(bracketIndex) then
        return GetPlayerTeamMMR(scoreInfo), nil, nil
    end

    local prematchMMR, postMatchMMR = GetMMRFromInfo(scoreInfo)
    local enrichmentMMR = prematchMMR
    if not prematchMMR or not postMatchMMR then
        local activePrematchMMR, activePostMatchMMR = GetMMRFromInfo(GetActiveMatchPersonalRatedInfo())
        prematchMMR = prematchMMR or activePrematchMMR
        postMatchMMR = postMatchMMR or activePostMatchMMR
        enrichmentMMR = enrichmentMMR or activePrematchMMR
    end
    return prematchMMR, postMatchMMR, enrichmentMMR
end

local function GetMatchResult(scoreInfo, eventWinner)
    local winner = tonumber(eventWinner)
    if winner == nil then
        if not GetBattlefieldWinner then return nil end
        winner = GetBattlefieldWinner()
    end
    winner = tonumber(winner)
    if winner ~= 0 and winner ~= 1 then return nil end

    if type(scoreInfo) == "table" and scoreInfo.faction ~= nil then
        local faction = tonumber(scoreInfo.faction)
        if faction ~= nil then
            return faction == tonumber(winner) and 1 or 0
        end
    end

    if GetBattlefieldArenaFaction then
        local faction = GetBattlefieldArenaFaction()
        if faction ~= nil then
            return tonumber(faction) == tonumber(winner) and 1 or 0
        end
    end

    return nil
end

local function GetCollectedRating(data, col, specID)
    if Database.IsSpecColumn(col) then
        local specRatings = data.specRatings and data.specRatings[specID]
        return specRatings and specRatings[col.key] or 0
    end

    return data.ratings and data.ratings[col.key] or 0
end

local function GetCollectedStats(data, col, specID)
    if Database.IsSpecColumn(col) then
        local specStats = data.specPVPStats and data.specPVPStats[specID]
        return specStats and specStats[col.key]
    end

    return data.pvpStats and data.pvpStats[col.key]
end

local function GetRatedSnapshot(bracketIndex)
    if not GetPersonalRatedInfo then return nil end

    local rating, _, _, seasonPlayed, _, _, _, _, _, _, _, roundsSeasonPlayed =
        GetPersonalRatedInfo(bracketIndex)
    return {
        rating = GetSafeNumber(rating) or 0,
        seasonPlayed = GetSafeNumber(seasonPlayed) or 0,
        roundsSeasonPlayed = GetSafeNumber(roundsSeasonPlayed) or 0,
    }
end

local function GetMatchSequence(stats)
    local seasonPlayed = GetSafeNumber(stats and stats.seasonPlayed)
    if seasonPlayed and seasonPlayed > 0 then
        return math.floor(seasonPlayed)
    end
    return nil
end

local function MatchesActiveContext(context, name, realm, specID, bracketIndex)
    return context
        and context.name == name
        and context.realm == realm
        and context.specID == specID
        and context.bracketIndex == bracketIndex
end

function DataCollection.BeginRatedMatch(forceNew)
    if IsRatedSeasonInactive() then
        activeRatedMatch = nil
        if History then History.RecordDiagnostic("matchStartInactiveSeason") end
        return false
    end

    local name, realm = GetCurrentCharacterIdentity()
    local specID = GetCurrentSpecID()
    local seasonKey = Season.GetContentSeasonKey()
    local bracketIndex = GetActiveRatedBracketIndex() or GetRememberedRatedBracketIndex()
    if not bracketIndex then
        if History then History.RecordDiagnostic("matchStartNoBracket") end
        return false
    end
    RememberRatedBracketIndex(bracketIndex)

    if not forceNew
        and MatchesActiveContext(activeRatedMatch, name, realm, specID, bracketIndex)
        and activeRatedMatch.seasonKey == seasonKey
        and not activeRatedMatch.finalized
    then
        return true
    end

    local snapshot = GetRatedSnapshot(bracketIndex) or {}
    activeRatedMatch = {
        seasonKey = seasonKey,
        name = name,
        realm = realm,
        specID = specID,
        bracketIndex = bracketIndex,
        startedAt = time(),
        preRating = tonumber(snapshot.rating) or 0,
        preSeasonPlayed = tonumber(snapshot.seasonPlayed) or 0,
        preRoundsSeasonPlayed = tonumber(snapshot.roundsSeasonPlayed) or 0,
    }
    if History then History.RecordDiagnostic("matchStarted") end
    return true
end

function DataCollection.CaptureActiveMatchMMR()
    if IsRatedSeasonInactive() then
        activeRatedMatch = nil
        return false
    end
    if not activeRatedMatch then return false end

    local context = activeRatedMatch
    local scoreInfo = GetPlayerScoreInfo()
    local prematchMMR, postMatchMMR, enrichmentMMR = GetAvailableMMR(scoreInfo, context.bracketIndex)
    if prematchMMR and not context.preMMR then
        context.preMMR = prematchMMR
    end
    if enrichmentMMR then
        context.enrichmentMMR = enrichmentMMR
        if History then
            History.EnrichPendingMMR(
                context.seasonKey,
                context.name,
                context.realm,
                context.specID,
                context.bracketIndex,
                enrichmentMMR,
                context.preSeasonPlayed
            )
        end
    end
    if postMatchMMR then
        context.postMMR = postMatchMMR
    end

    local currentMMR = postMatchMMR or prematchMMR
    if currentMMR then
        local isFinalMMRSample = context.completedAt or context.inactiveAt
        if isFinalMMRSample then
            -- Blizzard does not consistently label the final value as
            -- postmatchMMR. The value read after this match ends is still a
            -- valid post-match sample because preMMR was fixed at match start.
            context.postMMR = currentMMR
        end
        local mmrDelta
        local verifiedPostMMR = context.postMMR
        if isFinalMMRSample and context.preMMR and verifiedPostMMR
                and verifiedPostMMR ~= context.preMMR then
            mmrDelta = verifiedPostMMR - context.preMMR
        end
        Database.SaveLastMMR(
            context.seasonKey,
            context.name,
            context.realm,
            context.specID,
            context.bracketIndex,
            currentMMR,
            mmrDelta
        )
        return true
    end
    return false
end

function DataCollection.MarkRatedMatchComplete(winner, duration)
    if not activeRatedMatch then
        DataCollection.BeginRatedMatch()
    end
    if not activeRatedMatch then return false end

    activeRatedMatch.completedAt = time()
    activeRatedMatch.eventWinner = GetSafeNumber(winner)
    activeRatedMatch.duration = GetSafeNumber(duration)
    DataCollection.CaptureActiveMatchMMR()
    return true
end

function DataCollection.MarkRatedMatchInactive()
    if not activeRatedMatch then
        DataCollection.RequestRatedInfo(GetCurrentSpecID())
        return false
    end

    activeRatedMatch.inactiveAt = time()
    DataCollection.CaptureActiveMatchMMR()
    DataCollection.RequestRatedInfo(activeRatedMatch.specID)
    return true
end

local function GetResultFromContext(context, scoreInfo, bracketIndex)
    if bracketIndex == 7 then
        -- PVP_MATCH_COMPLETE is round-scoped in Solo Shuffle. A binary
        -- lobby result cannot be inferred reliably from one round winner
        -- or from rating direction (a 3-3 lobby can still change rating).
        return nil
    end

    return GetMatchResult(scoreInfo, context and context.eventWinner)
end

local function HasFreshMatch(context, matchSequence)
    if not context or not matchSequence then return false end

    local preSeasonPlayed = tonumber(context.preSeasonPlayed)
    if not preSeasonPlayed then return false end
    return matchSequence > preSeasonPlayed
end

local function FinalizeRatedMatch(recordHistory)
    if IsRatedSeasonInactive() then
        activeRatedMatch = nil
        if History then History.RecordDiagnostic("finalizeInactiveSeason") end
        return false
    end

    if not WarbandRatingsDB or not WarbandRatingsDB.seasons then
        return false
    end

    local name, realm = GetCurrentCharacterIdentity()
    local specID = GetCurrentSpecID()
    local context = activeRatedMatch
    if not context then
        if History then History.RecordDiagnostic("finalizeNoTrackedMatch") end
        return false
    end
    local bracketIndex = context.bracketIndex

    if not MatchesActiveContext(context, name, realm, specID, bracketIndex) then
        if History then History.RecordDiagnostic("finalizeContextMismatch") end
        return false
    end

    local scoreInfo = GetPlayerScoreInfo()
    local prematchMMR, postMatchMMR, enrichmentMMR = GetAvailableMMR(scoreInfo, bracketIndex)
    prematchMMR = prematchMMR or (context and context.preMMR)
    postMatchMMR = postMatchMMR or (context and context.postMMR)
    enrichmentMMR = enrichmentMMR or (context and context.enrichmentMMR)

    local col = Database.GetPVPColumnByBracketIndex(bracketIndex)
    if not col then
        if History then History.RecordDiagnostic("finalizeUnknownBracket") end
        return false
    end

    local seasonKey = context.seasonKey
    if not Database.IsValidSeasonKey(seasonKey) then
        if History then History.RecordDiagnostic("finalizeMissingSeason") end
        return false
    end

    local data = DataCollection.CollectCurrentCharacter(seasonKey)
    if not data then return false end
    local stats = GetCollectedStats(data, col, specID)
    local matchSequence = GetMatchSequence(stats)
    local rating = tonumber(GetCollectedRating(data, col, specID))
    local hasCurrentSpecRating = not Database.IsSpecColumn(col) or data.currentSpecRatings

    if enrichmentMMR and History then
        History.EnrichPendingMMR(
            seasonKey,
            name,
            realm,
            specID,
            bracketIndex,
            enrichmentMMR,
            context.preSeasonPlayed
        )
    end

    local currentMMR = postMatchMMR or prematchMMR
    local verifiedPostMMR = context.postMMR or postMatchMMR
    local mmrDelta = (context.completedAt or context.inactiveAt)
        and context.preMMR
        and verifiedPostMMR
        and verifiedPostMMR ~= context.preMMR
        and (verifiedPostMMR - context.preMMR)
    local savedMMR = currentMMR
        and Database.SaveLastMMR(seasonKey, name, realm, specID, bracketIndex, currentMMR, mmrDelta)
        or false

    if not recordHistory then
        return savedMMR
    end
    if not hasCurrentSpecRating or rating == nil or rating < 0 then
        if History then History.RecordDiagnostic("finalizeNoFreshRating") end
        return savedMMR
    end
    if not HasFreshMatch(context, matchSequence) then
        if History then History.RecordDiagnostic("finalizeStatsNotAdvanced") end
        return savedMMR
    end

    local result = GetResultFromContext(context, scoreInfo, bracketIndex)
    local recorded = History and History.RecordMatch(
        seasonKey,
        name,
        realm,
        specID,
        bracketIndex,
        rating,
        postMatchMMR,
        result,
        time(),
        postMatchMMR ~= nil,
        matchSequence,
        postMatchMMR and "postmatch" or "pending"
    )
    if recorded then
        if not postMatchMMR and History then
            History.RecordDiagnostic("ratingRecordedWithoutMMR")
        elseif History then
            History.RecordDiagnostic("ratingRecordedWithMMR")
        end
        if activeRatedMatch == context then
            activeRatedMatch.finalized = true
            activeRatedMatch = nil
        end
    end
    return recorded or savedMMR
end

function DataCollection.CollectLastMatchMMR(recordHistory)
    if not recordHistory then
        return DataCollection.CaptureActiveMatchMMR()
    end
    return FinalizeRatedMatch(true)
end
