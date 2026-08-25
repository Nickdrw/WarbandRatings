# Warband PvP Companion (`WarbandRatings`) - Architecture & Developer Guide

## Overview

Warband PvP Companion is a World of Warcraft Retail addon that tracks PvP ratings, Mythic+ score, PvP/M+ currencies, honorable kills, and PvP match history across all characters on an account. Data is collected per character and stored in account-wide SavedVariables. The main UI displays a warband table, and PvP rating cells can open an interactive rating/MMR history graph.

The public display name is `Warband PvP Companion`. The technical addon identity intentionally remains `WarbandRatings`, including the folder, TOC filename, Lua globals, frame names, and SavedVariables, so existing installations retain their data and integrations.

Version 2.0 adds season-aware PvP history, graph inspection tools, theming, column filtering, Conquest cap tooltip data, and a development-only fake data provider kept in source but disconnected from normal addon behavior.

## Environment

- WoW Lua 5.1: no `goto`, no `continue`, no `//` integer division.
- Retail clients: Interfaces `120007` and `120100`.
- SavedVariables: `WarbandRatingsDB`.
- Linting: `wsl luacheck .` using `.luacheckrc`.
- Load order is defined by `WarbandRatings.toc`.

## Feature Inventory

### Account Table

- Character rows grouped from `WarbandRatingsDB.seasons[seasonKey].characters`.
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
- Hide minimap icon.
- Hide addon compartment icon.
- Hide helper panels for box opening, Heliotrope purchases, and season-enabled Conquest chest purchase/mailing features. Unavailable seasonal controls remain hidden.
- Theme selector:
  - Obsidian
  - Stormglass
  - Verdant
  - Ember
- Honor alert threshold, defaulting to 12,000. Chat warnings appear at login and on Honor gains within range, escalating from yellow at 2,000 remaining to orange at 1,000 remaining and red at the threshold. Rapid currency snapshots are briefly coalesced so only the newest, closest warning is shown. Alerts earned in Arena or Battleground instances are deferred until `PLAYER_ENTERING_WORLD` after leaving; outdoor gains alert normally. Reaching the threshold shows a movable bouncing Honor icon while outside combat and instances; right-clicking it hides it until re-enabled in settings.
- Per-column visibility filter window.
- History graph `Games` slider defaults to the maximum visible game count, capped at 200 points.

### PvP MMR Display

- PvP rating tooltips show current/last MMR when available.
- The history graph has session-local Rating/MMR toggles.
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

### Helper Panels

- `HelperPanel.lua` provides the shared shell, borders, theme application helpers, and pixel snapping for small floating helper panels.
- `Merchant.lua` shows a vendor-adjacent helper for currency dump purchases:
  - Infused Heliotrope with Honor
  - the active season's Equipment Chest with Conquest, when available
  - an affordable Equipment Chest that is blocked by a known rating requirement remains visible with a disabled warning state
- `BagOpener.lua` scans player bags for openable boxes and shows secure click buttons for:
  - Field Medic's Hazard Payout
  - Illustrious Contender's Strongbox
  - the active season's Equipment Chest, when available
- Bag opener buttons are `SecureActionButtonTemplate` buttons with `/stopcasting` + `/use` macro actions assigned outside combat. Instant boxes click through normally; seasonal Equipment Chests track the real opening cast and use a short post-cast rebind lock for the in-button cast bar. The panel is hidden in combat and instances.
- `Mailbox.lua` shows a mailbox-adjacent helper for attaching and sending the active season's Equipment Chests, with the recipient saved in settings.
- A future season's chest is activated only after `Merchant.lua` sees an Equipment Chest with a real Conquest cost at an open vendor. The detected item ID, exact name, and cost are persisted under that season so purchase, opening, mailing, and settings controls share one source of truth.

### PvP History Graph

- Clicking a PvP cell opens a graph for that character/bracket/spec.
- The selected cell gets a subtle class-colored highlight and graph affordance icon.
- Graph title uses class color for `Character-Realm`, independent of theme.
- Rating and MMR can be toggled independently.
- Y-axis dynamically scales to the selected Rating/MMR values in the visible window.
- Y-axis labels show max, midpoint, and min.
- Bottom chronological slider moves through the series.
- Top `Games` slider defaults to the maximum visible point count:
  - starts by showing all recorded games up to 200 points
  - starts by showing the latest 200 points when history is longer
  - can be moved lower to zoom into fewer games during the open graph session
  - bottom range slider or mouse wheel can browse older windows when capped
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

