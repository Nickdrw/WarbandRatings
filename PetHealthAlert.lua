local _, ns = ...
ns.PetHealthAlert = {}
local PetHealthAlert = ns.PetHealthAlert
local Database = ns.Database

local MEND_PET_SPELL_ID = 136
local ICON_SIZE = 64
local DANGER_HEALTH_THRESHOLD = 0.50
local CRITICAL_HEALTH_THRESHOLD = 0.30
local WARNING_HEALTH_THRESHOLD = 0.70
local THRESHOLD_EPSILON = 0.001
local DEPTH_SCALE = 1.25
local BORDER_WIDTH = 3
local ICON_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"

local alertFrame
local eventFrame
local warningAlphaCurve
local dangerAlphaCurve
local criticalAlphaCurve
local initialized = false
local testMode = false
local testThreshold = "warning"

local function CreateHealthAlphaCurve(points)
    local curveAPI = _G.C_CurveUtil
    local curveType = _G.Enum and _G.Enum.LuaCurveType and _G.Enum.LuaCurveType.Linear
    if not curveAPI or not curveAPI.CreateCurve or not curveType then return nil end

    local ok, curve = pcall(curveAPI.CreateCurve)
    if not ok or not curve then return nil end

    local configured = pcall(function()
        curve:SetType(curveType)
        for _, point in ipairs(points) do
            curve:AddPoint(point[1], point[2])
        end
    end)
    return configured and curve or nil
end

local function CreateWarningAlphaCurve()
    return CreateHealthAlphaCurve({
        { 0, 0 },
        { DANGER_HEALTH_THRESHOLD, 0 },
        { DANGER_HEALTH_THRESHOLD + THRESHOLD_EPSILON, 1 },
        { WARNING_HEALTH_THRESHOLD - THRESHOLD_EPSILON, 1 },
        { WARNING_HEALTH_THRESHOLD, 0 },
        { 1, 0 },
    })
end

local function CreateDangerAlphaCurve()
    return CreateHealthAlphaCurve({
        { 0, 0 },
        { CRITICAL_HEALTH_THRESHOLD, 0 },
        { CRITICAL_HEALTH_THRESHOLD + THRESHOLD_EPSILON, 1 },
        { DANGER_HEALTH_THRESHOLD, 1 },
        { DANGER_HEALTH_THRESHOLD + THRESHOLD_EPSILON, 0 },
        { 1, 0 },
    })
end

local function CreateCriticalAlphaCurve()
    return CreateHealthAlphaCurve({
        { 0, 1 },
        { CRITICAL_HEALTH_THRESHOLD, 1 },
        { CRITICAL_HEALTH_THRESHOLD + THRESHOLD_EPSILON, 0 },
        { 1, 0 },
    })
end

local function GetMendPetTexture()
    local spellAPI = _G.C_Spell
    if spellAPI and spellAPI.GetSpellTexture then
        local texture = spellAPI.GetSpellTexture(MEND_PET_SPELL_ID)
        if texture then return texture end
    end

    local getSpellTexture = _G.GetSpellTexture
    return getSpellTexture and getSpellTexture(MEND_PET_SPELL_ID)
        or "Interface\\Icons\\Ability_Hunter_MendPet"
end

local function GetSettings()
    return Database and Database.GetSettings and Database.GetSettings() or {}
end

local function GetAlertOpacity(settingKey, defaultValue)
    local value = GetSettings()[settingKey]
    if value == nil then value = defaultValue end
    if Database and Database.NormalizePetHealthAlertOpacity then
        return Database.NormalizePetHealthAlertOpacity(value)
    end
    return math.max(0.10, math.min(1, tonumber(value) or 1))
end

local function GetAlertSize(settingKey, defaultValue)
    local value = GetSettings()[settingKey]
    if value == nil then value = defaultValue end
    if Database and Database.NormalizePetHealthAlertSize then
        return Database.NormalizePetHealthAlertSize(value, defaultValue)
    end
    return math.floor(math.max(32, math.min(168, tonumber(value) or defaultValue)) + 0.5)
end

local function IsTestMode()
    return testMode
end

local function IsEnabled()
    return GetSettings().petHealthAlertEnabled == true
end

local function IsBouncingEnabled()
    return GetSettings().petHealthAlertBouncing ~= false
end

local function SetPosition(frame)
    local position = GetSettings().petHealthAlertPosition
    frame:ClearAllPoints()
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        frame:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function SavePosition(frame)
    local centerX, centerY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    if not centerX or not centerY or not parentCenterX or not parentCenterY then return end

    local position = {
        x = math.floor(centerX - parentCenterX + 0.5),
        y = math.floor(centerY - parentCenterY + 0.5),
    }
    if Database and Database.SetSetting then
        Database.SetSetting("petHealthAlertPosition", position)
    else
        GetSettings().petHealthAlertPosition = position
    end
    SetPosition(frame)
