# inventory-hotbar Specification Delta

## ADDED Requirements

### Requirement: Farm interaction can sync from selected hotbar item
`FarmInteractionController` MUST be able to interpret the currently selected hotbar item as a temporary farm interaction selection when the hotbar query API is available.

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

#### Scenario: Empty selected slot does not crash
- **WHEN** `InventoryManager.get_selected_item()` returns `null`
- **AND** `FarmInteractionController.sync_selection_from_hotbar()` is called
- **THEN** the controller MUST NOT crash
- **AND** it MUST either clear selection or keep an explicitly configured debug selection

### Requirement: Debug farm selection does not mutate hotbar state
PRD10 debug selection MUST remain a temporary controller selection and MUST NOT rewrite inventory slot contents or selected hotbar index.

#### Scenario: Debug key selects seed without changing inventory slots
- **WHEN** debug mode selects `seed_carrot` through `FarmInteractionController.select_seed("carrot")`
- **THEN** `InventoryManager` slot contents MUST remain unchanged
- **AND** only a later successful plant operation may consume one seed through CropManager

#### Scenario: Debug key selects tool without changing selected hotbar index
- **WHEN** debug mode selects `watering_can`
- **THEN** `InventoryManager.selected_hotbar` MUST NOT be changed by that debug selection alone
