# project-config Specification

## Purpose
This specification defines the project-config capability.

## Requirements

### Requirement: Pixel-perfect rendering configuration
The project SHALL configure Godot's rendering pipeline for pixel-perfect display with Nearest texture filtering, viewport stretch mode, and keep aspect ratio.

#### Scenario: Textures render without blur
- **WHEN** any texture or sprite is displayed in the game window
- **THEN** the texture SHALL appear with sharp pixel edges (no bilinear interpolation)

#### Scenario: Window scales correctly
- **WHEN** the game launches with default settings
- **THEN** the window SHALL display at 1920×1280 pixels with internal viewport of 480×320

#### Scenario: Aspect ratio preserved on resize
- **WHEN** the player resizes the game window to a non-3:2 ratio
- **THEN** black bars SHALL appear to maintain the 3:2 aspect ratio without stretching

### Requirement: Viewport resolution matches tile grid
The viewport SHALL be exactly 480×320 pixels (30×20 tiles at 16px/tile) to match the farm scene grid.

#### Scenario: Farm scene fills viewport
- **WHEN** the farm scene (30×20 tiles) is loaded
- **THEN** the full scene SHALL be visible within the viewport without scrolling

### Requirement: InputMap actions registered
The project SHALL define all gameplay input actions in project.godot, including movement (4 directions), interaction, UI controls, hotbar slots, and zoom.

#### Scenario: Movement inputs respond
- **WHEN** the player presses W, A, S, D or arrow keys
- **THEN** the corresponding `move_up`, `move_left`, `move_down`, `move_right` actions SHALL be detected via `Input.is_action_pressed()`

#### Scenario: Hotbar slots 1-9 respond
- **WHEN** the player presses number keys 1 through 9
- **THEN** the corresponding `hotbar_1` through `hotbar_9` actions SHALL be detected

#### Scenario: Interact key responds
- **WHEN** the player presses E
- **THEN** the `interact` action SHALL be detected

#### Scenario: Zoom inputs respond
- **WHEN** the player scrolls mouse wheel up or down
- **THEN** the corresponding `zoom_in` or `zoom_out` actions SHALL be detected

### Requirement: Project directory structure
The project SHALL contain the standard directory structure with folders for scenes, scripts (including autoload), assets (sprites, tilesets, audio, ui, fonts), data, and addons.

#### Scenario: All required directories exist
- **WHEN** the project is opened in Godot editor
- **THEN** the FileSystem panel SHALL show: `scenes/`, `scripts/autoload/`, `scripts/crop/`, `scripts/character/`, `scripts/social/`, `scripts/inventory/`, `scripts/ui/`, `assets/sprites/`, `assets/tilesets/`, `assets/audio/`, `assets/ui/`, `assets/fonts/`, `data/`, `addons/`

### Requirement: Compatibility renderer selected
The project SHALL use `gl_compatibility` rendering method for maximum platform support and 2D pixel game suitability.

#### Scenario: Renderer is GL Compatibility
- **WHEN** project.godot is inspected
- **THEN** `renderer/rendering_method` SHALL be `"gl_compatibility"`
