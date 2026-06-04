## 上下文

PRD10 位于色块版可玩原型的核心闭环阶段。项目已经拥有作物生命周期、背包槽位、经济、等级、存档、时间、田园网格和玩家面前地块交互入口，但田园场景还缺少一个业务编排层来消费这些系统并形成玩家可操作流程。

当前 `FarmGridManager` 是地块状态所有者，`CropManager` 是作物生命周期和种子 / 收获物库存变更的业务所有者，`PlayerController` 只负责识别面前地块并广播 `farm_tile_interaction_requested`。PRD10 必须保持这些职责边界，把新增逻辑集中在 `FarmInteractionController`，避免 `farm.gd` 继续膨胀为业务核心。

## 目标 / 非目标

**目标：**

- 在 `farm.tscn` 中跑通选择种子、种植、浇水、等待阶段推进、再次浇水、成熟、收获入背包、地块恢复空闲的闭环。
- 支持鼠标左键点击地块和玩家面前按 `E` 两种入口，并保证它们进入同一套业务规则。
- 为种植、浇水、收获、清除提供统一结果 Dictionary、稳定错误码、EventBus 事件和调试显示。
- 每次成功操作后同步 CropManager、FarmGridManager、InventoryManager、LevelManager / GameManager 的状态，并提供加载后一致性修复。
- 用最小占位视觉表达作物阶段、浇水状态、成熟和枯萎，不依赖正式美术。
- 新增测试场景覆盖核心闭环、失败回滚、自动动作优先级和存档一致性修复。

**非目标：**

- 不实现正式背包 UI、商店 UI、HUD 快捷栏视觉、正式作物 Sprite、角色动画、音效、粒子、售卖流程、好友田园或移动端触屏专项适配。
- 不重写 `CropManager` 的生长状态机、时间推进、种子扣除、收获物添加或 XP 规则。
- 不让 `PlayerController` 直接调用作物、背包或地块修改业务。
- 不新增新的持久化数据结构；只保证既有管理器导出的状态一致。

## 决策

### 1. 使用 `FarmInteractionController` 作为唯一交互编排层

`FarmInteractionController` 持有当前模式、选中种子 / 工具、最后结果、网格管理器引用和可选作物覆盖层引用。它监听 `EventBus.farm_tile_interaction_requested`，处理鼠标地块点击，并公开测试可直接调用的 `request_tile_interaction()`、`try_plant()`、`try_water()`、`try_harvest()`、`try_clear()` 和 `resolve_action()`。

替代方案是把业务直接放进 `farm.gd` 或 `PlayerController`。这会让田园场景脚本同时承担 UI、输入、作物、背包和网格同步职责，也会破坏 PRD9 中玩家控制器只广播请求的边界。因此本变更只让 `farm.gd` 负责场景装配和调试显示，业务判断进入控制器。

### 2. 真实库存和 XP 仍由 `CropManager` 负责

种植成功调用 `CropManager.plant_crop(tile_pos, crop_id)`，由 CropManager 扣除 `seed_<crop_id>` 并发出作物事件。收获成功调用 `CropManager.harvest_crop(tile_pos)`，由 CropManager 添加 `harvest_<crop_id>` 并发放经验。控制器在调用前做用户可理解的前置校验，在调用后只根据返回值同步 `FarmGridManager`。

替代方案是在控制器里先扣种子或先加收获物，再调用作物接口。这样容易造成双扣、双加或背包满时清地丢作物。PRD10 因此以 CropManager 返回结果作为真实业务提交点。

### 3. Grid 状态是视觉和可操作性镜像，不是作物数据源

作物是否存在、是否成熟、是否需要水以 `CropManager` 查询为准。地块是否可种植、是否已解锁、是否可清理以 `FarmGridManager` 查询为准。种植成功后调用 `set_tile_occupied()`；浇水成功后调用 `mark_tile_watered()`；收获或清除成功后调用 `clear_tile()`。

