local _, ns = ...
ns.History = {}
local History = ns.History
local Database = ns.Database
local Utils = ns.Utils
local Season = ns.Season

local UNKNOWN_SEASON = "unknown"
local DUPLICATE_WINDOW_SECONDS = 30
local HISTORY_VERSION = 5
local DATABASE_SCHEMA_VERSION = 2

local FIELD_TIME = 1
local FIELD_RATING = 2
local FIELD_MMR = 3
local FIELD_RATING_DELTA = 4
local FIELD_MMR_DELTA = 5
local FIELD_RESULT = 6
local FIELD_MMR_IS_POSTMATCH = 7
local FIELD_MATCH_SEQUENCE = 8
local FIELD_MMR_SOURCE = 9
local FIELD_SPEC_ID = 10

local EnsureCharacterHistory
local BuildCharacterFromHistory

local MMR_SOURCE_PENDING = "pending"
local MMR_SOURCE_POSTMATCH = "postmatch"
local MMR_SOURCE_PREMATCH = "prematch"
local MMR_SOURCE_NEXT_PREMATCH = "nextPrematch"

local function NormalizeSeasonID(value)
    value = tonumber(value)
    if value and value > 0 then
        return "pvp-" .. value
    end
    return nil
end

local function GetSeasonNumber(seasonKey)
    return tonumber((seasonKey or ""):match("^pvp%-(%d+)$")) or 0
end

function History.GetDetectedSeasonKey()
    if GetCurrentArenaSeason then
        local key = NormalizeSeasonID(GetCurrentArenaSeason())
        if key then return key end
    end

    if C_PvP and C_PvP.GetUIDisplaySeason then
        local key = NormalizeSeasonID(C_PvP.GetUIDisplaySeason())
        if key then return key end
    end

    if C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID then
        local key = NormalizeSeasonID(C_SeasonInfo.GetCurrentDisplaySeasonID())
        if key then return key end
    end

    return UNKNOWN_SEASON
end

local function EnsureRoot()
    WarbandRatingsDB.seasons = WarbandRatingsDB.seasons or {}
    WarbandRatingsDB.history = WarbandRatingsDB.history or {}
    local history = WarbandRatingsDB.history
    history.version = math.max(tonumber(history.version) or 1, HISTORY_VERSION)
    history.diagnostics = history.diagnostics or {}
    return history
end

function History.RecordDiagnostic(reason)
    if type(reason) ~= "string" or reason == "" then return end

    local history = EnsureRoot()
    local diagnostic = history.diagnostics[reason] or {}
    diagnostic.count = (tonumber(diagnostic.count) or 0) + 1
    diagnostic.lastAt = time()
    history.diagnostics[reason] = diagnostic
end

local function EnsureSeason(_, seasonKey)
    return Database.EnsureSeason(seasonKey)
end

local function UpdateSummaryPeak(summary, rating, mmr, specID)
    rating = tonumber(rating) or 0
    mmr = tonumber(mmr) or 0
    specID = tonumber(specID) or 0

    if rating > summary.peakRating then
        summary.peakRating = rating
        summary.peakSpecID = specID
    elseif rating == summary.peakRating and (tonumber(summary.peakSpecID) or 0) <= 0 and specID > 0 then
        summary.peakSpecID = specID
    end
    if rating < summary.lowestRating then
        summary.lowestRating = rating
    end
    if mmr > summary.peakMMR then
        summary.peakMMR = mmr
    end
end

