## 1. Artifact 编写

- [x] 1.1 创建 `openspec/changes/prd4-economy-shop-system/.openspec.yaml`
- [x] 1.2 完成 `proposal.md`
- [x] 1.3 完成 `design.md`
- [x] 1.4 完成 `specs/*/spec.md`
- [x] 1.5 完成 `tasks.md` 实施清单

## 2. Autoload 与项目配置

- [x] 2.1 新增 `pixel-farm/scripts/autoload/economy_manager.gd`，不使用 `class_name`
- [x] 2.2 在 `pixel-farm/project.godot` 注册 `EconomyManager` Autoload
- [x] 2.3 确保加载顺序为 `EventBus → DataManager → GameManager → CropManager → InventoryManager → EconomyManager → SceneManager → AudioManager`
- [x] 2.4 在 `EconomyManager._ready()` 初始化交易统计并输出调试日志

## 3. EventBus 信号扩展

- [x] 3.1 在 `pixel-farm/scripts/autoload/event_bus.gd` 新增 `transaction_completed(result: Dictionary)` 信号
- [x] 3.2 在 `pixel-farm/scripts/autoload/event_bus.gd` 新增 `transaction_failed(result: Dictionary)` 信号
- [x] 3.3 确认成功交易发射 `transaction_completed`，失败交易发射 `transaction_failed`
- [x] 3.4 确认失败交易不发射 `item_purchased` 或 `item_sold`

## 4. EconomyManager 基础结构

- [x] 4.1 定义交易错误码常量：`INVALID_ITEM`、`INVALID_CROP`、`INVALID_QUANTITY`、`NOT_SELLABLE`、`NOT_BUYABLE`、`NOT_ENOUGH_GOLD`、`NOT_ENOUGH_ITEMS`、`INVENTORY_FULL`、`LOCKED`
- [x] 4.2 定义可购买类型集合：`seed`、`consumable`、`decoration`
- [x] 4.3 定义 PRD4 可出售类型规则：默认仅 `harvest`
- [x] 4.4 定义 `stats` 字典：`total_gold_spent`、`total_gold_earned_from_sales`、`total_items_bought`、`total_items_sold`、`total_transactions`
- [x] 4.5 实现 `_make_result()` 统一生成交易结果 Dictionary
- [x] 4.6 实现 `_fail_result()` 并统一处理失败信号和可选 UI 通知
- [x] 4.7 实现 `_complete_transaction()` 并统一处理成功信号与统计更新

## 5. 价格查询与元数据 helper

- [x] 5.1 实现 `get_buy_price(item_id: String) -> int`
- [x] 5.2 购买价格优先读取 item `price > 0`
- [x] 5.3 种子购买价格在缺失 item price 时回退到 crop `seed_price > 0`
- [x] 5.4 非 `seed` / `consumable` / `decoration` 购买价格返回 `-1`
- [x] 5.5 实现 `get_sell_price(item_id: String) -> int`
- [x] 5.6 出售价格优先读取 harvest item `sell_price > 0`
- [x] 5.7 harvest 出售价格在缺失 item sell_price 时回退到 crop `sell_price > 0`
- [x] 5.8 非 `harvest` 出售价格返回 `-1`
- [x] 5.9 实现 `_get_crop_id_for_item(item_data: Dictionary) -> String`
- [x] 5.10 实现 `_is_item_unlocked(item_id: String) -> bool`，PRD4 使用 `GameManager.level`

## 6. 购买逻辑

- [x] 6.1 实现 `buy_seed(crop_id: String, quantity: int = 1) -> Dictionary`
- [x] 6.2 `buy_seed` 校验 crop 存在并映射 `seed_<crop_id>`
- [x] 6.3 实现 `can_buy_item(item_id: String, quantity: int = 1) -> Dictionary`，只校验不产生副作用
- [x] 6.4 实现 `buy_item(item_id: String, quantity: int = 1) -> Dictionary`
- [x] 6.5 校验无效 item 返回 `INVALID_ITEM`
- [x] 6.6 校验无效 quantity 返回 `INVALID_QUANTITY`
- [x] 6.7 校验不可购买类型或无效价格返回 `NOT_BUYABLE`
- [x] 6.8 校验未解锁商品返回 `LOCKED`
- [x] 6.9 校验金币不足返回 `NOT_ENOUGH_GOLD`
- [x] 6.10 校验背包容量不足返回 `INVENTORY_FULL`
- [x] 6.11 成功购买调用 `GameManager.spend_gold(total_price)`
- [x] 6.12 成功购买调用 `InventoryManager.add_item(item_id, quantity)`
- [x] 6.13 处理入包数量不足时的金币与库存回滚
- [x] 6.14 成功购买更新统计并发射 `item_purchased` 与 `transaction_completed`
- [x] 6.15 失败购买发射 `transaction_failed`，且金币与背包不变

## 7. 出售逻辑

