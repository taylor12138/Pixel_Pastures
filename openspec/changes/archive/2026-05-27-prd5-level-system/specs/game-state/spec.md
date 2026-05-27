## MODIFIED Requirements

### Requirement: Player level and XP
GameManager SHALL maintain player XP and level runtime values with initial level `1` and XP `0`; `LevelManager` SHALL be the business authority for XP addition, level checks, and unlock queries.

#### Scenario: Initial level and XP
- **WHEN** a new game is started
- **THEN** `GameManager.level` SHALL equal `1`
- **AND** `GameManager.xp` SHALL equal `0`

#### Scenario: GameManager delegates XP gain when LevelManager exists
- **WHEN** `GameManager.add_xp(amount, source)` is called and `LevelManager` is available
- **THEN** `GameManager` SHALL delegate the operation to `LevelManager.add_xp(amount, source)`
- **AND** `GameManager` SHALL NOT run duplicate level-up logic for the same operation

#### Scenario: GameManager legacy XP fallback remains available
- **WHEN** `GameManager.add_xp(amount, source)` is called and `LevelManager` is not available
- **THEN** `GameManager` SHALL preserve a fallback behavior that can add XP without crashing

### Requirement: Reset to default
GameManager SHALL provide a `reset_to_default()` method that resets all player properties to their initial values, including XP and level values consumed by LevelManager.

#### Scenario: Reset restores all defaults
- **WHEN** `GameManager.reset_to_default()` is called after player data has been modified
- **THEN** `GameManager.gold` or `player_gold` SHALL be reset to its configured starting value
- **AND** `GameManager.level` SHALL be `1`
- **AND** `GameManager.xp` SHALL be `0`
- **AND** player energy SHALL be reset to its configured starting value

### Requirement: Autoload registration in project.godot
All required Autoloads SHALL be registered in the `[autoload]` section of `project.godot` in dependency order, including `LevelManager` after `EconomyManager` and before `SceneManager` and `AudioManager`.

#### Scenario: All autoloads accessible
- **WHEN** any game script runs
- **THEN** `EventBus`, `DataManager`, `GameManager`, `CropManager`, `InventoryManager`, `EconomyManager`, `LevelManager`, `SceneManager`, and `AudioManager` SHALL be accessible as global singletons when their PRDs are implemented

#### Scenario: Load order includes LevelManager dependencies first
- **WHEN** project.godot `[autoload]` section is inspected
- **THEN** the order SHALL place `EventBus`, `DataManager`, and `GameManager` before `LevelManager`
- **AND** `LevelManager` SHALL be registered after `EconomyManager` and before `SceneManager` and `AudioManager`

### Requirement: Game save data preserves level system data when available
GameManager SHALL include LevelManager save data in its save payload when the `LevelManager` Autoload exists, and SHALL restore it during load when level-system data is present.

#### Scenario: Save includes level system data
- **WHEN** `GameManager.save_game()` is called and `LevelManager` is available
- **THEN** the serialized save data SHALL contain a `level_system` field
- **AND** that field SHALL equal `LevelManager.export_save_data()`

#### Scenario: Load restores level system data
- **WHEN** `GameManager.load_game()` reads save data containing a `level_system` field
- **AND** `LevelManager` is available
- **THEN** it SHALL call `LevelManager.import_save_data(level_system_data)`
- **AND** XP and level consistency SHALL be restored through `LevelManager.recalculate_level()`

#### Scenario: Legacy save without level system data remains compatible
- **WHEN** `GameManager.load_game()` reads a save file without a `level_system` field
- **THEN** loading SHALL still succeed
- **AND** `GameManager.xp` and `GameManager.level` root fields SHALL remain compatible with existing save behavior
