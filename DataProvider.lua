local _, ns = ...
ns.DataProvider = {}
local DataProvider = ns.DataProvider
local Database = ns.Database
local History = ns.History
local Utils = ns.Utils

-- Local screenshot/testing switch. Keep false for normal addon behavior.
DataProvider.USE_FAKE_DATA = false

local FAKE_REALM = "ArgentDawn"
local FAKE_HISTORY_POINT_COUNT = 720
local fakeCharacters
local fakeHistorySeries = {}

local FAKE_ROSTER = {
    {
        "Aeloria", "PALADIN", 2, { 65 }, 1,
        { arena3v3 = true, mythicPlus = true, solo = { [65] = { soloShuffle = true } } },
    },
    {
        "Brannick", "WARRIOR", 1, { 71, 72 }, 2,
        {
            arena2v2 = true,
            arena3v3 = true,
            solo = {
                [71] = { soloShuffle = true },
                [72] = { soloBG = true },
            },
        },
    },
    {
        "Duskveil", "ROGUE", 4, { 259 }, 3,
        { rbg10v10 = true, solo = { [259] = { soloBG = true } } },
    },
    {
        "Hearthspark", "MAGE", 8, { 63 }, 4,
        { arena2v2 = true, mythicPlus = true },
    },
    {
        "Myrrakai", "EVOKER", 13, { 1467, 1473 }, 5,
        { rbg10v10 = true, mythicPlus = true },
    },
}

local function Mod(value, divisor)
    return value - math.floor(value / divisor) * divisor
end

local function BuildSeed(text, specID)
    local seed = tonumber(specID) or 0
    for i = 1, #text do
        seed = Mod(seed * 33 + text:byte(i), 100000)
    end
    return seed
end

local function GetFakeMaxLevel()
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
    return tonumber(maxLevel) or 80
end

local function ShouldDropRating(index, salt, missingChance)
    if not missingChance or missingChance <= 0 then
        return false
    end
    return Mod(index * 29 + salt * 17, 100) < missingChance
end

local function MakeRating(index, base, span, missingChance, salt)
    if ShouldDropRating(index, salt or 1, missingChance) then
        return 0
    end
    return base + Mod(index * 137, span)
end

local function MakeParticipatingRating(enabled, index, base, span, salt)
    if not enabled then
        return 0
    end
    return MakeRating(index, base, span, 0, salt)
end

local function MakeOptionalRating(enabled, index, base, span, missingChance, salt)
    if enabled == false then
        return 0
    end
    return MakeRating(index, base, span, enabled == true and 0 or missingChance, salt)
end

