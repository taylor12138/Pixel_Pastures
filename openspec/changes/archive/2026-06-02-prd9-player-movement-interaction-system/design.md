## 上下文

项目当前已通过 PRD1-PRD8 建立 Godot 4.4+ / 4.6 兼容的像素田园基础框架，包括全局管理器、作物状态、背包、经济、等级、存档、时间系统以及 30×20、16 像素单格的田园网格场景。`FarmGridManager` 已提供地图边界、地块数据、坐标转换和可视化调试能力，`EventBus` 已承担跨系统信号边界。

PRD9 的核心缺口是玩家在田园场景中的身体表示和交互入口。没有玩家控制器时，后续 PRD10 的种植、浇水、收获闭环无法获得稳定的玩家位置、面朝方向和交互目标。该设计以最小可玩原型为目标，用占位视觉替代正式美术，先稳定移动、方向、坐标和事件接口。

## 目标 / 非目标

**目标：**

- 提供基于 `CharacterBody2D` 的 `Player` 场景，使用 32×48 像素占位视觉，并以脚底点作为世界坐标与网格换算基准。
- 提供 `PlayerController`，统一处理移动输入、4 方向面朝方向、移动启停、地图边界限制和公共查询接口。
- 复用 `FarmGridManager` 的 `world_to_grid()`、`grid_to_world_center()`、`is_in_map_bounds()` 和 `get_tile_data()` 识别当前格、面前格和 `farm_tile` 交互目标。
- 通过 `EventBus` 广播玩家出生、移动、方向变化、交互目标变化、成功交互、交互失败和地块交互请求。
- 将玩家实例接入田园场景，提供最小调试显示，便于观察坐标、方向和目标。
- 提供测试场景和脚本，覆盖移动、方向、坐标、交互开关、交互目标和信号行为。

**非目标：**

- 不实现正式角色 Sprite Sheet、`AnimatedSprite2D`、idle / walk / interact 动画和美术遮挡排序。
- 不实现种植、浇水、收获、清除枯萎作物等业务效果。
- 不读取快捷栏工具或背包选中物品，不扣除物品、金币或经验。
- 不实现 NPC 对话、入口切场景、装饰物交互、音效、多人同步或移动端虚拟摇杆。
- 不改变 `FarmGridManager` 对地块数据的所有权，`PlayerController` 只查询，不直接修改网格状态。

## 决策

### 决策 1：玩家根节点使用 `CharacterBody2D`

选择 `CharacterBody2D` 作为 `Player` 根节点，移动逻辑集中在 `_physics_process(delta)` 中读取 InputMap、设置 `velocity` 并调用 `move_and_slide()`。这样符合 Godot 4 的 2D 角色控制模型，也便于后续接入碰撞层、障碍物和动画状态机。

替代方案是使用普通 `Node2D` 直接修改 `global_position`。该方案实现更简单，但无法自然接入物理移动、碰撞和 `move_and_slide()` 行为，不利于 PRD17 场景碰撞扩展，因此不采用。

### 决策 2：`global_position` 表示脚底点

`Player` 的 `global_position` 作为脚底 / 碰撞中心点，而不是视觉左上角。占位视觉通过子节点向上偏移，例如 32×48 角色主体放置在 `Vector2(-16, -48)` 到 `Vector2(16, 0)` 范围内，碰撞体位于脚底附近。

该设计使 `FarmGridManager.world_to_grid(global_position)` 能稳定得到玩家脚下地块，避免角色头部或视觉中心影响网格判断。代价是场景制作时需要明确视觉偏移，但这与像素农场游戏常见的脚底定位模型一致。

### 决策 3：移动输入完全通过 InputMap

`PlayerController` 读取 `move_up`、`move_down`、`move_left`、`move_right` 和 `interact` Action，不直接读取具体键码。移动输入允许斜向组合，并在长度大于 1 时归一化，避免斜向速度超过单方向速度。

该设计延续 PRD1 的输入抽象，后续可在不改控制器核心逻辑的情况下支持手柄或移动端虚拟摇杆。

