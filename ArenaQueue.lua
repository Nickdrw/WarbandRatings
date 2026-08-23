local _, ns = ...
ns.ArenaQueue = {}
local ArenaQueue = ns.ArenaQueue
local Database = ns.Database
local HelperPanel = ns.HelperPanel

local PANEL_WIDTH = 308
local PANEL_GAP = 8
local PANEL_TOP_INSET = 46
local PANEL_BOTTOM_INSET = 4
local CARD_HEIGHT = 100
local UNRATED_CARD_HEIGHT = 82
local CARD_GAP = 4
local MINIMIZED_CARD_HEIGHT = 44
local MINIMIZED_CARD_GAP = 2
local MINIMIZED_PANEL_BOTTOM_INSET = 3
local CARD_SIDE_INSET = 4
local CARD_WIDTH = PANEL_WIDTH - CARD_SIDE_INSET * 2
local CARD_PROGRESS_WIDTH = CARD_WIDTH - 20
local MAX_CARDS = 4
local FALLBACK_BADGE_TEXTURE = 2022761
local NoShow = {
    -- Missed invitations stack until one hour after the resulting aura was applied.
    -- The aura's full duration identifies the current step in the penalty ladder.
    matchLeavingSpellID = 368798,
    missedQueueSpellID = 1311694,
    spellIDs = {
        368798, -- Leaving an active Solo Shuffle or Battleground Blitz match.
        1311694, -- Missing a Solo Shuffle or Battleground Blitz invitation.
    },
    resetSeconds = 60 * 60,
    penaltySeconds = { 60, 5 * 60, 10 * 60, 15 * 60, 20 * 60 },
    durationTolerance = 5,
    alertTexture = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
    activeIconSize = 16,
    alertIconSize = 14,
}
local QUEUE_EYE_TOP_PADDING = 6
local QUEUE_EYE_FLARE_SCALE = 1.15
local HEADER_ROLE_BUTTON_SIZE = 18
local HEADER_ROLE_BUTTON_GAP = 1
local HEADER_ROLE_SELECTOR_GAP = 10
local QUEUE_TAB_HEIGHT = 18
local QUEUE_TAB_GAP = 2
local QUEUE_TAB_TOP_INSET = 26
local QUEUE_CATEGORY_RATED = "rated"
local QUEUE_CATEGORY_UNRATED = "unrated"

local PVP_ROLE_ATLASES = {
    TANK = "roleicon-tiny-tank",
    HEALER = "roleicon-tiny-healer",
    DAMAGER = "roleicon-tiny-dps",
}

local PVP_ROLE_OPTIONS = {
    { role = "TANK", atlas = PVP_ROLE_ATLASES.TANK, frameKey = "TankIcon" },
    { role = "HEALER", atlas = PVP_ROLE_ATLASES.HEALER, frameKey = "HealerIcon" },
    { role = "DAMAGER", atlas = PVP_ROLE_ATLASES.DAMAGER, frameKey = "DPSIcon" },
}

local STATUS_COLORS = {
    rolecheck = { 0.82, 0.36, 0.24, 1 },
    queued = { 0.30, 0.68, 1.00, 1 },
    ready = { 0.24, 0.95, 0.48, 1 },
    active = { 0.72, 0.48, 1.00, 1 },
}
local SESSION_LOSS_COLOR = { 1.00, 0.32, 0.32, 1 }

local SECURE_PROXY_NAMES = {
    [QUEUE_CATEGORY_RATED] = {},
    [QUEUE_CATEGORY_UNRATED] = {},
}
local SECURE_BUTTON_NAMES = {
    [QUEUE_CATEGORY_RATED] = {},
    [QUEUE_CATEGORY_UNRATED] = {},
}
local SECURE_TAB_NAMES = {
    [QUEUE_CATEGORY_RATED] = "WarbandRatingsRatedQueueTab",
    [QUEUE_CATEGORY_UNRATED] = "WarbandRatingsUnratedQueueTab",
}
local SECURE_CLOSE_BUTTON_NAME = "WarbandRatingsQueueCloseButton"
local QUEUE_MACROS = {
    [QUEUE_CATEGORY_RATED] = {},
    [QUEUE_CATEGORY_UNRATED] = {},
}
for cardIndex = 1, MAX_CARDS do
    SECURE_PROXY_NAMES[QUEUE_CATEGORY_RATED][cardIndex] = "WarbandRatingsRatedQueueProxy" .. cardIndex
    SECURE_PROXY_NAMES[QUEUE_CATEGORY_UNRATED][cardIndex] = "WarbandRatingsUnratedQueueProxy" .. cardIndex
    SECURE_BUTTON_NAMES[QUEUE_CATEGORY_RATED][cardIndex] = "WarbandRatingsRatedQueueButton" .. cardIndex
    SECURE_BUTTON_NAMES[QUEUE_CATEGORY_UNRATED][cardIndex] = "WarbandRatingsUnratedQueueButton" .. cardIndex
    QUEUE_MACROS[QUEUE_CATEGORY_RATED][cardIndex] =
        "/click " .. SECURE_PROXY_NAMES[QUEUE_CATEGORY_RATED][cardIndex]
        .. " LeftButton\n/click ConquestJoinButton LeftButton"
    QUEUE_MACROS[QUEUE_CATEGORY_UNRATED][cardIndex] =
        "/click " .. SECURE_PROXY_NAMES[QUEUE_CATEGORY_UNRATED][cardIndex]
        .. " LeftButton\n/click HonorFrameQueueButton LeftButton"
end

local BRACKETS = {
    soloShuffle = {
        key = "soloShuffle",
        category = QUEUE_CATEGORY_RATED,
        label = "Solo Shuffle",
        description = "Rated solo arena for one player.",
        bracketIndex = 7,
        targetKey = "RatedSoloShuffle",
    },
    ratedBGBlitz = {
        key = "ratedBGBlitz",
        category = QUEUE_CATEGORY_RATED,
        label = "Battleground Blitz",
        description = "Rated 8v8 battleground for solo players or a duo with a healer.",
        bracketIndex = 9,
        targetKey = "RatedBGBlitz",
    },
    arena2v2 = {
        key = "arena2v2",
        category = QUEUE_CATEGORY_RATED,
        label = "2v2 Arena",
        description = "Rated arena for your two-player group.",
        bracketIndex = 1,
        targetKey = "Arena2v2",
    },
    arena3v3 = {
        key = "arena3v3",
        category = QUEUE_CATEGORY_RATED,
        label = "3v3 Arena",
        description = "Rated arena for your three-player group.",
        bracketIndex = 2,
        targetKey = "Arena3v3",
    },
}

local UNRATED_BRACKETS = {
    randomBattleground = {
        key = "randomBattleground",
        category = QUEUE_CATEGORY_UNRATED,
        label = _G.RANDOM_BATTLEGROUNDS or "Random Battleground",
        description = "A random battleground for honor and seasonal rewards.",
        targetKey = "RandomBGButton",
    },
    randomEpicBattleground = {
        key = "randomEpicBattleground",
        category = QUEUE_CATEGORY_UNRATED,
        label = _G.RANDOM_EPIC_BATTLEGROUND or "Random Epic Battleground",
        description = "A large-scale random battleground.",
        targetKey = "RandomEpicBGButton",
    },
    arenaSkirmish = {
        key = "arenaSkirmish",
        category = QUEUE_CATEGORY_UNRATED,
        label = _G.SKIRMISH or "Arena Skirmish",
        description = "An unrated arena match.",
        targetKey = "Arena1Button",
    },
    brawl = {
        key = "brawl",
        category = QUEUE_CATEGORY_UNRATED,
        label = _G.PVP_BRAWL or "PvP Brawl",
        description = "The currently active PvP brawl.",
        targetKey = "BrawlButton",
    },
}

local GROUP_BRACKET_KEYS = {
    [1] = { "soloShuffle", "ratedBGBlitz" },
    [2] = { "arena2v2", "ratedBGBlitz" },
    [3] = { "arena3v3" },
}

local BRACKET_DISPLAY_ORDER = {
    "soloShuffle",
    "ratedBGBlitz",
    "arena2v2",
    "arena3v3",
}

local UNRATED_BRACKET_DISPLAY_ORDER = {
    "randomBattleground",
    "randomEpicBattleground",
    "arenaSkirmish",
    "brawl",
}

local eventFrame
local panel
local isPanelMoving
local pendingRoleCheck
local activeRoleCheckBracketKey
local roleCheckTracking
local roleCheckResponses = {}
local lastGroupSize
local ratedStatsReady
local ratingSessionInitialized
local ratingSessionResumeSaved
local ratingSessionRecord
local sessionRatingBaselines = {}
local bracketProxies = {
    [QUEUE_CATEGORY_RATED] = {},
    [QUEUE_CATEGORY_UNRATED] = {},
}
local secureQueueTabs = {}
local secureCloseButton
local queueStatusOriginalLayout
local queueStatusRelocated
local queueStatusHooked
local queueEyeEffect
local builtInPvPDeltas = {}
local builtInPvPDeltasHooked
local betterBlizzTrackerPoints = {}
local noShowPenaltyActive = false
local queueBracketKeysByIndex = {}
local acceptedBattlefieldQueues = {}
local UpdatePanel
local UpdateDynamicCards
local PrimeSecureQueueBrackets
local SyncSecureQueueControls
local HideSecureQueueControls

local function GetCharacterSettings()
    if Database and Database.GetCharacterSettings then
        return Database.GetCharacterSettings()
    end
    local characterDB = _G.WarbandRatingsCharacterDB
    return characterDB and characterDB.settings
end

local function IsHelperHidden()
    local settings = GetCharacterSettings()
    return settings and settings.hideArenaQueueHelper
end

local function IsInInstancedContent()
    local isInInstance = _G.IsInInstance
    if not isInInstance then return false end
    return isInInstance() == true
end

local function IsPlayerMaxLevel()
    if not UnitLevel then return true end

    local maxLevel = GetMaxLevelForLatestExpansion and GetMaxLevelForLatestExpansion()
    if not maxLevel and GetMaxLevelForPlayerExpansion then
        maxLevel = GetMaxLevelForPlayerExpansion()
    end
    if not maxLevel then return true end

    return UnitLevel("player") >= maxLevel
end

function ArenaQueue.IsAvailable()
    return IsPlayerMaxLevel() and not IsInInstancedContent()
end

local function GetGroupSize()
    local size = GetNumGroupMembers and GetNumGroupMembers() or 0
    return math.max(tonumber(size) or 0, 1)
end

local function GetObjectiveTracker()
    return _G.ObjectiveTrackerFrame or _G.ObjectiveTracker
end

local function GetSettings()
    return WarbandRatingsDB and WarbandRatingsDB.settings
end

local function IsPanelMinimized()
    local settings = GetSettings()
    return settings and settings.arenaQueueMinimized == true
end

local function SetPanelMinimized(minimized)
    local settings = GetSettings()
    if not settings then return end

    minimized = minimized == true
    if Database and Database.SetSetting then
        Database.SetSetting("arenaQueueMinimized", minimized)
    else
        settings.arenaQueueMinimized = minimized
    end
end

local function GetQueueCategory()
    local settings = GetSettings()
    if settings and settings.arenaQueueCategory == QUEUE_CATEGORY_UNRATED then
        return QUEUE_CATEGORY_UNRATED
    end
    return QUEUE_CATEGORY_RATED
end

local function SetQueueCategory(category)
    category = category == QUEUE_CATEGORY_UNRATED and QUEUE_CATEGORY_UNRATED or QUEUE_CATEGORY_RATED
    local settings = GetSettings()
    if not settings or GetQueueCategory() == category then return end

    if Database and Database.SetSetting then
        Database.SetSetting("arenaQueueCategory", category)
    else
        settings.arenaQueueCategory = category
    end
end

local function GetSavedPanelPosition()
    local settings = GetSettings()
    local position = settings and settings.arenaQueuePosition
    if type(position) == "table"
        and type(position.x) == "number"
        and type(position.y) == "number"
    then
        return position
    end
    return nil
end

local function SetPanelTopPosition(x, y)
    panel:ClearAllPoints()
    panel:SetPoint("TOP", UIParent, "TOP", x, y)
end

local function ClampPanelToScreen()
    if not panel or not UIParent then return end

    local parentWidth = UIParent:GetWidth()
    local parentHeight = UIParent:GetHeight()
    if not parentWidth or not parentHeight or parentWidth <= 0 or parentHeight <= 0 then return end

    local width = panel:GetWidth()
    local height = panel:GetHeight()
    local left = panel:GetLeft()
    local top = panel:GetTop()
    if not left or not top then return end

    if width <= parentWidth then
        left = math.max(0, math.min(left, parentWidth - width))
    else
        left = (parentWidth - width) / 2
    end

    if height <= parentHeight then
        top = math.max(height, math.min(top, parentHeight))
    else
        top = parentHeight
    end

    SetPanelTopPosition(left + (width / 2) - (parentWidth / 2), top - parentHeight)
end

local function SavePanelPosition()
    local settings = GetSettings()
    if not settings or not panel or not UIParent then return end

    local parentWidth = UIParent:GetWidth()
    local parentHeight = UIParent:GetHeight()
    local left = panel:GetLeft()
    local top = panel:GetTop()
    if not parentWidth or not parentHeight or not left or not top then return end

    local position = {
        x = math.floor(left + (panel:GetWidth() / 2) - (parentWidth / 2) + 0.5),
        y = math.floor(top - parentHeight + 0.5),
    }

    if Database and Database.SetSetting then
        Database.SetSetting("arenaQueuePosition", position)
    else
        settings.arenaQueuePosition = position
    end
end

local function StartPanelMove()
    if not panel or (InCombatLockdown and InCombatLockdown()) then return end

    HideSecureQueueControls()
    isPanelMoving = true
    panel:StartMoving()
end

local function StopPanelMove()
    if not panel or not isPanelMoving then return end

    panel:StopMovingOrSizing()
    isPanelMoving = false
    ClampPanelToScreen()
    HelperPanel.SnapFrameToPixelGrid(panel)
    SavePanelPosition()
    SyncSecureQueueControls()
end

local function IsPVPUIReady()
    return _G.ConquestFrame
        and _G.ConquestJoinButton
        and _G.ConquestFrame.RatedSoloShuffle
        and _G.ConquestFrame.RatedBGBlitz
        and _G.ConquestFrame.Arena2v2
        and _G.ConquestFrame.Arena3v3
        and _G.HonorFrame
        and _G.HonorFrameQueueButton
        and _G.HonorFrame.BonusFrame
        and _G.HonorFrame.BonusFrame.RandomBGButton
        and _G.HonorFrame.BonusFrame.RandomEpicBGButton
        and _G.HonorFrame.BonusFrame.Arena1Button
        and _G.HonorFrame.BonusFrame.BrawlButton
end

local function IsPVPUISettingUpAllowed()
    return not (InCombatLockdown and InCombatLockdown())
end

local function LoadPVPUI()
    if IsPVPUIReady() then return true end
    if not IsPVPUISettingUpAllowed() then return false end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PVPUI")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_PVPUI")
    end

    return IsPVPUIReady()
end

local function EnsureBracketProxy(category, cardIndex)
    local categoryProxies = bracketProxies[category]
    local proxyNames = SECURE_PROXY_NAMES[category]
    if not categoryProxies or not proxyNames then return false end
    if categoryProxies[cardIndex] then return true end
    if not IsPVPUISettingUpAllowed() then return false end

    local proxy = CreateFrame(
        "Button",
        proxyNames[cardIndex],
        UIParent,
        "SecureActionButtonTemplate"
    )
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetAttribute("type", "click")
    proxy:SetAttribute("useOnKeyDown", false)
    categoryProxies[cardIndex] = proxy
    return true
end

local function GetBracketTarget(bracket)
    if bracket.category == QUEUE_CATEGORY_UNRATED then
        local honorFrame = _G.HonorFrame
        local bonusFrame = honorFrame and honorFrame.BonusFrame
        return bonusFrame and bonusFrame[bracket.targetKey]
    end

    local conquestFrame = _G.ConquestFrame
    return conquestFrame and conquestFrame[bracket.targetKey]
