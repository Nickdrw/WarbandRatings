-- luacheck: globals WarbandRatingsDB C_CurrencyInfo C_Timer UIParent DEFAULT_CHAT_FRAME GameTooltip CreateFrame
-- luacheck: globals InCombatLockdown UnitAffectingCombat IsInInstance

local honor = 10000
local inCombat = false
local inInstance = false
local instanceType = "none"
local messages = {}
local frames = {}
local scheduledCallbacks = {}
local themeTitle = { 0.2, 0.6, 0.9 }
local settingsRefreshes = 0

WarbandRatingsDB = {
    settings = {
        honorAlertThreshold = 12000,
    },
}

C_CurrencyInfo = {
    GetCurrencyInfo = function()
        return { quantity = honor, iconFileID = 12345 }
    end,
}

C_Timer = {
    After = function(_, callback)
        scheduledCallbacks[#scheduledCallbacks + 1] = callback
    end,
}

UIParent = {
    GetCenter = function() return 500, 400 end,
}

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message, red, green, blue)
        messages[#messages + 1] = {
            message = message,
            red = red,
            green = green,
            blue = blue,
        }
    end,
}

GameTooltip = {
    SetOwner = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
}

InCombatLockdown = function() return inCombat end
UnitAffectingCombat = function() return inCombat end
IsInInstance = function() return inInstance, instanceType end

local function Noop() end

local function CreateTextureMock()
    return {
        SetPoint = Noop,
        SetAllPoints = Noop,
        SetSize = Noop,
        SetColorTexture = Noop,
        SetTexture = Noop,
    }
end

local function CreateFontStringMock(owner)
    local fontString = {
        owner = owner,
        SetShadowColor = Noop,
        SetShadowOffset = Noop,
    }
    fontString.SetTextColor = function(self, red, green, blue)
        self.textColor = { red, green, blue }
    end
    fontString.SetPoint = function(self, ...)
        self.point = { ... }
    end
    fontString.SetText = function(self, text) self.text = text end
    return fontString
end

local function CreateAnimationGroupMock()
    local group = { playing = false }
    group.CreateAnimation = function()
        return {
            SetOffset = Noop,
            SetDuration = Noop,
            SetSmoothing = Noop,
            SetOrder = Noop,
        }
    end
    group.SetLooping = Noop
    group.IsPlaying = function(self) return self.playing end
    group.Play = function(self) self.playing = true end
    group.Stop = function(self) self.playing = false end
    return group
end

