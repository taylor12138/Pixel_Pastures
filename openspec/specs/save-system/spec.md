# save-system Specification

## Purpose
This specification defines the save-system capability.

## Requirements

### Requirement: SaveManager Autoload singleton
The system SHALL provide a `SaveManager` Autoload singleton at `res://scripts/autoload/save_manager.gd` that orchestrates local JSON persistence for PRD1-5 runtime data.

#### Scenario: SaveManager is globally available
- **WHEN** the Godot project loads Autoload singletons
- **THEN** `SaveManager` SHALL be available globally
- **AND** it SHALL expose save, load, delete, listing, metadata, validation, migration, and auto-save APIs

#### Scenario: SaveManager initializes save directories
- **WHEN** `SaveManager.initialize()` or `SaveManager.ensure_save_dirs()` is called
- **THEN** the system SHALL create `user://saves/` and `user://saves/backup/` if they do not already exist

### Requirement: Save slot file paths
SaveManager SHALL support exactly three manual save slots and one auto-save slot.

#### Scenario: Manual slot path is resolved
- **WHEN** `SaveManager.get_save_path(0)` is called
- **THEN** it SHALL return `user://saves/slot_0.json`

#### Scenario: Auto-save path is resolved
- **WHEN** `SaveManager.get_save_path(-1)` is called
- **THEN** it SHALL return `user://saves/auto_save.json`

#### Scenario: Invalid slot is rejected
- **WHEN** a save operation receives a slot other than `0`, `1`, `2`, or `-1`
- **THEN** it SHALL fail with `error_code` equal to `INVALID_SLOT`
- **AND** it SHALL NOT write, read, delete, or mutate game state

### Requirement: Versioned JSON save structure
SaveManager SHALL serialize saves as JSON dictionaries with a stable root schema.

#### Scenario: Save root contains required fields
- **WHEN** `SaveManager.build_save_data(slot)` is called
- **THEN** the returned Dictionary SHALL contain `schema_version`, `game_version`, `created_at`, `updated_at`, `slot`, `metadata`, `game`, `inventory`, `crops`, `economy`, `level_system`, `settings`, and `future`

#### Scenario: Save root is JSON serializable
- **WHEN** SaveManager writes a save file
- **THEN** the save payload SHALL contain only JSON-serializable values
- **AND** coordinates SHALL be represented with string keys such as `"x,y"` instead of Vector2i objects

### Requirement: Manual save writes current runtime state
SaveManager SHALL save the current runtime state into a selected manual slot.

#### Scenario: Manual save succeeds
- **WHEN** `SaveManager.save_game(0)` is called with valid manager state
- **THEN** it SHALL write a valid JSON file to `user://saves/slot_0.json`
- **AND** the result Dictionary SHALL have `success=true`, `operation="save"`, and `slot=0`

#### Scenario: Save includes manager data
- **WHEN** a save succeeds
- **THEN** the JSON file SHALL include data exported from GameManager, InventoryManager, CropManager, EconomyManager, and LevelManager

#### Scenario: Save failure preserves previous save
- **WHEN** writing a save file fails after an older save already exists
- **THEN** SaveManager SHALL preserve the older save file
- **AND** return `success=false` with a stable error code

### Requirement: Save overwrite backup
SaveManager SHALL create a backup before overwriting an existing save file.

#### Scenario: Existing manual save is backed up
- **WHEN** `SaveManager.save_game(0)` overwrites an existing `slot_0.json`
- **THEN** SaveManager SHALL copy the previous save to `user://saves/backup/slot_0.bak.json` before replacing it

#### Scenario: Backup failure blocks overwrite
- **WHEN** backup creation fails before an overwrite
- **THEN** SaveManager SHALL return `success=false` with `error_code=BACKUP_FAILED`
- **AND** it SHALL NOT replace the previous save

### Requirement: Load restores saved runtime state
SaveManager SHALL load a valid save file and restore PRD1-5 manager state.

#### Scenario: Load succeeds
- **WHEN** `SaveManager.load_game(0)` reads a valid `slot_0.json`
- **THEN** it SHALL restore GameManager core state, InventoryManager slots and hotbar, CropManager tiles, EconomyManager stats, and LevelManager progress
- **AND** return `success=true`, `operation="load"`, and `slot=0`

#### Scenario: Load triggers post-load reconciliation
- **WHEN** `SaveManager.load_game(0)` succeeds
- **THEN** it SHALL trigger crop offline compensation using the saved last-online timestamp
- **AND** it SHALL trigger level consistency recalculation

