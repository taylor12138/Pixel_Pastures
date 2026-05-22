## ADDED Requirements

### Requirement: Crop lifecycle signals
EventBus SHALL define signals for the complete crop lifecycle: planted, watered, grown, matured, harvested, withered, and cleared.

#### Scenario: Crop planted signal emitted
- **WHEN** a crop is planted at a tile position
- **THEN** EventBus SHALL emit `crop_planted(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop watered signal emitted
- **WHEN** a crop is watered
- **THEN** EventBus SHALL emit `crop_watered(tile_pos: Vector2i)`

#### Scenario: Crop growth stage signal emitted
- **WHEN** a crop advances to a new growth stage
- **THEN** EventBus SHALL emit `crop_grown(tile_pos: Vector2i, new_stage: int)`

#### Scenario: Crop matured signal emitted
- **WHEN** a crop reaches the mature (harvestable) stage
- **THEN** EventBus SHALL emit `crop_matured(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop harvested signal emitted
- **WHEN** a mature crop is harvested by the player
- **THEN** EventBus SHALL emit `crop_harvested(tile_pos: Vector2i, crop_id: String, amount: int)`

#### Scenario: Crop withered signal emitted
- **WHEN** a mature crop withers due to not being harvested before midnight
- **THEN** EventBus SHALL emit `crop_withered(tile_pos: Vector2i)`

#### Scenario: Crop cleared signal emitted
- **WHEN** a withered crop is cleared from the tile
- **THEN** EventBus SHALL emit `crop_cleared(tile_pos: Vector2i)`

### Requirement: Economy signals
EventBus SHALL define signals for gold changes, purchases, and sales.

#### Scenario: Gold changed signal emitted
- **WHEN** the player's gold amount changes (increase or decrease)
- **THEN** EventBus SHALL emit `gold_changed(new_amount: int, delta: int)`

#### Scenario: Item purchased signal emitted
- **WHEN** the player buys an item from the shop
- **THEN** EventBus SHALL emit `item_purchased(item_id: String, price: int)`

#### Scenario: Item sold signal emitted
- **WHEN** the player sells an item
- **THEN** EventBus SHALL emit `item_sold(item_id: String, price: int)`

### Requirement: Inventory signals
EventBus SHALL define signals for inventory state changes.

#### Scenario: Inventory changed signal emitted
- **WHEN** an inventory slot's content changes (add/remove/swap)
- **THEN** EventBus SHALL emit `inventory_changed(slot_index: int)`

#### Scenario: Inventory full signal emitted
- **WHEN** an item cannot be added because all 20 inventory slots are occupied
- **THEN** EventBus SHALL emit `inventory_full()`

### Requirement: Level and XP signals
EventBus SHALL define signals for experience gain and level progression.

#### Scenario: XP gained signal emitted
- **WHEN** the player earns experience points
- **THEN** EventBus SHALL emit `xp_gained(amount: int, new_total: int)`

#### Scenario: Level up signal emitted
- **WHEN** the player's XP reaches the threshold for the next level
- **THEN** EventBus SHALL emit `level_up(new_level: int, unlocks: Array)`

### Requirement: Time system signals
EventBus SHALL define signals for game time progression including hour changes, day changes, season changes, and midnight crossing.

#### Scenario: Hour changed signal emitted
- **WHEN** the in-game hour advances
- **THEN** EventBus SHALL emit `hour_changed(new_hour: int)`

#### Scenario: Day changed signal emitted
- **WHEN** a new in-game day begins
- **THEN** EventBus SHALL emit `day_changed(new_day: int)`

#### Scenario: Season changed signal emitted
- **WHEN** the in-game season transitions
- **THEN** EventBus SHALL emit `season_changed(new_season: String)`

#### Scenario: Midnight crossed signal emitted
- **WHEN** the real-world clock crosses midnight (00:00)
- **THEN** EventBus SHALL emit `midnight_crossed()` for wither detection

### Requirement: Interaction signals
EventBus SHALL define signals for player interaction start and end.

#### Scenario: Interaction started
- **WHEN** the player begins interacting with a game object
- **THEN** EventBus SHALL emit `interaction_started(target: Node)`

#### Scenario: Interaction ended
- **WHEN** the player finishes or cancels an interaction
- **THEN** EventBus SHALL emit `interaction_ended()`

### Requirement: Save/Load signals
EventBus SHALL define signals for save and load operations.

#### Scenario: Game saved signal emitted
- **WHEN** the game is successfully saved
- **THEN** EventBus SHALL emit `game_saved()`

#### Scenario: Game loaded signal emitted
- **WHEN** a save file is successfully loaded
- **THEN** EventBus SHALL emit `game_loaded()`

### Requirement: Signal naming convention
All EventBus signals SHALL use past tense naming (e.g., `crop_planted` not `plant_crop`) to indicate events that have already occurred.

#### Scenario: All signals follow past tense convention
- **WHEN** the EventBus script is inspected
- **THEN** every signal name SHALL be in past tense or passive form (e.g., `_planted`, `_changed`, `_gained`, `_crossed`)

---

<!-- Synced from prd3-inventory-system -->

## MODIFIED Requirements

### Requirement: Inventory and hotbar events are broadcast through EventBus

`EventBus` SHALL define typed signals for inventory slot changes, inventory full state, hotbar selection, item addition, and item removal.

#### Scenario: Inventory slot changes are broadcast
- **WHEN** an inventory operation changes a slot
- **THEN** `EventBus.inventory_changed(slot_index: int)` is emitted with the changed slot index

#### Scenario: Inventory full is broadcast
- **WHEN** `InventoryManager.add_item()` cannot add the full requested quantity because capacity is exhausted
- **THEN** `EventBus.inventory_full()` is emitted

#### Scenario: Hotbar selection is broadcast
- **WHEN** `InventoryManager.select_hotbar(index)` successfully changes the selected hotbar index
- **THEN** `EventBus.hotbar_selected(index: int)` is emitted

#### Scenario: Item addition is broadcast
- **WHEN** `InventoryManager.add_item()` adds one or more items to a slot
- **THEN** `EventBus.item_added(item_id: String, quantity: int, slot_index: int)` is emitted
- **AND** `quantity` is the amount added to that slot

#### Scenario: Item removal is broadcast
- **WHEN** `InventoryManager.remove_item()`, `remove_from_slot()`, `discard_slot()`, or `use_selected_item()` removes one or more items
- **THEN** `EventBus.item_removed(item_id: String, quantity: int)` is emitted
- **AND** `quantity` is the actual removed quantity

### Requirement: EventBus remains the cross-system communication boundary

Inventory-related UI, HUD, economy, and achievement systems SHALL observe inventory state changes through `EventBus` instead of directly patching inventory internals.

#### Scenario: Future UI updates inventory display
- **WHEN** inventory data changes
- **THEN** future UI systems can refresh affected slots by listening to `inventory_changed(slot_index)`
- **AND** they do not need to own or mutate `InventoryManager._slots`
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
