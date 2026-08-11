local _, ns = ...

-- luacheck: globals GetBuildInfo GetCurrentArenaSeason C_PvP C_SeasonInfo

ns.Season = {}
local Season = ns.Season

local UNKNOWN_SEASON_KEY = "unknown"
local LEGACY_EXPANSION_KEY = "legacy"

local EXPANSIONS = {
    {
        key = "midnight",
        name = "Midnight",
        icon = "Interface\\AddOns\\WarbandRatings\\media\\midnight-logo.png",
        order = 10,
        seasons = {
            {
                key = "pvp-41",
                number = 1,
                globalID = 41,
                crests = {
                    { label = "Adventurer Dawncrest", key = "crest_adventurer", currencyID = 3383 },
                    { label = "Veteran Dawncrest", key = "crest_veteran", currencyID = 3341 },
                    { label = "Champion Dawncrest", key = "crest_champion", currencyID = 3343 },
                    { label = "Hero Dawncrest", key = "crest_hero", currencyID = 3345 },
                    { label = "Myth Dawncrest", key = "crest_myth", currencyID = 3347 },
                },
                features = {
                    conquestEquipmentChest = {
                        active = true,
                        itemID = 256553,
                        name = "Galactic Equipment Chest",
                        pluralName = "Galactic Equipment Chests",
                        fallbackCost = 375,
                        hasOpeningCast = true,
                        requiredPVPRating = 1400,
                    },
                },
            },
            {
                key = "pvp-42",
                number = 2,
                globalID = 42,
                crests = {
                    { label = "Adventurer Mistcrest", key = "crest_adventurer", currencyID = 3442 },
                    { label = "Veteran Mistcrest", key = "crest_veteran", currencyID = 3443 },
                    { label = "Champion Mistcrest", key = "crest_champion", currencyID = 3444 },
                    { label = "Hero Mistcrest", key = "crest_hero", currencyID = 3445 },
                    { label = "Myth Mistcrest", key = "crest_myth", currencyID = 3446 },
                },
                features = {
                    conquestEquipmentChest = {
                        expectedName = "Venomous Equipment Chest",
                        nameSuffix = " Equipment Chest",
                        fallbackCost = 375,
                        hasOpeningCast = true,
                        discoverAtVendor = true,
                    },
                },
            },
        },
    },
}

local expansionByKey = {}
local seasonByKey = {}

for _, expansion in ipairs(EXPANSIONS) do
    expansionByKey[expansion.key] = expansion
    for _, season in ipairs(expansion.seasons) do
        season.expansionKey = expansion.key
        season.expansionName = expansion.name
        season.label = "Season " .. season.number
        season.features = season.features or {}
        seasonByKey[season.key] = season
    end
end

local function CopyArray(source)
    local result = {}
    for i, value in ipairs(source or {}) do
        result[i] = value
    end
    return result
end

local function GetInterfaceVersion()
    if GetBuildInfo then
        local interfaceVersion = select(4, GetBuildInfo())
        return tonumber(interfaceVersion) or 0
    end
    return 0
end

local function GetDetectedSeasonID()
    local value
    if GetCurrentArenaSeason then
        value = tonumber(GetCurrentArenaSeason())
    end
    if (not value or value <= 0) and C_PvP and C_PvP.GetUIDisplaySeason then
        value = tonumber(C_PvP.GetUIDisplaySeason())
    end
    if (not value or value <= 0) and C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID then
        value = tonumber(C_SeasonInfo.GetCurrentDisplaySeasonID())
    end
    return value and value > 0 and value or nil
end

function Season.IsRatedSeasonActive()
    if not GetCurrentArenaSeason then return nil end

    local ok, seasonID = pcall(function()
        return tonumber(GetCurrentArenaSeason())
    end)
    if not ok then return nil end
    if seasonID == nil then return nil end
    return seasonID > 0
end

function Season.GetContentSeasonKey()
    local interfaceVersion = GetInterfaceVersion()
    local mappedSeasonID

    -- Patch 12.1 starts the Season 2 content model even during the short
    -- preseason window where the rated-PvP API can still report Season 1.
    if interfaceVersion >= 120100 then
        mappedSeasonID = 42
    elseif interfaceVersion >= 120000 then
        mappedSeasonID = 41
    end

    -- Unknown future seasons remain selectable and owned rather than leaking into
    -- the latest catalog entry. Their seasonal features stay disabled until their
    -- metadata is deliberately added above.
    local detectedSeasonID = GetDetectedSeasonID()
    if detectedSeasonID and (not mappedSeasonID or detectedSeasonID > mappedSeasonID) then
        return "pvp-" .. detectedSeasonID
    end
    if mappedSeasonID then
        return "pvp-" .. mappedSeasonID
    end
    return UNKNOWN_SEASON_KEY
end

function Season.GetSeasonInfo(seasonKey)
    local known = seasonByKey[seasonKey]
    if known then return known end

    local globalID = tonumber((seasonKey or ""):match("^pvp%-(%d+)$"))
    return {
        key = seasonKey or UNKNOWN_SEASON_KEY,
        number = globalID or 0,
        globalID = globalID,
        expansionKey = LEGACY_EXPANSION_KEY,
        expansionName = "Legacy",
        label = globalID and ("PvP Season " .. globalID) or "Unknown Season",
        features = {},
        crests = {},
        isLegacy = true,
    }
