# farm-interaction-loop Specification

## Purpose
TBD - created by archiving change prd10-farm-interaction-loop. Update Purpose after archive.
## Requirements
### Requirement: FarmInteractionController 交互编排层
系统 MUST 提供 `FarmInteractionController` 作为田园地块业务交互的唯一编排层，负责连接输入请求、当前选择、作物业务、地块状态、库存状态、结果事件和调试显示。

#### Scenario: 控制器文件存在
- **WHEN** 项目文件被检查
- **THEN** `res://scripts/farm/farm_interaction_controller.gd` MUST 存在
- **AND** 该脚本 MUST 可挂载到 `Node` 或等价控制器节点

#### Scenario: 控制器可绑定网格与覆盖层
- **WHEN** 调用 `setup(grid_manager, overlay)`
- **THEN** 控制器 MUST 保存 `FarmGridManager` 引用
- **AND** 当 overlay 非空时 MUST 保存作物占位视觉层引用
- **AND** 控制器 MUST 能在无 overlay 时继续处理业务交互

#### Scenario: 控制器连接事件
- **WHEN** 调用 `connect_events()`
- **THEN** 控制器 MUST 监听 `EventBus.farm_tile_interaction_requested(tile_pos, target)`
- **AND** 控制器 MUST 监听作物生命周期事件以刷新占位视觉

### Requirement: 当前选择与模式管理
系统 MUST 支持 `NONE`、`PLANT`、`WATER`、`HARVEST`、`CLEAR` 交互模式，并提供种子、工具、清除模式和清空选择接口。

#### Scenario: 选择种子成功
- **WHEN** 调用 `select_seed("carrot")`
- **AND** `DataManager.get_crop("carrot")` 返回有效作物数据
- **AND** 若 `LevelManager` 存在则 `LevelManager.is_crop_unlocked("carrot")` 返回 `true`
- **THEN** 当前模式 MUST 变为 `PLANT`
- **AND** `selected_crop_id` MUST 为 `"carrot"`
- **AND** `selected_item_id` MUST 为 `"seed_carrot"`
- **AND** `EventBus.farm_interaction_mode_changed("PLANT", "seed_carrot", "carrot")` MUST 被发射

#### Scenario: 选择未解锁作物失败
- **WHEN** 调用 `select_seed(crop_id)`
- **AND** `LevelManager.is_crop_unlocked(crop_id)` 返回 `false`
- **THEN** 方法 MUST 返回 `false`
- **AND** 当前选择 MUST 保持不变

#### Scenario: 选择水壶成功
- **WHEN** 调用 `select_tool("watering_can")`
- **AND** `DataManager.get_item("watering_can")` 返回有效物品数据
- **THEN** 当前模式 MUST 变为 `WATER`
- **AND** `selected_item_id` MUST 为 `"watering_can"`
- **AND** `EventBus.farm_interaction_mode_changed("WATER", "watering_can", "")` MUST 被发射

#### Scenario: 选择清除模式
- **WHEN** 调用 `select_clear_mode()`
- **THEN** 当前模式 MUST 变为 `CLEAR`
- **AND** 当前种子选择 MUST 被清空
- **AND** 模式变化事件 MUST 被发射

#### Scenario: 清空选择
- **WHEN** 调用 `clear_selection()`
- **THEN** 当前模式 MUST 变为 `NONE`
- **AND** `selected_item_id` 和 `selected_crop_id` MUST 为空字符串

### Requirement: 地块交互请求入口
系统 MUST 通过统一入口处理鼠标点击和玩家面前地块请求，并返回结构化结果 Dictionary。

#### Scenario: 玩家交互请求进入控制器
- **WHEN** `EventBus.farm_tile_interaction_requested(tile_pos, target)` 被发射
- **THEN** `FarmInteractionController` MUST 调用 `request_tile_interaction(tile_pos, "player")` 或等价流程
- **AND** 该流程 MUST 执行与鼠标点击相同的业务规则

#### Scenario: 鼠标世界坐标转换为地块请求
- **WHEN** 调用 `request_mouse_tile_interaction(mouse_world_pos)`
- **THEN** 控制器 MUST 使用 `FarmGridManager.world_to_grid(mouse_world_pos)` 转换为 `Vector2i`
- **AND** MUST 调用统一地块请求入口处理

#### Scenario: 结果结构包含稳定字段
- **WHEN** 任意地块交互请求返回
- **THEN** 返回 Dictionary MUST 包含 `success`、`action`、`tile_pos`、`crop_id`、`item_id`、`reason` 和 `message` 字段
- **AND** 失败时 `reason` MUST 为稳定非空错误码

### Requirement: 自动动作解析
当 `auto_resolve_action` 为 `true` 时，系统 MUST 按成熟收获、枯萎清除、需水浇水、选中种子种植的顺序解析地块动作。

#### Scenario: 成熟作物优先收获
- **WHEN** 自动解析开启
- **AND** 目标地块存在可收获成熟作物
- **THEN** 控制器 MUST 执行收获动作
- **AND** 当前选择为水壶或种子时也不得覆盖成熟收获优先级

