# inventory-data Specification

## ADDED Requirements

### Requirement: InventoryManager Autoload singleton

`InventoryManager` SHALL be registered as a global Autoload singleton at `res://scripts/autoload/inventory_manager.gd`, loaded after `CropManager` and before `SceneManager`, and SHALL NOT use `class_name`.

#### Scenario: Project starts with InventoryManager registered
- **WHEN** the Godot project loads Autoload singletons
- **THEN** `InventoryManager` is available globally after `EventBus`, `DataManager`, `GameManager`, and `CropManager`
- **AND** systems can call `InventoryManager.add_item()` without manually instantiating it

### Requirement: Fixed slot inventory structure

`InventoryManager` SHALL maintain exactly 20 inventory slots. Empty slots SHALL be represented as `null`; occupied slots SHALL be dictionaries with `item_id: String` and `quantity: int`.

#### Scenario: Inventory initializes empty
- **WHEN** `InventoryManager` initializes for a new game
- **THEN** it creates 20 slots
- **AND** every slot is `null`
- **AND** `get_empty_slot_count()` returns `20`

#### Scenario: Slot query returns immutable data
- **WHEN** a caller requests `get_slot(index)` or `get_all_slots()`
- **THEN** occupied slot dictionaries and arrays are returned as deep duplicates
- **AND** external mutation of returned data does not modify internal `_slots`

### Requirement: Item metadata driven stack rules

`InventoryManager` SHALL read item metadata from `DataManager.get_item(item_id)` and use `stackable` and `max_stack` to determine slot placement rules.

#### Scenario: Known stackable item uses configured max stack
- **WHEN** a caller adds a known item with `stackable=true` and `max_stack=99`
- **THEN** each occupied slot for that item contains at most 99 items

#### Scenario: Known non-stackable item occupies one slot per item
- **WHEN** a caller adds a known item with `stackable=false` or `max_stack=1`
- **THEN** each added item occupies a separate slot with quantity `1`

#### Scenario: Unknown item uses fallback rules
- **WHEN** `DataManager.get_item(item_id)` returns an empty dictionary
- **THEN** `InventoryManager` emits `push_warning()`
- **AND** treats the item as `stackable=true` and `max_stack=99`

### Requirement: Add item operation

`add_item(item_id: String, quantity: int = 1)` SHALL add as many items as possible and return the actual added quantity. Stackable items SHALL merge into existing same-item slots before using empty slots.

#### Scenario: Add item to empty inventory
- **WHEN** `add_item("seed_carrot", 10)` is called on an empty inventory
- **THEN** it returns `10`
- **AND** the first available slot stores `{ "item_id": "seed_carrot", "quantity": 10 }`
- **AND** `inventory_changed(slot_index)` and `item_added("seed_carrot", 10, slot_index)` are emitted

#### Scenario: Add stackable item merges before using empty slot
- **WHEN** slot 0 contains 90 `seed_carrot`
- **AND** `add_item("seed_carrot", 15)` is called
- **THEN** slot 0 is filled to 99
- **AND** the remaining 6 are placed in the next empty slot
- **AND** the method returns `15`

#### Scenario: Add item when inventory cannot fit all quantity
- **WHEN** only 5 units of addable capacity remain for `seed_carrot`
- **AND** `add_item("seed_carrot", 10)` is called
- **THEN** it returns `5`
- **AND** `inventory_full()` is emitted
- **AND** no slot exceeds its max stack

#### Scenario: Add non-positive quantity
- **WHEN** `add_item(item_id, 0)` or `add_item(item_id, -1)` is called
- **THEN** it returns `0`
- **AND** inventory state is unchanged

### Requirement: Remove item operation

`remove_item(item_id: String, quantity: int = 1)` SHALL remove up to the requested quantity across all matching slots and return the actual removed quantity.

#### Scenario: Remove item across one or more slots
- **WHEN** inventory contains at least 12 `seed_carrot` across slots
- **AND** `remove_item("seed_carrot", 12)` is called
- **THEN** it returns `12`
- **AND** matching slot quantities are reduced until 12 items are removed
- **AND** any slot reduced to 0 becomes `null`
- **AND** `inventory_changed(slot_index)` and `item_removed("seed_carrot", 12)` are emitted

