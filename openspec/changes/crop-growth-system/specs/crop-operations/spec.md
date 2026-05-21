## ADDED Requirements

### Requirement: Plant crop operation
`CropManager.plant_crop(tile_pos: Vector2i, crop_id: String) -> bool` SHALL create a new crop at the specified tile if: the tile has no existing crop, the crop_id exists in DataManager, and the player has the corresponding seed in inventory.

#### Scenario: Successful planting
- **WHEN** `plant_crop(Vector2i(0,0), "carrot")` is called AND tile is empty AND crop_id exists AND player has `seed_carrot` in inventory
- **THEN** the method SHALL return `true`, deduct 1 seed from inventory, create crop data with stage=SEED and watered=false, sync to GameManager.farm_data, and emit `EventBus.crop_planted`

#### Scenario: Tile already occupied
- **WHEN** `plant_crop()` is called on a tile that already has a crop
- **THEN** the method SHALL return `false` without modifying any state

#### Scenario: Invalid crop_id
- **WHEN** `plant_crop()` is called with a crop_id not found in DataManager
- **THEN** the method SHALL return `false` without modifying any state

#### Scenario: No seed in inventory
- **WHEN** `plant_crop()` is called but player has no corresponding seed item
- **THEN** the method SHALL return `false` without modifying any state

### Requirement: Water crop operation
`CropManager.water_crop(tile_pos: Vector2i) -> bool` SHALL water the crop at the specified tile if: the tile has a crop, the crop stage is SEED/SPROUT/GROWING, and the crop is not already watered.

#### Scenario: Successful watering
- **WHEN** `water_crop()` is called on a tile with an unwatered crop in SEED/SPROUT/GROWING stage
- **THEN** the method SHALL return `true`, set `watered = true`, record `water_timestamp`, increment `water_count`, update `GameManager.stats["total_water_count"]`, and emit `EventBus.crop_watered`

#### Scenario: Already watered
- **WHEN** `water_crop()` is called on a tile where the crop is already watered
- **THEN** the method SHALL return `false` without modifying any state

#### Scenario: Water mature crop
- **WHEN** `water_crop()` is called on a tile with a MATURE crop
- **THEN** the method SHALL return `false`

#### Scenario: Water withered crop
- **WHEN** `water_crop()` is called on a tile with a WITHERED crop
- **THEN** the method SHALL return `false`

### Requirement: Harvest crop operation
`CropManager.harvest_crop(tile_pos: Vector2i) -> String` SHALL harvest the crop if it is in MATURE stage, returning the crop_id on success or empty string on failure.

#### Scenario: Successful harvest
- **WHEN** `harvest_crop()` is called on a tile with a MATURE crop
- **THEN** the method SHALL return the crop_id, add `harvest_<crop_id>` to inventory, grant 10 XP, increment `total_harvests` stat, clear the tile, sync to GameManager.farm_data, and emit `EventBus.crop_harvested`

#### Scenario: Harvest non-mature crop
- **WHEN** `harvest_crop()` is called on a tile with a crop NOT in MATURE stage
- **THEN** the method SHALL return an empty string without modifying any state

#### Scenario: Harvest empty tile
- **WHEN** `harvest_crop()` is called on a tile with no crop
- **THEN** the method SHALL return an empty string

### Requirement: Clear crop operation
`CropManager.clear_crop(tile_pos: Vector2i) -> bool` SHALL remove the crop from the specified tile if one exists.

#### Scenario: Successful clear
- **WHEN** `clear_crop()` is called on a tile with a crop (any stage)
- **THEN** the method SHALL return `true`, remove the crop data, sync to GameManager.farm_data, and emit `EventBus.crop_cleared`

#### Scenario: Clear empty tile
- **WHEN** `clear_crop()` is called on a tile with no crop
- **THEN** the method SHALL return `false`

### Requirement: Data sync with GameManager
CropManager SHALL synchronize crop data to `GameManager.farm_data` after every mutation operation (plant, water, harvest, clear, stage advance, wither). The key format SHALL be `"x,y"` string.

#### Scenario: Sync after plant
- **WHEN** a crop is successfully planted
- **THEN** `GameManager.farm_data` SHALL contain the new crop data under key `"x,y"`

#### Scenario: Sync after clear
- **WHEN** a crop is cleared
- **THEN** the corresponding key SHALL be removed from `GameManager.farm_data`

#### Scenario: Load from GameManager on init
- **WHEN** CropManager initializes (or `import_save_data()` is called)
- **THEN** CropManager SHALL load all crop data from `GameManager.farm_data`
