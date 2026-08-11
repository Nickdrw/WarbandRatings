local _, ns = ...
ns.HelperPanel = {}
local HelperPanel = ns.HelperPanel

local fallbackTheme = {
    surface = { 0.055, 0.064, 0.078, 0.96 },
    surfaceRaised = { 0.080, 0.092, 0.110, 0.98 },
    border = { 0.250, 0.285, 0.330, 0.88 },
    rowHover = { 0.950, 0.720, 0.280, 0.13 },
    text = { 0.900, 0.930, 0.960, 1 },
    title = { 0.970, 0.820, 0.450, 1 },
    muted = { 0.560, 0.600, 0.650, 1 },
    accent = { 0.960, 0.720, 0.320, 1 },
}

function HelperPanel.GetTheme()
    if ns.UI and ns.UI.GetActiveTheme then
        return ns.UI.GetActiveTheme()
    end
    return fallbackTheme
end

function HelperPanel.SetTextureColor(texture, color, alpha)
    if texture and texture.SetColorTexture and color then
        texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
    end
end

function HelperPanel.SetFontColor(fontString, color, alpha)
    if fontString and fontString.SetTextColor and color then
        fontString:SetTextColor(color[1], color[2], color[3], alpha or color[4] or 1)
    end
end

function HelperPanel.CreateBorder(parent, key, point, relativePoint, x, y, width, height)
    local border = parent[key]
    if not border then
        border = parent:CreateTexture(nil, "BORDER")
        parent[key] = border
    end

    border:ClearAllPoints()
    border:SetPoint(point, parent, relativePoint, x, y)
    border:SetSize(width, height)
    return border
end

local function RoundToPixel(value, scale)
    return math.floor((value * scale) + 0.5) / scale
end

function HelperPanel.SnapFrameToPixelGrid(frame)
    if not frame or not UIParent then return end

    local left = frame:GetLeft()
    local top = frame:GetTop()
    if not left or not top then return end

    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return end

    local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(1)
    if point and relativeTo and relativePoint then
        frame:ClearAllPoints()
        frame:SetPoint(
            point,
            relativeTo,
            relativePoint,
            (xOffset or 0) + RoundToPixel(left, scale) - left,
            (yOffset or 0) + RoundToPixel(top, scale) - top
        )
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", RoundToPixel(left, scale), RoundToPixel(top, scale))
end

function HelperPanel.CreateShell(name, width, height, titleText)
    local panel = CreateFrame("Frame", name, UIParent)
    panel.helperPanelWidth = width
    panel.helperPanelHeight = height
    panel:SetSize(width, height)
    panel:SetFrameStrata("HIGH")
    panel:EnableMouse(true)
    panel:Hide()

    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()

    panel.headerBg = panel:CreateTexture(nil, "BORDER")
    panel.headerBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.headerBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.headerBg:SetHeight(22)

    panel.accentLine = panel:CreateTexture(nil, "BORDER")
    panel.accentLine:SetPoint("TOPLEFT", panel.headerBg, "BOTTOMLEFT", 0, 0)
    panel.accentLine:SetPoint("TOPRIGHT", panel.headerBg, "BOTTOMRIGHT", 0, 0)
    panel.accentLine:SetHeight(1)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.title:SetPoint("LEFT", panel.headerBg, "LEFT", 8, 0)
    panel.title:SetText(titleText or ns.DISPLAY_NAME)

    return panel
end

function HelperPanel.ApplyShellTheme(panel)
    if not panel then return nil end

    local theme = HelperPanel.GetTheme()
    HelperPanel.SetTextureColor(panel.bg, theme.surface)
    HelperPanel.SetTextureColor(panel.headerBg, theme.surfaceRaised)
    HelperPanel.SetTextureColor(panel.accentLine, theme.accent, 0.75)
    HelperPanel.SetFontColor(panel.title, theme.title)

    local width = panel.helperPanelWidth or panel:GetWidth()
    local height = panel.helperPanelHeight or panel:GetHeight()
    HelperPanel.SetTextureColor(HelperPanel.CreateBorder(panel, "borderTop", "TOPLEFT", "TOPLEFT", 0, 0, width, 1), theme.border)
    HelperPanel.SetTextureColor(HelperPanel.CreateBorder(panel, "borderBottom", "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, width, 1), theme.border)
    HelperPanel.SetTextureColor(HelperPanel.CreateBorder(panel, "borderLeft", "TOPLEFT", "TOPLEFT", 0, 0, 1, height), theme.border)
    HelperPanel.SetTextureColor(HelperPanel.CreateBorder(panel, "borderRight", "TOPRIGHT", "TOPRIGHT", 0, 0, 1, height), theme.border)
    return theme
end
