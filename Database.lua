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
--   8 = Rated Battleground Blitz (Solo BG)
-- "mythicPlus" is special-cased, not a PvP bracket.
--
-- perSpec: Solo Shuffle and BG Blitz ratings are per-specialization in WoW.
-- They are stored under charData.specRatings[specID] instead of charData.ratings.

Database.SPEC_COLUMNS = {
    { key = "soloShuffle",  label = "Solo Shuffle",  bracketIndex = 7 },
    { key = "soloBG",       label = "Solo BG",       bracketIndex = 8 },
}

Database.GLOBAL_COLUMNS = {
    { key = "arena2v2",     label = "2v2",           bracketIndex = 1 },
    { key = "arena3v3",     label = "3v3",           bracketIndex = 2 },
    { key = "rbg10v10",     label = "10v10",         bracketIndex = 4 },
    { key = "mythicPlus",   label = "Mythic+",       bracketIndex = nil },
}

-- All columns in display order
Database.RATING_COLUMNS = {}
for _, c in ipairs(Database.SPEC_COLUMNS) do Database.RATING_COLUMNS[#Database.RATING_COLUMNS + 1] = c end
for _, c in ipairs(Database.GLOBAL_COLUMNS) do Database.RATING_COLUMNS[#Database.RATING_COLUMNS + 1] = c end

function Database.IsSpecColumn(col)
    for _, sc in ipairs(Database.SPEC_COLUMNS) do
        if sc.key == col.key then return true end
    end
    return false
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
            hideNonMaxLevel = true,
        }
    end
    if WarbandRatingsDB.settings.hideNonMaxLevel == nil then
        WarbandRatingsDB.settings.hideNonMaxLevel = true
    end
    if WarbandRatingsDB.settings.minimapPos == nil then
        WarbandRatingsDB.settings.minimapPos = 220
    end
    Database.Migrate()
end

-- Migrate old flat-ratings format to new per-spec format
function Database.Migrate()
    for _, charData in pairs(WarbandRatingsDB.characters) do
        if charData.ratings and not charData.specRatings then
            charData.specRatings = {}
            local specID = charData.specID or 0
            if specID ~= 0 then
                charData.specRatings[specID] = {}
                for _, sc in ipairs(Database.SPEC_COLUMNS) do
                    charData.specRatings[specID][sc.key] = charData.ratings[sc.key] or 0
                end
            end
            -- Move global ratings, remove spec keys from flat ratings
            for _, sc in ipairs(Database.SPEC_COLUMNS) do
                charData.ratings[sc.key] = nil
            end
        end
        -- Ensure specRatings exists
        if not charData.specRatings then
            charData.specRatings = {}
        end
    end
end

function Database.GetSettings()
    return WarbandRatingsDB.settings
end

function Database.SetSetting(key, value)
    WarbandRatingsDB.settings[key] = value
end

function Database.GetCharacters()
    return WarbandRatingsDB.characters
end

function Database.SaveCharacter(data)
    local key = Utils.CharKey(data.name, data.realm)
    local existing = WarbandRatingsDB.characters[key]
    if existing then
        -- Merge: keep existing specRatings, update current spec and global ratings
        existing.classFilename = data.classFilename
        existing.classID = data.classID
        existing.level = data.level
        existing.ratings = data.ratings
        existing.lastUpdated = data.lastUpdated
        if data.currentSpecID and data.currentSpecID ~= 0 then
            existing.specRatings[data.currentSpecID] = data.currentSpecRatings
        end
    else
        WarbandRatingsDB.characters[key] = data
    end
end

-- Returns grouped character data for display.
-- Each entry = { charData = ..., specs = { specID1, specID2, ... } }
-- Sorted by name-realm. specs sorted by specID.
function Database.GetFilteredCharacterGroups()
    local settings = Database.GetSettings()
    local groups = {}
    for _, charData in pairs(WarbandRatingsDB.characters) do
        -- Collect specs
        local specs = {}
        if charData.specRatings then
            for specID, _ in pairs(charData.specRatings) do
                specs[#specs + 1] = specID
            end
        end
        table.sort(specs)
        if #specs == 0 then
            specs = { 0 }
        end

        -- Filter: hide if all ratings empty (global + all specs)
        if settings.hideNoRating then
            local hasAny = false
            -- Check global ratings
            for _, col in ipairs(Database.GLOBAL_COLUMNS) do
                if not Utils.IsEmptyRating(charData.ratings and charData.ratings[col.key]) then
                    hasAny = true
                    break
                end
            end
            -- Check spec ratings
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
            if not hasAny then
                charData = nil
            end
        end

        if charData then
            if settings.hideNonMaxLevel then
                local maxLevel = GetMaxLevelForPlayerExpansion
                    and GetMaxLevelForPlayerExpansion() or 80
                if (charData.level or 0) < maxLevel then
                    charData = nil
                end
            end
        end

        if charData then
            groups[#groups + 1] = { charData = charData, specs = specs }
        end
    end
    table.sort(groups, function(a, b)
        local classA = a.charData.classFilename or ""
        local classB = b.charData.classFilename or ""
        if classA ~= classB then
            return classA < classB
        end
        return (a.charData.name or "") < (b.charData.name or "")
    end)
    return groups
end

-- For column visibility, check across all groups and their specs.
function Database.GetVisibleColumns(groups)
    local settings = Database.GetSettings()
    if not settings.hideEmptyColumns then
        return Database.RATING_COLUMNS
    end
    local visible = {}
    for _, col in ipairs(Database.RATING_COLUMNS) do
        local found = false
        for _, grp in ipairs(groups) do
            if Database.IsSpecColumn(col) then
                for _, specID in ipairs(grp.specs) do
                    local sr = grp.charData.specRatings and grp.charData.specRatings[specID]
                    if not Utils.IsEmptyRating(sr and sr[col.key]) then
                        found = true
                        break
                    end
                end
            else
                if not Utils.IsEmptyRating(grp.charData.ratings and grp.charData.ratings[col.key]) then
                    found = true
                end
            end
            if found then break end
        end
        if found then
            visible[#visible + 1] = col
        end
    end
    return visible
end
