# player-movement Specification

## Purpose

本规范定义 PRD9 玩家移动能力，覆盖玩家场景、占位视觉、移动输入、面朝方向、坐标与边界、移动事件和调试接口。

## Requirements

### Requirement: 玩家场景与占位视觉
系统 SHALL 提供可实例化的玩家角色场景，根节点 MUST 基于 `CharacterBody2D`，并使用 32×48 像素占位视觉表达玩家角色。

#### 场景:玩家场景文件存在
- **当** 项目文件被检查
- **那么** `res://scenes/character/player.tscn` MUST 存在
- **并且** `res://scripts/character/player_controller.gd` MUST 存在
- **并且** 玩家场景根节点 MUST 能够挂载 `PlayerController`

#### 场景:占位角色视觉尺寸稳定
- **当** 玩家场景被实例化
- **那么** 玩家 MUST 包含可见的 `ColorRect`、`Polygon2D` 或等价占位视觉
- **并且** 占位视觉 MUST 遵循 32×48 像素角色规格
- **并且** 玩家脚底点 MUST 作为 `CharacterBody2D.global_position` 的语义基准

#### 场景:玩家碰撞体存在
- **当** 玩家场景被打开
- **那么** 玩家 MUST 包含 `CollisionShape2D` 或等价碰撞形状
- **并且** 碰撞区域 MUST 位于角色脚底附近

### Requirement: 玩家移动输入与速度
`PlayerController` MUST 通过 InputMap 读取移动输入，并驱动玩家在 `_physics_process(delta)` 中移动。

#### 场景:读取 InputMap 移动输入
- **当** `move_right` 强度大于 `move_left` 强度
- **那么** 玩家输入向量的 x 分量 MUST 为正
- **当** `move_left` 强度大于 `move_right` 强度
- **那么** 玩家输入向量的 x 分量 MUST 为负
- **当** `move_down` 强度大于 `move_up` 强度
- **那么** 玩家输入向量的 y 分量 MUST 为正
- **当** `move_up` 强度大于 `move_down` 强度
- **那么** 玩家输入向量的 y 分量 MUST 为负

#### 场景:斜向移动归一化
- **当** 玩家同时按下水平和垂直移动 Action
- **那么** 输入向量长度 MUST 不大于 `1.0`
- **并且** 斜向移动速度 MUST 不超过单方向移动速度

#### 场景:移动开关禁用移动
- **当** 调用 `set_can_move(false)` 后继续输入移动 Action
- **那么** `get_input_vector()` MUST 返回 `Vector2.ZERO`
- **并且** 玩家速度 MUST 为 `Vector2.ZERO`

#### 场景:移动速度可配置
- **当** 调用 `set_move_speed(120.0)`
- **那么** `get_move_speed()` MUST 返回 `120.0`
- **并且** 后续移动 MUST 使用新的移动速度计算 `velocity`

### Requirement: 玩家面朝方向
`PlayerController` MUST 记录玩家面朝方向，并提供枚举、字符串 ID 与方向向量查询接口。

#### 场景:初始面朝方向为向下
- **当** 玩家初始化或调用 `reset_player()`
- **那么** `get_facing_direction_id()` MUST 返回 `down`
- **并且** `get_facing_vector()` MUST 返回 `Vector2i(0, 1)`

#### 场景:移动输入更新面朝方向
- **当** 玩家向上移动
- **那么** 面朝方向 MUST 更新为 `up`
- **当** 玩家向下移动
- **那么** 面朝方向 MUST 更新为 `down`
- **当** 玩家向左移动
- **那么** 面朝方向 MUST 更新为 `left`
- **当** 玩家向右移动
- **那么** 面朝方向 MUST 更新为 `right`

#### 场景:停止移动保持方向
- **当** 玩家最后一次有效移动方向为 `left`
- **并且** 当前输入向量变为 `Vector2.ZERO`
- **那么** `get_facing_direction_id()` MUST 继续返回 `left`

#### 场景:斜向输入选择主方向
- **当** 水平输入绝对值大于等于垂直输入绝对值
- **那么** 面朝方向 MUST 优先为 `left` 或 `right`
- **当** 垂直输入绝对值大于水平输入绝对值
- **那么** 面朝方向 MUST 为 `up` 或 `down`

### Requirement: 玩家坐标与地图边界
`PlayerController` MUST 以脚底世界坐标计算当前网格坐标，并限制玩家不离开 30×20、16 像素单格地图范围。

