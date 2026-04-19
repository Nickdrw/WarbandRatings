local _, ns = ...
ns.Utils = {}
local Utils = ns.Utils

-- Class colors from RAID_CLASS_COLORS
function Utils.GetClassColor(classFilename)
    local color = RAID_CLASS_COLORS[classFilename]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

function Utils.CharKey(name, realm)
    return name .. "-" .. realm
end

-- Returns true if rating is nil, 0, or not a positive number
function Utils.IsEmptyRating(value)
    return not value or value == 0
end

-- Returns a display string for a rating value
function Utils.FormatRating(value)
    if Utils.IsEmptyRating(value) then
        return "-"
    end
    return tostring(value)
end

-- Spec icon texture path from specID
function Utils.GetSpecIcon(specID)
    if not specID or specID == 0 then return nil end
    local _, _, _, icon = GetSpecializationInfoByID(specID)
    return icon
end

-- Class icon from class filename
function Utils.GetClassIcon(classFilename)
    if not classFilename then return nil end
    local coords = CLASS_ICON_TCOORDS[classFilename]
    if coords then
        return "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes", coords
    end
    return nil, nil
end

