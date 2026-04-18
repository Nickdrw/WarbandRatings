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

    -- Global ratings (not per-spec)
    local globalRatings = {}
    for _, col in ipairs(Database.GLOBAL_COLUMNS) do
        if col.bracketIndex then
            local rating = GetPersonalRatedInfo(col.bracketIndex)
            globalRatings[col.key] = rating or 0
        elseif col.key == "mythicPlus" then
            local score = C_ChallengeMode
                and C_ChallengeMode.GetOverallDungeonScore
                and C_ChallengeMode.GetOverallDungeonScore()
            globalRatings[col.key] = score or 0
        end
    end

    -- Per-spec ratings (Solo Shuffle, Solo BG)
    local specRatings = {}
    for _, col in ipairs(Database.SPEC_COLUMNS) do
        if col.bracketIndex then
            local rating = GetPersonalRatedInfo(col.bracketIndex)
            specRatings[col.key] = rating or 0
        end
    end

    local data = {
        name = name,
        realm = realm,
        classFilename = classFilename,
        classID = classID,
        level = UnitLevel("player"),
        ratings = globalRatings,
        specRatings = { [specID] = specRatings },
        currentSpecID = specID,
        currentSpecRatings = specRatings,
        lastUpdated = time(),
    }

    Database.SaveCharacter(data)
    return data
end
