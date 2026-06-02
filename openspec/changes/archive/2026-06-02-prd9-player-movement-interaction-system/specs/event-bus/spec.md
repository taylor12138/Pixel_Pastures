## MODIFIED Requirements

### 需求:Interaction signals
EventBus SHALL define signals for generic interaction start and end, and MUST also define player-driven interaction request signals for PRD9 player movement and farm-tile interaction flow.

#### Scenario: Interaction started
- **WHEN** the player begins interacting with a game object
- **THEN** EventBus SHALL emit `interaction_started(target: Node)`

#### Scenario: Interaction ended
- **WHEN** the player finishes or cancels an interaction
- **THEN** EventBus SHALL emit `interaction_ended()`

#### Scenario: Player spawned signal emitted
- **WHEN** `PlayerController` initializes or resets the player spawn position
- **THEN** EventBus SHALL emit `player_spawned(world_pos: Vector2, grid_pos: Vector2i)`

#### Scenario: Player moved signal emitted
- **WHEN** `PlayerController` detects an effective player world position or grid position change
- **THEN** EventBus SHALL emit `player_moved(world_pos: Vector2, grid_pos: Vector2i)`

#### Scenario: Player direction changed signal emitted
- **WHEN** `PlayerController` changes the player's facing direction
- **THEN** EventBus SHALL emit `player_direction_changed(direction: String, direction_vector: Vector2i)`
- **AND** `direction` SHALL be one of `down`, `up`, `left`, or `right`

#### Scenario: Player movement enabled changed signal emitted
- **WHEN** `PlayerController.set_can_move(value)` changes movement enabled state
- **THEN** EventBus SHALL emit `player_movement_enabled_changed(enabled: bool)`

#### Scenario: Player interaction target changed signal emitted
- **WHEN** `PlayerController` changes the current interaction target
- **THEN** EventBus SHALL emit `player_interaction_target_changed(target: Dictionary)`
- **AND** `target` SHALL be an empty Dictionary when no target is available

#### Scenario: Player interacted signal emitted
- **WHEN** `PlayerController.try_interact()` succeeds with any interaction target
- **THEN** EventBus SHALL emit `player_interacted(target: Dictionary)`

#### Scenario: Player interaction failed signal emitted
- **WHEN** `PlayerController.try_interact()` fails because interaction is disabled or no target exists
- **THEN** EventBus SHALL emit `player_interaction_failed(reason: String)`
- **AND** `reason` SHALL be a stable non-empty error code such as `interaction_disabled` or `no_target`

#### Scenario: Farm tile interaction request signal emitted
- **WHEN** `PlayerController.try_interact()` succeeds and the target type is `farm_tile`
- **THEN** EventBus SHALL emit `farm_tile_interaction_requested(tile_pos: Vector2i, target: Dictionary)`
- **AND** this signal SHALL represent that the player requested a farm-tile interaction, not that planting, watering, harvesting, or clearing has completed

## ADDED Requirements

### 需求:Player interaction signals do not replace crop lifecycle signals
玩家交互请求信号 SHALL 只表达玩家发起交互的事实，禁止替代或移除既有作物生命周期信号和田园网格状态变化信号。

#### 场景:作物生命周期信号保持独立
- **WHEN** `farm_tile_interaction_requested` is emitted for a farm tile
- **THEN** EventBus SHALL NOT imply that `crop_planted`, `crop_watered`, `crop_harvested`, or `crop_cleared` has occurred
- **AND** crop lifecycle signals SHALL remain emitted only by the systems that actually complete those crop operations

#### 场景:地块状态变化信号保持独立
- **WHEN** `player_interacted` or `farm_tile_interaction_requested` is emitted
- **THEN** EventBus SHALL NOT imply that `farm_tile_state_changed` has occurred
- **AND** farm grid mutation signals SHALL remain emitted only when FarmGridManager or an equivalent owner changes tile state

## REMOVED Requirements
