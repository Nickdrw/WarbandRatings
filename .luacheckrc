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

    -- Tables & constants
    "RAID_CLASS_COLORS",
    "CLASS_ICON_TCOORDS",

    -- Unit info
    "UnitName",
    "UnitClass",
    "UnitGUID",
    "UnitLevel",
    "GetRealmName",
    "GetNormalizedRealmName",
    "GetMaxLevelForPlayerExpansion",

    -- Spec
    "GetSpecialization",
    "GetSpecializationInfo",
    "GetSpecializationInfoByID",

    -- PvP
    "C_PvP",
    "MAX_BATTLEFIELD_QUEUES",
    "GetBattlefieldStatus",
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
    "C_SeasonInfo",
    "DEFAULT_CHAT_FRAME",
    "date",
    "tinsert",
    "time",
    "AddonCompartmentFrame",
    "Settings",
    "InterfaceOptions_AddCategory",
    "SettingsPanel",
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