local function MakeFakeCharacter(entry)
    local name, classFilename, classID, specs, index = entry[1], entry[2], entry[3], entry[4], entry[5]
    local profile = entry[6] or {}
    local maxLevel = GetFakeMaxLevel()
    local level = Mod(index, 11) == 0 and math.max(1, maxLevel - 8) or maxLevel
    local arena2v2 = MakeParticipatingRating(profile.arena2v2, index, 980, 980, 1)
    local arena3v3 = MakeParticipatingRating(profile.arena3v3, index + 2, 1120, 1180, 2)
    local rbg10v10 = MakeParticipatingRating(profile.rbg10v10, index + 4, 900, 1050, 3)
    local mythicPlus = MakeOptionalRating(profile.mythicPlus, index + 7, 1250, 2150, 20, 4)
    local honor = 2500 + Mod(index * 977, 12500)
    local hk = 750 + index * 529
    local crestAdventurer = Mod(index * 3, 31)
    local crestVeteran = Mod(index * 5, 42)
    local crestChampion = Mod(index * 7, 38)
    local crestHero = Mod(index * 11, 30)
    local crestMyth = Mod(index * 13, 24)
    local crestHighest = crestMyth > 0 and crestMyth
        or crestHero > 0 and crestHero
        or crestChampion > 0 and crestChampion
        or crestVeteran > 0 and crestVeteran
        or crestAdventurer

    local specRatings = {}
    local specLastMMR = {}
    for specIndex, specID in ipairs(specs) do
        local specProfile = profile.solo and profile.solo[specID] or {}
        local soloShuffle = MakeParticipatingRating(
            specProfile.soloShuffle,
            index + specIndex * 3,
            1180,
            1180,
            10 + specIndex
        )
        local soloBG = MakeParticipatingRating(
            specProfile.soloBG,
            index + specIndex * 5,
            1050,
            1120,
            20 + specIndex
        )
        specRatings[specID] = {
            soloShuffle = soloShuffle,
            soloBG = soloBG,
        }
        specLastMMR[specID] = {
            soloShuffle = soloShuffle > 0 and soloShuffle + 37 + Mod(index * specIndex, 90) or 0,
            soloBG = soloBG > 0 and soloBG + 28 + Mod(index * specIndex * 2, 95) or 0,
        }
    end

    local bestPvpRating = math.max(arena2v2, arena3v3, rbg10v10)
    local activePvpBrackets = 0
    if arena2v2 > 0 then activePvpBrackets = activePvpBrackets + 1 end
    if arena3v3 > 0 then activePvpBrackets = activePvpBrackets + 1 end
    if rbg10v10 > 0 then activePvpBrackets = activePvpBrackets + 1 end
    for _, sr in pairs(specRatings) do
        if (sr.soloShuffle or 0) > 0 then
            bestPvpRating = math.max(bestPvpRating, sr.soloShuffle)
            activePvpBrackets = activePvpBrackets + 1
        end
        if (sr.soloBG or 0) > 0 then
            bestPvpRating = math.max(bestPvpRating, sr.soloBG)
            activePvpBrackets = activePvpBrackets + 1
        end
    end

    local conquest = 0
    if bestPvpRating > 0 then
        local activityBase = 550 + activePvpBrackets * 360
        local ratingBonus = math.max(0, bestPvpRating - 1000) * 1.35
        conquest = math.floor(math.min(6500, activityBase + ratingBonus + Mod(index * 431, 650)))
    end

    return {
        name = name,
        realm = FAKE_REALM,
        classFilename = classFilename,
        classID = classID,
        level = level,
        ratings = {
            arena2v2 = arena2v2,
            arena3v3 = arena3v3,
            rbg10v10 = rbg10v10,
            honor = honor,
            conquest = conquest,
            hk = hk,
            hk_world = math.floor(hk * 0.42),
            hk_arena = math.floor(hk * 0.19),
            hk_bg = math.floor(hk * 0.39),
            mythicPlus = mythicPlus,
            crest_adventurer = crestAdventurer,
            crest_veteran = crestVeteran,
            crest_champion = crestChampion,
            crest_hero = crestHero,
            crest_myth = crestMyth,
            crests = crestHighest,
        },
        lastMMR = {
            arena2v2 = arena2v2 > 0 and arena2v2 + 31 + Mod(index * 7, 80) or 0,
            arena3v3 = arena3v3 > 0 and arena3v3 + 45 + Mod(index * 9, 85) or 0,
            rbg10v10 = rbg10v10 > 0 and rbg10v10 + 24 + Mod(index * 11, 95) or 0,
        },
        specRatings = specRatings,
        specLastMMR = specLastMMR,
        currentSpecID = specs[1],
        lastUpdated = time(),
    }
end

local function GetFakeCharacters()
    if fakeCharacters then return fakeCharacters end

    fakeCharacters = {}
    for _, entry in ipairs(FAKE_ROSTER) do
        local character = MakeFakeCharacter(entry)
        fakeCharacters[Utils.CharKey(character.name, character.realm)] = character
    end
    return fakeCharacters
end

local function GetFakeRating(character, colKey, specID)
    specID = tonumber(specID) or 0
    if specID ~= 0 and character.specRatings and character.specRatings[specID] then
        return tonumber(character.specRatings[specID][colKey]) or 0
    end
    return tonumber(character.ratings and character.ratings[colKey]) or 0
end

local function GetFakeMMR(character, colKey, specID)
    specID = tonumber(specID) or 0
    if specID ~= 0 and character.specLastMMR and character.specLastMMR[specID] then
        return tonumber(character.specLastMMR[specID][colKey]) or 0
    end
    return tonumber(character.lastMMR and character.lastMMR[colKey]) or 0
end

