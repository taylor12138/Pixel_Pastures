## ADDED Requirements

### Requirement: Content unlocks are derived from level data
`LevelManager` SHALL derive crop, feature, and farm-slot unlocks from `DataManager.get_level_data()` and cumulative `levels.json.unlocks` entries from level 1 through the requested level.

#### Scenario: Level 1 cumulative unlocks are returned
- **WHEN** `GameManager.level` is `1`
- **AND** `LevelManager.get_accumulated_unlocks()` is called
- **THEN** the result SHALL include crops `carrot`, `cabbage`, `corn`, and `potato`
- **AND** features SHALL include `basic_farm`
- **AND** `farm_slots` SHALL equal `12`

#### Scenario: Level 4 cumulative unlocks are returned
- **WHEN** `GameManager.level` is `4`
- **AND** `LevelManager.get_accumulated_unlocks()` is called
- **THEN** the result SHALL include crops through `pepper` and `eggplant`
- **AND** features SHALL include `steal_crops` and `expand_land`
- **AND** `farm_slots` SHALL equal `36`

#### Scenario: Unlock arrays are safe copies
- **WHEN** external code mutates arrays returned by `LevelManager.get_unlocked_crops()` or `LevelManager.get_unlocked_features()`
- **THEN** subsequent queries SHALL NOT reflect those external mutations

### Requirement: Crop unlock queries use LevelManager
`LevelManager` SHALL provide crop unlock queries including `is_crop_unlocked(crop_id)`, `get_crop_unlock_level(crop_id)`, `get_unlocked_crops()`, and `get_locked_crops()`.

#### Scenario: Crop is unlocked by current level
- **WHEN** `GameManager.level` is `2`
- **THEN** `LevelManager.is_crop_unlocked("tomato")` SHALL return `true`
- **AND** `LevelManager.get_crop_unlock_level("tomato")` SHALL return `2`

#### Scenario: Crop remains locked below unlock level
- **WHEN** `GameManager.level` is `1`
- **THEN** `LevelManager.is_crop_unlocked("tomato")` SHALL return `false`
- **AND** `LevelManager.get_locked_crops()` SHALL include tomato with its required unlock level

#### Scenario: Missing crop is not unlocked
- **WHEN** `LevelManager.is_crop_unlocked("missing_crop")` is called
- **THEN** it SHALL return `false`

#### Scenario: Crop table unlock level is used as compatibility fallback
- **WHEN** a crop is absent from `levels.json.unlocks.crops` but has `unlock_level` in `crops.json`
- **THEN** `LevelManager.is_crop_unlocked(crop_id)` SHALL compare `GameManager.level` with that crop `unlock_level`

### Requirement: Feature unlock queries use cumulative level unlocks
`LevelManager` SHALL provide `is_feature_unlocked(feature_id)` and `get_unlocked_features()` based on cumulative feature unlocks from `levels.json`.

#### Scenario: Basic farm feature is unlocked at level 1
- **WHEN** `GameManager.level` is `1`
- **THEN** `LevelManager.is_feature_unlocked("basic_farm")` SHALL return `true`

#### Scenario: Decoration mode unlocks at level 3
- **WHEN** `GameManager.level` is `2`
- **THEN** `LevelManager.is_feature_unlocked("decoration_mode")` SHALL return `false`
- **WHEN** `GameManager.level` is `3`
- **THEN** `LevelManager.is_feature_unlocked("decoration_mode")` SHALL return `true`

#### Scenario: Unknown feature is locked
- **WHEN** `LevelManager.is_feature_unlocked("missing_feature")` is called
- **THEN** it SHALL return `false`

### Requirement: Farm slot unlock query returns current capacity
`LevelManager.get_unlocked_farm_slots()` SHALL return the current level's configured farm-slot capacity and SHALL inherit the previous maximum if a level omits `farm_slots`.

#### Scenario: Farm slots increase by level
- **WHEN** `GameManager.level` is `1`, `2`, `3`, `4`, `5`, `6`, or `7`
- **THEN** `LevelManager.get_unlocked_farm_slots()` SHALL return `12`, `16`, `24`, `36`, `48`, `64`, or `80` respectively

#### Scenario: Missing farm slots inherit previous value
- **WHEN** a level configuration lacks `unlocks.farm_slots`
- **THEN** accumulated unlocks SHALL use the most recent lower-level farm slot value instead of returning `0`

### Requirement: Per-level unlock data is queryable
`LevelManager.get_level_unlocks(level: int)` SHALL return only the unlocks introduced at the specified level, while `get_accumulated_unlocks(level: int = -1)` SHALL return all unlocks through the target level.

#### Scenario: Level unlocks return only new content
- **WHEN** `LevelManager.get_level_unlocks(4)` is called
- **THEN** it SHALL return crops `pepper` and `eggplant`
- **AND** features `steal_crops` and `expand_land`
- **AND** `farm_slots` equal to `36`

#### Scenario: Invalid level unlocks are empty
- **WHEN** `LevelManager.get_level_unlocks(999)` is called
- **THEN** it SHALL return an empty or default unlock Dictionary without crashing

### Requirement: Upgrade results include merged unlocks
When an XP gain causes one or more level-ups, the result Dictionary SHALL include merged unlocks for all gained levels with duplicate crops and features removed and the final farm-slot value retained.

#### Scenario: Multi-level unlocks are merged
- **WHEN** `LevelManager.add_xp(500, "manual")` raises the player from level 1 to level 4
- **THEN** result unlocks SHALL include level 2, 3, and 4 crops and features
- **AND** `farm_slots` SHALL equal `36`
- **AND** duplicate crop or feature IDs SHALL appear only once