#### 场景:出生网格设置玩家位置
- **当** 调用 `set_spawn_grid(Vector2i(8, 13))`
- **那么** 玩家世界坐标 MUST 移动到该网格中心
- **并且** `get_current_grid_pos()` MUST 返回 `Vector2i(8, 13)`

#### 场景:世界坐标设置刷新网格坐标
- **当** 调用 `set_world_position(Vector2(136, 216))`
- **那么** 玩家脚底世界坐标 MUST 更新为 `Vector2(136, 216)`
- **并且** `get_current_grid_pos()` MUST 与 `FarmGridManager.world_to_grid(Vector2(136, 216))` 一致

#### 场景:面前地块计算
- **当** 玩家当前网格为 `Vector2i(8, 13)` 且面朝方向为 `down`
- **那么** `get_front_grid_pos()` MUST 返回 `Vector2i(8, 14)`
- **当** 面朝方向为 `up`
- **那么** `get_front_grid_pos()` MUST 返回 `Vector2i(8, 12)`
- **当** 面朝方向为 `left`
- **那么** `get_front_grid_pos()` MUST 返回 `Vector2i(7, 13)`
- **当** 面朝方向为 `right`
- **那么** `get_front_grid_pos()` MUST 返回 `Vector2i(9, 13)`

#### 场景:玩家不能离开地图边界
- **当** 玩家移动后脚底世界坐标小于 `Vector2(0, 0)` 或大于 `Vector2(480, 320)`
- **那么** 玩家脚底世界坐标 MUST 被钳制在地图范围内
- **并且** 玩家 MUST 不得持续停留在地图范围外

### Requirement: 玩家移动事件
`PlayerController` MUST 在玩家出生、移动状态和方向变化时通过 `EventBus` 广播类型化事件。

#### 场景:玩家出生事件
- **当** 玩家初始化或调用 `reset_player()` 完成出生点设置
- **那么** `EventBus.player_spawned(world_pos: Vector2, grid_pos: Vector2i)` MUST 被发射

#### 场景:玩家移动事件
- **当** 玩家世界坐标或当前网格坐标发生有效变化
- **那么** `EventBus.player_moved(world_pos: Vector2, grid_pos: Vector2i)` MUST 被发射

#### 场景:玩家方向变化事件
- **当** 玩家面朝方向从一个方向变化为另一个方向
- **那么** `EventBus.player_direction_changed(direction: String, direction_vector: Vector2i)` MUST 被发射

#### 场景:移动开关变化事件
- **当** `set_can_move(value)` 改变移动启用状态
- **那么** `EventBus.player_movement_enabled_changed(enabled: bool)` MUST 被发射

### Requirement: 玩家控制器调试接口
`PlayerController` MUST 提供用于测试方向、坐标和状态刷新的调试辅助接口。

#### 场景:调试设置方向
- **当** 调用 `debug_set_facing_direction("right")`
- **那么** `get_facing_direction_id()` MUST 返回 `right`
- **并且** `get_facing_vector()` MUST 返回 `Vector2i(1, 0)`

#### 场景:调试刷新状态
- **当** 调用 `debug_refresh_state()`
- **那么** 玩家当前网格、面前网格和交互目标 MUST 根据当前位置和面朝方向重新计算

#### 场景:缺少调试 Label 不影响移动
- **当** 玩家场景中不存在 `DebugLabel` 或田园场景未绑定玩家调试 Label
- **那么** 玩家移动、方向、坐标和事件逻辑 MUST 继续正常工作

### Requirement: UI 输入阻塞期间禁止玩家移动
`PlayerController` MUST 响应共享 UI 输入阻塞状态，并在阻塞型功能面板打开时停止玩法移动。

#### 场景:背包打开停止移动
- **当** `EventBus.ui_input_block_changed(true)` 被发射
- **那么** PlayerController MUST 停止当前速度
- **并且** 移动输入 MUST NOT 改变玩家位置

#### 场景:背包关闭恢复打开前状态
- **当** UI 阻塞开始前玩家移动已启用
- **并且** 随后发射 `EventBus.ui_input_block_changed(false)`
- **那么** PlayerController MUST 恢复移动启用状态

#### 场景:不覆盖其他系统的移动锁
- **当** UI 阻塞开始前玩家移动已经被禁用
- **并且** UI 阻塞随后结束
- **那么** PlayerController MUST 保持禁用
