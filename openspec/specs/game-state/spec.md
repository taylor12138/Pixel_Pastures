# game-state Specification

## Purpose
This specification defines the game-state capability.

## Requirements

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
GameManager SHALL maintain player XP and level runtime values with initial level `1` and XP `0`; `LevelManager` SHALL be the business authority for XP addition, level checks, and unlock queries.

#### Scenario: Initial level and XP
- **WHEN** a new game is started
- **THEN** `GameManager.level` SHALL equal `1`
- **AND** `GameManager.xp` SHALL equal `0`

#### Scenario: GameManager delegates XP gain when LevelManager exists
- **WHEN** `GameManager.add_xp(amount, source)` is called and `LevelManager` is available
- **THEN** `GameManager` SHALL delegate the operation to `LevelManager.add_xp(amount, source)`
- **AND** `GameManager` SHALL NOT run duplicate level-up logic for the same operation

#### Scenario: GameManager legacy XP fallback remains available
- **WHEN** `GameManager.add_xp(amount, source)` is called and `LevelManager` is not available
- **THEN** `GameManager` SHALL preserve a fallback behavior that can add XP without crashing

### Requirement: Player energy system
GameManager SHALL maintain `player_energy` (initial: 100) and `player_max_energy` (initial: 100) properties.

#### Scenario: Initial energy values
- **WHEN** a new game is started
- **THEN** `GameManager.player_energy` SHALL equal `100` and `GameManager.player_max_energy` SHALL equal `100`

### Requirement: Reset to default
GameManager SHALL provide a `reset_to_default()` method that resets all player properties to their initial values, including XP and level values consumed by LevelManager.

#### Scenario: Reset restores all defaults
- **WHEN** `GameManager.reset_to_default()` is called after player data has been modified
- **THEN** `GameManager.gold` or `player_gold` SHALL be reset to its configured starting value
- **AND** `GameManager.level` SHALL be `1`
- **AND** `GameManager.xp` SHALL be `0`
- **AND** player energy SHALL be reset to its configured starting value

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

### Requirement: AudioManager placeholder
AudioManager SHALL exist as a registered Autoload with placeholder methods `play_bgm()`, `play_sfx()`, and `stop_bgm()` that emit warnings.

#### Scenario: Play BGM placeholder
- **WHEN** `AudioManager.play_bgm("bgm_morning")` is called
- **THEN** a warning "AudioManager: 尚未实现 (PRD19)" SHALL be printed and no crash SHALL occur

#### Scenario: Play SFX placeholder
- **WHEN** `AudioManager.play_sfx("sfx_plant")` is called
- **THEN** a warning "AudioManager: 尚未实现 (PRD19)" SHALL be printed and no crash SHALL occur

### Requirement: Autoload registration in project.godot
All core Autoloads SHALL be registered in the `[autoload]` section of project.godot in dependency-safe load order including SaveManager after the PRD1-5 gameplay managers.

#### Scenario: All autoloads accessible
- **WHEN** any game script runs
- **THEN** `EventBus`, `DataManager`, `GameManager`, `CropManager`, `InventoryManager`, `EconomyManager`, `LevelManager`, `SceneManager`, `SaveManager`, and `AudioManager` SHALL all be accessible as global singletons when their scripts exist in the project

#### Scenario: Load order is correct
- **WHEN** project.godot `[autoload]` section is inspected
- **THEN** the order SHALL place `SaveManager` after `EventBus`, `DataManager`, `GameManager`, `CropManager`, `InventoryManager`, `EconomyManager`, `LevelManager`, and `SceneManager`
- **AND** it SHALL place `SaveManager` before `AudioManager`

### Requirement: Initialization logging
Each Autoload SHALL print a confirmation log message in `_ready()` to verify successful initialization.

#### Scenario: Console shows all init logs
- **WHEN** the game launches
- **THEN** the console SHALL display initialization messages from all 5 Autoloads confirming they are ready

---

<!-- Synced from prd3-inventory-system -->

### Requirement: InventoryManager is the runtime authority for item state

`InventoryManager` SHALL be the authoritative runtime owner of inventory slot data. `GameManager.inventory` SHALL remain as a compatibility summary dictionary maintained by `InventoryManager`.

#### Scenario: Inventory changes update GameManager compatibility summary
- **WHEN** `InventoryManager` adds, removes, discards, moves, merges, or imports items
- **THEN** it synchronizes `GameManager.inventory` to a dictionary of `item_id -> total_quantity`
- **AND** the summary contains no entries for zero-quantity items

#### Scenario: Legacy item queries remain compatible
- **WHEN** existing systems query `GameManager.inventory` after inventory changes
- **THEN** they observe totals matching `InventoryManager.get_item_count(item_id)`

### Requirement: Inventory save data supports slot restoration

`InventoryManager` SHALL export and import serializable save data that preserves slot order and selected hotbar state.

#### Scenario: Export inventory save data
- **WHEN** `InventoryManager.export_save_data()` is called
- **THEN** it returns a dictionary containing `slots` and `selected_hotbar`
- **AND** `slots` is a deep duplicate of the 20-slot inventory array

