## ADDED Requirements

### Requirement: Level unlock signals are broadcast through EventBus
`EventBus` SHALL define typed signals for level-system unlock changes: `unlocks_changed(unlocks: Dictionary)`, `crop_unlocked(crop_id: String, level: int)`, `feature_unlocked(feature_id: String, level: int)`, and `farm_slots_changed(new_slots: int)`.

#### Scenario: Unlocks changed signal is emitted for upgrade unlocks
- **WHEN** `LevelManager.add_xp()` causes one or more level-ups with unlocked content
- **THEN** `EventBus.unlocks_changed(unlocks: Dictionary)` SHALL be emitted once with the merged unlocks for that XP operation

#### Scenario: Crop unlock signals are emitted per crop
- **WHEN** a level-up unlocks one or more crops
- **THEN** `EventBus.crop_unlocked(crop_id: String, level: int)` SHALL be emitted once for each newly unlocked crop

#### Scenario: Feature unlock signals are emitted per feature
- **WHEN** a level-up unlocks one or more features
- **THEN** `EventBus.feature_unlocked(feature_id: String, level: int)` SHALL be emitted once for each newly unlocked feature

#### Scenario: Farm slot change is emitted when capacity increases
- **WHEN** a level-up increases the unlocked farm-slot capacity
- **THEN** `EventBus.farm_slots_changed(new_slots: int)` SHALL be emitted with the new capacity

## MODIFIED Requirements

### Requirement: Level and XP signals
EventBus SHALL define signals for experience gain and level progression while preserving PRD5-compatible signatures.

#### Scenario: XP gained signal emitted
- **WHEN** `LevelManager.add_xp(amount, source)` successfully adds experience points
- **THEN** EventBus SHALL emit `xp_gained(amount: int, source: String)`
- **AND** the signal SHALL NOT be emitted for failed XP operations

#### Scenario: Level up signal emitted
- **WHEN** the player's XP reaches the threshold for the next level and `LevelManager.check_level_up()` raises the level
- **THEN** EventBus SHALL emit `level_up(new_level: int)` once for each level gained
- **AND** a multi-level upgrade SHALL emit one `level_up` signal per gained level in ascending order
