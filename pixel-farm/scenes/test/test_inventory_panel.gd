extends Node2D
## InventoryPanel 自动化测试。

@onready var label: Label = $Label
@onready var panel: Control = $InventoryPanel
@onready var player: CharacterBody2D = $Player
@onready var interaction_controller: Node = $FarmInteractionController

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []
var _opened_count: int = 0
var _closed_count: int = 0
var _blocked_values: Array[bool] = []


func _ready() -> void:
	GameManager.start_new_game("背包面板测试农夫")
	InventoryManager.debug_clear()
	panel.setup(interaction_controller, player)
	EventBus.inventory_panel_opened.connect(_on_panel_opened)
	EventBus.inventory_panel_closed.connect(_on_panel_closed)
	EventBus.ui_input_block_changed.connect(_on_ui_block_changed)

	print("=== InventoryPanel 自动化测试 ===")
	test_project_actions_and_event_bus()
	test_slot_initialization_and_rendering()
	test_panel_open_close_and_input_block()
	test_filters_keep_real_indexes()
	test_drag_move_merge_and_swap()
	test_hotbar_and_farm_selection()
	test_discard_flow()
	test_load_refresh_and_unknown_metadata()
	test_inventory_full_feedback()

	panel.close_panel()
	InventoryManager.debug_clear()
	var summary := "=== InventoryPanel 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	_results.append(summary)
	label.text = "\n".join(_results)
	print(summary)


func test_project_actions_and_event_bus() -> void:
	_assert(InputMap.has_action("open_bag"), "InputMap 注册 open_bag")
	_assert(InputMap.has_action("cancel"), "InputMap 注册 cancel")
	_assert(InputMap.action_get_events("open_bag").size() > 0, "open_bag 绑定输入事件")
	var tab_event := InputEventKey.new()
	tab_event.pressed = true
	tab_event.keycode = KEY_TAB
	_assert(tab_event.is_action_pressed("open_bag"), "Tab 键匹配 open_bag")
	_assert(panel._is_open_bag_event(tab_event), "背包面板直接识别 Tab 键")
	_assert(EventBus.has_signal("inventory_panel_opened"), "EventBus 注册面板打开信号")
	_assert(EventBus.has_signal("inventory_drag_completed"), "EventBus 注册拖拽完成信号")
	_assert(EventBus.has_signal("ui_input_block_changed"), "EventBus 注册 UI 输入锁信号")


func test_slot_initialization_and_rendering() -> void:
	InventoryManager.debug_clear()
	panel.refresh_all_slots()
	_assert(panel.slot_views.size() == InventoryManager.MAX_SLOTS, "初始化固定 20 个槽位")
	var indexes_ok := true
	for index in range(panel.slot_views.size()):
		indexes_ok = indexes_ok and panel.slot_views[index].slot_index == index
	_assert(indexes_ok, "槽位绑定真实索引 0-19")
	_assert(not panel.get_slot_view(0).is_item_content_visible(), "空槽位不显示物品内容")
	InventoryManager.add_item("seed_carrot", 12)
	_assert(panel.get_slot_view(0).get_displayed_item_id() == "seed_carrot", "占用槽位显示 item_id")
	_assert(panel.get_slot_view(0).quantity_label.text == "12", "可堆叠数量正确显示")
	_assert(panel.get_slot_view(0).hotbar_label.text == "1", "slot 0 显示快捷栏编号 1")
	_assert(not panel.get_slot_view(9).hotbar_label.visible, "slot 9 不显示快捷栏编号")