end

local function ConfigureSecureBracket(cardIndex, bracket)
    local card = panel and panel.cards and panel.cards[cardIndex]
    local category = bracket and bracket.category
    local button = card and card.secureActionButtons and card.secureActionButtons[category]
    local categoryProxies = category and bracketProxies[category]
    local proxy = categoryProxies and categoryProxies[cardIndex]
    if not bracket or not button then return false end
    local queueMacros = QUEUE_MACROS[category]
    local queueMacro = queueMacros and queueMacros[cardIndex]
    if not queueMacro then return false end
    local target = GetBracketTarget(bracket)
    if target
        and button:GetAttribute("configuredBracketKey") == bracket.key
        and proxy
        and proxy:GetAttribute("configuredBracketKey") == bracket.key
        and proxy:GetAttribute("clickbutton") == target
        and button:GetAttribute("type") == "macro"
        and button:GetAttribute("macrotext") == queueMacro then
        return true
    end
    if not IsPVPUISettingUpAllowed() then return false end
    if not LoadPVPUI() or not EnsureBracketProxy(category, cardIndex) then return false end
    proxy = bracketProxies[category][cardIndex]

    target = GetBracketTarget(bracket)
    if not target then return false end

    if proxy:GetAttribute("configuredBracketKey") ~= bracket.key
        or proxy:GetAttribute("clickbutton") ~= target then
        proxy:SetAttribute("clickbutton", target)
        proxy:SetAttribute("configuredBracketKey", bracket.key)
    end

    button:SetAttribute("type", "macro")
    button:SetAttribute("clickbutton", nil)
    button:SetAttribute("macrotext", queueMacro)
    button:SetAttribute("configuredBracketKey", bracket.key)
    return true
end

local function ClearSecureAction(cardIndex, category)
    local card = panel and panel.cards and panel.cards[cardIndex]
    if not card or not card.secureActionButtons or not IsPVPUISettingUpAllowed() then return false end

    local cleared = false
    for buttonCategory, button in pairs(card.secureActionButtons) do
        if not category or category == buttonCategory then
            button:SetAttribute("type", nil)
            button:SetAttribute("clickbutton", nil)
            button:SetAttribute("macrotext", nil)
            button:SetAttribute("configuredBracketKey", nil)
            cleared = true
        end
    end
    return cleared
end

local function GetRatedQueueBracket(queueType, teamSize, registeredMatch, isSoloQueue)
    if queueType == "RATEDSOLORBG" then
        return BRACKETS.ratedBGBlitz
    elseif queueType == "RATEDSHUFFLE" then
        return BRACKETS.soloShuffle
    elseif queueType == "ARENA"
        and registeredMatch
        and not isSoloQueue
        and teamSize == 2 then
        return BRACKETS.arena2v2
    elseif queueType == "ARENA"
        and registeredMatch
        and not isSoloQueue
        and teamSize == 3 then
        return BRACKETS.arena3v3
    end
end

local function NormalizeQueueName(queueName)
    if type(queueName) ~= "string" then return nil end
    return queueName:lower():gsub("[%s%p]+", "")
end

local function QueueNamesMatch(firstName, secondName)
    local first = NormalizeQueueName(firstName)
    local second = NormalizeQueueName(secondName)
    if not first or not second or first == "" or second == "" then return false end
    if first == second then return true end

    -- Blizzard's casual PvP tile and battlefield status can differ only by an
    -- English plural (for example, "Random Epic Battlegrounds" vs
    -- "Random Epic Battleground"). Treat those as the same queue.
    return (first:sub(-1) == "s" and first:sub(1, -2) == second)
        or (second:sub(-1) == "s" and second:sub(1, -2) == first)
end

local function QueueNameContains(queueName, fragment)
    local normalizedName = NormalizeQueueName(queueName)
    local normalizedFragment = NormalizeQueueName(fragment)
    return normalizedName
        and normalizedFragment
        and normalizedFragment ~= ""
        and normalizedName:find(normalizedFragment, 1, true) ~= nil
end

local function GetBrawlInfo(specialEvent)
    if not C_PvP then return nil end
    local getter = specialEvent and C_PvP.GetSpecialEventBrawlInfo or C_PvP.GetAvailableBrawlInfo
    return getter and getter() or nil
end

local function RefreshUnratedBracketLabels()
    local brawlInfo = GetBrawlInfo(false)
    local specialBrawlInfo = GetBrawlInfo(true)
    UNRATED_BRACKETS.brawl.label = brawlInfo and brawlInfo.name
        or _G.PVP_BRAWL
        or "PvP Brawl"
    return brawlInfo, specialBrawlInfo
end

local function GetUnratedQueueBracket(queueType, mapName, teamSize, registeredMatch, cachedBracketKey)
    if cachedBracketKey == "ignoredSpecialBrawl" then return nil, true end

    local brawlInfo, specialBrawlInfo = RefreshUnratedBracketLabels()
    if (queueType and queueType:find("SKIRMISH", 1, true))
        or QueueNameContains(mapName, _G.SKIRMISH or "Skirmish") then
        return UNRATED_BRACKETS.arenaSkirmish
    elseif QueueNamesMatch(mapName, specialBrawlInfo and specialBrawlInfo.name) then
        return nil, true
    elseif QueueNamesMatch(mapName, brawlInfo and brawlInfo.name) then
        return UNRATED_BRACKETS.brawl
    elseif queueType and queueType:find("BRAWL", 1, true) then
        return UNRATED_BRACKETS.brawl
    elseif QueueNamesMatch(mapName, _G.RANDOM_EPIC_BATTLEGROUND) then
        return UNRATED_BRACKETS.randomEpicBattleground
    elseif QueueNamesMatch(mapName, _G.RANDOM_BATTLEGROUNDS) then
        return UNRATED_BRACKETS.randomBattleground
    end

    if not registeredMatch and (teamSize == 2 or teamSize == 3 or teamSize == 5) then
        return UNRATED_BRACKETS.arenaSkirmish
    end
    if registeredMatch then return nil end
    if queueType == "ARENA" then
        return UNRATED_BRACKETS.arenaSkirmish
    end

    local cachedBracket = cachedBracketKey and UNRATED_BRACKETS[cachedBracketKey]
    if queueType == "BATTLEGROUND" and cachedBracket then
        return cachedBracket
    elseif queueType == "BATTLEGROUND" then
        return UNRATED_BRACKETS.randomBattleground
    end
end

local function GetQueuedPVPRole(queueIndex, battlefieldRole)
    local specializationID = C_PvP
        and C_PvP.GetAssignedSpecForBattlefieldQueue
        and C_PvP.GetAssignedSpecForBattlefieldQueue(queueIndex)
    local role
    if specializationID then
        if _G.GetSpecializationRoleByID then
            role = _G.GetSpecializationRoleByID(specializationID)
        elseif _G.GetSpecializationInfoByID then
            role = select(5, _G.GetSpecializationInfoByID(specializationID))
        end
    end
    if PVP_ROLE_ATLASES[role] then return role end
    if PVP_ROLE_ATLASES[battlefieldRole] then return battlefieldRole end
end

local function RecordBattlefieldPortResponse(queueIndex, accepted)
    queueIndex = tonumber(queueIndex)
    if not queueIndex then return end

    if accepted == true or accepted == 1 then
        acceptedBattlefieldQueues[queueIndex] = true
    else
        acceptedBattlefieldQueues[queueIndex] = nil
    end
end

local function ScanPVPQueues()
    local queues = {
        [QUEUE_CATEGORY_RATED] = {},
        [QUEUE_CATEGORY_UNRATED] = {},
    }
    local maxQueues = GetMaxBattlefieldID and GetMaxBattlefieldID()
    maxQueues = tonumber(maxQueues) or tonumber(_G.MAX_BATTLEFIELD_QUEUES) or 8

    for queueIndex = 1, maxQueues do
        local status, mapName, teamSize, registeredMatch, suspended, queueType, _, battlefieldRole, asGroup, _, _, isSoloQueue =
            GetBattlefieldStatus(queueIndex)
        if status and status ~= "none" then
            if status ~= "confirm" then
                acceptedBattlefieldQueues[queueIndex] = nil
            end
            local bracket, ignoredQueue = GetUnratedQueueBracket(
                queueType,
                mapName,
                teamSize,
                registeredMatch,
                queueBracketKeysByIndex[queueIndex]
            )
            if not bracket and not ignoredQueue then
                bracket = GetRatedQueueBracket(queueType, teamSize, registeredMatch, isSoloQueue)
            end
            if bracket then
                local isSolo = isSoloQueue
                    or bracket.key == "soloShuffle"
                    or bracket.key == "ratedBGBlitz"
                -- Solo queues can remain "confirm" after the player accepts.
                -- Present that interval like Blizzard's locked premade ready check.
                if status == "confirm" and isSolo and acceptedBattlefieldQueues[queueIndex] then
                    status = "locked"
                elseif not isSolo then
                    acceptedBattlefieldQueues[queueIndex] = nil
                end
                queueBracketKeysByIndex[queueIndex] = bracket.key
                queues[bracket.category][bracket.key] = {
                    index = queueIndex,
                    status = status,
                    mapName = mapName,
                    suspended = suspended,
                    role = GetQueuedPVPRole(queueIndex, battlefieldRole),
                    asGroup = asGroup,
                    isSolo = isSolo,
                    bracket = bracket,
                }
            elseif ignoredQueue then
                queueBracketKeysByIndex[queueIndex] = "ignoredSpecialBrawl"
            else
                queueBracketKeysByIndex[queueIndex] = nil
            end
        else
            queueBracketKeysByIndex[queueIndex] = nil
            acceptedBattlefieldQueues[queueIndex] = nil
        end
    end

    return queues
end

local function GetRoleCheckBracketKeyFromName(queueName)
    if type(queueName) ~= "string" then return nil end

    local normalizedName = queueName:lower()
    if normalizedName:find("shuffle", 1, true) then
        return "soloShuffle"
    elseif normalizedName:find("blitz", 1, true)
        or normalizedName:find("solo rbg", 1, true)
    then
        return "ratedBGBlitz"
    elseif normalizedName:find("2v2", 1, true)
        or normalizedName:find("2 vs 2", 1, true)
    then
        return "arena2v2"
    elseif normalizedName:find("3v3", 1, true)
        or normalizedName:find("3 vs 3", 1, true)
    then
        return "arena3v3"
    end

    local brawlInfo, specialBrawlInfo = RefreshUnratedBracketLabels()
    if QueueNamesMatch(queueName, specialBrawlInfo and specialBrawlInfo.name) then
        return nil
    elseif QueueNamesMatch(queueName, brawlInfo and brawlInfo.name) then
        return "brawl"
    elseif QueueNamesMatch(queueName, _G.RANDOM_EPIC_BATTLEGROUND) then
        return "randomEpicBattleground"
    elseif QueueNamesMatch(queueName, _G.RANDOM_BATTLEGROUNDS) then
        return "randomBattleground"
    elseif QueueNameContains(queueName, _G.SKIRMISH or "Skirmish") then
        return "arenaSkirmish"
    end
end

local function NormalizeRoleCheckPlayerName(playerName)
    if type(playerName) ~= "string" or playerName == "" then return nil end

    local linkedName = playerName:match("|Hplayer:[^|]+|h%[([^%]]+)%]|h")
    if linkedName then
        playerName = linkedName
    end
    playerName = playerName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return playerName:lower():gsub("%s+", "")
end

local function GetClassColoredPlayerName(unit, playerName)
    if not UnitClass or not RAID_CLASS_COLORS then return playerName end

    local _, classFilename = UnitClass(unit)
    local classColor = classFilename and RAID_CLASS_COLORS[classFilename]
    if not classColor then return playerName end
    if classColor.WrapTextInColorCode then
        return classColor:WrapTextInColorCode(playerName)
    elseif classColor.colorStr then
        return "|c" .. classColor.colorStr .. playerName .. "|r"
    end
    return playerName
end

local function GetRoleCheckPlayerInfo(unit)
    if not UnitName then return nil end

    local playerName, realmName = UnitName(unit)
    if not playerName or playerName == "" then return nil end

    local fullName = playerName
    if realmName and realmName ~= "" then
        fullName = playerName .. "-" .. realmName
    end
    return {
        key = NormalizeRoleCheckPlayerName(fullName),
        shortKey = NormalizeRoleCheckPlayerName(playerName),
        displayName = GetClassColoredPlayerName(unit, playerName),
        responded = false,
    }
end

local function FindTrackedRoleCheckPlayer(players, responseKey)
    for _, playerInfo in ipairs(players) do
        if playerInfo.key == responseKey then
            return playerInfo
        end
    end

    local responseShortKey = responseKey:match("^([^-]+)")
    local matchingPlayer
    for _, playerInfo in ipairs(players) do
        if playerInfo.shortKey == responseShortKey then
            if matchingPlayer then return nil end
            matchingPlayer = playerInfo
        end
    end
    return matchingPlayer
end

