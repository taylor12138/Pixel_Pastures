# game-state Specification

## MODIFIED Requirements

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
