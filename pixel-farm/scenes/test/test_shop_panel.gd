extends Node2D
## ShopPanel 自动化测试。

@onready var label: Label = $Label
@onready var panel: Control = $ShopPanel
@onready var player: CharacterBody2D = $Player
@onready var interaction_controller: Node = $FarmInteractionController

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []
var _opened_count: int = 0
var _closed_count: int = 0
var _tab_values: Array[String] = []
var _quantity_values: Array[int] = []
var _selected_info_received: Dictionary = {}
var _blocked_values: Array[bool] = []


func _ready() -> void:
	_connect_signals_once()
	_reset_state()
	panel.setup(self)

	print("=== ShopPanel 自动化测试 ===")
	test_project_actions_and_event_bus()
	test_initialization_and_lists()
	test_panel_open_close_and_input_block()
	test_selection_lock_and_safe_info()
	test_quantity_limits_and_total_price()
	test_buy_success_and_failures()
	test_sell_success_and_inventory_zero()
	test_external_refresh_and_load()
	test_row_fallback_and_mouse_block()

	panel.close_panel()
	InventoryManager.debug_clear()
	var summary := "=== ShopPanel 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	_results.append(summary)
	label.text = "\n".join(_results)
	print(summary)


func test_project_actions_and_event_bus() -> void:
	_assert(InputMap.has_action("cancel"), "InputMap 注册 cancel")
	var has_escape := false
	var has_right_mouse := false
	for event in InputMap.action_get_events("cancel"):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			has_escape = has_escape or key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE
		elif event is InputEventMouseButton:
			has_right_mouse = has_right_mouse or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
	_assert(has_escape, "cancel 绑定 Escape")
	_assert(has_right_mouse, "cancel 绑定鼠标右键")
	_assert(EventBus.has_signal("shop_panel_opened"), "EventBus 注册商店打开信号")
	_assert(EventBus.has_signal("shop_panel_closed"), "EventBus 注册商店关闭信号")
	_assert(EventBus.has_signal("shop_tab_changed"), "EventBus 注册商店 Tab 信号")
	_assert(EventBus.has_signal("shop_item_selected"), "EventBus 注册商品选择信号")
	_assert(EventBus.has_signal("shop_quantity_changed"), "EventBus 注册数量变化信号")


func test_initialization_and_lists() -> void:
	_reset_state()
	panel.set_tab(panel.ShopTab.BUY)
	_assert(panel.get_current_tab_id() == "buy", "默认/购买 Tab 标识正确")
	_assert(panel.gold_label.text == "金币：100", "余额与 GameManager.gold 一致")
	_assert(panel.row_views.size() == EconomyManager.get_shop_items().size(), "购买列表行数与 EconomyManager 一致")
	var has_consumable := false
	var has_decoration := false
	for item in panel.get_current_items():
		has_consumable = has_consumable or str(item.get("type", "")) == "consumable"
		has_decoration = has_decoration or str(item.get("type", "")) == "decoration"
	_assert(has_consumable and has_decoration, "购买列表包含消耗品和装饰")

	InventoryManager.add_item("harvest_carrot", 4)
	panel.set_tab(panel.ShopTab.SELL)
	_assert(panel.get_current_tab_id() == "sell", "切换到出售 Tab")
	_assert(panel.row_views.size() == 1, "出售列表只显示可售库存")
	_assert(panel.get_current_items()[0]["quantity"] == 4, "出售列表聚合库存数量")
	_assert(panel.selected_item_id == "" and panel.selected_quantity == 0, "Tab 切换清空选择与数量")
	_assert(_tab_values.has("sell"), "Tab 切换广播 sell")

	InventoryManager.debug_clear()
	panel.rebuild_list()
	_assert(panel.empty_label.visible, "无可售物品显示空列表提示")
	_assert(panel.confirm_button.disabled, "空列表禁用确认按钮")


