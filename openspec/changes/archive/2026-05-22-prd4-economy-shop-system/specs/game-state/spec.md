# game-state Specification

## MODIFIED Requirements

### Requirement: GameManager remains the gold authority while EconomyManager is the transaction authority

`GameManager.gold` SHALL remain the authoritative runtime value for player gold. `EconomyManager` SHALL be the only PRD4 transaction entry point for shop purchases and item sales, and SHALL change gold by calling `GameManager.add_gold()` and `GameManager.spend_gold()` instead of directly mutating `GameManager.gold` outside test setup.

#### Scenario: Purchase spends gold through GameManager
- **WHEN** `EconomyManager.buy_item(item_id, quantity)` succeeds
- **THEN** it calls `GameManager.spend_gold(total_price)` to reduce gold
- **AND** `GameManager.gold` decreases by `total_price`
- **AND** `EventBus.gold_changed(new_amount, delta)` is emitted by `GameManager`

#### Scenario: Sale earns gold through GameManager
- **WHEN** `EconomyManager.sell_item(item_id, quantity)` succeeds
- **THEN** it calls `GameManager.add_gold(total_price, "sell")` to increase gold
- **AND** `GameManager.gold` increases by `total_price`
- **AND** `GameManager.stats.total_gold_earned` increases through existing `GameManager` logic

#### Scenario: Failed transaction does not mutate gold
- **WHEN** `EconomyManager` returns a failed transaction result
- **THEN** `GameManager.gold` remains equal to the result's `gold_before`
- **AND** no successful purchase or sale side-effect remains applied

### Requirement: EconomyManager is registered in Autoload order

The Godot project SHALL register `EconomyManager` as an Autoload singleton after `InventoryManager` and before `SceneManager`.

#### Scenario: Project starts with EconomyManager available
- **WHEN** the Godot project loads Autoload singletons
- **THEN** `EconomyManager` is available globally after `EventBus`, `DataManager`, `GameManager`, `CropManager`, and `InventoryManager`
- **AND** systems can call `EconomyManager.buy_seed()` without manually instantiating it
- **AND** `EconomyManager` does not use `class_name`

### Requirement: Game save data preserves economy stats when available

`GameManager` SHALL include EconomyManager save data in its save payload when the `EconomyManager` Autoload exists, and SHALL restore it during load when economy data is present.

#### Scenario: Save includes economy data
- **WHEN** `GameManager.save_game()` is called and `EconomyManager` is available
- **THEN** the serialized save data contains an `economy` field
- **AND** that field equals `EconomyManager.export_save_data()`

#### Scenario: Load restores economy data
- **WHEN** `GameManager.load_game()` reads save data containing an `economy` field
- **AND** `EconomyManager` is available
- **THEN** it calls `EconomyManager.import_save_data(economy_data)`
- **AND** economy transaction stats are restored

#### Scenario: Legacy save without economy data remains compatible
- **WHEN** `GameManager.load_game()` reads a save file without an `economy` field
- **THEN** loading still succeeds
- **AND** `EconomyManager` keeps or resets default zeroed stats without throwing errors
