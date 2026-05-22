## Context

PRD4 的目标是补齐经济系统与商店数据层，使项目具备纯代码可验证的经营闭环：出售作物获得金币，使用金币购买种子，种子进入背包，后续种植系统继续消费种子。

当前项目已有关键依赖：

- `DataManager` 可读取 `crops.json`、`items.json` 并返回副本。
- `GameManager` 持有 `gold`、`level`、`stats`，并提供 `add_gold()`、`spend_gold()`、`can_afford()`。
- `InventoryManager` 持有 20 格背包权威状态，并提供 `add_item()`、`remove_item()`、`has_item()`、`get_item_count()`、`get_addable_count()`、`get_all_slots()`、`debug_clear()`。
- `EventBus` 已有金币、买卖、背包、UI 通知等信号。

PRD4 只实现纯数据层，不实现商店 UI、NPC、按钮、确认弹窗或视觉表现。

## Goals / Non-Goals

### Goals

- 提供 `EconomyManager` 作为购买、出售、价格查询、商品列表与统计的统一入口。
- 保持 `GameManager.gold` 为金币权威，不绕过 `GameManager` 修改金币。
- 保持 `InventoryManager` 为库存权威，购买入库与出售扣除均经由其 API。
- 所有交易返回结构化结果，失败时提供稳定错误码。
- 交易具备原子性，任一失败不得产生半完成状态。
- 成功和失败交易都通过 `EventBus` 广播结构化结果。
- 提供自动化测试场景覆盖核心链路和边界情况。

### Non-Goals

- 不实现商店 UI、商品卡片、购买确认弹窗、售卖面板。
- 不实现 NPC、商店地图或货架交互。
- 不实现多货币、折扣、每日限购、动态价格。
- 不实现完整等级系统，仅通过 `GameManager.level` 预留解锁校验。
- 不修改 PRD3 背包槽位模型。

## EconomyManager Design

`EconomyManager` 是 Autoload 单例，路径为 `res://scripts/autoload/economy_manager.gd`，注册名为 `EconomyManager`，不使用 `class_name`。

### Public API

购买相关：

- `buy_seed(crop_id: String, quantity: int = 1) -> Dictionary`
- `buy_item(item_id: String, quantity: int = 1) -> Dictionary`
- `can_buy_item(item_id: String, quantity: int = 1) -> Dictionary`

出售相关：

- `sell_harvest(crop_id: String, quantity: int = 1) -> Dictionary`
- `sell_item(item_id: String, quantity: int = 1) -> Dictionary`
- `can_sell_item(item_id: String, quantity: int = 1) -> Dictionary`

查询相关：

- `get_buy_price(item_id: String) -> int`
- `get_sell_price(item_id: String) -> int`
- `get_seed_shop_items() -> Array`
- `get_shop_items() -> Array`
- `get_sellable_inventory_items() -> Array`
- `get_shop_item_info(item_id: String) -> Dictionary`

存档/统计相关：

- `export_save_data() -> Dictionary`
- `import_save_data(data: Dictionary) -> void`
- 可额外提供 `debug_reset_stats()` 作为测试 helper。

## Transaction Result

所有购买/出售接口返回统一 Dictionary：

```gdscript
{
	"success": true,
	"type": "buy",
	"item_id": "seed_carrot",
	"crop_id": "carrot",
	"quantity": 3,
	"unit_price": 10,
	"total_price": 30,
	"gold_before": 100,
	"gold_after": 70,
	"message": "购买成功",
	"error_code": "",
}
```

失败结果必须保持同一结构，`success=false`，`gold_after` 等于 `gold_before`，并包含稳定错误码。

### Error Codes

- `INVALID_ITEM`: `item_id` 为空或数据表中不存在。
- `INVALID_CROP`: `crop_id` 为空或数据表中不存在。
- `INVALID_QUANTITY`: `quantity <= 0`。
- `NOT_SELLABLE`: 物品不允许出售或无有效售价。
- `NOT_BUYABLE`: 物品不允许购买或无有效购买价。
- `NOT_ENOUGH_GOLD`: 金币不足。
- `NOT_ENOUGH_ITEMS`: 背包数量不足。
- `INVENTORY_FULL`: 背包无法完整容纳购买数量。
- `LOCKED`: 等级或解锁条件未满足。

