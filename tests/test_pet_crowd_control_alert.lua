-- luacheck: globals UIParent CreateFrame C_AddOns C_Spell UnitClass AuraContainerSortMethod AuraContainerSortDirection

local playerClassFile = "HUNTER"
local loadedAddOn
local frames = {}
local settings = {
    petCrowdControlAlertEnabled = true,
    petCrowdControlAlertBouncing = true,
    petCrowdControlAlertOpacity = 1,
    petCrowdControlAlertSize = 64,
}

UIParent = {
    GetCenter = function() return 960, 540 end,
}

C_AddOns = {
    LoadAddOn = function(addOnName)
        loadedAddOn = addOnName
        return true
    end,
}

C_Spell = {
    GetSpellTexture = function(spellID)
        assert(spellID == 118, "the preview did not request the Polymorph texture")
        return 12345
    end,
}

UnitClass = function(unit)
    assert(unit == "player", "the alert checked the wrong unit's class")
    return playerClassFile == "HUNTER" and "Hunter" or "Mage", playerClassFile
end

AuraContainerSortMethod = { AuraInstanceIDOnly = 7 }
AuraContainerSortDirection = { Reverse = 2 }

local function Noop() end

local function CreateTextureMock()
    local texture = {}
    texture.SetAllPoints = function(self, target) self.allPointsTarget = target end
    texture.SetPoint = function(self, ...) self.point = { ... } end
    texture.SetTexture = function(self, asset) self.texture = asset end
    texture.SetAtlas = function(self, ...) self.atlas = { ... } end
    texture.SetColorTexture = function(self, ...) self.color = { ... } end
    texture.SetTexCoord = function(self, ...) self.texCoord = { ... } end
    texture.AddMaskTexture = function(self, mask) self.mask = mask end
    return texture
end

local function CreateFontStringMock(parent)
    local fontString = { parent = parent }
    fontString.SetPoint = function(self, ...) self.point = { ... } end
    fontString.SetText = function(self, value) self.text = value end
    fontString.SetTextColor = function(self, ...) self.textColor = { ... } end
    fontString.SetShadowColor = function(self, ...) self.shadowColor = { ... } end
    fontString.SetShadowOffset = function(self, ...) self.shadowOffset = { ... } end
    return fontString
end

