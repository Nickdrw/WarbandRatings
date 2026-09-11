-- luacheck: globals WarbandRatingsDB CreateFrame UnitGUID UnitName GetNormalizedRealmName
-- luacheck: globals GetSpecialization GetSpecializationInfo

WarbandRatingsDB = { settings = {} }

local eventFrame
CreateFrame = function()
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:RegisterUnitEvent() end
    function frame:SetScript(script, handler)
        frame.scripts[script] = handler
        if script == "OnEvent" then eventFrame = frame end
    end
    return frame
end

UnitGUID = function() return "Player-123" end
UnitName = function() return "Tester" end
GetNormalizedRealmName = function() return "Realm" end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 270 end

local character = {
    lastMMR = { arena2v2 = 1838 },
    specLastMMR = { [270] = { soloShuffle = 1700 } },
}
local ns = {
    Utils = {
        CharKey = function(name, realm) return name .. "-" .. realm end,
    },
    Database = {
        GetCurrentCharacters = function() return { ["Tester-Realm"] = character } end,
    },
}

assert(loadfile("ArenaQueue.lua"))("WarbandRatings", ns)
assert(eventFrame and eventFrame.scripts.OnEvent, "queue event handler should be registered")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD", nil, false)

local arena = { key = "arena2v2", databaseKey = "arena2v2" }
local shuffle = { key = "soloShuffle", databaseKey = "soloShuffle" }
assert(ns.ArenaQueue.GetLastMMRInfo(arena).delta == 0,
    "the first MMR read of a new session should establish its baseline")
assert(ns.ArenaQueue.GetLastMMRInfo(shuffle).delta == 0,
    "the first spec MMR read of a new session should establish its baseline")

character.lastMMR.arena2v2 = 1861
character.specLastMMR[270].soloShuffle = 1684
assert(ns.ArenaQueue.GetLastMMRInfo(arena).delta == 23,
    "arena MMR delta should be measured from the session baseline")
assert(ns.ArenaQueue.GetLastMMRInfo(shuffle).delta == -16,
    "spec MMR delta should be measured from the session baseline")

local session = WarbandRatingsDB.settings.arenaQueueRatingSessions["Player-123"]
assert(session.mmrBaselines.arena2v2 == 1838 and session.mmrBaselines["soloShuffle:270"] == 1700,
    "MMR baselines should be persisted to survive a UI reload")

print("arena queue MMR session tests passed")
