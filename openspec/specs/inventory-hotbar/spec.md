# inventory-hotbar Specification

## ADDED Requirements

### Requirement: Hotbar maps to first nine inventory slots

`InventoryManager` SHALL expose a 9-slot hotbar that directly maps to inventory slots 0 through 8 and SHALL NOT store separate hotbar item data.

#### Scenario: Hotbar query returns first nine slots
- **WHEN** inventory slots 0 through 8 contain any combination of items and empty slots
- **THEN** `get_hotbar_slots()` returns a 9-element array matching those slots
- **AND** returned slot data is a deep duplicate

#### Scenario: Inventory slot changes are reflected in hotbar query
- **WHEN** slot 0 changes from empty to `seed_carrot`
- **THEN** the next `get_hotbar_slots()` call includes `seed_carrot` at hotbar index 0

### Requirement: Hotbar selection state

`InventoryManager` SHALL track the selected hotbar index as an integer from 0 to 8 and expose `select_hotbar(index: int)`.

#### Scenario: Select valid hotbar index
- **WHEN** `select_hotbar(3)` is called
- **THEN** selected hotbar index becomes `3`
- **AND** `EventBus.hotbar_selected(3)` is emitted

#### Scenario: Select invalid hotbar index
- **WHEN** `select_hotbar(-1)` or `select_hotbar(9)` is called
- **THEN** selected hotbar index is unchanged
- **AND** no `hotbar_selected` signal is emitted

### Requirement: Selected item query

`get_selected_item()` SHALL return the slot data for the currently selected hotbar slot or `null` when the selected slot is empty.

#### Scenario: Selected slot contains item
- **WHEN** selected hotbar index is `0`
- **AND** inventory slot 0 contains `{ "item_id": "seed_carrot", "quantity": 5 }`
- **THEN** `get_selected_item()` returns a deep duplicate of that slot data

#### Scenario: Selected slot is empty
- **WHEN** selected hotbar index points to an empty inventory slot
- **THEN** `get_selected_item()` returns `null`

### Requirement: Use selected item

`use_selected_item()` SHALL consume one item from the selected hotbar slot and return the used `item_id`; it SHALL return an empty string when no item can be used.

#### Scenario: Use selected stackable item
- **WHEN** selected slot contains `{ "item_id": "seed_carrot", "quantity": 2 }`
- **AND** `use_selected_item()` is called
- **THEN** it returns `"seed_carrot"`
- **AND** selected slot quantity becomes `1`
- **AND** `inventory_changed(selected_slot_index)` and `item_removed("seed_carrot", 1)` are emitted

#### Scenario: Use last item in selected slot
- **WHEN** selected slot contains `{ "item_id": "seed_carrot", "quantity": 1 }`
- **AND** `use_selected_item()` is called
- **THEN** it returns `"seed_carrot"`
- **AND** selected slot becomes `null`

#### Scenario: Use selected empty slot
- **WHEN** selected slot is empty
- **AND** `use_selected_item()` is called
- **THEN** it returns an empty string
- **AND** inventory state is unchanged

### Requirement: Hotbar does not own input handling

`InventoryManager` SHALL NOT listen for keyboard input directly. Number key handling for selecting hotbar slots belongs to later HUD/UI implementation.

#### Scenario: InventoryManager runs without input processing
- **WHEN** the scene is running
- **THEN** `InventoryManager` changes selected hotbar only when `select_hotbar()` is called by another system