- [x] 7.1 实现 `sell_harvest(crop_id: String, quantity: int = 1) -> Dictionary`
- [x] 7.2 `sell_harvest` 校验 crop 存在并映射 `harvest_<crop_id>`
- [x] 7.3 实现 `can_sell_item(item_id: String, quantity: int = 1) -> Dictionary`，只校验不产生副作用
- [x] 7.4 实现 `sell_item(item_id: String, quantity: int = 1) -> Dictionary`
- [x] 7.5 校验无效 item 返回 `INVALID_ITEM`
- [x] 7.6 校验无效 quantity 返回 `INVALID_QUANTITY`
- [x] 7.7 校验不可出售类型或无效价格返回 `NOT_SELLABLE`
- [x] 7.8 校验持有数量不足返回 `NOT_ENOUGH_ITEMS`
- [x] 7.9 成功出售调用 `InventoryManager.remove_item(item_id, quantity)`
- [x] 7.10 成功出售调用 `GameManager.add_gold(total_price, "sell")`
- [x] 7.11 处理移除数量不足时的库存回滚
- [x] 7.12 成功出售更新统计并发射 `item_sold` 与 `transaction_completed`
- [x] 7.13 失败出售发射 `transaction_failed`，且金币与背包不变

## 8. 商店与库存列表查询

- [x] 8.1 实现 `get_seed_shop_items() -> Array`
- [x] 8.2 种子商品遍历 `DataManager.get_all_crops()` 生成
- [x] 8.3 种子商品包含 `item_id`、`crop_id`、`name`、`type`、`price`、`unlocked`、`unlock_level`、`owned_count`、`can_afford_one`
- [x] 8.4 实现 `get_shop_items() -> Array`
- [x] 8.5 全部商店商品包含种子、有效消耗品、有效装饰物，并排除 harvest
- [x] 8.6 实现 `get_sellable_inventory_items() -> Array`
- [x] 8.7 可出售列表聚合同一 item 的数量与 slot 索引
- [x] 8.8 可出售列表仅包含 `harvest` 类型且 `quantity > 0` 的物品
- [x] 8.9 实现 `get_shop_item_info(item_id: String) -> Dictionary`
- [x] 8.10 确保所有列表返回新 Dictionary / Array，不暴露内部可变数据

## 9. 统计与存档

- [x] 9.1 实现 `export_save_data() -> Dictionary`
- [x] 9.2 实现 `import_save_data(data: Dictionary) -> void`
- [x] 9.3 实现 `debug_reset_stats()` 测试 helper
- [x] 9.4 成功购买更新 `total_gold_spent`、`total_items_bought`、`total_transactions`
- [x] 9.5 成功出售更新 `total_gold_earned_from_sales`、`total_items_sold`、`total_transactions`
- [x] 9.6 失败交易不更新统计
- [x] 9.7 修改 `GameManager.save_game()`，存在 EconomyManager 时写入 `economy`
- [x] 9.8 修改 `GameManager.load_game()`，存在 economy 数据时调用 `EconomyManager.import_save_data()`
- [x] 9.9 修改 `GameManager.new_game()`，存在 EconomyManager 时重置经济统计

## 10. 自动化测试场景

- [x] 10.1 新增 `pixel-farm/scenes/test/test_economy_manager.gd`，脚本 `extends Node2D`
- [x] 10.2 新增 `pixel-farm/scenes/test/test_economy_manager.tscn` 并绑定测试脚本
- [x] 10.3 实现 `_assert(condition: bool, message: String)` 测试 helper 和通过/失败计数
- [x] 10.4 实现测试前置清理 helper：清理金币、等级、背包、经济统计与信号计数
- [x] 10.5 测试 `get_buy_price("seed_carrot") == 10`
- [x] 10.6 测试 `get_sell_price("harvest_carrot") == 25`
- [x] 10.7 测试购买种子成功：扣金币、加背包、结果结构正确、统计正确
- [x] 10.8 测试金币不足：返回 `NOT_ENOUGH_GOLD` 且无副作用
- [x] 10.9 测试无效 crop：返回 `INVALID_CROP`
- [x] 10.10 测试无效 quantity：返回 `INVALID_QUANTITY`
- [x] 10.11 测试背包容量不足：返回 `INVENTORY_FULL` 且无副作用
- [x] 10.12 测试未解锁种子：返回 `LOCKED` 且无副作用
- [x] 10.13 测试购买 harvest：返回 `NOT_BUYABLE`
- [x] 10.14 测试出售 harvest 成功：扣背包、加金币、结果结构正确、统计正确
- [x] 10.15 测试出售数量不足：返回 `NOT_ENOUGH_ITEMS` 且无副作用
- [x] 10.16 测试出售无效 item：返回 `INVALID_ITEM`
- [x] 10.17 测试出售 seed：返回 `NOT_SELLABLE`
- [x] 10.18 测试 `get_seed_shop_items()` 返回全部种子并包含关键字段
- [x] 10.19 测试 `get_shop_items()` 包含种子、肥料、装饰物并排除收获物
- [x] 10.20 测试 `get_sellable_inventory_items()` 仅返回可出售收获物
- [x] 10.21 测试成功与失败交易信号计数
- [x] 10.22 测试 `export_save_data()` / `import_save_data()` 统计回放

## 11. 验证与收尾

- [x] 11.1 运行或手动打开 `test_economy_manager.tscn`，确认输出 `=== EconomyManager 自动化测试 ===`
- [x] 11.2 确认所有购买测试通过
- [x] 11.3 确认所有出售测试通过
- [x] 11.4 确认所有价格查询测试通过
- [x] 11.5 确认所有列表查询测试通过
- [x] 11.6 确认所有交易失败场景无状态污染
- [x] 11.7 检查 GDScript 静态类型、Tab 缩进、Autoload 不使用 `class_name`
- [x] 11.8 检查 `EconomyManager` 不直接修改 `DataManager` 原始数据
- [x] 11.9 检查金币变更均经由 `GameManager`，库存变更均经由 `InventoryManager`
- [x] 11.10 检查 `project.godot` Autoload 顺序符合 PRD4
