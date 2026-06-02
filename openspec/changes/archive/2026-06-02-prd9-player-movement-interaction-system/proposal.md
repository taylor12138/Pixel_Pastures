## 为什么

PRD9 需要在已完成的田园场景与网格系统基础上补齐玩家可控角色，让项目从系统验证推进到可视化可玩原型。当前项目已有作物、背包、经济、等级、存档、时间与农田网格等基础系统，但缺少角色移动、面朝方向、交互目标识别和统一交互事件，导致后续种植、浇水、收获等闭环缺少稳定的输入与空间基础。

本变更将建立玩家角色移动与交互请求基础，使玩家可以在 30×20 田园地图内移动、面向地块并通过 `interact` 发起交互事件，为 PRD10 的种植 / 浇水 / 收获业务闭环提供入口。

## 变更内容

- 新增基于 `CharacterBody2D` 的占位玩家角色场景，使用 32×48 像素色块或简单几何体表示角色。
- 新增 `PlayerController`，负责 InputMap 移动输入、4 方向面朝方向、移动开关、地图边界限制、当前格 / 面前格计算、交互目标刷新和交互输入处理。
- 将玩家角色挂入 `scenes/farm/farm.tscn`，并与 `FarmGridManager` 绑定以复用网格坐标转换、地图边界和地块数据查询能力。
- 新增最小调试显示，展示玩家世界坐标、网格坐标、面朝方向、面前地块与当前交互目标。
- 扩展 `EventBus` 玩家移动与交互相关信号，包括出生、移动、方向变化、目标变化、成功交互、交互失败和地块交互请求。
- 新增 `PlayerController` 自动化 / 半自动化测试场景与脚本，覆盖出生点、方向、坐标、移动开关、交互开关、交互目标和 EventBus 信号。
- 不实现正式角色 Sprite、动画状态机、种植 / 浇水 / 收获业务效果、快捷栏工具选择、NPC 对话、音效或多人同步。

## 功能 (Capabilities)

### 新增功能
- `player-movement`: 玩家角色移动控制、面朝方向、地图边界与移动状态接口。
- `player-interaction`: 玩家交互范围、面前地块目标识别、交互请求处理与 EventBus 广播。

### 修改功能
- `event-bus`: 新增玩家移动与交互相关全局信号，供田园场景、调试 UI 和后续 PRD10 业务系统监听。
- `farm-grid-system`: 扩展现有农田网格系统的使用场景，使其为玩家当前位置、面前地块与交互目标识别提供规范化查询基础；不改变既有网格数据所有权和地块状态修改职责。

## 影响

- 新增文件：`pixel-farm/scenes/character/player.tscn`、`pixel-farm/scripts/character/player_controller.gd`、`pixel-farm/scenes/test/test_player_controller.tscn`、`pixel-farm/scenes/test/test_player_controller.gd`。
- 修改文件：`pixel-farm/scenes/farm/farm.tscn`、`pixel-farm/scenes/farm/farm.gd`、`pixel-farm/scripts/autoload/event_bus.gd`。
- 可选修改：`pixel-farm/project.godot`，仅用于确认或补齐 PRD9 依赖的 `move_up`、`move_down`、`move_left`、`move_right`、`interact` 输入 Action。
- 运行时影响：田园场景将出现可移动占位玩家角色，交互输入将通过 `EventBus` 广播请求，但不会直接触发作物、背包、金币、经验或存档业务变更。
- 后续影响：PRD10 可监听 `farm_tile_interaction_requested` 实现地块业务交互；PRD15 可在不破坏 `PlayerController` 公共接口的前提下替换正式角色 Sprite 和动画。
