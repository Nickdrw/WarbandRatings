-- luacheck: globals CreateFrame C_Timer SlashCmdList DEFAULT_CHAT_FRAME

local eventFrame
CreateFrame = function()
    eventFrame = {}
    function eventFrame:RegisterEvent() end
    function eventFrame:SetScript(_, callback) self.onEvent = callback end
    return eventFrame
end

local timers = {}
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
    end,
}
SlashCmdList = {}
local messages = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message) messages[#messages + 1] = message end,
}

local collections, bankScans, tableRefreshes, counterRefreshes = 0, 0, 0, 0
local ns = {
    DISPLAY_NAME = "Warband PvP Companion",
    Database = { Init = function() end },
    History = { Init = function() return true end },
    Season = {},
    DataCollection = {
        RequestRatedInfo = function() end,
        CollectCurrentCharacter = function() collections = collections + 1 end,
        CollectPreseasonCharacter = function() end,
        ScanWarbandBankHeliotrope = function() bankScans = bankScans + 1 end,
    },
    UI = {
        RefreshTable = function() tableRefreshes = tableRefreshes + 1 end,
        RefreshHeliotropeCounter = function() counterRefreshes = counterRefreshes + 1 end,
    },
}
assert(loadfile("Core.lua"))("WarbandRatings", ns)
local function Event(name, arg)
    eventFrame:onEvent(name, arg)
end

Event("PLAYER_LOGIN")
timers = {}
Event("CRITERIA_UPDATE")
Event("CRITERIA_UPDATE")
Event("BAG_UPDATE_DELAYED")
Event("PLAYERBANKSLOTS_CHANGED")
assert(#timers == 1, "related collection events scheduled duplicate refreshes")
timers[1].callback()
assert(collections == 1 and bankScans == 1,
    "combined refresh did not collect and scan the bank exactly once")
assert(tableRefreshes == 1 and counterRefreshes == 1,
    "combined refresh did not update the visible UI exactly once")

Event("CRITERIA_UPDATE")
assert(#timers == 2, "later criteria update did not schedule a new refresh")
Event("SAVED_VARIABLES_TOO_LARGE", "WarbandRatingsDB")
timers[2].callback()
Event("CRITERIA_UPDATE")
assert(collections == 1 and #timers == 2,
    "collection continued after the saved-variable load failed")
assert(#messages == 1 and messages[1]:find("could not be loaded", 1, true),
    "oversized SavedVariables did not report the load failure")

local initCount = 0
ns.History.Init = function()
    initCount = initCount + 1
    return true
end
assert(loadfile("Core.lua"))("WarbandRatings", ns)
Event("SAVED_VARIABLES_TOO_LARGE", "WarbandRatingsDB")
Event("PLAYER_LOGIN")
assert(initCount == 0,
    "a pre-login SavedVariables load failure still initialized an empty database")

print("core refresh tests passed")