#### Scenario: 枯萎作物优先清除
- **WHEN** 自动解析开启
- **AND** 目标地块存在枯萎作物
- **AND** 该地块没有可收获成熟作物
- **THEN** 控制器 MUST 执行清除动作

#### Scenario: 需水作物执行浇水
- **WHEN** 自动解析开启
- **AND** 当前选择为水壶
- **AND** 目标地块作物需要浇水
- **THEN** 控制器 MUST 执行浇水动作

#### Scenario: 可种植空地执行种植
- **WHEN** 自动解析开启
- **AND** 当前选择了有效种子
- **AND** 目标地块可种植且没有作物
- **THEN** 控制器 MUST 执行种植动作

#### Scenario: 无可用动作返回失败
- **WHEN** 自动解析开启
- **AND** 目标地块不满足收获、清除、浇水或种植条件
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `no_action_available` 或更具体错误码

### Requirement: 种植业务规则
系统 MUST 在种植前校验地块、作物、等级和种子，并在成功后同步作物与地块状态。

#### Scenario: 空地种植成功
- **WHEN** 目标地块在地图内、已解锁、为可种植 `farm_plot`
- **AND** `CropManager.has_crop(tile_pos)` 返回 `false`
- **AND** 作物数据存在且等级已解锁
- **AND** 背包中存在至少 1 个 `seed_<crop_id>`
- **AND** `CropManager.plant_crop(tile_pos, crop_id)` 返回成功
- **THEN** 控制器 MUST 调用 `FarmGridManager.set_tile_occupied(tile_pos, true, FarmGridManager.tile_pos_to_key(tile_pos))`
- **AND** 返回结果 MUST 为 `success=true` 且 `action="plant"`
- **AND** `EventBus.farm_interaction_completed(result)` MUST 被发射

#### Scenario: 无种子种植失败不修改状态
- **WHEN** 背包中没有 `seed_<crop_id>`
- **AND** 请求种植该作物
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `seed_missing`
- **AND** CropManager、FarmGridManager 和 InventoryManager 状态 MUST 保持不变

#### Scenario: 已有作物重复种植失败
- **WHEN** `CropManager.has_crop(tile_pos)` 返回 `true`
- **AND** 请求种植作物
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `crop_exists`
- **AND** 不得消耗种子

#### Scenario: 锁定地块种植失败
- **WHEN** 目标地块未解锁或不可种植
- **AND** 请求种植作物
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `tile_locked` 或 `tile_not_plantable`

### Requirement: 浇水业务规则
系统 MUST 只允许对未成熟、未枯萎且需要水的作物浇水，并在成功后同步湿土表现。

#### Scenario: 作物浇水成功
- **WHEN** 目标地块存在未浇水的非成熟非枯萎作物
- **AND** 当前选择为水壶或自动解析决定浇水
- **AND** `CropManager.water_crop(tile_pos)` 返回成功
- **THEN** 控制器 MUST 调用 `FarmGridManager.mark_tile_watered(tile_pos)`
- **AND** 返回结果 MUST 为 `success=true` 且 `action="water"`
- **AND** `EventBus.farm_interaction_completed(result)` MUST 被发射

#### Scenario: 重复浇水失败
- **WHEN** 目标作物已经浇水或不需要浇水
- **AND** 请求浇水
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `crop_does_not_need_water`

#### Scenario: 无作物浇水失败
- **WHEN** 目标地块没有作物
- **AND** 请求浇水
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `crop_missing`

### Requirement: 收获业务规则
系统 MUST 只允许收获成熟作物，并以 CropManager 的成功返回作为清空地块的唯一依据。

#### Scenario: 成熟作物收获成功
- **WHEN** `CropManager.is_harvestable(tile_pos)` 返回 `true`
- **AND** `CropManager.harvest_crop(tile_pos)` 返回非空 crop_id
- **THEN** 控制器 MUST 调用 `FarmGridManager.clear_tile(tile_pos)`
- **AND** 返回结果 MUST 为 `success=true` 且 `action="harvest"`
- **AND** 背包 MUST 增加 `harvest_<crop_id>` 的数量
- **AND** `EventBus.farm_interaction_completed(result)` MUST 被发射

#### Scenario: 未成熟收获失败
- **WHEN** 目标地块存在作物但不可收获
- **AND** 请求收获
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `crop_not_mature`
- **AND** 地块和作物 MUST 保持不变

#### Scenario: 背包满收获失败不清地
- **WHEN** `CropManager.harvest_crop(tile_pos)` 因背包无法加入收获物而返回空字符串
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `inventory_full`
- **AND** FarmGridManager MUST NOT 清空该地块

### Requirement: 清除枯萎作物业务规则
系统 MUST 只允许清除枯萎作物，并在成功后恢复地块为空闲。

#### Scenario: 枯萎作物清除成功
- **WHEN** 目标地块存在 `WITHERED` 阶段作物
- **AND** 当前为清除模式或自动解析决定清除
- **AND** `CropManager.clear_crop(tile_pos)` 返回成功
- **THEN** 控制器 MUST 调用 `FarmGridManager.clear_tile(tile_pos)`
- **AND** 返回结果 MUST 为 `success=true` 且 `action="clear"`
- **AND** 不得向背包添加收获物