func test_panel_open_close_and_input_block() -> void:
	panel.close_panel()
	player.set_can_move(true)
	player.set_can_interact(true)
	var tree_was_paused := get_tree().paused
	panel.open_panel()
	panel.open_panel()
	_assert(panel.is_panel_open() and panel.visible, "open_panel 打开并显示面板")
	_assert(_opened_count == 1, "重复 open_panel 不重复发射打开事件")
	_assert(not player.is_movement_enabled(), "面板打开禁用玩家移动")
	_assert(not player.is_interaction_enabled(), "面板打开禁用玩家交互")
	_assert(interaction_controller.ui_input_blocked, "农田控制器收到 UI 输入锁")
	var blocked_result: Dictionary = interaction_controller.request_tile_interaction(Vector2i.ZERO, "test")
	_assert(blocked_result.get("reason", "") == "ui_input_blocked", "UI 锁期间拒绝农田交互请求")
	var debug_event := InputEventKey.new()
	debug_event.pressed = true
	debug_event.physical_keycode = KEY_1
	_assert(not interaction_controller.handle_debug_key_event(debug_event), "UI 锁期间调试数字键不生效")
	_assert(not player.try_interact(), "UI 锁期间 E 交互入口被拒绝")
	_assert(get_tree().paused == tree_was_paused, "打开背包不暂停 SceneTree")
	panel.close_panel()
	panel.close_panel()
	_assert(not panel.is_panel_open() and not panel.visible, "close_panel 关闭并隐藏面板")
	_assert(_closed_count == 1, "重复 close_panel 不重复发射关闭事件")
	_assert(player.is_movement_enabled(), "关闭面板恢复原移动状态")
	_assert(player.is_interaction_enabled(), "关闭面板恢复原交互状态")
	_assert(not interaction_controller.ui_input_blocked, "关闭面板解除农田输入锁")
	_assert(_blocked_values == [true, false], "UI 输入锁按打开关闭顺序广播")

	player.set_can_move(false)
	player.set_can_interact(false)
	panel.open_panel()
	panel.close_panel()
	_assert(not player.is_movement_enabled(), "关闭面板不覆盖原有移动锁")
	_assert(not player.is_interaction_enabled(), "关闭面板不覆盖原有交互锁")
	player.set_can_move(true)
	player.set_can_interact(true)


func test_filters_keep_real_indexes() -> void:
	_import_slots([
		{"item_id": "seed_carrot", "quantity": 3},
		{"item_id": "harvest_tomato", "quantity": 2},
		{"item_id": "watering_can", "quantity": 1},
	])
	panel.set_filter(panel.FilterType.SEED)
	_assert(not panel.get_slot_view(0).filtered_out, "种子筛选保留种子")
	_assert(panel.get_slot_view(1).filtered_out, "种子筛选隐藏收获物")
	_assert(panel.get_slot_view(2).filtered_out, "种子筛选隐藏工具")
	_assert(panel.get_slot_view(1).slot_index == 1, "筛选不改变真实槽位索引")
	panel.set_filter(panel.FilterType.ALL)
	_assert(not panel.get_slot_view(1).filtered_out, "切回全部恢复原槽位内容")


func test_drag_move_merge_and_swap() -> void:
	_import_slots([
		{"item_id": "seed_carrot", "quantity": 10},
		null,
		{"item_id": "seed_carrot", "quantity": 80},
		{"item_id": "seed_tomato", "quantity": 5},
	])
	_assert(panel.simulate_drag(0, 1), "拖拽到空槽执行移动")
	_assert(InventoryManager.get_slot(0) == null and InventoryManager.get_slot(1)["quantity"] == 10, "移动后源空目标正确")
	_assert(panel.simulate_drag(1, 2), "同类拖拽执行合并")
	_assert(InventoryManager.get_slot(1) == null and InventoryManager.get_slot(2)["quantity"] == 90, "同类完全合并结果正确")
	_import_slots([
		{"item_id": "seed_carrot", "quantity": 20},
		{"item_id": "seed_carrot", "quantity": 90},
	])
	_assert(panel.simulate_drag(0, 1), "同类部分合并成功")
	_assert(InventoryManager.get_slot(0)["quantity"] == 11 and InventoryManager.get_slot(1)["quantity"] == 99, "部分合并遵守 99 上限")
	_import_slots([
		{"item_id": "seed_carrot", "quantity": 2},
		{"item_id": "watering_can", "quantity": 1},
	])
	_assert(panel.simulate_drag(0, 1), "不同物品拖拽执行交换")
	_assert(InventoryManager.get_slot(0)["item_id"] == "watering_can", "交换后源槽内容正确")
	_assert(not panel.simulate_drag(0, 0), "拖回原槽位不修改数据")


