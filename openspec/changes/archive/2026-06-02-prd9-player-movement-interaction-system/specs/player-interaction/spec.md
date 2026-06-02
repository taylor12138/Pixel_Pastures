## ADDED Requirements

### 需求:玩家交互目标结构
`PlayerController` 必须维护当前交互目标，目标数据必须使用可扩展的 Dictionary 结构表达地块、对象或后续扩展目标。

#### 场景:交互目标包含必要字段
- **当** 玩家面前存在可查询的地图内地块
- **那么** `get_current_interaction_target()` 必须返回 Dictionary
- **并且** Dictionary 必须包含 `type`、`grid_pos`、`world_pos`、`node` 和 `priority` 字段
- **并且** 地块目标的 `type` 必须为 `farm_tile`

#### 场景:地块目标包含地块状态字段
- **当** 当前交互目标为 `farm_tile`
- **那么** 目标必须包含 `terrain_type`、`plot_state`、`unlocked` 和 `occupied` 字段
- **并且** 这些字段必须来自 `FarmGridManager.get_tile_data(tile_pos)` 或等价查询结果

#### 场景:无目标时返回空字典
- **当** 玩家没有可交互目标
- **那么** `get_current_interaction_target()` 必须返回空 Dictionary
- **并且** `has_interaction_target()` 必须返回 `false`

### 需求:面前地块交互目标识别
`PlayerController` 必须优先使用玩家面朝方向前方一格识别 `farm_tile` 交互目标。

#### 场景:面前地块在地图内生成目标
- **当** 玩家当前网格为 `Vector2i(5, 5)` 且面朝方向为 `right`
- **并且** `FarmGridManager.get_tile_data(Vector2i(6, 5))` 返回非空数据
- **那么** `update_interaction_target()` 必须生成 `farm_tile` 目标
- **并且** 目标的 `grid_pos` 必须为 `Vector2i(6, 5)`

#### 场景:面前地块在地图外清空目标
- **当** 玩家面前一格不在 `FarmGridManager.is_in_map_bounds()` 范围内
- **那么** `update_interaction_target()` 必须清空当前交互目标
- **并且** `has_interaction_target()` 必须返回 `false`

#### 场景:未绑定 FarmGridManager 时不生成地块目标
- **当** `PlayerController` 未绑定 `FarmGridManager`
- **那么** `update_interaction_target()` 必须保持交互目标为空
- **并且** 玩家移动逻辑必须不受影响

#### 场景:交互目标变化事件
- **当** 当前交互目标从空变为非空、从非空变为空或目标坐标发生变化
- **那么** `EventBus.player_interaction_target_changed(target: Dictionary)` 必须被发射

### 需求:玩家交互输入处理
`PlayerController` 必须响应 `interact` InputMap Action，并通过 `try_interact()` 统一处理交互请求。

#### 场景:按下交互 Action 调用交互逻辑
- **当** 玩家按下 `interact` Action
- **那么** `PlayerController` 必须调用 `try_interact()` 或执行等价交互请求流程

#### 场景:交互禁用时失败
- **当** 调用 `set_can_interact(false)` 后玩家尝试交互
- **那么** `try_interact()` 必须返回 `false`
- **并且** `EventBus.player_interaction_failed(reason: String)` 必须以 `interaction_disabled` 原因被发射

#### 场景:无目标时交互失败
- **当** `can_interact` 为 `true` 且当前没有交互目标
- **那么** `try_interact()` 必须返回 `false`
- **并且** `EventBus.player_interaction_failed(reason: String)` 必须以 `no_target` 原因被发射

#### 场景:有目标时交互成功
- **当** `can_interact` 为 `true` 且当前存在交互目标
- **那么** `try_interact()` 必须返回 `true`
- **并且** `EventBus.player_interacted(target: Dictionary)` 必须被发射

#### 场景:地块目标额外发射地块请求
- **当** 成功交互目标的 `type` 为 `farm_tile`
- **那么** `EventBus.farm_tile_interaction_requested(tile_pos: Vector2i, target: Dictionary)` 必须被发射
- **并且** `tile_pos` 必须等于目标的 `grid_pos`

### 需求:玩家交互职责边界
`PlayerController` 必须只识别交互目标并广播请求，禁止直接执行作物、背包、经济、经验或存档业务。

#### 场景:交互不直接种植作物
- **当** 玩家对空地块执行 `try_interact()`
- **那么** `PlayerController` 禁止直接调用 `CropManager.plant_crop()`
- **并且** 禁止直接修改地块为已占用作物状态

#### 场景:交互不直接浇水或收获
- **当** 玩家对已有作物或可浇水地块执行 `try_interact()`
- **那么** `PlayerController` 禁止直接调用 `CropManager.water_crop()`、`CropManager.harvest_crop()` 或等价业务方法

#### 场景:交互不消耗资源
- **当** 玩家执行任意交互请求
- **那么** `PlayerController` 禁止直接扣除背包物品、金币或经验
- **并且** 具体业务效果必须由后续监听 `farm_tile_interaction_requested` 的系统处理

### 需求:玩家交互调试显示
田园场景或玩家场景必须提供最小调试显示，用于展示玩家坐标、网格坐标、面朝方向、面前地块和当前交互目标。

#### 场景:存在目标时显示目标信息
- **当** 玩家当前存在 `farm_tile` 交互目标
- **那么** 调试 Label 必须显示目标类型、目标坐标和地块状态信息

#### 场景:不存在目标时显示 none
- **当** 玩家当前没有交互目标
- **那么** 调试 Label 必须显示 `Target: none` 或等价无目标文本

#### 场景:调试显示缺失不影响交互
- **当** 调试 Label 不存在或未绑定
- **那么** `update_interaction_target()` 和 `try_interact()` 必须继续正常工作

### 需求:玩家交互测试场景
系统必须提供 `PlayerController` 测试场景和脚本，覆盖交互目标、交互开关和 EventBus 信号。

#### 场景:测试场景文件存在
- **当** 项目文件被检查
- **那么** `res://scenes/test/test_player_controller.tscn` 必须存在
- **并且** `res://scenes/test/test_player_controller.gd` 必须存在

#### 场景:测试覆盖交互核心行为
- **当** `test_player_controller.tscn` 运行
- **那么** 测试必须覆盖初始出生点、面朝方向、当前格、面前格、移动开关、交互开关、交互目标生成、地图外无目标、成功交互、失败交互和 EventBus 信号

## MODIFIED Requirements

## REMOVED Requirements
