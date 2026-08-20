local _, ns = ...
ns.PetCrowdControlAlert = {}
local PetCrowdControlAlert = ns.PetCrowdControlAlert
local Database = ns.Database

local TEST_CC_SPELL_ID = 118
local ICON_SIZE = 64
local DEPTH_SCALE = 1.25
local BORDER_WIDTH = 3
local ICON_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local AURA_FILTER = "HARMFUL|CROWD_CONTROL"

local alertFrame
local auraContainer
local eventFrame
local initialized = false
local testMode = false
local bounceGroups = {}

local function GetSettings()
    return Database and Database.GetSettings and Database.GetSettings() or {}
end

local function GetAlertOpacity()
    local value = GetSettings().petCrowdControlAlertOpacity
    if value == nil then value = 1 end
    if Database and Database.NormalizePetCrowdControlAlertOpacity then
        return Database.NormalizePetCrowdControlAlertOpacity(value)
    end
    return math.max(0.10, math.min(1, tonumber(value) or 1))
end

local function GetAlertSize()
    local value = GetSettings().petCrowdControlAlertSize
    if value == nil then value = ICON_SIZE end
    if Database and Database.NormalizePetCrowdControlAlertSize then
        return Database.NormalizePetCrowdControlAlertSize(value)
    end
    return math.floor(math.max(32, math.min(168, tonumber(value) or ICON_SIZE)) + 0.5)
end

local function IsEnabled()
    return GetSettings().petCrowdControlAlertEnabled == true
end

local function IsBouncingEnabled()
    return GetSettings().petCrowdControlAlertBouncing ~= false
end

local function IsHunter()
    local unitClass = _G.UnitClass
    return unitClass and select(2, unitClass("player")) == "HUNTER"
end

local function SetPosition(frame)
    local position = GetSettings().petCrowdControlAlertPosition
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
        Database.SetSetting("petCrowdControlAlertPosition", position)
    else
        GetSettings().petCrowdControlAlertPosition = position
    end
    SetPosition(frame)
end

local function GetTestCCTexture()
    local spellAPI = _G.C_Spell
    if spellAPI and spellAPI.GetSpellTexture then
        local texture = spellAPI.GetSpellTexture(TEST_CC_SPELL_ID)
        if texture then return texture end
    end

    local getSpellTexture = _G.GetSpellTexture
    return getSpellTexture and getSpellTexture(TEST_CC_SPELL_ID)
        or "Interface\\Icons\\Spell_Nature_Polymorph"
end

local function AddRoundedMask(parent, texture, layer)
    local mask = parent:CreateMaskTexture(nil, layer)
    mask:SetAllPoints(texture)
    mask:SetAtlas(ICON_MASK_ATLAS, false)
    texture:AddMaskTexture(mask)
    return mask
end

local function CreateDepthBounce(target)
    local bounce = target:CreateAnimationGroup()
    local bounceForward = bounce:CreateAnimation("Scale")
    bounceForward:SetOrigin("CENTER", 0, 0)
    bounceForward:SetScale(DEPTH_SCALE, DEPTH_SCALE)
    bounceForward:SetDuration(0.34)
    bounceForward:SetSmoothing("OUT")
    bounceForward:SetOrder(1)

    local bounceBack = bounce:CreateAnimation("Scale")
    bounceBack:SetOrigin("CENTER", 0, 0)
    bounceBack:SetScale(1 / DEPTH_SCALE, 1 / DEPTH_SCALE)
    bounceBack:SetDuration(0.34)
    bounceBack:SetSmoothing("IN")
    bounceBack:SetOrder(2)

    bounce:SetLooping("REPEAT")
    bounceGroups[#bounceGroups + 1] = bounce
    return bounce
end

local function CreateAlertVisual(parent, textureAsset)
    local visual = CreateFrame("Frame", nil, parent)
    visual:SetAllPoints(parent)

    visual.imageLayer = CreateFrame("Frame", nil, visual)
    visual.imageLayer:SetAllPoints(visual)
    visual.imageLayer:SetFrameLevel(visual:GetFrameLevel() + 1)

    visual.border = visual.imageLayer:CreateTexture(nil, "BORDER")
    visual.border:SetAllPoints(visual.imageLayer)
    visual.border:SetColorTexture(1, 0.05, 0.05, 1)
    visual.borderMask = AddRoundedMask(visual.imageLayer, visual.border, "BORDER")

    visual.icon = visual.imageLayer:CreateTexture(nil, "ARTWORK")
    visual.icon:SetPoint(
        "TOPLEFT",
        visual.imageLayer,
        "TOPLEFT",
        BORDER_WIDTH,
        -BORDER_WIDTH
    )
    visual.icon:SetPoint(
        "BOTTOMRIGHT",
        visual.imageLayer,
        "BOTTOMRIGHT",
        -BORDER_WIDTH,
        BORDER_WIDTH
    )
    if textureAsset then
        visual.icon:SetTexture(textureAsset)
    end
    visual.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    visual.iconMask = AddRoundedMask(visual.imageLayer, visual.icon, "ARTWORK")
    visual.bounce = CreateDepthBounce(visual.imageLayer)

    visual.labelLayer = CreateFrame("Frame", nil, visual)
    visual.labelLayer:SetAllPoints(visual)
    visual.labelLayer:SetFrameLevel(visual.imageLayer:GetFrameLevel() + 1)
    visual.petLabel = visual.labelLayer:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )
    visual.petLabel:SetPoint("CENTER", visual.labelLayer, "CENTER", 0, 0)
    visual.petLabel:SetText("PET")
    visual.petLabel:SetTextColor(1, 1, 1, 1)
    visual.petLabel:SetShadowColor(0, 0, 0, 1)
    visual.petLabel:SetShadowOffset(1, -1)
    return visual