func test_hotbar_and_farm_selection() -> void:
	_import_slots([
		{"item_id": "seed_carrot", "quantity": 2},
		{"item_id": "watering_can", "quantity": 1},
		null,
		{"item_id": "seed_carrot", "quantity": 3},
	])
	InventoryManager.select_hotbar(1)
	panel.select_hotbar_slot(0)
	_assert(InventoryManager.get_selected_hotbar() == 0, "选择快捷栏更新权威索引")
	_assert(panel.get_slot_view(0).is_hotbar_selected, "背包高亮当前快捷栏")
	_assert(interaction_controller.selected_crop_id == "carrot", "选中种子同步农田种植模式")
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	panel.get_slot_view(3)._on_gui_input(double_click)
	_assert(InventoryManager.get_selected_hotbar() == 3, "双击槽位更新快捷栏索引")
	_assert(panel.get_slot_view(3).is_hotbar_selected, "双击槽位显示快捷栏选中高亮")
	var selected_style: StyleBoxFlat = panel.get_slot_view(3).get_theme_stylebox("panel")
	_assert(selected_style.border_color == Color("#F2D35C"), "快捷栏黄色高亮不被详情白框覆盖")
	_assert(panel.footer_hint_label.text.contains("已选择：胡萝卜种子"), "双击成功显示选择反馈")
	panel.select_hotbar_slot(1)
	_assert(interaction_controller.selected_tool_id == "watering_can", "选中水壶同步农田浇水模式")
	_assert(panel.simulate_drag(1, 9), "当前水壶可移出快捷栏")
	_assert(interaction_controller.current_mode == interaction_controller.InteractionMode.NONE, "当前物品移出快捷栏后清空农田模式")
	var debug_tool_event := InputEventKey.new()
	debug_tool_event.pressed = true
	debug_tool_event.physical_keycode = KEY_4
	_assert(not interaction_controller.handle_debug_key_event(debug_tool_event), "数字键 4 不再绕过快捷栏选择水壶")
	_assert(interaction_controller.current_mode == interaction_controller.InteractionMode.NONE, "按 4 后仍保持无农田选择")
	var old_index := InventoryManager.get_selected_hotbar()
	_assert(not panel.select_hotbar_slot(9), "非快捷栏槽位不可直接选择")
	_assert(InventoryManager.get_selected_hotbar() == old_index, "非法直接选择不修改快捷栏索引")
	InventoryManager.discard_slot(1, -1)
	interaction_controller.sync_selection_from_hotbar()
	_assert(interaction_controller.current_mode == interaction_controller.InteractionMode.NONE, "选中槽变空后清除旧农田选择")


func test_discard_flow() -> void:
	_import_slots([{"item_id": "seed_carrot", "quantity": 7}])
	panel.select_slot(0)
	panel.request_discard(0)
	panel._on_discard_canceled()
	_assert(InventoryManager.get_slot(0)["quantity"] == 7, "取消丢弃保持槽位数据")
	panel.request_discard(0)
	_assert(panel.confirm_discard(), "确认丢弃返回成功")
	_assert(InventoryManager.get_slot(0) == null, "确认丢弃清空整格")
	_assert(panel.selected_slot_index == -1, "丢弃当前详情物后清空详情选择")


func test_load_refresh_and_unknown_metadata() -> void:
	_import_slots([{"item_id": "unknown_test_item", "quantity": 2}])
	EventBus.game_loaded.emit(0, {})
	_assert(panel.get_slot_view(0).get_displayed_item_id() == "unknown_test_item", "读档事件触发全量刷新")
	panel.select_slot(0)
	_assert(panel.item_name_label.text == "unknown_test_item", "缺失元数据使用 item_id 回退")
	_assert(panel.item_type_label.text == "未知", "缺失元数据显示未知类型")


func test_inventory_full_feedback() -> void:
	var slots: Array = []
	for _index in range(InventoryManager.MAX_SLOTS):
		slots.append({"item_id": "watering_can", "quantity": 1})
	InventoryManager.import_save_data({"slots": slots, "selected_hotbar": 0})
	EventBus.inventory_full.emit()
	_assert(panel.footer_hint_label.text == "背包已满", "背包满事件显示明确提示")
	_assert(panel.capacity_label.text == "20/20", "容量显示满包状态")


func _import_slots(initial_slots: Array) -> void:
	var slots: Array = []
	for index in range(InventoryManager.MAX_SLOTS):
		slots.append(initial_slots[index] if index < initial_slots.size() else null)
	InventoryManager.import_save_data({"slots": slots, "selected_hotbar": 0})
	panel.set_filter(panel.FilterType.ALL)
	panel.refresh_all_slots()


func _on_panel_opened() -> void:
	_opened_count += 1


func _on_panel_closed() -> void:
	_closed_count += 1


func _on_ui_block_changed(blocked: bool) -> void:
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
