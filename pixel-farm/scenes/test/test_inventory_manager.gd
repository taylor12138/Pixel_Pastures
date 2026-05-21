extends Node2D
## InventoryManager 自动化测试脚本

@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []


func _ready() -> void:
	GameManager.start_new_game("库存测试农夫")
	InventoryManager.debug_clear()

	print("=== InventoryManager 自动化测试 ===")

	test_add_item_basic()
	test_add_item_stack_overflow()
	test_add_non_stackable_item()
	test_add_inventory_full()
	test_is_full_with_partial_stacks()
	test_remove_item_basic()
	test_remove_missing_item()
	test_remove_from_slot()
	test_slot_swap_move_merge_smart_discard()
	test_query_interfaces()
	test_hotbar()
	test_export_import()
	test_debug_clear()

	var summary := "=== 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_add_item_basic() -> void:
	InventoryManager.debug_clear()
	var added := InventoryManager.add_item("seed_carrot", 10)
	_assert(added == 10, "基础添加返回实际添加数量")
	_assert(InventoryManager.get_item_count("seed_carrot") == 10, "添加后数量正确")
	_assert(GameManager.inventory.get("seed_carrot", 0) == 10, "GameManager 兼容汇总同步")


func test_add_item_stack_overflow() -> void:
	InventoryManager.debug_clear()
	var added := InventoryManager.add_item("seed_carrot", 105)
	var slot_0 = InventoryManager.get_slot(0)
	var slot_1 = InventoryManager.get_slot(1)
	_assert(added == 105, "堆叠溢出添加总数正确")
	_assert(slot_0["quantity"] == 99, "第一格填满 max_stack")
	_assert(slot_1["quantity"] == 6, "剩余数量进入下一空格")


func test_add_non_stackable_item() -> void:
	InventoryManager.debug_clear()
	var added := InventoryManager.add_item("watering_can", 2)
	_assert(added == 2, "不可堆叠物品可添加多个")
	_assert(InventoryManager.get_slot(0)["quantity"] == 1, "不可堆叠第一格数量为 1")
	_assert(InventoryManager.get_slot(1)["quantity"] == 1, "不可堆叠第二格数量为 1")


func test_add_inventory_full() -> void:
	InventoryManager.debug_clear()
	var added_tools := InventoryManager.add_item("watering_can", InventoryManager.MAX_SLOTS)
	var added_extra := InventoryManager.add_item("watering_can", 1)
	_assert(added_tools == InventoryManager.MAX_SLOTS, "填满背包成功")
	_assert(added_extra == 0, "满包时无法继续添加不可堆叠物品")
	_assert(InventoryManager.is_full(), "满包状态为 true")


func test_is_full_with_partial_stacks() -> void:
	InventoryManager.debug_clear()
	for index in range(InventoryManager.MAX_SLOTS):
		InventoryManager.add_item("watering_can", 1)
	InventoryManager.remove_from_slot(0, 1)
	InventoryManager.add_item("seed_carrot", 1)
	_assert(not InventoryManager.is_full(), "无空格但可堆叠物品未满时不算满包")
	_assert(InventoryManager.get_addable_count("seed_carrot") > 0, "可堆叠物品仍可继续添加")


func test_remove_item_basic() -> void:
	InventoryManager.debug_clear()
	InventoryManager.add_item("seed_carrot", 12)
	var removed := InventoryManager.remove_item("seed_carrot", 5)
	_assert(removed == 5, "移除已有物品返回实际移除数量")
	_assert(InventoryManager.get_item_count("seed_carrot") == 7, "移除后剩余数量正确")


func test_remove_missing_item() -> void:
	InventoryManager.debug_clear()
	var removed := InventoryManager.remove_item("seed_carrot", 1)
	_assert(removed == 0, "移除不存在物品返回 0")


func test_remove_from_slot() -> void:
	InventoryManager.debug_clear()
	InventoryManager.add_item("seed_carrot", 10)
	var removed := InventoryManager.remove_from_slot(0, 4)
	_assert(removed == 4, "指定格部分移除返回数量")
	_assert(InventoryManager.get_slot(0)["quantity"] == 6, "指定格部分移除后数量正确")


