## MODIFIED Requirements

### Requirement: Time system signals
EventBus SHALL define signals for game time progression and time-control state, including minute changes, hour changes, game-day starts, season changes, year changes, day-phase changes, midnight crossing, time-scale changes, and time-paused changes.

#### Scenario: Minute changed signal emitted
- **WHEN** the in-game minute advances
- **THEN** EventBus SHALL emit `minute_changed(hour: int, minute: int)`

#### Scenario: Hour changed signal emitted
- **WHEN** the in-game hour advances
- **THEN** EventBus SHALL emit `hour_changed(new_hour: int)`

#### Scenario: Day started signal emitted
- **WHEN** a new in-game day begins
- **THEN** EventBus SHALL emit `day_started(year: int, season: String, day: int)`

#### Scenario: Season changed signal emitted
- **WHEN** the in-game season transitions
- **THEN** EventBus SHALL emit `season_changed(new_season: String)`

#### Scenario: Year changed signal emitted
- **WHEN** the in-game year advances after winter ends
- **THEN** EventBus SHALL emit `year_changed(new_year: int)`

#### Scenario: Midnight crossed signal emitted
- **WHEN** the in-game clock advances from 23:59 to 00:00
- **THEN** EventBus SHALL emit `midnight_crossed()` for wither detection

#### Scenario: Day phase changed signal emitted
- **WHEN** the calculated day phase changes between `morning`, `afternoon`, `evening`, and `night`
- **THEN** EventBus SHALL emit `day_phase_changed(new_phase: String)`

#### Scenario: Time scale changed signal emitted
- **WHEN** `TimeManager.set_time_scale(scale)` accepts a new legal time scale
- **THEN** EventBus SHALL emit `time_scale_changed(new_scale: float)`

#### Scenario: Time paused changed signal emitted
- **WHEN** `TimeManager.set_time_paused(value)` changes the paused state
- **THEN** EventBus SHALL emit `time_paused_changed(paused: bool)`
