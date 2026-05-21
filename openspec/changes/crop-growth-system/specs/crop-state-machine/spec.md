## ADDED Requirements

### Requirement: Crop stage enum
CropManager SHALL define a `CropStage` enum with values: `SEED = 0`, `SPROUT = 1`, `GROWING = 2`, `MATURE = 3`, `WITHERED = 4`.

#### Scenario: All stages defined
- **WHEN** CropManager script is loaded
- **THEN** `CropStage` enum SHALL contain exactly 5 values in order: SEED(0), SPROUT(1), GROWING(2), MATURE(3), WITHERED(4)

### Requirement: Watered sub-state per growth stage
Each growth stage (SEED, SPROUT, GROWING) SHALL have a boolean `watered` sub-state. When `watered` is false, the crop SHALL NOT advance to the next stage regardless of elapsed time.

#### Scenario: Unwatered crop does not advance
- **WHEN** a crop is in SEED stage with `watered = false`
- **THEN** the crop SHALL remain in SEED stage indefinitely until watered

#### Scenario: Watered crop starts timer
- **WHEN** a crop's `watered` is set to `true`
- **THEN** `water_timestamp` SHALL be recorded and growth timer SHALL begin

### Requirement: Stage advancement via timer
When a crop is watered, it SHALL advance to the next stage after `growth_time_per_stage` seconds have elapsed since `water_timestamp`.

#### Scenario: SEED advances to SPROUT
- **WHEN** a crop in SEED stage has `watered = true` AND `current_time >= water_timestamp + growth_time_per_stage`
- **THEN** the crop SHALL advance to SPROUT stage AND `watered` SHALL reset to `false`

#### Scenario: SPROUT advances to GROWING
- **WHEN** a crop in SPROUT stage has `watered = true` AND `current_time >= water_timestamp + growth_time_per_stage`
- **THEN** the crop SHALL advance to GROWING stage AND `watered` SHALL reset to `false`

#### Scenario: GROWING advances to MATURE
- **WHEN** a crop in GROWING stage has `watered = true` AND `current_time >= water_timestamp + growth_time_per_stage`
- **THEN** the crop SHALL advance to MATURE stage AND `mature_timestamp` SHALL be recorded

### Requirement: Wither on midnight crossing
A crop in MATURE stage SHALL transition to WITHERED if the current calendar date is later than the date when it became mature.

#### Scenario: Mature crop withers after midnight
- **WHEN** a crop is in MATURE stage AND the current system date is later than the date of `mature_timestamp`
- **THEN** the crop SHALL transition to WITHERED stage

#### Scenario: Mature crop same day does not wither
- **WHEN** a crop is in MATURE stage AND the current system date equals the date of `mature_timestamp`
- **THEN** the crop SHALL remain in MATURE stage

### Requirement: Wither is soft penalty
When a crop withers, the system SHALL NOT deduct gold, XP, or any other player resource. The only loss is the potential harvest.

#### Scenario: No penalty on wither
- **WHEN** a crop transitions to WITHERED
- **THEN** `player_gold`, `player_xp`, and `player_level` SHALL remain unchanged

### Requirement: Growth check polling
CropManager SHALL check all crops for stage advancement every 1 second via `_process(delta)`, only when `GameManager.current_state == GameState.PLAYING`.

#### Scenario: Growth check interval
- **WHEN** game is in PLAYING state
- **THEN** CropManager SHALL evaluate all crop timers once per second (not every frame)

#### Scenario: Growth check paused
- **WHEN** game is NOT in PLAYING state
- **THEN** CropManager SHALL NOT evaluate crop timers

### Requirement: Offline compensation
When `process_offline_time(last_online_timestamp)` is called, CropManager SHALL advance each watered crop by at most one stage (since the player cannot water during offline). Crops that reach MATURE during offline SHALL undergo wither judgment.

#### Scenario: Watered crop advances one stage offline
- **WHEN** a crop was watered before going offline AND offline duration exceeds `growth_time_per_stage`
- **THEN** the crop SHALL advance exactly one stage AND `watered` SHALL reset to `false`

#### Scenario: Unwatered crop does not advance offline
- **WHEN** a crop was NOT watered before going offline
- **THEN** the crop SHALL remain in its current stage regardless of offline duration

#### Scenario: Crop reaches mature and withers offline
- **WHEN** a crop advances to MATURE during offline compensation AND the current date is later than the computed mature date
- **THEN** the crop SHALL transition to WITHERED

### Requirement: Crop runtime data structure
Each crop instance SHALL maintain: `crop_id` (String), `stage` (CropStage), `watered` (bool), `water_timestamp` (float), `water_count` (int), `planted_timestamp` (float), `mature_timestamp` (float).

#### Scenario: Data structure completeness
- **WHEN** a crop is created via `plant_crop()`
- **THEN** all 7 fields SHALL be initialized with appropriate default values
