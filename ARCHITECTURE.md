# WarbandRatings - Architecture & Developer Guide

## Overview

WarbandRatings is a World of Warcraft Retail addon that tracks PvP ratings, Mythic+ score, PvP/M+ currencies, honorable kills, and PvP match history across all characters on an account. Data is collected per character and stored in account-wide SavedVariables. The main UI displays a warband table, and PvP rating cells can open an interactive rating/MMR history graph.

Version 2.0 adds season-aware PvP history, graph inspection tools, theming, column filtering, Conquest cap tooltip data, and a development-only fake data provider kept in source but disconnected from normal addon behavior.

## Environment

- WoW Lua 5.1: no `goto`, no `continue`, no `//` integer division.
- Retail client: Interface `120005`.
- SavedVariables: `WarbandRatingsDB`.
- Linting: `wsl luacheck .` using `.luacheckrc`.
- Load order is defined by `WarbandRatings.toc`.

## Feature Inventory

### Account Table

- Character rows grouped from `WarbandRatingsDB.characters`.
- Sort order: max-level/highest level first, then class token, then character name.
- Class icon plus class-colored `level name-realm`.
- Alternating row backgrounds and hover highlight.
- Mouse-wheel scrolling; no visual scrollbar.
- Window width grows/shrinks to fit visible columns.

### Rating And Resource Columns

- Per-spec PvP ratings:
  - Solo Shuffle
  - Solo BG / Rated Battleground Blitz
- Global PvP ratings:
  - 2v2
  - 3v3
  - 10v10 Rated Battlegrounds
- Other global values:
  - Honor
  - Conquest
  - Honorable Kills, with World/Arena/Battleground breakdown tooltip
  - Mythic+
  - Crest tier summary, with per-tier tooltip

### Filtering And Settings

- Max level only.
- Hide characters with no rating.
- Hide brackets with no rating.
- Hide MMR for PvP ratings. Default: enabled for fresh installs.
- Hide minimap icon.
- Hide addon compartment icon.
- Theme selector:
  - Obsidian
  - Stormglass
  - Verdant
  - Ember
- Per-column visibility filter window.
- Graph visible-game count is persisted as `settings.graphVisiblePointCount`.

### PvP MMR Display

- Table MMR display is controlled by `settings.hideMMR`.
- MMR is shown inline as `rating (MMR)` when enabled.
- Saved as:
  - `charData.lastMMR[colKey]` for global PvP brackets.
  - `charData.specLastMMR[specID][colKey]` for spec PvP brackets.

### Conquest Tooltip

- Conquest quantity is stored in `ratings.conquest`.
- Extra Conquest cap metadata is collected per character:
  - `conquest_totalEarned`
  - `conquest_maxQuantity`
  - `conquest_quantityEarnedThisWeek`
  - `conquest_maxWeeklyQuantity`
- Hovering the Conquest cell shows a row-specific tooltip similar to the official currency tooltip:
  - title and description from the current client currency metadata
  - total from the row character
  - season earned/cap from the row character

### PvP History Graph

- Clicking a PvP cell opens a graph for that character/bracket/spec.
- The selected cell gets a subtle class-colored highlight and graph affordance icon.
- Graph title uses class color for `Character-Realm`, independent of theme.
- Rating and MMR can be toggled independently.
- Y-axis uses a fixed scale computed from the full selected series, not only the visible window.
- Y-axis labels show max, midpoint, and min.
- Bottom chronological slider moves through the series.
- Top `Games` slider controls how many points are visible:
  - default 50
  - min 20
  - max 200
  - disabled/dimmed below 20 recorded games with explanatory tooltip
- Hovering a point shows:
  - date first
  - rating plus delta
  - MMR plus delta, or `Pending next game`
- Graph can be detached:
  - detached size: `980x420`
  - movable and clamped to screen
  - `Attach` docks it back under the table
  - Escape closes detached graph via `UISpecialFrames`

### Launch Surfaces

