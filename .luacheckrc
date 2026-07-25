std = "lua51"
max_line_length = 160

-- WoW global API
read_globals = {
    -- Frames & UI
    "CreateFrame",
    "UIParent",
    "UISpecialFrames",
    "PVEFrame",
    "ConquestFrame",
    "PVPUIFrame",
    "ChallengesFrame",
    "Minimap",
    "MerchantFrame",
    "GameTooltip",
    "GetCursorPosition",
    "IsMouseButtonDown",
    "InCombatLockdown",

    -- Tables & constants
    "RAID_CLASS_COLORS",
    "CLASS_ICON_TCOORDS",
    "MAX_PARTY_MEMBERS",

    -- Unit info
    "UnitName",
    "UnitClass",
    "UnitGUID",
    "UnitLevel",
    "GetRealmName",
    "GetNormalizedRealmName",
    "GetMaxLevelForPlayerExpansion",
    "GetMaxLevelForLatestExpansion",
    "GetNumGroupMembers",
    "UnitIsConnected",
    "UnitIsGroupLeader",

    -- Spec
    "C_SpecializationInfo",
    "GetSpecialization",
    "GetSpecializationInfo",
    "GetSpecializationInfoByID",

    -- PvP
    "C_PvP",
    "C_LobbyMatchmakerInfo",
    "MAX_BATTLEFIELD_QUEUES",
    "GetAverageItemLevel",
    "GetBattlefieldEstimatedWaitTime",
    "GetBattlefieldPortExpiration",
    "GetBattlefieldStatus",
    "GetBattlefieldTimeWaited",
    "GetMaxBattlefieldID",
    "GetLFGRoleUpdate",
    "GetLFGRoleUpdateBattlegroundInfo",
    "GetBattlefieldArenaFaction",
    "GetBattlefieldTeamInfo",
    "GetBattlefieldWinner",
    "GetCurrentArenaSeason",
    "GetNumBattlefieldScores",
    "GetPersonalRatedInfo",
    "IsArenaSkirmish",
    "RequestRatedInfo",

    -- Statistics
    "GetStatistic",
    "RequestAchievementData",

    -- M+
    "C_ChallengeMode",
    "C_LFGList",
    "C_PartyInfo",

    -- Currency
    "C_CurrencyInfo",

    -- Items & merchants
    "C_Item",
    "C_Container",
    "C_MerchantFrame",
    "Enum",
    "GetItemCount",
    "GetMerchantNumItems",
    "GetMerchantItemInfo",
    "GetMerchantItemID",
    "GetMerchantItemLink",
    "GetMerchantItemCostInfo",
    "GetMerchantItemCostItem",
    "BuyMerchantItem",

    -- Misc
    "C_Timer",
    "C_AddOns",
    "C_SeasonInfo",
    "DEFAULT_CHAT_FRAME",
    "date",
    "GetTime",
    "tinsert",
    "time",
    "AddonCompartmentFrame",
    "Settings",
    "InterfaceOptions_AddCategory",
    "SettingsPanel",
    "LoadAddOn",
    "HideUIPanel",
    "InterfaceOptionsFrame",
}

-- Globals we define
globals = {
    "WarbandRatingsDB",
    "SLASH_WARBANDRATINGS1",
    "SLASH_WARBANDRATINGS2",
    "SlashCmdList",
    "WarbandRatings_OnAddonCompartmentClick",
    "WarbandRatings_OnAddonCompartmentEnter",
    "WarbandRatings_OnAddonCompartmentLeave",
}

-- Ignore unused self/event/msg in callbacks
ignore = {
    "212/self",   -- unused argument 'self'
    "212/event",  -- unused argument 'event'
    "212/msg",    -- unused argument 'msg'
}
