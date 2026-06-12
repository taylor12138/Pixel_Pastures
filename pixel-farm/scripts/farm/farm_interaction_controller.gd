extends Node
## FarmInteractionController — PRD10 种植 / 浇水 / 收获 / 清除交互编排层。

enum InteractionMode {
	NONE,
	PLANT,
	WATER,
	HARVEST,
	CLEAR,
}

const ACTION_NONE := "none"
const ACTION_PLANT := "plant"
const ACTION_WATER := "water"
const ACTION_HARVEST := "harvest"
const ACTION_CLEAR := "clear"

const REASON_TILE_OUT_OF_BOUNDS := "tile_out_of_bounds"
const REASON_TILE_LOCKED := "tile_locked"
const REASON_TILE_NOT_PLANTABLE := "tile_not_plantable"
const REASON_CROP_EXISTS := "crop_exists"
const REASON_CROP_MISSING := "crop_missing"
const REASON_CROP_LOCKED := "crop_locked"
const REASON_SEED_MISSING := "seed_missing"
const REASON_TOOL_MISSING := "tool_missing"
const REASON_CROP_DOES_NOT_NEED_WATER := "crop_does_not_need_water"
const REASON_CROP_NOT_MATURE := "crop_not_mature"
const REASON_INVENTORY_FULL := "inventory_full"
const REASON_CROP_NOT_WITHERED := "crop_not_withered"
const REASON_NO_ACTION_AVAILABLE := "no_action_available"
const REASON_INVALID_CROP := "invalid_crop"

@export var auto_resolve_action: bool = true
@export var debug_mode: bool = true
@export var debug_direct_selection_enabled: bool = false
@export var default_seed_crop_id: String = "carrot"
@export var debug_grant_starter_items: bool = true
@export var debug_starter_seed_count: int = 10

var current_mode: int = InteractionMode.NONE
var selected_crop_id: String = ""
var selected_item_id: String = ""
var selected_tool_id: String = ""
var last_result: Dictionary = {}
var farm_grid_manager: Node = null
var crop_overlay: Node2D = null
var interaction_debug_label: Label = null
var ui_input_blocked: bool = false


func _ready() -> void:
	connect_events()


func _unhandled_input(event: InputEvent) -> void:
	handle_debug_key_event(event)


func handle_debug_key_event(event: InputEvent) -> bool:
	if ui_input_blocked or not debug_mode:
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if (
		not debug_direct_selection_enabled
		and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]
	):
		return false
	match event.physical_keycode:
		KEY_1:
			return _select_debug_seed("carrot")
		KEY_2:
			return _select_debug_seed("cabbage")
		KEY_3:
			return _select_debug_seed("corn")
		KEY_4:
			return _select_debug_tool("watering_can")
		KEY_5:
			select_clear_mode()
			_set_debug_last_message("选择清除模式")
			return true
		KEY_0:
			clear_selection()
			_set_debug_last_message("清空选择")
			return true
		KEY_F6:
			debug_advance_hovered_or_selected_crop()
			_set_debug_last_message("调试推进作物")
			return true
		KEY_F7:
			debug_force_mature_hovered_or_selected_crop()
			_set_debug_last_message("调试强制成熟")
			return true
		KEY_F8:
			debug_force_wither_hovered_or_selected_crop()
			_set_debug_last_message("调试强制枯萎")
			return true
	return false


func setup(grid_manager: Node, overlay: Node2D = null, debug_label: Label = null) -> void:
	farm_grid_manager = grid_manager
	crop_overlay = overlay
	interaction_debug_label = debug_label
	if crop_overlay != null and crop_overlay.has_method("setup"):
		crop_overlay.call("setup", farm_grid_manager)
	if debug_mode and debug_grant_starter_items:
		_ensure_debug_starter_items()
	reconcile_grid_with_crops()
	refresh_crop_overlay()
	_update_debug_label()