## Price Rules

### Buy Price

`get_buy_price(item_id)` 规则：

1. 若 item 不存在，返回 `-1`。
2. 若 item 类型不是 `seed`、`consumable`、`decoration`，返回 `-1`。
3. 若 item 数据存在有效 `price > 0`，返回该字段。
4. 若 item 类型为 `seed` 且存在 `crop_id`，读取对应 crop 的 `seed_price > 0`。
5. 其它情况返回 `-1`。

`watering_can` 虽有 `price=0`，PRD4 默认不允许重复购买工具，因此返回 `-1`。

### Sell Price

`get_sell_price(item_id)` 规则：

1. 若 item 不存在，返回 `-1`。
2. PRD4 默认仅 `type == "harvest"` 可出售，其它类型返回 `-1`。
3. 若 item 数据存在有效 `sell_price > 0`，返回该字段。
4. 若 item 类型为 `harvest` 且存在 `crop_id`，读取对应 crop 的 `sell_price > 0`。
5. 其它情况返回 `-1`。

## Buy Flow

### buy_seed

`buy_seed(crop_id, quantity)`：

1. 校验 `quantity > 0`。
2. 校验 `DataManager.get_crop(crop_id)` 非空。
3. 生成 `item_id = "seed_" + crop_id`。
4. 校验 `DataManager.get_item(item_id)` 非空。
5. 调用 `buy_item(item_id, quantity)` 或复用内部购买流程。

### buy_item

`buy_item(item_id, quantity)`：

1. 校验 item、quantity、购买类型和购买价格。
2. 校验 `_is_item_unlocked(item_id)`。
3. 计算 `total_price = unit_price * quantity`。
4. 用 `GameManager.can_afford(total_price)` 预检金币。
5. 用 `InventoryManager.get_addable_count(item_id)` 预检背包容量。
6. 所有校验通过后调用 `GameManager.spend_gold(total_price)`。
7. 调用 `InventoryManager.add_item(item_id, quantity)`。
8. 若实际添加数量不足，回滚已添加数量与金币。
9. 更新购买统计。
10. 发射 `EventBus.item_purchased(item_id, total_price)`。
11. 发射 `EventBus.transaction_completed(result)`。
12. 返回成功结果。

失败时：

- 不扣金币。
- 不加背包物品。
- 发射 `EventBus.transaction_failed(result)`。
- 可发射 `EventBus.ui_notification(message, "warning")`。
- 不发射 `item_purchased`。

## Sell Flow

### sell_harvest

`sell_harvest(crop_id, quantity)`：

1. 校验 `quantity > 0`。
2. 校验 `DataManager.get_crop(crop_id)` 非空。
3. 生成 `item_id = "harvest_" + crop_id`。
4. 校验 `DataManager.get_item(item_id)` 非空。
5. 调用 `sell_item(item_id, quantity)` 或复用内部出售流程。

### sell_item

`sell_item(item_id, quantity)`：

1. 校验 item、quantity、可出售类型和出售价格。
2. 计算 `total_price = unit_price * quantity`。
3. 用 `InventoryManager.has_item(item_id, quantity)` 预检持有数量。
4. 调用 `InventoryManager.remove_item(item_id, quantity)`。
5. 若实际移除数量不足，回滚已移除数量。
6. 调用 `GameManager.add_gold(total_price, "sell")`。
7. 更新出售统计。
8. 发射 `EventBus.item_sold(item_id, total_price)`。
9. 发射 `EventBus.transaction_completed(result)`。
10. 返回成功结果。

失败时：

- 不扣背包物品。
- 不增加金币。
- 发射 `EventBus.transaction_failed(result)`。
- 可发射 `EventBus.ui_notification(message, "warning")`。
- 不发射 `item_sold`。

## Atomicity Strategy

购买优先通过容量和金币预检避免回滚。若中间步骤仍失败：

