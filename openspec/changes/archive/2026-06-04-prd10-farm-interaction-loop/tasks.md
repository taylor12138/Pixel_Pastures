## 1. 事件、输入与场景装配

- [x] 1.1 在 `scripts/autoload/event_bus.gd` 中新增 `farm_interaction_mode_changed`、`farm_interaction_completed`、`farm_interaction_failed`、`farm_tile_action_preview_changed` 信号
- [x] 1.2 检查 `project.godot` InputMap，确认 PRD10 调试选择、鼠标点击和既有 `interact` 输入不会互相覆盖
- [x] 1.3 修改 `scenes/farm/farm.tscn`，新增或复用 `Controllers` 容器并挂载 `FarmInteractionController`
- [x] 1.4 修改 `scenes/farm/farm.tscn`，新增 `CropOverlay` 或等价作物占位视觉层
- [x] 1.5 修改 `scenes/farm/farm.tscn`，新增 `InteractionDebugLabel` 或等价调试显示
- [x] 1.6 修改 `scenes/farm/farm.gd`，在场景初始化时绑定 `FarmGridManager`、`CropOverlay`、玩家和交互控制器
- [x] 1.7 修改 `scenes/farm/farm.gd`，关闭或限制 PRD8 左键地块状态循环，避免覆盖 PRD10 真实业务交互

## 2. FarmInteractionController 基础结构

- [x] 2.1 新增 `scripts/farm/farm_interaction_controller.gd`，定义 `InteractionMode`、导出项、当前选择、最后结果和依赖引用
- [x] 2.2 实现 `setup()`、`reset_controller()`、`connect_events()`、`disconnect_events()` 初始化与事件生命周期接口
- [x] 2.3 实现统一结果 Dictionary 构造方法，包含 `success`、`action`、`tile_pos`、`crop_id`、`item_id`、`reason`、`message`
- [x] 2.4 实现成功 / 失败结果派发，分别发射 `farm_interaction_completed(result)` 和 `farm_interaction_failed(result)`
- [x] 2.5 实现地块基础校验，覆盖地图越界、地块缺失、锁定、不可种植和作物缺失等错误码

## 3. 当前选择与调试入口

- [x] 3.1 实现 `select_seed(crop_id)`，校验 `DataManager.get_crop()`、等级解锁和 `seed_<crop_id>` 映射
- [x] 3.2 实现 `select_tool(tool_id)`，至少支持并校验 `watering_can`
- [x] 3.3 实现 `select_clear_mode()`、`clear_selection()`、`get_current_selection()`
- [x] 3.4 实现选择变化事件发射，确保模式、选中物品和选中作物参数稳定
- [x] 3.5 实现 `sync_selection_from_hotbar()`，支持从选中 seed 和 `watering_can` 推导模式
- [x] 3.6 实现 debug 模式下的临时数字键或按钮选择入口：胡萝卜、白菜、玉米、水壶、清除、清空
- [x] 3.7 确认 debug 选择不会直接修改 `InventoryManager` 槽位或 selected hotbar 状态

## 4. 地块请求与动作解析

- [x] 4.1 实现 `request_tile_interaction(tile_pos, source)`，作为鼠标和玩家交互的统一入口
- [x] 4.2 实现 `request_mouse_tile_interaction(mouse_world_pos)`，通过 `FarmGridManager.world_to_grid()` 转换坐标
- [x] 4.3 接入 `EventBus.farm_tile_interaction_requested(tile_pos, target)`，将玩家按 `E` 请求转入统一入口
- [x] 4.4 实现 `can_interact_with_tile(tile_pos)`，用于预览和基本合法性判断
- [x] 4.5 实现 `resolve_action(tile_pos)` 自动优先级：成熟收获、枯萎清除、需水浇水、选中种子种植、无动作失败
- [x] 4.6 实现严格模式下按 `current_mode` 分发到种植、浇水、收获或清除
- [x] 4.7 可选实现悬停或面前目标预览，并发射 `farm_tile_action_preview_changed`

## 5. 种植、浇水、收获、清除业务