#### Scenario: 非枯萎作物清除失败
- **WHEN** 目标地块存在作物但阶段不是 `WITHERED`
- **AND** 请求清除
- **THEN** 控制器 MUST 返回 `success=false`
- **AND** `reason` MUST 为 `crop_not_withered`
- **AND** 作物和地块 MUST 保持不变

### Requirement: 错误反馈与事件
系统 MUST 为成功和失败交互发射不同事件，并通过稳定错误码支持调试 UI 和后续 HUD。

#### Scenario: 成功交互发射完成事件
- **WHEN** 种植、浇水、收获或清除成功
- **THEN** `EventBus.farm_interaction_completed(result)` MUST 被发射
- **AND** `result.success` MUST 为 `true`

#### Scenario: 失败交互发射失败事件
- **WHEN** 任意交互请求失败
- **THEN** `EventBus.farm_interaction_failed(result)` MUST 被发射
- **AND** `result.success` MUST 为 `false`
- **AND** `result.reason` MUST 为稳定非空错误码

#### Scenario: 支持 PRD10 错误码
- **WHEN** 控制器返回失败结果
- **THEN** `reason` MUST 能表达 `tile_out_of_bounds`、`tile_locked`、`tile_not_plantable`、`crop_exists`、`crop_missing`、`crop_locked`、`seed_missing`、`tool_missing`、`crop_does_not_need_water`、`crop_not_mature`、`inventory_full`、`crop_not_withered` 或 `no_action_available`

### Requirement: 占位视觉与调试显示
系统 MUST 在田园场景中用最小占位视觉展示作物阶段、浇水状态和交互结果。

#### Scenario: 作物覆盖层展示阶段
- **WHEN** 田园场景存在作物数据
- **THEN** `CropOverlay` 或等价节点 MUST 能显示种子、发芽、生长中、成熟和枯萎状态
- **AND** 显示方式 MUST 不依赖正式作物 Sprite

#### Scenario: 浇水状态可见
- **WHEN** 作物 `watered=true`
- **THEN** 占位视觉 MUST 通过颜色、边框、短文本或标记表达已浇水状态

#### Scenario: 调试 Label 显示选择与结果
- **WHEN** 田园场景运行
- **THEN** `InteractionDebugLabel` 或等价调试 UI MUST 显示当前模式、选中物品、最后结果和目标地块作物摘要

### Requirement: 调试加速与测试入口
系统 MUST 在 debug 模式或测试场景中提供快速验证完整闭环的入口。

#### Scenario: 调试选择入口可用
- **WHEN** debug 模式开启
- **THEN** 玩家 MUST 能通过数字键、按钮或等价测试接口选择胡萝卜种子、水壶、清除模式和清空选择

#### Scenario: 调试推进不在非 debug 模式启用
- **WHEN** debug 模式关闭
- **THEN** 强制成熟、推进时间或强制枯萎入口 MUST 不响应普通玩家输入

#### Scenario: 测试可直接调用接口
- **WHEN** `test_farm_interaction_controller.tscn` 运行
- **THEN** 测试脚本 MUST 能直接调用控制器业务接口而不依赖鼠标或键盘输入

### Requirement: 存档一致性修复
系统 MUST 保持 CropManager、FarmGridManager 和 InventoryManager 状态可被既有存档系统一致保存，并提供作物 / 地块状态修复。

#### Scenario: 作物存在时地块恢复占用
- **WHEN** `reconcile_grid_with_crops()` 发现 CropManager 某地块存在作物
- **AND** FarmGridManager 对应地块未标记 occupied
- **THEN** 控制器 MUST 将该地块恢复为 occupied

#### Scenario: 无作物但地块占用时清理地块
- **WHEN** `reconcile_grid_with_crops()` 发现 FarmGridManager 某地块标记 occupied
- **AND** CropManager 对应地块没有作物
- **THEN** 控制器 MUST 清理该地块为空闲

#### Scenario: PRD10 不新增持久化结构
- **WHEN** 游戏保存
- **THEN** PRD10 状态 MUST 通过 CropManager、FarmGridManager、InventoryManager、GameManager 或 LevelManager 既有导出接口保存
- **AND** 控制器自身的临时选择状态 MUST NOT 成为必须保存的数据

### Requirement: FarmInteractionController 测试场景
系统 MUST 提供 PRD10 自动化 / 半自动化测试场景，覆盖核心闭环和错误回滚。

#### Scenario: 测试场景文件存在
- **WHEN** 项目文件被检查
- **THEN** `res://scenes/test/test_farm_interaction_controller.tscn` MUST 存在
- **AND** `res://scenes/test/test_farm_interaction_controller.gd` MUST 存在

#### Scenario: 测试覆盖核心闭环
- **WHEN** `test_farm_interaction_controller.tscn` 运行
- **THEN** 测试 MUST 覆盖空地种植成功、无种子种植失败、未解锁地块种植失败、重复种植失败、浇水成功、重复浇水失败、未成熟收获失败、成熟收获成功、背包满收获失败、枯萎清除成功、自动交互优先级和存档一致性修复

