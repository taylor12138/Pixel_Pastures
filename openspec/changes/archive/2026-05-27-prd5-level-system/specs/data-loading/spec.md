## ADDED Requirements

### Requirement: Query all level data
DataManager SHALL provide a read-only query that returns all configured level records for use by LevelManager and tests.

#### Scenario: All levels query returns safe copy
- **WHEN** `DataManager.get_all_levels()` is called
- **THEN** it SHALL return all configured level dictionaries
- **AND** mutating the returned Array or Dictionaries SHALL NOT mutate DataManager source data

## MODIFIED Requirements

### Requirement: Query level data
DataManager SHALL provide a `get_level_data(level: int) -> Dictionary` method that returns a safe copy of level configuration including XP requirements and unlock information.

#### Scenario: Level 3 data query
- **WHEN** `DataManager.get_level_data(3)` is called
- **THEN** the returned Dictionary SHALL contain `xp_required: 250` and `unlocks.crops` containing `strawberry`

#### Scenario: Invalid level data query
- **WHEN** `DataManager.get_level_data(999)` is called
- **THEN** the method SHALL return an empty Dictionary
- **AND** the game SHALL NOT crash

#### Scenario: Level data query is immutable
- **WHEN** external code mutates a Dictionary returned by `DataManager.get_level_data(3)`
- **THEN** subsequent calls to `DataManager.get_level_data(3)` SHALL return unchanged source data

### Requirement: Query crops by ID
DataManager SHALL provide a `get_crop(crop_id: String) -> Dictionary` method that returns a safe copy of the full crop data dictionary for a given crop ID.

#### Scenario: Valid crop ID query
- **WHEN** `DataManager.get_crop("carrot")` is called
- **THEN** the returned Dictionary SHALL contain keys: `id`, `name`, `seed_price`, `sell_price`, `growth_time_per_stage`, `total_water_count`, `seasons`, `unlock_level`, `description`
- **AND** `id` SHALL equal `carrot` and `seed_price` SHALL equal `10`

#### Scenario: Invalid crop ID query
- **WHEN** `DataManager.get_crop("nonexistent")` is called
- **THEN** the method SHALL return an empty Dictionary `{}`

#### Scenario: Crop data query is immutable
- **WHEN** external code modifies a dictionary returned by `get_crop()`
- **THEN** the original data in DataManager SHALL remain unchanged on subsequent queries

### Requirement: Query unlocked crops by player level
DataManager SHALL provide a `get_unlocked_crops(player_level: int) -> Array` method that returns safe copies of all crops with `unlock_level` less than or equal to the given player level for compatibility, while LevelManager remains the gameplay unlock authority.

#### Scenario: Level 1 player crops
- **WHEN** `DataManager.get_unlocked_crops(1)` is called
- **THEN** the returned Array SHALL contain exactly 4 crops: carrot, cabbage, corn, potato

#### Scenario: Level 4 player crops
- **WHEN** `DataManager.get_unlocked_crops(4)` is called
- **THEN** the returned Array SHALL contain 8 crops: all configured crops except pumpkin and broccoli

#### Scenario: LevelManager uses DataManager for compatibility fallback
- **WHEN** `LevelManager` needs a crop unlock fallback for a crop missing from `levels.json.unlocks.crops`
- **THEN** it SHALL be able to use `DataManager.get_crop(crop_id).unlock_level` without mutating DataManager data