#### Scenario: Failed load does not mutate runtime state
- **WHEN** `SaveManager.load_game(0)` fails because the file is missing, invalid JSON, invalid schema, unsupported schema, or failed migration
- **THEN** current runtime game state SHALL remain unchanged

### Requirement: Save validation and migration
SaveManager SHALL validate save data and provide a migration framework for older schemas.

#### Scenario: Valid save passes validation
- **WHEN** `SaveManager.validate_save_data(data)` receives a current-schema save with required root fields
- **THEN** it SHALL return `success=true`

#### Scenario: Missing required root fails validation
- **WHEN** validation receives data missing `metadata`, `game`, `inventory`, `crops`, `economy`, or `level_system`
- **THEN** it SHALL return `success=false` with `error_code=INVALID_SAVE_DATA`

#### Scenario: Future schema is rejected
- **WHEN** validation or migration receives a save whose `schema_version` is greater than `CURRENT_SCHEMA_VERSION`
- **THEN** it SHALL return `success=false` with `error_code=UNSUPPORTED_SCHEMA_VERSION`

#### Scenario: Current schema migration succeeds without changes
- **WHEN** `SaveManager.migrate_save_data(data)` receives data whose `schema_version` equals `CURRENT_SCHEMA_VERSION`
- **THEN** it SHALL return `success=true`
- **AND** return the original save data as the migrated data

### Requirement: Save slot metadata and listing
SaveManager SHALL expose metadata queries for save slots without requiring callers to apply the save.

#### Scenario: Existing valid slot metadata is returned
- **WHEN** `SaveManager.get_save_metadata(0)` is called for a valid save
- **THEN** it SHALL return metadata containing level, XP, gold, updated timestamp, summary, and auto-save flag when available

#### Scenario: All slots are listed
- **WHEN** `SaveManager.list_saves(true)` is called
- **THEN** it SHALL return entries for slots `0`, `1`, `2`, and `-1`
- **AND** nonexistent slots SHALL be represented with `exists=false`

#### Scenario: Corrupted save appears invalid in list
- **WHEN** `SaveManager.list_saves(true)` encounters a corrupted JSON save file
- **THEN** that slot entry SHALL have `exists=true`, `valid=false`, and a non-empty `error_code`

### Requirement: Save deletion
SaveManager SHALL delete manual or auto-save slot files without deleting backups by default.

#### Scenario: Existing save is deleted
- **WHEN** `SaveManager.delete_save(0)` is called for an existing save
- **THEN** it SHALL remove `user://saves/slot_0.json`
- **AND** return `success=true`

#### Scenario: Empty slot deletion succeeds
- **WHEN** `SaveManager.delete_save(0)` is called for a missing save file
- **THEN** it SHALL return `success=true`
- **AND** indicate that the slot was already empty

### Requirement: Auto-save slot
SaveManager SHALL support a dedicated auto-save slot independent from manual slots.

#### Scenario: Auto-save writes auto-save file
- **WHEN** `SaveManager.auto_save_now()` is called
- **THEN** it SHALL write `user://saves/auto_save.json`
- **AND** it SHALL NOT overwrite `slot_0.json`, `slot_1.json`, or `slot_2.json`

#### Scenario: Auto-save can be disabled
- **WHEN** `SaveManager.set_auto_save_enabled(false)` is called
- **THEN** timer-driven auto-save SHALL NOT write files until auto-save is re-enabled

### Requirement: Save operation result dictionaries
SaveManager SHALL return structured result dictionaries for persistence operations.

#### Scenario: Success result contains stable fields
- **WHEN** a save, load, or delete operation succeeds
- **THEN** the result SHALL contain `success`, `operation`, `slot`, `path`, `timestamp`, `metadata`, `message`, and `error_code`
- **AND** `success` SHALL be `true`
- **AND** `error_code` SHALL be an empty string

#### Scenario: Failure result contains stable error code
- **WHEN** a save, load, or delete operation fails
- **THEN** the result SHALL contain the same stable fields
- **AND** `success` SHALL be `false`
- **AND** `error_code` SHALL be a non-empty stable error code

### Requirement: SaveManager automated tests
The system SHALL include an automated SaveManager test scene and script.

#### Scenario: SaveManager test scene exists
- **WHEN** the project files are inspected
- **THEN** `res://scenes/test/test_save_manager.tscn` and `res://scenes/test/test_save_manager.gd` SHALL exist

#### Scenario: SaveManager tests cover core persistence
- **WHEN** the SaveManager test scene is run
- **THEN** it SHALL validate directory creation, path resolution, save, load, backup, deletion, listing, metadata, invalid slots, missing files, validation, migration, auto-save, manager state restoration, corrupted JSON handling, and save signals