func test_slot_swap_move_merge_smart_discard() -> void:
	InventoryManager.debug_clear()
	InventoryManager.add_item("seed_carrot", 10)
	InventoryManager.add_item("seed_tomato", 5)
	_assert(InventoryManager.swap_slots(0, 1), "交换两个非空槽成功")
	_assert(InventoryManager.get_slot(0)["item_id"] == "seed_tomato", "交换后 slot 0 正确")
	_assert(InventoryManager.move_to_slot(1, 2), "移动到空槽成功")
	_assert(InventoryManager.get_slot(1) == null, "移动后源槽为空")
	InventoryManager.add_item("seed_carrot", 95)
	var moved_for_merge := InventoryManager.move_to_slot(1, 3)
	var discarded_for_space := InventoryManager.discard_slot(2, 50)
	var merged := InventoryManager.merge_slots(3, 2)
	_assert(moved_for_merge and discarded_for_space and merged == 6, "合并同类堆叠返回实际合并数量")
	_assert(InventoryManager.smart_place(0, 2), "智能放置不同物品时交换成功")
	_assert(InventoryManager.discard_slot(0, 1), "丢弃指定数量成功")


func test_query_interfaces() -> void:
	InventoryManager.debug_clear()
	InventoryManager.add_item("seed_carrot", 12)
	InventoryManager.add_item("harvest_tomato", 3)
	_assert(InventoryManager.has_item("seed_carrot", 10), "has_item 数量满足返回 true")
	_assert(not InventoryManager.has_item("seed_carrot", 13), "has_item 数量不足返回 false")
	_assert(InventoryManager.get_empty_slot_count() == 18, "空槽数量正确")
	_assert(InventoryManager.get_addable_count("seed_carrot") > 0, "可添加数量大于 0")
	_assert(InventoryManager.get_items_by_type("seed").size() == 1, "按 type 查询种子物品")
	_assert(InventoryManager.find_item_slot("seed_carrot") == 0, "查找首个匹配槽位")


func test_hotbar() -> void:
	InventoryManager.debug_clear()
	InventoryManager.add_item("seed_carrot", 2)
	var hotbar := InventoryManager.get_hotbar_slots()
	_assert(hotbar.size() == InventoryManager.HOTBAR_SIZE, "快捷栏返回 9 格")
	InventoryManager.select_hotbar(1)
	_assert(InventoryManager.selected_hotbar_index == 1, "公开快捷栏索引同步更新")
	InventoryManager.select_hotbar(0)
	_assert(InventoryManager.get_selected_item()["item_id"] == "seed_carrot", "选中物品查询正确")
	var used := InventoryManager.use_selected_item()
	_assert(used == "seed_carrot", "使用选中物品返回 item_id")
	_assert(InventoryManager.get_item_count("seed_carrot") == 1, "使用后数量减少")
	InventoryManager.select_hotbar(8)
	_assert(InventoryManager.use_selected_item() == "", "使用空快捷栏返回空字符串")


func test_export_import() -> void:
	InventoryManager.debug_clear()
	InventoryManager.add_item("seed_carrot", 7)
	InventoryManager.select_hotbar(1)
	var exported := InventoryManager.export_save_data()
	InventoryManager.debug_clear()
	InventoryManager.import_save_data(exported)
	_assert(InventoryManager.get_item_count("seed_carrot") == 7, "导入后数量保持一致")
	_assert(InventoryManager.get_selected_hotbar() == 1, "导入后快捷栏选中保持一致")
	_assert(InventoryManager.selected_hotbar_index == 1, "导入后公开快捷栏索引保持一致")


func test_debug_clear() -> void:
	InventoryManager.add_item("seed_carrot", 1)
	InventoryManager.debug_clear()
	_assert(InventoryManager.get_empty_slot_count() == InventoryManager.MAX_SLOTS, "debug_clear 清空全部槽位")
	_assert(GameManager.inventory.is_empty(), "debug_clear 同步清空 GameManager.inventory")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)