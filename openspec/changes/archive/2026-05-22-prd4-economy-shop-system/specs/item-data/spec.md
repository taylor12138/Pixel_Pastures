# item-data Specification

## MODIFIED Requirements

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