end

local function AddRoundedMask(parent, texture, layer)
    local mask = parent:CreateMaskTexture(nil, layer)
    mask:SetAllPoints(texture)
    mask:SetAtlas(ICON_MASK_ATLAS, false)
    texture:AddMaskTexture(mask)
    return mask
end

local function CreateAlertState(parent, size, texture, borderColor)
    local state = CreateFrame("Frame", nil, parent)
    state:SetSize(size, size)
    state:SetPoint("CENTER", parent, "CENTER", 0, 0)
    state:SetAlpha(0)

    local visual = CreateFrame("Frame", nil, state)
    visual:SetAllPoints(state)
    state.visual = visual

    if borderColor then
        state.border = visual:CreateTexture(nil, "BORDER")
        state.border:SetAllPoints(state)
        state.border:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], 1)
        state.borderMask = AddRoundedMask(visual, state.border, "BORDER")
    end

    state.icon = visual:CreateTexture(nil, "ARTWORK")
    if borderColor then
        state.icon:SetPoint("TOPLEFT", state, "TOPLEFT", BORDER_WIDTH, -BORDER_WIDTH)
        state.icon:SetPoint("BOTTOMRIGHT", state, "BOTTOMRIGHT", -BORDER_WIDTH, BORDER_WIDTH)
    else
        state.icon:SetAllPoints(state)
    end
    state.icon:SetTexture(texture)
    state.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    state.iconMask = AddRoundedMask(visual, state.icon, "ARTWORK")
    state:Show()
    return state
end

local function ApplyVisualSettings(frame)
    local warningSize = GetAlertSize("petHealthWarningSize", ICON_SIZE)
    local dangerSize = GetAlertSize("petHealthDangerSize", ICON_SIZE)
    local criticalSize = GetAlertSize("petHealthCriticalSize", 83)
    local frameSize = math.max(warningSize, dangerSize, criticalSize)
    if testMode then
        if testThreshold == "danger" then
            frameSize = dangerSize
        elseif testThreshold == "critical" then
            frameSize = criticalSize
        else
            frameSize = warningSize
        end
    end

    frame:SetSize(frameSize, frameSize)
    frame:SetAlpha(1)
    frame:EnableMouse(IsEnabled() and IsTestMode())
    frame.warningState:SetSize(warningSize, warningSize)
    frame.dangerState:SetSize(dangerSize, dangerSize)
    frame.criticalState:SetSize(criticalSize, criticalSize)
    frame.warningState.visual:SetAlpha(GetAlertOpacity("petHealthWarningOpacity", 0.5))
    frame.dangerState.visual:SetAlpha(GetAlertOpacity("petHealthDangerOpacity", 1))
    frame.criticalState.visual:SetAlpha(GetAlertOpacity("petHealthCriticalOpacity", 1))
    if frame.bounce then
        if IsBouncingEnabled() and IsEnabled() then
            if not frame.bounce:IsPlaying() then frame.bounce:Play() end
        elseif frame.bounce:IsPlaying() then
            frame.bounce:Stop()
        end
    end
end

local function EnsureAlertFrame()
    if alertFrame then return alertFrame end

    local frame = CreateFrame("Frame", "WarbandRatingsPetHealthAlertFrame", UIParent)
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    local bounceFrame = CreateFrame("Frame", nil, frame)
    bounceFrame:SetAllPoints(frame)

    local texture = GetMendPetTexture()
    frame.warningState = CreateAlertState(bounceFrame, ICON_SIZE, texture)
    frame.dangerState = CreateAlertState(bounceFrame, ICON_SIZE, texture, { 1, 0.32, 0 })
    frame.criticalState = CreateAlertState(
        bounceFrame,
        83,
        texture,
        { 1, 0.05, 0.05 }
    )
    ApplyVisualSettings(frame)

    frame.bounce = bounceFrame:CreateAnimationGroup()
    local bounceForward = frame.bounce:CreateAnimation("Scale")
    bounceForward:SetOrigin("CENTER", 0, 0)
    bounceForward:SetScale(DEPTH_SCALE, DEPTH_SCALE)
    bounceForward:SetDuration(0.34)
    bounceForward:SetSmoothing("OUT")
    bounceForward:SetOrder(1)

    local bounceBack = frame.bounce:CreateAnimation("Scale")
    bounceBack:SetOrigin("CENTER", 0, 0)
    bounceBack:SetScale(1 / DEPTH_SCALE, 1 / DEPTH_SCALE)
    bounceBack:SetDuration(0.34)
    bounceBack:SetSmoothing("IN")
    bounceBack:SetOrder(2)

    frame.bounce:SetLooping("REPEAT")
    frame:SetScript("OnDragStart", function(self)
        if IsTestMode() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if IsTestMode() then
            SavePosition(self)
        end
    end)
    SetPosition(frame)
    frame:Show()
    if IsBouncingEnabled() and IsEnabled() then
        frame.bounce:Play()
    end

    alertFrame = frame
    return frame
