## ADDED Requirements

### 需求:FarmGridManager supports player position queries
FarmGridManager SHALL provide stable coordinate and tile-data query behavior for player movement and interaction systems without transferring tile ownership to `PlayerController`.

#### 场景:玩家脚底世界坐标可换算当前地块
- **WHEN** `PlayerController` passes the player's feet world position to `FarmGridManager.world_to_grid(world_pos)`
- **THEN** FarmGridManager SHALL return the corresponding `Vector2i` grid position using the existing 16-pixel tile size
- **AND** the result SHALL be compatible with `is_in_map_bounds(tile_pos)`

#### 场景:玩家出生格可换算为世界中心
- **WHEN** `PlayerController` calls `FarmGridManager.grid_to_world_center(Vector2i(8, 13))`
- **THEN** FarmGridManager SHALL return the world-space center of that tile
- **AND** the returned position SHALL be suitable for assigning to the player's feet `global_position`

#### 场景:玩家面前地块可查询目标数据
- **WHEN** `PlayerController` queries a map-bounds front tile with `get_tile_data(tile_pos)`
- **THEN** FarmGridManager SHALL return a Dictionary containing at least `terrain_type`, `plot_state`, `unlocked`, and `occupied`
- **AND** PlayerController SHALL be able to copy these fields into a `farm_tile` interaction target

#### 场景:地图外玩家交互查询为空
- **WHEN** `PlayerController` queries a front tile outside map bounds
- **THEN** `FarmGridManager.is_in_map_bounds(tile_pos)` SHALL return `false`
- **AND** `FarmGridManager.get_tile_data(tile_pos)` SHALL return an empty Dictionary

### 需求:FarmGridManager remains tile state owner
`PlayerController` SHALL use FarmGridManager only for coordinate conversion, bounds checks, and tile data reads; tile mutation ownership MUST remain in FarmGridManager and crop/business systems.

#### 场景:玩家控制器不直接修改 tiles
- **WHEN** `PlayerController` refreshes position or interaction target data
- **THEN** it SHALL NOT directly mutate `FarmGridManager.tiles`
- **AND** it SHALL NOT call tile mutation APIs such as `set_plot_state()`, `set_tile_occupied()`, `clear_tile()`, or `mark_tile_watered()` as part of PRD9 interaction detection

#### 场景:未来业务系统通过请求信号执行修改
- **WHEN** `farm_tile_interaction_requested(tile_pos, target)` is emitted
- **THEN** future systems MAY decide whether to call FarmGridManager mutation APIs
- **AND** FarmGridManager SHALL remain responsible for validating and emitting tile-state events when those mutations occur

## MODIFIED Requirements

## REMOVED Requirements
