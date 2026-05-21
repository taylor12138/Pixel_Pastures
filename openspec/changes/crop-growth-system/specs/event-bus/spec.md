## MODIFIED Requirements

### Requirement: Crop lifecycle signals
EventBus SHALL define signals for the complete crop lifecycle: planted, watered, grown, matured, harvested, withered, and cleared.

#### Scenario: Crop planted signal emitted
- **WHEN** a crop is planted at a tile position
- **THEN** EventBus SHALL emit `crop_planted(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop watered signal emitted
- **WHEN** a crop is watered
- **THEN** EventBus SHALL emit `crop_watered(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop growth stage signal emitted
- **WHEN** a crop advances to a new growth stage (not mature)
- **THEN** EventBus SHALL emit `crop_grown(tile_pos: Vector2i, crop_id: String, new_stage: int)`

#### Scenario: Crop matured signal emitted
- **WHEN** a crop reaches the mature (harvestable) stage
- **THEN** EventBus SHALL emit `crop_matured(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop harvested signal emitted
- **WHEN** a mature crop is harvested by the player
- **THEN** EventBus SHALL emit `crop_harvested(tile_pos: Vector2i, crop_id: String, amount: int)`

#### Scenario: Crop withered signal emitted
- **WHEN** a mature crop withers due to not being harvested before midnight
- **THEN** EventBus SHALL emit `crop_withered(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop cleared signal emitted
- **WHEN** a crop is cleared from the tile
- **THEN** EventBus SHALL emit `crop_cleared(tile_pos: Vector2i)`
