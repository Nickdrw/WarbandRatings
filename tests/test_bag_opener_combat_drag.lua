-- luacheck: globals CreateFrame InCombatLockdown C_Timer

local inCombat = false
InCombatLockdown = function() return inCombat end
local eventFrame
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript(_, callback) self.onEvent = callback end
    eventFrame = frame
    return frame
end
C_Timer = { After = function() end }

local ns = {
    Database = {
        FIELD_MEDIC_HAZARD_PAYOUT_ITEM_IDS = {},
        ILLUSTRIOUS_CONTENDER_STRONGBOX_ITEM_ID = 1,
    },
    HelperPanel = {
        SnapFrameToPixelGrid = function() end,
    },
}
assert(loadfile("BagOpener.lua"))("WarbandRatings", ns)

local function FindUpvalue(root, targetName, visited)
    if type(root) ~= "function" then return nil end
    visited = visited or {}
    if visited[root] then return nil end
    visited[root] = true
    for index = 1, 100 do
        local name, value = debug.getupvalue(root, index)
        if not name then break end
        if name == targetName then return value end
        if type(value) == "function" then
            local found = FindUpvalue(value, targetName, visited)
            if found then return found end
        end
    end
end

local function SetUpvalue(root, targetName, value)
    for index = 1, 100 do
        local name = debug.getupvalue(root, index)
        if not name then break end
        if name == targetName then
            debug.setupvalue(root, index, value)
            return true
        end
    end
end

local startMove = FindUpvalue(ns.BagOpener.Attach, "StartPanelMove")
local stopMove = FindUpvalue(ns.BagOpener.Attach, "StopPanelMove")
assert(startMove and stopMove, "bag panel drag handlers should be reachable")
local starts, stops = 0, 0
local panel = {
    StartMoving = function() starts = starts + 1 end,
    StopMovingOrSizing = function() stops = stops + 1 end,
}
assert(SetUpvalue(startMove, "panel", panel))

inCombat = true
startMove()
assert(starts == 0, "bag panel drag started in combat")
inCombat = false
startMove()
assert(starts == 1, "bag panel drag did not start out of combat")
inCombat = true
stopMove()
assert(stops == 0, "bag panel movement was changed in combat")
inCombat = false
eventFrame:onEvent("PLAYER_REGEN_ENABLED")
assert(stops == 1, "bag panel drag was not finalized when combat ended")

print("bag opener combat drag tests passed")
