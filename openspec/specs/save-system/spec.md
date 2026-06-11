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

---

<!-- Synced from prd8-farm-grid-system -->

### Requirement: Farm grid save payload contract
FarmGridManager SHALL 提供可被 SaveManager 接入的 `farm_grid` 存档数据契约，且该数据必须完全 JSON 可序列化。

#### 场景:FarmGridManager 导出 farm_grid 数据
- **WHEN** `FarmGridManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary suitable for a save root field named `farm_grid`
- **AND** the Dictionary SHALL contain `schema_version`, `map_width`, `map_height`, `tile_size`, `farm_origin`, `unlocked_plot_count`, and `tiles`
- **AND** `farm_origin` SHALL be represented as a JSON object with `x` and `y` fields
- **AND** `tiles` SHALL use string coordinate keys such as `"5,5"`

#### 场景:Farm grid save data is JSON serializable
- **WHEN** farm grid data is exported for persistence
- **THEN** the payload SHALL contain only JSON-serializable values
- **AND** it SHALL NOT contain Node, Resource, Signal, Callable, or raw Vector2i values

#### 场景:Farm grid tile save fields
- **WHEN** an individual farm grid tile is exported
- **THEN** the tile payload SHALL include `terrain_type`, `plot_state`, `unlocked`, `occupied`, and `crop_tile_ref`
- **AND** missing optional runtime-only fields SHALL NOT prevent save serialization

### Requirement: Farm grid import compatibility
FarmGridManager SHALL 能够从 `farm_grid` 存档数据恢复地块状态，并兼容缺失、非法或旧版本数据。

#### 场景:缺少 farm_grid 时使用默认田园
- **WHEN** a loaded save does not contain `farm_grid` data or provides an empty farm grid payload
- **THEN** FarmGridManager SHALL initialize the default PRD8 grid
- **AND** the default grid SHALL contain 12 initially unlocked empty plots

#### 场景:导入 farm_grid 恢复地块状态
- **WHEN** `FarmGridManager.import_save_data(data)` receives valid farm grid data with a tile saved as `wet_soil`
- **THEN** the corresponding runtime tile SHALL be restored with `plot_state="wet_soil"`
- **AND** grid rendering state SHALL be refreshed after import

#### 场景:导入非法 farm_grid 坐标跳过
- **WHEN** imported farm grid data contains an invalid coordinate key or a coordinate outside the current map bounds
- **THEN** FarmGridManager SHALL skip that tile
- **AND** it SHALL continue importing other valid tiles
- **AND** it SHALL NOT crash the load process

#### 场景:导入缺失字段补默认值
- **WHEN** imported farm grid tile data is missing supported fields
- **THEN** FarmGridManager SHALL fill missing fields from the default tile data for that coordinate
- **AND** the import operation SHALL complete without crashing

### Requirement: SaveManager may persist farm_grid without breaking old saves
SaveManager SHALL allow 后续实现把 FarmGridManager 导出的数据挂载到保存根结构的 `farm_grid` 字段，且旧存档不得因缺少该字段而失效。

#### 场景:保存根结构可包含 farm_grid
- **WHEN** SaveManager integrates PRD8 farm grid persistence
- **THEN** the save root MAY include `farm_grid` populated from `FarmGridManager.export_save_data()`
- **AND** the save root SHALL remain JSON serializable

#### 场景:旧存档缺少 farm_grid 不失败
- **WHEN** SaveManager loads an older valid save without a `farm_grid` root field
- **THEN** validation SHALL NOT fail only because `farm_grid` is missing
- **AND** FarmGridManager SHALL be allowed to initialize default farm grid data

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