local function StartRoleCheckTracking(bracketKey)
    roleCheckTracking = nil
    if not bracketKey
        or GetGroupSize() <= 1
        or not UnitIsGroupLeader
        or not UnitIsGroupLeader("player")
    then
        return
    end

    local players = {}
    for partyIndex = 1, GetGroupSize() - 1 do
        local playerInfo = GetRoleCheckPlayerInfo("party" .. partyIndex)
        if playerInfo then
            players[#players + 1] = playerInfo
        end
    end
    if #players == 0 then return end

    roleCheckTracking = {
        bracketKey = bracketKey,
        players = players,
    }
    for responseKey in pairs(roleCheckResponses) do
        local playerInfo = FindTrackedRoleCheckPlayer(players, responseKey)
        if playerInfo then
            playerInfo.responded = true
        end
    end
end

local function EnsureRoleCheckTracking(bracketKey)
    if roleCheckTracking and roleCheckTracking.bracketKey == bracketKey then return end
    StartRoleCheckTracking(bracketKey)
end

local function MarkRoleCheckPlayerResponded(playerName)
    local responseKey = NormalizeRoleCheckPlayerName(playerName)
    if not responseKey then return end
    roleCheckResponses[responseKey] = true

    if roleCheckTracking then
        local playerInfo = FindTrackedRoleCheckPlayer(roleCheckTracking.players, responseKey)
        if playerInfo then
            playerInfo.responded = true
        end
    end
end

local function SyncRoleCheckPlayerResponses(numMembers)
    local getRoleUpdateMember = _G.GetLFGRoleUpdateMember
    if not getRoleUpdateMember then return end

    numMembers = tonumber(numMembers) or GetGroupSize()
    for memberIndex = 1, numMembers do
        local responded, _, playerName = getRoleUpdateMember(memberIndex)
        if responded == true and playerName then
            MarkRoleCheckPlayerResponded(playerName)
        end
    end
end

local function GetUnansweredRoleCheckPlayers(bracketKey)
    if not roleCheckTracking or roleCheckTracking.bracketKey ~= bracketKey then return nil end

    local unanswered = {}
    for _, playerInfo in ipairs(roleCheckTracking.players) do
        if not playerInfo.responded then
            unanswered[#unanswered + 1] = playerInfo.displayName
        end
    end

    return unanswered
end

local function FormatPlayerList(playerNames)
    if #playerNames == 1 then return playerNames[1] end
    if #playerNames == 2 then return playerNames[1] .. " and " .. playerNames[2] end
    return table.concat(playerNames, ", ")
end

local function ScanPVPRoleCheck()
    if not GetLFGRoleUpdate then return nil end

    local inProgress, _, numMembers, _, fifthValue, sixthValue = GetLFGRoleUpdate()
    if not inProgress then
        activeRoleCheckBracketKey = nil
        roleCheckTracking = nil
        local now = GetTime and GetTime() or 0
        if pendingRoleCheck and pendingRoleCheck.expiresAt < now then
            pendingRoleCheck = nil
        end
        return nil
    end

    local queueName = GetLFGRoleUpdateBattlegroundInfo
        and GetLFGRoleUpdateBattlegroundInfo()
        or nil
    local isBattlegroundRoleCheck = fifthValue == true
        or sixthValue == true
        or (type(queueName) == "string" and queueName ~= "")
    if not isBattlegroundRoleCheck then return nil end

    local now = GetTime and GetTime() or 0
    if pendingRoleCheck and pendingRoleCheck.expiresAt < now then
        pendingRoleCheck = nil
    end

    local bracketKey = activeRoleCheckBracketKey
        or (pendingRoleCheck and pendingRoleCheck.bracketKey)
        or GetRoleCheckBracketKeyFromName(queueName)
    local bracket = bracketKey
        and (BRACKETS[bracketKey] or UNRATED_BRACKETS[bracketKey])
    if not bracket then return nil end

    activeRoleCheckBracketKey = bracketKey
    pendingRoleCheck = nil
    EnsureRoleCheckTracking(bracketKey)
    SyncRoleCheckPlayerResponses(numMembers)
    return {
        status = "rolecheck",
        queueName = queueName,
        bracket = bracket,
    }
end

local function GetDisplayedBrackets(queues)
    local displayed = {}
    local included = {}
    local groupKeys = GROUP_BRACKET_KEYS[GetGroupSize()]

    if groupKeys then
        for _, key in ipairs(groupKeys) do
            displayed[#displayed + 1] = BRACKETS[key]
            included[key] = true
        end
    end

    -- Solo Shuffle queues only the player, so remaining in a group should not
    -- remove it from the helper.
    if not included.soloShuffle and #displayed < MAX_CARDS then
        displayed[#displayed + 1] = BRACKETS.soloShuffle
        included.soloShuffle = true
    end

    for _, key in ipairs(BRACKET_DISPLAY_ORDER) do
        if queues[key] and not included[key] and #displayed < MAX_CARDS then
            displayed[#displayed + 1] = BRACKETS[key]
            included[key] = true
        end
    end

    return displayed
end

local function GetDisplayedUnratedBrackets(queues)
    local displayed = {}
    local brawlInfo = RefreshUnratedBracketLabels()

    for _, key in ipairs(UNRATED_BRACKET_DISPLAY_ORDER) do
        local isCoreBracket = key == "randomBattleground"
            or key == "randomEpicBattleground"
            or key == "arenaSkirmish"
        local isAvailableBrawl = key == "brawl" and brawlInfo ~= nil
        if isCoreBracket or isAvailableBrawl or queues[key] then
            displayed[#displayed + 1] = UNRATED_BRACKETS[key]
        end
    end

    return displayed
end

local function CountQueues(queues)
    local count = 0
    for _ in pairs(queues) do
        count = count + 1
    end
    return count
end

local QUEUE_VISUAL_STATE_PRIORITY = {
    queued = 1,
    active = 2,
    rolecheck = 3,
    ready = 4,
}

local function GetQueueVisualState(queue)
    if not queue then return nil end
    if queue.status == "confirm" then
        return "ready"
    elseif queue.status == "rolecheck" then
        return "rolecheck"
    elseif queue.status == "active" or queue.status == "locked" then
        return "active"
    elseif queue.status == "queued" then
        return "queued"
    end
end

local function GetCategoryQueueVisualState(queues)
    local bestState
    local bestPriority = 0
    for _, queue in pairs(queues) do
        local visualState = GetQueueVisualState(queue)
        local priority = visualState and QUEUE_VISUAL_STATE_PRIORITY[visualState] or 0
        if priority > bestPriority then
            bestState = visualState
            bestPriority = priority
        end
    end
    return bestState
end

local function PrepareUnratedQueueControls()
    return LoadPVPUI()
end

local function GetUnratedQueueFailure(bracket, groupSize)
    if not GetBracketTarget(bracket) or not _G.HonorFrameQueueButton then
        return "Unrated PvP queue controls are not ready."
    end

    if C_LobbyMatchmakerInfo
        and C_LobbyMatchmakerInfo.IsInQueue
        and C_LobbyMatchmakerInfo.IsInQueue() then
        return _G.WOW_LABS_CANNOT_ENTER_NON_PLUNDER_QUEUE or "Another matchmaking queue is active."
    end
    if groupSize > 1 and UnitIsGroupLeader and not UnitIsGroupLeader("player") then
        return _G.ERR_NOT_LEADER or "Only the group leader can queue."
    end

    if bracket.key == "randomBattleground" and C_PvP and C_PvP.GetRandomBGInfo then
        local info = C_PvP.GetRandomBGInfo()
        if not info or not info.canQueue or not info.bgID then
            return "Random Battlegrounds are currently unavailable."
        end
    elseif bracket.key == "randomEpicBattleground" and C_PvP and C_PvP.GetRandomEpicBGInfo then
        local info = C_PvP.GetRandomEpicBGInfo()
        if not info or not info.canQueue or not info.bgID then
            return "Random Epic Battlegrounds are currently unavailable."
        end
    elseif bracket.key == "arenaSkirmish" and C_PvP and C_PvP.GetSkirmishInfo then
        local info = C_PvP.GetSkirmishInfo(4)
        if not info then
            return "Arena Skirmishes are currently unavailable."
        elseif groupSize < (tonumber(info.minPlayers) or 1) then
            return "Your group needs more players for Arena Skirmish."
        elseif groupSize > (tonumber(info.maxPlayers) or groupSize) then
            return "Your group has too many players for Arena Skirmish."
        end
    elseif bracket.key == "brawl" then
        local info = GetBrawlInfo(false)
        if not info or not info.canQueue then
            return "The PvP Brawl is currently unavailable."
        elseif groupSize > 1 and info.groupsAllowed == false then
            return _G.SOLO_BRAWL_CANT_QUEUE or "This PvP Brawl only allows solo players."
        end
    end
end

local function GetRatedAccessFailure()
    if C_PvP and C_PvP.CanPlayerUseRatedPVPUI then
        local canUse, failureReason = C_PvP.CanPlayerUseRatedPVPUI()
        if not canUse then
            return failureReason or "Rated PvP is unavailable."
        end
    end

    if C_LobbyMatchmakerInfo
        and C_LobbyMatchmakerInfo.IsInQueue
        and C_LobbyMatchmakerInfo.IsInQueue() then
        return _G.WOW_LABS_CANNOT_ENTER_NON_PLUNDER_QUEUE or "Another matchmaking queue is active."
    end

    if _G.ConquestFrame_HasActiveSeason and not _G.ConquestFrame_HasActiveSeason() then
        return "The rated PvP season is not active."
    end
end

local function GetLFGListFailure()
    if not C_LFGList then return nil end

    if C_LFGList.GetNumApplications and select(2, C_LFGList.GetNumApplications()) > 0 then
        return _G.CANNOT_DO_THIS_WITH_LFGLIST_APP or "Cancel Group Finder applications before queueing."
    end
    if C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() then
        return _G.CANNOT_DO_THIS_WHILE_LFGLIST_LISTED or "Delist your Group Finder group before queueing."
    end
end

local function GetPlayerPVPItemLevel()
    if not GetAverageItemLevel then return 0 end
    local _, _, playerPVPItemLevel = GetAverageItemLevel()
    return tonumber(playerPVPItemLevel) or 0
end

local function FormatPVPItemLevelFailure(requiredItemLevel, currentItemLevel, playerName)
    if playerName then
        return ("%s: PvP ilvl %d/%d."):format(
            playerName,
            currentItemLevel,
            requiredItemLevel
        )
    end
    return ("PvP ilvl %d/%d required."):format(currentItemLevel, requiredItemLevel)
end

function NoShow.GetCurrentEpoch()
    local getServerTime = _G.GetServerTime
    if getServerTime then
        local serverTime = tonumber(getServerTime())
        if serverTime and serverTime > 0 then
            return serverTime
        end
    end
    return time and tonumber(time()) or nil
end

function NoShow.NormalizeDuration(duration)
    duration = tonumber(duration)
    if not duration then return nil end

    for tierIndex, tierDuration in ipairs(NoShow.penaltySeconds) do
        if math.abs(duration - tierDuration) <= NoShow.durationTolerance then
            return tierDuration, tierIndex
        end
    end
end

function NoShow.SaveRecord(record)
    local settings = GetSettings()
    if settings then
        settings.arenaQueueNoShowPenalty = record
    end
end

function NoShow.GetSavedRecord()
    local settings = GetSettings()
    local record = settings and settings.arenaQueueNoShowPenalty
    if type(record) ~= "table" then return nil end

    local appliedAt = tonumber(record.appliedAt)
    local duration, tierIndex = NoShow.NormalizeDuration(record.duration)
    if not appliedAt or not duration then
        NoShow.SaveRecord(nil)
        return nil
    end

    record.appliedAt = appliedAt
    record.duration = duration
    return record, tierIndex
end

function NoShow.GetAuraAppliedAt(auraData)
    local currentEpoch = NoShow.GetCurrentEpoch()
    if not currentEpoch then return nil end

    local auraDuration = auraData and tonumber(auraData.duration)
    local expirationTime = auraData and tonumber(auraData.expirationTime)
    local currentTime = GetTime and tonumber(GetTime())
    if not auraDuration or auraDuration <= 0 or not expirationTime or not currentTime then
        return currentEpoch
    end

    local remaining = math.max(0, expirationTime - currentTime)
    local elapsed = math.max(0, math.min(auraDuration, auraDuration - remaining))
    return math.floor(currentEpoch - elapsed + 0.5)
end

function NoShow.TrackMissedQueue(auraData)
    local duration = NoShow.NormalizeDuration(auraData and auraData.duration)
    local appliedAt = duration and NoShow.GetAuraAppliedAt(auraData)
    if not duration or not appliedAt then return end

    local currentRecord = NoShow.GetSavedRecord()
    if currentRecord
        and currentRecord.duration == duration
        and math.abs(currentRecord.appliedAt - appliedAt) <= 2
    then
        return
    end

    NoShow.SaveRecord({
        appliedAt = appliedAt,
        duration = duration,
    })
end

function NoShow.GetSpellIcon(spellID)
    local spellAPI = _G.C_Spell
    if spellAPI and spellAPI.GetSpellTexture then
        local icon = spellAPI.GetSpellTexture(spellID)
        if icon then return icon end
    end

    local getSpellTexture = _G.GetSpellTexture
    return getSpellTexture and getSpellTexture(spellID) or nil
end

function NoShow.FormatInlineIcon(texture, size)
    if not texture then return "" end
    size = tonumber(size) or NoShow.activeIconSize
    return ("|T%s:%d:%d:0:0|t"):format(tostring(texture), size, size)
end

function NoShow.FormatCountdown(seconds)
    seconds = tonumber(seconds)
    if not seconds then return nil end

    seconds = math.max(0, math.ceil(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function NoShow.GetActiveCountdown()
    local expirationTime = tonumber(NoShow.expirationTime)
    local currentTime = GetTime and tonumber(GetTime())
    if not noShowPenaltyActive or not expirationTime or not currentTime then return nil end
    return NoShow.FormatCountdown(expirationTime - currentTime)
end

function NoShow.GetActiveText()
    local icon = NoShow.FormatInlineIcon(
        NoShow.icon or NoShow.GetSpellIcon(NoShow.missedQueueSpellID),
        NoShow.activeIconSize
    )
    local penaltyLabel = NoShow.activeSpellID == NoShow.matchLeavingSpellID
        and "Match-leaving penalty active"
        or "No-Show penalty active"
    local text = (icon ~= "" and (icon .. " ") or "") .. penaltyLabel
    return text .. "."
end

function NoShow.GetActiveButtonText()
    return NoShow.GetActiveCountdown() or "--:--"
end

function NoShow.ScanActivePenalty()
    noShowPenaltyActive = false
    NoShow.icon = nil
    NoShow.expirationTime = nil
    NoShow.activeSpellID = nil
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for _, spellID in ipairs(NoShow.spellIDs) do
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
            if auraData then
                noShowPenaltyActive = true
                if spellID == NoShow.missedQueueSpellID then
                    NoShow.activeSpellID = spellID
                    NoShow.icon = auraData.icon or NoShow.GetSpellIcon(spellID)
                    NoShow.expirationTime = auraData.expirationTime
                    NoShow.TrackMissedQueue(auraData)
                elseif not NoShow.icon then
                    NoShow.activeSpellID = spellID
                    NoShow.icon = auraData.icon or NoShow.GetSpellIcon(spellID)
                    NoShow.expirationTime = auraData.expirationTime
                end
            end
        end
    end
    return noShowPenaltyActive
end

function NoShow.GetWarning()
    if noShowPenaltyActive then return nil end

    local record, tierIndex = NoShow.GetSavedRecord()
    local currentEpoch = record and NoShow.GetCurrentEpoch()
    if not record or not currentEpoch then return nil end
    if record.appliedAt > currentEpoch + NoShow.durationTolerance then
        NoShow.SaveRecord(nil)
        return nil
    end

    local remainingSeconds = record.appliedAt + NoShow.resetSeconds - currentEpoch
    if remainingSeconds <= 0 then
        NoShow.SaveRecord(nil)
        return nil
    end

    local nextTierIndex = math.min(tierIndex + 1, #NoShow.penaltySeconds)
    return {
        remainingSeconds = remainingSeconds,
        nextPenaltySeconds = NoShow.penaltySeconds[nextTierIndex],
    }
end

function NoShow.FormatWarningSentence(warning)
    if not warning then return nil end

    local remainingText = NoShow.FormatCountdown(warning.remainingSeconds)
    local nextPenaltyMinutes = math.floor(warning.nextPenaltySeconds / 60)
    return ("Next missed queue within %s triggers a %d min penalty."):format(
        remainingText,
        nextPenaltyMinutes
    )
end

function NoShow.FormatWarning(warning, minimized)
    if not warning then return nil end

    local remainingText = NoShow.FormatCountdown(warning.remainingSeconds)
    local nextPenaltyMinutes = math.floor(warning.nextPenaltySeconds / 60)
    local icon = NoShow.FormatInlineIcon(
        NoShow.alertTexture,
        minimized and 12 or NoShow.alertIconSize
    )
    if minimized then
        return ("%s Miss: %dm (%s left)"):format(
            icon,
            nextPenaltyMinutes,
            remainingText
        )
    end
    return icon .. " " .. NoShow.FormatWarningSentence(warning)
end

function NoShow.ShowQueueWarningTooltip(button)
    local tooltip = _G.GameTooltip
    if not tooltip or not button or not button.tooltipText then return end

    tooltip:SetOwner(button, "ANCHOR_RIGHT")
    tooltip:SetText(button.tooltipText, 1, 0.82, 0, 1, true)
    tooltip:Show()
end

function NoShow.HideQueueWarningTooltip(button)
    local tooltip = _G.GameTooltip
    if tooltip and (not tooltip.IsOwned or tooltip:IsOwned(button)) then
        tooltip:Hide()
    end
end

function NoShow.UpdateQueueWarningDisplay(card, state, warning)
    local button = card and card.noShowWarningButton
    if not button then return end

    if warning then
        button.tooltipText = NoShow.FormatWarningSentence(warning)
        button:Show()
        local tooltip = _G.GameTooltip
        if tooltip and tooltip.IsOwned and tooltip:IsOwned(button) then
            NoShow.ShowQueueWarningTooltip(button)
        end
    else
        button.tooltipText = nil
        button:Hide()
        NoShow.HideQueueWarningTooltip(button)
    end

    if not state then return end

    local showWarning = warning ~= nil
    local showQueueInButton = card.minimizedLayout
        and state.queue ~= nil
        and (not state.buttonVisible or showWarning)
    local showActionButton = state.buttonVisible and not showQueueInButton and not showWarning
    card.actionButton:SetShown(showActionButton)
    card.actionBlocker:SetShown(
        showWarning or not (state.buttonEnabled and showActionButton)
    )

    local compactFailureShowsRating = state.failureKind == "notLeader"
        or state.failureKind == "noShow"
    local showCompactRating = card.minimizedLayout
        and state.isRated
        and not state.noShowWarning
        and (showQueueInButton or not state.failureReason or compactFailureShowsRating)
    card.compactRating:SetShown(showCompactRating)
    card.compactDelta:SetShown(showCompactRating)
    card.queueText:SetShown(showWarning or showQueueInButton or not showCompactRating)

    card.queueText:ClearAllPoints()
    if showWarning and showQueueInButton then
        card.queueText:SetPoint("TOPLEFT", card.actionButton, "TOPLEFT", 0, 0)
        card.queueText:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -2, 0)
        card.queueText:SetJustifyH("CENTER")
    elseif showWarning then
        card.queueText:SetPoint(
            "BOTTOMLEFT",
            card,
            "BOTTOMLEFT",
            10,
            card.minimizedLayout and 7 or 13
        )
        card.queueText:SetPoint("RIGHT", button, "LEFT", -8, 0)
        card.queueText:SetJustifyH("LEFT")
    elseif showQueueInButton then
        card.queueText:SetAllPoints(card.actionButton)
        card.queueText:SetJustifyH("CENTER")
    else
        card.queueText:SetPoint(
            "BOTTOMLEFT",
            card,
            "BOTTOMLEFT",
            10,
            card.minimizedLayout and 7 or 13
        )
        if state.buttonVisible then
            card.queueText:SetPoint("RIGHT", card.actionButton, "LEFT", -8, 0)
        else
            card.queueText:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        end
        card.queueText:SetJustifyH("LEFT")
    end
end

function NoShow.IsBracket(bracket)
    return bracket
        and (bracket.key == "soloShuffle" or bracket.key == "ratedBGBlitz")
end

local function GetSoloShuffleFailure()
    if _G.ConquestFrame and _G.ConquestFrame.ratedSoloShuffleEnabled == false then
        return "Solo Shuffle is currently unavailable."
    elseif _G.ConquestFrame and _G.ConquestFrame.ratedSoloShuffleEnabled == nil then
        return "Waiting for rated PvP availability."
    end

    if noShowPenaltyActive then
        return NoShow.GetActiveText(), "noShow"
    end

    if C_PvP and C_PvP.GetRatedSoloShuffleMinItemLevel then
        local minItemLevel = tonumber(C_PvP.GetRatedSoloShuffleMinItemLevel()) or 0
        local playerPVPItemLevel = GetPlayerPVPItemLevel()
        if minItemLevel > 0 and playerPVPItemLevel < minItemLevel then
            return FormatPVPItemLevelFailure(minItemLevel, playerPVPItemLevel)
        end
    end
end

local function UnitClassCanHeal(unit)
    if not UnitClass
        or not C_SpecializationInfo
        or not C_SpecializationInfo.GetNumSpecializationsForClassID
        or not GetSpecializationInfoForClassID then
        return nil
    end

    local _, _, classID = UnitClass(unit)
    if not classID then return nil end

    local specializationCount = tonumber(
        C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
    ) or 0
    if specializationCount <= 0 then return nil end

    for specializationIndex = 1, specializationCount do
        local _, _, _, _, role = GetSpecializationInfoForClassID(
            classID,
            specializationIndex
        )
        if role == "HEALER" then
            return true
        end
    end
    return false
end

local function IsBlitzDuoMissingHealerCapableClass()
    -- Fail open when class/spec data is not ready; Blizzard's role check remains
    -- authoritative and will reject a duo that does not select a healer.
    return UnitClassCanHeal("player") == false
        and UnitClassCanHeal("party1") == false
end

local function GetBlitzFailure(groupSize)
    if _G.ConquestFrame and _G.ConquestFrame.ratedBGBlitzEnabled == false then
        return "Battleground Blitz is currently unavailable."
    elseif _G.ConquestFrame and _G.ConquestFrame.ratedBGBlitzEnabled == nil then
        return "Waiting for rated PvP availability."
    end

    if noShowPenaltyActive then
        return NoShow.GetActiveText(), "noShow"
    end

    local lfgFailure = GetLFGListFailure()
    if lfgFailure then return lfgFailure end

    if groupSize == 2 and IsBlitzDuoMissingHealerCapableClass() then
        return "Blitz duo needs a healer class."
    end

    if groupSize == 2 and (not UnitIsGroupLeader or not UnitIsGroupLeader("player")) then
        return _G.PVP_NOT_LEADER or "Only the group leader can queue.", "notLeader"
    end

    if C_PvP and C_PvP.GetRatedSoloRBGMinItemLevel then
        local minItemLevel = tonumber(C_PvP.GetRatedSoloRBGMinItemLevel()) or 0
        if groupSize == 2
            and C_PartyInfo
            and C_PartyInfo.GetMinItemLevel
            and Enum
            and Enum.AvgItemLevelCategories then
            local partyMinItemLevel, lowestPlayer =
                C_PartyInfo.GetMinItemLevel(Enum.AvgItemLevelCategories.PvP)
            partyMinItemLevel = tonumber(partyMinItemLevel)
            if minItemLevel > 0 and partyMinItemLevel and partyMinItemLevel < minItemLevel then
                return FormatPVPItemLevelFailure(
                    minItemLevel,
                    partyMinItemLevel,
                    lowestPlayer
                )
            end
        else
            local playerPVPItemLevel = GetPlayerPVPItemLevel()
            if minItemLevel > 0 and playerPVPItemLevel < minItemLevel then
                return FormatPVPItemLevelFailure(minItemLevel, playerPVPItemLevel)
            end
        end
    end
end

local function GetGroupUnitLayout(groupSize)
    if groupSize > ((tonumber(_G.MAX_PARTY_MEMBERS) or 4) + 1) then
        return "raid", groupSize
    end
    return "party", groupSize - 1
end

local function GetArenaGroupFailure(groupSize)
    if _G.ConquestFrame and _G.ConquestFrame.arenasEnabled == false then
        return "Rated arenas are currently unavailable."
    elseif _G.ConquestFrame and _G.ConquestFrame.arenasEnabled == nil then
        return "Waiting for rated PvP availability."
    end
    if not UnitIsGroupLeader or not UnitIsGroupLeader("player") then
        return _G.PVP_NOT_LEADER or "Only the group leader can queue.", "notLeader"
    end

    local lfgFailure = GetLFGListFailure()
    if lfgFailure then return lfgFailure end

    local maxLevel = GetMaxLevelForLatestExpansion and GetMaxLevelForLatestExpansion()
    local unitPrefix, unitCount = GetGroupUnitLayout(groupSize)
    for index = 1, unitCount do
        local unit = unitPrefix .. index
        if UnitIsConnected and not UnitIsConnected(unit) then
            return "A group member is offline."
        end
        if maxLevel and UnitLevel and UnitLevel(unit) < maxLevel then
            if _G.QUEUE_UNAVAILABLE_PARTY_MIN_LEVEL then
                return _G.QUEUE_UNAVAILABLE_PARTY_MIN_LEVEL:format(maxLevel)
            end
            return "Every group member must be max level."
        end
    end

    local hasSpecialization
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        hasSpecialization = C_SpecializationInfo.GetSpecialization()
    elseif GetSpecialization then
        hasSpecialization = GetSpecialization()
    end
    if not hasSpecialization then
        return _G.SPELL_FAILED_CUSTOM_ERROR_122 or "Select a specialization before queueing."
    end
end

local function GetBracketFailure(bracket, groupSize)
    if bracket.key == "soloShuffle" then
        return GetSoloShuffleFailure()
    elseif bracket.key == "ratedBGBlitz" then
        return GetBlitzFailure(groupSize)
    end
    return GetArenaGroupFailure(groupSize)
end

local function GetPublicTierName(tierInfo)
    local tierName = tierInfo and tierInfo.name
    if not tierName or tierName == "" then
        return "Unranked"
    end

    -- Blizzard's raw name includes the bracket and an internal tier sequence,
    -- such as "Solo Shuffle - 9 - Elite". Only the public rank is useful here.
    return tierName:match("^.- %- %d+ %- (.+)$") or tierName
end

local function GetCurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or not GetSpecializationInfo then return 0 end
    return GetSpecializationInfo(specIndex) or 0
end

local function GetSessionRatingKey(bracket)
    if bracket.key == "soloShuffle" or bracket.key == "ratedBGBlitz" then
        return bracket.key .. ":" .. GetCurrentSpecID()
    end
    return bracket.key
end

local function InitializeRatingSession()
    if ratingSessionInitialized then return true end
    if ratingSessionResumeSaved == nil then return false end

    local settings = GetSettings()
    local playerGUID = UnitGUID and UnitGUID("player")
    if not settings or not playerGUID then return false end

    if type(settings.arenaQueueRatingSessions) ~= "table" then
        settings.arenaQueueRatingSessions = {}
    end

    local savedSession = settings.arenaQueueRatingSessions[playerGUID]
    if ratingSessionResumeSaved
        and type(savedSession) == "table"
        and savedSession.reloadOnly == true
        and type(savedSession.baselines) == "table"
    then
        sessionRatingBaselines = savedSession.baselines
    else
        sessionRatingBaselines = {}
    end

    ratingSessionRecord = {
        baselines = sessionRatingBaselines,
        reloadOnly = true,
    }
    settings.arenaQueueRatingSessions[playerGUID] = ratingSessionRecord
    ratingSessionInitialized = true
    return true
end

local function TouchRatingSession()
    if not InitializeRatingSession() then return end
    ratingSessionRecord.baselines = sessionRatingBaselines
end

local function CaptureSessionRatingBaselines()
    if not ratedStatsReady or not GetPersonalRatedInfo then return end
    if not InitializeRatingSession() then return end

    for _, bracketKey in ipairs(BRACKET_DISPLAY_ORDER) do
        local bracket = BRACKETS[bracketKey]
        local sessionKey = GetSessionRatingKey(bracket)
        if sessionRatingBaselines[sessionKey] == nil then
            local rating = GetPersonalRatedInfo(bracket.bracketIndex)
            sessionRatingBaselines[sessionKey] = tonumber(rating) or 0
        end
    end
    TouchRatingSession()
end

local function GetRatingInfo(bracket)
    local rating, _, _, _, _, _, _, _, _, pvpTier, ranking =
        GetPersonalRatedInfo(bracket.bracketIndex)
    rating = tonumber(rating) or 0
    pvpTier = tonumber(pvpTier)
    ranking = tonumber(ranking) or 0

    local tierInfo
    if pvpTier and C_PvP and C_PvP.GetPvpTierInfo then
        tierInfo = C_PvP.GetPvpTierInfo(pvpTier)
    end

    local sessionDelta
    if ratedStatsReady and InitializeRatingSession() then
        local sessionKey = GetSessionRatingKey(bracket)
        if sessionRatingBaselines[sessionKey] == nil then
            sessionRatingBaselines[sessionKey] = rating
        end
        sessionDelta = rating - sessionRatingBaselines[sessionKey]
        TouchRatingSession()
    end

    return {
        rating = rating,
        ranking = ranking,
        tierName = GetPublicTierName(tierInfo),
        tierIcon = tierInfo and tierInfo.tierIconID,
        sessionDelta = sessionDelta,
    }
end

local function GetBetterBlizzTrackerPoints(tracker)
    local points = betterBlizzTrackerPoints[tracker]
    if points then return points end

    points = {}
    for index = 1, tracker:GetNumPoints() do
        points[index] = { tracker:GetPoint(index) }
    end
    betterBlizzTrackerPoints[tracker] = points
    return points
end

local function ApplyBetterBlizzTrackerOffset(tracker, yOffset)
    local points = GetBetterBlizzTrackerPoints(tracker)
    tracker:ClearAllPoints()
    for _, point in ipairs(points) do
        tracker:SetPoint(point[1], point[2], point[3], point[4], (point[5] or 0) + yOffset)
    end
end

local function PositionBuiltInPvPRatingDelta(deltaText, bracketFrame, currentRating)
    deltaText:ClearAllPoints()

    local gladWinTracker = bracketFrame.bbfGladWinTracker
    if gladWinTracker and gladWinTracker:IsShown() and deltaText:IsShown() then
        local verticalGap = 1
        local trackerOffset = -((deltaText:GetStringHeight() + verticalGap) / 2)
        ApplyBetterBlizzTrackerOffset(gladWinTracker, trackerOffset)
        deltaText:SetJustifyH("CENTER")
        deltaText:SetPoint("BOTTOM", gladWinTracker, "TOP", 0, verticalGap)
    else
        if gladWinTracker and betterBlizzTrackerPoints[gladWinTracker] then
            ApplyBetterBlizzTrackerOffset(gladWinTracker, 0)
        end
        deltaText:SetJustifyH("LEFT")
        deltaText:SetPoint("LEFT", currentRating, "RIGHT", 4, 0)
    end
end

local function UpdateBuiltInPvPRatingDeltas()
    local conquestFrame = _G.ConquestFrame
    if not conquestFrame or not GetPersonalRatedInfo then return end

    for _, bracketKey in ipairs(BRACKET_DISPLAY_ORDER) do
        local bracket = BRACKETS[bracketKey]
        local bracketFrame = conquestFrame[bracket.targetKey]
        local currentRating = bracketFrame and bracketFrame.CurrentRating
        if currentRating then
            local deltaText = builtInPvPDeltas[bracketKey]
            if not deltaText then
                deltaText = bracketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                deltaText:SetJustifyH("LEFT")
                builtInPvPDeltas[bracketKey] = deltaText
            end

            local sessionDelta = GetRatingInfo(bracket).sessionDelta
            if sessionDelta and sessionDelta ~= 0 then
                deltaText:SetText((sessionDelta >= 0 and "+" or "") .. sessionDelta)
                if sessionDelta > 0 then
                    deltaText:SetTextColor(unpack(STATUS_COLORS.ready))
                else
                    deltaText:SetTextColor(unpack(SESSION_LOSS_COLOR))
                end
                deltaText:Show()
            else
                deltaText:SetText("")
                deltaText:Hide()
            end
            PositionBuiltInPvPRatingDelta(deltaText, bracketFrame, currentRating)
        end
    end

    if not builtInPvPDeltasHooked then
        conquestFrame:HookScript("OnShow", UpdateBuiltInPvPRatingDeltas)
        builtInPvPDeltasHooked = true
    end
end

local function BuildCardState(cardIndex, bracket, queue, commonFailure, groupSize)
    local isRated = bracket.category == QUEUE_CATEGORY_RATED
    local state = {
        bracket = bracket,
        category = bracket.category,
        isRated = isRated,
        queue = queue,
        rating = isRated and GetRatingInfo(bracket) or {
            rating = 0,
            ranking = 0,
            tierName = "",
        },
        buttonText = "Queue",
        buttonEnabled = false,
        buttonVisible = true,
        visualState = "available",
        noShowWarningEligible = NoShow.IsBracket(bracket),
    }

    -- Preserve the prepared secure action while a queue temporarily blocks it.
    -- If the queue ends in combat, protected attributes cannot be rebuilt then.
    if queue then
        if queue.status == "rolecheck" then
            state.visualState = "rolecheck"
            state.statusText = "ROLE CHECK"
            if groupSize > 1
                and UnitIsGroupLeader
                and UnitIsGroupLeader("player")
                and ConfigureSecureBracket(cardIndex, bracket)
            then
                state.buttonText = "Requeue"
                state.buttonEnabled = true
            else
                state.buttonVisible = false
            end
        elseif queue.status == "queued" then
            state.buttonVisible = false
            state.visualState = "queued"
            if queue.suspended then
                state.statusText = "QUEUE SUSPENDED"
            else
                state.statusText = "IN QUEUE"
            end
        elseif queue.status == "confirm" then
            state.buttonText = "Match ready"
            state.visualState = "ready"
            state.statusText = "MATCH READY"
        elseif queue.status == "locked" then
            state.buttonText = "Waiting"
            state.visualState = "active"
            state.statusText = "WAITING FOR PLAYERS"
        elseif queue.status == "active" then
            state.buttonText = "In match"
            state.visualState = "active"
            state.statusText = "MATCH IN PROGRESS"
        else
            state.buttonText = "Unavailable"
            state.visualState = "active"
            state.statusText = "QUEUE UNAVAILABLE"
        end
        return state
    end

    if commonFailure then
        state.failureReason = commonFailure
    elseif not isRated then
        state.failureReason = GetUnratedQueueFailure(bracket, groupSize)
    else
        state.failureReason, state.failureKind = GetBracketFailure(bracket, groupSize)
    end
    if not state.failureReason and not ConfigureSecureBracket(cardIndex, bracket) then
        state.failureReason = isRated
            and "Rated PvP queue controls are not ready."
            or "Unrated PvP queue controls are not ready."
    end
    if not state.failureReason and state.noShowWarningEligible then
        local warning = NoShow.GetWarning()
        if warning then
            state.noShowWarning = true
            state.noShowWarningText = NoShow.FormatWarning(warning, false)
            state.noShowWarningCompactText = NoShow.FormatWarning(warning, true)
        end
    end
    state.buttonEnabled = not state.failureReason
    state.statusText = state.failureReason and "UNAVAILABLE" or "READY TO QUEUE"
    return state
end

local function GetPanelState()
    if IsHelperHidden() or not GetObjectiveTracker() then return nil end

    NoShow.ScanActivePenalty()
    local queueGroups = ScanPVPQueues()
    local ratedQueues = queueGroups[QUEUE_CATEGORY_RATED]
    local unratedQueues = queueGroups[QUEUE_CATEGORY_UNRATED]
    local roleCheck = ScanPVPRoleCheck()
    if roleCheck then
        local roleCheckQueues = queueGroups[roleCheck.bracket.category]
        if roleCheckQueues and not roleCheckQueues[roleCheck.bracket.key] then
            roleCheckQueues[roleCheck.bracket.key] = roleCheck
        end
    end
    local category = GetQueueCategory()
    local queues = category == QUEUE_CATEGORY_UNRATED and unratedQueues or ratedQueues
    local ratedBrackets = GetDisplayedBrackets(ratedQueues)
    local unratedBrackets = GetDisplayedUnratedBrackets(unratedQueues)
    PrimeSecureQueueBrackets(ratedBrackets, unratedBrackets)
    local brackets = category == QUEUE_CATEGORY_UNRATED and unratedBrackets or ratedBrackets
    if #brackets == 0 then return nil end

    local groupSize = GetGroupSize()
    local commonFailure
    if category == QUEUE_CATEGORY_UNRATED then
        if not PrepareUnratedQueueControls() then
            commonFailure = "Unrated PvP UI is not ready."
        end
    elseif not IsPVPUIReady() then
        commonFailure = "Rated PvP UI is not ready."
    else
        commonFailure = GetRatedAccessFailure()
    end

    local state = {
        category = category,
        queueCounts = {
            [QUEUE_CATEGORY_RATED] = CountQueues(ratedQueues),
            [QUEUE_CATEGORY_UNRATED] = CountQueues(unratedQueues),
        },
        queueVisualStates = {
            [QUEUE_CATEGORY_RATED] = GetCategoryQueueVisualState(ratedQueues),
            [QUEUE_CATEGORY_UNRATED] = GetCategoryQueueVisualState(unratedQueues),
        },
        cards = {},
    }
    for cardIndex, bracket in ipairs(brackets) do
        local cardState = BuildCardState(
            cardIndex,
            bracket,
            queues[bracket.key],
            commonFailure,
            groupSize
        )
        state.cards[cardIndex] = cardState
    end
    return state
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60
    if hours > 0 then
        return ("%d:%02d:%02d"):format(hours, minutes, remainingSeconds)
    end
    return ("%d:%02d"):format(minutes, remainingSeconds)
end

local function SetCardProgress(card, ratio)
    ratio = math.max(0, math.min(tonumber(ratio) or 0, 1))
    if ratio <= 0 then
        card.progressFill:Hide()
        return
    end

    card.progressFill:SetWidth(math.max(1, CARD_PROGRESS_WIDTH * ratio))
    card.progressFill:Show()
end

local function SetQueueDisplayText(card, expandedText, minimizedText)
    card.queueText:SetText(card.minimizedLayout and minimizedText or expandedText)
end

local function UpdateDynamicCard(card)
    local state = card.cardState
    local queue = state and state.queue
    if not state or not queue then
        NoShow.UpdateQueueWarningDisplay(card, state, nil)
        card.readyGlow:Hide()
        card.progressBg:Hide()
        card.progressFill:Hide()
        if state and state.failureKind == "noShow" then
            state.failureReason = NoShow.GetActiveText()
            card.queueText:SetText(state.failureReason)
            card.actionButton:SetText(NoShow.GetActiveButtonText())
        elseif state and state.noShowWarning and not state.failureReason then
            local warning = NoShow.GetWarning()
            if warning then
                state.noShowWarningText = NoShow.FormatWarning(warning, false)
                state.noShowWarningCompactText = NoShow.FormatWarning(warning, true)
                SetQueueDisplayText(
                    card,
                    state.noShowWarningText,
                    state.noShowWarningCompactText
                )
            else
                state.noShowWarning = false
                state.noShowWarningText = nil
                state.noShowWarningCompactText = nil
                card.queueText:SetText(state.bracket.description)
                if card.minimizedLayout and state.isRated then
                    card.queueText:Hide()
                    card.compactRating:Show()
                    card.compactDelta:Show()
                end
            end
        end
        return
    end

    local queueWarning
    if state.noShowWarningEligible
        and (queue.status == "queued" or queue.status == "confirm")
    then
        queueWarning = NoShow.GetWarning()
    end
    NoShow.UpdateQueueWarningDisplay(card, state, queueWarning)

    if queue.status == "rolecheck" then
        card.readyGlow:Hide()
        local unanswered = GetUnansweredRoleCheckPlayers(queue.bracket.key)
        if unanswered and #unanswered == 0 then
            card.statusText:SetText("ROLE CHECK COMPLETE")
            if card.minimizedLayout then card.modeName:SetText("All responded") end
            SetQueueDisplayText(card, "All group members responded; joining queue", "All responded")
        elseif unanswered and #unanswered > 0 then
            local playerList = FormatPlayerList(unanswered)
            card.statusText:SetText("ROLE CHECK")
            if card.minimizedLayout then card.modeName:SetText("Waiting: " .. playerList) end
            SetQueueDisplayText(
                card,
                "Waiting for " .. playerList .. " to choose a role",
                "Waiting: " .. playerList
            )
        else
            card.statusText:SetText("ROLE CHECK")
            if card.minimizedLayout then card.modeName:SetText("Role check") end
            SetQueueDisplayText(card, "Waiting for all players to choose a role", "Role check")
        end
        card.progressBg:Hide()
        card.progressFill:Hide()
    elseif queue.status == "queued" then
        card.readyGlow:Hide()
        if queue.suspended then
            SetQueueDisplayText(card, "Queue suspended", "Suspended")
            card.progressBg:Hide()
            card.progressFill:Hide()
            return
        end

        local waited = GetBattlefieldTimeWaited and GetBattlefieldTimeWaited(queue.index) or 0
        local estimated = GetBattlefieldEstimatedWaitTime
            and GetBattlefieldEstimatedWaitTime(queue.index)
            or 0
        waited = (tonumber(waited) or 0) / 1000
        estimated = (tonumber(estimated) or 0) / 1000
        local waitedText = FormatDuration(waited)

        if estimated > 0 then
            local estimatedText = FormatDuration(estimated)
            SetQueueDisplayText(
                card,
                "Queued " .. waitedText .. "  •  Est. " .. estimatedText,
                "Wait " .. waitedText .. "\nEst. " .. estimatedText
            )
            SetCardProgress(card, waited / estimated)
        else
            SetQueueDisplayText(
                card,
                "Queued " .. waitedText .. "  •  Est. —",
                "Wait " .. waitedText .. "\nEst. —"
            )
            SetCardProgress(card, 0.08)
        end
        card.progressBg:Show()
    elseif queue.status == "confirm" then
        local expiration = GetBattlefieldPortExpiration
            and GetBattlefieldPortExpiration(queue.index)
            or 0
        local expirationText = FormatDuration(expiration)
        SetQueueDisplayText(
            card,
            "Match ready  •  " .. expirationText,
            "Ready\n" .. expirationText
        )
        card.progressBg:Show()
        SetCardProgress(card, 1)
        card.readyGlow:Show()
        local now = GetTime and GetTime() or 0
        card.readyGlow:SetAlpha(0.12 + (math.sin(now * 5) + 1) * 0.10)
    elseif queue.status == "locked" then
        card.readyGlow:Hide()
        SetQueueDisplayText(
            card,
            "Waiting for other players to accept the match",
            "Waiting for players"
        )
        card.progressBg:Hide()
        card.progressFill:Hide()
    else
        card.readyGlow:Hide()
        SetQueueDisplayText(card, state.statusText, state.buttonText)
        card.progressBg:Hide()
        card.progressFill:Hide()
    end
end

UpdateDynamicCards = function()
    if not panel or not panel:IsShown() then return end
    for _, card in ipairs(panel.cards) do
        if card:IsShown() then
            UpdateDynamicCard(card)
        end
    end
end

local function GetCardAccent(state, theme)
    if state.visualState == "rolecheck" then
        return STATUS_COLORS.rolecheck
    elseif state.visualState == "queued" then
        return STATUS_COLORS.queued
    elseif state.visualState == "ready" then
        return STATUS_COLORS.ready
    elseif state.visualState == "active" then
        return STATUS_COLORS.active
    elseif state.failureReason then
        return theme.muted
    end
    return theme.accent
end

local function ApplyCardTheme(card, theme)
    local state = card.cardState
    if not state then return end

    local accent = GetCardAccent(state, theme)
    HelperPanel.SetTextureColor(card.bg, theme.surfaceRaised)
    HelperPanel.SetTextureColor(card.badgeBg, theme.surface, 0)
    HelperPanel.SetTextureColor(card.borderTop, theme.border, 0.72)
    HelperPanel.SetTextureColor(card.borderBottom, theme.border, 0.72)
    HelperPanel.SetTextureColor(card.borderLeft, theme.border, 0.72)
    HelperPanel.SetTextureColor(card.borderRight, theme.border, 0.72)
    HelperPanel.SetTextureColor(card.accent, accent)
    HelperPanel.SetTextureColor(card.statusDot, accent)
    HelperPanel.SetTextureColor(card.progressBg, theme.surface)
    HelperPanel.SetTextureColor(card.progressFill, accent)
    HelperPanel.SetTextureColor(card.readyGlow, STATUS_COLORS.ready, 0.2)
    HelperPanel.SetFontColor(card.modeName, theme.text)
    HelperPanel.SetFontColor(card.rankText, theme.muted)
    HelperPanel.SetFontColor(card.ratingValue, accent)
    HelperPanel.SetFontColor(card.ratingLabel, theme.muted)
    HelperPanel.SetFontColor(card.compactRating, accent)
    local sessionDelta = state.rating.sessionDelta
    local sessionDeltaColor = theme.muted
    if sessionDelta and sessionDelta > 0 then
        sessionDeltaColor = STATUS_COLORS.ready
    elseif sessionDelta and sessionDelta < 0 then
        sessionDeltaColor = SESSION_LOSS_COLOR
    end
    HelperPanel.SetFontColor(card.sessionDelta, sessionDeltaColor)
    HelperPanel.SetFontColor(card.compactDelta, sessionDeltaColor)
    HelperPanel.SetFontColor(card.statusText, accent)
    HelperPanel.SetFontColor(card.queueText, theme.muted)
end

local function ApplyQueueTabTheme(button, theme)
    local backgroundColor = button.selected and theme.accent or theme.surface
    local backgroundAlpha = button.selected and 0.18 or 0.28
    local borderColor = button.selected and theme.accent or theme.border
    local borderAlpha = button.selected and 0.72 or 0.42

    HelperPanel.SetTextureColor(button.bg, backgroundColor, backgroundAlpha)
    HelperPanel.SetTextureColor(button.border, borderColor, borderAlpha)
    HelperPanel.SetTextureColor(button.selection, theme.accent, button.selected and 1 or 0)
    HelperPanel.SetTextureColor(button.highlight, theme.rowHover)
    HelperPanel.SetTextureColor(
        button.queueIndicator,
        STATUS_COLORS[button.queueVisualState] or STATUS_COLORS.queued
    )
    HelperPanel.SetFontColor(button.label, button.selected and theme.accent or theme.muted)
end

local function UpdateQueueTabs(state, theme)
    if not panel or not panel.queueTabs then return end

    local selectedCategory = state and state.category or GetQueueCategory()
    local queueCounts = state and state.queueCounts or {}
    local queueVisualStates = state and state.queueVisualStates or {}
    theme = theme or HelperPanel.GetTheme()
    for _, button in ipairs(panel.queueTabs) do
        button.selected = button.category == selectedCategory
        button.queueCount = queueCounts[button.category] or 0
        button.queueVisualState = queueVisualStates[button.category]
        button.queueIndicator:SetShown(not button.selected and button.queueCount > 0)
        ApplyQueueTabTheme(button, theme)
    end
end

local function CreateQueueTabs()
    panel.queueTabs = {}
    local tabWidth = (CARD_WIDTH - QUEUE_TAB_GAP) / 2
    local tabOptions = {
        { category = QUEUE_CATEGORY_RATED, label = "Rated" },
        { category = QUEUE_CATEGORY_UNRATED, label = "Unrated" },
    }

    local anchor
    for tabIndex, tabOption in ipairs(tabOptions) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(tabWidth, QUEUE_TAB_HEIGHT)
        if anchor then
            button:SetPoint("TOPLEFT", anchor, "TOPRIGHT", QUEUE_TAB_GAP, 0)
        else
            button:SetPoint("TOPLEFT", panel, "TOPLEFT", CARD_SIDE_INSET, -QUEUE_TAB_TOP_INSET)
        end
        button:SetFrameLevel(panel:GetFrameLevel() + 4)
        button:RegisterForClicks("LeftButtonUp")
        button.category = tabOption.category

        button.border = button:CreateTexture(nil, "BORDER")
        button.border:SetAllPoints()

        button.bg = button:CreateTexture(nil, "BORDER", nil, 1)
        button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)

        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label:SetPoint("CENTER")
        button.label:SetText(tabOption.label:upper())

        button.selection = button:CreateTexture(nil, "OVERLAY")
        button.selection:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 0)
        button.selection:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 0)
        button.selection:SetHeight(2)

        button.queueIndicator = button:CreateTexture(nil, "OVERLAY")
        button.queueIndicator:SetSize(6, 6)
        button.queueIndicator:SetPoint("RIGHT", button, "RIGHT", -9, 0)
        button.queueIndicator:Hide()

        button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
        button.highlight:SetAllPoints()
        button:SetHighlightTexture(button.highlight)

        button:SetScript("OnClick", function()
            if GetQueueCategory() == button.category then return end
            SetQueueCategory(button.category)
            UpdatePanel()
        end)

        panel.queueTabs[tabIndex] = button
        anchor = button
    end
end

-- Secure queue buttons cannot be parented or anchored to the dynamic cards:
-- doing so would protect the whole panel and prevent its combat-time refreshes.
-- Each category therefore owns a separate set of detached controls. They are
-- configured before combat and a secure tab click only swaps which set is
-- visible; it never changes what a combat-clickable button will queue.
local SECURE_QUEUE_TAB_ON_CLICK = [=[
    local category = self:GetAttribute("category")
    local count = self:GetAttribute(category .. "Count") or 0
    for cardIndex = 1, self:GetAttribute("maxCards") do
        local ratedAction = self:GetFrameRef("ratedAction" .. cardIndex)
        local unratedAction = self:GetFrameRef("unratedAction" .. cardIndex)
        if ratedAction then
            if category == "rated" and cardIndex <= count then
                ratedAction:Show()
            else
                ratedAction:Hide()
            end
        end
        if unratedAction then
            if category == "unrated" and cardIndex <= count then
                unratedAction:Show()
            else
                unratedAction:Hide()
            end
        end
    end
]=]

local SECURE_QUEUE_CLOSE_ON_CLICK = [=[
    for cardIndex = 1, self:GetAttribute("maxCards") do
        local ratedAction = self:GetFrameRef("ratedAction" .. cardIndex)
        local unratedAction = self:GetFrameRef("unratedAction" .. cardIndex)
        if ratedAction then ratedAction:Hide() end
        if unratedAction then unratedAction:Hide() end
    end
    local ratedTab = self:GetFrameRef("ratedTab")
    local unratedTab = self:GetFrameRef("unratedTab")
    if ratedTab then ratedTab:Hide() end
    if unratedTab then unratedTab:Hide() end
    self:Hide()
]=]

local function CreateSecureQueueControls()
    if secureCloseButton or not panel or not panel.cards or not panel.queueTabs then return end
    if not IsPVPUISettingUpAllowed() then return end

    for tabIndex, visualTab in ipairs(panel.queueTabs) do
        local secureTab = CreateFrame(
            "Button",
            SECURE_TAB_NAMES[visualTab.category],
            UIParent,
            "SecureHandlerClickTemplate"
        )
        secureTab:SetSize(visualTab:GetSize())
        secureTab:RegisterForClicks("LeftButtonUp")
        secureTab:SetAttribute("category", visualTab.category)
        secureTab:SetAttribute("maxCards", MAX_CARDS)
        secureTab:SetAttribute("_onclick", SECURE_QUEUE_TAB_ON_CLICK)
        secureTab.category = visualTab.category
        secureTab:SetScript("PostClick", function(button)
            if GetQueueCategory() == button.category then return end
            SetQueueCategory(button.category)
            UpdatePanel()
        end)
        secureTab:Hide()
        secureQueueTabs[visualTab.category] = secureTab
        visualTab:EnableMouse(false)
        visualTab.secureTab = secureTab
        panel.queueTabs[tabIndex] = visualTab
    end

    for cardIndex, card in ipairs(panel.cards) do
        for category, secureActionButton in pairs(card.secureActionButtons) do
            EnsureBracketProxy(category, cardIndex)
            for _, secureTab in pairs(secureQueueTabs) do
                secureTab:SetFrameRef(category .. "Action" .. cardIndex, secureActionButton)
            end
        end
    end

    secureCloseButton = CreateFrame(
        "Button",
        SECURE_CLOSE_BUTTON_NAME,
        UIParent,
        "SecureHandlerClickTemplate"
    )
    secureCloseButton:SetSize(panel.closeButton:GetSize())
    secureCloseButton:RegisterForClicks("LeftButtonUp")
    secureCloseButton:SetAttribute("maxCards", MAX_CARDS)
    secureCloseButton:SetAttribute("_onclick", SECURE_QUEUE_CLOSE_ON_CLICK)
    for cardIndex, card in ipairs(panel.cards) do
        for category, secureActionButton in pairs(card.secureActionButtons) do
            secureCloseButton:SetFrameRef(category .. "Action" .. cardIndex, secureActionButton)
        end
    end
    secureCloseButton:SetFrameRef("ratedTab", secureQueueTabs[QUEUE_CATEGORY_RATED])
    secureCloseButton:SetFrameRef("unratedTab", secureQueueTabs[QUEUE_CATEGORY_UNRATED])
    secureCloseButton:SetScript("PostClick", function()
        ArenaQueue.Hide()
    end)
    secureCloseButton:Hide()
    panel.closeButton:EnableMouse(false)
end

PrimeSecureQueueBrackets = function(ratedBrackets, unratedBrackets)
    if not secureCloseButton or not IsPVPUISettingUpAllowed() then return end

    local bracketGroups = {
        [QUEUE_CATEGORY_RATED] = ratedBrackets,
        [QUEUE_CATEGORY_UNRATED] = unratedBrackets,
    }
    for category, brackets in pairs(bracketGroups) do
        local count = math.min(#brackets, MAX_CARDS)
        for _, secureTab in pairs(secureQueueTabs) do
            secureTab:SetAttribute(category .. "Count", count)
        end
        for cardIndex = 1, MAX_CARDS do
            local bracket = brackets[cardIndex]
            if bracket then
                ConfigureSecureBracket(cardIndex, bracket)
            else
                ClearSecureAction(cardIndex, category)
            end
        end
    end
end

local function GetSecureActionPosition(category, cardIndex)
    local panelLeft = panel and panel:GetLeft()
    local panelTop = panel and panel:GetTop()
    if not panelLeft or not panelTop then return nil end

    local minimized = IsPanelMinimized()
    local cardHeight = minimized
        and MINIMIZED_CARD_HEIGHT
        or (category == QUEUE_CATEGORY_UNRATED and UNRATED_CARD_HEIGHT or CARD_HEIGHT)
    local cardGap = minimized and MINIMIZED_CARD_GAP or CARD_GAP
    local cardTop = panelTop - PANEL_TOP_INSET - (cardIndex - 1) * (cardHeight + cardGap)
    local x = panelLeft + CARD_SIDE_INSET + CARD_WIDTH - 9 - 88
    local y = minimized and (cardTop - (cardHeight + 22) / 2) or (cardTop - cardHeight + 7)
    return x, y
end

SyncSecureQueueControls = function()
    if not secureCloseButton or not panel or not IsPVPUISettingUpAllowed() then return end

    for _, visualTab in ipairs(panel.queueTabs) do
        local secureTab = visualTab.secureTab
        local left = visualTab:GetLeft()
        local bottom = visualTab:GetBottom()
        if secureTab and left and bottom then
            secureTab:SetFrameStrata(panel:GetFrameStrata())
            secureTab:SetFrameLevel(visualTab:GetFrameLevel() + 10)
            secureTab:ClearAllPoints()
            secureTab:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        end
    end

    for category in pairs(secureQueueTabs) do
        for cardIndex = 1, MAX_CARDS do
            local x, y = GetSecureActionPosition(category, cardIndex)
            local card = panel.cards[cardIndex]
            local secureActionButton = card.secureActionButtons[category]
            if x and y and secureActionButton then
                secureActionButton:SetFrameStrata(panel:GetFrameStrata())
                secureActionButton:SetFrameLevel(card.actionButton:GetFrameLevel() + 1)
                secureActionButton:ClearAllPoints()
                secureActionButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                card.actionBlocker:SetFrameLevel(card.actionButton:GetFrameLevel() + 2)
            end
        end
    end

    local closeLeft = panel.closeButton:GetLeft()
    local closeBottom = panel.closeButton:GetBottom()
    if closeLeft and closeBottom then
        secureCloseButton:SetFrameStrata(panel:GetFrameStrata())
        secureCloseButton:SetFrameLevel(panel.closeButton:GetFrameLevel() + 10)
        secureCloseButton:ClearAllPoints()
        secureCloseButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", closeLeft, closeBottom)
    end

    for _, secureTab in pairs(secureQueueTabs) do
        secureTab:SetShown(panel:IsShown())
    end
    local selectedCategory = GetQueueCategory()
    for cardIndex, card in ipairs(panel.cards) do
        for category, secureActionButton in pairs(card.secureActionButtons) do
            local secureTab = secureQueueTabs[category]
            local count = secureTab and secureTab:GetAttribute(category .. "Count") or 0
            secureActionButton:SetShown(
                panel:IsShown() and category == selectedCategory and cardIndex <= count
            )
        end
    end
    secureCloseButton:SetShown(panel:IsShown())
end

HideSecureQueueControls = function()
    if not secureCloseButton or not IsPVPUISettingUpAllowed() then return end
    for _, secureTab in pairs(secureQueueTabs) do
        secureTab:Hide()
    end
    for _, card in ipairs(panel.cards) do
        for _, secureActionButton in pairs(card.secureActionButtons) do
            secureActionButton:Hide()
        end
    end
    secureCloseButton:Hide()
end

local function GetBuiltInPVPRoleCheckButton(frameKey)
    local pvpFrame = GetQueueCategory() == QUEUE_CATEGORY_UNRATED and _G.HonorFrame or _G.ConquestFrame
    local roleList = pvpFrame and pvpFrame.RoleList
    local roleButton = roleList and roleList[frameKey]
    return roleButton and roleButton.checkButton
end

local function GetPVPRoleSelections()
    local getPVPRoles = _G.GetPVPRoles
    if not getPVPRoles then return {} end

    local tank, healer, damager = getPVPRoles()
    return {
        TANK = not not tank,
        HEALER = not not healer,
        DAMAGER = not not damager,
    }
end

local function AreHeaderRolesLocked()
    return InCombatLockdown and InCombatLockdown() or false
end

local function ApplyHeaderRoleButtonTheme(button, theme)
    local borderColor = button.selected and theme.accent or theme.border
    local borderAlpha = button.available and (button.selected and 0.95 or 0.48) or 0.20
    local backgroundColor = button.selected and theme.accent or theme.surface
    local backgroundAlpha = button.selected and 0.22 or 0

    HelperPanel.SetTextureColor(button.border, borderColor, borderAlpha)
    HelperPanel.SetTextureColor(button.bg, backgroundColor, backgroundAlpha)
    HelperPanel.SetTextureColor(button.highlight, theme.rowHover)
    button.icon:SetDesaturated(not button.available)
    button.icon:SetAlpha(button.available and (button.selected and 1 or 0.58) or 0.22)
end

local function UpdateHeaderRoleSelector(theme)
    if not panel or not panel.roleButtons then return end

    local selections = GetPVPRoleSelections()
    local rolesLocked = AreHeaderRolesLocked()
    theme = theme or HelperPanel.GetTheme()
    for _, button in ipairs(panel.roleButtons) do
        local builtInCheckButton = GetBuiltInPVPRoleCheckButton(button.frameKey)
        button.locked = rolesLocked
        button.available = not rolesLocked
            and builtInCheckButton ~= nil
            and builtInCheckButton:IsEnabled()
        button.selected = selections[button.role] == true
        button:SetEnabled(button.available)
        ApplyHeaderRoleButtonTheme(button, theme)
    end
end

local function ToggleHeaderPVPRole(button)
    if not button.available then return end

    local getPVPRoles = _G.GetPVPRoles
    local setPVPRoles = _G.SetPVPRoles
    if not getPVPRoles or not setPVPRoles then return end

    local tank, healer, damager = getPVPRoles()
    tank = not not tank
    healer = not not healer
    damager = not not damager
    if button.role == "TANK" then
        tank = not tank
    elseif button.role == "HEALER" then
        healer = not healer
    elseif button.role == "DAMAGER" then
        damager = not damager
    end

    setPVPRoles(tank, healer, damager)
    if _G.LFG_UpdateAllRoleCheckboxes then
        _G.LFG_UpdateAllRoleCheckboxes()
    end
    UpdatePanel()
end

local function CreateHeaderRoleSelector()
    panel.roleButtons = {}
    local anchor = panel.minimizeButton
    for roleIndex = #PVP_ROLE_OPTIONS, 1, -1 do
        local roleOption = PVP_ROLE_OPTIONS[roleIndex]
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(HEADER_ROLE_BUTTON_SIZE, HEADER_ROLE_BUTTON_SIZE)
        local gap = roleIndex == #PVP_ROLE_OPTIONS and HEADER_ROLE_SELECTOR_GAP or HEADER_ROLE_BUTTON_GAP
        button:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
        button:SetFrameLevel(panel:GetFrameLevel() + 5)
        button:RegisterForClicks("LeftButtonUp")
        button.role = roleOption.role
        button.frameKey = roleOption.frameKey

        button.border = button:CreateTexture(nil, "BORDER")
        button.border:SetAllPoints()

        button.bg = button:CreateTexture(nil, "BORDER", nil, 1)
        button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16)
        button.icon:SetPoint("CENTER")
        button.icon:SetAtlas(roleOption.atlas, false)

        button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
        button.highlight:SetAllPoints()
        button:SetHighlightTexture(button.highlight)

        button:SetScript("OnClick", ToggleHeaderPVPRole)

        panel.roleButtons[roleIndex] = button
        anchor = button
    end
end

local function ApplyQueueEyeEffectTheme(theme)
    if not queueEyeEffect or not theme then return end
    local accent = theme.accent
    local transparent = _G.CreateColor(accent[1], accent[2], accent[3], 0)
    local line = _G.CreateColor(accent[1], accent[2], accent[3], 0.72)

    queueEyeEffect.leftLine:SetGradient("HORIZONTAL", transparent, line)
    queueEyeEffect.rightLine:SetGradient("HORIZONTAL", line, transparent)
    queueEyeEffect.leftGlow:SetVertexColor(accent[1], accent[2], accent[3], 1)
    queueEyeEffect.rightGlow:SetVertexColor(accent[1], accent[2], accent[3], 1)
    queueEyeEffect.leftHaze:SetVertexColor(accent[1], accent[2], accent[3], 1)
    queueEyeEffect.rightHaze:SetVertexColor(accent[1], accent[2], accent[3], 1)
end

local function ApplyPanelTheme()
    if not panel then return end
    local theme = HelperPanel.ApplyShellTheme(panel)
    if panel.minimizeButton then
        HelperPanel.SetTextureColor(panel.minimizeButton.highlight, theme.rowHover)
        HelperPanel.SetTextureColor(panel.minimizeButton.horizontalLine, theme.text)
        HelperPanel.SetTextureColor(panel.minimizeButton.verticalLine, theme.text)
    end
    UpdateQueueTabs(panel.state, theme)
    UpdateHeaderRoleSelector(theme)
    for _, card in ipairs(panel.cards) do
        if card:IsShown() then
            ApplyCardTheme(card, theme)
        end
    end
    ApplyQueueEyeEffectTheme(theme)
end

ArenaQueue.ApplyTheme = ApplyPanelTheme

local function RefreshSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, UpdatePanel)
    else
        UpdatePanel()
    end
end

local function RefreshBuiltInQueueStatusSoon()
    local function RefreshBuiltInQueueStatus()
        local queueStatusFrame = _G.QueueStatusFrame
        if queueStatusFrame and queueStatusFrame.Update then
            queueStatusFrame:Update()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, RefreshBuiltInQueueStatus)
    else
        RefreshBuiltInQueueStatus()
    end
end

local function CancelAbandonedPVPRoleCheck()
    if not GetLFGRoleUpdate then return end

    local inProgress, _, _, _, _, isBattleground = GetLFGRoleUpdate()
    local completeRoleCheck = _G.CompleteLFGRoleCheck
    if inProgress and isBattleground and completeRoleCheck then
        completeRoleCheck(false)
    end
end

local function CanMoveQueueStatusButton(button)
    return not (
        InCombatLockdown
        and InCombatLockdown()
        and button.IsProtected
        and button:IsProtected()
    )
end

local function CaptureQueueStatusLayout(button)
    local points = {}
    for pointIndex = 1, button:GetNumPoints() do
        points[pointIndex] = { button:GetPoint(pointIndex) }
    end

    return {
        parent = button:GetParent(),
        frameStrata = button:GetFrameStrata(),
        frameLevel = button:GetFrameLevel(),
        points = points,
    }
end

local function SetQueueStatusPoint(button, point, relativeTo, relativePoint, xOffset, yOffset)
    local wasChanging = button.changing
    button.changing = true
    button:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
    button.changing = wasChanging
end

local function HideQueueEyeEffect()
    if not queueEyeEffect then return end
    queueEyeEffect.pulse:Stop()
    queueEyeEffect:SetAlpha(0.82)
    queueEyeEffect:Hide()
end

local function ShowQueueEyeEffect(button)
    if not panel or not button then return end

    if not queueEyeEffect then
        queueEyeEffect = CreateFrame("Frame", nil, panel)
        queueEyeEffect:EnableMouse(false)
        queueEyeEffect:SetAlpha(0.82)
        queueEyeEffect:SetScale(QUEUE_EYE_FLARE_SCALE)

        queueEyeEffect.leftHaze = queueEyeEffect:CreateTexture(nil, "BACKGROUND")
        queueEyeEffect.leftHaze:SetTexture("Interface\\Cooldown\\star4")
        queueEyeEffect.leftHaze:SetTexCoord(0, 0.5, 0, 1)
        queueEyeEffect.leftHaze:SetBlendMode("ADD")
        queueEyeEffect.leftHaze:SetAlpha(0.13)

        queueEyeEffect.rightHaze = queueEyeEffect:CreateTexture(nil, "BACKGROUND")
        queueEyeEffect.rightHaze:SetTexture("Interface\\Cooldown\\star4")
        queueEyeEffect.rightHaze:SetTexCoord(0.5, 1, 0, 1)
        queueEyeEffect.rightHaze:SetBlendMode("ADD")
        queueEyeEffect.rightHaze:SetAlpha(0.13)

        queueEyeEffect.leftGlow = queueEyeEffect:CreateTexture(nil, "BACKGROUND")
        queueEyeEffect.leftGlow:SetTexture("Interface\\Cooldown\\star4")
        queueEyeEffect.leftGlow:SetTexCoord(0, 0.5, 0, 1)
        queueEyeEffect.leftGlow:SetBlendMode("ADD")
        queueEyeEffect.leftGlow:SetAlpha(0.30)

        queueEyeEffect.rightGlow = queueEyeEffect:CreateTexture(nil, "BACKGROUND")
        queueEyeEffect.rightGlow:SetTexture("Interface\\Cooldown\\star4")
        queueEyeEffect.rightGlow:SetTexCoord(0.5, 1, 0, 1)
        queueEyeEffect.rightGlow:SetBlendMode("ADD")
        queueEyeEffect.rightGlow:SetAlpha(0.30)

        queueEyeEffect.leftLine = queueEyeEffect:CreateTexture(nil, "ARTWORK")
        queueEyeEffect.leftLine:SetTexture("Interface\\Buttons\\WHITE8X8")
        queueEyeEffect.leftLine:SetHeight(1)

        queueEyeEffect.rightLine = queueEyeEffect:CreateTexture(nil, "ARTWORK")
        queueEyeEffect.rightLine:SetTexture("Interface\\Buttons\\WHITE8X8")
        queueEyeEffect.rightLine:SetHeight(1)

        queueEyeEffect.pulse = queueEyeEffect:CreateAnimationGroup()
        local pulse = queueEyeEffect.pulse:CreateAnimation("Alpha")
        pulse:SetFromAlpha(0.82)
        pulse:SetToAlpha(1)
        pulse:SetDuration(2.2)
        pulse:SetSmoothing("IN_OUT")
        queueEyeEffect.pulse:SetLooping("BOUNCE")
    end

    local eyeSize = math.max(button:GetWidth(), button:GetHeight(), 36)
    queueEyeEffect:SetSize(eyeSize + 84, eyeSize + 16)
    queueEyeEffect:ClearAllPoints()
    queueEyeEffect:SetPoint("CENTER", button, "CENTER")
    queueEyeEffect:SetFrameStrata(panel:GetFrameStrata())
    queueEyeEffect:SetFrameLevel(panel:GetFrameLevel() + 19)

    queueEyeEffect.leftHaze:ClearAllPoints()
    queueEyeEffect.leftHaze:SetPoint("RIGHT", button, "LEFT", 15, 0)
    queueEyeEffect.leftHaze:SetSize(42, 14)
    queueEyeEffect.rightHaze:ClearAllPoints()
    queueEyeEffect.rightHaze:SetPoint("LEFT", button, "RIGHT", -15, 0)
    queueEyeEffect.rightHaze:SetSize(42, 14)

    queueEyeEffect.leftGlow:ClearAllPoints()
    queueEyeEffect.leftGlow:SetPoint("RIGHT", button, "LEFT", 13, 0)
    queueEyeEffect.leftGlow:SetSize(58, 8)
    queueEyeEffect.rightGlow:ClearAllPoints()
    queueEyeEffect.rightGlow:SetPoint("LEFT", button, "RIGHT", -13, 0)
    queueEyeEffect.rightGlow:SetSize(58, 8)

    queueEyeEffect.leftLine:ClearAllPoints()
    queueEyeEffect.leftLine:SetPoint("RIGHT", button, "LEFT", 0, 0)
    queueEyeEffect.leftLine:SetWidth(76)
    queueEyeEffect.rightLine:ClearAllPoints()
    queueEyeEffect.rightLine:SetPoint("LEFT", button, "RIGHT", 0, 0)
    queueEyeEffect.rightLine:SetWidth(76)

    if button:IsShown() then
        queueEyeEffect:Show()
        if not queueEyeEffect.pulse:IsPlaying() then
            queueEyeEffect.pulse:Play()
        end
    else
        HideQueueEyeEffect()
    end
end

local function RestoreQueueStatusButton()
    local button = _G.QueueStatusButton
    if not button or not queueStatusRelocated or not queueStatusOriginalLayout then return end
    if not CanMoveQueueStatusButton(button) then return end

    local layout = queueStatusOriginalLayout
    button:SetParent(layout.parent or UIParent)
    button:SetFrameStrata(layout.frameStrata)
    button:SetFrameLevel(layout.frameLevel)
    button:ClearAllPoints()
    for _, point in ipairs(layout.points) do
        SetQueueStatusPoint(button, unpack(point))
    end

    HideQueueEyeEffect()
    queueStatusOriginalLayout = nil
    queueStatusRelocated = false
end

local function RelocateQueueStatusButton()
    local button = _G.QueueStatusButton
    if not button or not panel or not panel:IsShown() then return false end
    if not CanMoveQueueStatusButton(button) then return false end

    if not queueStatusRelocated then
        queueStatusOriginalLayout = CaptureQueueStatusLayout(button)
        queueStatusRelocated = true
    end

    button:SetParent(panel)
    button:SetFrameStrata(panel:GetFrameStrata())
    button:SetFrameLevel(panel:GetFrameLevel() + 20)
    button:ClearAllPoints()
    SetQueueStatusPoint(
        button,
        "TOP",
        panel,
        "BOTTOM",
        0,
        -QUEUE_EYE_TOP_PADDING
    )
    ShowQueueEyeEffect(button)

    if not queueStatusHooked then
        button:HookScript("OnShow", RefreshSoon)
        button:HookScript("OnHide", RefreshSoon)
        queueStatusHooked = true
    end
    return true
end

local function UpdateMinimizeButton()
    local button = panel and panel.minimizeButton
    if not button then return end

    local minimized = IsPanelMinimized()
    button.verticalLine:SetShown(minimized)
    button.tooltipText = minimized and "Expand queue helper" or "Minimize queue helper"
    button:SetEnabled(IsPVPUISettingUpAllowed())
end

local function ApplyCardLayout(card, minimized, isRated)
    if card.minimizedLayout == minimized and card.ratedLayout == isRated then return end
    card.minimizedLayout = minimized
    card.ratedLayout = isRated

    local cardHeight = minimized and MINIMIZED_CARD_HEIGHT or (isRated and CARD_HEIGHT or UNRATED_CARD_HEIGHT)
    card:SetSize(CARD_WIDTH, cardHeight)
    card.borderLeft:SetHeight(cardHeight)
    card.borderRight:SetHeight(cardHeight)

    card.modeName:ClearAllPoints()
    card.progressBg:ClearAllPoints()
    card.actionButton:ClearAllPoints()
    card.statusDot:ClearAllPoints()

    if minimized then
        card.badgeBg:Hide()
        card.badge:Hide()
        card.ratingValue:Hide()
        card.ratingLabel:Hide()
        card.sessionDelta:Hide()
        card.rankText:Hide()
        card.statusDot:Hide()
        card.statusText:Hide()

        card.modeName:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -6)
        card.modeName:SetPoint("RIGHT", card.actionButton, "LEFT", -8, 0)
        card.progressBg:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 2)
        card.actionButton:SetPoint("RIGHT", card, "RIGHT", -9, 0)
    else
        card.badgeBg:SetShown(isRated)
        card.badge:SetShown(isRated)
        card.ratingValue:SetShown(isRated)
        card.ratingLabel:SetShown(isRated)
        card.rankText:SetShown(isRated)
        card.statusDot:Show()
        card.statusText:Show()

        local contentLeft = isRated and 64 or 10
        card.modeName:SetPoint("TOPLEFT", card, "TOPLEFT", contentLeft, -10)
        if isRated then
            card.modeName:SetPoint("RIGHT", card.ratingValue, "LEFT", -8, 0)
            card.statusDot:SetPoint("TOPLEFT", card, "TOPLEFT", 64, -49)
        else
            card.modeName:SetPoint("RIGHT", card, "RIGHT", -10, 0)
            card.statusDot:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -32)
        end
        card.progressBg:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, isRated and 34 or 27)
        card.actionButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -9, 7)
    end
