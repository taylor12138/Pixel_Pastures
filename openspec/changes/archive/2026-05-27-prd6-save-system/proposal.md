## Why

PRD6 requires a stable local persistence layer so the already-completed data systems can survive application restarts and support the full loop of new game, state mutation, save, reset, load, and offline crop compensation. This change is needed now because PRD1-5 have established core runtime state but still lack a concrete SaveManager implementation to serialize and restore that state.

## What Changes

- Add a `SaveManager` Autoload that manages local JSON save files under `user://saves/`.
- Support 3 manual save slots plus 1 auto-save slot, including slot path resolution, existence checks, metadata listing, deletion, and overwrite backups.
- Define a versioned JSON save root structure with `schema_version`, metadata, game, inventory, crops, economy, level system, settings, and future-extension fields.
- Implement save/load result dictionaries with stable `success`, `operation`, `slot`, `path`, `timestamp`, `metadata`, `message`, and `error_code` fields.
- Add save data validation, unsupported future-version rejection, and a migration framework for older schemas.
- Integrate with `GameManager`, `CropManager`, `InventoryManager`, `EconomyManager`, and `LevelManager` through export/import save data interfaces.
- Add EventBus save/load/delete/auto-save success and failure signals.
- Add automated SaveManager test scene coverage for directories, slot paths, save/load, overwrite backup, deletion, listing, metadata, validation, migration, corrupted JSON handling, auto-save, manager state restoration, and signals.
- No storage UI, Steam Cloud, encryption, compression, screenshot thumbnails, or cloud conflict handling are included in this change.

## Capabilities

### New Capabilities

- `save-system`: Covers versioned local JSON save files, SaveManager APIs, manual and auto save slots, validation, migration, metadata listing, deletion, backups, manager state aggregation/restoration, error handling, and save-related tests.

### Modified Capabilities

- `event-bus`: Adds typed save/load/delete/auto-save success and failure signals required by SaveManager.
- `game-state`: Adds GameManager save export/import behavior for persistent core player state.
- `crop-state-machine`: Requires CropManager save export/import compatibility and post-load offline progression processing.
- `inventory-data`: Requires InventoryManager save export/import compatibility for inventory slots and selected hotbar.
- `shop-economy`: Requires EconomyManager save export/import compatibility for economy statistics.

## Impact

- Adds `pixel-farm/scripts/autoload/save_manager.gd` and registers it in `pixel-farm/project.godot` after existing gameplay managers.
- Modifies `pixel-farm/scripts/autoload/event_bus.gd` to expose save-related signals.
- Modifies or verifies save import/export APIs in:
  - `pixel-farm/scripts/autoload/game_manager.gd`
  - `pixel-farm/scripts/autoload/crop_manager.gd`
  - `pixel-farm/scripts/autoload/inventory_manager.gd`
  - `pixel-farm/scripts/autoload/economy_manager.gd`
  - `pixel-farm/scripts/autoload/level_manager.gd`
- Adds `pixel-farm/scenes/test/test_save_manager.tscn` and `pixel-farm/scenes/test/test_save_manager.gd` for automated validation.
- Creates local save files at runtime under Godot `user://saves/`, with backup files under `user://saves/backup/`.
- Establishes a file layout compatible with future save-management UI and Steam Cloud synchronization.