local function BuildSummary(points)
    if not points or #points == 0 then return nil end

    local first = points[1]
    local last = points[#points]
    local summary = {
        generatedAt = time(),
        sourcePointCount = #points,
        sourceFirstTime = first[FIELD_TIME],
        sourceLastTime = last[FIELD_TIME],
        games = #points,
        wins = 0,
        losses = 0,
        startRating = tonumber(first[FIELD_RATING]) or 0,
        finalRating = tonumber(last[FIELD_RATING]) or 0,
        peakRating = tonumber(first[FIELD_RATING]) or 0,
        peakSpecID = tonumber(first[FIELD_SPEC_ID]) or 0,
        lowestRating = tonumber(first[FIELD_RATING]) or 0,
        peakMMR = 0,
        finalMMR = 0,
    }

    for _, point in ipairs(points) do
        UpdateSummaryPeak(summary, point[FIELD_RATING], point[FIELD_MMR], point[FIELD_SPEC_ID])
        local mmr = tonumber(point[FIELD_MMR]) or 0
        if mmr > 0 then
            summary.finalMMR = mmr
        end
        if point[FIELD_RESULT] == 1 then
            summary.wins = summary.wins + 1
        elseif point[FIELD_RESULT] == 0 then
            summary.losses = summary.losses + 1
        end
    end

    return summary
end

local function ArchiveSeries(series)
    if not series then return end

    if series.archived then
        if series.points and not series.summary then
            series.summary = BuildSummary(series.points)
        end
        return
    end

    local summary = BuildSummary(series.points)
    if summary then
        series.summary = summary
        series.archived = true
        series.archivedAt = time()
        series.rawPointsRetained = true
    end
end

local function ArchiveSeason(season)
    if not season then return end
    local wasArchived = season.archived and true or false

    for _, charData in pairs(season.characters or {}) do
        local allSeries = charData.series or {}
        for _, series in pairs(allSeries.global or {}) do
            ArchiveSeries(series)
        end
        for _, specHistory in pairs(allSeries.specs or {}) do
            for _, series in pairs(specHistory) do
                ArchiveSeries(series)
            end
        end
    end

    season.archived = true
    if not wasArchived then
        season.archivedAt = time()
    end
end

local function ForEachSeries(season, callback)
    if not season then return end

    for _, charData in pairs(season.characters or {}) do
        local allSeries = charData.series or {}
        for _, series in pairs(allSeries.global or {}) do
            callback(series)
        end
        for _, specHistory in pairs(allSeries.specs or {}) do
            for _, series in pairs(specHistory) do
                callback(series)
            end
        end
    end
end

local function ClearArchivedRawPoints(series)
    if series and series.archived and series.summary then
        series.points = nil
        series.rawPointsRetained = false
    end
end

local function TrimOldestArchivedRawSeason(history)
    local archivedSeasons = {}
    local activeContentSeasonKey = history.contentSeasonKey or history.currentSeasonKey
    for seasonKey, season in pairs(WarbandRatingsDB.seasons or {}) do
        if seasonKey ~= activeContentSeasonKey and season.archived then
            archivedSeasons[#archivedSeasons + 1] = {
                key = seasonKey,
                season = season,
            }
        end
    end

    table.sort(archivedSeasons, function(a, b)
        local aNumber = GetSeasonNumber(a.key)
        local bNumber = GetSeasonNumber(b.key)
        if aNumber ~= bNumber then
            return aNumber < bNumber
        end
        return a.key < b.key
    end)

    for _, entry in ipairs(archivedSeasons) do
        local trimmed = false
        ForEachSeries(entry.season, function(series)
            if series and series.points and #series.points > 0 then
                ClearArchivedRawPoints(series)
                trimmed = true
            end
        end)
        if trimmed then return entry.key end
    end
    return nil
end

function History.EnsureCurrentSeason()
    local history = EnsureRoot()
    local detectedSeasonKey = History.GetDetectedSeasonKey()
    local currentSeasonKey = history.currentSeasonKey

    if currentSeasonKey == UNKNOWN_SEASON and detectedSeasonKey ~= UNKNOWN_SEASON then
        if WarbandRatingsDB.seasons[UNKNOWN_SEASON] and not WarbandRatingsDB.seasons[detectedSeasonKey] then
            WarbandRatingsDB.seasons[detectedSeasonKey] = WarbandRatingsDB.seasons[UNKNOWN_SEASON]
            WarbandRatingsDB.seasons[UNKNOWN_SEASON] = nil
            WarbandRatingsDB.seasons[detectedSeasonKey].seasonKey = detectedSeasonKey
            for _, charData in pairs(WarbandRatingsDB.seasons[detectedSeasonKey].characters or {}) do
                charData.seasonKey = detectedSeasonKey
            end
        end
        currentSeasonKey = detectedSeasonKey
    elseif not currentSeasonKey then
        currentSeasonKey = detectedSeasonKey
    elseif detectedSeasonKey ~= UNKNOWN_SEASON and detectedSeasonKey ~= currentSeasonKey then
        ArchiveSeason(WarbandRatingsDB.seasons[currentSeasonKey])
        currentSeasonKey = detectedSeasonKey
    end

    history.currentSeasonKey = currentSeasonKey
    EnsureSeason(history, currentSeasonKey)
    return currentSeasonKey
end

EnsureCharacterHistory = function(season, charKey)
    season.characters[charKey] = season.characters[charKey] or {
        seasonKey = season.seasonKey,
        ratings = {},
        pvpStats = {},
        lastMMR = {},
        specRatings = {},
        specPVPStats = {},
        specLastMMR = {},
        itemCounts = {},
        series = { global = {}, specs = {} },
        recoveredFromHistory = true,
    }
    local charData = season.characters[charKey]
    if charData.seasonKey ~= season.seasonKey then return nil end
    charData.series = charData.series or { global = {}, specs = {} }
    charData.series.global = charData.series.global or {}
    charData.series.specs = charData.series.specs or {}
    return charData
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
    end
    return copy
end

local function CreateSeasonBaseline(charData, seasonKey)
    local baseline = DeepCopy(charData or {})
    local oldRatings = baseline.ratings or {}

    -- Honor and lifetime honorable-kill statistics persist. Everything tied to
    -- rated PvP, Mythic+, Conquest, or upgrade crests starts with a clean season.
    baseline.ratings = {
        honor = tonumber(oldRatings.honor) or 0,
        hk = tonumber(oldRatings.hk) or 0,
        hk_world = tonumber(oldRatings.hk_world) or 0,
        hk_arena = tonumber(oldRatings.hk_arena) or 0,
        hk_bg = tonumber(oldRatings.hk_bg) or 0,
    }
    baseline.pvpStats = {}
    baseline.lastMMR = {}
    baseline.specRatings = {}
    baseline.specPVPStats = {}
    baseline.specLastMMR = {}
    baseline.currentSpecRatings = {}
    baseline.series = { global = {}, specs = {} }
    baseline.seasonKey = seasonKey
    baseline.lastUpdated = 0
    return baseline
end

local function GetInitialCharacterSeason(previousCurrentSeasonKey, contentSeasonKey)
    if previousCurrentSeasonKey and previousCurrentSeasonKey ~= UNKNOWN_SEASON then
        return previousCurrentSeasonKey
    end

    -- Untagged records encountered for the first time after a patch are owned by
    -- the preceding season. This prevents offline characters from leaking stale
    -- ratings into a newly installed schema.
    local previousSeasonKey = Season.GetPreviousSeasonKey(contentSeasonKey)
    return previousSeasonKey or contentSeasonKey
end

local function CreateSeasonContainer(seasonKey, source)
    local seasonInfo = Season.GetSeasonInfo(seasonKey)
    return {
        seasonKey = seasonKey,
        expansionKey = seasonInfo.expansionKey,
        expansionName = seasonInfo.expansionName,
        seasonNumber = seasonInfo.number,
        archived = source and source.archived and true or false,
        archivedAt = source and source.archivedAt or nil,
        characters = {},
    }
end

local function EnsureSeasonContainer(seasons, seasonKey, source)
    seasons[seasonKey] = seasons[seasonKey] or CreateSeasonContainer(seasonKey, source)
    return seasons[seasonKey]
end

local function CopyLegacySeries(charHistory)
    return {
        global = DeepCopy(charHistory and charHistory.global or {}),
        specs = DeepCopy(charHistory and charHistory.specs or {}),
    }
end

local function BuildMigratedStorage(previousCurrentSeasonKey)
    local oldCharacters = WarbandRatingsDB.characters
    local oldHistory = WarbandRatingsDB.history or {}
    local newSeasons = {}

    for seasonKey, oldSeason in pairs(oldHistory.seasons or {}) do
        if not Database.IsValidSeasonKey(seasonKey) then
            error("invalid legacy season key")
        end
        local season = EnsureSeasonContainer(newSeasons, seasonKey, oldSeason)
        for charKey, charHistory in pairs(oldSeason.characters or {}) do
            if type(charHistory) ~= "table" then
                error("invalid legacy character history for " .. tostring(charKey))
            end
            local character = charHistory.snapshot
                and DeepCopy(charHistory.snapshot)
                or BuildCharacterFromHistory(charKey, charHistory, seasonKey)
            character.seasonKey = seasonKey
            character.series = CopyLegacySeries(charHistory)
            character.snapshot = nil
            character.global = nil
            character.specs = nil
            season.characters[charKey] = character
        end
    end

    local contentSeasonKey = Season.GetContentSeasonKey()
    local sourceSeasonKey = GetInitialCharacterSeason(previousCurrentSeasonKey, contentSeasonKey)
    if not Database.IsValidSeasonKey(sourceSeasonKey) or sourceSeasonKey == UNKNOWN_SEASON then
        sourceSeasonKey = contentSeasonKey
    end

    for charKey, charData in pairs(oldCharacters or {}) do
        if type(charData) ~= "table" then
            error("invalid legacy character for " .. tostring(charKey))
        end
        local ownerSeasonKey = charData.seasonKey or sourceSeasonKey
        if not Database.IsValidSeasonKey(ownerSeasonKey) then
            error("missing season binding for " .. tostring(charKey))
        end
        local season = EnsureSeasonContainer(newSeasons, ownerSeasonKey)
        local existing = season.characters[charKey]
        local character = DeepCopy(charData)
        character.seasonKey = ownerSeasonKey
        character.series = existing and existing.series
            or character.series
            or { global = {}, specs = {} }
        character.series.global = character.series.global or {}
        character.series.specs = character.series.specs or {}
        character.snapshot = nil
        character.global = nil
        character.specs = nil
        season.characters[charKey] = character
    end

    local newHistory = DeepCopy(oldHistory)
    newHistory.version = math.max(tonumber(newHistory.version) or 1, HISTORY_VERSION)
    newHistory.seasons = nil
    newHistory.snapshotSchemaVersion = nil
    newHistory.diagnostics = newHistory.diagnostics or {}
    local hasLegacyCharacters = next(oldCharacters or {}) ~= nil
    newHistory.contentSeasonKey = newHistory.contentSeasonKey
        or (hasLegacyCharacters and sourceSeasonKey or contentSeasonKey)

    return {
        seasons = newSeasons,
        history = newHistory,
        oldCharacters = oldCharacters,
        oldHistory = oldHistory,
    }
end

local function ValidateSeasonBindings(seasons)
    local tableFields = {
        "ratings",
        "pvpStats",
        "lastMMR",
        "specRatings",
        "specPVPStats",
        "specLastMMR",
        "itemCounts",
    }
    for seasonKey, season in pairs(seasons or {}) do
        if type(season) ~= "table"
            or season.seasonKey ~= seasonKey
            or type(season.characters) ~= "table"
        then
            return false, "invalid season container " .. tostring(seasonKey)
        end
        for charKey, character in pairs(season.characters) do
            if type(character) ~= "table" or character.seasonKey ~= seasonKey then
                return false, "invalid season binding for " .. tostring(charKey)
            end
            if type(character.series) ~= "table"
                or type(character.series.global) ~= "table"
                or type(character.series.specs) ~= "table"
            then
                return false, "invalid series container for " .. tostring(charKey)
            end
            if character.snapshot ~= nil or character.global ~= nil or character.specs ~= nil then
                return false, "legacy fields remained on " .. tostring(charKey)
            end
            for _, field in ipairs(tableFields) do
                if character[field] ~= nil and type(character[field]) ~= "table" then
                    return false, "invalid " .. field .. " for " .. tostring(charKey)
                end
            end
        end
    end
    return true
end

local function ValidateMigratedStorage(storage)
    local bindingsValid, bindingError = ValidateSeasonBindings(storage.seasons)
    if not bindingsValid then return false, bindingError end

    for seasonKey, oldSeason in pairs(storage.oldHistory.seasons or {}) do
        local migratedSeason = storage.seasons[seasonKey]
        if not migratedSeason then return false, "season was not migrated: " .. seasonKey end
        for charKey, charHistory in pairs(oldSeason.characters or {}) do
            local migrated = migratedSeason.characters[charKey]
            if not migrated then return false, "character was not migrated: " .. charKey end
            for colKey in pairs(charHistory.global or {}) do
                if not migrated.series.global[colKey] then
                    return false, "global series was not migrated: " .. charKey .. "/" .. colKey
                end
            end
            for specID, specHistory in pairs(charHistory.specs or {}) do
                local migratedSpec = migrated.series.specs[specID]
                    or migrated.series.specs[tostring(specID)]
                if not migratedSpec then
                    return false, "spec series was not migrated: " .. charKey
                end
                for colKey in pairs(specHistory) do
                    if not migratedSpec[colKey] then
                        return false, "spec bracket was not migrated: " .. charKey .. "/" .. colKey
                    end
                end
            end
        end
    end

    for charKey, charData in pairs(storage.oldCharacters or {}) do
        local ownerSeasonKey = charData.seasonKey
            or GetInitialCharacterSeason(
                storage.oldHistory.currentSeasonKey,
                Season.GetContentSeasonKey()
            )
        local season = storage.seasons[ownerSeasonKey]
        if not season or not season.characters[charKey] then
            return false, "live character was not migrated: " .. tostring(charKey)
        end
    end
    return true
end

local function MigrateSeasonStorage(previousCurrentSeasonKey)
    if (tonumber(WarbandRatingsDB.schemaVersion) or 0) >= DATABASE_SCHEMA_VERSION then
        return ValidateSeasonBindings(WarbandRatingsDB.seasons)
    end

    local ok, storageOrError = pcall(BuildMigratedStorage, previousCurrentSeasonKey)
    if not ok then return false, tostring(storageOrError) end

    local valid, validationError = ValidateMigratedStorage(storageOrError)
    if not valid then return false, validationError end

    local hasLegacyData = next(storageOrError.oldCharacters or {}) ~= nil
        or next(storageOrError.oldHistory.seasons or {}) ~= nil
    if hasLegacyData and not WarbandRatingsDB.legacySchemaBackup then
        WarbandRatingsDB.legacySchemaBackup = {
            schemaVersion = tonumber(WarbandRatingsDB.schemaVersion) or 1,
            characters = storageOrError.oldCharacters,
            history = storageOrError.oldHistory,
            migratedAt = time(),
        }
    end

    -- The new structure was built and validated independently. These assignments
    -- are the only destructive part of the migration and therefore act as the
    -- atomic commit boundary.
    WarbandRatingsDB.seasons = storageOrError.seasons
    WarbandRatingsDB.history = storageOrError.history
    WarbandRatingsDB.characters = nil
    WarbandRatingsDB.schemaVersion = DATABASE_SCHEMA_VERSION
    return true
end

function History.EnsureContentSeason()
    local history = EnsureRoot()
    local targetSeasonKey = Season.GetContentSeasonKey()
    if targetSeasonKey == UNKNOWN_SEASON then
        targetSeasonKey = history.contentSeasonKey or History.GetDetectedSeasonKey()
    end
    if not Database.IsValidSeasonKey(targetSeasonKey) then return nil end

    local bindingsValid = ValidateSeasonBindings(WarbandRatingsDB.seasons)
    if not bindingsValid then
        History.RecordDiagnostic("seasonBindingRejected")
        return nil
    end

    local oldSeasonKey = history.contentSeasonKey
    if oldSeasonKey and oldSeasonKey ~= targetSeasonKey then
        local oldSeason = WarbandRatingsDB.seasons[oldSeasonKey]
        ArchiveSeason(oldSeason)

        local targetSeason = EnsureSeason(history, targetSeasonKey)
        for charKey, charData in pairs(oldSeason and oldSeason.characters or {}) do
            if not targetSeason.characters[charKey] then
                targetSeason.characters[charKey] = CreateSeasonBaseline(charData, targetSeasonKey)
            end
        end
    end

    local targetSeason = EnsureSeason(history, targetSeasonKey)
    if not targetSeason then return nil end
    history.contentSeasonKey = targetSeasonKey
    return targetSeasonKey
end

local function GetLegacyGlobalStatsFingerprint(stats)
    if type(stats) ~= "table" or stats.ownerCharacterKey then return nil end

    local seasonBest = tonumber(stats.seasonBest) or 0
    local seasonPlayed = tonumber(stats.seasonPlayed) or 0
    local seasonWon = tonumber(stats.seasonWon) or 0
    if seasonBest <= 0 or seasonPlayed <= 0 then return nil end

    return table.concat({ seasonBest, seasonPlayed, seasonWon }, ":")
end

local function MarkMismatchedOwners(characters)
    for charKey, snapshot in pairs(characters or {}) do
        snapshot = type(snapshot) == "table" and snapshot or {}
        for _, stats in pairs(snapshot.pvpStats or {}) do
            if type(stats) == "table"
                and stats.ownerCharacterKey
                and stats.ownerCharacterKey ~= charKey
            then
                stats.seasonTotalsUntrusted = true
                stats.seasonTotalsUntrustedReason = "owner-mismatch"
            end
        end
        for specID, statsByBracket in pairs(snapshot.specPVPStats or {}) do
            if type(statsByBracket) == "table" then
                for _, stats in pairs(statsByBracket) do
                    if type(stats) == "table" then
                        local ownerSpecID = tonumber(stats.ownerSpecID)
                        if (stats.ownerCharacterKey and stats.ownerCharacterKey ~= charKey)
                            or (ownerSpecID and ownerSpecID ~= tonumber(specID))
                        then
                            stats.seasonTotalsUntrusted = true
                            stats.seasonTotalsUntrustedReason = "owner-mismatch"
                        end
                    end
                end
            end
        end
    end
end

local function AuditLegacyGlobalStats(characters)
    MarkMismatchedOwners(characters)

    for _, column in ipairs(Database.GLOBAL_COLUMNS or {}) do
        if Database.IsPVPColumn(column) then
            local groups = {}
            for charKey, snapshot in pairs(characters or {}) do
                snapshot = type(snapshot) == "table" and snapshot or {}
                local stats = snapshot.pvpStats and snapshot.pvpStats[column.key]
                local fingerprint = GetLegacyGlobalStatsFingerprint(stats)
                if fingerprint then
                    groups[fingerprint] = groups[fingerprint] or {}
                    groups[fingerprint][#groups[fingerprint] + 1] = {
                        characterKey = charKey,
                        snapshot = snapshot,
                        stats = stats,
                    }
                end
            end

            for _, entries in pairs(groups) do
                if #entries > 1 then
                    local likelyOwner
                    local likelyOwnerCount = 0
                    for _, entry in ipairs(entries) do
                        local rating = tonumber(
                            entry.snapshot.ratings and entry.snapshot.ratings[column.key]
                        ) or 0
                        if rating > 0 and rating == (tonumber(entry.stats.seasonBest) or 0) then
                            likelyOwner = entry
                            likelyOwnerCount = likelyOwnerCount + 1
                        end
                    end

                    -- Exact best/played/won triples shared by multiple characters
                    -- are only rejected when one unambiguous character currently
                    -- owns that peak. Ambiguous legacy data is preserved.
                    if likelyOwnerCount == 1 then
                        for _, entry in ipairs(entries) do
                            if entry ~= likelyOwner then
                                entry.stats.seasonTotalsUntrusted = true
                                entry.stats.seasonTotalsUntrustedReason = "duplicate-character-cache"
                            end
                        end
                    end
                end
            end
        end
    end
end

function History.AuditPVPStatOwnership()
    EnsureRoot()
    for _, season in pairs(WarbandRatingsDB.seasons or {}) do
        AuditLegacyGlobalStats(season.characters)
    end
end

function History.IsPVPStatsTrusted(stats, characterKey, specID)
    if type(stats) ~= "table" or stats.seasonTotalsUntrusted then return false end
    if stats.ownerCharacterKey
        and characterKey
        and stats.ownerCharacterKey ~= characterKey
    then
        return false
    end

    local ownerSpecID = tonumber(stats.ownerSpecID)
    if ownerSpecID and specID and ownerSpecID ~= tonumber(specID) then
        return false
    end
    return true
end

function History.Init()
    WarbandRatingsDB = WarbandRatingsDB or {}
    local previousCurrentSeasonKey = WarbandRatingsDB.history
        and WarbandRatingsDB.history.currentSeasonKey
    local migrated, migrationError = MigrateSeasonStorage(previousCurrentSeasonKey)
    if not migrated then
        WarbandRatingsDB.storageMigrationError = migrationError
        return false, migrationError
    end

    WarbandRatingsDB.storageMigrationError = nil
    EnsureRoot()
    History.EnsureCurrentSeason()
    if not History.EnsureContentSeason() then
        local bindingError = "season binding validation failed"
        WarbandRatingsDB.storageMigrationError = bindingError
        return false, bindingError
    end
    Database.Migrate()

    for _, season in pairs(WarbandRatingsDB.seasons or {}) do
        ForEachSeries(season, function(series)
            if series and series.archived and series.points and not series.summary then
                series.summary = BuildSummary(series.points)
            end
        end)
    end
    History.AuditPVPStatOwnership()
    return true
end

function History.GetContentSeasonKey()
    local history = EnsureRoot()
    return history.contentSeasonKey or History.EnsureContentSeason()
end

function History.GetAvailableSeasonKeys()
    EnsureRoot()
    local contentSeasonKey = History.GetContentSeasonKey()
    local keys = {}

    for seasonKey, season in pairs(WarbandRatingsDB.seasons or {}) do
        local hasCharacters = next(season.characters or {}) ~= nil
        if seasonKey == contentSeasonKey or hasCharacters then
            keys[#keys + 1] = seasonKey
        end
    end

    local contentIncluded = false
    for _, seasonKey in ipairs(keys) do
        if seasonKey == contentSeasonKey then
            contentIncluded = true
            break
        end
    end
    if not contentIncluded then
        keys[#keys + 1] = contentSeasonKey
    end

    table.sort(keys, function(a, b)
        local aNumber = GetSeasonNumber(a)
        local bNumber = GetSeasonNumber(b)
        if aNumber ~= bNumber then return aNumber > bNumber end
        return a > b
    end)
    return keys
end

local function GetSeriesEndValues(series)
    local points = series and series.points
    if points and #points > 0 then
        local last = points[#points]
        local mmr = 0
        for index = #points, 1, -1 do
            mmr = tonumber(points[index][FIELD_MMR]) or 0
            if mmr > 0 then break end
        end
        return tonumber(last[FIELD_RATING]) or 0, mmr, tonumber(last[FIELD_TIME]) or 0
    end

    local summary = series and series.summary
    if summary then
        return tonumber(summary.finalRating) or 0,
            tonumber(summary.finalMMR) or 0,
            tonumber(summary.sourceLastTime) or 0
    end
    return 0, 0, 0
end

BuildCharacterFromHistory = function(charKey, charHistory, seasonKey)
    local name, realm = tostring(charKey):match("^([^-]+)%-(.+)$")
    local character = {
        name = name or tostring(charKey),
        realm = realm or "Unknown",
        classFilename = "",
        classID = 0,
        level = 0,
        currentSpecID = 0,
        currentSpecRatings = {},
        ratings = {},
        pvpStats = {},
        lastMMR = {},
        specRatings = {},
        specPVPStats = {},
        specLastMMR = {},
        itemCounts = {},
        seasonKey = seasonKey,
        lastUpdated = 0,
        recoveredFromHistory = true,
    }

    for colKey, series in pairs(charHistory.global or {}) do
        local rating, mmr, updated = GetSeriesEndValues(series)
        character.ratings[colKey] = rating
        character.lastMMR[colKey] = mmr
        character.lastUpdated = math.max(character.lastUpdated, updated)
    end
    for specID, specHistory in pairs(charHistory.specs or {}) do
        specID = tonumber(specID) or 0
        character.specRatings[specID] = {}
        character.specLastMMR[specID] = {}
        if character.currentSpecID == 0 and specID > 0 then
            character.currentSpecID = specID
        end
        for colKey, series in pairs(specHistory) do
            local rating, mmr, updated = GetSeriesEndValues(series)
            character.specRatings[specID][colKey] = rating
            character.specLastMMR[specID][colKey] = mmr
            character.lastUpdated = math.max(character.lastUpdated, updated)
        end
    end
    return character
end

function History.GetSeasonCharacters(seasonKey)
    EnsureRoot()
    seasonKey = seasonKey or History.GetContentSeasonKey()
    return Database.GetSeasonCharacters(seasonKey)
end

function History.ArchiveSeason(seasonKey)
    if not Database.IsValidSeasonKey(seasonKey) then return false end
    if seasonKey == History.GetContentSeasonKey() then return false end

    local season = Database.EnsureSeason(seasonKey)
    if not season then return false end
    ArchiveSeason(season)
    return true
end

local function EnsureSeries(charData, col, specID)
    charData.series = charData.series or { global = {}, specs = {} }
    charData.series.global = charData.series.global or {}
    charData.series.specs = charData.series.specs or {}
    if Database.IsSpecColumn(col) then
        specID = tonumber(specID) or 0
        charData.series.specs[specID] = charData.series.specs[specID] or {}
        charData.series.specs[specID][col.key] = charData.series.specs[specID][col.key] or {
            points = {},
            archived = false,
        }
        return charData.series.specs[specID][col.key]
    end

    charData.series.global[col.key] = charData.series.global[col.key] or {
        points = {},
        archived = false,
    }
    return charData.series.global[col.key]
end

local function GetSeries(charData, colKey, specID)
    local allSeries = charData and charData.series
    if not allSeries then return nil end
    specID = tonumber(specID) or 0
    if specID ~= 0
        and allSeries.specs
        and allSeries.specs[specID]
        and allSeries.specs[specID][colKey]
    then
        return allSeries.specs[specID][colKey]
    end
    return allSeries.global and allSeries.global[colKey]
end

local function CopyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function GetCompletedSeriesRating(series, stats, storedRating)
    if not series then return nil end

    local points = series.points or {}
    local summary = series.summary
    local finalRating
    local pointCount
    local lastMatchSequence
    if #points > 0 then
        local last = points[#points]
        finalRating = tonumber(last[FIELD_RATING])
        pointCount = #points
        lastMatchSequence = tonumber(last[FIELD_MATCH_SEQUENCE])
    elseif summary then
        finalRating = tonumber(summary.finalRating)
        pointCount = tonumber(summary.sourcePointCount) or tonumber(summary.games)
    end
    if not finalRating or finalRating <= 0 then return nil end

    local seasonPlayed = tonumber(stats and stats.seasonPlayed)
    local seriesIsComplete = seasonPlayed and seasonPlayed > 0 and (
        (lastMatchSequence and lastMatchSequence == math.floor(seasonPlayed))
        or (not lastMatchSequence and pointCount == math.floor(seasonPlayed))
    )
    local seasonBest = tonumber(stats and stats.seasonBest)
    local liveRatingDriftedPastSeasonBest = seasonBest and seasonBest > 0
        and tonumber(storedRating) and tonumber(storedRating) > seasonBest
        and finalRating <= seasonBest

    if seriesIsComplete or liveRatingDriftedPastSeasonBest then
        return finalRating
    end
    return nil
end

local function BuildSeasonDisplayCharacter(character)
    local display = CopyMap(character)
    display.ratings = CopyMap(character.ratings)
    display.specRatings = {}
    for specID, ratings in pairs(character.specRatings or {}) do
        display.specRatings[specID] = CopyMap(ratings)
    end

    for _, col in ipairs(Database.RATING_COLUMNS or {}) do
        if Database.IsPVPColumn(col) then
            if Database.IsSpecColumn(col) then
                for specID in pairs(character.specRatings or {}) do
                    local copiedRatings = display.specRatings[specID]
                    local statsByBracket = character.specPVPStats and (
                        character.specPVPStats[specID]
                        or character.specPVPStats[tostring(specID)]
                    )
                    local completedRating = GetCompletedSeriesRating(
                        GetSeries(character, col.key, specID),
                        statsByBracket and statsByBracket[col.key],
                        copiedRatings[col.key]
                    )
                    if completedRating then copiedRatings[col.key] = completedRating end
                end
            else
                local completedRating = GetCompletedSeriesRating(
                    GetSeries(character, col.key),
                    character.pvpStats and character.pvpStats[col.key],
                    display.ratings[col.key]
                )
                if completedRating then display.ratings[col.key] = completedRating end
            end
        end
    end
    local currentSpecID = character.currentSpecID
    display.currentSpecRatings = currentSpecID and (
        display.specRatings[currentSpecID]
        or display.specRatings[tostring(currentSpecID)]
    ) or character.currentSpecRatings
    return display
end

function History.GetSeasonDisplayCharacters(seasonKey)
    seasonKey = seasonKey or History.GetContentSeasonKey()
    local characters = History.GetSeasonCharacters(seasonKey)
    local isCurrentActiveSeason = seasonKey == History.GetContentSeasonKey()
        and (not Season.IsRatedSeasonActive or Season.IsRatedSeasonActive() ~= false)
    if isCurrentActiveSeason then return characters end

    local displayCharacters = {}
    for charKey, character in pairs(characters) do
        displayCharacters[charKey] = BuildSeasonDisplayCharacter(character)
    end
    return displayCharacters
end

local function GetPositiveNumber(value)
    value = tonumber(value)
    if value and value > 0 then
        return value
    end
    return nil
end

local function GetMMRDelta(previousPoint, mmr, mmrIsPostMatch)
    mmr = GetPositiveNumber(mmr)
    local previousMMR = GetPositiveNumber(previousPoint and previousPoint[FIELD_MMR])
    if not previousMMR or not mmr or not mmrIsPostMatch or previousPoint[FIELD_MMR_IS_POSTMATCH] ~= true then
        return 0
    end

    return mmr - previousMMR
end

local function RecalculatePointDeltas(points)
    for index, point in ipairs(points or {}) do
        local previousPoint = points[index - 1]
        point[FIELD_RATING_DELTA] = previousPoint
            and ((tonumber(point[FIELD_RATING]) or 0) - (tonumber(previousPoint[FIELD_RATING]) or 0))
            or 0
        point[FIELD_MMR_DELTA] = GetMMRDelta(
            previousPoint,
            point[FIELD_MMR],
            point[FIELD_MMR_IS_POSTMATCH] == true
        )
    end
end

local function NormalizeResult(result)
    result = tonumber(result)
    if result == 0 or result == 1 then
        return result
    end
    return -1
end

local function NormalizeMatchSequence(matchSequence)
    matchSequence = tonumber(matchSequence)
    if matchSequence and matchSequence > 0 then
        return math.floor(matchSequence)
    end
    return 0
end

local function FindPointByMatchSequence(points, matchSequence)
    if matchSequence <= 0 then return nil end

    for index = #points, 1, -1 do
        if tonumber(points[index][FIELD_MATCH_SEQUENCE]) == matchSequence then
            return index
        end
    end
    return nil
end

local function FindInsertionIndex(points, timestamp)
    for index, point in ipairs(points) do
        if timestamp < (tonumber(point[FIELD_TIME]) or 0) then
            return index
        end
    end
    return #points + 1
end

local function GetMMRSource(mmr, mmrIsPostMatch, explicitSource)
    if explicitSource then return explicitSource end
    if not GetPositiveNumber(mmr) then return MMR_SOURCE_PENDING end
    return mmrIsPostMatch and MMR_SOURCE_POSTMATCH or MMR_SOURCE_PREMATCH
end

local function UpdatePoint(
    point,
    timestamp,
    rating,
    mmr,
    result,
    mmrIsPostMatch,
    matchSequence,
    mmrSource,
    specID
)
    point[FIELD_TIME] = math.min(tonumber(point[FIELD_TIME]) or timestamp, timestamp)
    point[FIELD_RATING] = rating

    local positiveMMR = GetPositiveNumber(mmr)
    if positiveMMR then
        point[FIELD_MMR] = positiveMMR
        point[FIELD_MMR_IS_POSTMATCH] = mmrIsPostMatch and true or false
        point[FIELD_MMR_SOURCE] = GetMMRSource(positiveMMR, mmrIsPostMatch, mmrSource)
    elseif not GetPositiveNumber(point[FIELD_MMR]) then
        point[FIELD_MMR] = 0
        point[FIELD_MMR_IS_POSTMATCH] = false
        point[FIELD_MMR_SOURCE] = MMR_SOURCE_PENDING
    end

    local normalizedResult = NormalizeResult(result)
    if normalizedResult ~= -1 or point[FIELD_RESULT] == nil then
        point[FIELD_RESULT] = normalizedResult
    end
    if matchSequence > 0 then
        point[FIELD_MATCH_SEQUENCE] = matchSequence
    elseif point[FIELD_MATCH_SEQUENCE] == nil then
        point[FIELD_MATCH_SEQUENCE] = 0
    end
    specID = tonumber(specID) or 0
    if specID > 0 then
        point[FIELD_SPEC_ID] = specID
    end
end

function History.RecordMatch(
    seasonKey,
    name,
    realm,
    specID,
    bracketIndex,
    rating,
    mmr,
    result,
    timestamp,
    mmrIsPostMatch,
    matchSequence,
    mmrSource
)
    if Database.IsStorageReady and not Database.IsStorageReady() then return false end
    if not Database.IsValidSeasonKey(seasonKey) then return false end
    local col = Database.GetPVPColumnByBracketIndex(bracketIndex)
    if not col then return false end

    rating = tonumber(rating)
    if not rating or rating < 0 then return false end
    mmr = GetPositiveNumber(mmr) or 0

    timestamp = tonumber(timestamp) or time()
    result = NormalizeResult(result)
    mmrIsPostMatch = mmrIsPostMatch and true or false
    matchSequence = NormalizeMatchSequence(matchSequence)
    mmrSource = GetMMRSource(mmr, mmrIsPostMatch, mmrSource)

    local history = EnsureRoot()
    local season = EnsureSeason(history, seasonKey)
    if not season then return false end
    local wasArchived = season.archived and true or false

    local charKey = Utils.CharKey(name, realm)
    local charData = EnsureCharacterHistory(season, charKey)
    if not charData or charData.seasonKey ~= seasonKey then return false end
    charData.name = charData.name or name
    charData.realm = charData.realm or realm
    local series = EnsureSeries(charData, col, specID)
    series.archived = false
    series.points = series.points or {}

    local points = series.points
    local lastPoint = points[#points]
    local existingIndex = FindPointByMatchSequence(points, matchSequence)
    if not existingIndex
        and lastPoint
        and matchSequence == 0
        and (tonumber(lastPoint[FIELD_MATCH_SEQUENCE]) or 0) == 0
        and timestamp >= (tonumber(lastPoint[FIELD_TIME]) or 0)
        and (timestamp - (tonumber(lastPoint[FIELD_TIME]) or 0)) <= DUPLICATE_WINDOW_SECONDS
    then
        existingIndex = #points
    end

    if existingIndex then
        UpdatePoint(
            points[existingIndex],
            timestamp,
            rating,
            mmr,
            result,
            mmrIsPostMatch,
            matchSequence,
            mmrSource,
            specID
        )
        RecalculatePointDeltas(points)
        if wasArchived then ArchiveSeries(series) end
        return true
    end

    local point = {
        timestamp,
        rating,
        mmr,
        0,
        0,
        result,
        mmrIsPostMatch,
        matchSequence,
        mmrSource,
        tonumber(specID) or 0,
    }
    table.insert(points, FindInsertionIndex(points, timestamp), point)
    RecalculatePointDeltas(points)
    if wasArchived then ArchiveSeries(series) end
    return true
end

function History.EnrichPendingMMR(seasonKey, name, realm, specID, bracketIndex, mmr, matchSequence)
    if Database.IsStorageReady and not Database.IsStorageReady() then return false end
    if not Database.IsValidSeasonKey(seasonKey) then return false end
    mmr = GetPositiveNumber(mmr)
    matchSequence = NormalizeMatchSequence(matchSequence)
    if not mmr or matchSequence <= 0 then return false end

    local col = Database.GetPVPColumnByBracketIndex(bracketIndex)
    if not col then return false end

    EnsureRoot()
    local season = WarbandRatingsDB.seasons[seasonKey]
    local charData = season and season.characters and season.characters[Utils.CharKey(name, realm)]
    if charData and charData.seasonKey ~= seasonKey then return false end
    local series = charData and GetSeries(charData, col.key, specID)
    local points = series and series.points
    if not points then return false end

    local pointIndex = FindPointByMatchSequence(points, matchSequence)
    local point = pointIndex and points[pointIndex]
    if not point or GetPositiveNumber(point[FIELD_MMR]) then return false end

    point[FIELD_MMR] = mmr
    point[FIELD_MMR_IS_POSTMATCH] = true
    point[FIELD_MMR_SOURCE] = MMR_SOURCE_NEXT_PREMATCH
    RecalculatePointDeltas(points)
    History.RecordDiagnostic("mmrEnrichedFromNextLobby")
    return true
end

function History.HandleSavedVariablesTooLarge()
    local history = EnsureRoot()
    local activeContentSeasonKey = history.contentSeasonKey or history.currentSeasonKey
    for seasonKey, season in pairs(WarbandRatingsDB.seasons or {}) do
        if seasonKey ~= activeContentSeasonKey then
            ArchiveSeason(season)
        end
    end
    return TrimOldestArchivedRawSeason(history)
end

function History.GetCurrentSeries(charKey, colKey, specID)
    local seasonKey = History.GetContentSeasonKey()
    return History.GetSeriesForSeason(seasonKey, charKey, colKey, specID), seasonKey
end

function History.GetSeriesForSeason(seasonKey, charKey, colKey, specID)
    EnsureRoot()
    local season = WarbandRatingsDB.seasons[seasonKey]
    local charData = season and season.characters and season.characters[charKey]
    if not charData or charData.seasonKey ~= seasonKey then return nil end
    return GetSeries(charData, colKey, specID)
end

local function GetSeriesSummary(series)
    if not series then return nil end
    if series.points and #series.points > 0 then
        local summary = BuildSummary(series.points)
        if series.summary and series.summary.peakSpecID == nil then
            series.summary = summary
        end
        return summary
    end
    return series.summary
end

local function AddCounts(target, source)
    if not source then return end
    target.games = target.games + (tonumber(source.games) or 0)
    target.wins = target.wins + (tonumber(source.wins) or 0)
    target.losses = target.losses + (tonumber(source.losses) or 0)
end

local function AddClass(bracket, classFilename)
    if type(classFilename) == "string" and classFilename ~= "" then
        bracket.classesByFilename[classFilename] = true
    end
end

local function AddClassGames(bracket, classFilename, source)
    AddClass(bracket, classFilename)
    if type(classFilename) ~= "string" or classFilename == "" or not source then return end
    bracket.classGamesByFilename[classFilename] =
        (tonumber(bracket.classGamesByFilename[classFilename]) or 0)
        + (tonumber(source.games) or 0)
end

local function AddSpecCounts(bracket, specID, source, classFilename, maxRating)
    specID = tonumber(specID) or 0
    bracket.specsByID[specID] = bracket.specsByID[specID] or {
        specID = specID,
        classFilename = classFilename,
        maxRating = 0,
        games = 0,
        wins = 0,
        losses = 0,
    }
    if not bracket.specsByID[specID].classFilename then
        bracket.specsByID[specID].classFilename = classFilename
    end
    bracket.specsByID[specID].maxRating = math.max(
        tonumber(bracket.specsByID[specID].maxRating) or 0,
        tonumber(maxRating) or 0
    )
    AddCounts(bracket.specsByID[specID], source)
end

local function GetSeasonStatCounts(stats, useRounds, characterKey, specID)
    if not History.IsPVPStatsTrusted(stats, characterKey, specID) then return nil end

    local playedKey = useRounds and "roundsSeasonPlayed" or "seasonPlayed"
    local wonKey = useRounds and "roundsSeasonWon" or "seasonWon"
    if stats[playedKey] == nil or stats[wonKey] == nil then return nil end

    local games = math.max(tonumber(stats[playedKey]) or 0, 0)
    local wins = math.max(math.min(tonumber(stats[wonKey]) or 0, games), 0)
    return {
        games = games,
        wins = wins,
        losses = math.max(games - wins, 0),
    }
end

local function HasCounts(counts)
    return counts and (
        (tonumber(counts.games) or 0) > 0
        or (tonumber(counts.wins) or 0) > 0
        or (tonumber(counts.losses) or 0) > 0
    )
end

-- A non-nil zero count is authoritative inactivity. History is only a fallback
-- when the season counters are unavailable or untrusted and this value is nil.

local function AddRecordedShuffleFallback(bracket, specID, summary, classFilename, maxRating)
    specID = tonumber(specID) or 0
    bracket.specsByID[specID] = bracket.specsByID[specID] or {
        specID = specID,
        classFilename = classFilename,
        maxRating = 0,
        games = 0,
        wins = 0,
        losses = 0,
    }
    local spec = bracket.specsByID[specID]
    if not spec.classFilename then
        spec.classFilename = classFilename
    end
    spec.maxRating = math.max(tonumber(spec.maxRating) or 0, tonumber(maxRating) or 0)
    spec.recordedGames = (tonumber(spec.recordedGames) or 0) + (tonumber(summary.games) or 0)
    spec.seasonTotalsUnavailable = true
    bracket.partial = true
end

local function UpdateBracketPeakOwner(
    bracket,
    rating,
    specID,
    classFilename,
    characterKey,
    specIsExact
)
    rating = tonumber(rating) or 0
    specID = tonumber(specID) or 0
    local currentRating = tonumber(bracket.maxRating) or 0
    local currentSpecID = tonumber(bracket.maxRatingSpecID) or 0
    local replace = rating > currentRating

    if rating == currentRating then
        if specIsExact and not bracket.maxRatingSpecIsExact then
            replace = true
        elseif specIsExact == bracket.maxRatingSpecIsExact and specID > 0 and currentSpecID <= 0 then
            replace = true
        elseif specIsExact == bracket.maxRatingSpecIsExact
            and (specID > 0) == (currentSpecID > 0)
            and tostring(characterKey or "") < tostring(bracket.maxRatingCharacterKey or "")
        then
            replace = true
        end
    end

    if not replace then return end
    bracket.maxRating = rating
    bracket.maxRatingSpecID = specID
    bracket.maxRatingClassFilename = classFilename
    bracket.maxRatingCharacterKey = characterKey
    bracket.maxRatingSpecIsExact = specIsExact and true or false
end

function History.GetSeasonStatistics(seasonKey)
    EnsureRoot()
    seasonKey = seasonKey or History.GetContentSeasonKey()
    local season = WarbandRatingsDB.seasons[seasonKey]
    local brackets = {}
    local bracketByKey = {}

    for _, column in ipairs(Database.RATING_COLUMNS) do
        if Database.IsPVPColumn(column) then
            local bracket = {
                key = column.key,
                label = column.label,
                bracketIndex = column.bracketIndex,
                perSpec = Database.IsSpecColumn(column),
                unit = column.key == "soloShuffle" and "rounds" or "games",
                total = { games = 0, wins = 0, losses = 0 },
                maxRating = 0,
                maxRatingSpecID = 0,
                classes = {},
                classesByFilename = {},
                classGamesByFilename = {},
                specs = {},
                specsByID = {},
            }
            brackets[#brackets + 1] = bracket
            bracketByKey[column.key] = bracket
        end
    end

    for charKey, snapshot in pairs(season and season.characters or {}) do
        local allSeries = snapshot.series or {}

        for colKey, bracket in pairs(bracketByKey) do
            if not bracket.perSpec then
                local stats = snapshot.pvpStats and snapshot.pvpStats[colKey]
                local statsAreTrusted = History.IsPVPStatsTrusted(stats, charKey)
                local summary = GetSeriesSummary(allSeries.global and allSeries.global[colKey])
                local counts = GetSeasonStatCounts(stats, false, charKey)
                local authoritativeZero = counts and not HasCounts(counts)
                local characterMaxRating = math.max(
                    statsAreTrusted and (tonumber(stats.seasonBest) or 0) or 0,
                    not authoritativeZero
                        and (tonumber(snapshot.ratings and snapshot.ratings[colKey]) or 0)
                        or 0,
                    not authoritativeZero and (tonumber(summary and summary.peakRating) or 0) or 0
                )
                local summaryPeakRating = tonumber(summary and summary.peakRating) or 0
                local summaryPeakSpecID = tonumber(summary and summary.peakSpecID) or 0
                local specIsExact = summaryPeakSpecID > 0 and summaryPeakRating == characterMaxRating
                local maxRatingSpecID = specIsExact
                    and summaryPeakSpecID
                    or tonumber(snapshot.currentSpecID or snapshot.specID) or 0
                UpdateBracketPeakOwner(
                    bracket,
                    characterMaxRating,
                    maxRatingSpecID,
                    snapshot.classFilename,
                    charKey,
                    specIsExact
                )
                if counts then
                    if HasCounts(counts) then
                        AddCounts(bracket.total, counts)
                        AddClassGames(bracket, snapshot.classFilename, counts)
                    end
                else
                    if summary then
                        AddCounts(bracket.total, summary)
                        AddClassGames(bracket, snapshot.classFilename, summary)
                        bracket.partial = true
                    end
                    if stats and not statsAreTrusted then
                        bracket.partial = true
                    end
                end
            end
        end

        local specIDs = {}
        for specID in pairs(snapshot.specPVPStats or {}) do specIDs[specID] = true end
        for specID in pairs(snapshot.specRatings or {}) do specIDs[specID] = true end
        for specID in pairs(allSeries.specs or {}) do specIDs[specID] = true end

        for specID in pairs(specIDs) do
            local specStats = snapshot.specPVPStats and snapshot.specPVPStats[specID]
            local specHistory = allSeries.specs and allSeries.specs[specID]
            for colKey, bracket in pairs(bracketByKey) do
                if bracket.perSpec then
                    local bracketStats = specStats and specStats[colKey]
                    local statsAreTrusted = History.IsPVPStatsTrusted(
                        bracketStats,
                        charKey,
                        specID
                    )
                    local summary = GetSeriesSummary(specHistory and specHistory[colKey])
                    local counts = GetSeasonStatCounts(
                        bracketStats,
                        bracket.unit == "rounds",
                        charKey,
                        specID
                    )
                    local authoritativeZero = counts and not HasCounts(counts)
                    local snapshotRating = not authoritativeZero
                        and snapshot.specRatings
                        and snapshot.specRatings[specID]
                        and snapshot.specRatings[specID][colKey]
                    local maxRating = math.max(
                        statsAreTrusted and (tonumber(bracketStats.seasonBest) or 0) or 0,
                        tonumber(snapshotRating) or 0,
                        not authoritativeZero and (tonumber(summary and summary.peakRating) or 0) or 0
                    )
                    bracket.maxRating = math.max(tonumber(bracket.maxRating) or 0, maxRating)
                    if counts then
                        if HasCounts(counts) then
                            AddCounts(bracket.total, counts)
                            AddSpecCounts(bracket, specID, counts, snapshot.classFilename, maxRating)
                            AddClass(bracket, snapshot.classFilename)
                        end
                    else
                        if summary then
                            if bracket.unit == "rounds" then
                                AddRecordedShuffleFallback(
                                    bracket,
                                    specID,
                                    summary,
                                    snapshot.classFilename,
                                    maxRating
                                )
                            else
                                AddCounts(bracket.total, summary)
                                AddSpecCounts(bracket, specID, summary, snapshot.classFilename, maxRating)
                                bracket.partial = true
                            end
                            AddClass(bracket, snapshot.classFilename)
                        end
                        if bracketStats and not statsAreTrusted then
                            bracket.partial = true
                        end
                    end
                end
            end
        end
    end

    for _, bracket in ipairs(brackets) do
        for classFilename in pairs(bracket.classesByFilename) do
            bracket.classes[#bracket.classes + 1] = classFilename
        end
        table.sort(bracket.classes)
        for classFilename, games in pairs(bracket.classGamesByFilename) do
            games = tonumber(games) or 0
            if games > (tonumber(bracket.mostPlayedGames) or 0)
                or (games == (tonumber(bracket.mostPlayedGames) or 0)
                    and classFilename < tostring(bracket.mostPlayedClassFilename or ""))
            then
                bracket.mostPlayedGames = games
                bracket.mostPlayedClassFilename = classFilename
            end
        end
        for _, specSummary in pairs(bracket.specsByID) do
            bracket.specs[#bracket.specs + 1] = specSummary
        end
        table.sort(bracket.specs, function(a, b)
            local aActivity = math.max(tonumber(a.games) or 0, tonumber(a.recordedGames) or 0)
            local bActivity = math.max(tonumber(b.games) or 0, tonumber(b.recordedGames) or 0)
            if aActivity ~= bActivity then return aActivity > bActivity end
            return a.specID < b.specID
        end)
        bracket.classesByFilename = nil
        bracket.classGamesByFilename = nil
        bracket.specsByID = nil
        bracket.maxRatingCharacterKey = nil
    end
    return brackets
end

local MVSPEC_MIN_RATING = 1000
local MVSPEC_MIN_GAMES = 10
local MVSPEC_MIN_ACTIVE_BRACKETS = 3

local function AddMVSpecBracket(candidate, bracketKey, rating, games)
    rating = tonumber(rating) or 0
    games = tonumber(games) or 0
    if rating <= MVSPEC_MIN_RATING or games <= MVSPEC_MIN_GAMES then return end

    local previousRating = tonumber(candidate.ratingsByBracket[bracketKey]) or 0
    if rating <= previousRating then return end

    candidate.ratingsByBracket[bracketKey] = rating
    candidate.ratingTotal = candidate.ratingTotal - previousRating + rating
    if previousRating == 0 then
        candidate.activeBracketCount = candidate.activeBracketCount + 1
    end
end

local function IsBetterMVSpecCandidate(candidate, current)
    if not current then return true end

    local candidateWeighted = candidate.ratingTotal * current.activeBracketCount
    local currentWeighted = current.ratingTotal * candidate.activeBracketCount
    if candidateWeighted ~= currentWeighted then
        return candidateWeighted > currentWeighted
    end
    if candidate.activeBracketCount ~= current.activeBracketCount then
        return candidate.activeBracketCount > current.activeBracketCount
    end
    return tostring(candidate.specID) < tostring(current.specID)
end

local function GetSpecMapValue(map, specID)
    if type(map) ~= "table" then return nil end
    return map[specID] or map[tostring(specID)]
end

local function EnsureMVSpecCandidate(candidatesBySpecID, specID, classFilename)
    specID = tonumber(specID) or specID
    if not specID or specID == 0 then return nil end

    local candidate = candidatesBySpecID[specID]
    if not candidate then
        candidate = {
            specID = specID,
            classFilename = classFilename,
            ratingTotal = 0,
            activeBracketCount = 0,
            ratingsByBracket = {},
        }
        candidatesBySpecID[specID] = candidate
    elseif not candidate.classFilename then
        candidate.classFilename = classFilename
    end
    return candidate
end

local function GetMVSpecGlobalSpecID(snapshot, stats, column)
    local specID = tonumber(stats and stats.seasonMostPlayedSpecID) or 0
    if specID > 0 then return specID end

    local globalSeries = snapshot.series and snapshot.series.global
    local summary = GetSeriesSummary(globalSeries and globalSeries[column.key])
    specID = tonumber(summary and summary.peakSpecID) or 0
    if specID > 0 then return specID end

    return tonumber(snapshot.currentSpecID or snapshot.specID) or 0
end

function History.GetSeasonMVSpec(seasonKey)
    seasonKey = seasonKey or History.GetContentSeasonKey()
    local candidatesBySpecID = {}

    for charKey, snapshot in pairs(History.GetSeasonCharacters(seasonKey)) do
        local specIDs = {}
        for specID in pairs(snapshot.specRatings or {}) do
            specIDs[tonumber(specID) or specID] = true
        end
        for specID in pairs(snapshot.specPVPStats or {}) do
            specIDs[tonumber(specID) or specID] = true
        end

        for specID in pairs(specIDs) do
            local candidate = EnsureMVSpecCandidate(
                candidatesBySpecID,
                specID,
                snapshot.classFilename
            )

            for _, column in ipairs(Database.SPEC_COLUMNS or {}) do
                if Database.IsPVPColumn(column) then
                    local ratings = GetSpecMapValue(snapshot.specRatings, specID)
                    local statsByBracket = GetSpecMapValue(snapshot.specPVPStats, specID)
                    local rating = ratings and ratings[column.key]
                    local stats = statsByBracket and statsByBracket[column.key]
                    local counts = GetSeasonStatCounts(
                        stats,
                        column.key == "soloShuffle",
                        charKey,
                        specID
                    )
                    AddMVSpecBracket(
                        candidate,
                        column.key,
                        rating,
                        counts and counts.games
                    )
                end
            end
        end

        for _, column in ipairs(Database.GLOBAL_COLUMNS or {}) do
            if Database.IsPVPColumn(column) then
                local stats = snapshot.pvpStats and snapshot.pvpStats[column.key]
                local specID = GetMVSpecGlobalSpecID(snapshot, stats, column)
                local candidate = EnsureMVSpecCandidate(
                    candidatesBySpecID,
                    specID,
                    snapshot.classFilename
                )
                if candidate then
                    local counts = GetSeasonStatCounts(stats, false, charKey)
                    local rating = snapshot.ratings and snapshot.ratings[column.key]
                    AddMVSpecBracket(
                        candidate,
                        column.key,
                        rating,
                        counts and counts.games
                    )
                end
            end
        end
    end

    local winner
    for _, candidate in pairs(candidatesBySpecID) do
        if candidate.activeBracketCount >= MVSPEC_MIN_ACTIVE_BRACKETS
            and IsBetterMVSpecCandidate(candidate, winner)
        then
            winner = candidate
        end
    end
    if winner then
        winner.averageRating = winner.ratingTotal / winner.activeBracketCount
    end
    return winner
end

function History.GetArchivedSummaries(charKey, colKey, specID)
    local history = EnsureRoot()
    local summaries = {}
    local currentSeasonKey = history.contentSeasonKey or history.currentSeasonKey

    for seasonKey, season in pairs(WarbandRatingsDB.seasons or {}) do
        if seasonKey ~= currentSeasonKey and season.archived then
            local charHistory = season.characters and season.characters[charKey]
            local series = charHistory and GetSeries(charHistory, colKey, specID)
            if series and series.summary then
                summaries[#summaries + 1] = {
                    seasonKey = seasonKey,
                    summary = series.summary,
                }
            end
        end
    end

    table.sort(summaries, function(a, b)
        local aNumber = GetSeasonNumber(a.seasonKey)
        local bNumber = GetSeasonNumber(b.seasonKey)
        if aNumber ~= bNumber then
            return aNumber < bNumber
        end
        return a.seasonKey < b.seasonKey
    end)
    return summaries
end