end

local function UpdateQueuedRoleIcon(card, role, minimized, isRated)
    local roleAtlas = PVP_ROLE_ATLASES[role]
    local baseX = minimized and 10 or (isRated and 64 or 10)
    card.queuedRoleIcon:ClearAllPoints()
    card.modeName:ClearAllPoints()

    if roleAtlas then
        card.queuedRoleIcon:SetPoint("TOPLEFT", card, "TOPLEFT", baseX, minimized and -5 or -8)
        card.queuedRoleIcon:SetAtlas(roleAtlas, false)
        card.queuedRoleIcon:Show()
        baseX = baseX + 21
    else
        card.queuedRoleIcon:Hide()
    end

    card.modeName:SetPoint("TOPLEFT", card, "TOPLEFT", baseX, minimized and -6 or -10)
    if minimized then
        card.modeName:SetPoint("RIGHT", card.actionButton, "LEFT", -8, 0)
    elseif isRated then
        card.modeName:SetPoint("RIGHT", card.ratingValue, "LEFT", -8, 0)
    else
        card.modeName:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    end
end

local function RunVisualActionButtonScript(card, scriptName, mouseButton)
    local actionButton = card and card.actionButton
    local script = actionButton and actionButton:GetScript(scriptName)
    if script then
        script(actionButton, mouseButton)
    end
