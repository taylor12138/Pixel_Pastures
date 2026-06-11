## MODIFIED Requirements

### Requirement: 田园场景文件与节点结构
系统 SHALL 提供可运行的个人田园场景，用于展示 30×20 的田园占位地图，并承载可向 SaveManager 注册的网格管理器与调试 UI。

#### Scenario: 田园场景文件存在
- **WHEN** 项目文件被检查
- **THEN** `res://scenes/farm/farm.tscn` SHALL 存在
- **AND** `res://scenes/farm/farm.gd` SHALL 存在
- **AND** 场景根节点 SHALL 能够挂载田园调试交互脚本

#### Scenario: 田园场景包含网格管理器和调试显示
- **WHEN** `res://scenes/farm/farm.tscn` 被打开
- **THEN** 场景 SHALL 包含可访问的 `FarmGridManager` 节点
- **AND** 场景 SHALL 包含用于显示当前地块坐标和状态的 Label 或等价调试 UI

#### Scenario: 田园场景注册网格提供者
- **WHEN** 田园场景进入树并准备初始化
- **THEN** `farm.gd` SHALL 向 SaveManager 注册场景内 FarmGridManager
- **AND** 场景退出树时 SHALL 注销该 FarmGridManager

### Requirement: 网格初始化数据
FarmGridManager SHALL 生成完整 30×20 地图数据，并按 PRD8 布局初始化默认网格；农场场景仅在没有可恢复的存档网格时使用该默认初始化。

#### Scenario: 初始化生成 600 个 tile
- **WHEN** 调用 `initialize_grid()`
- **THEN** `tiles.size()` SHALL 等于 `600`
- **AND** 地图外坐标不得出现在 `tiles` 中

#### Scenario: 初始已解锁地块为空闲
- **WHEN** 调用 `initialize_grid()`
- **THEN** 从 `Vector2i(5, 5)` 到 `Vector2i(7, 8)` 的 12 个初始地块 SHALL 是 `terrain_type="farm_plot"`
- **AND** 这些地块的 `plot_state` SHALL 是 `empty`
- **AND** 这些地块的 `unlocked` SHALL 是 `true`

#### Scenario: 最大可解锁区未解锁地块为 locked
- **WHEN** 调用 `initialize_grid()`
- **THEN** 最大 8×10 可解锁区域内、初始 12 格之外的地块 SHALL 是 `plot_state="locked"`
- **AND** 这些地块的 `unlocked` SHALL 是 `false`

#### Scenario: 非可解锁可耕预留区不可用
- **WHEN** 调用 `initialize_grid()`
- **THEN** 位于 20×12 可耕区域内但不属于最大 8×10 可解锁区域的地块 SHALL 是 `terrain_type="farm_plot"`
- **AND** 这些地块的 `plot_state` SHALL 是 `unavailable`

#### Scenario: 非可耕地图区域为草地不可用
- **WHEN** 调用 `initialize_grid()`
- **THEN** 不在可耕区域内的地图格子 SHALL 默认为 `terrain_type="grass"`
- **AND** `plot_state` SHALL 是 `unavailable`

#### Scenario: 进入农场恢复存档网格
- **WHEN** 农场场景注册 FarmGridManager 且 SaveManager 有有效的待恢复 `farm_grid`
- **THEN** 场景 SHALL 使用 `import_save_data()` 恢复存档网格
- **AND** 场景 SHALL NOT 随后调用 `initialize_grid()` 覆盖恢复结果

#### Scenario: 进入农场无存档网格时初始化默认值
- **WHEN** 农场场景注册 FarmGridManager 且 SaveManager 没有有效的待恢复 `farm_grid`
- **THEN** 场景 SHALL 调用 `initialize_grid()` 或等价默认初始化
- **AND** 初始网格 SHALL 包含 12 个已解锁空地

### Requirement: FarmGridManager 存档接口
FarmGridManager SHALL 提供 JSON 可序列化的导出数据和健壮的导入恢复逻辑，并能作为 SaveManager 注册的场景级状态提供者。

#### Scenario: 导出存档数据
- **WHEN** 调用 `export_save_data()`
- **THEN** 返回 Dictionary SHALL 包含 `schema_version`、`map_width`、`map_height`、`tile_size`、`farm_origin`、`unlocked_plot_count`、`tiles`
- **AND** `tiles` SHALL 使用 `"x,y"` 字符串 key
- **AND** 导出数据不得包含 Node、Resource、Signal、Callable 或原始 Vector2i 对象

#### Scenario: 导入存档恢复状态
- **WHEN** 先将扩展解锁数量、`dry_soil`、`wet_soil` 或 occupied 地块导出，再重置网格并调用 `import_save_data(data)`
- **THEN** 解锁数量和对应地块状态 SHALL 恢复为保存值
- **AND** 导入后 SHALL 刷新视觉并发射整体网格变化事件

#### Scenario: 导入缺失或空数据回退默认值
- **WHEN** 调用 `import_save_data({})` 或传入缺少必要字段的数据
- **THEN** FarmGridManager SHALL 使用 `reset_to_default()` 或等价默认初始化逻辑
- **AND** 项目不得崩溃

#### Scenario: 导入非法坐标跳过
- **WHEN** 导入数据包含非法坐标 key 或地图外 tile
- **THEN** FarmGridManager SHALL 跳过该 tile
- **AND** SHALL 通过 warning 或等价方式暴露问题
- **AND** 其他合法 tile SHALL 继续导入

#### Scenario: 注销前导出最新状态
- **WHEN** FarmGridManager 即将随农场场景退出并被 SaveManager 注销
- **THEN** 其 `export_save_data()` SHALL 能返回退出时的最新网格状态
- **AND** 该状态 SHALL 可用于离开农场后的后续保存
