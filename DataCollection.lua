local _, ns = ...
ns.DataCollection = {}
local DataCollection = ns.DataCollection
local Database = ns.Database

function DataCollection.CollectCurrentCharacter()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName() or GetRealmName():gsub("%s", "")
    local _, classFilename, classID = UnitClass("player")

    local specIndex = GetSpecialization()
    local specID
    if specIndex then
        specID = GetSpecializationInfo(specIndex)
    end
    specID = specID or 0

    local level = UnitLevel("player")
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
    local isMaxLevel = level >= maxLevel

    -- Global ratings (not per-spec)
    local globalRatings = {}
    for _, col in ipairs(Database.GLOBAL_COLUMNS) do
        if col.bracketIndex then
            -- PvP bracket ratings are season-specific; zero out for sub-max-level characters
            local rating = isMaxLevel and GetPersonalRatedInfo(col.bracketIndex) or 0
            globalRatings[col.key] = rating or 0
        elseif col.key == "mythicPlus" then
            local score = C_ChallengeMode
                and C_ChallengeMode.GetOverallDungeonScore
                and C_ChallengeMode.GetOverallDungeonScore()
            globalRatings[col.key] = score or 0
        elseif col.currencyID then
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(col.currencyID)
            globalRatings[col.key] = info and info.quantity or 0
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
    local specRatings = {}
    for _, col in ipairs(Database.SPEC_COLUMNS) do
        if col.bracketIndex then
            local rating = isMaxLevel and GetPersonalRatedInfo(col.bracketIndex) or 0
            specRatings[col.key] = rating or 0
        end
    end

    local data = {
        name = name,
        realm = realm,
        classFilename = classFilename,
        classID = classID,
        level = level,
        ratings = globalRatings,
        specRatings = { [specID] = specRatings },
        currentSpecID = specID,
        currentSpecRatings = specRatings,
        lastUpdated = time(),
    }

    Database.SaveCharacter(data)
    return data
end