end

local function ResetVisualActionButton(card)
    local actionButton = card and card.actionButton
    if not actionButton then return end

    actionButton:UnlockHighlight()
    RunVisualActionButtonScript(card, "OnMouseUp", "LeftButton")
end

local function CreateCard(cardIndex)
    local card = CreateFrame("Frame", nil, panel)
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)

    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()

    card.readyGlow = card:CreateTexture(nil, "BORDER")
    card.readyGlow:SetAllPoints()
    card.readyGlow:SetBlendMode("ADD")
    card.readyGlow:Hide()

    card.accent = card:CreateTexture(nil, "ARTWORK")
    card.accent:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    card.accent:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
    card.accent:SetWidth(3)

    card.borderTop = HelperPanel.CreateBorder(card, "borderTop", "TOPLEFT", "TOPLEFT", 0, 0, CARD_WIDTH, 1)
    card.borderBottom = HelperPanel.CreateBorder(
        card,
        "borderBottom",
        "BOTTOMLEFT",
        "BOTTOMLEFT",
        0,
        0,
        CARD_WIDTH,
        1
    )
    card.borderLeft = HelperPanel.CreateBorder(card, "borderLeft", "TOPLEFT", "TOPLEFT", 0, 0, 1, CARD_HEIGHT)
    card.borderRight = HelperPanel.CreateBorder(
        card,
        "borderRight",
        "TOPRIGHT",
        "TOPRIGHT",
        0,
        0,
        1,
        CARD_HEIGHT
    )

    card.badgeBg = card:CreateTexture(nil, "BORDER")
    card.badgeBg:SetSize(48, 48)
    card.badgeBg:SetPoint("TOPLEFT", card, "TOPLEFT", 9, -9)

    card.badge = card:CreateTexture(nil, "ARTWORK")
    card.badge:SetSize(42, 42)
    card.badge:SetPoint("CENTER", card.badgeBg, "CENTER", 0, 0)

    card.ratingValue = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.ratingValue:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -9)
    card.ratingValue:SetJustifyH("RIGHT")

    card.ratingLabel = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.ratingLabel:SetPoint("TOPRIGHT", card.ratingValue, "BOTTOMRIGHT", 0, -1)
    card.ratingLabel:SetText("RATING")

    card.sessionDelta = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.sessionDelta:SetPoint("RIGHT", card.ratingLabel, "LEFT", -6, 0)
    card.sessionDelta:SetJustifyH("RIGHT")

    card.modeName = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.modeName:SetPoint("TOPLEFT", card, "TOPLEFT", 64, -10)
    card.modeName:SetPoint("RIGHT", card.ratingValue, "LEFT", -8, 0)
    card.modeName:SetJustifyH("LEFT")

    card.queuedRoleIcon = card:CreateTexture(nil, "OVERLAY")
    card.queuedRoleIcon:SetSize(16, 16)
    card.queuedRoleIcon:Hide()

    card.rankText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.rankText:SetPoint("TOPLEFT", card.modeName, "BOTTOMLEFT", 0, -4)
    card.rankText:SetPoint("RIGHT", card.sessionDelta, "LEFT", -8, 0)
    card.rankText:SetJustifyH("LEFT")

    card.statusDot = card:CreateTexture(nil, "ARTWORK")
    card.statusDot:SetSize(6, 6)
    card.statusDot:SetPoint("TOPLEFT", card, "TOPLEFT", 64, -49)

    card.statusText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.statusText:SetPoint("LEFT", card.statusDot, "RIGHT", 6, 0)
    card.statusText:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card.statusText:SetJustifyH("LEFT")

    card.progressBg = card:CreateTexture(nil, "ARTWORK")
    card.progressBg:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 34)
    card.progressBg:SetSize(CARD_PROGRESS_WIDTH, 3)
    card.progressBg:Hide()

    card.progressFill = card:CreateTexture(nil, "OVERLAY")
    card.progressFill:SetPoint("BOTTOMLEFT", card.progressBg, "BOTTOMLEFT", 0, 0)
    card.progressFill:SetHeight(3)
    card.progressFill:Hide()

    card.actionButton = CreateFrame(
        "Button",
        nil,
        card,
        "UIPanelButtonTemplate"
    )
    card.actionButton:SetSize(88, 22)
    card.actionButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -9, 7)
    card.actionButton:EnableMouse(false)

    card.actionBlocker = CreateFrame("Frame", nil, card)
    card.actionBlocker:SetAllPoints(card.actionButton)
    card.actionBlocker:SetFrameLevel(card.actionButton:GetFrameLevel() + 2)
    card.actionBlocker:EnableMouse(true)

    card.noShowWarningButton = CreateFrame("Button", nil, card)
    card.noShowWarningButton:SetSize(22, 22)
    card.noShowWarningButton:SetPoint("RIGHT", card.actionButton, "RIGHT", 0, 0)
    card.noShowWarningButton:SetFrameLevel(card.actionBlocker:GetFrameLevel() + 1)
    card.noShowWarningButton:EnableMouse(true)
    card.noShowWarningButton.icon = card.noShowWarningButton:CreateTexture(nil, "ARTWORK")
    card.noShowWarningButton.icon:SetSize(18, 18)
    card.noShowWarningButton.icon:SetPoint("CENTER")
    card.noShowWarningButton.icon:SetTexture(NoShow.alertTexture)
    card.noShowWarningButton:SetScript("OnEnter", function(button)
        NoShow.ShowQueueWarningTooltip(button)
    end)
    card.noShowWarningButton:SetScript("OnLeave", function(button)
        NoShow.HideQueueWarningTooltip(button)
    end)
    card.noShowWarningButton:SetScript("OnHide", function(button)
        NoShow.HideQueueWarningTooltip(button)
    end)
    card.noShowWarningButton:Hide()

    card.secureActionButtons = {}
    for _, category in ipairs({ QUEUE_CATEGORY_RATED, QUEUE_CATEGORY_UNRATED }) do
        local buttonCategory = category
        local secureActionButton = CreateFrame(
            "Button",
            SECURE_BUTTON_NAMES[buttonCategory][cardIndex],
            UIParent,
            "SecureActionButtonTemplate"
        )
        secureActionButton:SetSize(88, 22)
        secureActionButton:RegisterForClicks("LeftButtonUp")
        secureActionButton:SetAttribute("type", nil)
        secureActionButton:SetAttribute("macrotext", nil)
        secureActionButton:SetAttribute("useOnKeyDown", false)
        secureActionButton:SetScript("OnEnter", function()
            if card.actionButton:IsShown() and card.actionButton:IsEnabled() then
                card.actionButton:LockHighlight()
            end
        end)
        secureActionButton:SetScript("OnLeave", function()
            ResetVisualActionButton(card)
        end)
        secureActionButton:SetScript("OnMouseDown", function(_, mouseButton)
            if mouseButton == "LeftButton"
                and card.actionButton:IsShown()
                and card.actionButton:IsEnabled()
            then
                RunVisualActionButtonScript(card, "OnMouseDown", mouseButton)
            end
        end)
        secureActionButton:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                RunVisualActionButtonScript(card, "OnMouseUp", mouseButton)
            end
        end)
        secureActionButton:SetScript("OnHide", function()
            ResetVisualActionButton(card)
        end)
        secureActionButton:SetScript("PostClick", function()
            local state = card.cardState
            if state and state.category == buttonCategory and state.bracket then
                local now = GetTime and GetTime() or 0
                pendingRoleCheck = {
                    bracketKey = state.bracket.key,
                    expiresAt = now + 5,
                }
            end
            RefreshSoon()
        end)
        secureActionButton:Hide()
        card.secureActionButtons[buttonCategory] = secureActionButton
        EnsureBracketProxy(buttonCategory, cardIndex)
    end

    card.queueText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.queueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 13)
    card.queueText:SetPoint("RIGHT", card.actionButton, "LEFT", -8, 0)
    card.queueText:SetJustifyH("LEFT")
    card.queueText:SetJustifyV("MIDDLE")

    card.compactRating = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.compactRating:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 7)
    card.compactRating:SetJustifyH("LEFT")
    card.compactRating:Hide()

    card.compactDelta = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.compactDelta:SetPoint("LEFT", card.compactRating, "RIGHT", 8, 0)
    card.compactDelta:SetJustifyH("LEFT")
    card.compactDelta:Hide()

    card:Hide()
    return card
