## 为什么

PRD1-9 已经建立作物状态机、背包、经济、等级、存档、时间、田园网格和玩家面前地块交互入口，但这些系统还没有被串成玩家可操作的种植闭环。当前田园场景仍以调试地块状态为主，玩家无法在同一套业务逻辑中完成选择种子、种植、浇水、等待生长、再次浇水、收获入背包和清除枯萎作物。

本变更将把现有数据系统接入 `farm.tscn`，形成色块版可玩原型的核心玩法闭环，为后续背包 UI、快捷栏 HUD、正式作物视觉、角色动画、音效和商店流程提供稳定的交互编排层。

## 变更内容

- 新增 `FarmInteractionController`，集中处理当前种子 / 工具选择、鼠标地块点击、玩家面前按 `E` 交互、自动动作解析、业务前置校验和结果返回。
- 在田园场景中挂载交互控制器，接入 `FarmGridManager`、`CropManager`、`InventoryManager`、`LevelManager`、`DataManager`、`EventBus` 和作物占位视觉层。
- 支持种植、浇水、收获、清除枯萎作物四类业务操作，并在成功后同步 Crop、Grid、Inventory、经验和事件状态。
- 提供临时调试选择入口和调试推进能力，使玩家无需正式 UI 也能在 `farm.tscn` 跑通完整闭环。
- 用色块、短文本或简单几何标记展示作物阶段、浇水状态、成熟 / 枯萎状态和最后交互结果。
- 扩展 `EventBus` 农田交互相关信号，供后续 HUD、动画、音效和特效订阅。
- 衔接 PRD9 玩家交互请求，使鼠标点击地块和角色面前按 `E` 进入同一套 `FarmInteractionController` 逻辑。
- 新增 `test_farm_interaction_controller` 自动化 / 半自动化测试场景，覆盖种植、浇水、成熟收获、枯萎清除、错误回滚、自动交互优先级和存档一致性修复。
- 不实现正式背包 UI、商店 UI、HUD 快捷栏视觉、正式 Sprite、角色动作动画、音效、粒子、售卖流程、好友田园或移动端触屏专项适配。

## 功能 (Capabilities)

### 新增功能
- `farm-interaction-loop`: 定义田园种植 / 浇水 / 收获 / 清除闭环的交互编排、业务规则、返回结果、占位视觉、调试入口和测试要求。

### 修改功能
- `event-bus`: 新增农田交互模式变化、交互完成、交互失败和动作预览事件。
- `farm-grid-system`: 明确 PRD10 接入后地块占用、湿土、清理和 CropManager 状态的一致性要求，并约束旧调试点击循环不应覆盖真实业务交互。
- `player-interaction`: 明确 `farm_tile_interaction_requested` 事件由 `FarmInteractionController` 消费，玩家控制器仍不直接调用作物、背包或地块修改业务。
- `inventory-hotbar`: 明确正式快捷栏未完成前的种子 / 水壶选择兜底策略，以及后续从选中物品同步交互模式的行为。
- `game-state`: 明确 PRD10 不新增持久化结构，但操作后必须保持 Crop、Grid、Inventory、等级经验和加载后一致性可被既有存档系统保存与恢复。

## 影响

- 新增文件：`pixel-farm/scripts/farm/farm_interaction_controller.gd`、`pixel-farm/scenes/test/test_farm_interaction_controller.tscn`、`pixel-farm/scenes/test/test_farm_interaction_controller.gd`。
- 修改文件：`pixel-farm/scenes/farm/farm.tscn`、`pixel-farm/scenes/farm/farm.gd`、`pixel-farm/scripts/farm/farm_grid_manager.gd`、`pixel-farm/scripts/autoload/event_bus.gd`。
- 可能修改：`pixel-farm/scripts/autoload/crop_manager.gd`、`pixel-farm/scripts/autoload/inventory_manager.gd`、`pixel-farm/scripts/autoload/game_manager.gd`、`pixel-farm/project.godot`，仅用于补齐 PRD10 所需的查询、测试或调试输入衔接。
- 运行时影响：田园场景左键点击地块和玩家按 `E` 将触发真实种植 / 浇水 / 收获 / 清除业务；PRD8 的地块状态循环调试逻辑需要关闭、降级或限制在不会破坏真实作物数据的 debug 分支内。
- 后续影响：PRD11、PRD13、PRD15、PRD16、PRD18、PRD19 可复用 `FarmInteractionController` 的选择接口、结果事件和动作判断，不需要重新实现核心闭环规则。