- Slash commands: `/wpc`, `/warbandpvpcompanion`, `/wr`, `/warbandratings`.
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
  - Open Warband PvP Companion button
  - support/project links with copy-friendly URL popup

## File Structure & Load Order

Files load in `.toc` order. Each file receives the addon namespace via `local _, ns = ...` and registers a module on `ns`.

| File | Module | Purpose |
| --- | --- | --- |
| `Utils.lua` | `ns.Utils` | Shared helpers: class colors, character keys, rating/number formatting, spec/class icons. |
| `Season.lua` | `ns.Season` | Expansion/season catalog, build-to-content-season resolution, seasonal crest metadata, and feature availability. |
| `Database.lua` | `ns.Database` | Column definitions, SavedVariables initialization/migration, settings, character saves, filtering, visible-column selection. |
| `History.lua` | `ns.History` | PvP history storage, season detection, archived summaries, duplicate-window handling, SavedVariables size trimming. |
| `DataProvider.lua` | `ns.DataProvider` | Development-only fake data generator retained in source. `USE_FAKE_DATA` is false and normal UI/Core paths do not depend on it. |
| `DataCollection.lua` | `ns.DataCollection` | Reads WoW APIs for current character ratings, currencies, stats, active PvP context, last-match MMR, and history recording. |
| `HelperPanel.lua` | `ns.HelperPanel` | Shared themed shell, border, color, and pixel-snapping helpers for floating helper panels. |
| `Merchant.lua` | `ns.Merchant` | Vendor helper for buying currency dump items such as Infused Heliotrope and the active seasonal Equipment Chest. |
| `BagOpener.lua` | `ns.BagOpener` | Bag scanner and secure helper buttons for opening Field Medic payouts, Contender strongboxes, and the active seasonal Equipment Chest. |
| `Mailbox.lua` | `ns.Mailbox` | Mail helper for attaching and sending the active seasonal Equipment Chest. |
| `HonorAlert.lua` | `ns.HonorAlert` | Escalating Honor-threshold chat alerts and a movable bouncing icon with combat/instance suppression. |
| `UI.lua` | `ns.UI` | Main table, settings panel, filters, themes, graph panel, tooltips, minimap button, Group Finder buttons, addon settings panel. |
| `SeasonUI.lua` | `ns.SeasonUI` | Themed expansion/season dropdowns and the detached, screenshot-friendly statistics / Rewind card. |
| `Core.lua` | entry point | Event registration, initialization orchestration, slash commands, addon compartment callbacks. |

## Data Model

### Root SavedVariables

```lua
WarbandRatingsDB = {
    schemaVersion = 2,
    seasons = {},
    history = { version = 5, currentSeasonKey = nil, contentSeasonKey = nil, diagnostics = {} },
    seasonFeatures = {},
    settings = {},
}
```

Schema 2 stores each character exactly once per season. On the first login after upgrading, the addon builds and validates this structure before replacing the legacy live/snapshot layout. The former `characters` and `history` tables are retained under `legacySchemaBackup` for one release; collection is disabled if migration validation fails.

### Character Records

```lua
WarbandRatingsDB.seasons["pvp-42"].characters["Name-Realm"] = {
    name = "Name",
    realm = "Realm",
    classFilename = "WARRIOR",
    classID = 1,
    level = 80,
    seasonKey = "pvp-42",

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

    series = {
        global = {},
        specs = {},
    },
}
```

### Settings

```lua
WarbandRatingsDB.settings = {
    hideNoRating = false,
    hideEmptyColumns = false,
    hideNonMaxLevel = false,
    hideBoxesHelper = false,
    hideHeliotropeHelper = false,
    hideConquestEquipmentChestPurchaseHelper = false,
    hideConquestEquipmentChestMailHelper = false,
    conquestEquipmentChestMailRecipient = "",
    selectedExpansionKey = "midnight",
    selectedSeasonKey = "pvp-42",
    selectionContentSeasonKey = "pvp-42",
    hideMinimapIcon = false,
    hideCompartmentIcon = false,
    honorAlertThreshold = 12000,
    hideHonorAlertIcon = false,
    honorAlertPosition = { x = 0, y = 0 }, -- saved after the alert icon is moved
    minimapPos = 220,
    hiddenColumns = {},
    themeKey = "obsidian",
    windowHeight = 450,
    sortKey = "character",
    sortDirection = "asc",
    bagOpenerPosition = { x = 0, y = -72 }, -- saved after the helper is moved
}
```

