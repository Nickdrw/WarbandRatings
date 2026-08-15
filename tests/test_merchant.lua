-- luacheck: globals C_CurrencyInfo C_MerchantFrame MerchantFrame GameTooltip
-- luacheck: globals GetMerchantNumItems GetMerchantItemID BuyMerchantItem C_Timer CreateFrame

local merchantPurchasable = false
local currencyQuantity = 3450
local currencyName = "Conquest"
local merchantItemID = 256553
local merchantItemName = "Galactic Equipment Chest"
local merchantItemPrice = 375
local merchantCurrencyID = 1602
local buyCount = 0
local lastBuyQuantity
local helperPanel

local function NewWidget()
    local widget = {
        shown = false,
        enabled = true,
        scripts = {},
    }

    function widget:SetFrameLevel() end
    function widget:GetFrameLevel() return 1 end
    function widget:SetScript(event, callback) self.scripts[event] = callback end
    function widget:RegisterEvent() end
    function widget:CreateTexture() return NewWidget() end
    function widget:CreateFontString() return NewWidget() end
    function widget:SetSize() end
    function widget:SetPoint() end
    function widget:ClearAllPoints() end
    function widget:SetTexCoord() end
    function widget:SetAllPoints() end
    function widget:SetHeight() end
    function widget:SetWidth() end
    function widget:SetJustifyH() end
    function widget:SetJustifyV() end
    function widget:SetColorTexture() end
    function widget:SetTextColor() end
    function widget:SetTexture(texture) self.texture = texture end
    function widget:SetText(value) self.text = value end
    function widget:Show() self.shown = true end
    function widget:Hide() self.shown = false end
    function widget:IsShown() return self.shown end
    function widget:Enable() self.enabled = true end
    function widget:Disable() self.enabled = false end
    return widget
end

MerchantFrame = NewWidget()
MerchantFrame.shown = true

C_CurrencyInfo = {
    GetCurrencyInfo = function()
        return { name = currencyName, quantity = currencyQuantity }
    end,
}

C_MerchantFrame = {
    GetItemInfo = function()
        return {
            name = merchantItemName,
            texture = 12345,
            price = merchantItemPrice,
            numAvailable = -1,
            isPurchasable = merchantPurchasable,
            currencyID = merchantCurrencyID,
        }
    end,
}

GetMerchantNumItems = function() return 1 end
GetMerchantItemID = function() return merchantItemID end
BuyMerchantItem = function(_, quantity)
    buyCount = buyCount + 1
    lastBuyQuantity = quantity
end
C_Timer = { After = function(_, callback) callback() end }
CreateFrame = function() return NewWidget() end

GameTooltip = NewWidget()
GameTooltip.lines = {}
function GameTooltip:SetOwner() end
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:AddDoubleLine(left, right)
    self.lines[#self.lines + 1] = left .. " " .. right
end

local ns = {
    DISPLAY_NAME = "Warband PvP Companion",
    Database = {
        HELIOTROPE_ITEM_ID = 210729,
        HELIOTROPE_NAME = "Infused Heliotrope",
        HELIOTROPE_FALLBACK_HONOR_COST = 2500,
        GetSettings = function() return {} end,
    },
    DataCollection = {},
    HelperPanel = {
        CreateShell = function()
            helperPanel = NewWidget()
            return helperPanel
        end,
        ApplyShellTheme = function()
            return {
                surfaceRaised = { 0, 0, 0, 1 },
                accent = { 1, 1, 1, 1 },
                text = { 1, 1, 1, 1 },
                muted = { 0.5, 0.5, 0.5, 1 },
            }
        end,
        SetTextureColor = function() end,
        SetFontColor = function() end,
        SnapFrameToPixelGrid = function() end,
    },
    Season = {
        GetFeature = function()
            return {
                itemID = 256553,
                name = "Galactic Equipment Chest",
                fallbackCost = 375,
                requiredPVPRating = 1400,
            }
        end,
    },
}

assert(loadfile("Merchant.lua"))("WarbandRatings", ns)
ns.Merchant.Refresh()

assert(helperPanel.shown, "rating-restricted affordable chest should keep the helper visible")
assert(not helperPanel.button.enabled, "rating-restricted chest should disable the purchase button")
assert(not helperPanel.singleButton.shown, "the chest helper should keep its single full-width button")
assert(helperPanel.body.text == "1,400 PvP rating required", "rating warning headline is incorrect")
assert(helperPanel.detail.text == "Reach it in any bracket to buy Galactic Equipment Chest.",
    "rating warning detail is incorrect")
assert(helperPanel.button.text == "Rating required", "rating warning button label is incorrect")

helperPanel.scripts.OnEnter(helperPanel)
assert(GameTooltip.lines[2] == "Requires 1,400 PvP rating in any bracket.",
    "rating restriction is missing from the helper tooltip")

helperPanel.button.scripts.OnClick()
assert(buyCount == 0, "disabled rating-restricted helper attempted a purchase")

merchantPurchasable = true
ns.Merchant.Refresh()
assert(helperPanel.shown and helperPanel.button.enabled, "eligible chest should restore the active purchase helper")
assert(helperPanel.button.text == "9 remaining", "eligible chest quantity is incorrect")

merchantItemID = 210729
merchantItemName = "Infused Heliotrope"
merchantItemPrice = 2500
merchantCurrencyID = 1792
currencyName = "Honor"
currencyQuantity = 7500
ns.Merchant.Refresh()

assert(helperPanel.shown, "affordable Heliotrope should show the helper")
assert(helperPanel.singleButton.shown and helperPanel.singleButton.enabled,
    "Heliotrope should show an enabled single-purchase button")
assert(helperPanel.singleButton.text == "Buy 1", "single-purchase button label is incorrect")
assert(helperPanel.button.text == "Buy 3", "bulk-purchase button label is incorrect")

helperPanel.singleButton.scripts.OnClick()
assert(buyCount == 1 and lastBuyQuantity == 1, "single-purchase button should buy exactly one Heliotrope")

helperPanel.button.scripts.OnClick()
assert(buyCount == 2 and lastBuyQuantity == 3, "bulk-purchase button should preserve the maximum purchase")

helperPanel.singleButton.scripts.OnEnter(helperPanel.singleButton)
assert(GameTooltip.lines[2] == "Buys one copy of Infused Heliotrope.",
    "single-purchase button tooltip is incorrect")

currencyQuantity = 0
ns.Merchant.Refresh()
assert(not helperPanel.shown, "unaffordable Heliotrope should preserve the existing hidden-helper behavior")
