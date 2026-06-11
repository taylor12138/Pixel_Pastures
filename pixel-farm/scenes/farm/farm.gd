extends Node2D
## Farm — 个人田园场景入口与占位视觉调试交互。

@onready var farm_grid_manager: Node = $FarmGridManager
@onready var grid_canvas: Node2D = $GridRoot/GridCanvas
@onready var crop_overlay: Node2D = $GridRoot/CropOverlay
@onready var player: Node = $EntityLayer/Player
@onready var interaction_overlay: Node2D = $InteractionOverlay
@onready var farm_interaction_controller: Node = $Controllers/FarmInteractionController
@onready var inventory_panel: Control = $UILayer/InventoryPanel
@onready var coordinate_label: Label = $DebugLayer/CoordinateLabel
@onready var tile_state_label: Label = $DebugLayer/TileStateLabel
@onready var player_debug_label: Label = $DebugLayer/PlayerDebugLabel
@onready var interaction_debug_label: Label = $DebugLayer/InteractionDebugLabel

var _state_cycle: Array[String] = ["empty", "dry_soil", "wet_soil", "occupied"]
var _last_interaction_message: String = "Interaction: none"
var _tile_colors := {
	"grass": Color("#5FAE4D"),
	"path": Color("#C2A36B"),
	"blocked": Color("#3E5C36"),
	"unavailable": Color("#4B6F44"),
	"locked": Color("#2F3D2E"),
	"empty": Color("#8B7355"),
	"dry_soil": Color("#8B5A2B"),
	"wet_soil": Color("#5C4033"),
	"occupied": Color("#6B4E2E"),
}


func _ready() -> void:
	grid_canvas.draw.connect(_on_grid_canvas_draw)
	interaction_overlay.draw.connect(_on_interaction_overlay_draw)
	if not EventBus.farm_grid_changed.is_connected(_on_farm_grid_changed):
		EventBus.farm_grid_changed.connect(_on_farm_grid_changed)
	if not EventBus.player_interacted.is_connected(_on_player_interacted):
		EventBus.player_interacted.connect(_on_player_interacted)
	if not EventBus.player_interaction_failed.is_connected(_on_player_interaction_failed):
		EventBus.player_interaction_failed.connect(_on_player_interaction_failed)
	if not EventBus.farm_interaction_completed.is_connected(_on_farm_interaction_completed):
		EventBus.farm_interaction_completed.connect(_on_farm_interaction_completed)
	if not EventBus.farm_interaction_failed.is_connected(_on_farm_interaction_failed):
		EventBus.farm_interaction_failed.connect(_on_farm_interaction_failed)
	if not EventBus.game_loaded.is_connected(_on_game_loaded):
		EventBus.game_loaded.connect(_on_game_loaded)
	_load_manual_save()
	var restored_grid := SaveManager.register_farm_grid_manager(farm_grid_manager)
	if not restored_grid:
		farm_grid_manager.initialize_grid()
	_setup_player()
	_setup_interaction_controller()
	_update_debug_labels(Vector2i(-1, -1))
	_update_player_debug_label()


func _exit_tree() -> void:
	if has_node("/root/SaveManager"):
		SaveManager.unregister_farm_grid_manager(farm_grid_manager)
	if has_node("/root/EventBus") and EventBus.game_loaded.is_connected(_on_game_loaded):
		EventBus.game_loaded.disconnect(_on_game_loaded)


func _input(event: InputEvent) -> void:
	if _is_open_bag_event(event):
		inventory_panel.call("toggle_panel")
		get_viewport().set_input_as_handled()
		return
	if _is_ui_input_blocked():
		return
	if event is InputEventKey and farm_interaction_controller != null and farm_interaction_controller.has_method("handle_debug_key_event"):
		if bool(farm_interaction_controller.call("handle_debug_key_event", event)):
			_update_player_debug_label()
			return
	if event.is_action_pressed("ui_pause"):
		_save_manual_game()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_update_hovered_tile_from_mouse()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hovered_tile_from_mouse()
		_select_hovered_tile()


