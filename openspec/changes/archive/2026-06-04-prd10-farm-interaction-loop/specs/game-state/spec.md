# game-state Specification Delta

## ADDED Requirements

### Requirement: Farm interaction loop preserves saveable runtime state
PRD10 interactions MUST update only existing manager-owned state so the current save system can persist the crop, grid, inventory, and progression effects of the loop.

#### Scenario: Planting produces saveable crop grid and inventory state
- **WHEN** `FarmInteractionController` successfully plants a crop
- **THEN** CropManager export data MUST include the new crop
- **AND** FarmGridManager export data MUST include the occupied tile
- **AND** InventoryManager export data MUST reflect one consumed seed

#### Scenario: Watering produces saveable crop and grid state
- **WHEN** `FarmInteractionController` successfully waters a crop
- **THEN** CropManager export data MUST include the crop watered state and water count
- **AND** FarmGridManager export data MUST include the wet or occupied watered visual state

#### Scenario: Harvesting produces saveable inventory and grid state
- **WHEN** `FarmInteractionController` successfully harvests a mature crop
- **THEN** CropManager export data MUST no longer include that crop
- **AND** FarmGridManager export data MUST show the tile as clear
- **AND** InventoryManager export data MUST include the added harvest item
- **AND** LevelManager or GameManager export data MUST include any harvest XP effects handled by CropManager

#### Scenario: Clearing withered crop produces saveable empty tile state
- **WHEN** `FarmInteractionController` successfully clears a withered crop
- **THEN** CropManager export data MUST no longer include that crop
- **AND** FarmGridManager export data MUST show the tile as clear
- **AND** InventoryManager export data MUST NOT gain a harvest item from the clear operation

### Requirement: Loaded farm state can be reconciled for interaction
After loading or initializing a farm scene, PRD10 MUST be able to repair mismatches between saved crop data and saved grid occupancy before player interaction resumes.

#### Scenario: Load with crop but unoccupied grid is repaired
- **WHEN** saved CropManager data contains a crop at `tile_pos`
- **AND** saved FarmGridManager data has that tile unoccupied
- **AND** `FarmInteractionController.reconcile_grid_with_crops()` runs
- **THEN** the tile MUST become occupied

#### Scenario: Load with occupied grid but no crop is repaired
- **WHEN** saved FarmGridManager data has a tile occupied
- **AND** saved CropManager data has no crop at that tile
- **AND** `FarmInteractionController.reconcile_grid_with_crops()` runs
- **THEN** the tile MUST become clear and plantable when it is an unlocked farm plot

#### Scenario: Controller selection is not required save data
- **WHEN** a save file is exported after PRD10 interactions
- **THEN** the save MUST NOT require `FarmInteractionController.current_mode`, `selected_item_id`, `selected_crop_id`, or `last_result` to restore the playable farm state