end

local function EnsurePanel()
    if panel or not GetObjectiveTracker() then return end
    if not IsPVPUISettingUpAllowed() then return end

    panel = HelperPanel.CreateShell(
        "WarbandRatingsRatedQueueFrame",
        PANEL_WIDTH,
        1,
        ns.DISPLAY_NAME .. " - Queues"
    )
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", StartPanelMove)
    panel:SetScript("OnDragStop", StopPanelMove)
    panel:SetScript("OnHide", function()
        StopPanelMove()
        HideSecureQueueControls()
        RestoreQueueStatusButton()
    end)

    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.closeButton:SetSize(20, 20)
    panel.closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.closeButton:SetFrameLevel(panel:GetFrameLevel() + 5)
    panel.closeButton:SetScript("OnClick", function()
        ArenaQueue.Hide()
    end)

    panel.minimizeButton = CreateFrame("Button", nil, panel)
    panel.minimizeButton:SetSize(18, 18)
    panel.minimizeButton:SetPoint("RIGHT", panel.closeButton, "LEFT", -1, 0)
    panel.minimizeButton:SetFrameLevel(panel:GetFrameLevel() + 5)

    panel.minimizeButton.highlight = panel.minimizeButton:CreateTexture(nil, "HIGHLIGHT")
    panel.minimizeButton.highlight:SetAllPoints()
    panel.minimizeButton:SetHighlightTexture(panel.minimizeButton.highlight)

    panel.minimizeButton.horizontalLine = panel.minimizeButton:CreateTexture(nil, "ARTWORK")
    panel.minimizeButton.horizontalLine:SetPoint("CENTER")
    panel.minimizeButton.horizontalLine:SetSize(9, 2)

    panel.minimizeButton.verticalLine = panel.minimizeButton:CreateTexture(nil, "ARTWORK")
    panel.minimizeButton.verticalLine:SetPoint("CENTER")
    panel.minimizeButton.verticalLine:SetSize(2, 9)

    panel.minimizeButton:SetScript("OnEnter", function(button)
        if not GameTooltip then return end
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText(button.tooltipText)
        GameTooltip:Show()
    end)
    panel.minimizeButton:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    panel.minimizeButton:SetScript("OnClick", function()
        if not IsPVPUISettingUpAllowed() then return end
        SetPanelMinimized(not IsPanelMinimized())
        UpdateMinimizeButton()
        UpdatePanel()
    end)
    UpdateMinimizeButton()

    CreateHeaderRoleSelector()
    panel.title:SetPoint("RIGHT", panel.roleButtons[1], "LEFT", -4, 0)
    panel.title:SetJustifyH("LEFT")
    CreateQueueTabs()

    panel.cards = {}
    for cardIndex = 1, MAX_CARDS do
        panel.cards[cardIndex] = CreateCard(cardIndex)
    end
    CreateSecureQueueControls()

    panel.dynamicElapsed = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        panel.dynamicElapsed = panel.dynamicElapsed + elapsed
        if panel.dynamicElapsed >= 0.2 then
            panel.dynamicElapsed = 0
            UpdateDynamicCards()
        end
    end)
