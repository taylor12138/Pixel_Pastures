# shop-economy Specification

## ADDED Requirements

### Requirement: EconomyManager Autoload singleton

`EconomyManager` SHALL be implemented as a global Autoload singleton at `res://scripts/autoload/economy_manager.gd`, loaded after `InventoryManager` and before `SceneManager`, and SHALL NOT use `class_name`.

#### Scenario: EconomyManager is available globally
- **WHEN** the Godot project starts
- **THEN** `EconomyManager` is available as an Autoload singleton
- **AND** systems can call `EconomyManager.buy_seed()` and `EconomyManager.sell_item()` without manual instantiation

#### Scenario: EconomyManager initializes stats
- **WHEN** `EconomyManager` enters the scene tree
- **THEN** it has zeroed economy stats for total spent gold, sale earnings, bought item count, sold item count, and transaction count

### Requirement: Economy transactions return structured results

All purchase and sale methods SHALL return a Dictionary with stable fields for UI, tests, and future analytics.

#### Scenario: Successful transaction result contains full context
- **WHEN** a purchase or sale succeeds
- **THEN** the result Dictionary contains `success`, `type`, `item_id`, `crop_id`, `quantity`, `unit_price`, `total_price`, `gold_before`, `gold_after`, `message`, and `error_code`
- **AND** `success` is `true`
- **AND** `error_code` is an empty string

#### Scenario: Failed transaction result contains error code
- **WHEN** a purchase or sale fails
- **THEN** the result Dictionary contains the same stable fields
- **AND** `success` is `false`
- **AND** `error_code` is one of `INVALID_ITEM`, `INVALID_CROP`, `INVALID_QUANTITY`, `NOT_SELLABLE`, `NOT_BUYABLE`, `NOT_ENOUGH_GOLD`, `NOT_ENOUGH_ITEMS`, `INVENTORY_FULL`, or `LOCKED`
- **AND** `gold_after` equals `gold_before`

### Requirement: Seed purchases spend gold and add seeds

`EconomyManager.buy_seed(crop_id: String, quantity: int = 1)` SHALL buy the seed item corresponding to a valid crop id.