func test_panel_open_close_and_input_block() -> void:
	_reset_state()
	panel.close_panel()
	player.set_can_move(true)
	player.set_can_interact(true)
	var tree_was_paused := get_tree().paused
	panel.open_panel()
	panel.open_panel()
	_assert(panel.is_panel_open() and panel.visible, "open_panel 打开并显示商店")
	_assert(_opened_count == 1, "重复打开不重复发射事件")
	_assert(not player.is_movement_enabled(), "商店打开禁用玩家移动")
	_assert(not player.is_interaction_enabled(), "商店打开禁用玩家交互")
	_assert(interaction_controller.ui_input_blocked, "商店打开阻塞农田控制器")
	var blocked_result: Dictionary = interaction_controller.request_tile_interaction(Vector2i.ZERO, "test")
	_assert(blocked_result.get("reason", "") == "ui_input_blocked", "输入锁期间拒绝农田交互")
	var debug_event := InputEventKey.new()
	debug_event.pressed = true
	debug_event.physical_keycode = KEY_1
	_assert(not interaction_controller.handle_debug_key_event(debug_event), "输入锁期间调试数字键不生效")
	_assert(not player.try_interact(), "输入锁期间 E 交互被拒绝")
	_assert(get_tree().paused == tree_was_paused, "商店打开不暂停 SceneTree")
	panel.close_panel()
	panel.close_panel()
	_assert(not panel.is_panel_open() and not panel.visible, "close_panel 关闭并隐藏商店")
	_assert(_closed_count == 1, "重复关闭不重复发射事件")
	_assert(player.is_movement_enabled() and player.is_interaction_enabled(), "关闭商店恢复玩家控制")
	_assert(not interaction_controller.ui_input_blocked, "关闭商店解除农田输入锁")
	_assert(_blocked_values == [true, false], "UI 输入锁按打开关闭顺序广播")

	player.set_can_move(false)
	player.set_can_interact(false)
	panel.open_panel()
	panel.close_panel()
	_assert(not player.is_movement_enabled(), "关闭商店不覆盖原有移动锁")
	_assert(not player.is_interaction_enabled(), "关闭商店不覆盖原有交互锁")
	player.set_can_move(true)
	player.set_can_interact(true)


func test_selection_lock_and_safe_info() -> void:
	_reset_state()
	GameManager.gold = 1000
	GameManager.level = 1
	panel.set_tab(panel.ShopTab.BUY)
	panel.select_item("seed_strawberry")
	var locked_info: Dictionary = panel.get_selected_info()
	_assert(panel.selected_item_id == "seed_strawberry", "锁定商品仍可选择查看")
	_assert(not bool(locked_info.get("unlocked", true)), "锁定商品详情状态正确")
	_assert(panel.unlock_label.visible and panel.unlock_label.text.contains("Lv."), "锁定商品显示解锁等级")
	_assert(panel.selected_quantity == 0 and panel.confirm_button.disabled, "锁定商品禁用数量和购买")

	panel.select_item("seed_carrot")
	_assert(panel.item_name_label.text == "胡萝卜种子", "选中商品显示名称")
	_assert(panel.unit_price_label.text == "单价：10 金", "选中商品显示单价")
	_assert(_selected_info_received.get("item_id", "") == "seed_carrot", "选择事件携带 item_id")
	_selected_info_received["name"] = "被外部修改"
	_assert(panel.get_selected_info().get("name", "") == "胡萝卜种子", "选择事件 info 为安全副本")