加载后若 Crop 和 Grid 不一致，`reconcile_grid_with_crops()` 以 CropManager 的作物数据为优先：有作物则恢复 occupied；无作物但 Grid 仍 occupied 则清空为 empty。这样可以避免 PRD8 调试状态或旧存档造成卡死地块。

### 4. 自动动作解析服务于原型可玩性

默认启用 `auto_resolve_action`。点击或按 `E` 时按成熟收获、枯萎清除、需水浇水、选中种子种植的顺序解析动作。该顺序让玩家在调试原型中少切模式也能完成闭环，同时确保成熟和枯萎作物不会被水壶或种子选择遮挡。

当后续 PRD13 快捷栏 HUD 完成后，可以关闭自动解析或改为严格工具模式，但控制器公共接口和错误码保持稳定。

### 5. 临时调试选择与 Hotbar 同步并存

PRD10 暂不要求正式 UI，因此数字键或调试按钮可以选择胡萝卜、白菜、玉米、水壶、清除模式或清空选择。若当前项目已有 `InventoryManager.get_selected_item()`，控制器也提供 `sync_selection_from_hotbar()`：选中物品为 seed 时进入 `PLANT`，选中 `watering_can` 时进入 `WATER`，否则保持或清空选择。

这使 PRD10 可独立验收，同时不会阻碍 PRD11 / PRD13 用正式 UI 替换临时入口。

### 6. 占位视觉通过 Overlay 观察作物状态

`CropOverlay` 可以是 `Node2D._draw()` 方案，也可以是轻量 Label / Marker 池。它不拥有作物数据，只在 `CropManager.get_all_crops()`、`get_crop_data()` 和作物生命周期事件后刷新。颜色和短文本必须足以区分未浇水、已浇水、发芽、生长中、成熟和枯萎。

## 风险 / 权衡

- CropManager 与 FarmGridManager 状态不一致 -> 每次成功操作后立即同步，并在场景初始化或加载后运行 `reconcile_grid_with_crops()`。
- 背包满导致收获失败 -> 控制器必须以 `CropManager.harvest_crop()` 返回的非空 crop_id 为成功条件，失败时禁止清空地块。
- PRD8 鼠标调试点击循环破坏真实作物 -> PRD10 接入后关闭该循环，或只在独立 debug flag 且无作物数据时允许。
- Hotbar 数字键和调试直选冲突 -> 优先支持从 `InventoryManager` 当前选中物同步；调试直选只作为无 UI 阶段的兜底。
- 生长等待太久影响手测 -> Debug 模式提供推进时间或强制成熟能力，并限制在测试场景或 debug 模式启用。
- EventBus 事件语义混淆 -> `farm_tile_interaction_requested` 只表示玩家请求；`farm_interaction_completed` / `farm_interaction_failed` 才表示 PRD10 业务结果。

## 迁移计划

1. 创建 `FarmInteractionController` 和测试场景，先用直接接口调用验证种植、浇水、收获、清除和失败回滚。
2. 在 `farm.tscn` 增加控制器、作物覆盖层和调试 Label，由 `farm.gd` 负责绑定 `FarmGridManager` 和 overlay。
3. 接入 `EventBus.farm_tile_interaction_requested`，让玩家按 `E` 触发同一套逻辑。
4. 接入鼠标左键地块点击，关闭或限制 PRD8 点击循环调试逻辑。
5. 增加调试选择、调试推进和占位视觉刷新。
6. 运行 PRD10 测试场景，并回归 CropManager、InventoryManager、FarmGridManager、PlayerController、SaveManager 和 TimeManager 相关测试。

## 开放问题

- 当前项目中水壶物品是否已经在 `data/items.json` 定义为 `watering_can`；如果不存在，实施时需要补齐占位物品数据。
- 当前作物测试数据的生长时间是否适合手测；如过长，debug 推进接口需要覆盖完整成熟流程。
