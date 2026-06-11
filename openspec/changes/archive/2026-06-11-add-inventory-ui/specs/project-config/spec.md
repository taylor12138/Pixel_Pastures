## MODIFIED Requirements

### Requirement: InputMap actions registered
The project SHALL define all gameplay input actions in project.godot, including movement (4 directions), interaction, inventory open/cancel controls, UI controls, hotbar slots, and zoom. `open_bag` SHALL be independent from save or system pause actions.

#### Scenario: Movement inputs respond
- **WHEN** the player presses W, A, S, D or arrow keys
- **THEN** the corresponding `move_up`, `move_left`, `move_down`, `move_right` actions SHALL be detected via `Input.is_action_pressed()`

#### Scenario: Hotbar slots 1-9 respond
- **WHEN** the player presses number keys 1 through 9
- **THEN** the corresponding `hotbar_1` through `hotbar_9` actions SHALL be detected

#### Scenario: Interact key responds
- **WHEN** the player presses E
- **THEN** the `interact` action SHALL be detected

#### Scenario: Inventory open input responds
- **WHEN** the player presses Tab
- **THEN** the `open_bag` action SHALL be detected
- **AND** the action SHALL NOT trigger manual save or system pause behavior

#### Scenario: Cancel inputs respond
- **WHEN** the player presses Escape or the right mouse button
- **THEN** the `cancel` action SHALL be detected

#### Scenario: Zoom inputs respond
- **WHEN** the player scrolls mouse wheel up or down
- **THEN** the corresponding `zoom_in` or `zoom_out` actions SHALL be detected