end

local function SetAlertStateAlpha(frame, alpha)
    frame.warningState:SetAlpha(alpha)
    frame.dangerState:SetAlpha(alpha)
    frame.criticalState:SetAlpha(alpha)
end

local function ApplyPetHealthAlphas(frame)
    -- UnitHealthPercent evaluates these curves inside the game engine. Their
    -- results can be secret in combat, so each one goes directly to SetAlpha
    -- without any Lua comparison, arithmetic, formatting, or table indexing.
    frame.warningState:SetAlpha(_G.UnitHealthPercent("pet", false, warningAlphaCurve))
    frame.dangerState:SetAlpha(_G.UnitHealthPercent("pet", false, dangerAlphaCurve))
    frame.criticalState:SetAlpha(_G.UnitHealthPercent("pet", false, criticalAlphaCurve))
end

function PetHealthAlert.Refresh()
    if not initialized then return end

    local frame = EnsureAlertFrame()
    if not IsEnabled() then
        SetAlertStateAlpha(frame, 0)
        return
    end
    if IsTestMode() then
        frame.warningState:SetAlpha(testThreshold == "warning" and 1 or 0)
        frame.dangerState:SetAlpha(testThreshold == "danger" and 1 or 0)
        frame.criticalState:SetAlpha(testThreshold == "critical" and 1 or 0)
        return
    end

    local unitClass = _G.UnitClass
    local classFile = unitClass and select(2, unitClass("player"))
    if classFile ~= "HUNTER" then
        SetAlertStateAlpha(frame, 0)
        return
    end

    if not warningAlphaCurve or not dangerAlphaCurve or not criticalAlphaCurve
            or not _G.UnitHealthPercent then
        SetAlertStateAlpha(frame, 0)
        return
    end

    local unitExists = _G.UnitExists
    if not unitExists then
        SetAlertStateAlpha(frame, 0)
        return
    end

    local exists = unitExists("pet")
    local isSecretValue = _G.issecretvalue
    if not (isSecretValue and isSecretValue(exists)) and not exists then
        SetAlertStateAlpha(frame, 0)
        return
    end

    if not pcall(ApplyPetHealthAlphas, frame) then
        SetAlertStateAlpha(frame, 0)
    end
end

function PetHealthAlert.ApplySettings()
    if not initialized then return end

    local frame = EnsureAlertFrame()
    ApplyVisualSettings(frame)
    PetHealthAlert.Refresh()
end

function PetHealthAlert.IsTestMode()
    return testMode
end

function PetHealthAlert.SetTestMode(enabled)
    testMode = enabled == true
    if initialized then
        PetHealthAlert.ApplySettings()
    end
end

function PetHealthAlert.SetTestThreshold(threshold)
    if threshold ~= "danger" and threshold ~= "critical" then
        threshold = "warning"
    end
    if testThreshold == threshold then return end

    testThreshold = threshold
    if initialized then
        PetHealthAlert.ApplySettings()
    end
end

function PetHealthAlert.Recenter()
    if Database and Database.SetSetting then
        Database.SetSetting("petHealthAlertPosition", nil)
    else
        GetSettings().petHealthAlertPosition = nil
    end
    if alertFrame then
        SetPosition(alertFrame)
    end
end

function PetHealthAlert.Init()
    if initialized then return end
    initialized = true

    warningAlphaCurve = CreateWarningAlphaCurve()
    dangerAlphaCurve = CreateDangerAlphaCurve()
    criticalAlphaCurve = CreateCriticalAlphaCurve()
    EnsureAlertFrame()

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterUnitEvent("UNIT_HEALTH", "pet")
    eventFrame:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" and testMode then
            testMode = false
            PetHealthAlert.ApplySettings()
            if ns.UI and ns.UI.RefreshClassSettings then
                ns.UI.RefreshClassSettings()
            end
            return
        end
        PetHealthAlert.Refresh()
    end)

    PetHealthAlert.Refresh()
end