func reset_controller() -> void:
	current_mode = InteractionMode.NONE
	selected_crop_id = ""
	selected_item_id = ""
	selected_tool_id = ""
	last_result = {}
	_emit_mode_changed()
	_update_debug_label()


func connect_events() -> void:
	if not has_node("/root/EventBus"):
		return
	if not EventBus.farm_tile_interaction_requested.is_connected(_on_farm_tile_interaction_requested):
		EventBus.farm_tile_interaction_requested.connect(_on_farm_tile_interaction_requested)
	if not EventBus.crop_planted.is_connected(_on_crop_state_changed):
		EventBus.crop_planted.connect(_on_crop_state_changed)
	if not EventBus.crop_watered.is_connected(_on_crop_state_changed):
		EventBus.crop_watered.connect(_on_crop_state_changed)
	if not EventBus.crop_grown.is_connected(_on_crop_stage_changed):
		EventBus.crop_grown.connect(_on_crop_stage_changed)
	if not EventBus.crop_matured.is_connected(_on_crop_state_changed):
		EventBus.crop_matured.connect(_on_crop_state_changed)
	if not EventBus.crop_withered.is_connected(_on_crop_state_changed):
		EventBus.crop_withered.connect(_on_crop_state_changed)
	if not EventBus.crop_harvested.is_connected(_on_crop_harvested):
		EventBus.crop_harvested.connect(_on_crop_harvested)
	if not EventBus.crop_cleared.is_connected(_on_crop_cleared):
		EventBus.crop_cleared.connect(_on_crop_cleared)
	if not EventBus.ui_input_block_changed.is_connected(_on_ui_input_block_changed):
		EventBus.ui_input_block_changed.connect(_on_ui_input_block_changed)
	if not EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.connect(_on_inventory_changed)


func disconnect_events() -> void:
	if not has_node("/root/EventBus"):
		return
	if EventBus.farm_tile_interaction_requested.is_connected(_on_farm_tile_interaction_requested):
		EventBus.farm_tile_interaction_requested.disconnect(_on_farm_tile_interaction_requested)
	if EventBus.crop_planted.is_connected(_on_crop_state_changed):
		EventBus.crop_planted.disconnect(_on_crop_state_changed)
	if EventBus.crop_watered.is_connected(_on_crop_state_changed):
		EventBus.crop_watered.disconnect(_on_crop_state_changed)
	if EventBus.crop_grown.is_connected(_on_crop_stage_changed):
		EventBus.crop_grown.disconnect(_on_crop_stage_changed)
	if EventBus.crop_matured.is_connected(_on_crop_state_changed):
		EventBus.crop_matured.disconnect(_on_crop_state_changed)
	if EventBus.crop_withered.is_connected(_on_crop_state_changed):
		EventBus.crop_withered.disconnect(_on_crop_state_changed)
	if EventBus.crop_harvested.is_connected(_on_crop_harvested):
		EventBus.crop_harvested.disconnect(_on_crop_harvested)
	if EventBus.crop_cleared.is_connected(_on_crop_cleared):
		EventBus.crop_cleared.disconnect(_on_crop_cleared)
	if EventBus.ui_input_block_changed.is_connected(_on_ui_input_block_changed):
		EventBus.ui_input_block_changed.disconnect(_on_ui_input_block_changed)
	if EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)


func select_seed(crop_id: String) -> bool:
	if DataManager.get_crop(crop_id).is_empty():
		_record_failure(_make_result(false, ACTION_PLANT, Vector2i(-1, -1), crop_id, "seed_" + crop_id, REASON_INVALID_CROP, "作物不存在"))
		return false
	if has_node("/root/LevelManager") and not LevelManager.is_crop_unlocked(crop_id):
		_record_failure(_make_result(false, ACTION_PLANT, Vector2i(-1, -1), crop_id, "seed_" + crop_id, REASON_CROP_LOCKED, "这种作物还没有解锁"))
		return false
	current_mode = InteractionMode.PLANT
	selected_crop_id = crop_id
	selected_item_id = "seed_" + crop_id
	selected_tool_id = ""
	_emit_mode_changed()
	_update_debug_label()
	return true


