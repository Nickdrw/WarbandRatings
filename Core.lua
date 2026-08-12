local _, ns = ...

-- luacheck: globals GetBuildInfo

local Database = ns.Database
local DataCollection = ns.DataCollection
local History = ns.History
local Season = ns.Season
local SPEC_RATED_INFO_REQUEST_DELAY = 1
local databaseReady = false

local function CallUI(method, ...)
    local UI = ns.UI
    if UI and UI[method] then
        return UI[method](...)
    end
end

local function ChatMessage(message)
    local text = ns.DISPLAY_NAME .. ": " .. tostring(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif print then
        print(text)
    end
end

local function FormatValue(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function DumpSeasonApiDiagnostics()
    local buildVersion
    if GetBuildInfo then
        buildVersion = select(4, GetBuildInfo())
    end
    ChatMessage("api probe start")
    ChatMessage("build=" .. FormatValue(buildVersion))
    ChatMessage(
        "season ids currentArena="
            .. FormatValue(GetCurrentArenaSeason and GetCurrentArenaSeason())
            .. " uiDisplay="
            .. FormatValue(C_PvP and C_PvP.GetUIDisplaySeason and C_PvP.GetUIDisplaySeason())
            .. " seasonInfo="
            .. FormatValue(
                C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID
                    and C_SeasonInfo.GetCurrentDisplaySeasonID()
            )
    )
    ChatMessage(
        "content season addon="
            .. FormatValue(Season and Season.GetContentSeasonKey and Season.GetContentSeasonKey())
            .. " history="
            .. FormatValue(History and History.GetContentSeasonKey and History.GetContentSeasonKey())
            .. " ratedActive="
            .. FormatValue(Season and Season.IsRatedSeasonActive and Season.IsRatedSeasonActive())
    )

    local availableSeasonKeys = History and History.GetAvailableSeasonKeys and History.GetAvailableSeasonKeys() or {}
    ChatMessage("available seasons=" .. table.concat(availableSeasonKeys, ", "))

    for _, bracketIndex in ipairs({ 1, 2, 4, 7, 9 }) do
        local ok, rating, seasonBest, weeklyBest, seasonPlayed, seasonWon, weeklyPlayed, weeklyWon,
            _, _, _, _, roundsSeasonPlayed, roundsSeasonWon, roundsWeeklyPlayed, roundsWeeklyWon =
            pcall(GetPersonalRatedInfo, bracketIndex)
        if ok then
            ChatMessage(
                "bracket "
                    .. bracketIndex
                    .. " rating="
                    .. FormatValue(rating)
                    .. " seasonBest="
                    .. FormatValue(seasonBest)
                    .. " seasonPlayed="
                    .. FormatValue(seasonPlayed)
                    .. " seasonWon="
                    .. FormatValue(seasonWon)
                    .. " weeklyBest="
                    .. FormatValue(weeklyBest)
                    .. " weeklyPlayed="
                    .. FormatValue(weeklyPlayed)
                    .. " weeklyWon="
                    .. FormatValue(weeklyWon)
                    .. " roundsSeasonPlayed="
                    .. FormatValue(roundsSeasonPlayed)
                    .. " roundsSeasonWon="
                    .. FormatValue(roundsSeasonWon)
                    .. " roundsWeeklyPlayed="
                    .. FormatValue(roundsWeeklyPlayed)
                    .. " roundsWeeklyWon="
                    .. FormatValue(roundsWeeklyWon)
            )
        else
            ChatMessage("bracket " .. bracketIndex .. " error=" .. FormatValue(rating))
        end
    end

    ChatMessage("api probe end")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CRITERIA_UPDATE")
eventFrame:RegisterEvent("PVP_RATED_STATS_UPDATE")
eventFrame:RegisterEvent("ARENA_SEASON_WORLD_STATE")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventFrame:RegisterEvent("PVP_MATCH_ACTIVE")
eventFrame:RegisterEvent("PVP_MATCH_COMPLETE")
eventFrame:RegisterEvent("PVP_MATCH_INACTIVE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
eventFrame:RegisterEvent("SAVED_VARIABLES_TOO_LARGE")

local function TryCollectLastMatchMMRWithRetries(recordHistory)
    if DataCollection.CollectLastMatchMMR(recordHistory) then
        CallUI("RefreshTable")
    end

    local delays = { 0.25, 0.75, 1.5, 3, 6, 10 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if DataCollection.CollectLastMatchMMR(recordHistory) then
                CallUI("RefreshTable")
            end
        end)
    end
end

local function TryCaptureActiveMatchMMRWithRetries()
    if DataCollection.CaptureActiveMatchMMR() then
        CallUI("RefreshTable")
    end

    local delays = { 0.25, 0.75, 1.5, 3 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if DataCollection.CaptureActiveMatchMMR() then
                CallUI("RefreshTable")
            end
        end)
    end
end

local function RefreshHeliotropeCounts()
    DataCollection.CollectCurrentCharacter()
    DataCollection.ScanWarbandBankHeliotrope()
    CallUI("RefreshHeliotropeCounter")
end

local function CollectPreseasonCharacter()
    if DataCollection.CollectPreseasonCharacter then
        return DataCollection.CollectPreseasonCharacter()
    end
end

local function IsPVPMatchActive()
    if not C_PvP or not C_PvP.GetActiveMatchState then return false end

    local ok, state = pcall(C_PvP.GetActiveMatchState)
    local activeState = Enum and Enum.PvPMatchState and Enum.PvPMatchState.Active or 1
    return ok and state == activeState
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        local initialized, migrationError = History.Init()
        if not initialized then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage(
                    ns.DISPLAY_NAME
                        .. ": season data migration failed; collection was disabled to protect your saved data. "
                        .. tostring(migrationError or "unknown error")
                )
            end
            return
        end
        Database.Init()
        databaseReady = true

        -- Request PvP data from server; ratings may not be available immediately
        DataCollection.RequestRatedInfo()

        -- Collect after a short delay to let PvP data load
        C_Timer.After(3, function()
            DataCollection.CollectCurrentCharacter()
            CollectPreseasonCharacter()
            DataCollection.ScanWarbandBankHeliotrope()
            CallUI("RefreshTable")
        end)

        CallUI("AttachGroupFinderButtons")
        CallUI("CreateMinimapButton")
        CallUI("RegisterAddonSettings")
        CallUI("UpdateCompartmentVisibility")

    elseif not databaseReady then
        return

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Request achievement/statistics data from server so GetStatistic() returns real values.
        -- The server responds with CRITERIA_UPDATE, which will trigger a re-collect.
        if RequestAchievementData then
            RequestAchievementData()
        end

        DataCollection.UpdateActivePVPContext()
        if IsPVPMatchActive() then
            DataCollection.BeginRatedMatch()
            TryCaptureActiveMatchMMRWithRetries()
        else
            C_Timer.After(1, function()
                TryCollectLastMatchMMRWithRetries(true)
            end)
        end

    elseif event == "CRITERIA_UPDATE" then
        -- Statistics are now available from the server; update HK and other stat columns.
        DataCollection.CollectCurrentCharacter()
        CallUI("RefreshTable")

    elseif event == "PVP_RATED_STATS_UPDATE" then
        DataCollection.MarkRatedStatsUpdated()
        DataCollection.UpdateActivePVPContext()
        -- Re-collect when PvP stats arrive
        C_Timer.After(0.5, function()
            DataCollection.CollectCurrentCharacter()
            CollectPreseasonCharacter()
            CallUI("RefreshTable")
        end)

        TryCollectLastMatchMMRWithRetries(true)

    elseif event == "ARENA_SEASON_WORLD_STATE" then
        DataCollection.MarkRatedStatsStale()
        DataCollection.RequestRatedInfo()
        CallUI("RefreshTable")

    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        local expectedSpecID = DataCollection.MarkRatedStatsStale()
        DataCollection.UpdateActivePVPContext()
        C_Timer.After(SPEC_RATED_INFO_REQUEST_DELAY, function()
            DataCollection.RequestRatedInfo(expectedSpecID)
        end)
        -- Re-collect non-PvP data immediately; cumulative PvP statistics and
        -- spec ratings stay gated until the active character/spec cache is fresh.
        C_Timer.After(0.5, function()
            DataCollection.CollectCurrentCharacter()
            CallUI("RefreshTable")
        end)

    elseif event == "BAG_UPDATE_DELAYED"
        or event == "BANKFRAME_OPENED"
        or event == "PLAYERBANKSLOTS_CHANGED"
        or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        RefreshHeliotropeCounts()
        if event == "BANKFRAME_OPENED" then
            C_Timer.After(0.5, RefreshHeliotropeCounts)
        end

    elseif event == "PVP_MATCH_ACTIVE" then
        DataCollection.UpdateActivePVPContext()
        DataCollection.BeginRatedMatch(true)
        TryCaptureActiveMatchMMRWithRetries()

    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        DataCollection.UpdateActivePVPContext()
        if DataCollection.CaptureActiveMatchMMR() then
            CallUI("RefreshTable")
        end

    elseif event == "PVP_MATCH_COMPLETE" then
        DataCollection.UpdateActivePVPContext()
        DataCollection.MarkRatedMatchComplete(arg1, arg2)
        TryCaptureActiveMatchMMRWithRetries()

    elseif event == "PVP_MATCH_INACTIVE" then
        DataCollection.UpdateActivePVPContext()
        DataCollection.MarkRatedMatchInactive()
        TryCollectLastMatchMMRWithRetries(true)

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        DataCollection.UpdateActivePVPContext()
        TryCollectLastMatchMMRWithRetries(true)

    elseif event == "SAVED_VARIABLES_TOO_LARGE" then
        if not arg1 or arg1 == "WarbandRatings" or arg1 == "WarbandRatingsDB" then
            local trimmedSeasonKey = History.HandleSavedVariablesTooLarge()
            if DEFAULT_CHAT_FRAME then
                if trimmedSeasonKey then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        ns.DISPLAY_NAME
                            .. ": raw graph points for the oldest archived season ("
                            .. trimmedSeasonKey
                            .. ") were trimmed; its summary was kept."
                    )
                else
                    DEFAULT_CHAT_FRAME:AddMessage(
                        ns.DISPLAY_NAME .. ": no archived raw graph points were available to trim."
                    )
                end
            end
        end
    end
end)

-- Keep the legacy aliases so existing macros continue to work.
SLASH_WARBANDRATINGS1 = "/warbandpvpcompanion"
SLASH_WARBANDRATINGS2 = "/wpc"
SLASH_WARBANDRATINGS3 = "/warbandratings"
SLASH_WARBANDRATINGS4 = "/wr"
SlashCmdList["WARBANDRATINGS"] = function(msg)
    local command = (msg or ""):match("^%s*(%S+)")
    command = command and command:lower() or ""
    if command == "api" or command == "diag" or command == "debug" then
        DumpSeasonApiDiagnostics()
        return
    end
    CallUI("Toggle")
end

-- Addon Compartment callbacks
function WarbandRatings_OnAddonCompartmentClick()
    CallUI("Toggle")
end

function WarbandRatings_OnAddonCompartmentEnter(_, btn)
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.DISPLAY_NAME)
    GameTooltip:AddLine("Click to toggle window", 1, 1, 1)
    GameTooltip:Show()
end

function WarbandRatings_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
