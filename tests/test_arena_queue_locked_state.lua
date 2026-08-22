-- luacheck: globals WarbandRatingsDB CreateFrame GetNumGroupMembers

WarbandRatingsDB = { settings = {} }
GetNumGroupMembers = function() return 0 end

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

local buildCardState = FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState")
local updateDynamicCard = FindUpvalue(ns.ArenaQueue.Attach, "UpdateDynamicCard")
assert(buildCardState, "queue card state builder should be reachable")
assert(updateDynamicCard, "dynamic queue card updater should be reachable")

local bracket = {
    key = "arenaSkirmish",
    category = "unrated",
}
local queue = {
    status = "locked",
    bracket = bracket,
}
local state = buildCardState(1, bracket, queue, nil, 1)
assert(state.statusText == "WAITING FOR PLAYERS",
    "locked ready checks should identify that the helper is waiting for players")
assert(state.buttonText == "Waiting",
    "locked ready checks should not label the queue action unavailable")

local queueText = {}
function queueText:SetText(text) self.text = text end
local card = {
    cardState = state,
    minimizedLayout = false,
    queueText = queueText,
    readyGlow = { Hide = function() end },
    progressBg = { Hide = function() end },
    progressFill = { Hide = function() end },
}

updateDynamicCard(card)
assert(queueText.text == "Waiting for other players to accept the match",
    "expanded locked state should explain what the other players must do")

card.minimizedLayout = true
updateDynamicCard(card)
assert(queueText.text == "Waiting for players",
    "minimized locked state should keep a concise waiting message")

print("arena queue locked-state tests passed")