func select_tool(tool_id: String) -> bool:
	if tool_id != "watering_can" or DataManager.get_item(tool_id).is_empty():
		_record_failure(_make_result(false, ACTION_WATER, Vector2i(-1, -1), "", tool_id, REASON_TOOL_MISSING, "需要先选择水壶"))
		return false
	current_mode = InteractionMode.WATER
	selected_crop_id = ""
	selected_item_id = tool_id
	selected_tool_id = tool_id
	_emit_mode_changed()
	_update_debug_label()
	return true


func select_clear_mode() -> void:
	current_mode = InteractionMode.CLEAR
	selected_crop_id = ""
	selected_item_id = ""
	selected_tool_id = ""
	_emit_mode_changed()
	_update_debug_label()


func _select_debug_seed(crop_id: String) -> bool:
	var ok := select_seed(crop_id)
	if ok:
		_set_debug_last_message("选择%s种子" % _get_crop_name(crop_id))
	return ok


func _select_debug_tool(tool_id: String) -> bool:
	var ok := select_tool(tool_id)
	if ok:
		_set_debug_last_message("选择浇水壶")
	return ok


func clear_selection() -> void:
	current_mode = InteractionMode.NONE
	selected_crop_id = ""
	selected_item_id = ""
	selected_tool_id = ""
	_emit_mode_changed()
	_update_debug_label()


func sync_selection_from_hotbar() -> void:
	if not has_node("/root/InventoryManager") or not InventoryManager.has_method("get_selected_item"):
		return
	var selected = InventoryManager.get_selected_item()
	if not selected is Dictionary:
		clear_selection()
		return
	var item_id := str(selected.get("item_id", ""))
	var item_data := DataManager.get_item(item_id)
	if item_data.get("type", "") == "seed":
		var fallback_crop_id := item_id.substr(5) if item_id.begins_with("seed_") else ""
		select_seed(str(item_data.get("crop_id", fallback_crop_id)))
	elif item_id == "watering_can":
		select_tool("watering_can")
	else:
		clear_selection()


func get_current_selection() -> Dictionary:
	return {
		"mode": _mode_to_string(current_mode),
		"selected_crop_id": selected_crop_id,
		"selected_item_id": selected_item_id,
		"selected_tool_id": selected_tool_id,
		"auto_resolve_action": auto_resolve_action,
	}


func request_tile_interaction(tile_pos: Vector2i, source: String = "unknown") -> Dictionary:
	if ui_input_blocked:
		return _make_result(false, ACTION_NONE, tile_pos, "", selected_item_id, "ui_input_blocked", "请先关闭背包")
	var result: Dictionary
	if auto_resolve_action:
		result = resolve_action(tile_pos)
	else:
		result = _dispatch_current_mode(tile_pos)
	result["source"] = source
	if bool(result.get("success", false)):
		_record_success(result)
	else:
		_record_failure(result)
	return result


func request_mouse_tile_interaction(mouse_world_pos: Vector2) -> Dictionary:
	if farm_grid_manager == null:
		var result := _make_result(false, ACTION_NONE, Vector2i(-1, -1), "", selected_item_id, REASON_TILE_OUT_OF_BOUNDS, "田园网格尚未初始化")
		_record_failure(result)
		return result
	var tile_pos: Vector2i = farm_grid_manager.world_to_grid(mouse_world_pos)
	return request_tile_interaction(tile_pos, "mouse")


func can_interact_with_tile(tile_pos: Vector2i) -> bool:
	update_action_preview(tile_pos)
	return _validate_tile_exists(tile_pos).is_empty()


func update_action_preview(tile_pos: Vector2i) -> Dictionary:
	var preview := _preview_action(tile_pos)
	if has_node("/root/EventBus"):
		EventBus.farm_tile_action_preview_changed.emit(tile_pos, str(preview.get("action", ACTION_NONE)), str(preview.get("reason", "")))
	return preview