end

local function LayoutPanel(cardCount, category)
    local minimized = IsPanelMinimized()
    local cardHeight = minimized
        and MINIMIZED_CARD_HEIGHT
        or (category == QUEUE_CATEGORY_UNRATED and UNRATED_CARD_HEIGHT or CARD_HEIGHT)
    local cardGap = minimized and MINIMIZED_CARD_GAP or CARD_GAP
    local bottomInset = minimized and MINIMIZED_PANEL_BOTTOM_INSET or PANEL_BOTTOM_INSET
    local height = PANEL_TOP_INSET
        + cardCount * cardHeight
        + math.max(cardCount - 1, 0) * cardGap
        + bottomInset
    panel.helperPanelHeight = height
    panel:SetSize(PANEL_WIDTH, height)

    for cardIndex, card in ipairs(panel.cards) do
        card:ClearAllPoints()
        if cardIndex <= cardCount then
            card:SetPoint(
                "TOPLEFT",
                panel,
                "TOPLEFT",
                CARD_SIDE_INSET,
                -PANEL_TOP_INSET - (cardIndex - 1) * (cardHeight + cardGap)
            )
        end
    end
end

local function PositionPanel()
    local tracker = GetObjectiveTracker()
    if not panel or isPanelMoving then return end

    local position = GetSavedPanelPosition()
    if position then
        SetPanelTopPosition(position.x, position.y)
        ClampPanelToScreen()
    elseif tracker then
        panel:ClearAllPoints()
        panel:SetPoint("TOPRIGHT", tracker, "TOPLEFT", -PANEL_GAP, 0)
    else
        return
    end
    HelperPanel.SnapFrameToPixelGrid(panel)
    panel:SetFrameLevel(((tracker and tracker:GetFrameLevel()) or 0) + 10)
