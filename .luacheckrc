std = "lua51"
max_line_length = 160

-- WoW global API
read_globals = {
    -- Frames & UI
    "CreateFrame",
    "UIParent",
    "UISpecialFrames",
    "PVEFrame",
    "PVPUIFrame",
    "Minimap",
    "GameTooltip",
    "GetCursorPosition",

    -- Tables & constants
    "RAID_CLASS_COLORS",
    "CLASS_ICON_TCOORDS",

    -- Unit info
    "UnitName",
    "UnitClass",
    "UnitLevel",
    "GetRealmName",
    "GetNormalizedRealmName",
    "GetMaxLevelForPlayerExpansion",

    -- Spec
    "GetSpecialization",
    "GetSpecializationInfo",
    "GetSpecializationInfoByID",

    -- PvP
    "GetPersonalRatedInfo",
    "RequestRatedInfo",

    -- M+
    "C_ChallengeMode",

    -- Misc
    "C_Timer",
    "tinsert",
    "date",
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