- `InventoryManager.add_item()` 返回不足时，调用 `InventoryManager.remove_item(item_id, added)` 回滚已添加物品，并调用 `GameManager.add_gold(total_price, "transaction_rollback")` 回滚金币。
- `GameManager.spend_gold()` 意外失败时直接返回 `NOT_ENOUGH_GOLD` 或内部失败结果，不执行入包。

出售优先通过数量预检避免回滚。若中间步骤仍失败：

- `InventoryManager.remove_item()` 返回不足时，调用 `InventoryManager.add_item(item_id, removed)` 回滚已移除物品，不加金币。
- `GameManager.add_gold()` 当前无失败返回值，因此加金币被视为可靠操作。

## Unlock Rules

PRD4 使用 `GameManager.level` 做轻量解锁：

- 非种子商品默认解锁。
- 种子商品读取 `item.crop_id` 对应 crop 的 `unlock_level`，当 `GameManager.level >= unlock_level` 时解锁。
- PRD5 完成后可替换为 `LevelManager.is_crop_unlocked(crop_id)`。

## Shop List Queries

### Seed Shop Items

`get_seed_shop_items()` 遍历 `DataManager.get_all_crops()`，为每个 crop 生成对应 `seed_<crop_id>` 商品。

每个条目包含：

- `item_id`
- `crop_id`
- `name`
- `type`
- `price`
- `unlocked`
- `unlock_level`
- `owned_count`
- `can_afford_one`

返回数组必须由新 Dictionary 组成，避免外部修改内部或 DataManager 数据。

### Shop Items

`get_shop_items()` 包含：

- 所有种子商品。
- `type == "consumable"` 且购买价格有效的物品。
- `type == "decoration"` 且购买价格有效的物品。

PRD4 不处理分类排序、分页和 UI 展示样式。

### Sellable Inventory Items

`get_sellable_inventory_items()` 基于 `InventoryManager.get_all_slots()` 汇总背包中可出售物品，默认只返回 `harvest` 类型且数量大于 0 的物品。

每个条目包含：

- `item_id`
- `name`
- `quantity`
- `unit_price`
- `total_price`
- `slot_indexes`

## Stats and Save Data

`EconomyManager` 维护：

```gdscript
var stats := {
	"total_gold_spent": 0,
	"total_gold_earned_from_sales": 0,
	"total_items_bought": 0,
	"total_items_sold": 0,
	"total_transactions": 0,
}
```

同步规则：

- 成功购买增加 `total_gold_spent`、`total_items_bought`、`total_transactions`。
- 成功出售增加 `total_gold_earned_from_sales`、`total_items_sold`、`total_transactions`。
- 出售获得金币仍通过 `GameManager.add_gold(total_price, "sell")` 更新 `GameManager.stats.total_gold_earned`。

`GameManager.save_game()` 应在 `EconomyManager` 存在时写入 `economy` 字段；`load_game()` 应在 `EconomyManager` 存在时导入该字段。若字段不存在，统计默认为 0。

## EventBus Integration

新增：

- `transaction_completed(result: Dictionary)`
- `transaction_failed(result: Dictionary)`

规则：

- 成功交易完成所有状态更新后发射 `transaction_completed`。
- 失败交易在校验失败或回滚完成后发射 `transaction_failed`。
- 失败交易不得发射 `item_purchased` 或 `item_sold`。

## Testing Strategy

新增 `test_economy_manager.tscn` 与 `test_economy_manager.gd`。

测试应覆盖：

- 种子购买价格。
- 收获物出售价格。
- 购买成功。
- 金币不足购买失败。
- 无效 crop。
- 无效 quantity。
- 背包容量不足。
- 未解锁种子。
- 收获物不可购买。
- 出售成功。
- 出售数量不足。
- 无效 item。
- 种子不可出售。
- 种子商店列表。
- 全部商店列表。
- 可出售背包列表。
- 成功/失败交易信号。
- 统计导出导入。

每个测试必须清理 `GameManager`、`InventoryManager`、`EconomyManager` 状态，避免污染后续测试。