end

local function UpdateCard(card, state)
    local minimized = IsPanelMinimized()
    ApplyCardLayout(card, minimized, state.isRated)
    card.cardState = state
    card.actionButton.cardState = state
    card.modeName:SetText(state.bracket.label)
    UpdateQueuedRoleIcon(card, state.queue and state.queue.role, minimized, state.isRated)
    card.ratingValue:SetText(state.rating.rating > 0 and state.rating.rating or "—")
    local sessionDelta = state.rating.sessionDelta
    if not minimized and sessionDelta and sessionDelta ~= 0 then
        local prefix = sessionDelta >= 0 and "+" or ""
        card.sessionDelta:SetText(prefix .. sessionDelta)
        card.sessionDelta:Show()
    else
        card.sessionDelta:SetText("")
        card.sessionDelta:Hide()
    end

    local rankText = state.rating.tierName
    if state.rating.ranking > 0 then
        rankText = rankText .. "  •  #" .. state.rating.ranking
    end
    card.rankText:SetText(rankText)

    card.badge:SetTexture(state.rating.tierIcon or FALLBACK_BADGE_TEXTURE)
    if state.rating.tierIcon then
        card.badge:SetTexCoord(0, 1, 0, 1)
    else
        card.badge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    card.statusText:SetText(state.statusText)
    local idleText = state.failureReason or state.bracket.description
    if state.noShowWarning then
        idleText = minimized and state.noShowWarningCompactText or state.noShowWarningText
    end
    card.queueText:SetText(idleText)
    local isLeaderOnly = state.failureKind == "notLeader"
    local isNoShow = state.failureKind == "noShow"
    local compactFailureButtonText
    if isLeaderOnly then
        compactFailureButtonText = "Leader only"
    elseif isNoShow then
        compactFailureButtonText = NoShow.GetActiveButtonText()
    end
    local ratingText = state.rating.rating > 0 and state.rating.rating or "—"
    local deltaText = sessionDelta == nil and "—" or ((sessionDelta >= 0 and "+" or "") .. sessionDelta)
    card.compactRating:SetText("Rating " .. ratingText)
    card.compactDelta:SetText("Session " .. deltaText)
    card.actionButton:SetText(
        isNoShow and NoShow.GetActiveButtonText()
            or (minimized and compactFailureButtonText or state.buttonText)
    )
    card.actionButton:SetEnabled(state.buttonEnabled)
    NoShow.UpdateQueueWarningDisplay(card, state, nil)
    card:Show()
    UpdateDynamicCard(card)
end

UpdatePanel = function()
    UpdateBuiltInPvPRatingDeltas()

    if ns.UI and ns.UI.UpdateQueueHelperPvPButton then
        ns.UI.UpdateQueueHelperPvPButton()
    end

    if IsHelperHidden() or not IsPlayerMaxLevel() or IsInInstancedContent() then
        if panel then panel:Hide() end
        RestoreQueueStatusButton()
        return
    end

    if not IsPVPUIReady() then
        LoadPVPUI()
    end
    EnsurePanel()
    if not panel then return end

    local state = GetPanelState()
    panel.state = state
    if not state then
        panel:Hide()
        RestoreQueueStatusButton()
        return
    end

    LayoutPanel(#state.cards, state.category)
    PositionPanel()
    for cardIndex, card in ipairs(panel.cards) do
        local cardState = state.cards[cardIndex]
        if cardState then
            UpdateCard(card, cardState)
        else
            card.cardState = nil
            card.actionButton.cardState = nil
            card:Hide()
            ClearSecureAction(cardIndex, state.category)
        end
    end

    panel:Show()
    SyncSecureQueueControls()
    RelocateQueueStatusButton()
    ApplyPanelTheme()
end

function ArenaQueue.Refresh()
    RefreshSoon()
end

function ArenaQueue.Show()
    if Database and Database.SetCharacterSetting then
        Database.SetCharacterSetting("hideArenaQueueHelper", false)
    elseif GetCharacterSettings() then
        GetCharacterSettings().hideArenaQueueHelper = false
    end
    if ns.UI and ns.UI.RefreshSettingsCheckboxes then
        ns.UI.RefreshSettingsCheckboxes()
    end
    if ns.UI and ns.UI.UpdateQueueHelperPvPButton then
        ns.UI.UpdateQueueHelperPvPButton()
    end
    if RequestRatedInfo then
        RequestRatedInfo()
    end
    if _G.RequestPVPRewards then
        _G.RequestPVPRewards()
    end
    if _G.RequestRandomBattlegroundInstanceInfo then
        _G.RequestRandomBattlegroundInstanceInfo()
    end
    RefreshSoon()
end

function ArenaQueue.Hide()
    if Database and Database.SetCharacterSetting then
        Database.SetCharacterSetting("hideArenaQueueHelper", true)
    elseif GetCharacterSettings() then
        GetCharacterSettings().hideArenaQueueHelper = true
    end
    if ns.UI and ns.UI.RefreshSettingsCheckboxes then
        ns.UI.RefreshSettingsCheckboxes()
    end
    if ns.UI and ns.UI.UpdateQueueHelperPvPButton then
        ns.UI.UpdateQueueHelperPvPButton()
    end
    if panel then
        if isPanelMoving then
            panel:StopMovingOrSizing()
            isPanelMoving = false
        end
        panel:Hide()
    end
    RestoreQueueStatusButton()
end

function ArenaQueue.Attach()
    if eventFrame then return end

    lastGroupSize = GetGroupSize()
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    eventFrame:RegisterEvent("PVP_TYPES_ENABLED")
    eventFrame:RegisterEvent("PVP_ROLE_UPDATE")
    eventFrame:RegisterEvent("PVP_RATED_STATS_UPDATE")
    eventFrame:RegisterEvent("PVP_REWARDS_UPDATE")
    eventFrame:RegisterEvent("PVP_BRAWL_INFO_UPDATED")
    eventFrame:RegisterEvent("PVP_WORLDSTATE_UPDATE")
    eventFrame:RegisterEvent("PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE")
    eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    eventFrame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
    eventFrame:RegisterEvent("LFG_ROLE_CHECK_UPDATE")
    eventFrame:RegisterEvent("LFG_ROLE_CHECK_HIDE")
    eventFrame:RegisterEvent("LFG_ROLE_CHECK_DECLINED")
    eventFrame:RegisterEvent("LFG_ROLE_CHECK_ROLE_CHOSEN")
    eventFrame:RegisterEvent("LFG_ROLE_UPDATE")
    eventFrame:RegisterEvent("LFG_UPDATE")
    eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:RegisterEvent("ADDON_LOADED")
    if _G.hooksecurefunc and _G.AcceptBattlefieldPort then
        _G.hooksecurefunc("AcceptBattlefieldPort", function(queueIndex, accepted)
            RecordBattlefieldPortResponse(queueIndex, accepted)
            RefreshSoon()
        end)
    end
    eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "ADDON_LOADED" and arg1 ~= "Blizzard_PVPUI" then
            return
        end

        if event == "UNIT_AURA" then
            local wasActive = noShowPenaltyActive
            local previousSpellID = NoShow.activeSpellID
            NoShow.ScanActivePenalty()
            if noShowPenaltyActive == wasActive
                and NoShow.activeSpellID == previousSpellID
            then
                return
            end
        end

        if event == "GROUP_ROSTER_UPDATE" then
            local groupSize = GetGroupSize()
            local leftGroup = (lastGroupSize or groupSize) > 1 and groupSize <= 1
            lastGroupSize = groupSize
            if leftGroup then
                CancelAbandonedPVPRoleCheck()
                pendingRoleCheck = nil
                activeRoleCheckBracketKey = nil
                roleCheckTracking = nil
                roleCheckResponses = {}
            end
            RefreshBuiltInQueueStatusSoon()
        end

        if event == "LFG_ROLE_CHECK_SHOW" then
            ScanPVPRoleCheck()
        elseif event == "LFG_ROLE_CHECK_UPDATE" then
            ScanPVPRoleCheck()
            if UpdateDynamicCards then
                UpdateDynamicCards()
            end
        elseif event == "LFG_ROLE_CHECK_ROLE_CHOSEN" then
            MarkRoleCheckPlayerResponded(arg1)
            if not roleCheckTracking then
                ScanPVPRoleCheck()
            end
            if UpdateDynamicCards then
                UpdateDynamicCards()
            end
        elseif event == "LFG_ROLE_CHECK_HIDE" then
            roleCheckTracking = nil
            roleCheckResponses = {}
        end

        if event == "PLAYER_LOGIN" then
            ratedStatsReady = false
            ratingSessionInitialized = false
            ratingSessionResumeSaved = nil
            ratingSessionRecord = nil
            sessionRatingBaselines = {}
        elseif event == "PLAYER_ENTERING_WORLD" then
            NoShow.ScanActivePenalty()
            ratedStatsReady = false
            if ratingSessionResumeSaved == nil then
                ratingSessionResumeSaved = arg2 == true
                InitializeRatingSession()
            end
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            ratedStatsReady = false
        elseif event == "PVP_RATED_STATS_UPDATE" then
            ratedStatsReady = true
            CaptureSessionRatingBaselines()
        end

        if (event == "PLAYER_LOGIN"
            or event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_SPECIALIZATION_CHANGED")
            and RequestRatedInfo then
            RequestRatedInfo()
        end
        if (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD")
            and _G.RequestPVPRewards then
            _G.RequestPVPRewards()
        end
        if (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD")
            and _G.RequestRandomBattlegroundInstanceInfo then
            _G.RequestRandomBattlegroundInstanceInfo()
        end
        RefreshSoon()
    end)
end

ArenaQueue.Attach()
