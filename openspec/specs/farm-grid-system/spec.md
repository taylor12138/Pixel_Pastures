# farm-grid-system Specification

## Purpose

本规范定义 PRD8 田园场景与网格系统能力，覆盖个人田园地图、可耕区域、地块状态、坐标转换、占位视觉、调试交互、存档接口和自动化测试。
## Requirements
### Requirement: 田园场景文件与节点结构
系统 SHALL 提供可运行的个人田园场景，用于展示 30×20 的田园占位地图并承载网格管理器与调试 UI。

#### 场景:田园场景文件存在
- **当** 项目文件被检查
- **那么** `res://scenes/farm/farm.tscn` 必须存在
- **并且** `res://scenes/farm/farm.gd` 必须存在
- **并且** 场景根节点必须能够挂载田园调试交互脚本

#### 场景:田园场景包含网格管理器和调试显示
- **当** `res://scenes/farm/farm.tscn` 被打开
- **那么** 场景必须包含可访问的 `FarmGridManager` 节点
- **并且** 场景必须包含用于显示当前地块坐标和状态的 Label 或等价调试 UI

### Requirement: 地图尺寸与固定布局
系统 SHALL 以 16 像素为单格尺寸初始化 30×20 的田园地图，并在固定位置定义可耕区域与可解锁区域。

#### 场景:地图常量符合 PRD8
- **当** FarmGridManager 初始化
- **那么** `TILE_SIZE` 必须等于 `16`
- **并且** `MAP_WIDTH` 必须等于 `30`
- **并且** `MAP_HEIGHT` 必须等于 `20`
- **并且** `FARM_ORIGIN` 必须等于 `Vector2i(5, 5)`

#### 场景:可耕区域边界正确
- **当** 查询 `Vector2i(5, 5)`、`Vector2i(24, 16)` 是否在可耕区域内
- **那么** FarmGridManager 必须返回 `true`
- **当** 查询 `Vector2i(4, 5)`、`Vector2i(25, 16)`、`Vector2i(5, 17)` 是否在可耕区域内
- **那么** FarmGridManager 必须返回 `false`

#### 场景:最大可解锁区域边界正确
- **当** 查询 `Vector2i(5, 5)`、`Vector2i(12, 14)` 是否在最大可解锁区域内
- **那么** FarmGridManager 必须返回 `true`
- **当** 查询 `Vector2i(13, 14)`、`Vector2i(12, 15)` 是否在最大可解锁区域内
- **那么** FarmGridManager 必须返回 `false`

### Requirement: 网格初始化数据
FarmGridManager SHALL 生成完整 30×20 地图数据，并按 PRD8 布局初始化草地、可耕地、锁定地块、空闲地块和不可用地块。

#### 场景:初始化生成 600 个 tile
- **当** 调用 `initialize_grid()`
- **那么** `tiles.size()` 必须等于 `600`
- **并且** 地图外坐标不得出现在 `tiles` 中

#### 场景:初始已解锁地块为空闲
- **当** 调用 `initialize_grid()`
- **那么** 从 `Vector2i(5, 5)` 到 `Vector2i(7, 8)` 的 12 个初始地块必须是 `terrain_type="farm_plot"`
- **并且** 这些地块的 `plot_state` 必须是 `empty`
- **并且** 这些地块的 `unlocked` 必须是 `true`

#### 场景:最大可解锁区未解锁地块为 locked
- **当** 调用 `initialize_grid()`
- **那么** 最大 8×10 可解锁区域内、初始 12 格之外的地块必须是 `plot_state="locked"`
- **并且** 这些地块的 `unlocked` 必须是 `false`

#### 场景:非可解锁可耕预留区不可用
- **当** 调用 `initialize_grid()`
- **那么** 位于 20×12 可耕区域内但不属于最大 8×10 可解锁区域的地块必须是 `terrain_type="farm_plot"`
- **并且** 这些地块的 `plot_state` 必须是 `unavailable`

#### 场景:非可耕地图区域为草地不可用
- **当** 调用 `initialize_grid()`
- **那么** 不在可耕区域内的地图格子必须默认为 `terrain_type="grass"`
- **并且** `plot_state` 必须是 `unavailable`

### Requirement: 地块查询接口
FarmGridManager SHALL 提供边界、地形、状态、解锁、可种植、可浇水、可清理和地块列表查询接口。

#### 场景:地图边界查询
- **当** 查询 `Vector2i(0, 0)` 和 `Vector2i(29, 19)`
- **那么** `is_in_map_bounds()` 必须返回 `true`
- **当** 查询 `Vector2i(-1, 0)`、`Vector2i(30, 0)`、`Vector2i(0, 20)`
- **那么** `is_in_map_bounds()` 必须返回 `false`

