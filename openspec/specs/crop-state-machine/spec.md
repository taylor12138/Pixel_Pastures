# crop-state-machine Specification

## Purpose
This specification defines the crop-state-machine capability.

## Requirements

### Requirement: CropManager Autoload singleton
CropManager SHALL be registered as a global Autoload singleton, loaded after GameManager, providing crop lifecycle management.

#### Scenario: CropManager is globally available
- **WHEN** the Godot project starts
- **THEN** `CropManager` SHALL be available as an Autoload singleton
- **AND** crop lifecycle methods can be called without manual instantiation

### Requirement: 5-stage crop state machine
CropManager SHALL implement a CropStage enum with values SEED(0), SPROUT(1), GROWING(2), MATURE(3), WITHERED(4).

#### Scenario: Crop stages are defined
- **WHEN** `CropManager.CropStage` is inspected
- **THEN** it SHALL include `SEED`, `SPROUT`, `GROWING`, `MATURE`, and `WITHERED` stages

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

### Requirement: Water crop operation
CropManager.water_crop(tile_pos) SHALL set watered=true, record water_timestamp, increment water_count, and emit crop_watered signal. It SHALL fail for MATURE/WITHERED/already-watered crops.

#### Scenario: Water crop succeeds once per stage
- **WHEN** `CropManager.water_crop(tile_pos)` is called for an unwatered non-mature crop
- **THEN** the crop data SHALL set `watered` to `true`
- **AND** `water_count` SHALL increase by `1`

### Requirement: Growth timing system
CropManager SHALL check all crops every 1 second. When elapsed time >= growth_time_per_stage for a watered crop, it SHALL advance the stage and reset watered=false.

#### Scenario: Watered crop advances after elapsed growth time
- **WHEN** a watered crop has elapsed at least its configured growth time per stage
- **THEN** `CropManager` SHALL advance it to the next crop stage
- **AND** reset `watered` to `false`

### Requirement: Mature signal emission
When a crop advances to MATURE stage, CropManager SHALL emit crop_matured(tile_pos, crop_id) and record mature_timestamp.

#### Scenario: Crop matured signal is emitted
- **WHEN** a crop advances to the `MATURE` stage
- **THEN** `EventBus.crop_matured(tile_pos, crop_id)` SHALL be emitted
- **AND** `mature_timestamp` SHALL be recorded

### Requirement: Wither detection
CropManager SHALL mark MATURE crops as WITHERED when the current natural date differs from the mature date, and emit crop_withered signal.

#### Scenario: Mature crop withers after date changes
- **WHEN** a mature crop's recorded mature date differs from the current natural date
- **THEN** `CropManager` SHALL mark it as `WITHERED`
- **AND** emit `EventBus.crop_withered(tile_pos)`

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

### Requirement: Clear operation
CropManager.clear_crop(tile_pos) SHALL remove crop data from the tile, sync to GameManager, and emit crop_cleared signal.

#### Scenario: Clear crop removes tile data
- **WHEN** `CropManager.clear_crop(tile_pos)` succeeds
- **THEN** the tile SHALL no longer contain crop data
- **AND** `EventBus.crop_cleared(tile_pos)` SHALL be emitted

### Requirement: Offline compensation
CropManager.process_offline_time() SHALL advance watered crops by at most one stage based on elapsed time, then run wither detection on all MATURE crops.

#### Scenario: Offline compensation advances watered crops at most once
- **WHEN** `CropManager.process_offline_time()` processes elapsed offline time
- **THEN** each eligible watered crop SHALL advance by at most one stage
- **AND** mature crop wither detection SHALL run afterward

### Requirement: Query interfaces
CropManager SHALL provide: has_crop(), get_crop_data(), is_harvestable(), needs_water(), get_growth_progress(), get_all_crops(), get_mature_crops(), get_crops_needing_water().

#### Scenario: Query interfaces expose crop state
- **WHEN** crop state query methods are called
- **THEN** they SHALL return the requested crop state, harvestability, water needs, growth progress, or filtered crop collections without mutating crop data

### Requirement: Save data integration
CropManager SHALL export and import all crop tile runtime state through JSON-serializable data using `"x,y"` string keys, and SHALL support post-load offline compensation.

#### Scenario: Crop state exports string-keyed tile data
- **WHEN** `CropManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary containing `tiles`
- **AND** every tile key SHALL be a string coordinate in `"x,y"` format
- **AND** every tile value SHALL contain JSON-serializable crop runtime state

#### Scenario: Crop state imports string-keyed tile data
- **WHEN** `CropManager.import_save_data(data)` receives a Dictionary containing `tiles`
- **THEN** it SHALL restore crop tile runtime state
- **AND** it SHALL skip invalid coordinates or invalid crop IDs without crashing

#### Scenario: Crop offline compensation runs after load
- **WHEN** SaveManager successfully loads a save containing crop data and a last-online timestamp
- **THEN** `CropManager.process_offline_time(last_online_timestamp)` SHALL run after crop data import
- **AND** mature or withered crop state SHALL be reconciled according to crop lifecycle rules