### 决策 4：面朝方向只记录主方向

虽然移动允许斜向输入，但 `facing_direction` 只记录 `down`、`up`、`left`、`right` 四个主方向。水平输入绝对值大于等于垂直输入时优先左右，否则使用上下；没有输入时保持最后方向。

该规则与后续像素角色 4 方向动画和面前一格交互模型兼容。替代方案是记录 8 方向，但会增加动画和交互格选择复杂度，不符合 PRD9 的最小范围。

### 决策 5：地图边界先用脚底点钳制

PRD9 最低实现只要求玩家脚底点不离开 30×20 地图范围，即世界坐标限制在 `Vector2(0, 0)` 到 `Vector2(480, 320)`。不强制实现 Tile 级阻挡地形，作物占用地块也暂不阻挡移动。

该方案优先保证玩家不会走出地图，同时避免早期因作物或地块状态导致卡位。正式障碍、碰撞层和 YSort 可在 PRD17 场景美术阶段补充。

### 决策 6：交互目标优先使用面前一格 `farm_tile`

`PlayerController` 根据 `current_grid_pos + facing_vector` 得到 `front_grid_pos`，通过 `FarmGridManager.is_in_map_bounds()` 和 `get_tile_data()` 生成 `farm_tile` 目标。目标数据包含类型、网格坐标、世界坐标、地形、地块状态、解锁、占用、节点引用和优先级。

PRD9 只必需实现 `farm_tile`，但保留 `node`、`priority`、`type` 等字段，便于后续 NPC、入口、装饰物和可拾取物接入同一目标结构。

### 决策 7：交互只发请求事件，不执行业务

`try_interact()` 成功命中目标时发射 `player_interacted(target)`；目标为地块时额外发射 `farm_tile_interaction_requested(tile_pos, target)`。交互失败时发射 `player_interaction_failed(reason)`。

`PlayerController` 禁止调用 `plant_crop()`、`water_crop()`、`harvest_crop()`、背包扣除、金币或经验逻辑。这样可以保持玩家控制系统与 PRD10 业务闭环解耦，后续系统只需监听事件并决定具体效果。

### 决策 8：调试 UI 是可选依赖

`Player` 可自带 `DebugLabel`，田园场景也可提供 `PlayerDebugLabel`。控制器在 Label 存在时更新坐标、方向、面前格和目标信息；Label 不存在时核心逻辑必须正常运行。

该设计保证测试和无 UI 场景可以复用 `PlayerController`，同时保留早期原型调试效率。

## 风险 / 权衡

- [风险] `EventBus` 现有规范要求信号偏过去时命名，而 `farm_tile_interaction_requested` 表达请求语义并非严格过去时 → 缓解措施：在 PRD9 增量规范中明确该信号属于“玩家已请求交互”的事件边界，保留请求语义以避免误导业务已完成。
- [风险] `FarmGridManager` 未绑定或接口缺失会导致交互目标无法生成 → 缓解措施：`PlayerController` 在缺少管理器时仍允许移动，交互目标为空并通过 warning 或失败信号暴露问题。
- [风险] 每帧刷新交互目标可能带来不必要开销 → 缓解措施：PRD9 只查询面前一格，不做全图扫描；后续可在格子或方向变化时增量刷新。
- [风险] 脚底点边界钳制允许角色视觉部分出屏或覆盖边缘 → 缓解措施：PRD9 以脚底不越界为准，正式摄像机和场景遮挡在后续 PRD 中优化。
- [风险] 斜向移动与主方向选择可能和玩家视觉预期不同 → 缓解措施：采用稳定、可测试的优先级规则，并通过 `debug_set_facing_direction()` 支持测试指定方向。
- [风险] 早期不做 Tile 阻挡会允许玩家穿过作物或装饰 → 缓解措施：明确 PRD9 范围只保证地图边界和目标识别，阻挡地形在场景美术 / 碰撞 PRD 中完善。