#### Scenario: Buy seed succeeds
- **WHEN** `GameManager.gold` is `100`
- **AND** `InventoryManager` can accept at least `3` `seed_carrot`
- **AND** `GameManager.level` satisfies carrot unlock requirements
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
- **WHEN** a crop requires a higher unlock level than `GameManager.level`
- **AND** `EconomyManager.buy_seed(crop_id, 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `LOCKED`
- **AND** gold and inventory remain unchanged

### Requirement: General item purchases validate buyable item types

`EconomyManager.buy_item(item_id: String, quantity: int = 1)` SHALL support buyable item types for PRD4 and reject non-buyable items.

#### Scenario: Buy consumable succeeds
- **WHEN** a consumable item has a valid positive buy price
- **AND** the player has enough gold and inventory capacity
- **THEN** `EconomyManager.buy_item(item_id, quantity)` succeeds
- **AND** gold decreases by total price
- **AND** inventory increases by quantity

#### Scenario: Buy decoration succeeds
- **WHEN** a decoration item has a valid positive buy price
- **AND** the player has enough gold and inventory capacity
- **THEN** `EconomyManager.buy_item(item_id, quantity)` succeeds
- **AND** gold decreases by total price
- **AND** inventory increases by quantity

#### Scenario: Buy harvest is rejected
- **WHEN** `EconomyManager.buy_item("harvest_carrot", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `NOT_BUYABLE`
- **AND** no gold or inventory state changes

#### Scenario: Buy invalid quantity is rejected
- **WHEN** `EconomyManager.buy_item("seed_carrot", 0)` or `EconomyManager.buy_item("seed_carrot", -1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `INVALID_QUANTITY`
- **AND** no gold or inventory state changes

#### Scenario: Buy with insufficient gold is rejected
- **WHEN** the player has less gold than the total purchase price
- **AND** `EconomyManager.buy_item(item_id, quantity)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `NOT_ENOUGH_GOLD`
- **AND** no gold or inventory state changes

### Requirement: Harvest sales remove harvest items and add gold

`EconomyManager.sell_harvest(crop_id: String, quantity: int = 1)` SHALL sell the harvest item corresponding to a valid crop id.

#### Scenario: Sell harvest succeeds
- **WHEN** `GameManager.gold` is `0`
- **AND** inventory contains `2` `harvest_carrot`
- **AND** `EconomyManager.sell_harvest("carrot", 2)` is called
- **THEN** the result has `success=true`
- **AND** `GameManager.gold` becomes `50`
- **AND** `InventoryManager.get_item_count("harvest_carrot")` becomes `0`
- **AND** economy stats record `50` sale earnings and `2` sold items

#### Scenario: Sell harvest rejects invalid crop
- **WHEN** `EconomyManager.sell_harvest("missing_crop", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `INVALID_CROP`
- **AND** gold and inventory remain unchanged

#### Scenario: Sell harvest rejects insufficient inventory
- **WHEN** inventory contains fewer harvest items than requested
- **AND** `EconomyManager.sell_harvest(crop_id, quantity)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `NOT_ENOUGH_ITEMS`
- **AND** gold and inventory remain unchanged

### Requirement: General item sales validate sellable item types

`EconomyManager.sell_item(item_id: String, quantity: int = 1)` SHALL only allow harvest items to be sold in PRD4.

#### Scenario: Sell harvest item succeeds
- **WHEN** inventory contains enough of a valid harvest item
- **AND** that item has a valid sell price or crop sell price fallback
- **THEN** `EconomyManager.sell_item(item_id, quantity)` succeeds
- **AND** inventory decreases by quantity
- **AND** gold increases by total sell price

#### Scenario: Sell seed is rejected
- **WHEN** `EconomyManager.sell_item("seed_carrot", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `NOT_SELLABLE`
- **AND** gold and inventory remain unchanged

#### Scenario: Sell tool is rejected
- **WHEN** `EconomyManager.sell_item("watering_can", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `NOT_SELLABLE`
- **AND** gold and inventory remain unchanged

#### Scenario: Sell invalid item is rejected
- **WHEN** `EconomyManager.sell_item("missing_item", 1)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `INVALID_ITEM`
- **AND** gold and inventory remain unchanged

### Requirement: EconomyManager provides buy and sell validation helpers

`EconomyManager.can_buy_item()` and `EconomyManager.can_sell_item()` SHALL return structured results without applying side effects.

#### Scenario: can_buy_item reports successful validation without buying
- **WHEN** all purchase requirements are satisfied
- **AND** `EconomyManager.can_buy_item(item_id, quantity)` is called
- **THEN** the result has `success=true`
- **AND** gold and inventory remain unchanged

#### Scenario: can_sell_item reports failed validation without selling
- **WHEN** inventory lacks the requested item quantity
- **AND** `EconomyManager.can_sell_item(item_id, quantity)` is called
- **THEN** the result has `success=false`
- **AND** `error_code` is `NOT_ENOUGH_ITEMS`
- **AND** gold and inventory remain unchanged

### Requirement: EconomyManager provides price query interfaces

`EconomyManager` SHALL expose buy and sell price query APIs.

#### Scenario: Seed buy price is returned
- **WHEN** `EconomyManager.get_buy_price("seed_carrot")` is called
- **THEN** it returns `10`

#### Scenario: Harvest sell price is returned
- **WHEN** `EconomyManager.get_sell_price("harvest_carrot")` is called
- **THEN** it returns `25`

#### Scenario: Invalid or unsupported buy price returns -1
- **WHEN** `EconomyManager.get_buy_price()` is called for an invalid or non-buyable item
- **THEN** it returns `-1`

#### Scenario: Invalid or unsupported sell price returns -1
- **WHEN** `EconomyManager.get_sell_price()` is called for an invalid or non-sellable item
- **THEN** it returns `-1`

### Requirement: EconomyManager provides shop item lists

`EconomyManager` SHALL expose data-only shop list queries for future UI.

#### Scenario: Seed shop list contains all crop seeds
- **WHEN** `EconomyManager.get_seed_shop_items()` is called
- **THEN** it returns one seed shop item per crop from `DataManager.get_all_crops()`
- **AND** each entry includes `item_id`, `crop_id`, `name`, `type`, `price`, `unlocked`, `unlock_level`, `owned_count`, and `can_afford_one`

#### Scenario: Shop list includes PRD4 buyable categories
- **WHEN** `EconomyManager.get_shop_items()` is called
- **THEN** it includes seed shop items
- **AND** it includes consumable items with valid positive buy prices
- **AND** it includes decoration items with valid positive buy prices
- **AND** it excludes harvest items

#### Scenario: Shop item info returns a safe data copy
- **WHEN** `EconomyManager.get_shop_item_info("seed_carrot")` is called
- **THEN** it returns display and transaction data for the item
- **AND** mutating the returned Dictionary does not mutate `DataManager` source data

### Requirement: EconomyManager provides sellable inventory list

`EconomyManager.get_sellable_inventory_items()` SHALL return only inventory items that are sellable in PRD4.

#### Scenario: Sellable inventory list aggregates harvest items
- **WHEN** inventory contains harvest items across one or more slots
- **THEN** `get_sellable_inventory_items()` returns an entry per sellable item id
- **AND** each entry includes `item_id`, `name`, `quantity`, `unit_price`, `total_price`, and `slot_indexes`

#### Scenario: Sellable inventory list excludes non-sellable items
- **WHEN** inventory contains seeds, tools, consumables, or decorations
- **THEN** those non-harvest items are excluded from `get_sellable_inventory_items()`

### Requirement: EconomyManager maintains transaction stats

`EconomyManager` SHALL maintain saveable transaction stats for spent gold, sale earnings, bought item count, sold item count, and total successful transactions.

#### Scenario: Successful purchase updates stats
- **WHEN** a purchase succeeds
- **THEN** `total_gold_spent` increases by total price
- **AND** `total_items_bought` increases by quantity
- **AND** `total_transactions` increases by `1`

#### Scenario: Successful sale updates stats
- **WHEN** a sale succeeds
- **THEN** `total_gold_earned_from_sales` increases by total price
- **AND** `total_items_sold` increases by quantity
- **AND** `total_transactions` increases by `1`

#### Scenario: Failed transaction does not update stats
- **WHEN** a transaction fails
- **THEN** economy stats remain unchanged

#### Scenario: Economy stats export and import round trip
- **WHEN** `EconomyManager.export_save_data()` is called
- **THEN** it returns a serializable Dictionary containing economy stats
- **WHEN** `EconomyManager.import_save_data(data)` receives that Dictionary
- **THEN** stats are restored to the exported values
