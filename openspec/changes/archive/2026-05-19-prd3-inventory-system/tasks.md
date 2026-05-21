## 1. Artifact 编写

- [x] 1.1 完成 proposal.md
- [x] 1.2 完成 design.md
- [x] 1.3 完成 specs/*/spec.md
- [x] 1.4 完成 tasks.md 实施清单

## 2. 数据表与配置

- [x] 2.1 修改 `pixel-farm/data/items.json`，为现有物品补充 `stackable` / `max_stack` 字段
- [x] 2.2 新增 10 个种子物品：`seed_carrot`、`seed_tomato`、`seed_cabbage`、`seed_corn`、`seed_potato`、`seed_strawberry`、`seed_pepper`、`seed_pumpkin`、`seed_eggplant`、`seed_broccoli`
- [x] 2.3 新增 10 个收获物品：`harvest_carrot`、`harvest_tomato`、`harvest_cabbage`、`harvest_corn`、`harvest_potato`、`harvest_strawberry`、`harvest_pepper`、`harvest_pumpkin`、`harvest_eggplant`、`harvest_broccoli`
- [x] 2.4 修改 `pixel-farm/project.godot`，注册 `InventoryManager` Autoload，加载顺序为 `EventBus → DataManager → GameManager → CropManager → InventoryManager → SceneManager → AudioManager`

## 3. EventBus 信号扩展

- [x] 3.1 在 `pixel-farm/scripts/autoload/event_bus.gd` 新增 `hotbar_selected(index: int)` 信号
- [x] 3.2 新增 `item_added(item_id: String, quantity: int, slot_index: int)` 信号
- [x] 3.3 新增 `item_removed(item_id: String, quantity: int)` 信号
- [x] 3.4 保持并复用已有 `inventory_changed(slot_index: int)` 与 `inventory_full()` 信号

## 4. InventoryManager 核心数据层

- [x] 4.1 新增 `pixel-farm/scripts/autoload/inventory_manager.gd`，不使用 `class_name`
- [x] 4.2 定义 `MAX_SLOTS = 20`、`HOTBAR_SIZE = 9`、`_slots`、`_selected_hotbar`
- [x] 4.3 实现初始化逻辑：创建 20 个空槽，并支持从 `GameManager.inventory` 兼容初始化
- [x] 4.4 实现物品元数据读取 helper：从 `DataManager.get_item()` 获取 `stackable` / `max_stack`，未知物品 `push_warning()` 并使用默认规则
- [x] 4.5 实现 `_sync_to_game_manager()`，将 slot 数据汇总同步到 `GameManager.inventory`
- [x] 4.6 确保所有查询返回 `.duplicate(true)` 或安全值，避免外部修改内部 `_slots`

## 5. InventoryManager 增删与容量 API

- [x] 5.1 实现 `add_item(item_id: String, quantity: int = 1) -> int`
- [x] 5.2 实现可堆叠物品“先合并已有同类格，再放入空格”的添加策略
- [x] 5.3 实现不可堆叠物品每个占用独立格的添加策略
- [x] 5.4 实现背包容量不足时返回实际添加数量并发射 `inventory_full()`
- [x] 5.5 实现 `remove_item(item_id: String, quantity: int = 1) -> int`
- [x] 5.6 实现 `remove_from_slot(slot_index: int, quantity: int = 1) -> int`
- [x] 5.7 每次实际变更 slot 时发射 `inventory_changed(slot_index)`，物品增删时发射 `item_added` / `item_removed`

## 6. InventoryManager 槽位操作 API

- [x] 6.1 实现 `swap_slots(from_index: int, to_index: int) -> bool`
- [x] 6.2 实现 `move_to_slot(from_index: int, to_index: int) -> bool`
- [x] 6.3 实现 `merge_slots(from_index: int, to_index: int) -> int`
- [x] 6.4 实现 `smart_place(from_index: int, to_index: int) -> bool`
- [x] 6.5 实现 `discard_slot(slot_index: int, quantity: int = -1) -> bool`
- [x] 6.6 统一处理越界、空槽、不同物品、满堆叠等边界情况

## 7. InventoryManager 查询 API

- [x] 7.1 实现 `get_slot(slot_index: int) -> Variant`
- [x] 7.2 实现 `get_all_slots() -> Array`
- [x] 7.3 实现 `get_item_count(item_id: String) -> int`
- [x] 7.4 实现 `has_item(item_id: String, quantity: int = 1) -> bool`
- [x] 7.5 实现 `is_full() -> bool`
- [x] 7.6 实现 `get_empty_slot_count() -> int`
- [x] 7.7 实现 `get_addable_count(item_id: String) -> int`
- [x] 7.8 实现 `get_items_by_type(type: String) -> Array`
- [x] 7.9 实现 `find_item_slot(item_id: String) -> int`

## 8. 快捷栏数据层

- [x] 8.1 实现 `get_hotbar_slots() -> Array`，返回 slot 0-8 的副本
- [x] 8.2 实现 `select_hotbar(index: int) -> void`，合法范围为 0-8
- [x] 8.3 成功切换快捷栏时发射 `hotbar_selected(index)`
- [x] 8.4 实现 `get_selected_item() -> Variant`
- [x] 8.5 实现 `use_selected_item() -> String`，消耗当前选中槽位 1 个物品，空槽返回空字符串
- [x] 8.6 确保 `InventoryManager` 不主动监听键盘输入，数字键选择留给 PRD13 HUD

## 9. 存档导入导出与 GameManager 兼容

- [x] 9.1 实现 `export_save_data() -> Dictionary`，导出 `slots` 和 `selected_hotbar`
- [x] 9.2 实现 `import_save_data(data: Dictionary) -> void`，恢复 slots 顺序和 selected hotbar
- [x] 9.3 导入时修正 slots 长度为 20，并清理非法数量/非法槽位
- [x] 9.4 导入旧版 `GameManager.inventory` 字典时按正常堆叠规则尽量恢复到 slots
- [x] 9.5 评估并必要时调整 `GameManager.save_game()` / `load_game()`，保证 PRD3 slot 级库存数据可存取且旧字段兼容

## 10. CropManager 集成

- [x] 10.1 修改 `CropManager.plant_crop()`，使用 `InventoryManager.has_item()` / `remove_item()` 检查并扣除种子
- [x] 10.2 修改 `CropManager.harvest_crop()`，使用 `InventoryManager.add_item("harvest_" + crop_id, 1)` 添加收获物
- [x] 10.3 处理收获物无法入包的边界：根据 `add_item()` 返回数量决定是否清除作物和发射收获信号
- [x] 10.4 确保作物系统仍同步 `GameManager.farm_data`，不直接修改 `GameManager.inventory`

## 11. 测试场景与自动化测试

- [x] 11.1 新增 `pixel-farm/scenes/test/test_inventory_manager.gd`，测试脚本 `extends Node2D`
- [x] 11.2 新增 `pixel-farm/scenes/test/test_inventory_manager.tscn` 并绑定测试脚本
- [x] 11.3 实现 `_assert(condition: bool, message: String)` 测试 helper 和通过/失败计数
- [x] 11.4 测试添加物品：基础添加、堆叠、溢出、不可堆叠、满包
- [x] 11.5 测试移除物品：基础移除、部分移除、不存在物品、指定格移除
- [x] 11.6 测试槽位操作：交换、空格交换、移动、合并、智能放置、丢弃
- [x] 11.7 测试查询接口：has_item、get_item_count、get_items_by_type、find_item_slot、is_full、get_empty_slot_count、get_addable_count
- [x] 11.8 测试快捷栏：选择、使用物品、使用空槽
- [x] 11.9 测试导入导出：export/import 后槽位、数量、selected hotbar 保持一致
- [x] 11.10 测试 debug helper：debug_clear 清空背包并同步兼容 summary

## 12. 验证与收尾

- [x] 12.1 运行或手动打开 `test_inventory_manager.tscn`，确认测试输出 `=== InventoryManager 自动化测试 ===`
- [x] 12.2 确认所有测试用例通过，输出通过/失败汇总（InventoryManager: 39 通过, 0 失败；CropManager 回归: 47 通过, 0 失败）
- [x] 12.3 检查 GDScript 静态类型、Tab 缩进、Autoload 不使用 `class_name`
- [x] 12.4 检查 `DataManager` 查询数据不被 `InventoryManager` 直接修改
- [x] 12.5 检查所有库存状态变更都通过 `EventBus` 发射信号
- [x] 12.6 检查 `GameManager.inventory` 与 `InventoryManager.get_item_count()` 汇总一致
- [x] 12.7 更新相关 README 或调试说明（如有必要）
