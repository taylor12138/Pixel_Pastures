## 1. SaveManager Foundation

- [x] 1.1 Replace the SaveManager placeholder with `pixel-farm/scripts/autoload/save_manager.gd` implementing constants for save directories, manual slot count, auto-save slot, and current schema version
- [x] 1.2 Implement slot validation and `get_save_path(slot)` for slots `0`, `1`, `2`, and `-1`
- [x] 1.3 Implement `initialize()` and `ensure_save_dirs()` to create `user://saves/` and `user://saves/backup/`
- [x] 1.4 Implement shared result dictionary helpers for success and failure responses with stable fields
- [x] 1.5 Register SaveManager in `pixel-farm/project.godot` after PRD1-5 gameplay managers and before AudioManager

## 2. Manager Save Integration

- [x] 2.1 Add or verify `GameManager.export_save_data()` and `GameManager.import_save_data(data)` for state, gold, level, XP, energy, max energy, stats, and last-online timestamp
- [x] 2.2 Verify `InventoryManager.export_save_data()` and `InventoryManager.import_save_data(data)` preserve slots and selected hotbar while normalizing malformed data
- [x] 2.3 Verify `CropManager.export_save_data()` and `CropManager.import_save_data(data)` use string coordinate keys and tolerate invalid tile data
- [x] 2.4 Verify `EconomyManager.export_save_data()` and `EconomyManager.import_save_data(data)` preserve and normalize transaction stats
- [x] 2.5 Add or verify `LevelManager.export_save_data()` and `LevelManager.import_save_data(data)` restore XP/level and recalculate unlocks

## 3. Save Data Construction and Validation

- [x] 3.1 Implement `build_save_data(slot)` with schema version, game version, timestamps, slot, metadata, game, inventory, crops, economy, level system, settings, and future fields
- [x] 3.2 Implement metadata generation with level, XP, gold, playtime, current scene, summary, updated timestamp, and auto-save flag
- [x] 3.3 Implement `validate_save_data(data)` for required root fields, type checks, schema bounds, and optional-field defaults
- [x] 3.4 Implement `migrate_save_data(data)` with current-schema pass-through, future-version rejection, and v0-to-v1 migration hook
- [x] 3.5 Ensure save payloads contain only JSON-serializable values and no Godot runtime objects

## 4. File Read/Write Operations

- [x] 4.1 Implement `read_save_file(slot)` with file existence, open, read, JSON parse, migration, and validation handling
- [x] 4.2 Implement `write_save_file(slot, data)` with temporary file write, verification readback, backup-before-overwrite, and target replacement
- [x] 4.3 Implement backup path generation and backup creation for manual and auto-save files
- [x] 4.4 Implement cleanup of failed temporary files without deleting existing valid saves
- [x] 4.5 Map file and JSON failures to stable error codes including `SAVE_NOT_FOUND`, `FILE_OPEN_FAILED`, `FILE_WRITE_FAILED`, `FILE_READ_FAILED`, `JSON_PARSE_FAILED`, and `BACKUP_FAILED`

## 5. Public SaveManager APIs

- [x] 5.1 Implement `save_game(slot)` to validate slot, build data, validate data, write file, emit success/failure signals, and return a result dictionary
- [x] 5.2 Implement `load_game(slot)` to read save data, apply it to managers, trigger crop offline compensation and level recalculation, emit success/failure signals, and return a result dictionary
- [x] 5.3 Implement `apply_save_data(data)` with deterministic manager import order and no mutation on pre-application validation failure
- [x] 5.4 Implement `has_save(slot)` to return true only for existing valid saves
- [x] 5.5 Implement `delete_save(slot)` preserving backups by default and emitting delete signals on successful deletion or empty-slot success
- [x] 5.6 Implement `get_save_metadata(slot)` and `list_saves(include_auto)` including invalid/corrupted slot summaries

## 6. Auto-save

- [x] 6.1 Implement `set_auto_save_enabled(enabled)` and `set_auto_save_interval(seconds)`
- [x] 6.2 Implement timer-driven auto-save in `_process(delta)` only while auto-save is enabled and the game is in playing state
- [x] 6.3 Implement `auto_save_now()` to save only to slot `-1` and never overwrite manual slots
- [x] 6.4 Emit `auto_save_completed(result)` and `auto_save_failed(result)` based on auto-save outcome
- [x] 6.5 Add close-request handling for best-effort auto-save on game exit if compatible with current project lifecycle

## 7. EventBus Signals

- [x] 7.1 Update `pixel-farm/scripts/autoload/event_bus.gd` with typed `game_saved(slot, metadata)` and `game_loaded(slot, metadata)` signals
- [x] 7.2 Add `game_save_failed(slot, error_code, message)` and `game_load_failed(slot, error_code, message)` signals
- [x] 7.3 Add `save_deleted(slot)`, `auto_save_completed(result)`, and `auto_save_failed(result)` signals
- [x] 7.4 Preserve compatibility with existing no-argument save/load signal usage if current code requires it

## 8. Debug and Test Support

- [x] 8.1 Add SaveManager debug helpers `debug_delete_all_saves()` and `debug_print_save_slots()`
- [x] 8.2 Create `pixel-farm/scenes/test/test_save_manager.tscn` with a simple test node and label
- [x] 8.3 Create `pixel-farm/scenes/test/test_save_manager.gd` covering directory creation, slot paths, save success, load success, backup overwrite, deletion, empty deletion, listing, metadata, and has-save behavior
- [x] 8.4 Add test coverage for invalid slots, missing files, corrupted JSON, validation failures, migration behavior, and unsupported future schema
- [x] 8.5 Add test coverage for inventory, crop, economy, and level state save/load round trips
- [x] 8.6 Add test coverage for save, load, delete, and auto-save EventBus signals

## 9. Verification

- [x] 9.1 Run the SaveManager test scene and confirm all tests pass without runtime errors
- [x] 9.2 Verify generated save JSON files contain the required PRD6 root fields and readable metadata
- [x] 9.3 Verify overwriting an existing slot creates the expected backup file
- [x] 9.4 Verify failed load from corrupted JSON leaves current runtime state unchanged
- [x] 9.5 Run relevant existing crop, inventory, economy, and level tests to confirm persistence changes do not regress PRD2-5 behavior