Missing settings are filled during `Database.Init()` without overwriting existing user choices.

Queue-helper visibility is character-specific and stored separately by WoW:

```lua
WarbandRatingsCharacterDB.settings = {
    hideArenaQueueHelper = false,
}
```

On upgrade, the former account-wide choice seeds each character's initial value. Changing it afterward affects only the current character.

The helper counts occupied battlefield slots across Rated, Unrated, and unrecognized PvP queues. Once three slots are occupied, existing queue cards continue to show their live status while every new queue action is disabled until a slot becomes available.

### PvP History

Graph series live inside the same canonical seasonal character record as the table and Rewind data. `WarbandRatingsDB.history` contains only coordination metadata and diagnostics.

```lua
WarbandRatingsDB.history = {
    version = 5,
    currentSeasonKey = "pvp-42", -- rated-PvP API season
    contentSeasonKey = "pvp-42", -- collection/feature season
    diagnostics = {},
}

WarbandRatingsDB.seasons["pvp-42"] = {
    seasonKey = "pvp-42",
    archived = false,
    expansionKey = "midnight",
    expansionName = "Midnight",
    seasonNumber = 2,
    characters = {
        ["Name-Realm"] = {
            seasonKey = "pvp-42",
            -- ratings, PvP statistics, identity, and other character fields above
            series = {
                global = {
                    arena2v2 = {
                        points = {
                            -- { time, rating, mmr, ratingDelta, mmrDelta, result,
                            --   mmrIsPostMatch, matchSequence, mmrSource, specID }
                            { 1713400000, 1500, 1530, 12, 0, 1, true, 42, "postmatch", 71 },
                        },
                        archived = false,
                    },
                },
                specs = {
                    [71] = {
                        soloShuffle = { points = {}, archived = false },
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
| `8` | season game counter used as the stable match sequence |
| `9` | MMR source: `postmatch`, `prematch`, `nextPrematch`, or `pending` |
| `10` | specialization active during the match |

MMR is optional. A point with `mmr = 0` and `mmrSource = "pending"` still preserves the rating result. When the next lobby exposes the player's exact prematch MMR, the preceding pending point is enriched and marked `nextPrematch`. Team-average scoreboard fallbacks are never used for this enrichment. Older history that stores prematch MMR on the following point remains supported by the graph alignment logic.

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
  - Crests: selected/current season currency IDs supplied by `Season.lua`

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

- `C_PvP.GetActiveMatchBracket`
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

Rated-match collection is stateful:

- table snapshots and graph recording are paused when `GetCurrentArenaSeason()` explicitly returns `0`; unavailable or failing season-state APIs fail open
- cumulative PvP statistics are persisted only after `PVP_RATED_STATS_UPDATE` confirms the cache requested for the same character and active specialization
- each fresh statistics block carries character/spec ownership metadata; an owned refresh replaces unowned legacy totals, while later refreshes for the same owner retain monotonic season maxima and counters
- legacy global statistics with an exact duplicated season-best/played/won tuple are quarantined when one character is the unambiguous current owner of the peak, preventing copied API cache data from affecting Rewind totals and peaks

1. `PVP_MATCH_ACTIVE` snapshots character, spec, bracket, rating, and season game counter
2. scoreboard updates capture prematch MMR when it is readable and use it to enrich the preceding pending point
3. `PVP_MATCH_COMPLETE` captures its payload and any synchronously readable score data without treating each Solo Shuffle round as a completed lobby
4. `PVP_RATED_STATS_UPDATE` provides the fresh post-lobby rating and season game counter
5. the rating point is recorded even when post-match MMR and result are unavailable
6. `PVP_MATCH_INACTIVE` and bounded retries provide additional post-match retrieval windows

`History.RecordMatch(seasonKey, ...)` deduplicates by the season game counter when available, falling back to the legacy short retry window for old/API-limited points. Low-level character, MMR, graph, and enrichment writes all require an explicit season key and reject mismatched records. Recording diagnostics are retained under `history.diagnostics`.

Raw graph points are retained across ordinary season transitions. Only `SAVED_VARIABLES_TOO_LARGE` invokes emergency trimming, one oldest archived season per event, after preserving its aggregate summaries.

## UI Architecture

### Main Window

- `WarbandRatingsMainFrame`
- `BasicFrameTemplateWithInset`
- movable, clamped, Escape-close via `UISpecialFrames`
- custom themed background/borders
- compact, caption-free custom-themed expansion and season dropdowns above the table
- a season-state label beside the selectors; the compact card button changes from Statistics to Rewind as soon as the selected season has ended
- the card's Rated Games headline includes all rated games and Solo Shuffle rounds; Peak Rating uses the highest season-best value across every bracket. A fifth anonymous Most Valuable Spec metric groups spec-owned ratings across all characters of each specialization and selects the highest arithmetic mean. A bracket record is active when its rating is above 1000 and it has more than 10 games (or Shuffle rounds); at least three active records across the warband are required. Only Solo Shuffle and Solo BG contribute because 2v2/3v3/10v10 intentionally remain spec-agnostic. The metric presents only the winning specialization's icon. Hovering the Most Valuable Spec label opens a compact themed panel just beyond the card's right edge, separating the score, concrete total/count calculation, eligibility criteria, and bracket-scope note into a structured layout
- known expansion artwork appears beside the expansion/season title; the addon name is reserved for the footer
- the card base is fully opaque and covered from header to footer by a generated seamless wide logo background, with no separate header wash; the texture is aspect-preserved, slightly zoomed, and vertically focused so the shield sits behind the header metrics at every dynamic card height, while metric and bracket fills remain slightly translucent so the artwork is visible through them
- the card grows to show all content without scrolling; Solo Shuffle and Solo Battleground have dedicated columns, while 2v2, 3v3, and 10v10 are stacked in the far-right column
- solo-bracket rows retain spec-owned counters but present only the spec icon, record, win rate, and golden best season rating; hovering the icon identifies the class and specialization. Non-solo brackets remain spec-agnostic and show aligned win-rate, record, best-rating, and most-played-class summaries, with empty brackets reduced to a centered `No data` state
- Rewind totals use Blizzard's cumulative counters from canonical seasonal character records: Solo Shuffle is measured in rounds, Solo BG in per-spec games, and 2v2/3v3/RBG in character-level games. History points remain graph data and are used only as an explicitly partial fallback when authoritative counters are unavailable.
- an icon-only camera control enlarges the card to the available screen height before calling WoW's screenshot API, hides capture controls and standard tooltips, blocks transient mouseover pollution, and restores the normal card on the following frame
- cog button opens the settings side panel
- table and graph are created lazily once the main frame exists

### Table Rendering

`UI.RefreshTable()`:

1. gets a read-only display view from `History.GetSeasonDisplayCharacters()`; for ended seasons, a provably complete graph can restore the last completed-match rating when an offseason API update already drifted the canonical snapshot
2. gets groups and season-specific columns from `Database`
3. rebuilds pooled header/row cells
4. renders class/name, per-spec subrows, global cells, icons, tooltips, graph overlays
5. resizes the main window width to fit visible columns
6. refreshes the graph if it is open

Rows and cells are pooled. `ResetCells()` hides/reuses existing font strings, textures, and overlays instead of creating new frames every refresh.

### Graph Rendering

`UI.RefreshHistoryGraph()`:

- reads the selected season's history series via `History.GetSeriesForSeason`
- computes a padded, rounded Y scale from the selected Rating/MMR lines in the visible window
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
  - initialize settings and atomically migrate/validate seasonal storage before collection
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
- `ARENA_SEASON_WORLD_STATE`
  - refresh the rated-season state and table toolbar
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
  - trim one oldest archived season's raw graph points while preserving summaries

## History Size Management

`History.EnsureCurrentSeason()` tracks the rated-PvP API season. `Season.IsRatedSeasonActive()` separately distinguishes a live rated season from the offseason value `0`. `History.EnsureContentSeason()` controls collection/feature rollover at the client patch boundary, archives the prior canonical season in place, and creates clean current-season baselines while preserving persistent Honor/HK values.

Every season keeps full canonical character records plus expansion/season metadata. History-only characters from legacy data are reconstructed into minimal records so their series never become orphaned. Archived seasons keep both summaries and raw points during normal operation. `SAVED_VARIABLES_TOO_LARGE` is the only automatic pruning path:

- non-current seasons are archived
- the oldest archived season that still has raw graph points is trimmed
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
- The graph Y scale updates with the visible window and selected Rating/MMR lines so local changes remain readable while navigating with the slider.
- Detached graph Escape handling depends on `WarbandRatingsHistoryGraphPanel` being in `UISpecialFrames`.
