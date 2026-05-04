local _, ns = ...
ns.History = {}
local History = ns.History
local Database = ns.Database
local Utils = ns.Utils

local UNKNOWN_SEASON = "unknown"
local DUPLICATE_WINDOW_SECONDS = 30
local ARCHIVED_RAW_SEASONS_TO_KEEP = 1

local FIELD_TIME = 1
local FIELD_RATING = 2
local FIELD_MMR = 3
local FIELD_RATING_DELTA = 4
local FIELD_MMR_DELTA = 5
local FIELD_RESULT = 6
local FIELD_MMR_IS_POSTMATCH = 7

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
    WarbandRatingsDB.history = WarbandRatingsDB.history or {}
    local history = WarbandRatingsDB.history
    history.version = history.version or 1
    history.seasons = history.seasons or {}
    return history
end

local function EnsureSeason(history, seasonKey)
    history.seasons[seasonKey] = history.seasons[seasonKey] or {
        archived = false,
        characters = {},
    }
    history.seasons[seasonKey].characters = history.seasons[seasonKey].characters or {}
    return history.seasons[seasonKey]
end

local function UpdateSummaryPeak(summary, rating, mmr)
    rating = tonumber(rating) or 0
    mmr = tonumber(mmr) or 0

    if rating > summary.peakRating then
        summary.peakRating = rating
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
        lowestRating = tonumber(first[FIELD_RATING]) or 0,
        peakMMR = tonumber(first[FIELD_MMR]) or 0,
        finalMMR = tonumber(last[FIELD_MMR]) or 0,
    }

    for _, point in ipairs(points) do
        UpdateSummaryPeak(summary, point[FIELD_RATING], point[FIELD_MMR])
        if point[FIELD_RESULT] == 1 then
            summary.wins = summary.wins + 1
        elseif point[FIELD_RESULT] == 0 then
            summary.losses = summary.losses + 1
        end
    end

    return summary
end

local function ArchiveSeries(series)
    if not series or series.archived then return end

    local summary = BuildSummary(series.points)
    if summary then
        series.summary = summary
        series.archived = true
        series.archivedAt = time()
        series.rawPointsRetained = true
    end
end

local function ArchiveSeason(season)
    if not season or season.archived then return end

    for _, charHistory in pairs(season.characters or {}) do
        for _, series in pairs(charHistory.global or {}) do
            ArchiveSeries(series)
        end
        for _, specHistory in pairs(charHistory.specs or {}) do
            for _, series in pairs(specHistory) do
                ArchiveSeries(series)
            end
        end
    end

    season.archived = true
    season.archivedAt = time()
end

local function ForEachSeries(season, callback)
    if not season then return end

    for _, charHistory in pairs(season.characters or {}) do
        for _, series in pairs(charHistory.global or {}) do
            callback(series)
        end
        for _, specHistory in pairs(charHistory.specs or {}) do
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

local function PruneArchivedRawPoints(history, rawSeasonsToKeep)
    rawSeasonsToKeep = tonumber(rawSeasonsToKeep) or ARCHIVED_RAW_SEASONS_TO_KEEP

    local archivedSeasons = {}
    for seasonKey, season in pairs(history.seasons or {}) do
        if seasonKey ~= history.currentSeasonKey and season.archived then
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
            return aNumber > bNumber
        end
        return a.key > b.key
    end)

    for i, entry in ipairs(archivedSeasons) do
        if i > rawSeasonsToKeep then
            ForEachSeries(entry.season, ClearArchivedRawPoints)
        end
    end
end

function History.EnsureCurrentSeason()
    local history = EnsureRoot()
    local detectedSeasonKey = History.GetDetectedSeasonKey()
    local currentSeasonKey = history.currentSeasonKey

    if currentSeasonKey == UNKNOWN_SEASON and detectedSeasonKey ~= UNKNOWN_SEASON then
        if history.seasons[UNKNOWN_SEASON] and not history.seasons[detectedSeasonKey] then
            history.seasons[detectedSeasonKey] = history.seasons[UNKNOWN_SEASON]
            history.seasons[UNKNOWN_SEASON] = nil
        end
        currentSeasonKey = detectedSeasonKey
    elseif not currentSeasonKey then
        currentSeasonKey = detectedSeasonKey
    elseif detectedSeasonKey ~= UNKNOWN_SEASON and detectedSeasonKey ~= currentSeasonKey then
        ArchiveSeason(history.seasons[currentSeasonKey])
        currentSeasonKey = detectedSeasonKey
    end

    history.currentSeasonKey = currentSeasonKey
    EnsureSeason(history, currentSeasonKey)
    PruneArchivedRawPoints(history)
    return currentSeasonKey
end

