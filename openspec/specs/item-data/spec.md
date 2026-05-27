# item-data Specification

## Purpose
This specification defines the item-data capability.

## Requirements

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


### Requirement: Item data provides economy buy price metadata

Shop purchase price lookup SHALL use item metadata and crop metadata without mutating loaded data.

#### Scenario: Direct item price is used for buyable item
- **WHEN** `EconomyManager.get_buy_price(item_id)` is called for an item whose type is `seed`, `consumable`, or `decoration`
- **AND** the item contains a positive `price` field
- **THEN** the method returns that `price`

#### Scenario: Seed buy price falls back to crop seed_price
- **WHEN** `EconomyManager.get_buy_price(item_id)` is called for a seed item without a positive `price` field
- **AND** the item contains `crop_id`
- **AND** `DataManager.get_crop(crop_id)` contains a positive `seed_price`
- **THEN** the method returns the crop `seed_price`

#### Scenario: Non-buyable item has no buy price
- **WHEN** `EconomyManager.get_buy_price(item_id)` is called for an item whose type is not `seed`, `consumable`, or `decoration`
- **THEN** the method returns `-1`

#### Scenario: Missing buy price returns invalid sentinel
- **WHEN** `EconomyManager.get_buy_price(item_id)` cannot find a positive item price or crop fallback price
- **THEN** the method returns `-1`

### Requirement: Item data provides economy sell price metadata

Sale price lookup SHALL use harvest item metadata and crop metadata without mutating loaded data.

#### Scenario: Direct harvest sell_price is used
- **WHEN** `EconomyManager.get_sell_price(item_id)` is called for a harvest item
- **AND** the item contains a positive `sell_price` field
- **THEN** the method returns that `sell_price`

#### Scenario: Harvest sell price falls back to crop sell_price
- **WHEN** `EconomyManager.get_sell_price(item_id)` is called for a harvest item without a positive `sell_price` field
- **AND** the item contains `crop_id`
- **AND** `DataManager.get_crop(crop_id)` contains a positive `sell_price`
- **THEN** the method returns the crop `sell_price`

#### Scenario: Non-harvest item has no sell price in PRD4
- **WHEN** `EconomyManager.get_sell_price(item_id)` is called for a non-harvest item
- **THEN** the method returns `-1`

#### Scenario: Missing sell price returns invalid sentinel
- **WHEN** `EconomyManager.get_sell_price(item_id)` cannot find a positive item sell price or crop fallback price
- **THEN** the method returns `-1`

### Requirement: Crop data provides seed shop source metadata

Seed shop item generation SHALL use `DataManager.get_all_crops()` and crop metadata to derive seed item ids, prices, names, and unlock levels.

#### Scenario: Seed shop item is generated from crop data
- **WHEN** `EconomyManager.get_seed_shop_items()` iterates a crop with id `carrot`
- **THEN** it creates a shop item for `seed_carrot`
- **AND** uses crop or item metadata for display name
- **AND** uses the buy price rules for `price`
- **AND** uses crop `unlock_level` for unlock checks

#### Scenario: Seed shop returns safe copies
- **WHEN** a caller mutates a Dictionary returned by `EconomyManager.get_seed_shop_items()`
- **THEN** stored crop metadata and item metadata loaded by `DataManager` remain unchanged

### Requirement: Economy price lookup preserves data immutability

Economy price lookup and shop list generation SHALL treat `DataManager` return values as read-only source data.

#### Scenario: Price lookup does not mutate item data
- **WHEN** `EconomyManager.get_buy_price()` or `EconomyManager.get_sell_price()` reads item metadata
- **THEN** no field is added to, removed from, or changed on the underlying loaded item table

#### Scenario: Shop list generation does not mutate crop data
- **WHEN** `EconomyManager.get_seed_shop_items()` or `EconomyManager.get_shop_items()` reads crop metadata
- **THEN** no field is added to, removed from, or changed on the underlying loaded crop table
