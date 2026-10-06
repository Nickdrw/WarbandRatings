-- luacheck: globals GetCurrentRegion time

time = os.time
local region = 3
GetCurrentRegion = function() return region end

local ns = {}
assert(loadfile("Season.lua"))("WarbandRatings", ns)

local function IsDate(timestamp, year, month, day)
    local parts = os.date("*t", timestamp)
    return parts.year == year and parts.month == month and parts.day == day
end

assert(IsDate(ns.Season.GetPVPSeasonStartTime("pvp-41"), 2026, 3, 18),
    "European Season 1 should begin on its regional PvP launch date")
assert(IsDate(ns.Season.GetPVPSeasonStartTime("pvp-42"), 2026, 8, 19),
    "European Season 2 should begin on its regional PvP launch date")
region = 1
assert(IsDate(ns.Season.GetPVPSeasonStartTime("pvp-41"), 2026, 3, 17),
    "US Season 1 should use its regional launch date")
assert(IsDate(ns.Season.GetPVPSeasonStartTime("pvp-42"), 2026, 8, 18),
    "US Season 2 should use its regional launch date")
assert(ns.Season.GetPVPSeasonStartTime("pvp-43") == nil,
    "unknown seasons should not receive a guessed start date")
assert(ns.Season.GetPVPSeasonStartTime("pvp-42", 2) == nil,
    "regions without a confirmed date should not offer season alignment")

print("season comparison tests passed")