#### 场景:获取地块数据
- **当** 对地图内坐标调用 `get_tile_data(tile_pos)`
- **那么** 必须返回包含 `grid_pos`、`terrain_type`、`plot_state`、`unlocked`、`occupied`、`crop_tile_ref`、`last_updated_at` 的 Dictionary
- **当** 对地图外坐标调用 `get_tile_data(tile_pos)`
- **那么** 必须返回空 Dictionary

#### 场景:可种植判断
- **当** 地块在地图内、地形为 `farm_plot`、已解锁、未占用且状态为 `empty`、`dry_soil` 或 `wet_soil`
- **那么** `can_plant_on_tile(tile_pos)` 必须返回 `true`
- **当** 地块锁定、不可用、非可耕、已占用或地图外
- **那么** `can_plant_on_tile(tile_pos)` 必须返回 `false`

#### 场景:可浇水判断
- **当** 地块已解锁且状态为 `dry_soil` 或已被作物占用且未处于湿土表现
- **那么** `can_water_tile(tile_pos)` 必须返回 `true`
- **当** 地块锁定、不可用、地图外或已是 `wet_soil`
- **那么** `can_water_tile(tile_pos)` 必须返回 `false`

### Requirement: 地块修改接口
FarmGridManager SHALL 提供安全的地块状态修改、解锁、占用、清理、浇水和按数量解锁接口。

#### 场景:设置合法地块状态
- **当** 对已解锁可耕地调用 `set_plot_state(tile_pos, "dry_soil")`
- **那么** 方法必须返回 `true`
- **并且** 该地块的 `plot_state` 必须变为 `dry_soil`
- **并且** 必须发射地块状态变化事件

#### 场景:拒绝非法地块状态
- **当** 调用 `set_plot_state(tile_pos, "unknown_state")`
- **那么** 方法必须返回 `false`
- **并且** 原地块状态必须保持不变
- **并且** 系统必须通过 warning 或等价方式暴露问题

#### 场景:拒绝在非可耕地设置可操作状态
- **当** 对草地或地图外坐标调用 `set_plot_state(tile_pos, "dry_soil")`
- **那么** 方法必须返回 `false`
- **并且** 不得破坏原有地块数据

#### 场景:设置地块占用
- **当** 对已解锁可耕地调用 `set_tile_occupied(tile_pos, true, "5,5")`
- **那么** 方法必须返回 `true`
- **并且** 地块 `occupied` 必须为 `true`
- **并且** `crop_tile_ref` 必须保存为 `"5,5"`
- **并且** `plot_state` 必须同步为 `occupied`

#### 场景:清理地块
- **当** 对已解锁可耕地调用 `clear_tile(tile_pos)`
- **那么** 方法必须返回 `true`
- **并且** `plot_state` 必须恢复为 `empty`
- **并且** `occupied` 必须为 `false`
- **并且** `crop_tile_ref` 必须为空字符串

#### 场景:标记地块已浇水
- **当** 对合法地块调用 `mark_tile_watered(tile_pos)`
- **那么** 方法必须返回 `true`
- **并且** 地块状态必须变为 `wet_soil` 或保持可表达湿润视觉的合法占用状态

### Requirement: 地块解锁数量
FarmGridManager SHALL 按稳定 row-major 顺序解锁地块，且解锁数量不得超过最大 80 格。

#### 场景:按目标数量解锁
- **当** 调用 `unlock_plots_by_count(24)`
- **那么** 已解锁可耕地数量必须等于 `24`
- **并且** 解锁顺序必须从 `FARM_ORIGIN` 开始先从左到右再从上到下

#### 场景:解锁数量被限制到最大值
- **当** 调用 `unlock_plots_by_count(999)`
- **那么** 已解锁可耕地数量必须等于 `80`
- **并且** 不得解锁最大 8×10 区域之外的地块

#### 场景:解锁事件发射
- **当** 某个地块从锁定变为已解锁
- **那么** EventBus 必须发射 `farm_tile_unlocked(tile_pos: Vector2i)`
- **并且** 影响整体网格时必须发射 `farm_grid_changed()`

### Requirement: 坐标转换接口
FarmGridManager SHALL 提供网格坐标、世界坐标、屏幕坐标和 JSON key 之间的转换接口。

#### 场景:网格坐标转世界坐标
- **当** 调用 `grid_to_world(Vector2i(0, 0))`
- **那么** 必须返回 `Vector2(0, 0)`
- **当** 调用 `grid_to_world_center(Vector2i(0, 0))`
- **那么** 必须返回 `Vector2(8, 8)`

