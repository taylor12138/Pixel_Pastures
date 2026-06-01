# event-bus Specification Delta

## ADDED Requirements

### Requirement: Farm grid signals
EventBus SHALL 定义田园网格与地块状态相关的类型化信号，使场景、UI、测试和后续交互系统能够通过事件观察地块变化，而不是直接依赖 FarmGridManager 内部数据。

#### 场景:田园网格初始化信号
- **WHEN** FarmGridManager 完成 30×20 网格初始化
- **THEN** EventBus SHALL emit `farm_grid_initialized(width: int, height: int)`
- **AND** `width` SHALL be `30`
- **AND** `height` SHALL be `20`

#### 场景:田园地块悬停信号
- **WHEN** 鼠标悬停地块发生变化且新地块位于地图范围内
- **THEN** EventBus SHALL emit `farm_tile_hovered(tile_pos: Vector2i, tile_data: Dictionary)`
- **AND** `tile_data` SHALL describe the hovered tile

#### 场景:田园地块选中信号
- **WHEN** 玩家或调试交互选中地图范围内地块
- **THEN** EventBus SHALL emit `farm_tile_selected(tile_pos: Vector2i, tile_data: Dictionary)`
- **AND** 地图外点击 SHALL NOT emit `farm_tile_selected`

#### 场景:田园地块状态变化信号
- **WHEN** FarmGridManager changes a tile `plot_state` from one value to another
- **THEN** EventBus SHALL emit `farm_tile_state_changed(tile_pos: Vector2i, old_state: String, new_state: String)`
- **AND** the signal SHALL NOT be emitted when the requested state equals the current state

#### 场景:田园地块解锁信号
- **WHEN** a farm plot changes from locked to unlocked
- **THEN** EventBus SHALL emit `farm_tile_unlocked(tile_pos: Vector2i)` once for that tile

#### 场景:田园地块占用变化信号
- **WHEN** FarmGridManager changes a tile occupied flag
- **THEN** EventBus SHALL emit `farm_tile_occupied_changed(tile_pos: Vector2i, occupied: bool)`
- **AND** `occupied` SHALL match the tile's new occupied state

#### 场景:田园网格整体变化信号
- **WHEN** an operation changes grid-wide state such as initialization, import, reset, bulk unlock, or a tile mutation that affects rendered grid state
- **THEN** EventBus SHALL emit `farm_grid_changed()`

### Requirement: Farm grid signals do not replace crop lifecycle signals
田园网格事件 SHALL 只描述场景网格、地块状态、解锁和占用变化，禁止替代或移除既有作物生命周期信号。

#### 场景:作物信号保持可用
- **WHEN** PRD8 farm grid signals are added
- **THEN** EventBus SHALL still define crop lifecycle signals including `crop_planted`, `crop_watered`, `crop_harvested`, and `crop_cleared`
- **AND** farm grid signals SHALL NOT change those existing crop signal signatures

#### 场景:后续种植交互可以同时广播作物和地块事件
- **WHEN** a future planting, watering, harvesting, or clearing interaction changes both crop state and tile state
- **THEN** crop lifecycle signals SHALL remain responsible for crop behavior
- **AND** farm grid signals SHALL remain responsible for tile state, unlock, occupancy, and grid rendering behavior
