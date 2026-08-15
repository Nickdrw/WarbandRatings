local _, ns = ...
ns.Database = {}
local Database = ns.Database
local Utils = ns.Utils
local Season = ns.Season

Database.HELIOTROPE_ITEM_ID = 253307
Database.HELIOTROPE_NAME = "Infused Heliotrope"
Database.HELIOTROPE_FALLBACK_HONOR_COST = 2500
Database.FIELD_MEDIC_HAZARD_PAYOUT_ITEM_ID = 258620
Database.FIELD_MEDIC_HAZARD_PAYOUT_ITEM_IDS = { 258620, 224557, 203724 }
Database.FIELD_MEDIC_HAZARD_PAYOUT_NAME = "Field Medic's Hazard Payout"
Database.ILLUSTRIOUS_CONTENDER_STRONGBOX_ITEM_ID = 258534
Database.ILLUSTRIOUS_CONTENDER_STRONGBOX_NAME = "Illustrious Contender's Strongbox"
Database.DEFAULT_HONOR_ALERT_THRESHOLD = 12000

function Database.NormalizeHonorAlertThreshold(value)
    value = tonumber(value)
    if not value or value < 1 then
        return Database.DEFAULT_HONOR_ALERT_THRESHOLD
    end
    return math.floor(value)
end

-- Rating column definitions.
-- bracketIndex: index passed to GetPersonalRatedInfo().
-- Known retail bracket indices for 12.x:
--   1 = Arena 2v2
--   2 = Arena 3v3
--   3 = Arena 5v5 (defunct, returns 0)
--   4 = 10v10 Rated Battlegrounds
--   7 = Solo Shuffle
--   8 = Rated Battleground Blitz (Solo BG) [pre-Midnight]
--   9 = Rated Battleground Blitz (Solo BG) [Midnight+]
-- "mythicPlus" is special-cased, not a PvP bracket.
--
-- perSpec: Solo Shuffle and BG Blitz ratings are per-specialization in WoW.
-- They are stored under charData.specRatings[specID] instead of charData.ratings.

Database.SPEC_COLUMNS = {
    { key = "soloShuffle",  label = "Solo Shuffle",  bracketIndex = 7 },
    { key = "soloBG",       label = "Solo BG",       bracketIndex = 9 },
}

Database.GLOBAL_COLUMNS = {
    { key = "arena2v2",     label = "2v2",           bracketIndex = 1 },
    { key = "arena3v3",     label = "3v3",           bracketIndex = 2 },
    { key = "rbg10v10",     label = "10v10",         bracketIndex = 4 },
    { key = "honor",        label = "Honor",         currencyID = 1792 },
    { key = "conquest",     label = "Conquest",      currencyID = 1602 },
    { key = "hk",           label = "HK",            statID = 588,     formatFn = Utils.FormatNumber,
      details = {
          { label = "World",         key = "hk_world",  statID = 381 },
          { label = "Arena",         key = "hk_arena",  statID = 383 },
          { label = "Battlegrounds", key = "hk_bg",     statID = 382 },
      }
    },
    { key = "mythicPlus",   label = "Mythic+",       bracketIndex = nil },
}

