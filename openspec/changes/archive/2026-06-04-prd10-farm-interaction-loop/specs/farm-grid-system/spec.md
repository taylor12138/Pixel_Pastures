# farm-grid-system Specification Delta

## ADDED Requirements

### Requirement: Farm grid synchronizes with crop interaction operations
FarmGridManager MUST remain the owner of tile state while supporting PRD10 interaction operations that mirror successful CropManager business changes.

#### Scenario: Successful planting marks tile occupied
- **WHEN** `FarmInteractionController` successfully plants a crop through `CropManager.plant_crop(tile_pos, crop_id)`
- **THEN** FarmGridManager MUST accept `set_tile_occupied(tile_pos, true, crop_tile_ref)`
- **AND** the tile MUST become occupied without overwriting CropManager crop data

#### Scenario: Successful watering marks wet visual state
- **WHEN** `FarmInteractionController` successfully waters a crop through `CropManager.water_crop(tile_pos)`
- **THEN** FarmGridManager MUST accept `mark_tile_watered(tile_pos)`
- **AND** the tile MUST express wet soil or equivalent watered visual state

#### Scenario: Successful harvest clears tile
- **WHEN** `FarmInteractionController` successfully harvests a mature crop and `CropManager.harvest_crop(tile_pos)` returns a crop_id
- **THEN** FarmGridManager MUST accept `clear_tile(tile_pos)`
- **AND** the tile MUST become unoccupied and plantable if it is an unlocked farm plot

#### Scenario: Successful clear restores tile
- **WHEN** `FarmInteractionController` successfully clears a withered crop
- **THEN** FarmGridManager MUST accept `clear_tile(tile_pos)`
- **AND** the tile MUST become unoccupied and plantable if it is an unlocked farm plot

### Requirement: Debug tile cycling must not corrupt real crop data
田园场景的 PRD8 调试点击循环 MUST NOT override PRD10 的真实作物交互闭环。

#### Scenario: PRD10 controller consumes left click in normal prototype mode
- **WHEN** `FarmInteractionController` is active in `farm.tscn`
- **AND** the player left-clicks a farm tile
- **THEN** the click MUST be routed to PRD10 interaction handling
- **AND** the PRD8 `empty -> dry_soil -> wet_soil -> occupied -> empty` debug cycle MUST NOT run for that click

#### Scenario: Debug cycling cannot alter tile with crop data
- **WHEN** any debug tile-state cycle remains enabled
- **AND** `CropManager.has_crop(tile_pos)` returns `true`
- **THEN** the debug cycle MUST NOT clear, occupy, unlock, wet, or otherwise mutate that tile
- **AND** PRD10 crop interaction state MUST remain authoritative

### Requirement: Farm grid can be reconciled from crop data
FarmGridManager MUST expose enough mutation and query behavior for PRD10 to repair mismatches between tile occupancy and CropManager crop records.

#### Scenario: Reconcile can restore occupied tile
- **WHEN** CropManager has crop data at an unlocked farm tile
- **AND** FarmGridManager reports the tile as not occupied
- **THEN** PRD10 reconciliation MUST be able to call FarmGridManager APIs to mark that tile occupied

#### Scenario: Reconcile can clear stale occupied tile
- **WHEN** FarmGridManager reports an unlocked farm tile as occupied
- **AND** CropManager has no crop data for that tile
- **THEN** PRD10 reconciliation MUST be able to call FarmGridManager APIs to clear that tile