CreateFrame = function()
    local frame = {
        scripts = {},
        shown = false,
    }
    frame.SetSize = Noop
    frame.SetFrameStrata = Noop
    frame.SetClampedToScreen = Noop
    frame.SetMovable = Noop
    frame.EnableMouse = Noop
    frame.RegisterForDrag = Noop
    frame.RegisterForClicks = Noop
    frame.RegisterEvent = Noop
    frame.ClearAllPoints = Noop
    frame.SetPoint = Noop
    frame.SetAllPoints = Noop
    frame.StartMoving = Noop
    frame.StopMovingOrSizing = Noop
    frame.CreateTexture = CreateTextureMock
    frame.CreateFontString = CreateFontStringMock
    frame.CreateAnimationGroup = CreateAnimationGroupMock
    frame.GetCenter = function() return 500, 400 end
    frame.Hide = function(self) self.shown = false end
    frame.Show = function(self) self.shown = true end
    frame.SetScript = function(self, scriptName, callback)
        self.scripts[scriptName] = callback
    end
    frames[#frames + 1] = frame
    return frame
end

local ns = {
    DISPLAY_NAME = "Warband PvP Companion",
    Database = {
        NormalizeHonorAlertThreshold = function(value)
            value = tonumber(value)
            return value and value >= 1 and math.floor(value) or 12000
        end,
        SetSetting = function(key, value)
            WarbandRatingsDB.settings[key] = value
        end,
        GetSettings = function()
            return WarbandRatingsDB.settings
        end,
    },
    Utils = {
        FormatNumber = function(value) return tostring(value) end,
    },
    UI = {
        GetActiveTheme = function()
            return { title = themeTitle }
        end,
        RefreshSettingsCheckboxes = function()
            settingsRefreshes = settingsRefreshes + 1
        end,
    },
}

assert(loadfile("HonorAlert.lua"))("WarbandRatings", ns)
ns.HonorAlert.Init()

local alertEvents = frames[1].scripts.OnEvent
assert(#frames == 1, "the Honor icon appeared at the yellow warning level")
assert(#messages == 0 and #scheduledCallbacks == 1,
    "the login warning was not held while currency data settled")

honor = 11000
alertEvents()
assert(#messages == 0, "a less-relevant login warning appeared before currency data settled")

scheduledCallbacks[1]()
assert(#messages == 1, "the coalesced login warning was not shown")
assert(messages[1].red == 1 and messages[1].green == 0.45 and messages[1].blue == 0.05,
    "the closer orange login warning was not selected")
assert(messages[1].message:find("You're approaching your 12000 Honor limit.", 1, true),
    "the approaching-limit warning did not use the expected wording")
assert(messages[1].message:find("currently: 11,000", 1, true),
    "the warning did not show the precise current Honor amount")
assert(not messages[1].message:find("HONOR WARNING", 1, true),
    "the removed HONOR WARNING label still appears in chat")
assert(messages[1].message:find("|cff3399e6Warband PvP Companion|r:", 1, true),
    "the add-on name did not use the selected theme title color")
assert(messages[1].message:find("|T12345:16:16:0:0|t |cff3399e6", 1, true) == 1,
    "the Honor currency icon was not placed before the add-on name")

alertEvents()
assert(#messages == 1, "the login warning repeated without an Honor gain")

themeTitle = { 1, 0.5, 0 }
honor = 11025
alertEvents()
honor = 11050
alertEvents()
assert(#messages == 1 and #scheduledCallbacks == 2,
    "rapid Honor gains were not held for deduplication")
scheduledCallbacks[2]()
assert(#messages == 2, "coalesced Honor gains did not produce one warning")
assert(messages[2].message:find("currently: 11,050", 1, true),
    "the coalesced warning did not keep the newest Honor amount")
assert(messages[2].message:find("|cffff8000Warband PvP Companion|r:", 1, true),
    "a changed theme color was not applied to the next chat alert")

honor = 12000
alertEvents()
local icon = frames[2]
assert(icon and icon.shown, "the Honor icon did not appear at the threshold")
assert(icon.bounce and icon.bounce.playing, "the Honor icon did not start bouncing")
assert(icon.amount and icon.amount.text == "12,000",
    "the Honor icon did not show the current Honor amount")
assert(icon.amount.point[1] == "TOP" and icon.amount.point[3] == "BOTTOM"
        and icon.amount.point[4] == 0 and icon.amount.point[5] == -2,
    "the Honor amount was not positioned just below the icon")
assert(icon.amount.owner == icon,
    "the Honor amount was attached to the bouncing icon instead of the stationary alert frame")
assert(icon.amount.textColor[1] == 1 and icon.amount.textColor[2] == 0.08
        and icon.amount.textColor[3] == 0.08,
    "the Honor amount did not use the red alert color")
assert(#messages == 2, "the red alert was not held for deduplication")
scheduledCallbacks[3]()
assert(#messages == 3, "the threshold crossing did not produce a red chat alert")
assert(messages[3].red == 1 and messages[3].green < 0.1 and messages[3].blue < 0.1,
    "the threshold Honor alert was not red")
assert(not messages[3].message:find("HONOR ALERT", 1, true),
    "the removed HONOR ALERT label still appears in chat")
assert(messages[3].message:find("You've reached your 12000 Honor limit.", 1, true),
    "the threshold alert did not use the expected wording")
assert(messages[3].message:find("currently: 12,000", 1, true),
    "the threshold alert did not show the precise current Honor amount")

icon.scripts.OnClick(icon, "RightButton")
assert(WarbandRatingsDB.settings.hideHonorAlertIcon == true and not icon.shown,
    "right-clicking did not persistently hide the bouncing Honor icon")
assert(settingsRefreshes == 1, "right-clicking the icon did not refresh its settings checkbox")
WarbandRatingsDB.settings.hideHonorAlertIcon = false
ns.HonorAlert.Refresh()
assert(icon.shown and #messages == 3,
    "re-enabling the bouncing Honor icon did not restore it without duplicating chat")

honor = 12050
alertEvents()
assert(icon.amount.text == "12,050", "the Honor amount on the icon did not update")
assert(#messages == 3, "the later red alert was not held for deduplication")
scheduledCallbacks[4]()
assert(#messages == 4, "an Honor gain above the threshold did not produce another red alert")

alertEvents()
assert(#messages == 4, "the red Honor alert repeated without an Honor gain")

inCombat = true
alertEvents()
assert(not icon.shown, "the Honor icon remained visible in combat")

inCombat = false
inInstance = true
alertEvents()
assert(not icon.shown, "the Honor icon remained visible in an instance")

inInstance = false
alertEvents()
assert(icon.shown, "the Honor icon did not return after leaving the instance")

honor = 9000
alertEvents()
assert(not icon.shown, "the Honor icon remained visible below the threshold")
assert(#messages == 4, "spending Honor incorrectly produced a chat alert")

honor = 10000
alertEvents()
assert(not icon.shown and #messages == 4,
    "the later yellow warning was not held for deduplication")
scheduledCallbacks[5]()
assert(#messages == 5,
    "a later Honor gain inside the yellow range did not produce a new warning")

inInstance = true
instanceType = "arena"
honor = 10100
alertEvents(nil, "CURRENCY_DISPLAY_UPDATE")
honor = 10200
alertEvents(nil, "CURRENCY_DISPLAY_UPDATE")
assert(#messages == 5 and #scheduledCallbacks == 5,
    "an Honor alert was scheduled while still inside instanced PvP")

inInstance = false
instanceType = "none"
alertEvents(nil, "CURRENCY_DISPLAY_UPDATE")
assert(#scheduledCallbacks == 5,
    "the instanced-PvP alert was released before the loading screen completed")
alertEvents(nil, "PLAYER_ENTERING_WORLD")
assert(#scheduledCallbacks == 6 and #messages == 5,
    "the instanced-PvP alert was not queued after the exit loading screen")
scheduledCallbacks[6]()
assert(#messages == 6 and messages[6].message:find("currently: 10,200", 1, true),
    "the post-instance alert did not use the newest Honor amount")

honor = 10300
alertEvents(nil, "CURRENCY_DISPLAY_UPDATE")
assert(#scheduledCallbacks == 7,
    "an outdoor Honor gain did not queue its normal alert")
scheduledCallbacks[7]()
assert(#messages == 7 and messages[7].message:find("currently: 10,300", 1, true),
    "the outdoor Honor gain did not produce its own alert")

print("honor alert tests passed")