- Slash commands: `/wr`, `/warbandratings`.
- Minimap button:
  - custom button, no library dependency
  - draggable around minimap
  - angle saved as `settings.minimapPos`
- Addon compartment entry:
  - registered/unregistered manually so it can be hidden from settings
- Group Finder buttons:
  - PvP button on `ConquestFrame`
  - M+ button on `ChallengesFrame`
  - created lazily for load-on-demand Blizzard UI frames
- Built-in addon settings panel:
  - Open Warband Ratings button
  - support/project links with copy-friendly URL popup

## File Structure & Load Order

Files load in `.toc` order. Each file receives the addon namespace via `local _, ns = ...` and registers a module on `ns`.

| File | Module | Purpose |
| --- | --- | --- |
| `Utils.lua` | `ns.Utils` | Shared helpers: class colors, character keys, rating/number formatting, spec/class icons. |
| `Database.lua` | `ns.Database` | Column definitions, SavedVariables initialization/migration, settings, character saves, filtering, visible-column selection. |
| `History.lua` | `ns.History` | PvP history storage, season detection, archived summaries, duplicate-window handling, SavedVariables size trimming. |
| `DataProvider.lua` | `ns.DataProvider` | Development-only fake data generator retained in source. `USE_FAKE_DATA` is false and normal UI/Core paths do not depend on it. |
| `DataCollection.lua` | `ns.DataCollection` | Reads WoW APIs for current character ratings, currencies, stats, active PvP context, last-match MMR, and history recording. |
| `UI.lua` | `ns.UI` | Main table, settings panel, filters, themes, graph panel, tooltips, minimap button, Group Finder buttons, addon settings panel. |
| `Core.lua` | entry point | Event registration, initialization orchestration, slash commands, addon compartment callbacks. |

## Data Model

### Root SavedVariables

```lua
WarbandRatingsDB = {
    characters = {},
    history = {},
    settings = {},
}
```

### Character Records

```lua
WarbandRatingsDB.characters["Name-Realm"] = {
    name = "Name",
    realm = "Realm",
    classFilename = "WARRIOR",
    classID = 1,
    level = 80,

    ratings = {
        arena2v2 = 1500,
        arena3v3 = 1600,
        rbg10v10 = 0,
        honor = 12000,
        conquest = 492,
        conquest_totalEarned = 4517,
        conquest_maxQuantity = 6400,
        conquest_quantityEarnedThisWeek = 0,
        conquest_maxWeeklyQuantity = 0,
        hk = 10000,
        hk_world = 4200,
        hk_arena = 1900,
        hk_bg = 3900,
        mythicPlus = 2500,
        crest_adventurer = 0,
        crest_veteran = 0,
        crest_champion = 0,
        crest_hero = 0,
        crest_myth = 0,
        crests = 0,
    },

    lastMMR = {
        arena2v2 = 1530,
        arena3v3 = 1605,
        rbg10v10 = 0,
    },

    specRatings = {
        [71] = { soloShuffle = 1800, soloBG = 0 },
        [72] = { soloShuffle = 1600, soloBG = 0 },
    },

    specLastMMR = {
        [71] = { soloShuffle = 1820, soloBG = 0 },
    },

    currentSpecID = 71,
    currentSpecRatings = { soloShuffle = 1800, soloBG = 0 },
    lastUpdated = 1713400000,
}
```

### Settings

```lua
WarbandRatingsDB.settings = {
    hideNoRating = false,
    hideEmptyColumns = false,
    hideNonMaxLevel = false,
    hideMMR = true,
    hideMinimapIcon = false,
    hideCompartmentIcon = false,
    minimapPos = 220,
    hiddenColumns = {},
    themeKey = "obsidian",
    graphVisiblePointCount = 50,
}
```

Missing settings are filled during `Database.Init()` without overwriting existing user choices.

### PvP History

History lives under `WarbandRatingsDB.history` and is organized by season, character, bracket, and optional spec.