#### Scenario: Remove more than owned
- **WHEN** inventory contains 3 `seed_carrot`
- **AND** `remove_item("seed_carrot", 10)` is called
- **THEN** it returns `3`
- **AND** all `seed_carrot` slots become empty

#### Scenario: Remove missing item
- **WHEN** inventory contains no `seed_carrot`
- **AND** `remove_item("seed_carrot", 1)` is called
- **THEN** it returns `0`
- **AND** no inventory signal is emitted

### Requirement: Remove item from specific slot

`remove_from_slot(slot_index: int, quantity: int = 1)` SHALL remove up to the requested quantity from a valid occupied slot and return the actual removed quantity.

#### Scenario: Remove part of a slot
- **WHEN** slot 2 contains `{ "item_id": "seed_carrot", "quantity": 10 }`
- **AND** `remove_from_slot(2, 4)` is called
- **THEN** it returns `4`
- **AND** slot 2 quantity becomes `6`

#### Scenario: Remove from invalid or empty slot
- **WHEN** `remove_from_slot()` is called with an out-of-range index or empty slot
- **THEN** it returns `0`
- **AND** inventory state is unchanged

### Requirement: Slot swap, move, merge, smart place, and discard operations

`InventoryManager` SHALL provide slot-level operations for future UI drag/drop behavior: `swap_slots()`, `move_to_slot()`, `merge_slots()`, `smart_place()`, and `discard_slot()`.

#### Scenario: Swap two valid slots
- **WHEN** `swap_slots(from_index, to_index)` is called with two valid indexes
- **THEN** the two slot contents are exchanged
- **AND** the method returns `true`
- **AND** `inventory_changed()` is emitted for both slots

#### Scenario: Move item to empty target slot
- **WHEN** source slot is occupied and target slot is empty
- **AND** `move_to_slot(source, target)` is called
- **THEN** the source content moves to target
- **AND** source becomes `null`
- **AND** the method returns `true`

#### Scenario: Merge compatible stackable slots
- **WHEN** source and target slots contain the same stackable `item_id`
- **AND** target slot is below max stack
- **THEN** `merge_slots(source, target)` moves as many units as possible into target
- **AND** returns the actual merged quantity
- **AND** source becomes `null` if its quantity reaches 0

#### Scenario: Smart place chooses correct operation
- **WHEN** `smart_place(source, target)` is called
- **THEN** it moves if target is empty
- **AND** merges if both slots contain the same stackable item
- **AND** swaps if slots contain different items

#### Scenario: Discard slot destroys items
- **WHEN** `discard_slot(index, quantity)` is called on an occupied slot
- **THEN** the requested quantity is removed from inventory without creating world drops
- **AND** `quantity = -1` discards the entire slot

### Requirement: Inventory query interfaces

`InventoryManager` SHALL provide query methods for slot state, total item counts, capacity, item ownership, type filtering, and first matching slot lookup.

#### Scenario: Query item count and ownership
- **WHEN** inventory contains 12 `seed_carrot` across multiple slots
- **THEN** `get_item_count("seed_carrot")` returns `12`
- **AND** `has_item("seed_carrot", 10)` returns `true`
- **AND** `has_item("seed_carrot", 13)` returns `false`

#### Scenario: Query full state and empty slot count
- **WHEN** no slot can accept any additional item
- **THEN** `is_full()` returns `true`
- **AND** `get_empty_slot_count()` returns `0`

#### Scenario: Query addable count
- **WHEN** existing stacks and empty slots can accept 150 more `seed_carrot`
- **THEN** `get_addable_count("seed_carrot")` returns `150`

#### Scenario: Filter items by type
- **WHEN** inventory contains items whose metadata types include `seed`, `harvest`, and `tool`
- **THEN** `get_items_by_type("seed")` returns only slot data for seed items
- **AND** the returned array is a deep duplicate

#### Scenario: Find first matching item slot
- **WHEN** `seed_carrot` appears in slots 3 and 8
- **THEN** `find_item_slot("seed_carrot")` returns `3`
- **AND** missing items return `-1`

### Requirement: Inventory debug helpers

`InventoryManager` SHALL provide debug helper methods for tests: `debug_print_all()`, `debug_clear()`, and `debug_fill_random()`.

#### Scenario: Clear inventory for test setup
- **WHEN** `debug_clear()` is called in a test scene
- **THEN** all 20 slots become `null`
- **AND** compatible summary state in `GameManager.inventory` is cleared