func resolve_action(tile_pos: Vector2i) -> Dictionary:
	var basic_error := _validate_tile_exists(tile_pos)
	if not basic_error.is_empty():
		return basic_error
	if CropManager.has_crop(tile_pos):
		var crop_data := CropManager.get_crop_data(tile_pos)
		var stage := int(crop_data.get("stage", CropManager.CropStage.SEED))
		if CropManager.is_harvestable(tile_pos):
			return try_harvest(tile_pos)
		if stage == CropManager.CropStage.WITHERED:
			return try_clear(tile_pos)
		if current_mode == InteractionMode.WATER:
			return try_water(tile_pos)
	if current_mode == InteractionMode.PLANT and selected_crop_id != "":
		return try_plant(tile_pos, selected_crop_id)
	return _make_result(false, ACTION_NONE, tile_pos, _get_crop_id(tile_pos), selected_item_id, REASON_NO_ACTION_AVAILABLE, "这里暂时没有可执行操作")


func try_plant(tile_pos: Vector2i, crop_id: String) -> Dictionary:
	var basic_error := _validate_tile_exists(tile_pos)
	if not basic_error.is_empty():
		basic_error["action"] = ACTION_PLANT
		basic_error["crop_id"] = crop_id
		basic_error["item_id"] = "seed_" + crop_id
		return basic_error
	if CropManager.has_crop(tile_pos):
		return _make_result(false, ACTION_PLANT, tile_pos, crop_id, "seed_" + crop_id, REASON_CROP_EXISTS, "这块地已经有作物")
	if not farm_grid_manager.can_plant_on_tile(tile_pos):
		var tile_data: Dictionary = farm_grid_manager.get_tile_data(tile_pos)
		var reason := REASON_TILE_LOCKED if not bool(tile_data.get("unlocked", false)) else REASON_TILE_NOT_PLANTABLE
		return _make_result(false, ACTION_PLANT, tile_pos, crop_id, "seed_" + crop_id, reason, _message_for_reason(reason))
	if DataManager.get_crop(crop_id).is_empty():
		return _make_result(false, ACTION_PLANT, tile_pos, crop_id, "seed_" + crop_id, REASON_INVALID_CROP, "作物不存在")
	if has_node("/root/LevelManager") and not LevelManager.is_crop_unlocked(crop_id):
		return _make_result(false, ACTION_PLANT, tile_pos, crop_id, "seed_" + crop_id, REASON_CROP_LOCKED, "这种作物还没有解锁")
	var seed_id := "seed_" + crop_id
	if not InventoryManager.has_item(seed_id, 1):
		return _make_result(false, ACTION_PLANT, tile_pos, crop_id, seed_id, REASON_SEED_MISSING, "背包里没有这种种子")
	if not CropManager.plant_crop(tile_pos, crop_id):
		return _make_result(false, ACTION_PLANT, tile_pos, crop_id, seed_id, REASON_SEED_MISSING, "种植失败")
	farm_grid_manager.set_tile_occupied(tile_pos, true, farm_grid_manager.tile_pos_to_key(tile_pos))
	return _make_result(true, ACTION_PLANT, tile_pos, crop_id, seed_id, "", "种下了%s" % _get_crop_name(crop_id))