end

function Season.GetExpansionInfo(expansionKey)
    if expansionKey == LEGACY_EXPANSION_KEY then
        return { key = LEGACY_EXPANSION_KEY, name = "Legacy", order = 0, seasons = {} }
    end
    return expansionByKey[expansionKey]
end

function Season.GetPreviousSeasonKey(seasonKey)
    local info = seasonByKey[seasonKey]
    if not info then
        local globalID = tonumber((seasonKey or ""):match("^pvp%-(%d+)$"))
        return globalID and globalID > 1 and ("pvp-" .. (globalID - 1)) or nil
    end

    local previous
    for _, expansion in ipairs(EXPANSIONS) do
        for _, candidate in ipairs(expansion.seasons) do
            if candidate.key == seasonKey then
                return previous and previous.key or nil
            end
            previous = candidate
        end
    end
    return nil
end

function Season.GetCrests(seasonKey)
    return CopyArray(Season.GetSeasonInfo(seasonKey).crests)
end

function Season.GetFeatureDefinition(featureKey, seasonKey)
    local info = Season.GetSeasonInfo(seasonKey or Season.GetContentSeasonKey())
    return info.features and info.features[featureKey] or nil
end

local function CopyFeature(definition, detected)
    local result = {}
    for key, value in pairs(definition or {}) do
        result[key] = value
    end
    for key, value in pairs(detected or {}) do
        result[key] = value
    end
    return result
end

function Season.GetFeature(featureKey, seasonKey)
    seasonKey = seasonKey or Season.GetContentSeasonKey()
    local definition = Season.GetFeatureDefinition(featureKey, seasonKey)
    if not definition then return nil end

    if definition.active or (definition.itemID and not definition.discoverAtVendor) then
        return definition
    end

    local detected = WarbandRatingsDB
        and WarbandRatingsDB.seasonFeatures
        and WarbandRatingsDB.seasonFeatures[seasonKey]
        and WarbandRatingsDB.seasonFeatures[seasonKey][featureKey]
    if detected and tonumber(detected.itemID) and detected.name then
        return CopyFeature(definition, detected)
    end
    return nil
end

function Season.RememberFeature(featureKey, featureData, seasonKey)
    seasonKey = seasonKey or Season.GetContentSeasonKey()
    local definition = Season.GetFeatureDefinition(featureKey, seasonKey)
    local itemID = featureData and tonumber(featureData.itemID)
    local name = featureData and featureData.name
    if not definition or not definition.discoverAtVendor or not itemID or not name or name == "" then
        return nil
    end

    WarbandRatingsDB = WarbandRatingsDB or {}
    WarbandRatingsDB.seasonFeatures = WarbandRatingsDB.seasonFeatures or {}
    WarbandRatingsDB.seasonFeatures[seasonKey] = WarbandRatingsDB.seasonFeatures[seasonKey] or {}

    local stored = {
        itemID = itemID,
        name = name,
        pluralName = featureData.pluralName or (name .. "s"),
        fallbackCost = tonumber(featureData.fallbackCost) or definition.fallbackCost,
        hasOpeningCast = featureData.hasOpeningCast ~= false,
        detectedAt = time and time() or nil,
    }
    WarbandRatingsDB.seasonFeatures[seasonKey][featureKey] = stored
    return CopyFeature(definition, stored)
end

function Season.IsFeatureAvailable(featureKey, seasonKey)
    return Season.GetFeature(featureKey, seasonKey) ~= nil
end

function Season.GetExpansionOptions(seasonKeys)
    local included = {}
    for _, seasonKey in ipairs(seasonKeys or {}) do
        included[Season.GetSeasonInfo(seasonKey).expansionKey] = true
    end

    local options = {}
    for _, expansion in ipairs(EXPANSIONS) do
        if included[expansion.key] then
            options[#options + 1] = {
                key = expansion.key,
                label = expansion.name,
                order = expansion.order,
            }
        end
    end
    if included[LEGACY_EXPANSION_KEY] then
        options[#options + 1] = {
            key = LEGACY_EXPANSION_KEY,
            label = "Legacy",
            order = 0,
        }
    end

    table.sort(options, function(a, b)
        if a.order ~= b.order then return a.order > b.order end
        return a.label < b.label
    end)
    return options
end

function Season.GetSeasonOptions(expansionKey, seasonKeys)
    local included = {}
    for _, seasonKey in ipairs(seasonKeys or {}) do
        included[seasonKey] = true
    end

    local options = {}
    for seasonKey in pairs(included) do
        local info = Season.GetSeasonInfo(seasonKey)
        if info.expansionKey == expansionKey then
            options[#options + 1] = {
                key = seasonKey,
                label = info.label,
                number = info.number or 0,
            }
        end
    end

    table.sort(options, function(a, b)
        if a.number ~= b.number then return a.number > b.number end
        return a.key > b.key
    end)
    return options
end

function Season.GetKnownSeasonKeys()
    local keys = {}
    for _, expansion in ipairs(EXPANSIONS) do
        for _, season in ipairs(expansion.seasons) do
            keys[#keys + 1] = season.key
        end
    end
    return keys
end