#### Scenario: Import inventory save data
- **WHEN** `InventoryManager.import_save_data(data)` receives save data with `slots` and `selected_hotbar`
- **THEN** it restores slot order
- **AND** clamps or resets selected hotbar to a valid index from 0 to 8
- **AND** ensures slot array length is exactly 20
- **AND** synchronizes `GameManager.inventory`

#### Scenario: Import legacy inventory dictionary
- **WHEN** only legacy `GameManager.inventory` dictionary data is available
- **THEN** `InventoryManager` can initialize slots from that dictionary using normal stack rules
- **AND** item totals are preserved as much as inventory capacity allows

### Requirement: Crop operations use InventoryManager for item changes

`CropManager` SHALL use `InventoryManager` for seed consumption and harvest item insertion instead of mutating `GameManager.inventory` directly.

#### Scenario: Plant crop consumes seed through InventoryManager
- **WHEN** `CropManager.plant_crop(tile_pos, crop_id)` succeeds
- **THEN** it removes one `seed_<crop_id>` through `InventoryManager.remove_item()`
- **AND** inventory slots and `GameManager.inventory` remain synchronized

#### Scenario: Harvest crop adds harvest item through InventoryManager
- **WHEN** `CropManager.harvest_crop(tile_pos)` succeeds
- **THEN** it adds one `harvest_<crop_id>` through `InventoryManager.add_item()`
- **AND** inventory slots and `GameManager.inventory` remain synchronized

### Requirement: GameManager remains the gold authority while EconomyManager is the transaction authority

`GameManager.gold` SHALL remain the authoritative runtime value for player gold. `EconomyManager` SHALL be the only PRD4 transaction entry point for shop purchases and item sales, and SHALL change gold by calling `GameManager.add_gold()` and `GameManager.spend_gold()` instead of directly mutating `GameManager.gold` outside test setup.

#### Scenario: Purchase spends gold through GameManager
- **WHEN** `EconomyManager.buy_item(item_id, quantity)` succeeds
- **THEN** it calls `GameManager.spend_gold(total_price)` to reduce gold
- **AND** `GameManager.gold` decreases by `total_price`
- **AND** `EventBus.gold_changed(new_amount, delta)` is emitted by `GameManager`

#### Scenario: Sale earns gold through GameManager
- **WHEN** `EconomyManager.sell_item(item_id, quantity)` succeeds
- **THEN** it calls `GameManager.add_gold(total_price, "sell")` to increase gold
- **AND** `GameManager.gold` increases by `total_price`
- **AND** `GameManager.stats.total_gold_earned` increases through existing `GameManager` logic

#### Scenario: Failed transaction does not mutate gold
- **WHEN** `EconomyManager` returns a failed transaction result
- **THEN** `GameManager.gold` remains equal to the result's `gold_before`
- **AND** no successful purchase or sale side-effect remains applied

### Requirement: EconomyManager is registered in Autoload order

The Godot project SHALL register `EconomyManager` as an Autoload singleton after `InventoryManager` and before `SceneManager`.

#### Scenario: Project starts with EconomyManager available
- **WHEN** the Godot project loads Autoload singletons
- **THEN** `EconomyManager` is available globally after `EventBus`, `DataManager`, `GameManager`, `CropManager`, and `InventoryManager`
- **AND** systems can call `EconomyManager.buy_seed()` without manually instantiating it
- **AND** `EconomyManager` does not use `class_name`

### Requirement: Game save data preserves level system data when available
GameManager SHALL include LevelManager save data in its save payload when the `LevelManager` Autoload exists, and SHALL restore it during load when level-system data is present.

#### Scenario: Save includes level system data
- **WHEN** `GameManager.save_game()` is called and `LevelManager` is available
- **THEN** the serialized save data SHALL contain a `level_system` field
- **AND** that field SHALL equal `LevelManager.export_save_data()`

#### Scenario: Load restores level system data
- **WHEN** `GameManager.load_game()` reads save data containing a `level_system` field
- **AND** `LevelManager` is available
- **THEN** it SHALL call `LevelManager.import_save_data(level_system_data)`
- **AND** XP and level consistency SHALL be restored through `LevelManager.recalculate_level()`

#### Scenario: Legacy save without level system data remains compatible
- **WHEN** `GameManager.load_game()` reads a save file without a `level_system` field
- **THEN** loading SHALL still succeed
- **AND** `GameManager.xp` and `GameManager.level` root fields SHALL remain compatible with existing save behavior

---

<!-- Synced from prd6-save-system -->

### Requirement: GameManager save export and import
GameManager SHALL expose serializable save export and import behavior for player core state used by SaveManager.

#### Scenario: GameManager exports core state
- **WHEN** `GameManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary containing game state, gold, level, XP, energy, max energy, stats, and last-online timestamp

#### Scenario: GameManager imports core state
- **WHEN** `GameManager.import_save_data(data)` receives saved core state
- **THEN** it SHALL restore gold, level, XP, energy, max energy, and stats
- **AND** it SHALL set runtime state to playing after a successful load
