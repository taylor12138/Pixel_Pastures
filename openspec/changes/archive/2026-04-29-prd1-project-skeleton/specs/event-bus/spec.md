## ADDED Requirements

### Requirement: Crop lifecycle signals
EventBus SHALL define signals for the complete crop lifecycle: planted, watered, grown, matured, harvested, withered, and cleared.

#### Scenario: Crop planted signal emitted
- **WHEN** a crop is planted at a tile position
- **THEN** EventBus SHALL emit `crop_planted(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop watered signal emitted
- **WHEN** a crop is watered
- **THEN** EventBus SHALL emit `crop_watered(tile_pos: Vector2i)`

#### Scenario: Crop growth stage signal emitted
- **WHEN** a crop advances to a new growth stage
- **THEN** EventBus SHALL emit `crop_grown(tile_pos: Vector2i, new_stage: int)`

#### Scenario: Crop matured signal emitted
- **WHEN** a crop reaches the mature (harvestable) stage
- **THEN** EventBus SHALL emit `crop_matured(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop harvested signal emitted
- **WHEN** a mature crop is harvested by the player
- **THEN** EventBus SHALL emit `crop_harvested(tile_pos: Vector2i, crop_id: String, amount: int)`

#### Scenario: Crop withered signal emitted
- **WHEN** a mature crop withers due to not being harvested before midnight
- **THEN** EventBus SHALL emit `crop_withered(tile_pos: Vector2i)`

#### Scenario: Crop cleared signal emitted
- **WHEN** a withered crop is cleared from the tile
- **THEN** EventBus SHALL emit `crop_cleared(tile_pos: Vector2i)`

### Requirement: Economy signals
EventBus SHALL define signals for gold changes, purchases, and sales.

#### Scenario: Gold changed signal emitted
- **WHEN** the player's gold amount changes (increase or decrease)
- **THEN** EventBus SHALL emit `gold_changed(new_amount: int, delta: int)`

#### Scenario: Item purchased signal emitted
- **WHEN** the player buys an item from the shop
- **THEN** EventBus SHALL emit `item_purchased(item_id: String, price: int)`

#### Scenario: Item sold signal emitted
- **WHEN** the player sells an item
- **THEN** EventBus SHALL emit `item_sold(item_id: String, price: int)`

### Requirement: Inventory signals
EventBus SHALL define signals for inventory state changes.

#### Scenario: Inventory changed signal emitted
- **WHEN** an inventory slot's content changes (add/remove/swap)
- **THEN** EventBus SHALL emit `inventory_changed(slot_index: int)`

#### Scenario: Inventory full signal emitted
- **WHEN** an item cannot be added because all 20 inventory slots are occupied
- **THEN** EventBus SHALL emit `inventory_full()`

### Requirement: Level and XP signals
EventBus SHALL define signals for experience gain and level progression.

#### Scenario: XP gained signal emitted
- **WHEN** the player earns experience points
- **THEN** EventBus SHALL emit `xp_gained(amount: int, new_total: int)`

#### Scenario: Level up signal emitted
- **WHEN** the player's XP reaches the threshold for the next level
- **THEN** EventBus SHALL emit `level_up(new_level: int, unlocks: Array)`

### Requirement: Time system signals
EventBus SHALL define signals for game time progression including hour changes, day changes, season changes, and midnight crossing.

#### Scenario: Hour changed signal emitted
- **WHEN** the in-game hour advances
- **THEN** EventBus SHALL emit `hour_changed(new_hour: int)`

#### Scenario: Day changed signal emitted
- **WHEN** a new in-game day begins
- **THEN** EventBus SHALL emit `day_changed(new_day: int)`

#### Scenario: Season changed signal emitted
- **WHEN** the in-game season transitions
- **THEN** EventBus SHALL emit `season_changed(new_season: String)`

#### Scenario: Midnight crossed signal emitted
- **WHEN** the real-world clock crosses midnight (00:00)
- **THEN** EventBus SHALL emit `midnight_crossed()` for wither detection

### Requirement: Interaction signals
EventBus SHALL define signals for player interaction start and end.

#### Scenario: Interaction started
- **WHEN** the player begins interacting with a game object
- **THEN** EventBus SHALL emit `interaction_started(target: Node)`

#### Scenario: Interaction ended
- **WHEN** the player finishes or cancels an interaction
- **THEN** EventBus SHALL emit `interaction_ended()`

### Requirement: Save/Load signals
EventBus SHALL define signals for save and load operations.

#### Scenario: Game saved signal emitted
- **WHEN** the game is successfully saved
- **THEN** EventBus SHALL emit `game_saved()`

#### Scenario: Game loaded signal emitted
- **WHEN** a save file is successfully loaded
- **THEN** EventBus SHALL emit `game_loaded()`

### Requirement: Signal naming convention
All EventBus signals SHALL use past tense naming (e.g., `crop_planted` not `plant_crop`) to indicate events that have already occurred.

#### Scenario: All signals follow past tense convention
- **WHEN** the EventBus script is inspected
- **THEN** every signal name SHALL be in past tense or passive form (e.g., `_planted`, `_changed`, `_gained`, `_crossed`)
