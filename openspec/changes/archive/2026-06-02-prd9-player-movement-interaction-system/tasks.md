## 1. 事件与输入基础

- [x] 1.1 检查 `project.godot` 的 InputMap，确认 `move_up`、`move_down`、`move_left`、`move_right`、`interact` 可用，缺失时补齐
- [x] 1.2 在 `scripts/autoload/event_bus.gd` 中新增玩家出生、移动、方向变化、移动开关、交互目标变化、成功交互、交互失败和地块交互请求信号
- [x] 1.3 确认新增信号不替代既有作物生命周期信号和田园网格状态信号

## 2. 玩家控制器核心

- [x] 2.1 新增 `scripts/character/player_controller.gd`，定义玩家尺寸、移动速度、地图范围、交互距离、默认出生格和面朝方向枚举
- [x] 2.2 实现初始化接口：`set_spawn_grid()`、`set_world_position()`、`set_farm_grid_manager()`、`reset_player()`
- [x] 2.3 实现移动接口：`set_can_move()`、`is_movement_enabled()`、`get_input_vector()`、`get_move_speed()`、`set_move_speed()`、`is_moving()`
- [x] 2.4 在 `_physics_process(delta)` 中读取 InputMap、归一化斜向输入、更新速度、调用 `move_and_slide()` 并限制地图边界
- [x] 2.5 实现面朝方向接口：`get_facing_direction()`、`get_facing_direction_id()`、`get_facing_vector()`，并按主方向规则更新方向
- [x] 2.6 实现坐标接口：`get_current_grid_pos()`、`get_front_grid_pos()`、`get_feet_world_position()`，并复用 `FarmGridManager` 坐标转换
- [x] 2.7 在出生、移动、方向变化和移动开关变化时发射对应 `EventBus` 信号

## 3. 玩家交互系统

- [x] 3.1 在 `PlayerController` 中实现交互开关接口：`set_can_interact()`、`is_interaction_enabled()`
- [x] 3.2 实现 `update_interaction_target()`，优先根据面前一格生成 `farm_tile` 目标，并处理地图外、无 `FarmGridManager` 和空地块数据情况
- [x] 3.3 实现 `get_current_interaction_target()`、`has_interaction_target()`，保证无目标时返回空 Dictionary
- [x] 3.4 实现 `_unhandled_input(event)` 响应 `interact` Action 并调用 `try_interact()`
- [x] 3.5 实现 `try_interact()`，成功时发射 `player_interacted`，地块目标额外发射 `farm_tile_interaction_requested`，失败时发射 `player_interaction_failed`
- [x] 3.6 确保 `PlayerController` 不直接调用作物、背包、经济、经验、存档或地块修改业务接口
- [x] 3.7 实现 `debug_set_facing_direction()`、`debug_refresh_state()`、`debug_print_state()` 以支持测试和调试

## 4. 玩家场景与田园场景集成

- [x] 4.1 新增 `scenes/character/player.tscn`，根节点为 `CharacterBody2D` 并挂载 `PlayerController`
- [x] 4.2 为玩家场景添加 32×48 占位视觉、方向标记、脚底碰撞体、`InteractionArea` 和可选 `DebugLabel`
- [x] 4.3 修改 `scenes/farm/farm.tscn`，新增或复用 `EntityLayer` 并实例化 `Player`
- [x] 4.4 修改 `scenes/farm/farm.gd`，将 `FarmGridManager` 绑定给玩家，并设置默认出生点 `Vector2i(8, 13)`
- [x] 4.5 在田园场景调试 UI 中显示玩家世界坐标、网格坐标、面朝方向、面前地块和当前交互目标
- [x] 4.6 运行田园场景，确认占位玩家可见、可移动、不会离开地图边界，且按 `interact` 能触发交互请求日志或信号

## 5. 测试与验证

- [x] 5.1 新增 `scenes/test/test_player_controller.tscn`，包含测试入口、`FarmGridManager`、`Player` 和结果 Label
- [x] 5.2 新增 `scenes/test/test_player_controller.gd`，覆盖初始出生点、默认方向、设置世界坐标、设置出生格和四方向面前格计算
- [x] 5.3 补充移动速度、移动开关、交互开关、交互目标生成、地图外无目标、成功交互和失败交互测试
- [x] 5.4 补充 `EventBus` 玩家移动与交互相关信号测试，确认信号参数和触发时机符合规范
- [x] 5.5 运行 `test_player_controller.tscn`，确认测试通过且无运行时报错
- [x] 5.6 回归运行既有 FarmGridManager 和核心管理器测试，确认新增玩家交互能力未破坏既有系统

## 6. 文档与收尾

- [x] 6.1 更新相关 README 或调试说明，记录如何运行田园场景和 `PlayerController` 测试场景
- [x] 6.2 对照 PRD9 验收标准检查文件、移动、方向、坐标、交互、EventBus 和自动化测试项
- [x] 6.3 清理临时调试输出，保留必要 warning 与测试日志
