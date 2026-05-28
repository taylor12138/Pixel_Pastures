## MODIFIED Requirements

### Requirement: Autoload registration in project.godot
All core Autoloads SHALL be registered in the `[autoload]` section of project.godot in dependency-safe load order including TimeManager after EventBus and before systems that consume game-time events, and including SaveManager after the gameplay managers.

#### Scenario: All autoloads accessible
- **WHEN** any game script runs
- **THEN** `EventBus`, `DataManager`, `GameManager`, `TimeManager`, `CropManager`, `InventoryManager`, `EconomyManager`, `LevelManager`, `SceneManager`, `SaveManager`, and `AudioManager` SHALL all be accessible as global singletons when their scripts exist in the project

#### Scenario: Load order is correct
- **WHEN** project.godot `[autoload]` section is inspected
- **THEN** the order SHALL place `TimeManager` after `EventBus`, `DataManager`, and `GameManager`
- **AND** it SHALL place `TimeManager` before `CropManager` when feasible so CropManager can subscribe to game-time events during initialization
- **AND** it SHALL place `SaveManager` after `EventBus`, `DataManager`, `GameManager`, `TimeManager`, `CropManager`, `InventoryManager`, `EconomyManager`, `LevelManager`, and `SceneManager`
- **AND** it SHALL place `SaveManager` before `AudioManager`

### Requirement: Game state management
GameManager SHALL maintain a `current_state` property using a `GameState` enum with values: `MAIN_MENU`, `PLAYING`, `PAUSED`, and SHALL initialize TimeManager to a new-game default time when TimeManager is available.

#### Scenario: Initial state is MAIN_MENU
- **WHEN** GameManager initializes
- **THEN** `current_state` SHALL be `GameState.MAIN_MENU`

#### Scenario: Start new game transitions to PLAYING
- **WHEN** `GameManager.start_new_game()` is called
- **THEN** `current_state` SHALL change to `GameState.PLAYING`
- **AND** if `TimeManager` is available, `TimeManager.initialize_new_game()` SHALL be called
- **AND** the new game time SHALL be 第 1 年 `spring` 第 1 天 06:00

#### Scenario: Pause game transitions to PAUSED
- **WHEN** `GameManager.pause_game()` is called while state is PLAYING
- **THEN** `current_state` SHALL change to `GameState.PAUSED`

#### Scenario: Resume game transitions back to PLAYING
- **WHEN** `GameManager.resume_game()` is called while state is PAUSED
- **THEN** `current_state` SHALL change to `GameState.PLAYING`
