local _, ns = ...
ns.ArenaQueue = {}
local ArenaQueue = ns.ArenaQueue
local Database = ns.Database
local HelperPanel = ns.HelperPanel

local PANEL_WIDTH = 300
local PANEL_GAP = 8
local PANEL_TOP_INSET = 30
local PANEL_BOTTOM_INSET = 8
local CARD_HEIGHT = 100
local CARD_GAP = 7
local MINIMIZED_CARD_HEIGHT = 44
local MINIMIZED_CARD_GAP = 4
local MINIMIZED_PANEL_BOTTOM_INSET = 6
local CARD_SIDE_INSET = 8
local CARD_WIDTH = PANEL_WIDTH - CARD_SIDE_INSET * 2
local CARD_PROGRESS_WIDTH = CARD_WIDTH - 20
local MAX_CARDS = 3
local FALLBACK_BADGE_TEXTURE = 2022761
local QUEUE_EYE_TOP_PADDING = 6
local QUEUE_EYE_FLARE_SCALE = 1.15

local STATUS_COLORS = {
    rolecheck = { 1.00, 0.78, 0.25, 1 },
    queued = { 0.30, 0.68, 1.00, 1 },
    ready = { 0.24, 0.95, 0.48, 1 },
    active = { 0.72, 0.48, 1.00, 1 },
}
local SESSION_LOSS_COLOR = { 1.00, 0.32, 0.32, 1 }

local SECURE_PROXY_NAMES = {
    "WarbandRatingsRatedQueueProxy1",
    "WarbandRatingsRatedQueueProxy2",
    "WarbandRatingsRatedQueueProxy3",
}

local SECURE_BUTTON_NAMES = {
    "WarbandRatingsRatedQueueButton1",
    "WarbandRatingsRatedQueueButton2",
    "WarbandRatingsRatedQueueButton3",
}

local QUEUE_MACROS = {
    "/click " .. SECURE_PROXY_NAMES[1] .. " LeftButton\n/click ConquestJoinButton LeftButton",
    "/click " .. SECURE_PROXY_NAMES[2] .. " LeftButton\n/click ConquestJoinButton LeftButton",
    "/click " .. SECURE_PROXY_NAMES[3] .. " LeftButton\n/click ConquestJoinButton LeftButton",
}