local function CreateAnimationGroupMock()
    local group = { playing = false, animations = {} }
    group.CreateAnimation = function(_, animationType)
        local animation = { animationType = animationType }
        animation.SetOrigin = function(self, ...) self.origin = { ... } end
        animation.SetScale = function(self, ...) self.scale = { ... } end
        animation.SetDuration = function(self, value) self.duration = value end
        animation.SetSmoothing = function(self, value) self.smoothing = value end
        animation.SetOrder = function(self, value) self.order = value end
        group.animations[#group.animations + 1] = animation
        return animation
    end
    group.SetLooping = function(self, value) self.looping = value end
    group.Play = function(self)
        self.playing = true
        self.playCount = (self.playCount or 0) + 1
    end
    group.Stop = function(self)
        self.playing = false
        self.stopCount = (self.stopCount or 0) + 1
    end
    group.IsPlaying = function()
        error("animation state should be tracked without querying the animation group")
    end
    return group
end

CreateFrame = function(frameType, name, parent, template)
    local frame = {
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        scripts = {},
        events = {},
        shown = false,
    }
    frame.SetSize = function(self, ...) self.size = { ... } end
    frame.SetPoint = function(self, ...) self.point = { ... } end
    frame.ClearAllPoints = function(self) self.point = nil end
    frame.SetFrameStrata = function(self, value) self.strata = value end
    frame.SetFrameLevel = function(self, value) self.frameLevel = value end
    frame.GetFrameLevel = function(self) return self.frameLevel or 0 end
    frame.SetClampedToScreen = function(self, value) self.clamped = value end
    frame.SetMovable = function(self, value) self.movable = value end
    frame.RegisterForDrag = Noop
    frame.EnableMouse = function(self, value) self.mouseEnabled = value end
    frame.SetAllPoints = function(self, target) self.allPointsTarget = target end
    frame.SetAlpha = function(self, value) self.alpha = value end
    frame.SetScale = function(self, value) self.scale = value end
    frame.Show = function(self) self.shown = true end
    frame.Hide = function(self) self.shown = false end
    frame.SetShown = function(self, value) self.shown = value == true end
    frame.IsShown = function(self) return self.shown end
    frame.SetScript = function(self, scriptName, callback) self.scripts[scriptName] = callback end
    frame.RegisterEvent = function(self, event) self.events[event] = true end
    frame.StartMoving = function(self) self.moving = true end
    frame.StopMovingOrSizing = function(self) self.moving = false end
    frame.GetCenter = function(self) return self.centerX or 960, self.centerY or 540 end
    frame.CreateTexture = CreateTextureMock
    frame.CreateFontString = CreateFontStringMock
    frame.CreateMaskTexture = function()
        local mask = CreateTextureMock()
        mask.isMask = true
        return mask
    end
    frame.CreateAnimationGroup = CreateAnimationGroupMock

    frame.SetCancelAuraButtons = function(self, value) self.cancelAuraButtons = value end
    frame.SetHideTooltipInCombat = function(self, value) self.hideTooltipInCombat = value end
    frame.SetMouseMotionEnabled = function(self, value) self.mouseMotionEnabled = value end
    frame.SetMouseClickEnabled = function(self, value) self.mouseClickEnabled = value end
    frame.SetIcon = function(self, icon) self.registeredIcon = icon end
    frame.SetDurationCooldown = function(self, cooldown) self.registeredCooldown = cooldown end

    frame.SetDrawEdge = function(self, value) self.drawEdge = value end
    frame.SetDrawSwipe = function(self, value) self.drawSwipe = value end
    frame.SetSwipeColor = function(self, ...) self.swipeColor = { ... } end
    frame.SetHideCountdownNumbers = function(self, value) self.hideCountdown = value end

    if frameType == "AuraContainer" then
        frame.SetUnit = function(self, unit) self.unit = unit end
        frame.SetEnabled = function(self, value) self.enabled = value end
        frame.UpdateAllAuras = function(self) self.updateCount = (self.updateCount or 0) + 1 end
        frame.AddAuraSlot = function(self, key, filter, options)
            self.slot = { key = key, filter = filter, options = options }
            local auraButton = CreateFrame("AuraButton", nil, self)
            self.auraButton = auraButton
            options.initializeFrame(auraButton)
            return auraButton
        end
    end

    frames[#frames + 1] = frame
    return frame
end

local ns = {
    Database = {
        GetSettings = function() return settings end,
        SetSetting = function(key, value) settings[key] = value end,
        NormalizePetCrowdControlAlertOpacity = function(value)
            local opacity = math.max(0.10, math.min(1, tonumber(value) or 1))
            return math.floor(opacity * 20 + 0.5) / 20
        end,
        NormalizePetCrowdControlAlertSize = function(value)
            local size = math.max(32, math.min(168, tonumber(value) or 64))
            return math.floor(size + 0.5)
        end,
    },
}

assert(loadfile("PetCrowdControlAlert.lua"))("WarbandRatings", ns)
ns.PetCrowdControlAlert.Init()

local alert
local container
for _, frame in ipairs(frames) do
    if frame.name == "WarbandRatingsPetCrowdControlAlertFrame" then alert = frame end
    if frame.frameType == "AuraContainer" then container = frame end
end
local eventFrame = frames[#frames]
local auraButton = container and container.auraButton

assert(alert and alert.parent == UIParent and alert.shown,
    "the centered pet crowd-control alert frame was not created")
assert(alert.clamped and alert.movable and alert.mouseEnabled == false,
    "the live alert was not safely locked against mouse input")
assert(loadedAddOn == "Blizzard_AuraContainer",
    "the protected Blizzard aura-container implementation was not loaded")
assert(container and container.template == "CustomAuraContainerTemplate",
    "the alert did not create Blizzard's custom AuraContainer")
assert(container.parent == alert.bounceFrame and container.unit == "pet",
    "the protected aura container did not target the Hunter pet")
assert(container.slot.key == "PetCrowdControl"
        and container.slot.filter == "HARMFUL|CROWD_CONTROL",
    "the protected aura slot was not restricted to pet crowd-control debuffs")
assert(container.slot.options.sortMethod == AuraContainerSortMethod.AuraInstanceIDOnly
        and container.slot.options.sortDirection == AuraContainerSortDirection.Reverse,
    "the protected aura slot was not configured to show the newest CC")
assert(container.enabled and container.shown and container.updateCount == 1,
    "the live protected pet-CC display did not start enabled for a Hunter")
assert(auraButton and auraButton.registeredIcon == auraButton.alertVisual.icon,
    "the restricted aura button did not register its Blizzard-populated icon")
assert(auraButton.alertVisual.icon.texture == nil,
    "the live alert replaced the protected aura icon with a guessed spell")
assert(auraButton.alertVisual.iconMask.isMask
        and auraButton.alertVisual.icon.mask == auraButton.alertVisual.iconMask,
    "the live CC icon did not receive rounded corners")
assert(auraButton.alertVisual.petLabel.text == "PET"
        and auraButton.alertVisual.petLabel.point[1] == "CENTER"
        and auraButton.alertVisual.petLabel.point[2] == auraButton.alertVisual.labelLayer
        and auraButton.alertVisual.petLabel.parent == auraButton.alertVisual.labelLayer
        and auraButton.alertVisual.labelLayer.frameLevel
            > auraButton.alertVisual.imageLayer.frameLevel,
    "the live CC icon did not receive its centered PET label")
assert(auraButton.alertVisual.border.color[1] == 1
        and auraButton.alertVisual.border.color[2] == 0.05
        and auraButton.alertVisual.border.color[3] == 0.05,
    "the live CC icon did not receive its red warning border")
assert(auraButton.registeredCooldown == auraButton.durationCooldown
        and auraButton.durationCooldown.drawSwipe == true,
    "the protected aura duration was not connected to its cooldown swipe")
assert(auraButton.mouseMotionEnabled == false and auraButton.mouseClickEnabled == false,
    "the restricted aura icon can intercept mouse input")
assert(alert.bounce.playing and alert.bounce.looping == "REPEAT",
    "the pet crowd-control alert did not start its depth bounce")
assert(alert.bounce.playCount == 1,
    "the pet crowd-control alert restarted an already active bounce")
assert(not alert.preview.bounce and not auraButton.alertVisual.bounce,
    "restricted aura artwork retained a directly controlled animation group")
assert(auraButton.alertVisual.petLabel.parent ~= auraButton.alertVisual.imageLayer,
    "the PET label was incorrectly attached to the moving artwork layer")
assert(eventFrame.events.UNIT_PET
        and eventFrame.events.PLAYER_ENTERING_WORLD
        and eventFrame.events.PLAYER_REGEN_ENABLED,
    "the pet crowd-control alert did not register its refresh events")

ns.PetCrowdControlAlert.SetTestMode(true)
assert(ns.PetCrowdControlAlert.IsTestMode()
        and alert.preview.shown
        and alert.preview.icon.texture == 12345
        and alert.preview.petLabel.text == "PET",
    "Test / Unlock did not show the Polymorph preview")
assert(alert.mouseEnabled and not container.enabled and not container.shown,
    "Test / Unlock did not safely replace the protected live display")

settings.petCrowdControlAlertOpacity = 0.65
settings.petCrowdControlAlertSize = 96
ns.PetCrowdControlAlert.ApplySettings()
assert(alert.alpha == 0.65
        and alert.size[1] == 96
        and alert.size[2] == 96
        and alert.scale == nil
        and alert.bounceFrame.scale == 1.5,
    "the pet crowd-control appearance settings did not resize its centered visual")
assert(alert.bounceFrame.point[1] == "CENTER"
        and alert.bounceFrame.point[2] == alert
        and alert.bounceFrame.point[3] == "CENTER",
    "the resized pet crowd-control visual was not kept centered on its saved position")
assert(alert.bounce.playCount == 1,
    "applying appearance settings restarted the active bounce")

alert.centerX = 1060
alert.centerY = 490
alert.scripts.OnDragStart(alert)
assert(alert.moving, "Test / Unlock did not allow the pet CC icon to move")
alert.scripts.OnDragStop(alert)
assert(not alert.moving
        and settings.petCrowdControlAlertPosition.x == 100
        and settings.petCrowdControlAlertPosition.y == -50,
    "moving the unlocked pet CC icon did not save its position")

ns.PetCrowdControlAlert.Recenter()
assert(settings.petCrowdControlAlertPosition == nil
        and alert.point[1] == "CENTER"
        and alert.point[4] == 0
        and alert.point[5] == 0,
    "Recenter did not return the pet CC alert to the middle of the screen")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
assert(not ns.PetCrowdControlAlert.IsTestMode()
        and not alert.preview.shown
        and not alert.mouseEnabled
        and container.enabled
        and container.shown
        and container.updateCount == 2,
    "a loading-screen world transition did not turn off pet-CC Test / Unlock")

settings.petCrowdControlAlertBouncing = false
ns.PetCrowdControlAlert.ApplySettings()
assert(not alert.bounce.playing,
    "disabling Bouncing did not stop the pet CC alert animation")
assert(alert.bounce.stopCount == 1,
    "disabling Bouncing stopped the pet CC alert animation more than once")

settings.petCrowdControlAlertEnabled = false
ns.PetCrowdControlAlert.ApplySettings()
assert(not alert.preview.shown and not alert.mouseEnabled
        and not container.enabled and not container.shown,
    "disabling the module did not hide and lock both alert displays")

settings.petCrowdControlAlertEnabled = true
settings.petCrowdControlAlertBouncing = true
playerClassFile = "MAGE"
ns.PetCrowdControlAlert.SetTestMode(false)
assert(not container.enabled and not container.shown,
    "the live pet crowd-control container was enabled for a non-Hunter")

playerClassFile = "HUNTER"
eventFrame.scripts.OnEvent()
assert(container.enabled and container.shown and container.updateCount == 4,
    "a pet event did not refresh the protected pet crowd-control container")

print("pet crowd-control alert tests passed")
