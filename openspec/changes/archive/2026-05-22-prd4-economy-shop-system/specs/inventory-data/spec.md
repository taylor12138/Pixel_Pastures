# inventory-data Specification

## MODIFIED Requirements

### Requirement: Economy transactions use InventoryManager as item authority

`EconomyManager` SHALL use `InventoryManager` as the authoritative runtime item store for purchases and sales. Economy code SHALL NOT directly mutate `GameManager.inventory` or `InventoryManager._slots`.

#### Scenario: Successful purchase adds items through InventoryManager
- **WHEN** `EconomyManager.buy_item("seed_carrot", 3)` succeeds
- **THEN** it calls `InventoryManager.add_item("seed_carrot", 3)`
- **AND** `InventoryManager.get_item_count("seed_carrot")` increases by `3`
- **AND** `GameManager.inventory` remains synchronized by `InventoryManager`

#### Scenario: Successful sale removes items through InventoryManager
- **WHEN** `EconomyManager.sell_item("harvest_carrot", 2)` succeeds
- **THEN** it calls `InventoryManager.remove_item("harvest_carrot", 2)`
- **AND** `InventoryManager.get_item_count("harvest_carrot")` decreases by `2`
- **AND** `GameManager.inventory` remains synchronized by `InventoryManager`

### Requirement: Purchase capacity is prechecked before spending gold

Before a purchase spends gold, `EconomyManager` SHALL verify that `InventoryManager` can fully accept the purchased quantity.

#### Scenario: Inventory has enough capacity for purchase
- **WHEN** `InventoryManager.get_addable_count(item_id)` is greater than or equal to the requested quantity
- **AND** all other purchase validation passes
- **THEN** `EconomyManager` may spend gold and add items

#### Scenario: Inventory lacks capacity for purchase
- **WHEN** `InventoryManager.get_addable_count(item_id)` is less than the requested quantity
- **THEN** `EconomyManager.buy_item()` returns `success=false`
- **AND** `error_code` is `INVENTORY_FULL`
- **AND** no gold is spent
- **AND** no partial item addition remains in inventory

### Requirement: Sale ownership is prechecked before removing items

Before a sale adds gold, `EconomyManager` SHALL verify that `InventoryManager` contains the full quantity being sold.

#### Scenario: Inventory has enough items for sale
- **WHEN** `InventoryManager.has_item(item_id, quantity)` returns `true`
- **AND** all other sale validation passes
- **THEN** `EconomyManager` may remove items and add gold

#### Scenario: Inventory lacks items for sale
- **WHEN** `InventoryManager.has_item(item_id, quantity)` returns `false`
- **THEN** `EconomyManager.sell_item()` returns `success=false`
- **AND** `error_code` is `NOT_ENOUGH_ITEMS`
- **AND** no items are removed
- **AND** no gold is added

### Requirement: EconomyManager rolls back partial inventory side effects

If an inventory operation unexpectedly applies only part of a transaction after validation, `EconomyManager` SHALL roll back the applied side effect before returning a failed result.

#### Scenario: Purchase add operation unexpectedly adds too few items
- **WHEN** `GameManager.spend_gold(total_price)` has succeeded
- **AND** `InventoryManager.add_item(item_id, quantity)` returns less than `quantity`
- **THEN** `EconomyManager` removes any added items using `InventoryManager.remove_item(item_id, added)`
- **AND** restores spent gold using `GameManager.add_gold(total_price, "transaction_rollback")`
- **AND** returns `success=false` with `error_code=INVENTORY_FULL`

#### Scenario: Sale remove operation unexpectedly removes too few items
- **WHEN** `InventoryManager.remove_item(item_id, quantity)` returns less than `quantity`
- **THEN** `EconomyManager` restores removed items using `InventoryManager.add_item(item_id, removed)`
- **AND** does not add sale gold
- **AND** returns `success=false` with `error_code=NOT_ENOUGH_ITEMS`
