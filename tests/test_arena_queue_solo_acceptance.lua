-- luacheck: globals WarbandRatingsDB CreateFrame GetNumGroupMembers GetMaxBattlefieldID
-- luacheck: globals GetBattlefieldStatus AcceptBattlefieldPort hooksecurefunc C_Timer

WarbandRatingsDB = { settings = {} }
GetNumGroupMembers = function() return 0 end
GetMaxBattlefieldID = function() return 1 end
C_Timer = { After = function() end }

local battlefieldStatus = "confirm"
local queueType = "RATEDSHUFFLE"
GetBattlefieldStatus = function()
    return battlefieldStatus, "Solo Shuffle", 0, true, false, queueType
end

AcceptBattlefieldPort = function() end
local battlefieldPortHook
hooksecurefunc = function(functionName, callback)
    assert(functionName == "AcceptBattlefieldPort", "helper should observe battlefield responses")
    battlefieldPortHook = callback
end

CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:RegisterUnitEvent() end
    function frame:SetScript() end
    return frame
end

local ns = {}
assert(loadfile("ArenaQueue.lua"))("WarbandRatings", ns)
assert(battlefieldPortHook, "battlefield response hook should be installed")

local function FindUpvalue(root, targetName, visited)
    if type(root) ~= "function" then return nil end
    visited = visited or {}
    if visited[root] then return nil end
    visited[root] = true

    for upvalueIndex = 1, 100 do
        local name, value = debug.getupvalue(root, upvalueIndex)
        if not name then break end
        if name == targetName then return value end
        if type(value) == "function" then
            local found = FindUpvalue(value, targetName, visited)
            if found then return found end
        end
    end
end

local scanPVPQueues = FindUpvalue(ns.ArenaQueue.Attach, "ScanPVPQueues")
assert(scanPVPQueues, "PvP queue scanner should be reachable")

local function GetSoloQueue()
    local queues = scanPVPQueues()
    return queues.rated.soloShuffle or queues.rated.ratedBGBlitz
end

assert(GetSoloQueue().status == "confirm", "unanswered solo queues should remain match ready")

battlefieldPortHook(1, true)
assert(GetSoloQueue().status == "locked",
    "accepted Solo Shuffle queues should wait for the remaining players")

battlefieldStatus = "queued"
assert(GetSoloQueue().status == "queued", "leaving confirmation should clear the accepted response")
battlefieldStatus = "confirm"
assert(GetSoloQueue().status == "confirm", "a later queue pop should start unanswered")

queueType = "RATEDSOLORBG"
battlefieldPortHook(1, 1)
assert(GetSoloQueue().status == "locked",
    "accepted Solo Battleground queues should wait for the remaining players")

battlefieldPortHook(1, false)
assert(GetSoloQueue().status == "confirm", "declining a solo match should not show a waiting state")

print("arena queue solo-acceptance tests passed")
