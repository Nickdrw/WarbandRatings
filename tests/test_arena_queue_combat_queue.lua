-- luacheck: globals WarbandRatingsDB CreateFrame GetNumGroupMembers InCombatLockdown HonorFrame HonorFrameQueueButton

local inCombat = false
WarbandRatingsDB = { settings = {} }
GetNumGroupMembers = function() return 0 end
InCombatLockdown = function() return inCombat end

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

local function SetUpvalue(root, targetName, value)
    for upvalueIndex = 1, 100 do
        local name = debug.getupvalue(root, upvalueIndex)
        if not name then break end
        if name == targetName then
            debug.setupvalue(root, upvalueIndex, value)
            return true
        end
    end
    return false
end

local function NewSecureButton(attributes)
    local button = { attributes = attributes or {} }
    function button:GetAttribute(name) return self.attributes[name] end
    function button:SetAttribute(name, value) self.attributes[name] = value end
    return button
end

local buildCardState = FindUpvalue(ns.ArenaQueue.Attach, "BuildCardState")
local configureSecureBracket = FindUpvalue(ns.ArenaQueue.Attach, "ConfigureSecureBracket")
assert(buildCardState, "queue card state builder should be reachable")
assert(configureSecureBracket, "secure queue configurator should be reachable")

local bracket = {
    key = "arenaSkirmish",
    category = "unrated",
    targetKey = "Arena1Button",
}
local target = {}
HonorFrame = { BonusFrame = { Arena1Button = target } }
HonorFrameQueueButton = {}

local queueMacro = "/click WarbandRatingsUnratedQueueProxy1 LeftButton\n/click HonorFrameQueueButton LeftButton"
local actionButton = NewSecureButton({
    configuredBracketKey = bracket.key,
    type = "macro",
    macrotext = queueMacro,
})
local proxy = NewSecureButton({
    configuredBracketKey = bracket.key,
    clickbutton = target,
})
local card = {
    secureActionButtons = { unrated = actionButton },
}
assert(SetUpvalue(configureSecureBracket, "panel", { cards = { card } }),
    "test should install the prepared queue card")

local bracketProxies = FindUpvalue(configureSecureBracket, "bracketProxies")
assert(bracketProxies and bracketProxies.unrated,
    "secure queue proxy table should be reachable")
bracketProxies.unrated[1] = proxy

local queuedState = buildCardState(1, bracket, {
    status = "queued",
    bracket = bracket,
}, nil, 1)
assert(not queuedState.buttonVisible, "active queues should continue hiding the queue action")
assert(actionButton:GetAttribute("type") == "macro",
    "active queues should preserve the prepared action for combat use")

inCombat = true
local readyState = buildCardState(1, bracket, nil, nil, 1)
assert(readyState.buttonEnabled,
    "a prepared queue action should become available when the queue ends in combat")
assert(not readyState.failureReason,
    "combat should not report prepared PvP queue controls as unavailable")

print("arena queue combat-queue tests passed")
