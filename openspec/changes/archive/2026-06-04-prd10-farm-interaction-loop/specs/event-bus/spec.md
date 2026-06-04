# event-bus Specification Delta

## ADDED Requirements

### Requirement: Farm interaction result signals
EventBus MUST define PRD10 farm interaction signals for mode changes, completed actions, failed actions, and action preview changes.

#### Scenario: Farm interaction mode changed signal emitted
- **WHEN** `FarmInteractionController` changes the current interaction mode or selected item
- **THEN** EventBus MUST emit `farm_interaction_mode_changed(mode: String, selected_item_id: String, selected_crop_id: String)`
- **AND** `mode` MUST be a stable mode name such as `NONE`, `PLANT`, `WATER`, `HARVEST`, or `CLEAR`

#### Scenario: Farm interaction completed signal emitted
- **WHEN** `FarmInteractionController` successfully plants, waters, harvests, or clears a farm tile
- **THEN** EventBus MUST emit `farm_interaction_completed(result: Dictionary)`
- **AND** `result.success` MUST be `true`

#### Scenario: Farm interaction failed signal emitted
- **WHEN** `FarmInteractionController` rejects a farm-tile request or a business operation fails
- **THEN** EventBus MUST emit `farm_interaction_failed(result: Dictionary)`
- **AND** `result.success` MUST be `false`
- **AND** `result.reason` MUST be a stable non-empty error code

#### Scenario: Farm tile action preview changed signal emitted
- **WHEN** the hovered or targeted farm tile changes and the controller can infer a preview action or reason
- **THEN** EventBus MUST be able to emit `farm_tile_action_preview_changed(tile_pos: Vector2i, action: String, reason: String)`

### Requirement: Farm request and result event semantics remain distinct
EventBus MUST keep player farm-tile requests distinct from completed PRD10 farm business actions.

#### Scenario: Farm tile request does not mean business completion
- **WHEN** `farm_tile_interaction_requested(tile_pos, target)` is emitted by `PlayerController`
- **THEN** listeners MUST treat it only as an interaction request
- **AND** planting, watering, harvesting, or clearing completion MUST only be represented by crop lifecycle signals and `farm_interaction_completed(result)`

#### Scenario: Farm interaction failure does not replace player interaction failure
- **WHEN** `PlayerController.try_interact()` cannot produce a target
- **THEN** `player_interaction_failed(reason)` MUST remain the event for player-side failure
- **WHEN** `FarmInteractionController` receives a target but rejects the business action
- **THEN** `farm_interaction_failed(result)` MUST be the event for business-side failure