func test_quantity_limits_and_total_price() -> void:
	_reset_state()
	GameManager.gold = 85
	panel.set_tab(panel.ShopTab.BUY)
	panel.select_item("seed_carrot")
	panel.set_quantity(10)
	_assert(panel.selected_quantity == 8, "购买数量按金币上限收敛")
	_assert(panel.total_price_label.text == "总价：80 金", "总价随数量正确计算")
	_assert(_quantity_values.has(8), "数量变化广播收敛后数值")

	var capacity_slots: Array = [{"item_id": "seed_carrot", "quantity": 96}]
	for _index in range(1, InventoryManager.MAX_SLOTS):
		capacity_slots.append({"item_id": "watering_can", "quantity": 1})
	InventoryManager.import_save_data({"slots": capacity_slots, "selected_hotbar": 0})
	GameManager.gold = 1000
	EventBus.gold_changed.emit(GameManager.gold, 0)
	panel.select_item("seed_carrot")
	panel.set_quantity_max()
	_assert(panel.get_max_quantity() == 3 and panel.selected_quantity == 3, "购买最大值取容量上限")

	InventoryManager.debug_clear()
	InventoryManager.add_item("harvest_carrot", 6)
	panel.set_tab(panel.ShopTab.SELL)
	panel.select_item("harvest_carrot")
	panel.set_quantity(10)
	_assert(panel.selected_quantity == 6, "出售数量按库存上限收敛")
	_assert(panel.total_price_label.text == "总价：150 金", "出售总价正确计算")


func test_buy_success_and_failures() -> void:
	_reset_state()
	GameManager.gold = 100
	panel.set_tab(panel.ShopTab.BUY)
	panel.select_item("seed_carrot")
	panel.set_quantity(5)
	var result: Dictionary = panel.confirm_transaction()
	_assert(bool(result.get("success", false)), "商店面板购买成功")
	_assert(GameManager.gold == 50, "购买成功扣除金币")
	_assert(InventoryManager.get_item_count("seed_carrot") == 5, "购买成功物品进入背包")
	_assert(panel.gold_label.text == "金币：50", "购买后余额局部刷新")

	GameManager.gold = 5
	EventBus.gold_changed.emit(5, -45)
	panel.select_item("seed_carrot")
	_assert(panel.selected_quantity == 0 and panel.confirm_button.disabled, "金币不足时确认禁用")
	_assert(panel.footer_hint_label.text == "金币不足", "金币不足显示明确提示")

	var full_slots: Array = []
	for _index in range(InventoryManager.MAX_SLOTS):
		full_slots.append({"item_id": "watering_can", "quantity": 1})
	InventoryManager.import_save_data({"slots": full_slots, "selected_hotbar": 0})
	GameManager.gold = 1000
	EventBus.gold_changed.emit(1000, 995)
	panel.select_item("seed_carrot")
	_assert(panel.selected_quantity == 0 and panel.footer_hint_label.text == "背包空间不足", "背包满时禁用购买并提示")

	panel.select_item("seed_strawberry")
	var locked_result: Dictionary = panel.confirm_transaction()
	_assert(not bool(locked_result.get("success", false)), "锁定商品无法通过面板购买")
	_assert(locked_result.get("error_code", "") == "INVALID_QUANTITY", "锁定商品不提交交易")


func test_sell_success_and_inventory_zero() -> void:
	_reset_state()
	GameManager.gold = 0
	InventoryManager.add_item("harvest_carrot", 3)
	panel.set_tab(panel.ShopTab.SELL)
	panel.select_item("harvest_carrot")
	panel.set_quantity(2)
	var partial_result: Dictionary = panel.confirm_transaction()
	_assert(bool(partial_result.get("success", false)), "出售部分库存成功")
	_assert(GameManager.gold == 50, "出售增加正确金币")
	_assert(InventoryManager.get_item_count("harvest_carrot") == 1, "出售扣除正确库存")
	_assert(panel.get_current_items()[0]["quantity"] == 1, "出售后行库存刷新")

	panel.set_quantity_max()
	var final_result: Dictionary = panel.confirm_transaction()
	_assert(bool(final_result.get("success", false)), "出售剩余库存成功")
	_assert(InventoryManager.get_item_count("harvest_carrot") == 0, "出售清空库存")
	_assert(panel.row_views.is_empty() and panel.empty_label.visible, "库存归零移除出售行")
	_assert(panel.selected_item_id == "" and panel.selected_quantity == 0, "库存归零清空详情选择")

	var failed_result: Dictionary = EconomyManager.can_sell_item("harvest_carrot", 1)
	_assert(failed_result.get("error_code", "") == "NOT_ENOUGH_ITEMS", "库存不足预校验保持数据不变")


