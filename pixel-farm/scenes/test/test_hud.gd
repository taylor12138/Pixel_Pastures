extends Node2D
## HUD 自动化测试。

@onready var label: Label = $Label
@onready var hud: Control = $HUD
@onready var hotbar: HBoxContainer = $HUD/HotbarRoot/Hotbar
@onready var interaction_controller: Node = $FarmInteractionController

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []
var _isolated_clicked_slot: int = -1


func _ready() -> void:
	_reset_state()
	hud.setup(interaction_controller)

	print("=== HUD 自动化测试 ===")
	test_project_actions_and_layout()
	test_initialization_and_time_refresh()
	test_gold_and_level_refresh()
	test_hotbar_rendering_and_fallback()
	test_hotbar_selection_inputs()
	test_input_block_and_farm_sync()
	test_interaction_prompt()
	test_local_refresh_load_and_connections()

	_cleanup_state()
	var summary := "=== HUD 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	_results.append(summary)
	label.text = "\n".join(_results)
	print(summary)


func test_project_actions_and_layout() -> void:
	var actions_valid := true
	for number in range(1, 10):
		var action := "hotbar_%d" % number
		actions_valid = actions_valid and InputMap.has_action(action)
		var events := InputMap.action_get_events(action)
		actions_valid = actions_valid and events.size() == 1
		if not events.is_empty() and events[0] is InputEventKey:
			actions_valid = actions_valid and (events[0] as InputEventKey).physical_keycode == KEY_0 + number
	_assert(actions_valid, "InputMap 注册物理数字键 hotbar_1 至 hotbar_9")
	_assert(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD 根节点不拦截空白区域")
	_assert(hud.get_node("HotbarRoot").mouse_filter == Control.MOUSE_FILTER_IGNORE, "快捷栏外层空白区域不遮挡下层按钮")
	_assert(hotbar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "快捷栏槽位间空隙允许鼠标穿透")
	_assert(hotbar.get_slot_view(0).mouse_filter == Control.MOUSE_FILTER_STOP, "快捷栏槽位接收鼠标点击")
	_assert(hotbar.slot_views.size() == 9, "快捷栏固定创建 9 个槽位")
	var hotkey_badge: ColorRect = hotbar.get_slot_view(0).get_node("Margin/Stack/HotkeyBadge")
	_assert(hotkey_badge.position.x < 0.0 and hotkey_badge.position.y < 0.0, "快捷键数字角标固定在槽位左上角")
	_assert(hud.get_node("TopBar/StatsPanel").custom_minimum_size.x <= 154.0, "顶部数值面板适配 480 宽布局")


func test_initialization_and_time_refresh() -> void:
	TimeManager.debug_set_datetime(2, "summer", 3, 14, 25)
	EventBus.minute_changed.emit(14, 25)
	EventBus.day_started.emit(2, "summer", 3)
	EventBus.season_changed.emit("summer")
	EventBus.day_phase_changed.emit(TimeManager.get_day_phase())
	_assert(hud.clock_label.text == "14:25", "minute_changed 刷新时钟")
	_assert(hud.date_label.text == "第2年 夏季 3日", "日期和季节显示权威文本")
	_assert(hud.phase_label.text == "下午", "昼夜阶段映射为中文")
	TimeManager.debug_set_datetime(2, "summer", 3, 19, 0)
	EventBus.day_phase_changed.emit(TimeManager.get_day_phase())
	_assert(hud.phase_label.text == "傍晚", "阶段变化局部刷新")


func test_gold_and_level_refresh() -> void:
	GameManager.gold = 0
	EventBus.gold_changed.emit(0, -100)
	_assert(hud.gold_label.text == "金币 0", "金币为 0 时正确显示")
	GameManager.gold = 1000000
	EventBus.gold_changed.emit(1000000, 1000000)
	_assert(hud.gold_label.text == "金币 1000000", "百万级金币完整显示")

	GameManager.level = 1
	GameManager.xp = 20
	EventBus.xp_gained.emit(20, "test")
	var progress := LevelManager.get_xp_progress()
	_assert(hud.level_label.text == "Lv.1", "等级文本与 GameManager 一致")
	_assert(is_equal_approx(hud.xp_bar.value, float(progress["progress_ratio"]) * 100.0), "经验条使用 LevelManager 进度")
	_assert(hud.xp_label.text == "20 / %d" % int(progress["xp_for_next_level"]), "经验数值显示当前与下一级阈值")

	GameManager.level = LevelManager.get_max_level()
	GameManager.xp = 999999
	EventBus.level_up.emit(GameManager.level)
	_assert(hud.xp_label.text == "MAX", "满级显示 MAX")
	_assert(is_equal_approx(hud.xp_bar.value, 100.0), "满级经验条显示满值")


func test_hotbar_rendering_and_fallback() -> void:
	_import_slots([
		{"item_id": "seed_carrot", "quantity": 12},
		{"item_id": "watering_can", "quantity": 1},
		{"item_id": "unknown_hud_item", "quantity": 2},
	])
	hud.refresh_hotbar()
	var seed_slot: Control = hotbar.get_slot_view(0)
	var tool_slot: Control = hotbar.get_slot_view(1)
	var unknown_slot: Control = hotbar.get_slot_view(2)
	var empty_slot: Control = hotbar.get_slot_view(8)
	_assert(seed_slot.get_displayed_item_id() == "seed_carrot", "快捷栏读取背包前九格")
	_assert(seed_slot.quantity_label.visible and seed_slot.quantity_label.text == "12", "数量大于 1 时显示数量")
	_assert(not tool_slot.quantity_label.visible, "数量等于 1 时隐藏数量")
	_assert(empty_slot.get_displayed_item_id() == "" and empty_slot.hotkey_label.text == "9", "空槽保留快捷键编号")
	_assert(unknown_slot.item_type == "unknown", "缺失元数据回退未知类型")
	_assert(unknown_slot.item_label.text == "un", "缺失元数据显示 item_id 短文本")
	_assert(unknown_slot.item_color.color == Color("#686868"), "未知类型使用灰色占位")

	var slot_scene: PackedScene = load("res://scenes/ui/hud/hotbar_slot.tscn")
	var isolated_slot: Control = slot_scene.instantiate()
	add_child(isolated_slot)
	isolated_slot.setup(6)
	isolated_slot.slot_clicked.connect(_on_isolated_slot_clicked)
	var selected_before := InventoryManager.get_selected_hotbar()
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	isolated_slot._on_gui_input(click)
	_assert(_isolated_clicked_slot == 6, "单槽点击仅发射槽位索引")
	_assert(InventoryManager.get_selected_hotbar() == selected_before, "单槽组件不直接修改 InventoryManager")
	isolated_slot.queue_free()


func test_hotbar_selection_inputs() -> void:
	InventoryManager.select_hotbar(0)
	hotbar.select_slot(2)
	_assert(InventoryManager.get_selected_hotbar() == 2, "select_slot 更新权威快捷栏索引")
	_assert(_selected_highlight_count() == 1 and hotbar.get_slot_view(2).is_selected, "快捷栏仅高亮权威选中槽")

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_4
	hotbar._unhandled_input(key_event)
	_assert(InventoryManager.get_selected_hotbar() == 3, "物理数字键 4 选择索引 3")

	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	hotbar.get_slot_view(5)._on_gui_input(click)
	_assert(InventoryManager.get_selected_hotbar() == 5, "点击槽位选择对应索引")
	hotbar.select_slot(5)
	_assert(_selected_highlight_count() == 1, "重复选择当前槽位保持唯一高亮")


func test_input_block_and_farm_sync() -> void:
	_import_slots([
		{"item_id": "seed_carrot", "quantity": 2},
		{"item_id": "watering_can", "quantity": 1},
	])
	InventoryManager.select_hotbar(1)
	_assert(interaction_controller.selected_tool_id == "watering_can", "快捷栏选择同步农田工具")
	var blocked_index := InventoryManager.get_selected_hotbar()
	EventBus.ui_input_block_changed.emit(true)
	var blocked_event := InputEventKey.new()
	blocked_event.pressed = true
	blocked_event.physical_keycode = KEY_1
	hotbar._unhandled_input(blocked_event)
	_assert(not hotbar.are_hotkeys_enabled(), "UI 阻塞时停用快捷栏热键")
	_assert(InventoryManager.get_selected_hotbar() == blocked_index, "UI 阻塞时数字键不改变选择")
	EventBus.ui_input_block_changed.emit(false)
	hotbar._unhandled_input(blocked_event)
	_assert(hotbar.are_hotkeys_enabled() and InventoryManager.get_selected_hotbar() == 0, "解除阻塞后数字键恢复")
	_assert(interaction_controller.selected_crop_id == "carrot", "恢复后选中种子同步种植模式")

	var debug_event := InputEventKey.new()
	debug_event.pressed = true
	debug_event.physical_keycode = KEY_5
	_assert(not interaction_controller.handle_debug_key_event(debug_event), "正式快捷栏启用时调试数字键 1-9 不抢占")


func test_interaction_prompt() -> void:
	EventBus.player_interaction_target_changed.emit({"type": "farm_tile"})
	EventBus.farm_tile_action_preview_changed.emit(Vector2i.ZERO, "water", "")
	_assert(hud.interaction_prompt.visible and hud.prompt_label.text == "按 E 浇水", "有效动作显示交互提示")
	EventBus.farm_tile_action_preview_changed.emit(Vector2i.ZERO, "harvest", "")
	_assert(hud.prompt_label.text == "按 E 收获", "动作变化刷新提示文案")
	EventBus.farm_tile_action_preview_changed.emit(Vector2i.ZERO, "water", "tool_missing")
	_assert(not hud.interaction_prompt.visible, "不可执行原因隐藏提示")
	EventBus.farm_tile_action_preview_changed.emit(Vector2i.ZERO, "unknown", "")
	_assert(not hud.interaction_prompt.visible, "未知动作隐藏提示")
	EventBus.player_interaction_target_changed.emit({})
	_assert(not hud.interaction_prompt.visible, "交互目标清空时隐藏提示")


func test_local_refresh_load_and_connections() -> void:
	_import_slots([{"item_id": "seed_carrot", "quantity": 3}])
	var unrelated: Control = hotbar.get_slot_view(8)
	unrelated.item_label.text = "sentinel"
	EventBus.inventory_changed.emit(0)
	_assert(unrelated.item_label.text == "sentinel", "单槽 inventory_changed 不重建无关槽位")
	EventBus.inventory_changed.emit(12)
	_assert(unrelated.item_label.text == "sentinel", "非快捷栏库存变化不刷新快捷栏")

	GameManager.gold = 345
	TimeManager.debug_set_datetime(3, "winter", 9, 22, 10)
	InventoryManager.select_hotbar(1)
	EventBus.game_loaded.emit(0, {})
	_assert(hud.gold_label.text == "金币 345", "读档事件全量刷新金币")
	_assert(hud.clock_label.text == "22:10" and hud.date_label.text == "第3年 冬季 9日", "读档事件全量刷新时间")
	_assert(hotbar.get_slot_view(1).is_selected, "读档事件同步快捷栏高亮")

	var before := _connection_count(EventBus.gold_changed, hud, "_on_gold_changed")
	hud._connect_events()
	var after := _connection_count(EventBus.gold_changed, hud, "_on_gold_changed")
	_assert(before == 1 and after == 1, "重复连接初始化保持事件回调幂等")


func _reset_state() -> void:
	GameManager.gold = 100
	GameManager.level = 1
	GameManager.xp = 0
	LevelManager.debug_reset_progress()
	TimeManager.initialize_new_game()
	InventoryManager.debug_clear()
	EventBus.ui_input_block_changed.emit(false)


func _cleanup_state() -> void:
	GameManager.gold = 100
	LevelManager.debug_reset_progress()
	TimeManager.initialize_new_game()
	InventoryManager.debug_clear()
	EventBus.ui_input_block_changed.emit(false)


func _import_slots(initial_slots: Array) -> void:
	var slots: Array = []
	for index in range(InventoryManager.MAX_SLOTS):
		slots.append(initial_slots[index] if index < initial_slots.size() else null)
	InventoryManager.import_save_data({"slots": slots, "selected_hotbar": 0})
	hotbar.refresh_all()


func _selected_highlight_count() -> int:
	var count := 0
	for slot in hotbar.slot_views:
		if slot.is_selected:
			count += 1
	return count


func _connection_count(signal_value: Signal, target: Object, method_name: String) -> int:
	var count := 0
	for connection in signal_value.get_connections():
		var callable: Callable = connection.get("callable", Callable())
		if callable.get_object() == target and callable.get_method() == method_name:
			count += 1
	return count


func _on_isolated_slot_clicked(index: int) -> void:
	_isolated_clicked_slot = index


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
