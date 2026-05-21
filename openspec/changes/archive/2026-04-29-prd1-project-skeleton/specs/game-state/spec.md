## ADDED Requirements

### Requirement: Game state management
GameManager SHALL maintain a `current_state` property using a `GameState` enum with values: `MAIN_MENU`, `PLAYING`, `PAUSED`.

#### Scenario: Initial state is MAIN_MENU
- **WHEN** GameManager initializes
- **THEN** `current_state` SHALL be `GameState.MAIN_MENU`

#### Scenario: Start new game transitions to PLAYING
- **WHEN** `GameManager.start_new_game()` is called
- **THEN** `current_state` SHALL change to `GameState.PLAYING`

#### Scenario: Pause game transitions to PAUSED
- **WHEN** `GameManager.pause_game()` is called while state is PLAYING
- **THEN** `current_state` SHALL change to `GameState.PAUSED`

#### Scenario: Resume game transitions back to PLAYING
- **WHEN** `GameManager.resume_game()` is called while state is PAUSED
- **THEN** `current_state` SHALL change to `GameState.PLAYING`

### Requirement: Player gold management
GameManager SHALL maintain a `player_gold` property with an initial value of 100.

#### Scenario: Initial gold value
- **WHEN** a new game is started
- **THEN** `GameManager.player_gold` SHALL equal `100`

#### Scenario: Gold accessible from any script
- **WHEN** any script references `GameManager.player_gold`
- **THEN** the current gold value SHALL be returned without error

### Requirement: Player level and XP
GameManager SHALL maintain `player_level` (initial: 1) and `player_xp` (initial: 0) properties.

#### Scenario: Initial level and XP
- **WHEN** a new game is started
- **THEN** `GameManager.player_level` SHALL equal `1` and `GameManager.player_xp` SHALL equal `0`

### Requirement: Player energy system
GameManager SHALL maintain `player_energy` (initial: 100) and `player_max_energy` (initial: 100) properties.

#### Scenario: Initial energy values
- **WHEN** a new game is started
- **THEN** `GameManager.player_energy` SHALL equal `100` and `GameManager.player_max_energy` SHALL equal `100`

### Requirement: Reset to default
GameManager SHALL provide a `reset_to_default()` method that resets all player properties to their initial values.

#### Scenario: Reset restores all defaults
- **WHEN** `GameManager.reset_to_default()` is called after player data has been modified
- **THEN** `player_gold` SHALL be `100`, `player_level` SHALL be `1`, `player_xp` SHALL be `0`, `player_energy` SHALL be `100`

### Requirement: SaveManager placeholder
SaveManager SHALL exist as a registered Autoload with placeholder methods `save_game()`, `load_game()`, and `has_save()` that emit warnings and return false.

#### Scenario: Save game placeholder
- **WHEN** `SaveManager.save_game(0)` is called
- **THEN** a warning "SaveManager: 尚未实现 (PRD6)" SHALL be printed and the method SHALL return `false`

#### Scenario: Has save placeholder
- **WHEN** `SaveManager.has_save(0)` is called
- **THEN** the method SHALL return `false`

### Requirement: AudioManager placeholder
AudioManager SHALL exist as a registered Autoload with placeholder methods `play_bgm()`, `play_sfx()`, and `stop_bgm()` that emit warnings.

#### Scenario: Play BGM placeholder
- **WHEN** `AudioManager.play_bgm("bgm_morning")` is called
- **THEN** a warning "AudioManager: 尚未实现 (PRD19)" SHALL be printed and no crash SHALL occur

#### Scenario: Play SFX placeholder
- **WHEN** `AudioManager.play_sfx("sfx_plant")` is called
- **THEN** a warning "AudioManager: 尚未实现 (PRD19)" SHALL be printed and no crash SHALL occur

### Requirement: Autoload registration in project.godot
All 5 Autoloads (EventBus, DataManager, GameManager, SaveManager, AudioManager) SHALL be registered in the `[autoload]` section of project.godot in the correct load order.

#### Scenario: All autoloads accessible
- **WHEN** any game script runs
- **THEN** `EventBus`, `DataManager`, `GameManager`, `SaveManager`, and `AudioManager` SHALL all be accessible as global singletons

#### Scenario: Load order is correct
- **WHEN** project.godot `[autoload]` section is inspected
- **THEN** the order SHALL be: EventBus, DataManager, GameManager, SaveManager, AudioManager

### Requirement: Initialization logging
Each Autoload SHALL print a confirmation log message in `_ready()` to verify successful initialization.

#### Scenario: Console shows all init logs
- **WHEN** the game launches
- **THEN** the console SHALL display initialization messages from all 5 Autoloads confirming they are ready
