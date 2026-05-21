## ADDED Requirements

### Requirement: CropManager Autoload singleton
CropManager SHALL be registered as a global Autoload singleton, loaded after GameManager, providing crop lifecycle management.

### Requirement: 5-stage crop state machine
CropManager SHALL implement a CropStage enum with values SEED(0), SPROUT(1), GROWING(2), MATURE(3), WITHERED(4).

### Requirement: Plant crop operation
CropManager.plant_crop(tile_pos, crop_id) SHALL deduct one seed from inventory, create crop_data at SEED stage, sync to GameManager.farm_data, and emit crop_planted signal.

### Requirement: Water crop operation
CropManager.water_crop(tile_pos) SHALL set watered=true, record water_timestamp, increment water_count, and emit crop_watered signal. It SHALL fail for MATURE/WITHERED/already-watered crops.

### Requirement: Growth timing system
CropManager SHALL check all crops every 1 second. When elapsed time >= growth_time_per_stage for a watered crop, it SHALL advance the stage and reset watered=false.

### Requirement: Mature signal emission
When a crop advances to MATURE stage, CropManager SHALL emit crop_matured(tile_pos, crop_id) and record mature_timestamp.

### Requirement: Wither detection
CropManager SHALL mark MATURE crops as WITHERED when the current natural date differs from the mature date, and emit crop_withered signal.

### Requirement: Harvest operation
CropManager.harvest_crop(tile_pos) SHALL add harvest item to inventory, grant 10 XP, clear the tile, sync data, and emit crop_harvested signal. Only MATURE crops can be harvested.

### Requirement: Clear operation
CropManager.clear_crop(tile_pos) SHALL remove crop data from the tile, sync to GameManager, and emit crop_cleared signal.

### Requirement: Offline compensation
CropManager.process_offline_time() SHALL advance watered crops by at most one stage based on elapsed time, then run wither detection on all MATURE crops.

### Requirement: Query interfaces
CropManager SHALL provide: has_crop(), get_crop_data(), is_harvestable(), needs_water(), get_growth_progress(), get_all_crops(), get_mature_crops(), get_crops_needing_water().

### Requirement: Save data integration
CropManager SHALL sync all state changes to GameManager.farm_data using "x,y" string keys, and load from it on initialization.
