## ADDED Requirements

### Requirement: LevelManager is the level progression authority
The system SHALL provide a `LevelManager` Autoload singleton that is the authoritative business entry point for XP gain, level recalculation, level-up checks, XP progress queries, and level-system save import/export while `GameManager` remains the runtime storage owner for XP and level values.

#### Scenario: LevelManager is globally available
- **WHEN** the Godot project starts
- **THEN** `LevelManager` SHALL be available as an Autoload singleton
- **AND** systems SHALL call `LevelManager` for XP, level, and unlock operations without manually instantiating it

#### Scenario: XP and level values are stored in GameManager
- **WHEN** `LevelManager.add_xp(amount, source)` succeeds
- **THEN** it SHALL update `GameManager.xp` and `GameManager.level`
- **AND** it MUST NOT maintain a duplicate authoritative XP or level value

### Requirement: XP gain returns structured results
`LevelManager.add_xp(amount: int, source: String = "manual")` SHALL validate input, add XP, update total XP stats, check for level-ups, emit XP events, and return a stable Dictionary result.

#### Scenario: XP gain succeeds without level up
- **WHEN** `GameManager.level` is `1`, `GameManager.xp` is `50`, and `LevelManager.add_xp(10, "manual")` is called
- **THEN** the result SHALL contain `success=true`, `xp_added=10`, `xp_before=50`, `xp_after=60`, `level_before=1`, `level_after=1`, `leveled_up=false`, `levels_gained=[]`, and empty or unchanged unlocks
- **AND** `GameManager.xp` SHALL equal `60`

#### Scenario: Invalid XP amount is rejected
- **WHEN** `LevelManager.add_xp(0, "manual")` or `LevelManager.add_xp(-1, "manual")` is called
- **THEN** the result SHALL contain `success=false` and `error_code="INVALID_XP_AMOUNT"`
- **AND** `GameManager.xp`, `GameManager.level`, and XP stats SHALL remain unchanged

#### Scenario: Empty source is rejected
- **WHEN** `LevelManager.add_xp(10, "")` is called
- **THEN** the result SHALL contain `success=false` and `error_code="INVALID_SOURCE"`
- **AND** no XP, level, or stat side effects SHALL occur

### Requirement: Level-up checks use cumulative XP thresholds
`LevelManager.check_level_up()` SHALL compare `GameManager.xp` against cumulative `xp_required` values from `DataManager.get_level_data(next_level)` and SHALL support gaining multiple levels from one XP gain.

#### Scenario: Single level-up occurs at threshold
- **WHEN** `GameManager.level` is `1`, `GameManager.xp` is `90`, and `LevelManager.add_xp(10, "manual")` is called
- **THEN** `GameManager.level` SHALL become `2`
- **AND** the result SHALL contain `leveled_up=true` and `levels_gained=[2]`
- **AND** the result unlocks SHALL include level 2 unlocks

#### Scenario: Multiple level-ups occur from one XP gain
- **WHEN** `GameManager.level` is `1`, `GameManager.xp` is `0`, and `LevelManager.add_xp(500, "manual")` is called
- **THEN** `GameManager.level` SHALL become `4`
- **AND** the result SHALL contain `levels_gained=[2, 3, 4]`
- **AND** unlocks from levels 2, 3, and 4 SHALL be merged in the result

#### Scenario: Max level keeps accumulating XP
- **WHEN** `GameManager.level` is the maximum configured level and `LevelManager.add_xp(100, "manual")` is called
- **THEN** `GameManager.xp` SHALL increase by `100`
- **AND** `GameManager.level` SHALL remain at the maximum configured level
- **AND** no `level_up` event SHALL be emitted

### Requirement: Level recalculation repairs XP and level mismatches
`LevelManager.recalculate_level()` SHALL compute the correct level from current cumulative `GameManager.xp` and configured level thresholds without granting upgrade rewards.

#### Scenario: Recalculate raises level from XP
- **WHEN** `GameManager.level` is `1` and `GameManager.xp` is `500`
- **AND** `LevelManager.recalculate_level()` is called
- **THEN** `GameManager.level` SHALL become `4`
- **AND** the result SHALL report the previous level, new level, and that a correction occurred

#### Scenario: Recalculate does not emit reward signals
- **WHEN** `LevelManager.recalculate_level()` changes `GameManager.level`
- **THEN** it SHALL NOT emit per-level upgrade rewards, `crop_unlocked`, `feature_unlocked`, or duplicate unlock notifications

### Requirement: XP source rules are centralized
`LevelManager.calculate_xp(source: String, context: Dictionary = {})` and `LevelManager.grant_xp(source: String, context: Dictionary = {})` SHALL centralize XP calculation rules for supported sources.

#### Scenario: Plant XP is calculated
- **WHEN** `LevelManager.calculate_xp("plant")` is called
- **THEN** it SHALL return `5`

#### Scenario: Harvest XP is calculated
- **WHEN** `LevelManager.calculate_xp("harvest")` is called
- **THEN** it SHALL return `10`

#### Scenario: Sell XP is calculated from total price
- **WHEN** `LevelManager.calculate_xp("sell", {"total_price": 50})` is called
- **THEN** it SHALL return `25`

#### Scenario: Manual XP is calculated from amount context
- **WHEN** `LevelManager.grant_xp("manual", {"amount": 20})` is called
- **THEN** it SHALL add `20` XP using the same result structure as `add_xp()`

#### Scenario: Unknown XP source is rejected
- **WHEN** `LevelManager.grant_xp("missing_source", {})` is called
- **THEN** the result SHALL contain `success=false` and `error_code="INVALID_SOURCE"`
- **AND** no XP or level side effects SHALL occur

### Requirement: Level query interfaces expose safe data
`LevelManager` SHALL expose current level data, next level data, max level, max-level status, XP progress, and progress setters for tests and load repair.

#### Scenario: XP progress includes current and next thresholds
- **WHEN** `GameManager.level` is `1` and `GameManager.xp` is `50`
- **AND** `LevelManager.get_xp_progress()` is called
- **THEN** it SHALL return a Dictionary containing current XP, current level, next level threshold, progress amount, and progress ratio

#### Scenario: Max level query returns empty next level
- **WHEN** `GameManager.level` is the maximum configured level
- **THEN** `LevelManager.is_max_level()` SHALL return `true`
- **AND** `LevelManager.get_next_level_data()` SHALL return an empty Dictionary

### Requirement: Level system save data round trips
`LevelManager.export_save_data()` SHALL export XP, level, unlocked crops, unlocked features, and farm slots; `LevelManager.import_save_data(data)` SHALL restore XP and level then recalculate level consistency.

#### Scenario: Export includes level system snapshot
- **WHEN** `LevelManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary containing `xp`, `level`, `unlocked_crops`, `unlocked_features`, and `farm_slots`

#### Scenario: Import repairs inconsistent data
- **WHEN** import data contains `xp=500` and `level=1`
- **AND** `LevelManager.import_save_data(data)` is called
- **THEN** `GameManager.xp` SHALL become `500`
- **AND** `GameManager.level` SHALL be recalculated to `4`
