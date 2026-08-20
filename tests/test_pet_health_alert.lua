-- luacheck: globals UIParent CreateFrame C_CurveUtil C_Spell Enum UnitClass UnitExists UnitHealthPercent

local secretAlphas = {}
local petExists = true
local playerClassFile = "HUNTER"
local healthReads = 0
local frames = {}
local createdCurves = {}
local settings = {
    petHealthAlertEnabled = true,
    petHealthAlertBouncing = true,
    petHealthWarningOpacity = 0.5,
    petHealthDangerOpacity = 1,
    petHealthCriticalOpacity = 1,
    petHealthWarningSize = 64,
    petHealthDangerSize = 64,
    petHealthCriticalSize = 83,
}

UIParent = {
    GetCenter = function() return 960, 540 end,
}

Enum = {
    LuaCurveType = {
        Linear = 1,
    },
}

C_CurveUtil = {
    CreateCurve = function()
        local curve = { points = {} }
        function curve:SetType(curveType)
            self.curveType = curveType
        end
        function curve:AddPoint(input, output)
            self.points[#self.points + 1] = { input, output }
        end
        createdCurves[#createdCurves + 1] = curve
        return curve
    end,
}

C_Spell = {
    GetSpellTexture = function(spellID)
        assert(spellID == 136, "the alert did not request the Mend Pet texture")
        return 12345
    end,
}

UnitExists = function(unit)
    assert(unit == "pet", "the alert checked the wrong unit")
    return petExists
end

UnitClass = function(unit)
    assert(unit == "player", "the alert checked the wrong unit's class")
    return playerClassFile == "HUNTER" and "Hunter" or "Mage", playerClassFile
end

UnitHealthPercent = function(unit, usePredicted, curve)
    assert(unit == "pet", "the alert read the wrong unit's health")
    assert(usePredicted == false, "the alert unexpectedly included predicted healing")
    assert(curve == createdCurves[1] or curve == createdCurves[2] or curve == createdCurves[3],
        "the alert did not supply one of its threshold curves")
    healthReads = healthReads + 1
    secretAlphas[curve] = secretAlphas[curve] or {}
    return secretAlphas[curve]
end

local function Noop() end

local function CreateAnimationGroupMock()
    local group = { playing = false, animations = {} }
    group.CreateAnimation = function(_, animationType)
        local animation = { animationType = animationType }
        animation.SetOrigin = function(self, ...) self.origin = { ... } end
        animation.SetScale = function(self, ...) self.scale = { ... } end
        animation.SetDuration = Noop
        animation.SetSmoothing = Noop
        animation.SetOrder = Noop
        group.animations[#group.animations + 1] = animation
        return animation
    end
    group.SetLooping = Noop
    group.Play = function(self) self.playing = true end
    group.Stop = function(self) self.playing = false end
    group.IsPlaying = function(self) return self.playing end
    return group
end

local function CreateTextureMock()
    local texture = {}
    texture.SetAllPoints = function(self, target) self.allPointsTarget = target end
    texture.SetPoint = Noop
    texture.SetSize = function(self, ...) self.size = { ... } end
    texture.SetTexture = function(self, ...) self.texture = select(1, ...) end
    texture.SetAtlas = function(self, ...) self.atlas = { ... } end
    texture.SetColorTexture = function(self, ...) self.color = { ... } end
    texture.SetTexCoord = Noop
    texture.SetBlendMode = function(self, blendMode) self.blendMode = blendMode end
    texture.SetVertexColor = function(self, ...) self.vertexColor = { ... } end
    texture.AddMaskTexture = function(self, mask) self.mask = mask end
    return texture
end

CreateFrame = function(_, name, parent)
    local frame = {
        name = name,
        parent = parent,
        scripts = {},
        shown = false,
    }
    frame.SetSize = function(self, ...) self.size = { ... } end
    frame.SetPoint = function(self, ...) self.point = { ... } end
    frame.ClearAllPoints = function(self) self.point = nil end
    frame.SetFrameStrata = Noop
    frame.SetClampedToScreen = function(self, value) self.clamped = value end
    frame.SetMovable = function(self, value) self.movable = value end
    frame.EnableMouse = function(self, enabled) self.mouseEnabled = enabled end
    frame.RegisterForDrag = Noop
    frame.SetAllPoints = Noop
    frame.RegisterUnitEvent = Noop
    frame.RegisterEvent = Noop
    frame.CreateAnimationGroup = CreateAnimationGroupMock
    frame.CreateTexture = CreateTextureMock
    frame.CreateMaskTexture = function()
        local mask = CreateTextureMock()
        mask.isMask = true
        return mask
    end
    frame.SetAlpha = function(self, alpha) self.alpha = alpha end
    frame.StartMoving = function(self) self.moving = true end
    frame.StopMovingOrSizing = function(self) self.moving = false end
    frame.GetCenter = function(self)
        return self.centerX or 960, self.centerY or 540
    end
    frame.Show = function(self) self.shown = true end
    frame.SetScript = function(self, scriptName, callback)
        self.scripts[scriptName] = callback
    end
    frames[#frames + 1] = frame
    return frame
end

local ns = {
    Database = {
        GetSettings = function() return settings end,
        SetSetting = function(key, value) settings[key] = value end,
        NormalizePetHealthAlertOpacity = function(value)
            local opacity = math.max(0.10, math.min(1, tonumber(value) or 1))
            return math.floor(opacity * 20 + 0.5) / 20
        end,
        NormalizePetHealthAlertSize = function(value)
            local size = math.max(32, math.min(168, tonumber(value) or 64))
            return math.floor(size + 0.5)
        end,
    },
}
assert(loadfile("PetHealthAlert.lua"))("WarbandRatings", ns)
ns.PetHealthAlert.Init()

local alert = frames[1]
local events = frames[#frames]
local warningCurve = createdCurves[1]
local dangerCurve = createdCurves[2]
local criticalCurve = createdCurves[3]
assert(alert.name == "WarbandRatingsPetHealthAlertFrame", "the centered alert frame was not created")
assert(alert.parent == UIParent and alert.shown, "the alert frame was not permanently shown")
assert(alert.mouseEnabled == false, "the transparent alert frame can intercept mouse input")
assert(alert.movable and alert.clamped, "the alert was not prepared for safe test-mode dragging")
assert(alert.alpha == 1, "the parent frame unexpectedly hid all alert states")
assert(alert.warningState.size[1] == 64 and alert.dangerState.size[1] == 64,
    "the 70% or 50% alert changed from the normal icon size")
assert(alert.criticalState.size[1] == 83 and alert.criticalState.size[2] == 83,
    "the 30% alert was not made 30% larger")
assert(alert.warningState.visual.alpha == 0.5
        and alert.dangerState.visual.alpha == 1
        and alert.criticalState.visual.alpha == 1,
    "the three alert states did not apply their independent opacity settings")

for _, state in ipairs({ alert.warningState, alert.dangerState, alert.criticalState }) do
    assert(state.icon.texture == 12345, "an alert state did not display the Mend Pet icon")
    assert(state.iconMask.isMask and state.icon.mask == state.iconMask,
        "an alert state did not receive its rounded-corner mask")
    assert(state.iconMask.atlas[1] == "UI-HUD-CoolDownManager-Mask"
            and state.iconMask.atlas[2] == false,
        "an alert state did not use Blizzard's rounded-square cooldown mask")
end

assert(not alert.warningState.border, "the unchanged 70% state unexpectedly gained a border")
assert(alert.dangerState.border.color[1] == 1
        and alert.dangerState.border.color[2] == 0.32
        and alert.dangerState.border.color[3] == 0,
    "the 50% state did not receive its orange border")
assert(alert.dangerState.border.mask == alert.dangerState.borderMask,
    "the orange border did not receive rounded corners")
assert(alert.criticalState.border.color[1] == 1
        and alert.criticalState.border.color[2] == 0.05
        and alert.criticalState.border.color[3] == 0.05,
    "the 30% state did not receive its red border")
assert(alert.criticalState.border.mask == alert.criticalState.borderMask,
    "the red border did not receive rounded corners")
assert(alert.bounce.playing, "the alert icon did not start bouncing")
assert(#alert.bounce.animations == 2
        and alert.bounce.animations[1].animationType == "Scale"
        and alert.bounce.animations[2].animationType == "Scale",
    "the alert did not use a forward-and-back depth scale animation")
assert(alert.bounce.animations[1].scale[1] == 1.25
        and alert.bounce.animations[1].scale[2] == 1.25,
    "the forward depth animation did not grow the icon")
assert(alert.bounce.animations[2].scale[1] == 0.8
        and alert.bounce.animations[2].scale[2] == 0.8,
    "the backward depth animation did not restore the icon's original scale")

assert(#createdCurves == 3, "the alert did not create its three health-state curves")
assert(warningCurve.curveType == Enum.LuaCurveType.Linear
        and dangerCurve.curveType == Enum.LuaCurveType.Linear
        and criticalCurve.curveType == Enum.LuaCurveType.Linear,
    "an alert curve is not linear")
assert(#warningCurve.points == 6
        and warningCurve.points[2][1] == 0.5 and warningCurve.points[2][2] == 0
        and warningCurve.points[3][1] == 0.501 and warningCurve.points[3][2] == 1
        and warningCurve.points[4][1] == 0.699 and warningCurve.points[4][2] == 1,
    "the unchanged 50-70% warning range was not preserved")
assert(warningCurve.points[5][1] == 0.7 and warningCurve.points[5][2] == 0,
    "the alert was not transparent at 70% health")
assert(#dangerCurve.points == 6
        and dangerCurve.points[2][1] == 0.3 and dangerCurve.points[2][2] == 0
        and dangerCurve.points[3][1] == 0.301 and dangerCurve.points[3][2] == 1
        and dangerCurve.points[4][1] == 0.5 and dangerCurve.points[4][2] == 1
        and dangerCurve.points[5][1] == 0.501 and dangerCurve.points[5][2] == 0,
    "the orange alert was not limited to the 30-50% range")
assert(#criticalCurve.points == 4
        and criticalCurve.points[2][1] == 0.3 and criticalCurve.points[2][2] == 1
        and criticalCurve.points[3][1] == 0.301 and criticalCurve.points[3][2] == 0,
    "the red alert was not limited to 30% health and below")
assert(alert.warningState.alpha == secretAlphas[warningCurve]
        and alert.dangerState.alpha == secretAlphas[dangerCurve]
        and alert.criticalState.alpha == secretAlphas[criticalCurve],
    "a secret curve result was inspected or replaced instead of reaching SetAlpha unchanged")
assert(healthReads == 3, "initialization did not refresh all three pet-health states")

events.scripts.OnEvent()
assert(healthReads == 6
        and alert.warningState.alpha == secretAlphas[warningCurve]
        and alert.dangerState.alpha == secretAlphas[dangerCurve]
        and alert.criticalState.alpha == secretAlphas[criticalCurve],
    "a pet-health event did not reapply all secret curve results")

petExists = false
events.scripts.OnEvent()
assert(healthReads == 6
        and alert.warningState.alpha == 0
        and alert.dangerState.alpha == 0
        and alert.criticalState.alpha == 0,
    "all alert states did not become transparent when the pet disappeared")
assert(alert.shown and alert.bounce.playing,
    "pet health incorrectly drove Show/Hide or stopped the permanent bounce animation")

settings.petHealthAlertBouncing = false
ns.PetHealthAlert.ApplySettings()
assert(not alert.bounce.playing, "disabling Bouncing did not stop the depth animation")
settings.petHealthAlertBouncing = true
ns.PetHealthAlert.ApplySettings()
assert(alert.bounce.playing, "enabling Bouncing did not restart the depth animation")

playerClassFile = "MAGE"
settings.petHealthWarningOpacity = 0.4
settings.petHealthDangerOpacity = 0.7
settings.petHealthCriticalOpacity = 0.9
settings.petHealthWarningSize = 60
settings.petHealthDangerSize = 72
settings.petHealthCriticalSize = 100
ns.PetHealthAlert.SetTestThreshold("critical")
ns.PetHealthAlert.SetTestMode(true)
assert(healthReads == 6
        and alert.warningState.alpha == 0
        and alert.dangerState.alpha == 0
        and alert.criticalState.alpha == 1,
    "Test / Unlock did not preview the selected 30% threshold")
assert(alert.mouseEnabled and alert.alpha == 1 and alert.criticalState.visual.alpha == 0.9,
    "Test / Unlock did not unlock the icon or apply the selected threshold opacity")
assert(alert.size[1] == 100
        and alert.warningState.size[1] == 60
        and alert.dangerState.size[1] == 72
        and alert.criticalState.size[1] == 100,
    "the size setting did not resize every pet-health alert state")

ns.PetHealthAlert.SetTestThreshold("danger")
assert(alert.size[1] == 72
        and alert.warningState.alpha == 0
        and alert.dangerState.alpha == 1
        and alert.criticalState.alpha == 0
        and alert.dangerState.visual.alpha == 0.7,
    "changing threshold tabs did not switch the Test / Unlock preview")

alert.centerX = 1060
alert.centerY = 490
alert.scripts.OnDragStart(alert)
assert(alert.moving, "Test / Unlock did not allow the Mend Pet icon to move")
alert.scripts.OnDragStop(alert)
assert(not alert.moving
        and settings.petHealthAlertPosition.x == 100
        and settings.petHealthAlertPosition.y == -50,
    "moving the unlocked icon did not save its position")
assert(alert.point[1] == "CENTER" and alert.point[4] == 100 and alert.point[5] == -50,
    "the saved pet-health alert position was not reapplied")

ns.PetHealthAlert.Recenter()
assert(settings.petHealthAlertPosition == nil,
    "recentering the pet-health alert did not clear its saved position")
assert(alert.point[1] == "CENTER" and alert.point[4] == 0 and alert.point[5] == 0,
    "recentering did not return the pet-health alert to the middle of the screen")

events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")
assert(not ns.PetHealthAlert.IsTestMode()
        and not alert.mouseEnabled
        and alert.warningState.alpha == 0
        and alert.dangerState.alpha == 0
        and alert.criticalState.alpha == 0,
    "a loading-screen world transition did not turn off pet-health Test / Unlock")

settings.petHealthAlertEnabled = false
ns.PetHealthAlert.ApplySettings()
assert(not alert.mouseEnabled
        and alert.warningState.alpha == 0
        and alert.dangerState.alpha == 0
        and alert.criticalState.alpha == 0
        and not alert.bounce.playing,
    "disabling the module did not hide and lock every pet-health alert state")

settings.petHealthAlertEnabled = true
ns.PetHealthAlert.SetTestMode(false)
assert(not alert.mouseEnabled
        and alert.warningState.alpha == 0
        and alert.dangerState.alpha == 0
        and alert.criticalState.alpha == 0,
    "locking the test icon did not restore condition-driven visibility")

print("pet health alert tests passed")
