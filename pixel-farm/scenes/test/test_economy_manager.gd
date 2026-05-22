extends Node2D
## EconomyManager 自动化测试脚本

@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []
var _transaction_completed_count: int = 0
var _transaction_failed_count: int = 0
var _item_purchased_count: int = 0
var _item_sold_count: int = 0


func _ready() -> void:
	_connect_signals_once()
	_reset_state()

	print("=== EconomyManager 自动化测试 ===")

	test_get_buy_price_seed()
	test_get_sell_price_harvest()
	test_buy_seed_success()
	test_buy_seed_not_enough_gold()
	test_buy_seed_invalid_crop()
	test_buy_item_invalid_quantity()
	test_buy_item_inventory_full()
	test_buy_locked_seed()
	test_buy_harvest_not_buyable()
	test_sell_harvest_success()
	test_sell_harvest_not_enough_items()
	test_sell_invalid_item()
	test_sell_seed_not_sellable()
	test_get_seed_shop_items()
	test_get_shop_items()
	test_get_sellable_inventory_items()
	test_transaction_signals()
	test_export_import_stats()

	var summary := "=== EconomyManager 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_get_buy_price_seed() -> void:
	_reset_state()
	_assert(EconomyManager.get_buy_price("seed_carrot") == 10, "种子购买价格正确")


func test_get_sell_price_harvest() -> void:
	_reset_state()
	_assert(EconomyManager.get_sell_price("harvest_carrot") == 25, "收获物出售价格正确")


func test_buy_seed_success() -> void:
	_reset_state()
	GameManager.gold = 100
	var result := EconomyManager.buy_seed("carrot", 3)
	_assert(result["success"] == true, "购买种子成功结果为 true")
	_assert(GameManager.gold == 70, "购买种子扣除正确金币")
	_assert(InventoryManager.get_item_count("seed_carrot") == 3, "购买种子进入背包")
	_assert(EconomyManager.stats["total_gold_spent"] == 30, "购买统计累计金币支出")
	_assert(EconomyManager.stats["total_items_bought"] == 3, "购买统计累计物品数量")


func test_buy_seed_not_enough_gold() -> void:
	_reset_state()
	GameManager.gold = 5
	var result := EconomyManager.buy_seed("carrot", 1)
	_assert(result["success"] == false, "金币不足购买失败")
	_assert(result["error_code"] == EconomyManager.ERR_NOT_ENOUGH_GOLD, "金币不足错误码正确")
	_assert(GameManager.gold == 5, "金币不足时金币不变")
	_assert(InventoryManager.get_item_count("seed_carrot") == 0, "金币不足时背包不变")


func test_buy_seed_invalid_crop() -> void:
	_reset_state()
	var result := EconomyManager.buy_seed("missing_crop", 1)
	_assert(result["success"] == false, "无效作物购买失败")
	_assert(result["error_code"] == EconomyManager.ERR_INVALID_CROP, "无效作物错误码正确")


func test_buy_item_invalid_quantity() -> void:
	_reset_state()
	var result := EconomyManager.buy_item("seed_carrot", 0)
	_assert(result["success"] == false, "无效购买数量失败")
	_assert(result["error_code"] == EconomyManager.ERR_INVALID_QUANTITY, "无效购买数量错误码正确")


func test_buy_item_inventory_full() -> void:
	_reset_state()
	GameManager.gold = 1000
	InventoryManager.add_item("watering_can", InventoryManager.MAX_SLOTS)
	var result := EconomyManager.buy_item("seed_carrot", 1)
	_assert(result["success"] == false, "满包购买失败")
	_assert(result["error_code"] == EconomyManager.ERR_INVENTORY_FULL, "满包错误码正确")
	_assert(GameManager.gold == 1000, "满包购买金币不变")
	_assert(InventoryManager.get_item_count("seed_carrot") == 0, "满包购买不添加物品")


func test_buy_locked_seed() -> void:
	_reset_state()
	GameManager.gold = 1000
	GameManager.level = 1
	var result := EconomyManager.buy_seed("strawberry", 1)
	_assert(result["success"] == false, "未解锁种子购买失败")
	_assert(result["error_code"] == EconomyManager.ERR_LOCKED, "未解锁错误码正确")
	_assert(InventoryManager.get_item_count("seed_strawberry") == 0, "未解锁购买不添加物品")


func test_buy_harvest_not_buyable() -> void:
	_reset_state()
	GameManager.gold = 1000
	var result := EconomyManager.buy_item("harvest_carrot", 1)
	_assert(result["success"] == false, "收获物不可购买")
	_assert(result["error_code"] == EconomyManager.ERR_NOT_BUYABLE, "不可购买错误码正确")


func test_sell_harvest_success() -> void:
	_reset_state()
	GameManager.gold = 0
	InventoryManager.add_item("harvest_carrot", 2)
	var result := EconomyManager.sell_harvest("carrot", 2)
	_assert(result["success"] == true, "出售收获物成功")
	_assert(GameManager.gold == 50, "出售收获物增加金币")
	_assert(InventoryManager.get_item_count("harvest_carrot") == 0, "出售收获物扣除背包")
	_assert(EconomyManager.stats["total_gold_earned_from_sales"] == 50, "出售统计累计金币收入")
	_assert(EconomyManager.stats["total_items_sold"] == 2, "出售统计累计物品数量")