- [x] 5.1 实现 `try_plant(tile_pos, crop_id)` 前置校验：地图内、已解锁、可种植、无作物、作物存在、等级解锁、有种子
- [x] 5.2 在种植成功后调用 `CropManager.plant_crop()`，并以成功结果同步 `FarmGridManager.set_tile_occupied()`
- [x] 5.3 实现 `try_water(tile_pos)` 前置校验：有作物、未成熟、未枯萎、需要浇水、当前水壶或自动浇水
- [x] 5.4 在浇水成功后调用 `CropManager.water_crop()`，并同步 `FarmGridManager.mark_tile_watered()`
- [x] 5.5 实现 `try_harvest(tile_pos)`，只允许成熟作物并以 `CropManager.harvest_crop()` 返回非空 crop_id 作为成功依据
- [x] 5.6 在收获成功后调用 `FarmGridManager.clear_tile()`，背包满或收获失败时不得清空地块
- [x] 5.7 实现 `try_clear(tile_pos)`，只允许清除 `WITHERED` 作物并在成功后清空地块
- [x] 5.8 覆盖 PRD10 稳定错误码和中文提示文案，确保失败操作不修改作物、地块或背包状态

## 6. 占位视觉、调试显示与生长事件

- [x] 6.1 实现 `CropOverlay` 的 `_draw()` 或轻量 Marker 方案，按 CropManager 作物数据绘制阶段标记
- [x] 6.2 为未浇水、已浇水、发芽、生长中、成熟、枯萎提供可区分颜色、边框、短文本或几何标记
- [x] 6.3 监听 `crop_planted`、`crop_watered`、`crop_grown`、`crop_matured`、`crop_withered`、`crop_harvested`、`crop_cleared` 并刷新占位视觉
- [x] 6.4 更新 `InteractionDebugLabel`，展示当前模式、选中物品、最后结果、目标地块作物阶段、浇水状态和生长进度
- [x] 6.5 实现 debug 模式下推进时间、强制成熟或强制枯萎的测试入口，并确保非 debug 模式不可用
- [x] 6.6 手测 `farm.tscn`，确认玩家和可耕地可见，点击和按 `E` 都能触发同一套交互结果

## 7. 存档一致性与系统衔接

- [x] 7.1 实现 `reconcile_grid_with_crops()`，有作物但地块未占用时恢复 occupied
- [x] 7.2 实现 `reconcile_grid_with_crops()`，无作物但地块 occupied 时清理为空闲
- [x] 7.3 在田园场景初始化或加载后调用一致性修复，避免旧调试状态或旧存档造成不可种植地块
- [x] 7.4 验证 PRD10 不新增必须持久化的控制器选择字段，保存仍通过 Crop、Grid、Inventory、Game / Level 既有导出完成
- [x] 7.5 检查 `data/items.json` 是否存在 `watering_can`，缺失时补齐占位工具数据
- [x] 7.6 检查 `data/crops.json` 和 `data/items.json` 是否包含 carrot、cabbage、corn 及对应种子 / 收获物，缺失时补齐测试所需数据

## 8. 自动化与回归测试

- [x] 8.1 新增 `scenes/test/test_farm_interaction_controller.tscn`，包含测试入口、FarmGridManager、FarmInteractionController 和可选 CropOverlay
- [x] 8.2 新增 `scenes/test/test_farm_interaction_controller.gd`，在 `_ready()` 中初始化新游戏、网格、背包种子和控制器绑定
- [x] 8.3 测试空地种植成功：返回 success、CropManager 有作物、Grid occupied、种子减少 1
- [x] 8.4 测试无种子、锁定地块、重复种植失败，确认错误码和状态回滚
- [x] 8.5 测试浇水成功、重复浇水失败和作物阶段推进后需要再次浇水
- [x] 8.6 测试未成熟收获失败、成熟收获成功和背包满收获失败不清地
- [x] 8.7 测试枯萎作物清除成功且不增加收获物
- [x] 8.8 测试自动交互优先级：成熟优先收获、枯萎优先清除、需水时浇水、空地时种植
- [x] 8.9 测试 Crop / Grid 存档一致性修复两种方向
- [x] 8.10 回归运行 CropManager、InventoryManager、FarmGridManager、PlayerController、SaveManager、TimeManager 相关测试，确认 PRD10 未破坏 PRD1-9

## 9. 验收与文档收尾

- [x] 9.1 在 `farm.tscn` 手测完整流程：选择种子、种植、浇水、推进、生长、再次浇水、成熟、收获、地块恢复
- [x] 9.2 在 `farm.tscn` 手测枯萎清除流程和主要错误提示
- [x] 9.3 确认鼠标左键和玩家面前按 `E` 触发同一套业务逻辑和 EventBus 结果事件
- [x] 9.4 清理临时日志，保留必要 warning、测试输出和 debug 模式下可理解的信息
- [x] 9.5 更新项目 README 或测试说明，记录如何运行田园场景和 `test_farm_interaction_controller.tscn`
- [x] 9.6 对照 PRD10 功能、工程和体验验收标准完成最终检查