```lua
WarbandRatingsDB.history = {
    version = 1,
    currentSeasonKey = "pvp-39",
    seasons = {
        ["pvp-39"] = {
            archived = false,
            characters = {
                ["Name-Realm"] = {
                    global = {
                        arena2v2 = {
                            points = {
                                -- { time, rating, mmr, ratingDelta, mmrDelta, result, mmrIsPostMatch }
                                { 1713400000, 1500, 1530, 12, 0, 1, false },
                            },
                            archived = false,
                        },
                    },
                    specs = {
                        [71] = {
                            soloShuffle = {
                                points = {},
                                archived = false,
                            },
                        },
                    },
                },
            },
        },
    },
}
```

History point fields are compact numeric indexes to reduce SavedVariables size:

| Index | Meaning |
| --- | --- |
| `1` | timestamp |
| `2` | rating |
| `3` | MMR |
| `4` | rating delta |
| `5` | MMR delta |
| `6` | result: `1` win, `0` loss, `-1` unknown |
| `7` | whether MMR is post-match |

For non-solo brackets, the MMR displayed after a match may actually be the next match's starting MMR. The graph aligns this with the previous rating result, and the last game can show `Pending next game` when the next MMR is not known yet.

## Column System

Columns are defined in `Database.lua`.

- `SPEC_COLUMNS`
  - Solo Shuffle: bracket index `7`
  - Solo BG: bracket index `9`
- `GLOBAL_COLUMNS`
  - 2v2: bracket index `1`
  - 3v3: bracket index `2`
  - 10v10: bracket index `4`
  - Honor: currency `1792`
  - Conquest: currency `1602`
  - HK: statistic `588` plus detail statistics
  - Mythic+: `C_ChallengeMode.GetOverallDungeonScore()`
  - Crests: current season currency IDs

`Database.IsSpecColumn(col)` and `Database.IsPVPColumn(col)` centralize column classification. `Database.GetPVPColumnByBracketIndex()` maps active PvP context back to a column.

## Data Collection

### Current Character Snapshot

`DataCollection.CollectCurrentCharacter()` gathers:

- identity: name, realm, class, level
- current spec
- PvP ratings via `GetPersonalRatedInfo`
- Mythic+ score via `C_ChallengeMode.GetOverallDungeonScore`
- currencies via `C_CurrencyInfo.GetCurrencyInfo`
- HK statistics via `GetStatistic`
- Conquest cap metadata

PvP bracket ratings are zeroed for sub-max-level characters before saving, because they are season-specific and stale values should not be displayed for leveling characters.

### Active PvP Context And MMR

The addon tries to infer the active rated bracket from:

- `C_PvP.IsRatedSoloShuffle`
- `C_PvP.IsSoloRBG`
- `C_PvP.IsRatedBattleground`
- `C_PvP.IsRatedArena`
- battlefield team size / scoreboard fallback
- remembered recent bracket
- rating-change inference

MMR is collected from several sources:

- `C_PvP.GetScoreInfoByPlayerGuid`
- `C_PvP.GetScoreInfo`
- `C_PvP.GetPVPActiveMatchPersonalRatedInfo`
- `GetBattlefieldTeamInfo`

PvP score APIs can expose secret/tainted placeholder values. Numeric MMR extraction uses guarded helpers (`pcall`) so unavailable secret values are ignored instead of compared or added directly.

### History Recording

`DataCollection.CollectLastMatchMMR(recordHistory)`:

1. resolves bracket and current spec
2. finds MMR
3. recollects current character ratings
4. saves last MMR to the character record
5. records a history point when match result is known

`History.RecordMatch()` deduplicates retries in a short window so delayed PvP API updates do not create repeated points for the same game.

## UI Architecture

### Main Window

- `WarbandRatingsMainFrame`
- `BasicFrameTemplateWithInset`
- movable, clamped, Escape-close via `UISpecialFrames`
- custom themed background/borders
- cog button opens the settings side panel
- table and graph are created lazily once the main frame exists

### Table Rendering

`UI.RefreshTable()`:

