local _, ns = ...
local Database = ns.Database
local DataCollection = ns.DataCollection
local UI = ns.UI

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CRITERIA_UPDATE")
eventFrame:RegisterEvent("PVP_RATED_STATS_UPDATE")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Database.Init()

        -- Request PvP data from server; ratings may not be available immediately
        if RequestRatedInfo then
            RequestRatedInfo()
        end

        -- Collect after a short delay to let PvP data load
        C_Timer.After(3, function()
            DataCollection.CollectCurrentCharacter()
            UI.RefreshTable()
        end)

        UI.AttachGroupFinderButtons()
        UI.CreateMinimapButton()
        UI.RegisterAddonSettings()
        UI.UpdateCompartmentVisibility()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Request achievement/statistics data from server so GetStatistic() returns real values.
        -- The server responds with CRITERIA_UPDATE, which will trigger a re-collect.
        if RequestAchievementData then
            RequestAchievementData()
        end

    elseif event == "CRITERIA_UPDATE" then
        -- Statistics are now available from the server; update HK and other stat columns.
        DataCollection.CollectCurrentCharacter()
        UI.RefreshTable()

    elseif event == "PVP_RATED_STATS_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        -- Re-collect when PvP stats arrive or spec changes
        C_Timer.After(0.5, function()
            DataCollection.CollectCurrentCharacter()
            UI.RefreshTable()
        end)
    end
end)

-- Slash command for convenience
SLASH_WARBANDRATINGS1 = "/warbandratings"
SLASH_WARBANDRATINGS2 = "/wr"
SlashCmdList["WARBANDRATINGS"] = function(msg)
    UI.Toggle()
end

-- Addon Compartment callbacks
function WarbandRatings_OnAddonCompartmentClick()
    UI.Toggle()
end

function WarbandRatings_OnAddonCompartmentEnter(_, btn)
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    GameTooltip:AddLine("Warband Ratings")
    GameTooltip:AddLine("Click to toggle window", 1, 1, 1)
    GameTooltip:Show()
end

function WarbandRatings_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