function History.Init()
    History.EnsureCurrentSeason()
end

local function EnsureCharacterHistory(season, charKey)
    season.characters[charKey] = season.characters[charKey] or {
        global = {},
        specs = {},
    }
    local charHistory = season.characters[charKey]
    charHistory.global = charHistory.global or {}
    charHistory.specs = charHistory.specs or {}
    return charHistory
end

local function EnsureSeries(charHistory, col, specID)
    if Database.IsSpecColumn(col) then
        specID = tonumber(specID) or 0
        charHistory.specs[specID] = charHistory.specs[specID] or {}
        charHistory.specs[specID][col.key] = charHistory.specs[specID][col.key] or {
            points = {},
            archived = false,
        }
        return charHistory.specs[specID][col.key]
    end

    charHistory.global[col.key] = charHistory.global[col.key] or {
        points = {},
        archived = false,
    }
    return charHistory.global[col.key]
end

local function GetSeries(charHistory, colKey, specID)
    specID = tonumber(specID) or 0
    if specID ~= 0 and charHistory.specs and charHistory.specs[specID] and charHistory.specs[specID][colKey] then
        return charHistory.specs[specID][colKey]
    end
    return charHistory.global and charHistory.global[colKey]
end

local function GetMMRDelta(previousPoint, mmr, mmrIsPostMatch)
    if not previousPoint or not mmrIsPostMatch or previousPoint[FIELD_MMR_IS_POSTMATCH] ~= true then
        return 0
    end

    return mmr - (tonumber(previousPoint[FIELD_MMR]) or 0)
end

function History.RecordMatch(name, realm, specID, bracketIndex, rating, mmr, result, timestamp, mmrIsPostMatch)
    local col = Database.GetPVPColumnByBracketIndex(bracketIndex)
    if not col then return false end

    rating = tonumber(rating) or 0
    mmr = tonumber(mmr)
    if not mmr or mmr <= 0 then return false end

    timestamp = tonumber(timestamp) or time()
    result = tonumber(result)
    if result ~= 0 and result ~= 1 then
        result = -1
    end
    mmrIsPostMatch = mmrIsPostMatch and true or false

    local history = EnsureRoot()
    local seasonKey = History.EnsureCurrentSeason()
    local season = EnsureSeason(history, seasonKey)
    season.archived = false

    local charKey = Utils.CharKey(name, realm)
    local charHistory = EnsureCharacterHistory(season, charKey)
    local series = EnsureSeries(charHistory, col, specID)
    series.archived = false
    series.points = series.points or {}

    local points = series.points
    local lastPoint = points[#points]
    if lastPoint and (timestamp - (lastPoint[FIELD_TIME] or 0)) <= DUPLICATE_WINDOW_SECONDS then
        local previousPoint = points[#points - 1]
        lastPoint[FIELD_TIME] = timestamp
        lastPoint[FIELD_RATING] = rating
        lastPoint[FIELD_MMR] = mmr
        lastPoint[FIELD_RATING_DELTA] = previousPoint and (rating - (tonumber(previousPoint[FIELD_RATING]) or 0)) or 0
        lastPoint[FIELD_MMR_DELTA] = GetMMRDelta(previousPoint, mmr, mmrIsPostMatch)
        lastPoint[FIELD_RESULT] = result
        lastPoint[FIELD_MMR_IS_POSTMATCH] = mmrIsPostMatch
        return true
    end

    local ratingDelta = lastPoint and (rating - (tonumber(lastPoint[FIELD_RATING]) or 0)) or 0
    local mmrDelta = GetMMRDelta(lastPoint, mmr, mmrIsPostMatch)
    points[#points + 1] = { timestamp, rating, mmr, ratingDelta, mmrDelta, result, mmrIsPostMatch }
    return true
end

function History.HandleSavedVariablesTooLarge()
    local history = EnsureRoot()
    for seasonKey, season in pairs(history.seasons or {}) do
        if seasonKey ~= history.currentSeasonKey then
            ArchiveSeason(season)
        end
    end
    PruneArchivedRawPoints(history, 0)
end

function History.GetCurrentSeries(charKey, colKey, specID)
    local history = EnsureRoot()
    local seasonKey = History.EnsureCurrentSeason()
    local season = history.seasons[seasonKey]
    local charHistory = season and season.characters and season.characters[charKey]
    if not charHistory then return nil, seasonKey end
    return GetSeries(charHistory, colKey, specID), seasonKey
end

function History.GetArchivedSummaries(charKey, colKey, specID)
    local history = EnsureRoot()
    local summaries = {}
    local currentSeasonKey = history.currentSeasonKey

    for seasonKey, season in pairs(history.seasons or {}) do
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
