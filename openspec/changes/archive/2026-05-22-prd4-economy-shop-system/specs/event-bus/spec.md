# event-bus Specification

## MODIFIED Requirements

### Requirement: Economy transaction events are broadcast through EventBus

`EventBus` SHALL define typed signals for completed and failed economy transactions so UI, HUD, achievement, logging, and tests can observe transaction outcomes without coupling to `EconomyManager` internals.

#### Scenario: Successful transaction is broadcast
- **WHEN** `EconomyManager.buy_item()`, `EconomyManager.buy_seed()`, `EconomyManager.sell_item()`, or `EconomyManager.sell_harvest()` completes successfully
- **THEN** `EventBus.transaction_completed(result: Dictionary)` is emitted
- **AND** `result.success` is `true`
- **AND** the signal is emitted only after gold, inventory, and economy stats have been updated

#### Scenario: Failed transaction is broadcast
- **WHEN** an economy transaction fails validation or fails after rollback
- **THEN** `EventBus.transaction_failed(result: Dictionary)` is emitted
- **AND** `result.success` is `false`
- **AND** `result.error_code` contains a stable non-empty error code
- **AND** no successful transaction signal is emitted for the same failed transaction

#### Scenario: Purchase-specific signal remains success-only
- **WHEN** a purchase succeeds
- **THEN** `EventBus.item_purchased(item_id: String, price: int)` is emitted
- **AND** `EventBus.transaction_completed(result: Dictionary)` is emitted
- **WHEN** a purchase fails
- **THEN** `EventBus.item_purchased` is not emitted
- **AND** `EventBus.transaction_failed(result: Dictionary)` is emitted

#### Scenario: Sale-specific signal remains success-only
- **WHEN** a sale succeeds
- **THEN** `EventBus.item_sold(item_id: String, price: int)` is emitted
- **AND** `EventBus.transaction_completed(result: Dictionary)` is emitted
- **WHEN** a sale fails
- **THEN** `EventBus.item_sold` is not emitted
- **AND** `EventBus.transaction_failed(result: Dictionary)` is emitted

### Requirement: EventBus remains the economy UI communication boundary

Economy UI, HUD, notifications, and future analytics systems SHALL observe economy outcomes through `EventBus` rather than mutating `EconomyManager`, `GameManager`, or `InventoryManager` internals.

#### Scenario: Future shop UI displays a failed purchase
- **WHEN** `EconomyManager.buy_item()` returns a failed transaction
- **THEN** future UI systems can display the failure by listening to `transaction_failed(result)`
- **AND** they do not need to parse console logs or inspect private manager state