func try_water(tile_pos: Vector2i) -> Dictionary:
	var basic_error := _validate_tile_exists(tile_pos)
	if not basic_error.is_empty():
		basic_error["action"] = ACTION_WATER
		basic_error["item_id"] = "watering_can"
		return basic_error
	if not CropManager.has_crop(tile_pos):
		return _make_result(false, ACTION_WATER, tile_pos, "", "watering_can", REASON_CROP_MISSING, "这里还没有作物")
	var crop_data := CropManager.get_crop_data(tile_pos)
	var crop_id := str(crop_data.get("crop_id", ""))
	if current_mode != InteractionMode.WATER and not auto_resolve_action:
		return _make_result(false, ACTION_WATER, tile_pos, crop_id, selected_item_id, REASON_TOOL_MISSING, "需要先选择水壶")
	if not CropManager.needs_water(tile_pos):
		return _make_result(false, ACTION_WATER, tile_pos, crop_id, "watering_can", REASON_CROP_DOES_NOT_NEED_WATER, "这株作物暂时不需要浇水")
	if not CropManager.water_crop(tile_pos):
		return _make_result(false, ACTION_WATER, tile_pos, crop_id, "watering_can", REASON_CROP_DOES_NOT_NEED_WATER, "这株作物暂时不需要浇水")
	farm_grid_manager.mark_tile_watered(tile_pos)
	return _make_result(true, ACTION_WATER, tile_pos, crop_id, "watering_can", "", "浇水完成")


func try_harvest(tile_pos: Vector2i) -> Dictionary:
	var basic_error := _validate_tile_exists(tile_pos)
	if not basic_error.is_empty():
		basic_error["action"] = ACTION_HARVEST
		return basic_error
	if not CropManager.has_crop(tile_pos):
		return _make_result(false, ACTION_HARVEST, tile_pos, "", selected_item_id, REASON_CROP_MISSING, "这里还没有作物")
	var crop_id := _get_crop_id(tile_pos)
	if not CropManager.is_harvestable(tile_pos):
		return _make_result(false, ACTION_HARVEST, tile_pos, crop_id, selected_item_id, REASON_CROP_NOT_MATURE, "作物还没有成熟")
	var harvested_crop_id := CropManager.harvest_crop(tile_pos)
	if harvested_crop_id == "":
		return _make_result(false, ACTION_HARVEST, tile_pos, crop_id, selected_item_id, REASON_INVENTORY_FULL, "背包已满")
	farm_grid_manager.clear_tile(tile_pos)
	return _make_result(true, ACTION_HARVEST, tile_pos, harvested_crop_id, "harvest_" + harvested_crop_id, "", "收获了%s" % _get_crop_name(harvested_crop_id))


func try_clear(tile_pos: Vector2i) -> Dictionary:
	var basic_error := _validate_tile_exists(tile_pos)
	if not basic_error.is_empty():
		basic_error["action"] = ACTION_CLEAR
		return basic_error
	if not CropManager.has_crop(tile_pos):
		return _make_result(false, ACTION_CLEAR, tile_pos, "", selected_item_id, REASON_CROP_MISSING, "这里还没有作物")
	var crop_data := CropManager.get_crop_data(tile_pos)
	var crop_id := str(crop_data.get("crop_id", ""))
	if int(crop_data.get("stage", CropManager.CropStage.SEED)) != CropManager.CropStage.WITHERED:
		return _make_result(false, ACTION_CLEAR, tile_pos, crop_id, selected_item_id, REASON_CROP_NOT_WITHERED, "只能清除枯萎作物")
	if not CropManager.clear_crop(tile_pos):
		return _make_result(false, ACTION_CLEAR, tile_pos, crop_id, selected_item_id, REASON_CROP_MISSING, "清除失败")
	farm_grid_manager.clear_tile(tile_pos)
	return _make_result(true, ACTION_CLEAR, tile_pos, crop_id, selected_item_id, "", "清除了枯萎作物")


