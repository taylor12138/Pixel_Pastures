# event-bus Specification

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
