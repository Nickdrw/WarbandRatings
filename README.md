# Warband PvP Companion

Inspired by a WeakAura I used back in the WeakAura era, Warband PvP Companion is a lightweight addon that lets you check your ratings and seasonal progression no matter which character you are currently logged into.

It provides an instant overview of your PvP and PvE progress, organized by class and character name, so you can quickly see where each of your characters stands across your warband.

Supports Retail patches 12.1.0 and 12.1.5. The 12.1.5 mid-season update continues Midnight Season 2, preserving its ratings, currencies, and match history.

## Supported data

Solo Shuffle  
Solo Battlegrounds  
2v2  
3v3  
10v10  
Honor earned  
Conquest earned and season cap  
Honorable Kills  
Mythic+  
Crests

## New features

- Rating history graphs for PvP brackets
- MMR and rating curves with toggleable display
- Graph scope selector: Session (current or last played session, preserved across UI reloads), Today (local day, extended through the logged-in character's session when it crosses midnight), or Season (all recorded games in the selected season). Session keeps the last played session until the first new game is recorded, with a "Last session from DD/MM/YYYY" label. Sessions are saved per character in shared history, so other characters' last sessions can also be viewed. Logging in without playing does not replace them. Overnight games stay assigned to the session's starting day after logout and are excluded from the next day's Today view.
- Detached graph window for a larger view
- Themed expansion and season dropdowns with historical seasonal character data
- Shareable current-season statistics and completed-season Rewind cards
- Season-aware crests and helper features
- Customizable Honor alert (12,000 by default) with yellow/orange warnings on Honor gains in range, coalescing rapid currency updates and deferring instanced-PvP alerts until after the exit loading screen, plus a red threshold notice and movable bouncing icon
- Column filters and display options
- PvP rating tooltips show the last recorded match date for that rating and its WoW version; older graph points can show a clearly marked version inferred from published patch dates
- PvP tooltip ratings (current, weekly best, and season best) show the matching rank badge before the number and use colors sampled from Blizzard's rank badges: Unranked bronze, Combatant silver (1,000+), Challenger gold (1,400+), Rival pale silver-blue (1,800+), Duelist blue (2,100+), and Elite purple (2,300+ in Midnight; 2,400+ in older seasons). Rank I and II share a badge and color; missing ratings stay muted without a badge
- The `By Game / Day` switch beside a rating graph's title slides between games and elapsed season days. The day axis shows the season week below each day label (Day 0–6 is `week 1`), and the hover tooltip shows the same week. Checking `Compare to last season (by day)` selects the day graph, shows both seasons' rating curves from a day-zero rating baseline, and hides the MMR curve; both seasons' recorded MMR remains in the hover tooltip. Each day's point is its final recorded match, with smooth visual transitions between recorded days and the final rating continued flat through today. The comparison stops at the current season's elapsed day

## How it works

While a rated season is active, the addon records and updates that character’s rating data automatically. Between seasons, the final table ratings and PvP match history stay frozen so offseason games cannot alter the completed season. The season toolbar shows the current state and changes Statistics to Rewind when a season ends.

## Goal

The purpose of Warband PvP Companion is simple: make it easy to track all your characters’ ratings and PvP progress without having to log in and out repeatedly or rely on external tools.

## Renamed from Warband Ratings

Warband PvP Companion keeps the existing `WarbandRatings` addon folder and saved-data identifiers so updates preserve your settings, character data, and rating history. Existing `/wr` and `/warbandratings` commands remain available alongside `/wpc` and `/warbandpvpcompanion`.
