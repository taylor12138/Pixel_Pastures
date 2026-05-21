## ADDED Requirements

### Requirement: Check if tile has crop
`CropManager.has_crop(tile_pos: Vector2i) -> bool` SHALL return true if the tile has a crop, false otherwise.

#### Scenario: Tile with crop
- **WHEN** `has_crop()` is called on a tile that has a planted crop
- **THEN** the method SHALL return `true`

#### Scenario: Empty tile
- **WHEN** `has_crop()` is called on a tile with no crop
- **THEN** the method SHALL return `false`

### Requirement: Check if crop is harvestable
`CropManager.is_harvestable(tile_pos: Vector2i) -> bool` SHALL return true only if the tile has a crop in MATURE stage.

#### Scenario: Mature crop is harvestable
- **WHEN** `is_harvestable()` is called on a tile with a MATURE crop
- **THEN** the method SHALL return `true`

#### Scenario: Non-mature crop is not harvestable
- **WHEN** `is_harvestable()` is called on a tile with a crop in any stage other than MATURE
- **THEN** the method SHALL return `false`

### Requirement: Check if crop needs water
`CropManager.needs_water(tile_pos: Vector2i) -> bool` SHALL return true if the tile has a crop in SEED/SPROUT/GROWING stage that is not yet watered.

#### Scenario: Unwatered growth-stage crop needs water
- **WHEN** `needs_water()` is called on a tile with a crop in SEED/SPROUT/GROWING with `watered = false`
- **THEN** the method SHALL return `true`

#### Scenario: Watered crop does not need water
- **WHEN** `needs_water()` is called on a tile with a crop that has `watered = true`
- **THEN** the method SHALL return `false`

#### Scenario: Mature crop does not need water
- **WHEN** `needs_water()` is called on a tile with a MATURE crop
- **THEN** the method SHALL return `false`

### Requirement: Get growth progress
`CropManager.get_growth_progress(tile_pos: Vector2i) -> float` SHALL return a value between 0.0 and 1.0 representing the current stage's growth progress. Returns 0.0 if not watered.

#### Scenario: Unwatered crop returns zero progress
- **WHEN** `get_growth_progress()` is called on a tile with an unwatered crop
- **THEN** the method SHALL return `0.0`

#### Scenario: Half-grown crop returns partial progress
- **WHEN** `get_growth_progress()` is called on a tile with a watered crop AND half of `growth_time_per_stage` has elapsed
- **THEN** the method SHALL return approximately `0.5`

#### Scenario: Mature crop returns full progress
- **WHEN** `get_growth_progress()` is called on a tile with a MATURE crop
- **THEN** the method SHALL return `1.0`

### Requirement: Get crop data
`CropManager.get_crop_data(tile_pos: Vector2i) -> Dictionary` SHALL return the full crop data dictionary for the tile, or an empty dictionary if no crop exists.

#### Scenario: Get existing crop data
- **WHEN** `get_crop_data()` is called on a tile with a crop
- **THEN** the method SHALL return a dictionary containing all crop runtime fields

#### Scenario: Get empty tile data
- **WHEN** `get_crop_data()` is called on an empty tile
- **THEN** the method SHALL return an empty dictionary `{}`

### Requirement: Get all crops
`CropManager.get_all_crops() -> Dictionary` SHALL return all tile crop data as a dictionary of Vector2i to crop data.

#### Scenario: Multiple crops exist
- **WHEN** `get_all_crops()` is called with 3 planted crops
- **THEN** the method SHALL return a dictionary with 3 entries

### Requirement: Get mature crops list
`CropManager.get_mature_crops() -> Array[Vector2i]` SHALL return positions of all crops in MATURE stage.

#### Scenario: Mixed stages
- **WHEN** `get_mature_crops()` is called with some crops mature and some not
- **THEN** the method SHALL return only the positions of MATURE crops

### Requirement: Get crops needing water list
`CropManager.get_crops_needing_water() -> Array[Vector2i]` SHALL return positions of all crops that need watering.

#### Scenario: Some crops need water
- **WHEN** `get_crops_needing_water()` is called with a mix of watered and unwatered growth-stage crops
- **THEN** the method SHALL return only the positions of unwatered SEED/SPROUT/GROWING crops

### Requirement: Export and import save data
CropManager SHALL provide `export_save_data() -> Dictionary` and `import_save_data(data: Dictionary) -> void` for archive integration.

#### Scenario: Export round-trip
- **WHEN** `export_save_data()` is called, then crops are cleared, then `import_save_data()` is called with the exported data
- **THEN** all crop states SHALL be fully restored to their pre-export state
