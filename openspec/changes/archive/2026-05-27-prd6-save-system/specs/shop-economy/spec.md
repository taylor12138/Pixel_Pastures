## MODIFIED Requirements

### Requirement: EconomyManager maintains transaction stats

`EconomyManager` SHALL maintain saveable transaction stats for spent gold, sale earnings, bought item count, sold item count, and total successful transactions.

#### Scenario: Successful purchase updates stats
- **WHEN** a purchase succeeds
- **THEN** `total_gold_spent` increases by total price
- **AND** `total_items_bought` increases by quantity
- **AND** `total_transactions` increases by `1`

#### Scenario: Successful sale updates stats
- **WHEN** a sale succeeds
- **THEN** `total_gold_earned_from_sales` increases by total price
- **AND** `total_items_sold` increases by quantity
- **AND** `total_transactions` increases by `1`

#### Scenario: Failed transaction does not update stats
- **WHEN** a transaction fails
- **THEN** economy stats remain unchanged

#### Scenario: Economy stats export and import round trip
- **WHEN** `EconomyManager.export_save_data()` is called
- **THEN** it SHALL return a serializable Dictionary containing `total_gold_spent`, `total_gold_earned_from_sales`, `total_items_bought`, `total_items_sold`, and `total_transactions`
- **WHEN** `EconomyManager.import_save_data(data)` receives that Dictionary
- **THEN** stats SHALL be restored to the exported values

#### Scenario: Economy import normalizes invalid stats
- **WHEN** `EconomyManager.import_save_data(data)` receives missing or negative stat fields
- **THEN** missing fields SHALL default to `0`
- **AND** negative fields SHALL be clamped to `0`
