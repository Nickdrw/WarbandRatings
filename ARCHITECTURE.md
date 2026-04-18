# WarbandRatings — Architecture & Developer Guide

## Overview

WarbandRatings is a World of Warcraft Retail addon that tracks PvP and Mythic+ ratings across all characters on an account. Data is collected per-character on login and stored in SavedVariables. A standalone window displays all characters with their ratings in a table format.

## Environment

- **WoW Lua 5.1** — no `goto`, no `continue`, no `//` integer division
- **Retail client** (Interface 120001+, The War Within / TWW expansion era)
- **SavedVariables**: `WarbandRatingsDB` (account-wide, declared in `.toc`)
- **Linting**: `luacheck .` using `.luacheckrc` (declares WoW globals)

## File Structure & Load Order

Files load in `.toc` order. Each file receives the addon namespace via `local _, ns = ...` and registers its module on `ns`.

| File | Module | Purpose |
|------|--------|---------|
| `Utils.lua` | `ns.Utils` | Pure helpers: class colors, char keys, rating formatting, spec/class icon lookups, timestamps |
| `Database.lua` | `ns.Database` | Column definitions, SavedVariables init/migration, settings, character storage, filtered queries |
| `DataCollection.lua` | `ns.DataCollection` | Gathers current character's ratings from WoW API and saves to DB |
| `UI.lua` | `ns.UI` | All frames: main window, scroll area, settings panel, table rendering, PvP button, minimap button |
| `Core.lua` | *(entry point)* | Event handling, initialization orchestration, slash commands |

## Key APIs Used

### PvP Ratings
- `GetPersonalRatedInfo(bracketIndex)` — returns rating for a PvP bracket
  - 1 = Arena 2v2, 2 = Arena 3v3, 4 = 10v10 RBG, 7 = Solo Shuffle, 8 = BG Blitz
- `RequestRatedInfo()` — requests PvP data from server (async, fires `PVP_RATED_STATS_UPDATE`)

### Mythic+ Score
- `C_ChallengeMode.GetOverallDungeonScore()` — returns M+ score

### Character Info
- `UnitName("player")`, `UnitClass("player")`, `UnitLevel("player")`
- `GetNormalizedRealmName()`, `GetSpecialization()`, `GetSpecializationInfo()`

## Data Model

### `WarbandRatingsDB` (SavedVariables)

```lua
WarbandRatingsDB = {
    characters = {
        ["Name-Realm"] = {
            name = "Name",
            realm = "Realm",
            classFilename = "WARRIOR",  -- uppercase English token
            classID = 1,
            level = 80,
            ratings = {                  -- global ratings (same across all specs)
                arena2v2 = 1500,
                arena3v3 = 1600,
                rbg10v10 = 0,
                mythicPlus = 2500,
            },
            specRatings = {              -- per-spec ratings (Solo Shuffle, BG Blitz)
                [71] = { soloShuffle = 1800, soloBG = 0 },  -- specID = Arms
                [72] = { soloShuffle = 1600, soloBG = 0 },  -- specID = Fury
            },
            lastUpdated = 1713400000,    -- time()
        },
    },
    settings = {
        hideNoRating = false,       -- hide chars with zero in all brackets
        hideEmptyColumns = false,   -- hide columns where no char has a rating
        hideNonMaxLevel = true,     -- show only max-level characters
        hideMinimapIcon = false,    -- hide the minimap button
        minimapPos = 220,           -- minimap button angle in degrees
    },
}
```

### Column System

Columns are split into two categories defined in `Database.lua`:

- **SPEC_COLUMNS**: Solo Shuffle, Solo BG — ratings differ per specialization. Stored under `charData.specRatings[specID]`.
- **GLOBAL_COLUMNS**: 2v2, 3v3, 10v10, Mythic+ — same rating regardless of spec. Stored under `charData.ratings`.

`Database.IsSpecColumn(col)` checks which category a column belongs to.

## UI Architecture

### Main Window
- `BasicFrameTemplateWithInset` frame, movable, draggable, added to `UISpecialFrames` for Escape-to-close
- Cogwheel button opens a settings side panel (`InsetFrameTemplate3`)

### Table Rendering (`RefreshTable`)
- Header row with column labels
- Character rows with:
  - Class icon + colored name (word-wrap disabled, truncates with `...`)
  - For **spec columns**: if any spec has a rating, shows one sub-row per rated spec (spec icon + rating). If no spec has a rating, shows a single centered hyphen aligned with the spec-rating text position.
  - For **global columns**: single centered value
- Row height adapts: `numSpecs * SUBROW_HEIGHT` if spec ratings exist, else `1 * SUBROW_HEIGHT`
- Alternating row backgrounds

### Scrolling
- Plain `ScrollFrame` (no scrollbar template) — mouse wheel only, 1 row per tick
- No scrollbar visual; content extends to full frame width

### Minimap Button
- Custom minimap button (no library dependency), draggable around minimap edge
- Position saved in `settings.minimapPos` (angle in degrees)
- Can be hidden via settings checkbox

### PvP Tab Button
- A `UIPanelButtonTemplate` button parented to `PVPUIFrame` (only visible on PvP tab of Group Finder)
- Created lazily: tries immediately, falls back to `ADDON_LOADED` event for `Blizzard_PVPUI`, or hooks `PVEFrame:OnShow`

## Sorting
Characters are sorted by class (alphabetical by `classFilename`), then by name within the same class.

## Settings Filters (applied in `Database.GetFilteredCharacterGroups`)
1. **hideNonMaxLevel**: Compares `charData.level` against `GetMaxLevelForPlayerExpansion()` (fallback 80)
2. **hideNoRating**: Skips characters with zero/nil in all rating columns (global + all specs)
3. **hideEmptyColumns**: `GetVisibleColumns()` omits columns where no character has a value

## Events (handled in `Core.lua`)
- `PLAYER_LOGIN`: Init DB, request PvP data, collect after 2s delay, attach UI
- `PVP_RATED_STATS_UPDATE`: Re-collect ratings (0.5s debounce)
- `ACTIVE_TALENT_GROUP_CHANGED`: Re-collect for new spec (0.5s debounce)

## Slash Commands
- `/wr` or `/warbandratings` — toggles the main window

## Known Patterns & Pitfalls
- **VS Code + WSL file watcher**: When editing files on a Windows-mounted path from WSL, VS Code's file watcher can append old content to files. Use terminal heredoc (`cat > file << 'ENDOFFILE'`) to write files safely, or reject IDE overwrites.
- **WoW FontString wrapping**: `SetWordWrap(false)` and `SetNonSpaceWrap(false)` must be set explicitly to get text truncation instead of line wrapping.
- **PVEFrame tabs**: PVEFrame is not designed for third-party tabs. Attempts to add a 4th tab caused bleed-through of Blizzard frames and required frame strata hacks. The button approach is simpler and reliable.
- **SavedVariables merging**: `SaveCharacter()` merges into existing records. New fields (like `level`) must be explicitly copied in the merge branch, not just the create branch.
- **PvP data availability**: Ratings aren't available immediately on login. `RequestRatedInfo()` is called, then data is collected after a delay and again on `PVP_RATED_STATS_UPDATE`.