local function BuildGlobalColumns(seasonKey)
    local columns = {}
    for _, column in ipairs(Database.GLOBAL_COLUMNS) do
        columns[#columns + 1] = column
    end

    local crests = Season.GetCrests(seasonKey)
    if #crests > 0 then
        columns[#columns + 1] = {
            key = "crests",
            label = "Crests",
            crests = crests,
        }
    end
    return columns
end

function Database.GetGlobalColumns(seasonKey)
    return BuildGlobalColumns(seasonKey or Season.GetContentSeasonKey())
end

function Database.GetRatingColumns(seasonKey)
    local columns = {}
    for _, column in ipairs(Database.SPEC_COLUMNS) do
        columns[#columns + 1] = column
    end
    for _, column in ipairs(BuildGlobalColumns(seasonKey or Season.GetContentSeasonKey())) do
        columns[#columns + 1] = column
    end
    return columns
end

-- All columns in display order
Database.RATING_COLUMNS = {}
for _, c in ipairs(Database.SPEC_COLUMNS) do Database.RATING_COLUMNS[#Database.RATING_COLUMNS + 1] = c end
for _, c in ipairs(Database.GetGlobalColumns()) do Database.RATING_COLUMNS[#Database.RATING_COLUMNS + 1] = c end

-- Lookup set for O(1) spec column checks
local specColumnKeys = {}
for _, c in ipairs(Database.SPEC_COLUMNS) do specColumnKeys[c.key] = true end

local pvpColumnByBracketIndex = {}
for _, c in ipairs(Database.RATING_COLUMNS) do
    if c.bracketIndex then
        pvpColumnByBracketIndex[c.bracketIndex] = c
    end
end

function Database.IsSpecColumn(col)
    return specColumnKeys[col.key] or false
end

function Database.IsPVPColumn(col)
    return col and col.bracketIndex ~= nil
end

function Database.GetPVPColumnByBracketIndex(bracketIndex)
    return pvpColumnByBracketIndex[bracketIndex]
end

local function NormalizeSpecID(specID)
    specID = tonumber(specID)
    if specID and specID > 0 then
        return specID
    end
    return nil
end

local function MergeMissingSpecValues(target, source)
    if type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if target[key] == nil or (Utils.IsEmptyRating(target[key]) and not Utils.IsEmptyRating(value)) then
            target[key] = value
        end
    end
end

local function NormalizeSpecMap(specMap, fallbackSpecID)
    local normalized = {}
    local unknownEntries = {}
    local hasKnownSpec = false

    for specID, values in pairs(specMap or {}) do
        local normalizedSpecID = NormalizeSpecID(specID)
        if normalizedSpecID then
            hasKnownSpec = true
            normalized[normalizedSpecID] = normalized[normalizedSpecID] or {}
            MergeMissingSpecValues(normalized[normalizedSpecID], values)
        elseif values then
            unknownEntries[#unknownEntries + 1] = values
        end
    end

    if fallbackSpecID and not hasKnownSpec then
        normalized[fallbackSpecID] = normalized[fallbackSpecID] or {}
        for _, values in ipairs(unknownEntries) do
            MergeMissingSpecValues(normalized[fallbackSpecID], values)
        end
    end

    return normalized
end

local function NormalizeCharacterSpecData(charData)
    local currentSpecID = NormalizeSpecID(charData.currentSpecID) or NormalizeSpecID(charData.specID)
    charData.currentSpecID = currentSpecID or 0
    charData.pvpStats = charData.pvpStats or {}
    charData.specRatings = NormalizeSpecMap(charData.specRatings, currentSpecID)
    charData.specPVPStats = NormalizeSpecMap(charData.specPVPStats, currentSpecID)
    charData.specLastMMR = NormalizeSpecMap(charData.specLastMMR, currentSpecID)
end

function Database.Init()
    if not WarbandRatingsDB then
        WarbandRatingsDB = {}
    end
    if type(WarbandRatingsDB.seasonFeatures) ~= "table" then
        WarbandRatingsDB.seasonFeatures = {}
    end
    if not WarbandRatingsDB.settings then
        WarbandRatingsDB.settings = {
            hideNoRating = false,
            hideEmptyColumns = false,
            hideNonMaxLevel = false,
            hideBoxesHelper = false,
            hideHeliotropeHelper = false,
            hideConquestEquipmentChestPurchaseHelper = false,
            hideConquestEquipmentChestMailHelper = false,
            arenaQueueMinimized = false,
            arenaQueueCategory = "rated",
            arenaQueueRatingSessions = {},
            conquestEquipmentChestMailRecipient = "",
            honorAlertThreshold = Database.DEFAULT_HONOR_ALERT_THRESHOLD,
            hideHonorAlertIcon = false,
            themeKey = "obsidian",
            windowHeight = 450,
            sortKey = "character",
            sortDirection = "asc",
        }
    end
    if WarbandRatingsDB.settings.themeKey == nil then
        WarbandRatingsDB.settings.themeKey = "obsidian"
    end
    if WarbandRatingsDB.settings.hideNonMaxLevel == nil then
        WarbandRatingsDB.settings.hideNonMaxLevel = false
    end
    if WarbandRatingsDB.settings.hideBoxesHelper == nil then
        WarbandRatingsDB.settings.hideBoxesHelper = false
    end
    if WarbandRatingsDB.settings.hideHeliotropeHelper == nil then
        WarbandRatingsDB.settings.hideHeliotropeHelper = false
    end
    if WarbandRatingsDB.settings.hideConquestEquipmentChestPurchaseHelper == nil then
        WarbandRatingsDB.settings.hideConquestEquipmentChestPurchaseHelper =
            WarbandRatingsDB.settings.hideGalacticConquestChestHelper or false
    end
    if WarbandRatingsDB.settings.hideConquestEquipmentChestMailHelper == nil then
        WarbandRatingsDB.settings.hideConquestEquipmentChestMailHelper =
            WarbandRatingsDB.settings.hideGalacticEquipmentMailHelper or false
    end
    WarbandRatingsDB.settings.hideGalacticConquestChestHelper = nil
    WarbandRatingsDB.settings.hideGalacticEquipmentMailHelper = nil

    -- Preserve the former account-wide choice as the initial value for each
    -- character, while keeping all subsequent changes character-specific.
    if type(WarbandRatingsDB.characterSettingsDefaults) ~= "table" then
        WarbandRatingsDB.characterSettingsDefaults = {}
    end
    if WarbandRatingsDB.characterSettingsDefaults.hideArenaQueueHelper == nil then
        WarbandRatingsDB.characterSettingsDefaults.hideArenaQueueHelper =
            WarbandRatingsDB.settings.hideArenaQueueHelper == true
    end
    WarbandRatingsDB.settings.hideArenaQueueHelper = nil

    if type(WarbandRatingsCharacterDB) ~= "table" then
        WarbandRatingsCharacterDB = {}
    end
    if type(WarbandRatingsCharacterDB.settings) ~= "table" then
        WarbandRatingsCharacterDB.settings = {}
    end
    if WarbandRatingsCharacterDB.settings.hideArenaQueueHelper == nil then
        WarbandRatingsCharacterDB.settings.hideArenaQueueHelper =
            WarbandRatingsDB.characterSettingsDefaults.hideArenaQueueHelper == true
    end
    if WarbandRatingsDB.settings.arenaQueueMinimized == nil then
        WarbandRatingsDB.settings.arenaQueueMinimized = false
    end
    if WarbandRatingsDB.settings.arenaQueueCategory ~= "unrated" then
        WarbandRatingsDB.settings.arenaQueueCategory = "rated"
    end
    if type(WarbandRatingsDB.settings.arenaQueueRatingSessions) ~= "table" then
        WarbandRatingsDB.settings.arenaQueueRatingSessions = {}
    end
    if WarbandRatingsDB.settings.conquestEquipmentChestMailRecipient == nil then
        WarbandRatingsDB.settings.conquestEquipmentChestMailRecipient =
            WarbandRatingsDB.settings.galacticEquipmentMailRecipient or ""
    end
    WarbandRatingsDB.settings.honorAlertThreshold = Database.NormalizeHonorAlertThreshold(
        WarbandRatingsDB.settings.honorAlertThreshold
    )
    if WarbandRatingsDB.settings.hideHonorAlertIcon == nil then
        WarbandRatingsDB.settings.hideHonorAlertIcon = false
    end
    WarbandRatingsDB.settings.galacticEquipmentMailRecipient = nil
    if WarbandRatingsDB.settings.windowHeight == nil then
        WarbandRatingsDB.settings.windowHeight = 450
    end
    if WarbandRatingsDB.settings.minimapPos == nil then
        WarbandRatingsDB.settings.minimapPos = 220
    end
    if WarbandRatingsDB.settings.hiddenColumns == nil then
        WarbandRatingsDB.settings.hiddenColumns = {
            mythicPlus = true,
            crests = true,
        }
    end
    if WarbandRatingsDB.settings.sortKey == nil then
        WarbandRatingsDB.settings.sortKey = "character"
    end
    if WarbandRatingsDB.settings.sortDirection ~= "asc" and WarbandRatingsDB.settings.sortDirection ~= "desc" then
        WarbandRatingsDB.settings.sortDirection = "asc"
    end
end

-- Migrate old flat-ratings format to new per-spec format
function Database.Migrate()
    local characterMaps = {}
    if type(WarbandRatingsDB.characters) == "table" then
        characterMaps[#characterMaps + 1] = WarbandRatingsDB.characters
    end
    for _, season in pairs(WarbandRatingsDB.seasons or {}) do
        if type(season.characters) == "table" then
            characterMaps[#characterMaps + 1] = season.characters
        end
    end

    for _, characters in ipairs(characterMaps) do
        for _, charData in pairs(characters) do
            if charData.level == nil then
                charData.level = 0
            end

            if charData.ratings and not charData.specRatings then
                charData.specRatings = {}
                local specID = NormalizeSpecID(charData.specID) or NormalizeSpecID(charData.currentSpecID)
                if specID then
                    charData.specRatings[specID] = {}
                end
                for _, sc in ipairs(Database.SPEC_COLUMNS) do
                    if specID then
                        charData.specRatings[specID][sc.key] = charData.ratings[sc.key] or 0
                    end
                    charData.ratings[sc.key] = nil
                end
            end
            -- Ensure specRatings exists
            if not charData.specRatings then
                charData.specRatings = {}
            end
            if not charData.pvpStats then
                charData.pvpStats = {}
            end
            if not charData.specPVPStats then
                charData.specPVPStats = {}
            end
            if not charData.lastMMR then
                charData.lastMMR = {}
            end
            if not charData.specLastMMR then
                charData.specLastMMR = {}
            end
            if not charData.itemCounts then
                charData.itemCounts = {}
            end
            charData.series = charData.series or { global = {}, specs = {} }
            charData.series.global = charData.series.global or {}
            charData.series.specs = charData.series.specs or {}
            NormalizeCharacterSpecData(charData)
        end
    end
end

function Database.IsValidSeasonKey(seasonKey)
    return type(seasonKey) == "string" and seasonKey ~= ""
end

function Database.IsStorageReady()
    return WarbandRatingsDB
        and (tonumber(WarbandRatingsDB.schemaVersion) or 0) >= 2
        and not WarbandRatingsDB.storageMigrationError
end

function Database.EnsureSeason(seasonKey)
    if not Database.IsValidSeasonKey(seasonKey) then return nil end

    WarbandRatingsDB.seasons = WarbandRatingsDB.seasons or {}
    WarbandRatingsDB.seasons[seasonKey] = WarbandRatingsDB.seasons[seasonKey] or {
        archived = false,
        characters = {},
    }

    local season = WarbandRatingsDB.seasons[seasonKey]
    if type(season) ~= "table" then return nil end
    if season.seasonKey and season.seasonKey ~= seasonKey then return nil end
    local seasonInfo = Season.GetSeasonInfo(seasonKey)
    season.characters = season.characters or {}
    season.seasonKey = seasonKey
    season.expansionKey = seasonInfo.expansionKey
    season.expansionName = seasonInfo.expansionName
    season.seasonNumber = seasonInfo.number
    return season
end

function Database.GetSeasonCharacters(seasonKey)
    if not WarbandRatingsDB or not Database.IsValidSeasonKey(seasonKey) then return {} end
    local season = WarbandRatingsDB.seasons and WarbandRatingsDB.seasons[seasonKey]
    if type(season) ~= "table"
        or season.seasonKey ~= seasonKey
        or type(season.characters) ~= "table"
    then
        return {}
    end
    for _, character in pairs(season.characters) do
        if type(character) ~= "table" or character.seasonKey ~= seasonKey then
            return {}
        end
    end
    return season.characters
end

function Database.GetCurrentCharacters()
    return Database.GetSeasonCharacters(Season.GetContentSeasonKey())
end

function Database.GetSettings()
    return WarbandRatingsDB.settings
end

function Database.SetSetting(key, value)
    WarbandRatingsDB.settings[key] = value
end

function Database.GetCharacterSettings()
    return WarbandRatingsCharacterDB.settings
end

function Database.GetCharacterSetting(key)
    return WarbandRatingsCharacterDB.settings[key]
end

function Database.SetCharacterSetting(key, value)
    WarbandRatingsCharacterDB.settings[key] = value
end

local function PreserveKnownStatValue(existingRatings, newRatings, key)
    if (newRatings[key] or 0) == 0 and (existingRatings[key] or 0) > 0 then
        newRatings[key] = existingRatings[key]
    end
end

local MONOTONIC_PVP_STAT_FIELDS = {
    "seasonBest",
    "seasonPlayed",
    "seasonWon",
    "roundsSeasonPlayed",
    "roundsSeasonWon",
}

local function HasStatsOwner(stats)
    return type(stats) == "table"
        and type(stats.ownerCharacterKey) == "string"
        and stats.ownerCharacterKey ~= ""
end

local function HasSameStatsOwner(existing, incoming)
    if existing.ownerCharacterKey ~= incoming.ownerCharacterKey then return false end

    local existingSpecID = tonumber(existing.ownerSpecID) or 0
    local incomingSpecID = tonumber(incoming.ownerSpecID) or 0
    return existingSpecID == incomingSpecID
end

local function MergePVPBracketStats(existing, incoming)
    if type(incoming) ~= "table" then return existing end
    if type(existing) ~= "table" then return incoming end

    -- A fresh response bound to this character/spec is authoritative. Legacy
    -- values have no owner marker and may contain another character's cached
    -- season totals; retaining their larger values would make that corruption
    -- permanent. Once ownership matches, cumulative values remain monotonic.
    local incomingHasOwner = HasStatsOwner(incoming)
    local preserveMonotonic = not incomingHasOwner
        or (HasStatsOwner(existing)
            and HasSameStatsOwner(existing, incoming)
            and not existing.seasonTotalsUntrusted)

    local merged = {}
    if preserveMonotonic then
        for key, value in pairs(existing) do
            merged[key] = value
        end
    end
    for key, value in pairs(incoming) do
        merged[key] = value
    end
    if preserveMonotonic then
        for _, key in ipairs(MONOTONIC_PVP_STAT_FIELDS) do
            merged[key] = math.max(tonumber(existing[key]) or 0, tonumber(incoming[key]) or 0)
        end

        local oldMostPlayed = tonumber(existing.seasonMostPlayedSpecCount) or 0
        local newMostPlayed = tonumber(incoming.seasonMostPlayedSpecCount) or 0
        if oldMostPlayed > newMostPlayed then
            merged.seasonMostPlayedSpecCount = oldMostPlayed
            merged.seasonMostPlayedSpecID = existing.seasonMostPlayedSpecID
        end
    end
    return merged
end

local function MergePVPStats(existing, incoming)
    local merged = existing or {}
    for colKey, stats in pairs(incoming or {}) do
        merged[colKey] = MergePVPBracketStats(merged[colKey], stats)
    end
    return merged
end

function Database.SaveCharacter(seasonKey, data)
    if not Database.IsStorageReady() then return false end
    if not Database.IsValidSeasonKey(seasonKey) or type(data) ~= "table" then return false end
    if data.seasonKey and data.seasonKey ~= seasonKey then return false end

    local key = Utils.CharKey(data.name, data.realm)
    local season = Database.EnsureSeason(seasonKey)
    if not season then return false end
    local existing = season.characters[key]
    data.seasonKey = seasonKey
    if existing and existing.seasonKey ~= seasonKey then return false end
    NormalizeCharacterSpecData(data)
    if existing then
        NormalizeCharacterSpecData(existing)
        -- Merge: keep existing specRatings, update current spec and global ratings
        existing.classFilename = data.classFilename
        existing.classID = data.classID
        existing.level = data.level
        -- For stat-based columns (e.g. HK), don't overwrite a known value with 0
        -- if the server hasn't returned stats yet this session.
        if existing.ratings then
            for _, col in ipairs(Database.GLOBAL_COLUMNS) do
                if col.statID then
                    PreserveKnownStatValue(existing.ratings, data.ratings, col.key)
                    if col.details then
                        for _, detail in ipairs(col.details) do
                            PreserveKnownStatValue(existing.ratings, data.ratings, detail.key)
                        end
                    end
                end
            end
        end
        existing.ratings = data.ratings
        existing.itemCounts = data.itemCounts or existing.itemCounts or {}
        existing.pvpStats = MergePVPStats(existing.pvpStats, data.pvpStats)
        existing.lastMMR = existing.lastMMR or {}
        if data.lastMMR then
            for k, v in pairs(data.lastMMR) do
                if not Utils.IsEmptyRating(v) then
                    existing.lastMMR[k] = v
                end
            end
        end
        existing.lastUpdated = data.lastUpdated
        existing.specRatings = existing.specRatings or {}
        existing.specPVPStats = existing.specPVPStats or {}
        existing.specLastMMR = existing.specLastMMR or {}
        existing.currentSpecID = data.currentSpecID
        existing.currentSpecRatings = data.currentSpecRatings
        if NormalizeSpecID(data.currentSpecID) and data.currentSpecRatings then
            existing.specRatings[data.currentSpecID] = data.currentSpecRatings
            if data.specPVPStats and data.specPVPStats[data.currentSpecID] then
                existing.specPVPStats[data.currentSpecID] = MergePVPStats(
                    existing.specPVPStats[data.currentSpecID],
                    data.specPVPStats[data.currentSpecID]
                )
            end
        end
    else
        data.series = data.series or { global = {}, specs = {} }
        data.series.global = data.series.global or {}
        data.series.specs = data.series.specs or {}
        season.characters[key] = data
        existing = data
    end
    existing.seasonKey = seasonKey
    existing.series = existing.series or { global = {}, specs = {} }
    existing.series.global = existing.series.global or {}
    existing.series.specs = existing.series.specs or {}
    return true
end

function Database.SaveWarbandItemCount(itemID, quantity)
    if not Database.IsStorageReady() then return end

    WarbandRatingsDB.warbandItemCounts = WarbandRatingsDB.warbandItemCounts or {}
    WarbandRatingsDB.warbandItemCounts[itemID] = {
        quantity = tonumber(quantity) or 0,
        lastUpdated = time(),
    }
end

function Database.GetWarbandItemCount(itemID)
    local item = WarbandRatingsDB
        and WarbandRatingsDB.warbandItemCounts
        and WarbandRatingsDB.warbandItemCounts[itemID]
    return tonumber(item and item.quantity) or 0
end

function Database.GetItemWarbandSummary(itemID)
    local total = Database.GetWarbandItemCount(itemID)
    local entries = {}

    local warbankQuantity = total
    if warbankQuantity > 0 then
        entries[#entries + 1] = {
            label = "Warband Bank",
            quantity = warbankQuantity,
            isWarbank = true,
        }
    end

    for _, charData in pairs(Database.GetCurrentCharacters()) do
        local quantity = tonumber(charData.itemCounts and charData.itemCounts[itemID]) or 0
        if quantity > 0 then
            total = total + quantity
            entries[#entries + 1] = {
                label = (charData.name or "?") .. "-" .. (charData.realm or "?"),
                quantity = quantity,
                classFilename = charData.classFilename,
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.isWarbank ~= b.isWarbank then
            return a.isWarbank
        end
        return (a.label or "") < (b.label or "")
    end)

    return total, entries
end

function Database.SaveLastMMR(seasonKey, name, realm, specID, bracketIndex, mmr)
    if not Database.IsStorageReady() then return false end
    if not Database.IsValidSeasonKey(seasonKey) then return false end
    mmr = tonumber(mmr)
    if not mmr or mmr <= 0 then return false end

    local col = Database.GetPVPColumnByBracketIndex(bracketIndex)
    if not col then return false end

    local key = Utils.CharKey(name, realm)
    local existing = Database.GetSeasonCharacters(seasonKey)[key]
    if not existing then return false end
    if existing.seasonKey ~= seasonKey then return false end

    if Database.IsSpecColumn(col) then
        specID = tonumber(specID)
        if not specID or specID == 0 then return false end
        existing.specLastMMR = existing.specLastMMR or {}
        existing.specLastMMR[specID] = existing.specLastMMR[specID] or {}
        existing.specLastMMR[specID][col.key] = mmr
    else
        existing.lastMMR = existing.lastMMR or {}
        existing.lastMMR[col.key] = mmr
    end

    existing.lastUpdated = time()
    return true
end

-- Returns grouped character data for display.
-- Each entry = { charData = ..., specs = { specID1, specID2, ... } }
-- Sorted by name-realm. specs sorted by specID.
function Database.BuildCharacterGroups(characters, seasonKey)
    local settings = Database.GetSettings()
    local globalColumns = Database.GetGlobalColumns(seasonKey)
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
    local groups = {}

    for _, charData in pairs(characters or {}) do
        local skip = false

        -- Filter: hide non-max-level characters
        if settings.hideNonMaxLevel and (charData.level or 0) < maxLevel then
            skip = true
        end

        -- Zero out PvP bracket ratings for sub-max-level characters at display time,
        -- so stale stored data from before this logic existed is never shown.
        if not skip and (charData.level or 0) < maxLevel then
            local patchedRatings = {}
            for k, v in pairs(charData.ratings or {}) do patchedRatings[k] = v end
            for _, col in ipairs(globalColumns) do
                if col.bracketIndex then patchedRatings[col.key] = 0 end
            end
            local patchedLastMMR = {}
            for k, v in pairs(charData.lastMMR or {}) do patchedLastMMR[k] = v end
            for _, col in ipairs(globalColumns) do
                if col.bracketIndex then patchedLastMMR[col.key] = 0 end
            end
            local patchedSpecRatings = {}
            for specID, sr in pairs(charData.specRatings or {}) do
                local normalizedSpecID = NormalizeSpecID(specID)
                if normalizedSpecID then
                    local psr = {}
                    for k, v in pairs(sr) do psr[k] = v end
                    for _, col in ipairs(Database.SPEC_COLUMNS) do
                        if col.bracketIndex then psr[col.key] = 0 end
                    end
                    patchedSpecRatings[normalizedSpecID] = psr
                end
            end
            local patchedSpecLastMMR = {}
            for specID, sr in pairs(charData.specLastMMR or {}) do
                local normalizedSpecID = NormalizeSpecID(specID)
                if normalizedSpecID then
                    local psr = {}
                    for k, v in pairs(sr) do psr[k] = v end
                    for _, col in ipairs(Database.SPEC_COLUMNS) do
                        if col.bracketIndex then psr[col.key] = 0 end
                    end
                    patchedSpecLastMMR[normalizedSpecID] = psr
                end
            end
            -- Use a shallow copy so we don't mutate SavedVariables
            charData = Utils.ShallowCopy(charData)
            charData.ratings = patchedRatings
            charData.lastMMR = patchedLastMMR
            charData.specRatings = patchedSpecRatings
            charData.specLastMMR = patchedSpecLastMMR
        end

        -- Collect specs
        local specs = {}
        local specsByID = {}
        if not skip and charData.specRatings then
            for specID, _ in pairs(charData.specRatings) do
                local normalizedSpecID = NormalizeSpecID(specID)
                if normalizedSpecID and not specsByID[normalizedSpecID] then
                    specsByID[normalizedSpecID] = true
                    specs[#specs + 1] = normalizedSpecID
                end
            end
        end
        table.sort(specs)
        if #specs == 0 then
            specs = { 0 }
        end

        -- Filter: hide if all ratings empty (global + all specs)
        if not skip and settings.hideNoRating then
            local hasAny = false
            for _, col in ipairs(globalColumns) do
                if not Utils.IsEmptyRating(charData.ratings and charData.ratings[col.key]) then
                    hasAny = true
                    break
                end
            end
            if not hasAny then
                for _, specID in ipairs(specs) do
                    local sr = charData.specRatings and charData.specRatings[specID]
                    if sr then
                        for _, col in ipairs(Database.SPEC_COLUMNS) do
                            if not Utils.IsEmptyRating(sr[col.key]) then
                                hasAny = true
                                break
                            end
                        end
                    end
                    if hasAny then break end
                end
            end
            if not hasAny then skip = true end
        end

        if not skip then
            groups[#groups + 1] = { charData = charData, specs = specs }
        end
    end

    table.sort(groups, function(a, b)
        local levelA = a.charData.level or 0
        local levelB = b.charData.level or 0
        if levelA ~= levelB then
            return levelA > levelB  -- higher level first
        end
        local classA = a.charData.classFilename or ""
        local classB = b.charData.classFilename or ""
        if classA ~= classB then
            return classA < classB
        end
        return (a.charData.name or "") < (b.charData.name or "")
    end)
    return groups
end

function Database.GetFilteredCharacterGroups(seasonKey, characters)
    seasonKey = seasonKey or Season.GetContentSeasonKey()
    return Database.BuildCharacterGroups(
        characters or Database.GetSeasonCharacters(seasonKey),
        seasonKey
    )
end

-- For column visibility, check across all groups and their specs.
function Database.GetVisibleColumns(groups, seasonKey)
    local settings = Database.GetSettings()
    local hiddenColumns = settings.hiddenColumns or {}
    local ratingColumns = Database.GetRatingColumns(seasonKey)

    if not settings.hideEmptyColumns then
        local visible = {}
        for _, col in ipairs(ratingColumns) do
            if not hiddenColumns[col.key] then
                visible[#visible + 1] = col
            end
        end
        return visible
    end

    local visible = {}
    for _, col in ipairs(ratingColumns) do
        if not hiddenColumns[col.key] then
            local found = false

            for _, grp in ipairs(groups or {}) do
                if Database.IsSpecColumn(col) then
                    for _, specID in ipairs(grp.specs) do
                        local sr = grp.charData.specRatings and grp.charData.specRatings[specID]
                        if not Utils.IsEmptyRating(sr and sr[col.key]) then
                            found = true
                            break
                        end
                    end
                elseif not Utils.IsEmptyRating(grp.charData.ratings and grp.charData.ratings[col.key]) then
                    found = true
                end

                if found then break end
            end

            if found then
                visible[#visible + 1] = col
            end
        end
    end
    return visible
end
