-- luacheck: globals C_CurrencyInfo

local ns = {
    Database = {},
    DataCollection = {},
    History = {},
    Utils = {},
}

function ns.Utils.IsEmptyRating(value)
    return not value or value == 0
end

function ns.Utils.FormatRating(value)
    return ns.Utils.IsEmptyRating(value) and "-" or tostring(value)
end

assert(loadfile("UI.lua"))("WarbandRatings", ns)

local conquestColumn = { key = "conquest" }
local cappedRatings = {
    conquest_totalEarned = 1600,
    conquest_maxQuantity = 1600,
}
local cappedText = ns.UI.FormatGlobalColumnValue(conquestColumn, cappedRatings, 725)
assert(cappedText:find("ReadyCheck%-Ready", 1) and cappedText:sub(-3) == "725",
    "capped Conquest should show a checkmark before the wallet value")

local spentCappedText = ns.UI.FormatGlobalColumnValue(conquestColumn, cappedRatings, 0)
assert(spentCappedText:find("ReadyCheck%-Ready", 1),
    "spending Conquest should not remove the earned-cap marker")

C_CurrencyInfo = {
    GetCurrencyInfo = function()
        return { maxQuantity = 0 }
    end,
}
local removedCapText = ns.UI.FormatGlobalColumnValue(conquestColumn, cappedRatings, 725)
assert(removedCapText == "725",
    "removing the live Conquest cap should clear stale markers from saved characters")
C_CurrencyInfo = nil

local uncappedText = ns.UI.FormatGlobalColumnValue(conquestColumn, {
    conquest_totalEarned = 1599,
    conquest_maxQuantity = 1600,
}, 725)
assert(uncappedText == "725", "uncapped Conquest should keep the normal table value")

local unknownCapText = ns.UI.FormatGlobalColumnValue(conquestColumn, {
    conquest_totalEarned = 1600,
    conquest_maxQuantity = 0,
}, 725)
assert(unknownCapText == "725", "missing cap data should not produce a false marker")

local otherColumnText = ns.UI.FormatGlobalColumnValue({ key = "honor" }, cappedRatings, 725)
assert(otherColumnText == "725", "the Conquest cap marker should not affect other currencies")

print("UI Conquest-cap tests passed")