func reconcile_grid_with_crops() -> void:
	if farm_grid_manager == null or not has_node("/root/CropManager"):
		return
	var all_crops: Dictionary = CropManager.get_all_crops()
	for tile_pos in all_crops.keys():
		if not tile_pos is Vector2i or not farm_grid_manager.is_in_unlockable_plot_area(tile_pos):
			continue
		var tile_data: Dictionary = farm_grid_manager.get_tile_data(tile_pos)
		if tile_data.is_empty() or str(tile_data.get("terrain_type", "")) != farm_grid_manager.TERRAIN_FARM_PLOT:
			continue
		if not bool(tile_data.get("unlocked", false)):
			farm_grid_manager.set_plot_unlocked(tile_pos, true)
		if not farm_grid_manager.is_tile_occupied(tile_pos):
			farm_grid_manager.set_tile_occupied(tile_pos, true, farm_grid_manager.tile_pos_to_key(tile_pos))
	for tile_pos in farm_grid_manager.get_unlocked_plot_positions():
		if farm_grid_manager.is_tile_occupied(tile_pos) and not CropManager.has_crop(tile_pos):
			farm_grid_manager.clear_tile(tile_pos)
	refresh_crop_overlay()


func refresh_crop_overlay() -> void:
	if crop_overlay != null:
		crop_overlay.queue_redraw()
	_update_debug_label()


func get_last_result() -> Dictionary:
	return last_result.duplicate(true)


func debug_advance_hovered_or_selected_crop(seconds: float = 9999.0) -> void:
	if not _debug_actions_enabled():
		return
	var tile_pos := _get_debug_target_tile()
	if CropManager.has_crop(tile_pos):
		CropManager.debug_advance_time(tile_pos, seconds)
		refresh_crop_overlay()


func debug_force_mature_hovered_or_selected_crop() -> void:
	if not _debug_actions_enabled():
		return
	var tile_pos := _get_debug_target_tile()
	if not CropManager.has_crop(tile_pos):
		return
	var crop_data: Dictionary = CropManager._crops[tile_pos]
	crop_data["stage"] = CropManager.CropStage.MATURE
	crop_data["watered"] = false
	crop_data["mature_timestamp"] = Time.get_unix_time_from_system()
	CropManager._sync_to_game_manager()
	EventBus.crop_matured.emit(tile_pos, str(crop_data.get("crop_id", "")))
	refresh_crop_overlay()


func debug_force_wither_hovered_or_selected_crop() -> void:
	if not _debug_actions_enabled():
		return
	var tile_pos := _get_debug_target_tile()
	if not CropManager.has_crop(tile_pos):
		return
	var crop_data: Dictionary = CropManager._crops[tile_pos]
	crop_data["stage"] = CropManager.CropStage.WITHERED
	crop_data["watered"] = false
	CropManager._sync_to_game_manager()
	EventBus.crop_withered.emit(tile_pos, str(crop_data.get("crop_id", "")))
	refresh_crop_overlay()


func _dispatch_current_mode(tile_pos: Vector2i) -> Dictionary:
	match current_mode:
		InteractionMode.PLANT:
			return try_plant(tile_pos, selected_crop_id)
		InteractionMode.WATER:
			return try_water(tile_pos)
		InteractionMode.HARVEST:
			return try_harvest(tile_pos)
		InteractionMode.CLEAR:
			return try_clear(tile_pos)
		_:
			return _make_result(false, ACTION_NONE, tile_pos, _get_crop_id(tile_pos), selected_item_id, REASON_NO_ACTION_AVAILABLE, "这里暂时没有可执行操作")


func _validate_tile_exists(tile_pos: Vector2i) -> Dictionary:
	if farm_grid_manager == null or not farm_grid_manager.is_in_map_bounds(tile_pos):
		return _make_result(false, ACTION_NONE, tile_pos, "", selected_item_id, REASON_TILE_OUT_OF_BOUNDS, "不在可操作范围内")
	var tile_data: Dictionary = farm_grid_manager.get_tile_data(tile_pos)
	if tile_data.is_empty():
		return _make_result(false, ACTION_NONE, tile_pos, "", selected_item_id, REASON_TILE_OUT_OF_BOUNDS, "不在可操作范围内")
	if str(tile_data.get("terrain_type", "")) != farm_grid_manager.TERRAIN_FARM_PLOT:
		return _make_result(false, ACTION_NONE, tile_pos, "", selected_item_id, REASON_TILE_NOT_PLANTABLE, "这里不能种植")
	if not bool(tile_data.get("unlocked", false)):
		return _make_result(false, ACTION_NONE, tile_pos, "", selected_item_id, REASON_TILE_LOCKED, "这块地还没有解锁")
	return {}