local function ShiftHistoryToCurrent(points, currentRating, currentMMR)
    local lastPoint = points[#points]
    if not lastPoint then return end

    local ratingOffset = currentRating - (tonumber(lastPoint[2]) or 0)
    local mmrOffset = currentMMR - (tonumber(lastPoint[3]) or 0)
    local ratingFloor = math.max(500, currentRating - 1300)
    local mmrFloor = math.max(500, currentMMR - 1300)

    for i, point in ipairs(points) do
        point[2] = math.max(ratingFloor, (tonumber(point[2]) or 0) + ratingOffset)
        point[3] = math.max(mmrFloor, (tonumber(point[3]) or 0) + mmrOffset)
        point[7] = true
        local previous = points[i - 1]
        point[4] = previous and (point[2] - previous[2]) or 0
        point[5] = previous and (point[3] - previous[3]) or 0
    end
end

local function GetFakeNoise(seed, index, range)
    return Mod(seed + index * 37, range * 2 + 1) - range
end

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function Round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function GetHistoryArcOffset(seed, progress)
    local profile = Mod(seed, 6)
    local magnitude = 680 + Mod(seed, 420)

    if profile == 0 then
        -- Breakout season: starts far below the current rating and climbs.
        return -magnitude * (1 - progress)
    elseif profile == 1 then
        -- Collapse season: starts far above the current rating and bleeds down.
        return magnitude * (1 - progress)
    elseif profile == 2 then
        -- Mid-season slump followed by a recovery.
        return -260 * (1 - progress) - magnitude * 0.62 * math.sin(math.pi * progress)
    elseif profile == 3 then
        -- Early peak, then a painful slide back to the current rating.
        return 240 * (1 - progress) + magnitude * 0.68 * math.sin(math.pi * progress)
    elseif profile == 4 then
        -- Strong progression with visible plateaus and corrections.
        return -magnitude * 0.78 * (1 - progress)
            + math.sin(progress * math.pi * 5 + seed * 0.01) * 190 * (1 - progress * 0.25)
    end

    -- Choppy season with no single clean trend.
    return math.sin(progress * math.pi * 4 + seed * 0.03) * magnitude * 0.35 * (1 - progress * 0.35)
end

local function BuildFakeHistorySeries(charKey, colKey, specID)
    local character = GetFakeCharacters()[charKey]
    if not character then
        return { points = {}, archived = false }
    end

    local seed = BuildSeed(charKey .. ":" .. colKey, specID)
    local currentRating = GetFakeRating(character, colKey, specID)
    if currentRating <= 0 then
        return { points = {}, archived = false }
    end

    local currentMMR = GetFakeMMR(character, colKey, specID)
    if currentMMR <= 0 then
        currentMMR = currentRating + 60 + Mod(seed, 90)
    end

    local now = time()
    local rating = math.max(750, currentRating + GetHistoryArcOffset(seed, 0) + GetFakeNoise(seed, 1, 80))
    local mmr = math.max(750, rating + Mod(seed, 320) - 160)
    local points = {}

    for i = 1, FAKE_HISTORY_POINT_COUNT do
        local progress = (i - 1) / (FAKE_HISTORY_POINT_COUNT - 1)
        local performance =
            math.sin((i + seed) * 0.041) * 0.72
            + math.sin((i + seed) * 0.013) * 0.46
            + math.sin((i + seed) * 0.117) * 0.18
        local targetRating = currentRating + GetHistoryArcOffset(seed, progress) + performance * 90
        local desiredMMR = targetRating + performance * 175 + GetFakeNoise(seed, i, 28)
        local winRoll = Mod(seed + i * 61, 1000) / 1000
        local winChance = Clamp(0.50 + performance * 0.13 + Clamp((desiredMMR - rating) / 1200, -0.08, 0.08), 0.22, 0.78)
        local won = winRoll < winChance
        local ratingPressure = Clamp((mmr - rating) / 42, -9, 9)
        local targetPressure = Clamp((targetRating - rating) / 58, -16, 16)
        local ratingDelta

        if won then
            ratingDelta = 8 + math.max(0, ratingPressure) + math.max(0, targetPressure * 0.40) + Mod(seed + i * 5, 5)
        else
            ratingDelta = -(7 + math.max(0, -ratingPressure) + math.max(0, -targetPressure * 0.40) + Mod(seed + i * 7, 5))
        end
        ratingDelta = ratingDelta + targetPressure * 0.58

        if Mod(i + seed, 43) == 0 then
            ratingDelta = math.floor(ratingDelta * 1.6)
        elseif Mod(i + seed, 29) == 0 then
            ratingDelta = math.floor(ratingDelta / 2)
        end

        rating = math.max(650, rating + Round(ratingDelta))
        mmr = math.max(650, mmr + (desiredMMR - mmr) * 0.22 + (won and 8 or -8) + GetFakeNoise(seed, i, 8))

        local previous = points[#points]
        points[#points + 1] = {
            now - (FAKE_HISTORY_POINT_COUNT - i) * 10800,
            rating,
            mmr,
            previous and (rating - previous[2]) or 0,
            previous and (mmr - previous[3]) or 0,
            won and 1 or 0,
            true,
        }
    end

    ShiftHistoryToCurrent(points, currentRating, currentMMR)
    return {
        points = points,
        archived = false,
    }
end

local function GetFakeHistorySeries(charKey, colKey, specID)
    local key = charKey .. ":" .. tostring(specID or 0) .. ":" .. colKey
    if not fakeHistorySeries[key] then
        fakeHistorySeries[key] = BuildFakeHistorySeries(charKey, colKey, specID)
    end
    return fakeHistorySeries[key]
end

function DataProvider.IsFakeDataEnabled()
    return DataProvider.USE_FAKE_DATA
end

function DataProvider.GetTableData()
    local groups
    if DataProvider.USE_FAKE_DATA then
        groups = Database.BuildCharacterGroups(GetFakeCharacters())
    else
        groups = Database.GetFilteredCharacterGroups()
    end
    return groups, Database.GetVisibleColumns(groups), not Database.GetSettings().hideMMR
end

function DataProvider.GetHistorySeries(charKey, colKey, specID)
    if DataProvider.USE_FAKE_DATA then
        return GetFakeHistorySeries(charKey, colKey, specID)
    end
    return History and History.GetCurrentSeries(charKey, colKey, specID)
end