end

local function InitializeAuraButton(auraButton)
    auraButton:SetSize(ICON_SIZE, ICON_SIZE)
    auraButton:SetPoint("CENTER", auraContainer, "CENTER", 0, 0)
    if auraButton.SetCancelAuraButtons then
        auraButton:SetCancelAuraButtons(nil)
    end
    if auraButton.SetHideTooltipInCombat then
        auraButton:SetHideTooltipInCombat(true)
    end
    if auraButton.SetMouseMotionEnabled then
        auraButton:SetMouseMotionEnabled(false)
    end
    if auraButton.SetMouseClickEnabled then
        auraButton:SetMouseClickEnabled(false)
    end

    local visual = CreateAlertVisual(auraButton)
    auraButton.alertVisual = visual
    auraButton:SetIcon(visual.icon)

    local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
    cooldown:SetAllPoints(visual.icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.55)
    cooldown:SetHideCountdownNumbers(false)
    auraButton:SetDurationCooldown(cooldown)
    auraButton.durationCooldown = cooldown
end

local function LoadAuraContainerAddOn()
    local addOnAPI = _G.C_AddOns
    if not addOnAPI or not addOnAPI.LoadAddOn then return end
    pcall(addOnAPI.LoadAddOn, "Blizzard_AuraContainer")
end

local function EnsureAuraContainer()
    if auraContainer then return auraContainer end
    if not alertFrame then return nil end

    LoadAuraContainerAddOn()
    local ok, container = pcall(
        CreateFrame,
        "AuraContainer",
        nil,
        alertFrame.bounceFrame,
        "CustomAuraContainerTemplate"
    )
    if not ok or not container or not container.AddAuraSlot then return nil end

    container:SetSize(ICON_SIZE, ICON_SIZE)
    container:SetPoint("CENTER", alertFrame.bounceFrame, "CENTER", 0, 0)
    container:SetUnit("pet")
    container:SetEnabled(false)
    container:Hide()
    auraContainer = container

    local added = pcall(function()
        local slotOptions = {
            initializeFrame = InitializeAuraButton,
        }
        if _G.AuraContainerSortMethod and _G.AuraContainerSortDirection then
            slotOptions.sortMethod = _G.AuraContainerSortMethod.AuraInstanceIDOnly
            slotOptions.sortDirection = _G.AuraContainerSortDirection.Reverse
        end
        container:AddAuraSlot("PetCrowdControl", AURA_FILTER, slotOptions)
    end)
    if not added then
        auraContainer = nil
        container:SetEnabled(false)
        container:Hide()
        return nil
    end
    return container
end

local function EnsureAlertFrame()
    if alertFrame then return alertFrame end

    local frame = CreateFrame("Frame", "WarbandRatingsPetCrowdControlAlertFrame", UIParent)
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    frame.bounceFrame = CreateFrame("Frame", nil, frame)
    frame.bounceFrame:SetSize(ICON_SIZE, ICON_SIZE)
    frame.bounceFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)

    frame.preview = CreateAlertVisual(frame.bounceFrame, GetTestCCTexture())
    frame.preview:Hide()
    frame:SetScript("OnDragStart", function(self)
        if testMode then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if testMode then
            SavePosition(self)
        end
    end)
    SetPosition(frame)
    frame:Show()

    alertFrame = frame
    return frame
end

local function SetContainerActive(active)
    local container = EnsureAuraContainer()
    if not container then return end

    container:SetEnabled(active)
    container:SetShown(active)
    if active and container.UpdateAllAuras then
        container:UpdateAllAuras()
    end
end

function PetCrowdControlAlert.ApplySettings()
    if not initialized then return end

    local frame = EnsureAlertFrame()
    local enabled = IsEnabled()
    local showTest = enabled and testMode
    local size = GetAlertSize()
    frame:SetSize(size, size)
    frame:SetAlpha(GetAlertOpacity())
    frame.bounceFrame:SetScale(size / ICON_SIZE)
    frame:EnableMouse(showTest)
    frame.preview:SetShown(showTest)

    local shouldBounce = IsBouncingEnabled() and enabled
    for _, bounce in ipairs(bounceGroups) do
        if shouldBounce then
            if not bounce:IsPlaying() then bounce:Play() end
        elseif bounce:IsPlaying() then
            bounce:Stop()
        end
    end

    SetContainerActive(enabled and not testMode and IsHunter())
end

function PetCrowdControlAlert.Refresh()
    if not initialized then return end
    PetCrowdControlAlert.ApplySettings()
end

function PetCrowdControlAlert.IsTestMode()
    return testMode
end

function PetCrowdControlAlert.SetTestMode(enabled)
    testMode = enabled == true
    if initialized then
        PetCrowdControlAlert.ApplySettings()
    end
end

function PetCrowdControlAlert.Recenter()
    if Database and Database.SetSetting then
        Database.SetSetting("petCrowdControlAlertPosition", nil)
    else
        GetSettings().petCrowdControlAlertPosition = nil
    end
    if alertFrame then
        SetPosition(alertFrame)
    end
end

function PetCrowdControlAlert.Init()
    if initialized then return end
    initialized = true

    EnsureAlertFrame()
    EnsureAuraContainer()

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" and testMode then
            testMode = false
            PetCrowdControlAlert.ApplySettings()
            if ns.UI and ns.UI.RefreshClassSettings then
                ns.UI.RefreshClassSettings()
            end
            return
        end
        PetCrowdControlAlert.Refresh()
    end)

    PetCrowdControlAlert.ApplySettings()
end