func _make_result(success: bool, action: String, tile_pos: Vector2i, crop_id: String, item_id: String, reason: String, message: String) -> Dictionary:
	return {
		"success": success,
		"action": action,
		"tile_pos": tile_pos,
		"crop_id": crop_id,
		"item_id": item_id,
		"reason": reason,
		"message": message,
	}


func _record_success(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	if has_node("/root/EventBus"):
		EventBus.farm_interaction_completed.emit(last_result)
		EventBus.ui_notification.emit(str(last_result.get("message", "")), "success")
	refresh_crop_overlay()


func _record_failure(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	if has_node("/root/EventBus"):
		EventBus.farm_interaction_failed.emit(last_result)
		var message := str(last_result.get("message", ""))
		if message != "":
			EventBus.ui_notification.emit(message, "warning")
	_update_debug_label()


func _set_debug_last_message(message: String) -> void:
	last_result = _make_result(true, "select", Vector2i(-1, -1), selected_crop_id, selected_item_id, "", message)
	_update_debug_label()


func _emit_mode_changed() -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_interaction_mode_changed.emit(_mode_to_string(current_mode), selected_item_id, selected_crop_id)


func _on_farm_tile_interaction_requested(tile_pos: Vector2i, _target: Dictionary) -> void:
	if ui_input_blocked:
		return
	request_tile_interaction(tile_pos, "player")


func _on_ui_input_block_changed(blocked: bool) -> void:
	ui_input_blocked = blocked


func _on_inventory_changed(slot_index: int) -> void:
	if (
		has_node("/root/InventoryManager")
		and slot_index == InventoryManager.get_selected_hotbar()
	):
		sync_selection_from_hotbar()


func _on_crop_state_changed(_tile_pos: Vector2i, _crop_id: String = "") -> void:
	refresh_crop_overlay()


func _on_crop_stage_changed(_tile_pos: Vector2i, _crop_id: String, _stage: int) -> void:
	refresh_crop_overlay()


func _on_crop_harvested(_tile_pos: Vector2i, _crop_id: String, _amount: int) -> void:
	refresh_crop_overlay()


func _on_crop_cleared(_tile_pos: Vector2i) -> void:
	refresh_crop_overlay()


func _get_crop_id(tile_pos: Vector2i) -> String:
	if has_node("/root/CropManager") and CropManager.has_crop(tile_pos):
		return str(CropManager.get_crop_data(tile_pos).get("crop_id", ""))
	return ""


func _get_crop_name(crop_id: String) -> String:
	var crop_data := DataManager.get_crop(crop_id)
	return str(crop_data.get("name", crop_id))


func _ensure_debug_starter_items() -> void:
	if not has_node("/root/InventoryManager"):
		return
	for seed_id in ["seed_carrot", "seed_cabbage", "seed_corn"]:
		var current_count := InventoryManager.get_item_count(seed_id)
		if current_count < debug_starter_seed_count:
			InventoryManager.add_item(seed_id, debug_starter_seed_count - current_count)
	if InventoryManager.get_item_count("watering_can") <= 0:
		InventoryManager.add_item("watering_can", 1)


func _message_for_reason(reason: String) -> String:
	match reason:
		REASON_TILE_OUT_OF_BOUNDS:
			return "不在可操作范围内"
		REASON_TILE_LOCKED:
			return "这块地还没有解锁"
		REASON_TILE_NOT_PLANTABLE:
			return "这里不能种植"
		REASON_CROP_EXISTS:
			return "这块地已经有作物"
		REASON_CROP_MISSING:
			return "这里还没有作物"
		REASON_CROP_LOCKED:
			return "这种作物还没有解锁"
		REASON_SEED_MISSING:
			return "背包里没有这种种子"
		REASON_TOOL_MISSING:
			return "需要先选择水壶"
		REASON_CROP_DOES_NOT_NEED_WATER:
			return "这株作物暂时不需要浇水"
		REASON_CROP_NOT_MATURE:
			return "作物还没有成熟"
		REASON_INVENTORY_FULL:
			return "背包已满"
		REASON_CROP_NOT_WITHERED:
			return "只能清除枯萎作物"
		_:
			return "这里暂时没有可执行操作"


func _preview_action(tile_pos: Vector2i) -> Dictionary:
	var basic_error := _validate_tile_exists(tile_pos)
	if not basic_error.is_empty():
		return {"action": ACTION_NONE, "reason": str(basic_error.get("reason", ""))}
	if CropManager.has_crop(tile_pos):
		var crop_data := CropManager.get_crop_data(tile_pos)
		var stage := int(crop_data.get("stage", CropManager.CropStage.SEED))
		if CropManager.is_harvestable(tile_pos):
			return {"action": ACTION_HARVEST, "reason": ""}
		if stage == CropManager.CropStage.WITHERED:
			return {"action": ACTION_CLEAR, "reason": ""}
		if current_mode == InteractionMode.WATER and CropManager.needs_water(tile_pos):
			return {"action": ACTION_WATER, "reason": ""}
	if current_mode == InteractionMode.PLANT and selected_crop_id != "" and farm_grid_manager.can_plant_on_tile(tile_pos):
		return {"action": ACTION_PLANT, "reason": ""}
	return {"action": ACTION_NONE, "reason": REASON_NO_ACTION_AVAILABLE}


func _mode_to_string(mode: int) -> String:
	match mode:
		InteractionMode.PLANT:
			return "PLANT"
		InteractionMode.WATER:
			return "WATER"
		InteractionMode.HARVEST:
			return "HARVEST"
		InteractionMode.CLEAR:
			return "CLEAR"
		_:
			return "NONE"


func _debug_actions_enabled() -> bool:
	return debug_mode and OS.is_debug_build() and has_node("/root/CropManager")


func _get_debug_target_tile() -> Vector2i:
	if farm_grid_manager == null:
		return Vector2i(-1, -1)
	if farm_grid_manager.is_in_map_bounds(farm_grid_manager.selected_tile):
		return farm_grid_manager.selected_tile
	return farm_grid_manager.hovered_tile


func _update_debug_label() -> void:
	if interaction_debug_label == null:
		return
	var target_tile := _get_debug_target_tile()
	var crop_text := "Tile Crop: none"
	if has_node("/root/CropManager") and CropManager.has_crop(target_tile):
		var crop_data := CropManager.get_crop_data(target_tile)
		crop_text = "Tile Crop: %s stage=%s watered=%s progress=%.2f" % [
			str(crop_data.get("crop_id", "")),
			_stage_to_string(int(crop_data.get("stage", 0))),
			str(crop_data.get("watered", false)),
			CropManager.get_growth_progress(target_tile),
		]
	var last_text := "Last: none"
	if not last_result.is_empty():
		last_text = "Last: %s %s at %s" % [
			str(last_result.get("action", "")),
			str(last_result.get("reason", last_result.get("message", ""))),
			str(last_result.get("tile_pos", Vector2i(-1, -1))),
		]
	interaction_debug_label.text = "Mode: %s\nSelected: %s %s\n%s\n%s" % [
		_mode_to_string(current_mode),
		selected_item_id,
		selected_crop_id,
		last_text,
		crop_text,
	]


func _stage_to_string(stage: int) -> String:
	match stage:
		CropManager.CropStage.SEED:
			return "SEED"
		CropManager.CropStage.SPROUT:
			return "SPROUT"
		CropManager.CropStage.GROWING:
			return "GROWING"
		CropManager.CropStage.MATURE:
			return "MATURE"
		CropManager.CropStage.WITHERED:
			return "WITHERED"
		_:
			return "UNKNOWN"
