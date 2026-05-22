## Why

《像素田园》已经完成 PRD1 项目骨架与核心数据系统，并完成 PRD3 背包/库存数据层。当前项目仍缺少统一的经济操作入口，导致“出售作物获得金币、用金币购买种子、种子进入背包、继续种植”的核心经营循环无法通过纯代码稳定闭环。

PRD4 需要引入 `EconomyManager` 作为经济系统与商店数据层的统一入口，所有购买、出售、价格查询、商店列表、交易统计都通过该 Autoload 暴露。金币数值仍由 `GameManager.gold` 持有，库存变更仍由 `InventoryManager` 执行，`EconomyManager` 负责交易校验、原子性、结构化结果与事件广播。

该变更是后续 PRD10 种植交互、PRD12 商店 UI、PRD13 HUD、PRD5 等级解锁与 PRD6 存档系统的基础能力。

## What Changes

- 新增 `EconomyManager` Autoload 单例（`pixel-farm/scripts/autoload/economy_manager.gd`），不使用 `class_name`。
- 在 `project.godot` 注册 `EconomyManager`，加载顺序为 `EventBus → DataManager → GameManager → CropManager → InventoryManager → EconomyManager → SceneManager → AudioManager`。
- 实现种子购买接口：`buy_seed(crop_id, quantity)`，完成价格读取、等级解锁、金币校验、背包容量预检、扣金币、入背包、统计与信号广播。
- 实现通用商品购买接口：`buy_item(item_id, quantity)`，当前支持 `seed`、`consumable`、`decoration` 类型。
- 实现作物出售接口：`sell_harvest(crop_id, quantity)`，完成收获物 item 映射、售价读取、库存校验、扣背包、加金币、统计与信号广播。
- 实现通用物品出售接口：`sell_item(item_id, quantity)`，PRD4 默认仅允许 `harvest` 类型出售。
- 实现价格查询、种子商品列表、全部商店商品列表、背包可出售物品列表、单个商品展示数据查询。
- 所有购买/出售返回统一结构化交易结果 Dictionary，包含成功状态、类型、物品、数量、单价、总价、金币前后、消息与错误码。
- 新增 `EventBus.transaction_completed(result)` 与 `EventBus.transaction_failed(result)` 信号。
- 在 `GameManager.save_game()` / `load_game()` 中预留经济统计数据导出/导入接入点。
- 创建 `scenes/test/test_economy_manager.tscn` 与 `test_economy_manager.gd`，覆盖购买、出售、失败无副作用、列表、信号与统计导入导出测试。

## Capabilities

### New Capabilities

- `shop-economy`: 经济系统与商店数据层，包含购买、出售、价格查询、商品列表、可出售库存列表、交易结果、错误码、统计数据与测试场景。

### Modified Capabilities

- `event-bus`: 扩展交易成功与交易失败信号，作为后续 UI、HUD、成就、日志系统的事件边界。
- `game-state`: 保持 `GameManager.gold` 为金币权威，同时通过 `EconomyManager` 统一交易入口；存档中预留经济统计数据。
- `inventory-data`: 购买入包与出售扣包均通过 `InventoryManager`，交易失败不得污染库存状态。
- `item-data`: 明确商店购买价格与出售价格来源，优先使用 `items.json` 字段，必要时回退到 `crops.json`。

## Impact

- **代码**:
  - 新增 `pixel-farm/scripts/autoload/economy_manager.gd`
  - 修改 `pixel-farm/scripts/autoload/event_bus.gd`
  - 修改 `pixel-farm/scripts/autoload/game_manager.gd`
  - 修改 `pixel-farm/project.godot`
- **数据**:
  - 不要求新增商品数据；依赖现有 `pixel-farm/data/crops.json` 与 `pixel-farm/data/items.json` 字段。
  - 对缺失价格字段需要返回明确错误，不在运行时修改原始数据。
- **测试**:
  - 新增 `pixel-farm/scenes/test/test_economy_manager.tscn`
  - 新增 `pixel-farm/scenes/test/test_economy_manager.gd`
- **后续影响**:
  - PRD10 可调用购买到的种子继续种植。
  - PRD12 可直接使用 `get_shop_items()`、`buy_item()`、`sell_item()` 构建商店 UI。
  - PRD13 可监听金币与交易信号更新 HUD。
  - PRD5 可替换当前 `GameManager.level` 解锁判断为 `LevelManager` 查询。