local BRACKETS = {
    soloShuffle = {
        key = "soloShuffle",
        label = "Solo Shuffle",
        description = "Rated solo arena for one player.",
        bracketIndex = 7,
        targetKey = "RatedSoloShuffle",
    },
    ratedBGBlitz = {
        key = "ratedBGBlitz",
        label = "Battleground Blitz",
        description = "Rated 8v8 battleground for solo players or a duo with a healer.",
        bracketIndex = 9,
        targetKey = "RatedBGBlitz",
    },
    arena2v2 = {
        key = "arena2v2",
        label = "2v2 Arena",
        description = "Rated arena for your two-player group.",
        bracketIndex = 1,
        targetKey = "Arena2v2",
    },
    arena3v3 = {
        key = "arena3v3",
        label = "3v3 Arena",
        description = "Rated arena for your three-player group.",
        bracketIndex = 2,
        targetKey = "Arena3v3",
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

local eventFrame
local panel
local isPanelMoving
local pendingRoleCheck
local activeRoleCheckBracketKey
local ratedStatsReady
local ratingSessionInitialized
local ratingSessionResumeSaved
local ratingSessionRecord
local sessionRatingBaselines = {}
local bracketProxies = {}
local configuredBracketKeys = {}
local queueStatusOriginalLayout
local queueStatusRelocated
local queueStatusHooked
local queueEyeEffect
local builtInPvPDeltas = {}
local builtInPvPDeltasHooked
local UpdatePanel
local UpdateDynamicCards

local function IsHelperHidden()
    local settings = WarbandRatingsDB and WarbandRatingsDB.settings
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
end

local function IsPVPUIReady()
    return _G.ConquestFrame
        and _G.ConquestJoinButton
        and _G.ConquestFrame.RatedSoloShuffle
        and _G.ConquestFrame.RatedBGBlitz
        and _G.ConquestFrame.Arena2v2
        and _G.ConquestFrame.Arena3v3
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

local function EnsureBracketProxy(cardIndex)
    if bracketProxies[cardIndex] then return true end
    if not IsPVPUISettingUpAllowed() then return false end

    local proxy = CreateFrame(
        "Button",
        SECURE_PROXY_NAMES[cardIndex],
        UIParent,
        "InsecureActionButtonTemplate"
    )
    proxy:SetAttribute("type", "click")
    proxy:SetAttribute("useOnKeyDown", false)
    bracketProxies[cardIndex] = proxy
    return true
end

local function ConfigureSecureBracket(cardIndex, bracket)
    local card = panel and panel.cards and panel.cards[cardIndex]
    local button = card and card.actionButton
    if not bracket or not button then return false end
    if configuredBracketKeys[cardIndex] == bracket.key
        and bracketProxies[cardIndex]
        and button:GetAttribute("type") == "macro"
        and button:GetAttribute("macrotext") == QUEUE_MACROS[cardIndex] then
        return true
    end
    if not IsPVPUISettingUpAllowed() then return false end
    if not LoadPVPUI() or not EnsureBracketProxy(cardIndex) then return false end

    local target = _G.ConquestFrame[bracket.targetKey]
    if not target then return false end

    if configuredBracketKeys[cardIndex] ~= bracket.key then
        bracketProxies[cardIndex]:SetAttribute("clickbutton", target)
        configuredBracketKeys[cardIndex] = bracket.key
    end

    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", QUEUE_MACROS[cardIndex])
    return true
end

local function ClearSecureAction(cardIndex)
    local card = panel and panel.cards and panel.cards[cardIndex]
    local button = card and card.actionButton
    if not button or not IsPVPUISettingUpAllowed() then return false end

    button:SetAttribute("type", nil)
    button:SetAttribute("macrotext", nil)
    return true
end

local function GetQueueBracket(queueType, teamSize, registeredMatch, isSoloQueue)
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

local function ScanRatedQueues()
    local queues = {}
    local maxQueues = GetMaxBattlefieldID and GetMaxBattlefieldID()
    maxQueues = tonumber(maxQueues) or tonumber(_G.MAX_BATTLEFIELD_QUEUES) or 8

    for queueIndex = 1, maxQueues do
        local status, mapName, teamSize, registeredMatch, suspended, queueType, _, _, asGroup, _, _, isSoloQueue =
            GetBattlefieldStatus(queueIndex)
        local bracket = GetQueueBracket(queueType, teamSize, registeredMatch, isSoloQueue)
        if bracket and status and status ~= "none" then
            queues[bracket.key] = {
                index = queueIndex,
                status = status,
                mapName = mapName,
                suspended = suspended,
                asGroup = asGroup,
                isSolo = isSoloQueue
                    or bracket.key == "soloShuffle"
                    or bracket.key == "ratedBGBlitz",
                bracket = bracket,
            }
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
end

local function ScanRatedRoleCheck()
    if not GetLFGRoleUpdate then return nil end

    local inProgress, _, _, _, fifthValue, sixthValue = GetLFGRoleUpdate()
    if not inProgress then
        activeRoleCheckBracketKey = nil
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
    local bracket = bracketKey and BRACKETS[bracketKey]
    if not bracket then return nil end

    activeRoleCheckBracketKey = bracketKey
    pendingRoleCheck = nil
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

    for _, key in ipairs(BRACKET_DISPLAY_ORDER) do
        if queues[key] and not included[key] and #displayed < MAX_CARDS then
            displayed[#displayed + 1] = BRACKETS[key]
            included[key] = true
        end
    end

    return displayed
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

local function GetSoloShuffleFailure()
    if _G.ConquestFrame and _G.ConquestFrame.ratedSoloShuffleEnabled == false then
        return "Solo Shuffle is currently unavailable."
    elseif _G.ConquestFrame and _G.ConquestFrame.ratedSoloShuffleEnabled == nil then
        return "Waiting for rated PvP availability."
    end

    if C_PvP and C_PvP.GetRatedSoloShuffleMinItemLevel then
        local minItemLevel = tonumber(C_PvP.GetRatedSoloShuffleMinItemLevel()) or 0
        local playerPVPItemLevel = GetPlayerPVPItemLevel()
        if minItemLevel > 0 and playerPVPItemLevel < minItemLevel then
            if _G.INSTANCE_UNAVAILABLE_SELF_PVP_GEAR_TOO_LOW then
                return _G.INSTANCE_UNAVAILABLE_SELF_PVP_GEAR_TOO_LOW:format(minItemLevel, playerPVPItemLevel)
            end
            return "Your PvP item level is too low."
        end
    end
end

local function GetBlitzFailure(groupSize)
    if _G.ConquestFrame and _G.ConquestFrame.ratedBGBlitzEnabled == false then
        return "Battleground Blitz is currently unavailable."
    elseif _G.ConquestFrame and _G.ConquestFrame.ratedBGBlitzEnabled == nil then
        return "Waiting for rated PvP availability."
    end

    local lfgFailure = GetLFGListFailure()
    if lfgFailure then return lfgFailure end

    if groupSize == 2 and (not UnitIsGroupLeader or not UnitIsGroupLeader("player")) then
        return _G.PVP_NOT_LEADER or "Only the group leader can queue."
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
                if _G.INSTANCE_UNAVAILABLE_OTHER_GEAR_TOO_LOW and lowestPlayer then
                    return _G.INSTANCE_UNAVAILABLE_OTHER_GEAR_TOO_LOW:format(
                        lowestPlayer,
                        minItemLevel,
                        partyMinItemLevel
                    )
                end
                return "A group member's PvP item level is too low."
            end
        else
            local playerPVPItemLevel = GetPlayerPVPItemLevel()
            if minItemLevel > 0 and playerPVPItemLevel < minItemLevel then
                if _G.INSTANCE_UNAVAILABLE_SELF_PVP_GEAR_TOO_LOW then
                    return _G.INSTANCE_UNAVAILABLE_SELF_PVP_GEAR_TOO_LOW:format(
                        minItemLevel,
                        playerPVPItemLevel
                    )
                end
                return "Your PvP item level is too low."
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
        return _G.PVP_NOT_LEADER or "Only the group leader can queue."
    end

    local lfgFailure = GetLFGListFailure()
    if lfgFailure then return lfgFailure end

    local maxLevel = GetMaxLevelForLatestExpansion and GetMaxLevelForLatestExpansion()
    local unitPrefix, unitCount = GetGroupUnitLayout(groupSize)
    for index = 1, unitCount do
        local unit = unitPrefix .. index
        if UnitIsConnected and not UnitIsConnected(unit) then
            return _G.PVP_NO_QUEUE_DISCONNECTED_GROUP or "Every group member must be online."
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
                deltaText = bracketFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                deltaText:SetPoint("LEFT", currentRating, "RIGHT", 4, 0)
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
        end
    end

    if not builtInPvPDeltasHooked then
        conquestFrame:HookScript("OnShow", UpdateBuiltInPvPRatingDeltas)
        builtInPvPDeltasHooked = true
    end
end

local function BuildCardState(cardIndex, bracket, queue, commonFailure, groupSize)
    local state = {
        bracket = bracket,
        queue = queue,
        rating = GetRatingInfo(bracket),
        buttonText = "Queue",
        buttonEnabled = false,
        buttonVisible = true,
        visualState = "available",
    }

    if queue then
        if queue.status == "rolecheck" then
            state.buttonVisible = false
            state.visualState = "rolecheck"
            state.statusText = "ROLE CHECK"
            ClearSecureAction(cardIndex)
        elseif queue.status == "queued" then
            state.buttonVisible = false
            state.visualState = "queued"
            if queue.suspended then
                state.statusText = "QUEUE SUSPENDED"
            else
                state.statusText = "IN QUEUE"
            end
            ClearSecureAction(cardIndex)
        elseif queue.status == "confirm" then
            state.buttonText = "Match ready"
            state.visualState = "ready"
            state.statusText = "MATCH READY"
            ClearSecureAction(cardIndex)
        elseif queue.status == "active" then
            state.buttonText = "In match"
            state.visualState = "active"
            state.statusText = "MATCH IN PROGRESS"
            ClearSecureAction(cardIndex)
        else
            state.buttonText = "Unavailable"
            state.visualState = "active"
            state.statusText = "QUEUE LOCKED"
            ClearSecureAction(cardIndex)
        end
        return state
    end

    state.failureReason = commonFailure or GetBracketFailure(bracket, groupSize)
    if not state.failureReason and not ConfigureSecureBracket(cardIndex, bracket) then
        state.failureReason = "Rated PvP queue controls are not ready."
    end
    state.buttonEnabled = not state.failureReason
    state.statusText = state.failureReason or "READY TO QUEUE"
    return state
end

local function GetPanelState()
    if IsHelperHidden() or not GetObjectiveTracker() then return nil end

    local queues = ScanRatedQueues()
    local roleCheck = ScanRatedRoleCheck()
    if roleCheck and not queues[roleCheck.bracket.key] then
        queues[roleCheck.bracket.key] = roleCheck
    end
    local brackets = GetDisplayedBrackets(queues)
    if #brackets == 0 then return nil end

    local groupSize = GetGroupSize()
    local commonFailure
    if not IsPVPUIReady() then
        commonFailure = "Rated PvP UI is not ready."
    else
        commonFailure = GetRatedAccessFailure()
    end

    local state = {
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

local function UpdateDynamicCard(card)
    local state = card.cardState
    local queue = state and state.queue
    if not state or not queue then
        card.readyGlow:Hide()
        card.progressBg:Hide()
        card.progressFill:Hide()
        return
    end

    if queue.status == "rolecheck" then
        card.readyGlow:Hide()
        card.queueText:SetText("Waiting for all players to choose a role")
        card.progressBg:Hide()
        card.progressFill:Hide()
    elseif queue.status == "queued" then
        card.readyGlow:Hide()
        if queue.suspended then
            card.queueText:SetText("Queue suspended")
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

        if estimated > 0 then
            card.queueText:SetText(
                "Queued " .. FormatDuration(waited) .. "  •  Est. " .. FormatDuration(estimated)
            )
            SetCardProgress(card, waited / estimated)
        else
            card.queueText:SetText("Queued " .. FormatDuration(waited) .. "  •  Est. —")
            SetCardProgress(card, 0.08)
        end
        card.progressBg:Show()
    elseif queue.status == "confirm" then
        local expiration = GetBattlefieldPortExpiration
            and GetBattlefieldPortExpiration(queue.index)
            or 0
        card.queueText:SetText("Match ready  •  " .. FormatDuration(expiration))
        card.progressBg:Show()
        SetCardProgress(card, 1)
        card.readyGlow:Show()
        local now = GetTime and GetTime() or 0
        card.readyGlow:SetAlpha(0.12 + (math.sin(now * 5) + 1) * 0.10)
    else
        card.readyGlow:Hide()
        card.queueText:SetText(state.statusText)
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
    HelperPanel.SetTextureColor(card.badgeBg, theme.surface)
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
end

local function ApplyCardLayout(card, minimized)
    if card.minimizedLayout == minimized then return end
    card.minimizedLayout = minimized

    local cardHeight = minimized and MINIMIZED_CARD_HEIGHT or CARD_HEIGHT
    card:SetSize(CARD_WIDTH, cardHeight)
    card.borderLeft:SetHeight(cardHeight)
    card.borderRight:SetHeight(cardHeight)

    card.modeName:ClearAllPoints()
    card.progressBg:ClearAllPoints()
    card.actionButton:ClearAllPoints()

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
        card.badgeBg:Show()
        card.badge:Show()
        card.ratingValue:Show()
        card.ratingLabel:Show()
        card.rankText:Show()
        card.statusDot:Show()
        card.statusText:Show()

        card.modeName:SetPoint("TOPLEFT", card, "TOPLEFT", 64, -10)
        card.modeName:SetPoint("RIGHT", card.ratingValue, "LEFT", -8, 0)
        card.progressBg:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 34)
        card.actionButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -9, 7)
    end
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
        SECURE_BUTTON_NAMES[cardIndex],
        card,
        "InsecureActionButtonTemplate,UIPanelButtonTemplate"
    )
    card.actionButton:SetSize(88, 22)
    card.actionButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -9, 7)
    card.actionButton:RegisterForClicks("LeftButtonUp")
    card.actionButton:SetAttribute("type", "macro")
    card.actionButton:SetAttribute("macrotext", QUEUE_MACROS[cardIndex])
    card.actionButton:SetAttribute("useOnKeyDown", false)
    card.actionButton:SetScript("PostClick", function()
        local state = card.cardState
        if state and state.bracket then
            local now = GetTime and GetTime() or 0
            pendingRoleCheck = {
                bracketKey = state.bracket.key,
                expiresAt = now + 5,
            }
        end
        RefreshSoon()
    end)

    card.queueText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.queueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 13)
    card.queueText:SetPoint("RIGHT", card.actionButton, "LEFT", -8, 0)
    card.queueText:SetJustifyH("LEFT")

    card.compactRating = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.compactRating:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 7)
    card.compactRating:SetJustifyH("LEFT")
    card.compactRating:Hide()

    card.compactDelta = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.compactDelta:SetPoint("LEFT", card.compactRating, "RIGHT", 8, 0)
    card.compactDelta:SetJustifyH("LEFT")
    card.compactDelta:Hide()

    EnsureBracketProxy(cardIndex)
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
        "Warband Ratings"
    )
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", StartPanelMove)
    panel:SetScript("OnDragStop", StopPanelMove)
    panel:SetScript("OnHide", function()
        StopPanelMove()
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
        SetPanelMinimized(not IsPanelMinimized())
        UpdateMinimizeButton()
        UpdatePanel()
    end)
    UpdateMinimizeButton()

    panel.title:SetPoint("RIGHT", panel.minimizeButton, "LEFT", -2, 0)

    panel.cards = {}
    for cardIndex = 1, MAX_CARDS do
        panel.cards[cardIndex] = CreateCard(cardIndex)
    end

    panel.dynamicElapsed = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        panel.dynamicElapsed = panel.dynamicElapsed + elapsed
        if panel.dynamicElapsed >= 0.2 then
            panel.dynamicElapsed = 0
            UpdateDynamicCards()
        end
    end)