func _is_open_bag_event(event: InputEvent) -> bool:
	if InputMap.has_action("open_bag") and event.is_action_pressed("open_bag"):
		return true
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and (key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_clear_hovered_tile()


func _update_hovered_tile_from_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	var tile_pos: Vector2i = farm_grid_manager.world_to_grid(mouse_pos)
	if not farm_grid_manager.is_in_map_bounds(tile_pos):
		_clear_hovered_tile()
		return
	farm_grid_manager.set_hovered_tile(tile_pos)
	if farm_interaction_controller != null and farm_interaction_controller.has_method("update_action_preview"):
		farm_interaction_controller.call("update_action_preview", tile_pos)
	_update_debug_labels(tile_pos)
	grid_canvas.queue_redraw()
	interaction_overlay.queue_redraw()


func _clear_hovered_tile() -> void:
	farm_grid_manager.set_hovered_tile(Vector2i(-1, -1))
	_update_debug_labels(Vector2i(-1, -1))
	grid_canvas.queue_redraw()
	interaction_overlay.queue_redraw()


func _select_hovered_tile() -> void:
	var tile_pos: Vector2i = farm_grid_manager.hovered_tile
	if not farm_grid_manager.is_in_map_bounds(tile_pos):
		_clear_hovered_tile()
		return
	farm_grid_manager.set_selected_tile(tile_pos)
	if farm_interaction_controller != null and farm_interaction_controller.has_method("request_tile_interaction"):
		farm_interaction_controller.call("request_tile_interaction", tile_pos, "mouse")
	elif farm_grid_manager.debug_mode and farm_grid_manager.is_plot_unlocked(tile_pos) and not _tile_has_crop(tile_pos):
		_cycle_debug_state(tile_pos)
	_update_debug_labels(tile_pos)
	grid_canvas.queue_redraw()
	interaction_overlay.queue_redraw()
	if crop_overlay != null:
		crop_overlay.queue_redraw()


func _cycle_debug_state(tile_pos: Vector2i) -> void:
	var current_state: String = farm_grid_manager.get_plot_state(tile_pos)
	if current_state not in _state_cycle:
		return
	var next_index := (_state_cycle.find(current_state) + 1) % _state_cycle.size()
	var next_state := _state_cycle[next_index]
	if next_state == "occupied":
		farm_grid_manager.set_tile_occupied(tile_pos, true, farm_grid_manager.tile_pos_to_key(tile_pos))
	else:
		farm_grid_manager.set_plot_state(tile_pos, next_state)


func _process(_delta: float) -> void:
	_update_player_debug_label()
	interaction_overlay.queue_redraw()


func _setup_player() -> void:
	if player == null:
		return
	if player.has_method("set_farm_grid_manager"):
		player.call("set_farm_grid_manager", farm_grid_manager)
	if player.has_method("set_spawn_grid"):
		player.call("set_spawn_grid", Vector2i(8, 13))
	if inventory_panel != null and inventory_panel.has_method("setup"):
		inventory_panel.call("setup", farm_interaction_controller, player)


func _setup_interaction_controller() -> void:
	if farm_interaction_controller == null:
		return
	if farm_interaction_controller.has_method("setup"):
		farm_interaction_controller.call("setup", farm_grid_manager, crop_overlay, interaction_debug_label)
	if farm_interaction_controller.has_method("select_seed"):
		farm_interaction_controller.call("select_seed", "carrot")


func _load_manual_save() -> void:
	if not SaveManager.has_save(0):
		return
	var result: Dictionary = SaveManager.load_game(0)
	if not bool(result.get("success", false)):
		push_warning("读取手动存档失败: %s" % str(result.get("message", "")))


func _save_manual_game() -> void:
	var result: Dictionary = SaveManager.save_game(0)
	if bool(result.get("success", false)):
		EventBus.ui_notification.emit("游戏已保存", "info")
		_last_interaction_message = "Save: success"
	else:
		EventBus.ui_notification.emit("保存失败", "warning")
		_last_interaction_message = "Save: failed %s" % str(result.get("error_code", ""))
	_update_player_debug_label()


func _update_player_debug_label() -> void:
	if player_debug_label == null or player == null:
		return
	var target: Dictionary = {}
	if player.has_method("get_current_interaction_target"):
		target = player.call("get_current_interaction_target")
	var target_text := "Target: none"
	if not target.is_empty():
		target_text = "Target: %s %s unlocked=%s" % [
			str(target.get("type", "")),
			str(target.get("plot_state", "")),
			str(target.get("unlocked", false)),
		]
	var grid_pos: Vector2i = player.call("get_current_grid_pos") if player.has_method("get_current_grid_pos") else Vector2i.ZERO
	var front_pos: Vector2i = player.call("get_front_grid_pos") if player.has_method("get_front_grid_pos") else Vector2i.ZERO
	var facing := str(player.call("get_facing_direction_id")) if player.has_method("get_facing_direction_id") else "down"
	player_debug_label.text = "Player: (%.0f, %.0f)\nGrid: (%d, %d)\nFacing: %s\nFront Tile: (%d, %d)\n%s\n%s" % [
		player.global_position.x,
		player.global_position.y,
		grid_pos.x,
		grid_pos.y,
		facing,
		front_pos.x,
		front_pos.y,
		target_text,
		_last_interaction_message,
	]


func _update_debug_labels(tile_pos: Vector2i) -> void:
	if not farm_grid_manager.is_in_map_bounds(tile_pos):
		coordinate_label.text = "Tile: out of bounds"
		tile_state_label.text = ""
		return
	var tile_data: Dictionary = farm_grid_manager.get_tile_data(tile_pos)
	coordinate_label.text = "Tile: (%d, %d)" % [tile_pos.x, tile_pos.y]
	tile_state_label.text = "Terrain: %s\nState: %s\nUnlocked: %s\nOccupied: %s" % [
		str(tile_data.get("terrain_type", "")),
		str(tile_data.get("plot_state", "")),
		str(tile_data.get("unlocked", false)),
		str(tile_data.get("occupied", false)),
	]


func _on_farm_grid_changed() -> void:
	grid_canvas.queue_redraw()
	interaction_overlay.queue_redraw()


func _on_game_loaded(_slot: int, _metadata: Dictionary) -> void:
	if farm_interaction_controller != null and farm_interaction_controller.has_method("reconcile_grid_with_crops"):
		farm_interaction_controller.call("reconcile_grid_with_crops")
	_update_debug_labels(farm_grid_manager.hovered_tile)
	grid_canvas.queue_redraw()
	interaction_overlay.queue_redraw()
	if crop_overlay != null:
		crop_overlay.queue_redraw()


func _on_player_interacted(target: Dictionary) -> void:
	_last_interaction_message = "Interaction: success %s %s" % [
		str(target.get("type", "unknown")),
		str(target.get("grid_pos", Vector2i(-1, -1))),
	]
	print(_last_interaction_message)
	_update_player_debug_label()


func _on_player_interaction_failed(reason: String) -> void:
	_last_interaction_message = "Interaction: failed %s" % reason
	print(_last_interaction_message)
	_update_player_debug_label()


func _on_farm_interaction_completed(result: Dictionary) -> void:
	_last_interaction_message = "Farm: %s %s" % [
		str(result.get("action", "")),
		str(result.get("message", "")),
	]
	print(_last_interaction_message)
	_update_player_debug_label()
	grid_canvas.queue_redraw()
	interaction_overlay.queue_redraw()
	if crop_overlay != null:
		crop_overlay.queue_redraw()


func _on_farm_interaction_failed(result: Dictionary) -> void:
	_last_interaction_message = "Farm: failed %s" % str(result.get("reason", ""))
	print(_last_interaction_message)
	_update_player_debug_label()


func _on_grid_canvas_draw() -> void:
	_draw_map_tiles()


func _on_interaction_overlay_draw() -> void:
	_draw_debug_overlays()


func _draw_map_tiles() -> void:
	for y in range(farm_grid_manager.MAP_HEIGHT):
		for x in range(farm_grid_manager.MAP_WIDTH):
			var tile_pos := Vector2i(x, y)
			var rect := Rect2(farm_grid_manager.grid_to_world(tile_pos), Vector2.ONE * farm_grid_manager.TILE_SIZE)
			grid_canvas.draw_rect(rect, _get_tile_color(tile_pos), true)
			grid_canvas.draw_rect(rect, Color(0, 0, 0, 0.18), false, 1.0)


func _draw_debug_overlays() -> void:
	var player_target_tile := _get_player_target_tile()
	if farm_grid_manager.is_in_map_bounds(player_target_tile):
		var target_rect := Rect2(farm_grid_manager.grid_to_world(player_target_tile), Vector2.ONE * farm_grid_manager.TILE_SIZE)
		interaction_overlay.draw_rect(target_rect, Color(0.0, 0.85, 1.0, 0.18), true)
		interaction_overlay.draw_rect(target_rect, Color(0.0, 0.95, 1.0, 0.95), false, 3.0)
	if farm_grid_manager.is_in_map_bounds(farm_grid_manager.hovered_tile):
		var hover_rect := Rect2(farm_grid_manager.grid_to_world(farm_grid_manager.hovered_tile), Vector2.ONE * farm_grid_manager.TILE_SIZE)
		interaction_overlay.draw_rect(hover_rect, Color(1, 1, 1, 0.35), false, 2.0)
	if farm_grid_manager.is_in_map_bounds(farm_grid_manager.selected_tile):
		var selected_rect := Rect2(farm_grid_manager.grid_to_world(farm_grid_manager.selected_tile), Vector2.ONE * farm_grid_manager.TILE_SIZE)
		interaction_overlay.draw_rect(selected_rect, Color(1, 0.9, 0.1, 0.6), false, 2.0)


func _get_tile_color(tile_pos: Vector2i) -> Color:
	var tile_data: Dictionary = farm_grid_manager.get_tile_data(tile_pos)
	var state := str(tile_data.get("plot_state", "unavailable"))
	if state in _tile_colors:
		return _tile_colors[state]
	var terrain := str(tile_data.get("terrain_type", "grass"))
	return _tile_colors.get(terrain, Color.MAGENTA)


func _tile_has_crop(tile_pos: Vector2i) -> bool:
	return has_node("/root/CropManager") and CropManager.has_crop(tile_pos)


func _get_player_target_tile() -> Vector2i:
	if player == null or not player.has_method("get_current_interaction_target"):
		return Vector2i(-1, -1)
	var target: Dictionary = player.call("get_current_interaction_target")
	if target.is_empty() or str(target.get("type", "")) != "farm_tile":
		return Vector2i(-1, -1)
	return target.get("grid_pos", Vector2i(-1, -1))


func _is_ui_input_blocked() -> bool:
	return inventory_panel != null and inventory_panel.has_method("is_panel_open") and bool(inventory_panel.call("is_panel_open"))
