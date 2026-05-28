## ADDED Requirements

### Requirement: CropManager listens to game midnight
CropManager SHALL subscribe to `EventBus.midnight_crossed()` when EventBus is available and SHALL use that game-time event as the primary trigger for mature crop wither checks.

#### Scenario: Midnight triggers wither check
- **WHEN** `EventBus.midnight_crossed()` is emitted by TimeManager
- **THEN** `CropManager` SHALL call `check_wither_all()` once for that midnight event

#### Scenario: Existing fallback remains safe
- **WHEN** CropManager also performs periodic or post-load wither reconciliation
- **THEN** the fallback SHALL NOT conflict with the midnight event listener
- **AND** already withered crops SHALL NOT emit duplicate wither side effects for the same state transition

## MODIFIED Requirements

### Requirement: Wither detection
CropManager SHALL mark MATURE crops as WITHERED when the game-time day changes after maturity, and emit crop_withered signal. Natural-date or offline compensation checks MAY remain as fallback reconciliation, but game-time midnight SHALL be the primary online wither trigger.

#### Scenario: Mature crop withers after game midnight
- **WHEN** a mature crop remains unharvested as TimeManager advances from 23:59 to 00:00
- **THEN** `CropManager` SHALL mark it as `WITHERED`
- **AND** emit `EventBus.crop_withered(tile_pos)`

#### Scenario: Offline compensation still reconciles mature crops
- **WHEN** `CropManager.process_offline_time(last_online_timestamp)` runs after loading a save
- **THEN** mature crop wither detection SHALL run afterward
- **AND** mature or withered crop state SHALL be reconciled according to crop lifecycle rules
