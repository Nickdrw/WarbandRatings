-- luacheck: globals WarbandRatingsDB CreateFrame GetNumGroupMembers GetMaxBattlefieldID GetBattlefieldStatus

WarbandRatingsDB = { settings = {} }
GetNumGroupMembers = function() return 0 end
GetMaxBattlefieldID = function() return 4 end

local battlefieldStatuses = {
    { "queued", "Random Battleground", 10, false, false, "BATTLEGROUND" },
    { "confirm", "Solo Shuffle", 3, true, false, "RATEDSHUFFLE", nil, nil, false, nil, nil, true },
    { "queued", "Unknown PvP Battle", 10, false, false, "OTHER" },
    { "none" },
}
GetBattlefieldStatus = function(queueIndex)
    return unpack(battlefieldStatuses[queueIndex])
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
local buildCardState = FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState")
assert(scanPVPQueues, "PvP queue scanner should be reachable")
assert(buildCardState, "queue card state builder should be reachable")

local _, activeQueueCount = scanPVPQueues()
assert(activeQueueCount == 3,
    "all occupied battlefield slots should count toward the queue limit")

local bracket = {
    key = "arenaSkirmish",
    category = "unrated",
}
local limitedState = buildCardState(1, bracket, nil, nil, 1, activeQueueCount)
assert(not limitedState.buttonEnabled,
    "a new queue action should be disabled when three battlefield slots are occupied")
assert(limitedState.failureKind == "queueLimit",
    "the disabled card should identify the queue-limit failure")
assert(limitedState.failureReason == "You can queue for up to 3 PvP battles at a time.",
    "the disabled card should explain the three-queue limit")

local existingQueueState = buildCardState(1, bracket, {
    status = "queued",
    bracket = bracket,
}, nil, 1, activeQueueCount)
assert(existingQueueState.visualState == "queued" and not existingQueueState.failureReason,
    "existing queues should retain their normal state at the limit")

print("arena queue limit tests passed")
