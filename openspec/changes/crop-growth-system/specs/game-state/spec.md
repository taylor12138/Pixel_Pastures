## MODIFIED Requirements

### Requirement: Autoload registration in project.godot
All 6 Autoloads (EventBus, DataManager, GameManager, CropManager, SaveManager, AudioManager) SHALL be registered in the `[autoload]` section of project.godot in the correct load order.

#### Scenario: All autoloads accessible
- **WHEN** any game script runs
- **THEN** `EventBus`, `DataManager`, `GameManager`, `CropManager`, `SaveManager`, and `AudioManager` SHALL all be accessible as global singletons

#### Scenario: Load order is correct
- **WHEN** project.godot `[autoload]` section is inspected
- **THEN** the order SHALL be: EventBus, DataManager, GameManager, CropManager, SaveManager, AudioManager

## ADDED Requirements

### Requirement: Farm data storage
GameManager SHALL maintain a `farm_data: Dictionary` property for storing crop tile data, initialized as an empty dictionary.

#### Scenario: Farm data accessible
- **WHEN** any script references `GameManager.farm_data`
- **THEN** the property SHALL be accessible and default to an empty `{}`

### Requirement: Inventory item operations
GameManager SHALL provide `add_item(item_id: String, amount: int)`, `has_item(item_id: String) -> bool`, and `remove_item(item_id: String, amount: int) -> bool` methods for inventory management.

#### Scenario: Add and check item
- **WHEN** `GameManager.add_item("seed_carrot", 3)` is called
- **THEN** `GameManager.has_item("seed_carrot")` SHALL return `true`

#### Scenario: Remove item success
- **WHEN** player has 3 seed_carrot AND `GameManager.remove_item("seed_carrot", 1)` is called
- **THEN** the method SHALL return `true` and remaining count SHALL be 2

#### Scenario: Remove item insufficient
- **WHEN** player has 0 of an item AND `remove_item()` is called
- **THEN** the method SHALL return `false` without modifying inventory

### Requirement: Stats tracking
GameManager SHALL maintain a `stats: Dictionary` with at minimum `total_water_count` (int) and `total_harvests` (int) fields, both initialized to 0.

#### Scenario: Stats initialized
- **WHEN** a new game starts
- **THEN** `GameManager.stats["total_water_count"]` SHALL be `0` AND `GameManager.stats["total_harvests"]` SHALL be `0`

### Requirement: XP addition method
GameManager SHALL provide `add_xp(amount: int, source: String)` method that adds XP to `player_xp` and emits the appropriate signal.

#### Scenario: Add XP from harvest
- **WHEN** `GameManager.add_xp(10, "harvest")` is called
- **THEN** `player_xp` SHALL increase by 10 AND `EventBus.xp_gained` SHALL be emitted
