## ADDED Requirements

### Requirement: Inventory save data supports slot restoration
InventoryManager SHALL export and import serializable save data that preserves slot order and selected hotbar state.

#### Scenario: Export inventory save data
- **WHEN** `InventoryManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary containing `slots` and `selected_hotbar`
- **AND** `slots` SHALL be a deep duplicate of the 20-slot inventory array

#### Scenario: Import inventory save data
- **WHEN** `InventoryManager.import_save_data(data)` receives save data with `slots` and `selected_hotbar`
- **THEN** it SHALL restore slot order
- **AND** it SHALL clamp or reset selected hotbar to a valid index from 0 to 8
- **AND** it SHALL ensure slot array length is exactly 20
- **AND** it SHALL synchronize `GameManager.inventory`

#### Scenario: Import malformed inventory data safely
- **WHEN** `InventoryManager.import_save_data(data)` receives missing, short, long, or malformed slot data
- **THEN** it SHALL normalize the inventory to exactly 20 slots
- **AND** invalid or non-positive quantity slots SHALL become `null`