func test_sell_harvest_not_enough_items() -> void:
	_reset_state()
	GameManager.gold = 0
	InventoryManager.add_item("harvest_carrot", 1)
	var result := EconomyManager.sell_harvest("carrot", 2)
	_assert(result["success"] == false, "物品不足出售失败")
	_assert(result["error_code"] == EconomyManager.ERR_NOT_ENOUGH_ITEMS, "物品不足错误码正确")
	_assert(GameManager.gold == 0, "物品不足出售金币不变")
	_assert(InventoryManager.get_item_count("harvest_carrot") == 1, "物品不足出售背包不变")


func test_sell_invalid_item() -> void:
	_reset_state()
	var result := EconomyManager.sell_item("missing_item", 1)
	_assert(result["success"] == false, "出售无效物品失败")
	_assert(result["error_code"] == EconomyManager.ERR_INVALID_ITEM, "出售无效物品错误码正确")


func test_sell_seed_not_sellable() -> void:
	_reset_state()
	InventoryManager.add_item("seed_carrot", 1)
	var result := EconomyManager.sell_item("seed_carrot", 1)
	_assert(result["success"] == false, "种子默认不可出售")
	_assert(result["error_code"] == EconomyManager.ERR_NOT_SELLABLE, "不可出售错误码正确")
	_assert(InventoryManager.get_item_count("seed_carrot") == 1, "不可出售时背包不变")


func test_get_seed_shop_items() -> void:
	_reset_state()
	var items := EconomyManager.get_seed_shop_items()
	_assert(items.size() == 10, "种子商店返回 10 种种子")
	var first: Dictionary = items[0]
	_assert(first.has("price") and first.has("unlocked") and first.has("owned_count") and first.has("can_afford_one"), "种子商品包含关键字段")


func test_get_shop_items() -> void:
	_reset_state()
	var items := EconomyManager.get_shop_items()
	var has_fertilizer := false
	var has_fence := false
	var has_harvest := false
	for item in items:
		if item["item_id"] == "fertilizer":
			has_fertilizer = true
		if item["item_id"] == "fence_wood":
			has_fence = true
		if str(item["item_id"]).begins_with("harvest_"):
			has_harvest = true
	_assert(has_fertilizer, "全部商店包含肥料")
	_assert(has_fence, "全部商店包含装饰物")
	_assert(not has_harvest, "全部商店排除收获物")


func test_get_sellable_inventory_items() -> void:
	_reset_state()
	InventoryManager.add_item("harvest_carrot", 2)
	InventoryManager.add_item("seed_carrot", 5)
	var items := EconomyManager.get_sellable_inventory_items()
	_assert(items.size() == 1, "可出售列表仅返回收获物")
	_assert(items[0]["item_id"] == "harvest_carrot", "可出售列表 item_id 正确")
	_assert(items[0]["total_price"] == 50, "可出售列表总价正确")


func test_transaction_signals() -> void:
	_reset_state()
	GameManager.gold = 100
	EconomyManager.buy_seed("carrot", 1)
	EconomyManager.buy_seed("carrot", 99)
	_assert(_transaction_completed_count == 1, "成功交易信号计数正确")
	_assert(_transaction_failed_count == 1, "失败交易信号计数正确")
	_assert(_item_purchased_count == 1, "失败购买不发射 item_purchased")


func test_export_import_stats() -> void:
	_reset_state()
	GameManager.gold = 100
	EconomyManager.buy_seed("carrot", 2)
	var exported := EconomyManager.export_save_data()
	EconomyManager.debug_reset_stats()
	EconomyManager.import_save_data(exported)
	_assert(EconomyManager.stats["total_gold_spent"] == 20, "经济统计导入恢复金币支出")
	_assert(EconomyManager.stats["total_items_bought"] == 2, "经济统计导入恢复购买数量")
	_assert(EconomyManager.stats["total_transactions"] == 1, "经济统计导入恢复交易次数")


func _reset_state() -> void:
	GameManager.gold = 100
	GameManager.level = 1
	GameManager.stats = {
		"total_harvests": 0,
		"total_gold_earned": 0,
		"total_water_count": 0,
		"crops_planted_types": [],
	}
	InventoryManager.debug_clear()
	EconomyManager.debug_reset_stats()
	_reset_signal_counts()


func _reset_signal_counts() -> void:
	_transaction_completed_count = 0
	_transaction_failed_count = 0
	_item_purchased_count = 0
	_item_sold_count = 0


func _connect_signals_once() -> void:
	if not EventBus.transaction_completed.is_connected(_on_transaction_completed):
		EventBus.transaction_completed.connect(_on_transaction_completed)
	if not EventBus.transaction_failed.is_connected(_on_transaction_failed):
		EventBus.transaction_failed.connect(_on_transaction_failed)
	if not EventBus.item_purchased.is_connected(_on_item_purchased):
		EventBus.item_purchased.connect(_on_item_purchased)
	if not EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.connect(_on_item_sold)


func _on_transaction_completed(_result: Dictionary) -> void:
	_transaction_completed_count += 1


func _on_transaction_failed(_result: Dictionary) -> void:
	_transaction_failed_count += 1


func _on_item_purchased(_item_id: String, _price: int) -> void:
	_item_purchased_count += 1


func _on_item_sold(_item_id: String, _price: int) -> void:
	_item_sold_count += 1


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
