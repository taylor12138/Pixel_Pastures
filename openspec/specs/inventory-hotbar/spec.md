# inventory-hotbar Specification

## Purpose
This specification defines the inventory-hotbar capability.
## Requirements
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

### Requirement: Farm interaction can sync from selected hotbar item
`FarmInteractionController` MUST interpret the currently selected hotbar item as the authoritative farm interaction selection when `sync_selection_from_hotbar()` is called. An empty selected slot, removed selected item, or unsupported item MUST clear any previous farm seed/tool selection.

#### Scenario: Selected seed enters plant mode
- **WHEN** `InventoryManager.get_selected_item()` returns an item whose `item_id` is `seed_carrot`
- **AND** `FarmInteractionController.sync_selection_from_hotbar()` is called
- **THEN** the controller MUST select crop id `carrot`
- **AND** the current mode MUST become `PLANT`

#### Scenario: Selected watering can enters water mode
- **WHEN** `InventoryManager.get_selected_item()` returns an item whose `item_id` is `watering_can`
- **AND** `FarmInteractionController.sync_selection_from_hotbar()` is called
- **THEN** the controller MUST select tool id `watering_can`
- **AND** the current mode MUST become `WATER`

#### Scenario: Empty selected slot clears stale selection
- **WHEN** `InventoryManager.get_selected_item()` returns `null`
- **AND** `FarmInteractionController.sync_selection_from_hotbar()` is called
- **THEN** the controller MUST NOT crash
- **AND** the controller MUST call `clear_selection()` or reach equivalent `NONE` state
- **AND** previous seed and tool ids MUST be empty

#### Scenario: Selected item is removed
- **WHEN** the selected hotbar slot becomes empty after move, discard, sale, use, or load
- **AND** hotbar selection is synchronized
- **THEN** the controller MUST clear the previous farm interaction selection

#### Scenario: Unsupported selected item clears farm mode
- **WHEN** the selected hotbar item is neither a seed nor `watering_can`
- **AND** hotbar selection is synchronized
- **THEN** the controller MUST enter `NONE`
- **AND** MUST NOT continue using a previously selected seed or tool

### Requirement: Debug farm selection does not mutate hotbar state
PRD10 debug selection MUST remain a temporary controller selection and MUST NOT rewrite inventory slot contents or selected hotbar index.

#### Scenario: Debug key selects seed without changing inventory slots
- **WHEN** debug mode selects `seed_carrot` through `FarmInteractionController.select_seed("carrot")`
- **THEN** `InventoryManager` slot contents MUST remain unchanged
- **AND** only a later successful plant operation may consume one seed through CropManager

#### Scenario: Debug key selects tool without changing selected hotbar index
- **WHEN** debug mode selects `watering_can`
- **THEN** `InventoryManager.selected_hotbar` MUST NOT be changed by that debug selection alone
