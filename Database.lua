local _, ns = ...
ns.Database = {}
local Database = ns.Database
local Utils = ns.Utils

-- Rating column definitions.
-- bracketIndex: index passed to GetPersonalRatedInfo().
-- Known retail bracket indices (as of TWW / 12.x):
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
    -- Crests: current season tiers from lowest to highest.
    { key = "crests",       label = "Crests",
      crests = {
          { label = "Adventurer Dawncrest", key = "crest_adventurer", currencyID = 3383 },
          { label = "Veteran Dawncrest",    key = "crest_veteran",    currencyID = 3341 },
          { label = "Champion Dawncrest",   key = "crest_champion",   currencyID = 3343 },
          { label = "Hero Dawncrest",       key = "crest_hero",       currencyID = 3345 },
          { label = "Myth Dawncrest",       key = "crest_myth",       currencyID = 3347 },
      }
    },
}

-- All columns in display order
Database.RATING_COLUMNS = {}
for _, c in ipairs(Database.SPEC_COLUMNS) do Database.RATING_COLUMNS[#Database.RATING_COLUMNS + 1] = c end
for _, c in ipairs(Database.GLOBAL_COLUMNS) do Database.RATING_COLUMNS[#Database.RATING_COLUMNS + 1] = c end

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
    charData.specRatings = NormalizeSpecMap(charData.specRatings, currentSpecID)
    charData.specLastMMR = NormalizeSpecMap(charData.specLastMMR, currentSpecID)
end

function Database.Init()
    if not WarbandRatingsDB then
        WarbandRatingsDB = {}
    end
    if not WarbandRatingsDB.characters then
        WarbandRatingsDB.characters = {}
    end
    if not WarbandRatingsDB.settings then
        WarbandRatingsDB.settings = {
            hideNoRating = false,
            hideEmptyColumns = false,
            hideNonMaxLevel = false,
            themeKey = "obsidian",
            graphVisiblePointCount = 50,
            windowHeight = 450,
        }
    end
    if WarbandRatingsDB.settings.themeKey == nil then
        WarbandRatingsDB.settings.themeKey = "obsidian"
    end
    if WarbandRatingsDB.settings.hideNonMaxLevel == nil then
        WarbandRatingsDB.settings.hideNonMaxLevel = false
    end
    if WarbandRatingsDB.settings.graphVisiblePointCount == nil then
        WarbandRatingsDB.settings.graphVisiblePointCount = 50
    end
    if WarbandRatingsDB.settings.windowHeight == nil then
        WarbandRatingsDB.settings.windowHeight = 450
    end
    if WarbandRatingsDB.settings.minimapPos == nil then
        WarbandRatingsDB.settings.minimapPos = 220
    end
    if WarbandRatingsDB.settings.hiddenColumns == nil then
        WarbandRatingsDB.settings.hiddenColumns = {}
    end
    Database.Migrate()
end

-- Migrate old flat-ratings format to new per-spec format
function Database.Migrate()
    for _, charData in pairs(WarbandRatingsDB.characters) do
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
        if not charData.lastMMR then
            charData.lastMMR = {}
        end
        if not charData.specLastMMR then
            charData.specLastMMR = {}
        end
        NormalizeCharacterSpecData(charData)
    end
end

function Database.GetSettings()
    return WarbandRatingsDB.settings
end

function Database.SetSetting(key, value)
    WarbandRatingsDB.settings[key] = value
end

local function PreserveKnownStatValue(existingRatings, newRatings, key)
    if (newRatings[key] or 0) == 0 and (existingRatings[key] or 0) > 0 then
        newRatings[key] = existingRatings[key]
    end
end

function Database.SaveCharacter(data)
    local key = Utils.CharKey(data.name, data.realm)
    local existing = WarbandRatingsDB.characters[key]
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
        existing.specLastMMR = existing.specLastMMR or {}
        existing.currentSpecID = data.currentSpecID
        existing.currentSpecRatings = data.currentSpecRatings
        if NormalizeSpecID(data.currentSpecID) and data.currentSpecRatings then
            existing.specRatings[data.currentSpecID] = data.currentSpecRatings
        end
    else
        WarbandRatingsDB.characters[key] = data
    end
end

function Database.SaveLastMMR(name, realm, specID, bracketIndex, mmr)
    mmr = tonumber(mmr)
    if not mmr or mmr <= 0 then return false end

    local col = Database.GetPVPColumnByBracketIndex(bracketIndex)
    if not col then return false end

    local key = Utils.CharKey(name, realm)
    local existing = WarbandRatingsDB.characters[key]
    if not existing then return false end

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
function Database.BuildCharacterGroups(characters)
    local settings = Database.GetSettings()
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
            for _, col in ipairs(Database.GLOBAL_COLUMNS) do
                if col.bracketIndex then patchedRatings[col.key] = 0 end
            end
            local patchedLastMMR = {}
            for k, v in pairs(charData.lastMMR or {}) do patchedLastMMR[k] = v end
            for _, col in ipairs(Database.GLOBAL_COLUMNS) do
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
            for _, col in ipairs(Database.GLOBAL_COLUMNS) do
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

function Database.GetFilteredCharacterGroups()
    return Database.BuildCharacterGroups(WarbandRatingsDB and WarbandRatingsDB.characters)
end

-- For column visibility, check across all groups and their specs.
function Database.GetVisibleColumns(groups)
    local settings = Database.GetSettings()
    local hiddenColumns = settings.hiddenColumns or {}

    if not settings.hideEmptyColumns then
        local visible = {}
        for _, col in ipairs(Database.RATING_COLUMNS) do
            if not hiddenColumns[col.key] then
                visible[#visible + 1] = col
            end
        end
        return visible
    end

    local visible = {}
    for _, col in ipairs(Database.RATING_COLUMNS) do
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
