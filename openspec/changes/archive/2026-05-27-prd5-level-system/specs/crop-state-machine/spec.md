## MODIFIED Requirements

### Requirement: Plant crop operation
CropManager.plant_crop(tile_pos, crop_id) SHALL validate crop unlock state, deduct one seed from inventory, create crop_data at SEED stage, sync to GameManager.farm_data, emit crop_planted signal, and grant plant XP through LevelManager when available.

#### Scenario: Plant crop consumes seed through InventoryManager
- **WHEN** `CropManager.plant_crop(tile_pos, crop_id)` succeeds
- **THEN** it removes one `seed_<crop_id>` through `InventoryManager.remove_item()`
- **AND** inventory slots and `GameManager.inventory` remain synchronized

#### Scenario: Plant crop grants XP through LevelManager
- **WHEN** `CropManager.plant_crop(tile_pos, crop_id)` succeeds and `LevelManager` is available
- **THEN** it SHALL call `LevelManager.grant_xp("plant", {"crop_id": crop_id})`
- **AND** planting SHALL grant `5` XP through the centralized level progression rules

#### Scenario: Locked crop planting is rejected
- **WHEN** `LevelManager` is available and `LevelManager.is_crop_unlocked(crop_id)` returns `false`
- **AND** `CropManager.plant_crop(tile_pos, crop_id)` is called
- **THEN** planting SHALL fail without consuming seed or creating crop data

### Requirement: Harvest operation
CropManager.harvest_crop(tile_pos) SHALL add harvest item to inventory, grant harvest XP through LevelManager when available, clear the tile, sync data, and emit crop_harvested signal. Only MATURE crops can be harvested.

#### Scenario: Harvest crop adds harvest item through InventoryManager
- **WHEN** `CropManager.harvest_crop(tile_pos)` succeeds
- **THEN** it adds one `harvest_<crop_id>` through `InventoryManager.add_item()`
- **AND** inventory slots and `GameManager.inventory` remain synchronized

#### Scenario: Harvest crop grants XP through LevelManager
- **WHEN** `CropManager.harvest_crop(tile_pos)` succeeds and `LevelManager` is available
- **THEN** it SHALL call `LevelManager.grant_xp("harvest", {"crop_id": crop_id})`
- **AND** harvesting SHALL grant `10` XP through the centralized level progression rules

#### Scenario: Harvest does not grant XP on failure
- **WHEN** `CropManager.harvest_crop(tile_pos)` fails because the tile is missing, not mature, or inventory cannot accept the item
- **THEN** no harvest XP SHALL be granted
