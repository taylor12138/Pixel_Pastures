# item-data Specification

## MODIFIED Requirements

### Requirement: Item metadata supports inventory stack rules

Every item in `data/items.json` SHALL include stack metadata used by `InventoryManager`: `stackable: bool` and `max_stack: int`.

#### Scenario: Existing items have stack metadata
- **WHEN** `DataManager` loads `data/items.json`
- **THEN** existing items `watering_can`, `fertilizer`, `fence_wood`, `scarecrow`, and `stone_path` include `stackable` and `max_stack`
- **AND** `watering_can` has `stackable=false` and `max_stack=1`
- **AND** the other existing stackable items have `stackable=true` and `max_stack=99`

### Requirement: Seed item data is complete

`data/items.json` SHALL define seed item entries for all PRD3 crop seeds with type `seed`, crop linkage, `stackable=true`, and `max_stack=99`.

#### Scenario: Seed entries can be queried
- **WHEN** `DataManager.get_item("seed_carrot")`, `seed_tomato`, `seed_cabbage`, `seed_corn`, `seed_potato`, `seed_strawberry`, `seed_pepper`, `seed_pumpkin`, `seed_eggplant`, and `seed_broccoli` are queried
- **THEN** each call returns non-empty item data
- **AND** each item has `type="seed"`
- **AND** each item has a `crop_id` matching its crop
- **AND** each item has `stackable=true` and `max_stack=99`

### Requirement: Harvest item data is complete

`data/items.json` SHALL define harvest item entries for all PRD3 crop harvests with type `harvest`, sell price, `stackable=true`, and `max_stack=99`.

#### Scenario: Harvest entries can be queried
- **WHEN** `DataManager.get_item("harvest_carrot")`, `harvest_tomato`, `harvest_cabbage`, `harvest_corn`, `harvest_potato`, `harvest_strawberry`, `harvest_pepper`, `harvest_pumpkin`, `harvest_eggplant`, and `harvest_broccoli` are queried
- **THEN** each call returns non-empty item data
- **AND** each item has `type="harvest"`
- **AND** each item has a positive `sell_price`
- **AND** each item has `stackable=true` and `max_stack=99`

### Requirement: Item data remains read-only to consumers

Item metadata returned by `DataManager.get_item()` SHALL be safe for consumers to read without mutating the stored JSON data.

#### Scenario: Caller mutates returned item data
- **WHEN** a caller retrieves an item with `DataManager.get_item(item_id)` and mutates the returned dictionary
- **THEN** a later call to `DataManager.get_item(item_id)` returns the original stored metadata
