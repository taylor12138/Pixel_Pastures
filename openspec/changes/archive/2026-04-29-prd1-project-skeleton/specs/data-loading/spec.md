## ADDED Requirements

### Requirement: Load all JSON data tables on startup
DataManager SHALL load all game data files (crops.json, levels.json, items.json, achievements.json) from the `res://data/` directory during `_ready()` and store them as in-memory dictionaries.

#### Scenario: All data loaded successfully
- **WHEN** the game starts and DataManager `_ready()` executes
- **THEN** DataManager SHALL have loaded 10 crops, 7 levels, 15+ items, and 8 achievements into memory
- **AND** the console SHALL print load confirmation logs

#### Scenario: Missing data file graceful handling
- **WHEN** a JSON file does not exist at the expected path
- **THEN** DataManager SHALL print an error via `push_error()` and initialize the corresponding dictionary as empty
- **AND** the game SHALL NOT crash

### Requirement: Query crops by ID
DataManager SHALL provide a `get_crop(crop_id: String) -> Dictionary` method that returns the full crop data dictionary for a given crop ID.

#### Scenario: Valid crop ID query
- **WHEN** `DataManager.get_crop("carrot")` is called
- **THEN** the returned Dictionary SHALL contain keys: `id`, `name`, `seed_price`, `sell_price`, `growth_time_per_stage`, `total_water_count`, `seasons`, `unlock_level`, `description`
- **AND** `id` SHALL equal `"carrot"` and `seed_price` SHALL equal `10`

#### Scenario: Invalid crop ID query
- **WHEN** `DataManager.get_crop("nonexistent")` is called
- **THEN** the method SHALL return an empty Dictionary `{}`

### Requirement: Query crops by season
DataManager SHALL provide a `get_crops_by_season(season: String) -> Array` method that returns all crops available in the specified season.

#### Scenario: Summer crops query
- **WHEN** `DataManager.get_crops_by_season("summer")` is called
- **THEN** the returned Array SHALL contain crop dictionaries for: tomato, corn, pepper, eggplant (4 crops)

#### Scenario: Spring crops query
- **WHEN** `DataManager.get_crops_by_season("spring")` is called
- **THEN** the returned Array SHALL contain crop dictionaries for: carrot, potato, strawberry, broccoli (4 crops)

### Requirement: Query unlocked crops by player level
DataManager SHALL provide a `get_unlocked_crops(player_level: int) -> Array` method that returns all crops with `unlock_level` <= the given player level.

#### Scenario: Level 1 player crops
- **WHEN** `DataManager.get_unlocked_crops(1)` is called
- **THEN** the returned Array SHALL contain exactly 4 crops: carrot, cabbage, corn, potato

#### Scenario: Level 4 player crops
- **WHEN** `DataManager.get_unlocked_crops(4)` is called
- **THEN** the returned Array SHALL contain 8 crops (all except pumpkin and broccoli)

### Requirement: Query level data
DataManager SHALL provide a `get_level_data(level: int) -> Dictionary` method that returns level configuration including XP requirements and unlock information.

#### Scenario: Level 3 data query
- **WHEN** `DataManager.get_level_data(3)` is called
- **THEN** the returned Dictionary SHALL contain `xp_required: 250` and `unlocks.crops` containing `["strawberry"]`

### Requirement: Query item data
DataManager SHALL provide a `get_item(item_id: String) -> Dictionary` method that returns item data by ID.

#### Scenario: Seed item query
- **WHEN** `DataManager.get_item("seed_carrot")` is called
- **THEN** the returned Dictionary SHALL contain `type: "seed"`, `crop_id: "carrot"`, `stackable: true`, `max_stack: 99`

### Requirement: Data immutability
DataManager's loaded data SHALL be treated as read-only. Runtime game state MUST NOT modify the original data tables.

#### Scenario: Attempt to modify loaded data
- **WHEN** external code modifies a dictionary returned by `get_crop()`
- **THEN** the original data in DataManager SHALL remain unchanged on subsequent queries
