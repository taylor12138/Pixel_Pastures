## MODIFIED Requirements

### Requirement: Versioned JSON save structure
SaveManager SHALL serialize saves as JSON dictionaries with a stable root schema that includes PRD1-7 runtime data and keeps `time` compatible with older saves.

#### Scenario: Save root contains required fields
- **WHEN** `SaveManager.build_save_data(slot)` is called
- **THEN** the returned Dictionary SHALL contain `schema_version`, `game_version`, `created_at`, `updated_at`, `slot`, `metadata`, `game`, `time`, `inventory`, `crops`, `economy`, `level_system`, `settings`, and `future`

#### Scenario: Save root is JSON serializable
- **WHEN** SaveManager writes a save file
- **THEN** the save payload SHALL contain only JSON-serializable values
- **AND** coordinates SHALL be represented with string keys such as `"x,y"` instead of Vector2i objects
- **AND** the `time` field SHALL contain only JSON-serializable values exported by `TimeManager.export_save_data()`

### Requirement: Manual save writes current runtime state
SaveManager SHALL save the current runtime state into a selected manual slot, including TimeManager data when available.

#### Scenario: Manual save succeeds
- **WHEN** `SaveManager.save_game(0)` is called with valid manager state
- **THEN** it SHALL write a valid JSON file to `user://saves/slot_0.json`
- **AND** the result Dictionary SHALL have `success=true`, `operation="save"`, and `slot=0`

#### Scenario: Save includes manager data
- **WHEN** a save succeeds
- **THEN** the JSON file SHALL include data exported from GameManager, TimeManager, InventoryManager, CropManager, EconomyManager, and LevelManager

#### Scenario: Save failure preserves previous save
- **WHEN** writing a save file fails after an older save already exists
- **THEN** SaveManager SHALL preserve the older save file
- **AND** return `success=false` with a stable error code

### Requirement: Load restores saved runtime state
SaveManager SHALL load a valid save file and restore PRD1-7 manager state while remaining compatible with saves that do not contain time data.

#### Scenario: Load succeeds
- **WHEN** `SaveManager.load_game(0)` reads a valid `slot_0.json`
- **THEN** it SHALL restore GameManager core state, TimeManager state, InventoryManager slots and hotbar, CropManager tiles, EconomyManager stats, and LevelManager progress
- **AND** return `success=true`, `operation="load"`, and `slot=0`

#### Scenario: Load missing time data remains compatible
- **WHEN** `SaveManager.load_game(0)` reads a valid older save without a `time` field
- **THEN** loading SHALL still succeed
- **AND** `TimeManager.initialize_new_game()` SHALL be used when `TimeManager` is available
- **AND** the save SHALL NOT be rejected only because `time` is missing

#### Scenario: Load triggers post-load reconciliation
- **WHEN** `SaveManager.load_game(0)` succeeds
- **THEN** it SHALL trigger crop offline compensation using the saved last-online timestamp
- **AND** it SHALL trigger level consistency recalculation

#### Scenario: Failed load does not mutate runtime state
- **WHEN** `SaveManager.load_game(0)` fails because the file is missing, invalid JSON, invalid schema, unsupported schema, or failed migration
- **THEN** current runtime game state SHALL remain unchanged

### Requirement: Save validation and migration
SaveManager SHALL validate save data and provide a migration framework for older schemas, treating `time` as optional for PRD6 compatibility.

#### Scenario: Valid save passes validation
- **WHEN** `SaveManager.validate_save_data(data)` receives a current-schema save with required root fields
- **THEN** it SHALL return `success=true`

#### Scenario: Missing required root fails validation
- **WHEN** validation receives data missing `metadata`, `game`, `inventory`, `crops`, `economy`, or `level_system`
- **THEN** it SHALL return `success=false` with `error_code=INVALID_SAVE_DATA`

#### Scenario: Missing time root is compatible
- **WHEN** validation receives otherwise valid PRD6-era data without `time`
- **THEN** validation SHALL NOT fail only because `time` is missing

#### Scenario: Future schema is rejected
- **WHEN** validation or migration receives a save whose `schema_version` is greater than `CURRENT_SCHEMA_VERSION`
- **THEN** it SHALL return `success=false` with `error_code=UNSUPPORTED_SCHEMA_VERSION`

#### Scenario: Current schema migration succeeds without changes
- **WHEN** `SaveManager.migrate_save_data(data)` receives data whose `schema_version` equals `CURRENT_SCHEMA_VERSION`
- **THEN** it SHALL return `success=true`
- **AND** return the original save data as the migrated data

### Requirement: Save slot metadata and listing
SaveManager SHALL expose metadata queries for save slots without requiring callers to apply the save, including time summary fields when available.

#### Scenario: Existing valid slot metadata is returned
- **WHEN** `SaveManager.get_save_metadata(0)` is called for a valid save
- **THEN** it SHALL return metadata containing level, XP, gold, updated timestamp, summary, and auto-save flag when available
- **AND** metadata SHALL include `date_text`, `time_text`, `season`, and `day` when time data is available

#### Scenario: All slots are listed
- **WHEN** `SaveManager.list_saves(true)` is called
- **THEN** it SHALL return entries for slots `0`, `1`, `2`, and `-1`
- **AND** nonexistent slots SHALL be represented with `exists=false`

#### Scenario: Corrupted save appears invalid in list
- **WHEN** `SaveManager.list_saves(true)` encounters a corrupted JSON save file
- **THEN** that slot entry SHALL have `exists=true`, `valid=false`, and a non-empty `error_code`
