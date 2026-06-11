## MODIFIED Requirements

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