func test_external_refresh_and_load() -> void:
	_reset_state()
	panel.set_tab(panel.ShopTab.BUY)
	panel.select_item("seed_carrot")
	GameManager.gold = 20
	EventBus.gold_changed.emit(20, -80)
	_assert(panel.gold_label.text == "金币：20", "外部 gold_changed 刷新余额")
	_assert(panel.get_max_quantity() == 2, "外部金币变化刷新购买上限")

	InventoryManager.add_item("seed_carrot", 2)
	_assert(panel.get_selected_info().get("owned_count", 0) == 2, "inventory_changed 刷新已拥有数量")

	GameManager.level = 7
	EventBus.level_up.emit(7)
	panel.select_item("seed_strawberry")
	_assert(bool(panel.get_selected_info().get("unlocked", false)), "升级事件刷新种子解锁状态")

	GameManager.gold = 345
	EventBus.game_loaded.emit(0, {})
	_assert(panel.gold_label.text == "金币：345", "读档事件全量刷新余额")
	_assert(panel.selected_item_id == "", "读档事件清空旧选择")


func test_row_fallback_and_mouse_block() -> void:
	var row_scene: PackedScene = load("res://scenes/ui/shop/shop_item_row.tscn")
	var row: Control = row_scene.instantiate()
	add_child(row)
	row.set_buy_data({"item_id": "unknown_shop_item", "price": -1})
	_assert(row.name_label.text == "unknown_shop_item", "商品行缺失名称回退 item_id")
	_assert(row.price_label.text == "价格无效", "商品行非法价格安全回退")
	_assert(row.type_color.color == Color("#686868"), "商品行未知类型使用灰色")
	row.queue_free()
	_assert(panel.get_node("DimBackground").mouse_filter == Control.MOUSE_FILTER_STOP, "全屏遮罩阻止鼠标穿透")


func _reset_state() -> void:
	panel.close_panel()
	GameManager.gold = 100
	GameManager.level = 1
	GameManager.xp = 0
	GameManager.stats = {
		"total_harvests": 0,
		"total_gold_earned": 0,
		"total_water_count": 0,
		"crops_planted_types": [],
	}
	InventoryManager.debug_clear()
	EconomyManager.debug_reset_stats()
	panel.current_tab = panel.ShopTab.BUY
	panel.refresh_gold()
	panel.rebuild_list()
	panel.clear_selection()
	_opened_count = 0
	_closed_count = 0
	_tab_values.clear()
	_quantity_values.clear()
	_selected_info_received.clear()
	_blocked_values.clear()


func _connect_signals_once() -> void:
	if not EventBus.shop_panel_opened.is_connected(_on_shop_opened):
		EventBus.shop_panel_opened.connect(_on_shop_opened)
	if not EventBus.shop_panel_closed.is_connected(_on_shop_closed):
		EventBus.shop_panel_closed.connect(_on_shop_closed)
	if not EventBus.shop_tab_changed.is_connected(_on_shop_tab_changed):
		EventBus.shop_tab_changed.connect(_on_shop_tab_changed)
	if not EventBus.shop_item_selected.is_connected(_on_shop_item_selected):
		EventBus.shop_item_selected.connect(_on_shop_item_selected)
	if not EventBus.shop_quantity_changed.is_connected(_on_shop_quantity_changed):
		EventBus.shop_quantity_changed.connect(_on_shop_quantity_changed)
	if not EventBus.ui_input_block_changed.is_connected(_on_ui_input_block_changed):
		EventBus.ui_input_block_changed.connect(_on_ui_input_block_changed)


func _on_shop_opened() -> void:
	_opened_count += 1


func _on_shop_closed() -> void:
	_closed_count += 1


func _on_shop_tab_changed(tab: String) -> void:
	_tab_values.append(tab)


func _on_shop_item_selected(_item_id: String, info: Dictionary) -> void:
	_selected_info_received = info


func _on_shop_quantity_changed(_item_id: String, quantity: int) -> void:
	_quantity_values.append(quantity)


func _on_ui_input_block_changed(blocked: bool) -> void:
	_blocked_values.append(blocked)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
