-- luacheck: globals time GetCurrentArenaSeason

local now = 1000
time = function() return now end
GetCurrentArenaSeason = function() return 41 end

local specColumn = { key = "soloShuffle", bracketIndex = 7 }
local globalColumn = { key = "arena2v2", bracketIndex = 1 }
local ns = {
    Utils = {
        CharKey = function(name, realm)
            return name .. "-" .. realm
        end,
    },
    Database = {
        SPEC_COLUMNS = { specColumn },
        GLOBAL_COLUMNS = { globalColumn },
        IsSpecColumn = function(col)
            return col == specColumn
        end,
        GetPVPColumnByBracketIndex = function(bracketIndex)
            if bracketIndex == 7 then return specColumn end
            if bracketIndex == 1 then return globalColumn end
        end,
    },
}

WarbandRatingsDB = {
    characters = {},
}

assert(loadfile("History.lua"))("WarbandRatings", ns)
local History = ns.History
History.Init()

assert(History.RecordMatch(
    "Tester",
    "Realm",
    71,
    7,
    1500,
    nil,
    1,
    100,
    false,
    10,
    "pending"
))

local series = History.GetCurrentSeries("Tester-Realm", "soloShuffle", 71)
assert(#series.points == 1, "rating-only match was not recorded")
assert(series.points[1][2] == 1500, "rating was not stored")
assert(series.points[1][3] == 0, "missing MMR should use the zero sentinel")
assert(series.points[1][8] == 10, "match sequence was not stored")
assert(series.points[1][9] == "pending", "missing MMR was not marked pending")

assert(History.RecordMatch(
    "Tester",
    "Realm",
    71,
    7,
    1500,
    nil,
    -1,
    105,
    false,
    10,
    "pending"
))
assert(#series.points == 1, "same match sequence created a duplicate")
assert(series.points[1][6] == 1, "unknown retry replaced a known result")

assert(History.EnrichPendingMMR("Tester", "Realm", 71, 7, 1540, 10))
assert(series.points[1][3] == 1540, "next-lobby MMR did not enrich the pending point")
assert(series.points[1][7] == true, "enriched MMR was not aligned to the completed match")
assert(series.points[1][9] == "nextPrematch", "MMR provenance was not stored")

assert(History.RecordMatch(
    "Tester",
    "Realm",
    71,
    7,
    1510,
    nil,
    -1,
    110,
    false,
    11,
    "pending"
))
assert(#series.points == 2, "a distinct match sequence was incorrectly deduplicated")
assert(series.points[2][4] == 10, "rating delta was not recalculated")

assert(History.RecordMatch(
    "Tester",
    "Realm",
    71,
    7,
    1500,
    nil,
    -1,
    115,
    false,
    10,
    "pending"
))
assert(series.points[1][3] == 1540, "a retry without MMR erased an enriched value")
assert(series.points[1][9] == "nextPrematch", "a retry erased MMR provenance")

print("history tests passed")
