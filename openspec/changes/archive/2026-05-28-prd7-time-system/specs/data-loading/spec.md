## ADDED Requirements

### Requirement: TimeManager can query crops by season
DataManager SHALL expose crop data in a form that allows TimeManager to determine whether a crop can be planted in a specified season without mutating source data.

#### Scenario: TimeManager queries valid crop seasons
- **WHEN** `TimeManager.can_plant_crop_in_season(crop_id, season_id)` calls `DataManager.get_crop(crop_id)` for a valid crop
- **THEN** the returned crop Dictionary SHALL include a `seasons` Array
- **AND** TimeManager SHALL be able to compare `season_id` against that Array

#### Scenario: TimeManager handles missing crop data
- **WHEN** `TimeManager.can_plant_crop_in_season(crop_id, season_id)` calls `DataManager.get_crop(crop_id)` for an invalid crop
- **THEN** DataManager SHALL return an empty Dictionary
- **AND** TimeManager SHALL return `false` without crashing

## MODIFIED Requirements

### Requirement: Query crops by season
DataManager SHALL provide a `get_crops_by_season(season: String) -> Array` method that returns safe copies of all crops available in the specified season and can be consumed by TimeManager for current-season helper queries.

#### Scenario: Summer crops query
- **WHEN** `DataManager.get_crops_by_season("summer")` is called
- **THEN** the returned Array SHALL contain crop dictionaries for: tomato, corn, pepper, eggplant (4 crops)

#### Scenario: Spring crops query
- **WHEN** `DataManager.get_crops_by_season("spring")` is called
- **THEN** the returned Array SHALL contain crop dictionaries for: carrot, potato, strawberry, broccoli (4 crops)

#### Scenario: TimeManager current season crop query uses safe copies
- **WHEN** `TimeManager.get_current_season_crops()` requests crops for the current season
- **THEN** the returned Array SHALL contain safe crop data copies from DataManager
- **AND** mutating the returned Array or Dictionaries SHALL NOT mutate DataManager source data