#### 场景:世界坐标转网格坐标
- **当** 调用 `world_to_grid(Vector2(0, 0))`
- **那么** 必须返回 `Vector2i(0, 0)`
- **当** 调用 `world_to_grid(Vector2(15, 15))`
- **那么** 必须返回 `Vector2i(0, 0)`
- **当** 调用 `world_to_grid(Vector2(16, 16))`
- **那么** 必须返回 `Vector2i(1, 1)`

#### 场景:负世界坐标转换
- **当** 调用 `world_to_grid()` 传入负坐标
- **那么** 必须返回对应负网格坐标
- **并且** 后续 `is_in_map_bounds()` 必须对该坐标返回 `false`

#### 场景:坐标 key 转换
- **当** 调用 `tile_pos_to_key(Vector2i(5, 8))`
- **那么** 必须返回 `"5,8"`
- **当** 调用 `key_to_tile_pos("5,8")`
- **那么** 必须返回 `Vector2i(5, 8)`

### Requirement: 占位视觉渲染
田园场景 SHALL 用最小占位视觉展示地图、地块状态、悬停和选中反馈，且所有格子必须 16 像素对齐。

#### 场景:地图可视化显示
- **当** 运行田园场景
- **那么** 玩家必须能看到 30×20 的色块地图
- **并且** 草地、锁定地块、空闲地块、干土地块、湿土地块和占用地块必须可通过颜色区分

#### 场景:像素对齐
- **当** 渲染任意地块
- **那么** 每个地块视觉区域必须严格按 16×16 像素绘制
- **并且** 地块边界必须清晰可辨

#### 场景:鼠标悬停高亮
- **当** 鼠标移动到地图内地块
- **那么** 场景必须显示当前地块高亮或调试文字
- **并且** 必须更新当前悬停地块数据

### Requirement: 鼠标调试交互
田园场景 SHALL 提供最低限度调试交互，用于显示当前地块信息并可在已解锁地块上循环切换调试状态。

#### 场景:鼠标在地图内显示地块信息
- **当** 鼠标悬停在地图内地块
- **那么** 调试 UI 必须显示 Tile、Terrain、State、Unlocked、Occupied 信息

#### 场景:鼠标在地图外显示越界
- **当** 鼠标移动到地图范围外
- **那么** 调试 UI 必须显示 `out of bounds`
- **并且** 不得发射选中信号

#### 场景:点击已解锁地块循环状态
- **当** Debug 模式开启并左键点击已解锁可耕地
- **那么** 场景必须选中该地块
- **并且** 可按 `empty → dry_soil → wet_soil → occupied → empty` 的固定顺序循环状态

#### 场景:点击锁定或不可用地块不修改状态
- **当** 左键点击 `locked` 或 `unavailable` 地块
- **那么** 场景必须只显示该地块状态
- **并且** 不得把该地块切换为可操作状态

### Requirement: FarmGridManager 存档接口
FarmGridManager SHALL 提供 JSON 可序列化的导出数据和健壮的导入恢复逻辑。

#### 场景:导出存档数据
- **当** 调用 `export_save_data()`
- **那么** 返回 Dictionary 必须包含 `schema_version`、`map_width`、`map_height`、`tile_size`、`farm_origin`、`unlocked_plot_count`、`tiles`
- **并且** `tiles` 必须使用 `"x,y"` 字符串 key
- **并且** 导出数据禁止包含 Node、Resource、Signal、Callable 或原始 Vector2i 对象

#### 场景:导入存档恢复状态
- **当** 先将某地块导出为 `wet_soil`，再重置网格并调用 `import_save_data(data)`
- **那么** 该地块必须恢复为 `wet_soil`
- **并且** 导入后必须刷新视觉并发射整体网格变化事件

#### 场景:导入缺失或空数据回退默认值
- **当** 调用 `import_save_data({})` 或传入缺少必要字段的数据
- **那么** FarmGridManager 必须使用 `reset_to_default()` 或等价默认初始化逻辑
- **并且** 项目不得崩溃

#### 场景:导入非法坐标跳过
- **当** 导入数据包含非法坐标 key 或地图外 tile
- **那么** FarmGridManager 必须跳过该 tile
- **并且** 必须通过 warning 或等价方式暴露问题
- **并且** 其他合法 tile 必须继续导入

### Requirement: FarmGridManager 自动化测试
系统 SHALL 提供 FarmGridManager 自动化测试场景和脚本，覆盖 PRD8 核心验收行为。

#### 场景:测试场景文件存在
- **当** 项目文件被检查
- **那么** `res://scenes/test/test_farm_grid_manager.tscn` 必须存在
- **并且** `res://scenes/test/test_farm_grid_manager.gd` 必须存在

