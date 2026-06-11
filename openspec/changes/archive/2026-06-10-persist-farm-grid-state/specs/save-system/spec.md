## MODIFIED Requirements

### Requirement: Versioned JSON save structure
SaveManager SHALL serialize saves as JSON dictionaries with a stable root schema that includes PRD1-10 runtime data, writes current farm grid state when available, and keeps older saves without farm grid or time data compatible.

#### Scenario: Save root contains current fields
- **WHEN** `SaveManager.build_save_data(slot)` is called
- **THEN** the returned Dictionary SHALL contain `schema_version`, `game_version`, `created_at`, `updated_at`, `slot`, `metadata`, `game`, `time`, `inventory`, `crops`, `farm_grid`, `economy`, `level_system`, `settings`, and `future`

#### Scenario: Save root is JSON serializable
- **WHEN** SaveManager writes a save file
- **THEN** the save payload SHALL contain only JSON-serializable values
- **AND** coordinates SHALL be represented with string keys such as `"x,y"` instead of Vector2i objects
- **AND** the `time` field SHALL contain only JSON-serializable values exported by `TimeManager.export_save_data()`
- **AND** the `farm_grid` field SHALL contain only JSON-serializable values exported by the registered FarmGridManager or retained in the farm grid cache

#### Scenario: Saving outside the farm preserves loaded grid data
- **WHEN** a valid save with `farm_grid` has been loaded
- **AND** no FarmGridManager scene node is currently registered
- **THEN** `SaveManager.build_save_data(slot)` SHALL write the cached loaded `farm_grid`
- **AND** it SHALL NOT replace that data with an empty or default grid

### Requirement: Manual save writes current runtime state
SaveManager SHALL save the current runtime state into a selected manual slot, including TimeManager data and the active or cached FarmGridManager data when available.

#### Scenario: Manual save succeeds
- **WHEN** `SaveManager.save_game(0)` is called with valid manager state
- **THEN** it SHALL write a valid JSON file to `user://saves/slot_0.json`
- **AND** the result Dictionary SHALL have `success=true`, `operation="save"`, and `slot=0`

#### Scenario: Save includes manager data
- **WHEN** a save succeeds
- **THEN** the JSON file SHALL include data exported from GameManager, TimeManager, InventoryManager, CropManager, EconomyManager, and LevelManager
- **AND** it SHALL include `farm_grid` from the active FarmGridManager when registered
- **AND** otherwise it SHALL include the last valid cached farm grid payload

#### Scenario: Save failure preserves previous save
- **WHEN** writing a save file fails after an older save already exists
- **THEN** SaveManager SHALL preserve the older save file
- **AND** return `success=false` with a stable error code

### Requirement: Load restores saved runtime state
SaveManager SHALL load a valid save file and restore PRD1-10 manager state while remaining compatible with saves that do not contain time or farm grid data.

#### Scenario: Load succeeds with registered farm grid
- **WHEN** `SaveManager.load_game(0)` reads a valid save containing `farm_grid`
- **AND** a valid FarmGridManager is registered
- **THEN** it SHALL restore GameManager core state, TimeManager state, InventoryManager slots and hotbar, CropManager tiles, FarmGridManager tiles, EconomyManager stats, and LevelManager progress
- **AND** return `success=true`, `operation="load"`, and `slot=0`

#### Scenario: Load caches farm grid until scene registration
- **WHEN** a valid save containing `farm_grid` is loaded while no FarmGridManager is registered
- **THEN** SaveManager SHALL retain the farm grid payload
- **AND** it SHALL apply that payload when a valid FarmGridManager later registers

#### Scenario: Load missing time data remains compatible
- **WHEN** `SaveManager.load_game(0)` reads a valid older save without a `time` field
- **THEN** loading SHALL still succeed
- **AND** `TimeManager.initialize_new_game()` SHALL be used when `TimeManager` is available
- **AND** the save SHALL NOT be rejected only because `time` is missing

#### Scenario: Load missing farm grid remains compatible
- **WHEN** `SaveManager.load_game(0)` reads a valid older save without a `farm_grid` field
- **THEN** loading SHALL still succeed
- **AND** the next FarmGridManager registration SHALL initialize the default farm grid
- **AND** the save SHALL NOT be rejected only because `farm_grid` is missing

#### Scenario: Load triggers post-load reconciliation
- **WHEN** `SaveManager.load_game(0)` succeeds
- **THEN** it SHALL trigger crop offline compensation using the saved last-online timestamp
- **AND** it SHALL trigger level consistency recalculation
- **AND** an active farm scene SHALL reconcile FarmGridManager occupancy with CropManager after grid restoration

#### Scenario: Failed load does not mutate runtime state
- **WHEN** `SaveManager.load_game(0)` fails because the file is missing, invalid JSON, invalid schema, unsupported schema, or failed migration
- **THEN** current runtime game state SHALL remain unchanged
- **AND** the cached farm grid state SHALL remain unchanged

### Requirement: Save validation and migration
SaveManager SHALL validate save data and provide a migration framework for older schemas, treating `time` and `farm_grid` as optional compatibility fields.

#### Scenario: Valid save passes validation
- **WHEN** `SaveManager.validate_save_data(data)` receives a current-schema save with required root fields
- **THEN** it SHALL return `success=true`

#### Scenario: Missing required root fails validation
- **WHEN** validation receives data missing `metadata`, `game`, `inventory`, `crops`, `economy`, or `level_system`
- **THEN** it SHALL return `success=false` with `error_code=INVALID_SAVE_DATA`

#### Scenario: Missing compatibility roots remain valid
- **WHEN** validation receives otherwise valid data without `time`, without `farm_grid`, or without both
- **THEN** validation SHALL NOT fail only because those fields are missing

#### Scenario: Future schema is rejected
- **WHEN** validation or migration receives a save whose `schema_version` is greater than `CURRENT_SCHEMA_VERSION`
- **THEN** it SHALL return `success=false` with `error_code=UNSUPPORTED_SCHEMA_VERSION`

#### Scenario: Current schema migration succeeds without changes
- **WHEN** `SaveManager.migrate_save_data(data)` receives data whose `schema_version` equals `CURRENT_SCHEMA_VERSION`
- **THEN** it SHALL return `success=true`
- **AND** return the original save data as the migrated data

## ADDED Requirements

### Requirement: Scene farm grid provider lifecycle
SaveManager SHALL support registering and unregistering the active scene-owned FarmGridManager without making it an Autoload.

#### Scenario: Registering a provider applies pending grid data
- **WHEN** a valid FarmGridManager registers after SaveManager has cached loaded `farm_grid`
- **THEN** SaveManager SHALL call the provider's import interface with that payload
- **AND** it SHALL report that saved grid state was restored

#### Scenario: Registering without pending data does not initialize the grid
- **WHEN** a FarmGridManager registers and no valid cached farm grid exists
- **THEN** SaveManager SHALL report that no saved grid state was restored
- **AND** the farm scene SHALL remain responsible for default grid initialization

#### Scenario: Unregistering caches latest state
- **WHEN** the active FarmGridManager unregisters while still valid
- **THEN** SaveManager SHALL export and cache its latest grid state
- **AND** subsequent saves outside the farm scene SHALL preserve that state

#### Scenario: Invalid provider is ignored safely
- **WHEN** the registered provider has been freed or lacks the required import or export method
- **THEN** SaveManager SHALL ignore the invalid provider safely
- **AND** save or load SHALL NOT crash