1. gets groups from `Database.GetFilteredCharacterGroups()`
2. gets columns from `Database.GetVisibleColumns(groups)`
3. rebuilds pooled header/row cells
4. renders class/name, per-spec subrows, global cells, icons, tooltips, graph overlays
5. resizes the main window width to fit visible columns
6. refreshes the graph if it is open

Rows and cells are pooled. `ResetCells()` hides/reuses existing font strings, textures, and overlays instead of creating new frames every refresh.

### Graph Rendering

`UI.RefreshHistoryGraph()`:

- reads the current selected history series via `History.GetCurrentSeries`
- computes a fixed full-series Y scale for selected Rating/MMR lines
- renders grid, axes, lines, and dots with pooled line/texture objects
- handles empty states and toggle states
- stores hover lookup data in `graphPanel.graphData`

The graph remains coupled to real history in normal addon behavior. `DataProvider.lua` is retained for future testing, but `UI.lua` does not currently call it.

### Tooltips

- Graph hover tooltip is compact and date-first.
- Crest cells show per-tier quantities.
- HK cells show total plus category breakdown.
- Conquest cells show current quantity and season cap metadata for the hovered character row.

## Events

Handled in `Core.lua`:

- `PLAYER_LOGIN`
  - init database and history
  - request PvP data
  - delayed character collection
  - attach Group Finder buttons
  - create minimap button
  - register addon settings
  - update addon compartment visibility
- `PLAYER_ENTERING_WORLD`
  - request achievement/stat data
  - update active PvP context
  - retry MMR collection
- `CRITERIA_UPDATE`
  - recollect statistics-backed data
- `PVP_RATED_STATS_UPDATE`
  - update active PvP context
  - delayed character recollection
  - retry MMR/history collection
- `ACTIVE_TALENT_GROUP_CHANGED`
  - delayed character recollection for new spec
- `UPDATE_BATTLEFIELD_SCORE`
  - update PvP context
  - collect MMR without recording history
- `PVP_MATCH_COMPLETE`
  - collect MMR and record history when possible
- `ZONE_CHANGED_NEW_AREA`
  - retry MMR/history collection after leaving PvP instances
- `SAVED_VARIABLES_TOO_LARGE`
  - archive/prune raw history points while preserving summaries

## History Size Management

`History.EnsureCurrentSeason()` detects season changes and archives old seasons.

Archived seasons keep summaries. Raw points are retained only for a limited number of archived seasons, and `SAVED_VARIABLES_TOO_LARGE` triggers stronger pruning:

- non-current seasons are archived
- archived raw points can be removed
- summaries remain

`History.GetArchivedSummaries()` exists for future UI surfaces that may display old-season summaries.

## Development Fake Data

`DataProvider.lua` contains a fake roster and fake history generator for screenshots and future tests. It includes:

- sparse PvP participation
- 5-character fake roster
- Conquest values derived from PvP activity
- long generated history series with trend profiles

Current normal behavior:

- `DataProvider.USE_FAKE_DATA = false`
- `UI.lua` calls `Database` and `History` directly
- `Core.lua` always collects real data
- no live feature path depends on fake data

To use fake data again, intentionally rewire the UI/Core paths or add a controlled development switch. Do not leave fake data connected for release builds.

## Known Patterns And Pitfalls

- Use WSL for project commands: `wsl luacheck .`, `wsl git ...`.
- WoW FontString truncation needs `SetWordWrap(false)` and `SetNonSpaceWrap(false)`.
- PVEFrame is not suited for third-party tabs; standalone buttons in Blizzard panes are more reliable.
- SavedVariables merging must explicitly copy new fields in both create and update paths.
- PvP data is asynchronous. Ratings and stats may require delayed collection and event retries.
- PvP MMR APIs can return secret/tainted values. Never compare or add raw MMR API values without guarded conversion.
- The graph Y scale is intentionally fixed across the selected full series. This makes slider navigation readable even when local point ranges are small.
- Detached graph Escape handling depends on `WarbandRatingsHistoryGraphPanel` being in `UISpecialFrames`.
