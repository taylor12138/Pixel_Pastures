# player-interaction Specification Delta

## ADDED Requirements

### Requirement: Player farm tile requests are consumed by FarmInteractionController
`PlayerController` MUST continue to broadcast farm-tile requests without owning PRD10 business logic, and `FarmInteractionController` MUST be able to consume those requests.

#### Scenario: Player request triggers farm interaction controller
- **WHEN** `PlayerController.try_interact()` emits `EventBus.farm_tile_interaction_requested(tile_pos, target)`
- **AND** `FarmInteractionController` is connected
- **THEN** `FarmInteractionController` MUST receive the request
- **AND** it MUST process `tile_pos` through the same business path used by mouse tile interaction

#### Scenario: Player controller remains business-free after PRD10
- **WHEN** PRD10 is implemented
- **THEN** `PlayerController` MUST NOT directly call `CropManager.plant_crop()`, `CropManager.water_crop()`, `CropManager.harvest_crop()`, `CropManager.clear_crop()`, `InventoryManager.remove_item()`, `InventoryManager.add_item()`, `FarmGridManager.set_tile_occupied()`, `FarmGridManager.clear_tile()`, or `FarmGridManager.mark_tile_watered()` as part of farm-tile interaction

#### Scenario: Player interaction success may still lead to farm business failure
- **WHEN** `PlayerController.try_interact()` succeeds because a farm-tile target exists
- **AND** `FarmInteractionController` rejects the requested action due to `seed_missing`, `crop_not_mature`, or another business reason
- **THEN** the player-side interaction result MUST remain a valid request
- **AND** the business failure MUST be reported through `farm_interaction_failed(result)`