#### 场景:测试覆盖核心行为
- **当** FarmGridManager 测试场景运行
- **那么** 测试必须覆盖网格初始化、地图边界、可耕区域边界、最大可解锁区域边界、初始解锁数量、坐标转换、key 转换、地块查询、状态修改、非法状态拒绝、可种植判断、占用、清理、浇水、按数量解锁、导入导出和 EventBus 信号

### Requirement: FarmGridManager supports player position queries
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

### Requirement: FarmGridManager remains tile state owner
`PlayerController` SHALL use FarmGridManager only for coordinate conversion, bounds checks, and tile data reads; tile mutation ownership MUST remain in FarmGridManager and crop/business systems.

#### 场景:玩家控制器不直接修改 tiles
- **WHEN** `PlayerController` refreshes position or interaction target data
- **THEN** it SHALL NOT directly mutate `FarmGridManager.tiles`
- **AND** it SHALL NOT call tile mutation APIs such as `set_plot_state()`, `set_tile_occupied()`, `clear_tile()`, or `mark_tile_watered()` as part of PRD9 interaction detection

#### 场景:未来业务系统通过请求信号执行修改
- **WHEN** `farm_tile_interaction_requested(tile_pos, target)` is emitted
- **THEN** future systems MAY decide whether to call FarmGridManager mutation APIs
- **AND** FarmGridManager SHALL remain responsible for validating and emitting tile-state events when those mutations occur

### Requirement: Farm grid synchronizes with crop interaction operations
FarmGridManager MUST remain the owner of tile state while supporting PRD10 interaction operations that mirror successful CropManager business changes.

#### Scenario: Successful planting marks tile occupied
- **WHEN** `FarmInteractionController` successfully plants a crop through `CropManager.plant_crop(tile_pos, crop_id)`
- **THEN** FarmGridManager MUST accept `set_tile_occupied(tile_pos, true, crop_tile_ref)`
- **AND** the tile MUST become occupied without overwriting CropManager crop data

#### Scenario: Successful watering marks wet visual state
- **WHEN** `FarmInteractionController` successfully waters a crop through `CropManager.water_crop(tile_pos)`
- **THEN** FarmGridManager MUST accept `mark_tile_watered(tile_pos)`
- **AND** the tile MUST express wet soil or equivalent watered visual state

#### Scenario: Successful harvest clears tile
- **WHEN** `FarmInteractionController` successfully harvests a mature crop and `CropManager.harvest_crop(tile_pos)` returns a crop_id
- **THEN** FarmGridManager MUST accept `clear_tile(tile_pos)`
- **AND** the tile MUST become unoccupied and plantable if it is an unlocked farm plot

#### Scenario: Successful clear restores tile
- **WHEN** `FarmInteractionController` successfully clears a withered crop
- **THEN** FarmGridManager MUST accept `clear_tile(tile_pos)`
- **AND** the tile MUST become unoccupied and plantable if it is an unlocked farm plot

### Requirement: Debug tile cycling must not corrupt real crop data
田园场景的 PRD8 调试点击循环 MUST NOT override PRD10 的真实作物交互闭环。

#### Scenario: PRD10 controller consumes left click in normal prototype mode
- **WHEN** `FarmInteractionController` is active in `farm.tscn`
- **AND** the player left-clicks a farm tile
- **THEN** the click MUST be routed to PRD10 interaction handling
- **AND** the PRD8 `empty -> dry_soil -> wet_soil -> occupied -> empty` debug cycle MUST NOT run for that click

#### Scenario: Debug cycling cannot alter tile with crop data
- **WHEN** any debug tile-state cycle remains enabled
- **AND** `CropManager.has_crop(tile_pos)` returns `true`
- **THEN** the debug cycle MUST NOT clear, occupy, unlock, wet, or otherwise mutate that tile
- **AND** PRD10 crop interaction state MUST remain authoritative

### Requirement: Farm grid can be reconciled from crop data
FarmGridManager MUST expose enough mutation and query behavior for PRD10 to repair mismatches between tile occupancy and CropManager crop records.

#### Scenario: Reconcile can restore occupied tile
- **WHEN** CropManager has crop data at an unlocked farm tile
- **AND** FarmGridManager reports the tile as not occupied
- **THEN** PRD10 reconciliation MUST be able to call FarmGridManager APIs to mark that tile occupied

#### Scenario: Reconcile can clear stale occupied tile
- **WHEN** FarmGridManager reports an unlocked farm tile as occupied
- **AND** CropManager has no crop data for that tile
- **THEN** PRD10 reconciliation MUST be able to call FarmGridManager APIs to clear that tile

