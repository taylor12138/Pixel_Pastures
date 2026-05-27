## MODIFIED Requirements

### Requirement: Seed purchases spend gold and add seeds
`EconomyManager.buy_seed(crop_id: String, quantity: int = 1)` SHALL buy the seed item corresponding to a valid crop id and SHALL use LevelManager for crop unlock validation when available.

#### Scenario: Buy seed succeeds
- **WHEN** `GameManager.gold` is `100`
- **AND** `InventoryManager` can accept at least `3` `seed_carrot`
- **AND** `LevelManager.is_crop_unlocked("carrot")` returns `true` when LevelManager is available
- **AND** `EconomyManager.buy_seed("carrot", 3)` is called
- **THEN** the result has `success=true`
- **AND** `GameManager.gold` becomes `70`
- **AND** `InventoryManager.get_item_count("seed_carrot")` increases by `3`
- **AND** economy stats record `30` spent gold and `3` bought items

#### Scenario: Buy seed rejects invalid crop
- **WHEN** `EconomyManager.buy_seed("missing_crop", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `INVALID_CROP`
- **AND** gold and inventory remain unchanged

#### Scenario: Buy seed rejects locked crop
- **WHEN** `LevelManager` is available and `LevelManager.is_crop_unlocked(crop_id)` returns `false`
- **AND** `EconomyManager.buy_seed(crop_id, 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `LOCKED`
- **AND** gold and inventory remain unchanged

#### Scenario: Buy seed uses legacy unlock fallback without LevelManager
- **WHEN** `LevelManager` is not available
- **AND** a crop requires a higher unlock level than `GameManager.level`
- **AND** `EconomyManager.buy_seed(crop_id, 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `LOCKED`

### Requirement: Harvest sales remove harvest items, add gold, and grant XP
`EconomyManager.sell_harvest(crop_id: String, quantity: int = 1)` SHALL sell the harvest item corresponding to a valid crop id and SHALL grant sell XP through LevelManager after successful sale when available.

#### Scenario: Sell harvest succeeds
- **WHEN** `GameManager.gold` is `0`
- **AND** inventory contains `2` `harvest_carrot`
- **AND** `EconomyManager.sell_harvest("carrot", 2)` is called
- **THEN** the result has `success=true`
- **AND** `GameManager.gold` becomes `50`
- **AND** `InventoryManager.get_item_count("harvest_carrot")` becomes `0`
- **AND** economy stats record `50` sale earnings and `2` sold items

#### Scenario: Sell harvest grants XP after success
- **WHEN** `EconomyManager.sell_harvest("carrot", 2)` succeeds for total price `50`
- **AND** `LevelManager` is available
- **THEN** `EconomyManager` SHALL call `LevelManager.grant_xp("sell", {"item_id": "harvest_carrot", "quantity": 2, "total_price": 50})`
- **AND** the player SHALL receive `25` XP through centralized XP rules

#### Scenario: Sell harvest does not grant XP on failure
- **WHEN** `EconomyManager.sell_harvest(crop_id, quantity)` fails validation or rollback
- **THEN** no sell XP SHALL be granted

### Requirement: General item sales validate sellable item types
`EconomyManager.sell_item(item_id: String, quantity: int = 1)` SHALL only allow harvest items to be sold in PRD4 and SHALL grant sell XP through LevelManager after successful harvest-item sale when available.

#### Scenario: Sell harvest item succeeds
- **WHEN** inventory contains enough of a valid harvest item
- **AND** that item has a valid sell price or crop sell price fallback
- **THEN** `EconomyManager.sell_item(item_id, quantity)` succeeds
- **AND** inventory decreases by quantity
- **AND** gold increases by total sell price
- **AND** sell XP is granted through `LevelManager.grant_xp("sell", context)` when LevelManager is available

#### Scenario: Sell seed is rejected
- **WHEN** `EconomyManager.sell_item("seed_carrot", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `NOT_SELLABLE`
- **AND** gold and inventory remain unchanged
- **AND** no XP is granted

#### Scenario: Sell invalid item is rejected
- **WHEN** `EconomyManager.sell_item("missing_item", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `INVALID_ITEM`
- **AND** gold and inventory remain unchanged
- **AND** no XP is granted

### Requirement: EconomyManager provides shop item lists
`EconomyManager` SHALL expose data-only shop list queries for future UI and SHALL use LevelManager crop unlock queries when available.

#### Scenario: Seed shop list contains all crop seeds
- **WHEN** `EconomyManager.get_seed_shop_items()` is called
- **THEN** it returns one seed shop item per crop from `DataManager.get_all_crops()`
- **AND** each entry includes `item_id`, `crop_id`, `name`, `type`, `price`, `unlocked`, `unlock_level`, `owned_count`, and `can_afford_one`
- **AND** `unlocked` SHALL equal `LevelManager.is_crop_unlocked(crop_id)` when LevelManager is available

#### Scenario: Shop list includes PRD4 buyable categories
- **WHEN** `EconomyManager.get_shop_items()` is called
- **THEN** it includes seed shop items
- **AND** it includes consumable items with valid positive buy prices
- **AND** it includes decoration items with valid positive buy prices
- **AND** it excludes harvest items