end

local function LayoutPanel(cardCount)
    local minimized = IsPanelMinimized()
    local cardHeight = minimized and MINIMIZED_CARD_HEIGHT or CARD_HEIGHT
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
    ApplyCardLayout(card, minimized)
    card.cardState = state
    card.actionButton.cardState = state
    card.modeName:SetText(state.bracket.label)
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
    card.queueText:SetText(state.failureReason or state.bracket.description)
    local showCompactRating = minimized and not state.failureReason and not state.queue
    local ratingText = state.rating.rating > 0 and state.rating.rating or "—"
    local deltaText = sessionDelta == nil and "—" or ((sessionDelta >= 0 and "+" or "") .. sessionDelta)
    card.compactRating:SetText("Rating " .. ratingText)
    card.compactRating:SetShown(showCompactRating)
    card.compactDelta:SetText("Session " .. deltaText)
    card.compactDelta:SetShown(showCompactRating)
    card.queueText:SetShown(not showCompactRating)
    card.actionButton:SetText(state.buttonText)
    card.actionButton:SetEnabled(state.buttonEnabled)
    card.actionButton:SetShown(state.buttonVisible)
    card.queueText:ClearAllPoints()
    card.queueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, minimized and 7 or 13)
    if state.buttonVisible then
        card.queueText:SetPoint("RIGHT", card.actionButton, "LEFT", -8, 0)
    else
        card.queueText:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    end
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

    LayoutPanel(#state.cards)
    PositionPanel()
    for cardIndex, card in ipairs(panel.cards) do
        local cardState = state.cards[cardIndex]
        if cardState then
            UpdateCard(card, cardState)
        else
            card.cardState = nil
            card.actionButton.cardState = nil
            card:Hide()
            ClearSecureAction(cardIndex)
        end
    end

    panel:Show()
    RelocateQueueStatusButton()
    ApplyPanelTheme()
end

function ArenaQueue.Refresh()
    RefreshSoon()
end

function ArenaQueue.Show()
    if Database and Database.SetSetting then
        Database.SetSetting("hideArenaQueueHelper", false)
    elseif GetSettings() then
        GetSettings().hideArenaQueueHelper = false
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
    RefreshSoon()
end

function ArenaQueue.Hide()
    if Database and Database.SetSetting then
        Database.SetSetting("hideArenaQueueHelper", true)
    elseif GetSettings() then
        GetSettings().hideArenaQueueHelper = true
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

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PVP_TYPES_ENABLED")
    eventFrame:RegisterEvent("PVP_RATED_STATS_UPDATE")
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
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "ADDON_LOADED" and arg1 ~= "Blizzard_PVPUI" then
            return
        end

        if event == "PLAYER_LOGIN" then
            ratedStatsReady = false
            ratingSessionInitialized = false
            ratingSessionResumeSaved = nil
            ratingSessionRecord = nil
            sessionRatingBaselines = {}
        elseif event == "PLAYER_ENTERING_WORLD" then
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
        RefreshSoon()
    end)
end

ArenaQueue.Attach()
