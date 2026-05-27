## MODIFIED Requirements

### Requirement: Save/Load signals
EventBus SHALL define typed signals for save, load, delete, and auto-save operations.

#### Scenario: Game saved signal emitted
- **WHEN** the game is successfully saved to a slot
- **THEN** EventBus SHALL emit `game_saved(slot: int, metadata: Dictionary)`

#### Scenario: Game loaded signal emitted
- **WHEN** a save file is successfully loaded from a slot
- **THEN** EventBus SHALL emit `game_loaded(slot: int, metadata: Dictionary)`

#### Scenario: Game save failed signal emitted
- **WHEN** a manual save operation fails
- **THEN** EventBus SHALL emit `game_save_failed(slot: int, error_code: String, message: String)`
- **AND** `error_code` SHALL be a stable non-empty error code

#### Scenario: Game load failed signal emitted
- **WHEN** a load operation fails
- **THEN** EventBus SHALL emit `game_load_failed(slot: int, error_code: String, message: String)`
- **AND** `error_code` SHALL be a stable non-empty error code

#### Scenario: Save deleted signal emitted
- **WHEN** a save slot delete operation succeeds
- **THEN** EventBus SHALL emit `save_deleted(slot: int)`

#### Scenario: Auto-save result signal emitted
- **WHEN** an auto-save operation succeeds
- **THEN** EventBus SHALL emit `auto_save_completed(result: Dictionary)`
- **WHEN** an auto-save operation fails
- **THEN** EventBus SHALL emit `auto_save_failed(result: Dictionary)`
