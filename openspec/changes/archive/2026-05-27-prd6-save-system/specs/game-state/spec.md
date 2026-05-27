## MODIFIED Requirements

### Requirement: SaveManager placeholder
SaveManager SHALL exist as a registered Autoload with concrete persistence methods that return structured Dictionary results and manage local JSON saves.

#### Scenario: Save game persists data
- **WHEN** `SaveManager.save_game(0)` is called with valid runtime state
- **THEN** the method SHALL write a JSON save file for slot 0
- **AND** it SHALL return a Dictionary with `success=true`

#### Scenario: Load game restores data
- **WHEN** `SaveManager.load_game(0)` is called for a valid save file
- **THEN** the method SHALL restore saved runtime state
- **AND** it SHALL return a Dictionary with `success=true`

#### Scenario: Has save checks valid save existence
- **WHEN** `SaveManager.has_save(0)` is called for an existing valid save
- **THEN** the method SHALL return `true`
- **WHEN** the slot is missing or invalid
- **THEN** the method SHALL return `false`

### Requirement: Autoload registration in project.godot
All core Autoloads SHALL be registered in the `[autoload]` section of project.godot in dependency-safe load order including SaveManager after the PRD1-5 gameplay managers.

#### Scenario: All autoloads accessible
- **WHEN** any game script runs
- **THEN** `EventBus`, `DataManager`, `GameManager`, `CropManager`, `InventoryManager`, `EconomyManager`, `LevelManager`, `SceneManager`, `SaveManager`, and `AudioManager` SHALL all be accessible as global singletons when their scripts exist in the project

#### Scenario: Load order is correct
- **WHEN** project.godot `[autoload]` section is inspected
- **THEN** the order SHALL place `SaveManager` after `EventBus`, `DataManager`, `GameManager`, `CropManager`, `InventoryManager`, `EconomyManager`, `LevelManager`, and `SceneManager`
- **AND** it SHALL place `SaveManager` before `AudioManager`

## ADDED Requirements

### Requirement: GameManager save export and import
GameManager SHALL expose serializable save export and import behavior for player core state used by SaveManager.

#### Scenario: GameManager exports core state
- **WHEN** `GameManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary containing game state, gold, level, XP, energy, max energy, stats, and last-online timestamp

#### Scenario: GameManager imports core state
- **WHEN** `GameManager.import_save_data(data)` receives saved core state
- **THEN** it SHALL restore gold, level, XP, energy, max energy, and stats
- **AND** it SHALL set runtime state to playing after a successful load
