extends Node2D
## Farm — 个人田园场景入口与占位视觉调试交互。

@onready var farm_grid_manager: Node = $FarmGridManager
@onready var grid_canvas: Node2D = $GridRoot/GridCanvas
@onready var coordinate_label: Label = $DebugLayer/CoordinateLabel
@onready var tile_state_label: Label = $DebugLayer/TileStateLabel

var _state_cycle: Array[String] = ["empty", "dry_soil", "wet_soil", "occupied"]
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
	if not EventBus.farm_grid_changed.is_connected(_on_farm_grid_changed):
		EventBus.farm_grid_changed.connect(_on_farm_grid_changed)
	farm_grid_manager.initialize_grid()
	_update_debug_labels(Vector2i(-1, -1))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hovered_tile_from_mouse()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hovered_tile_from_mouse()
		_select_hovered_tile()


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
	_update_debug_labels(tile_pos)
	grid_canvas.queue_redraw()


func _clear_hovered_tile() -> void:
	farm_grid_manager.set_hovered_tile(Vector2i(-1, -1))
	_update_debug_labels(Vector2i(-1, -1))
	grid_canvas.queue_redraw()


func _select_hovered_tile() -> void:
	var tile_pos: Vector2i = farm_grid_manager.hovered_tile
	if not farm_grid_manager.is_in_map_bounds(tile_pos):
		_clear_hovered_tile()
		return
	farm_grid_manager.set_selected_tile(tile_pos)
	if farm_grid_manager.debug_mode and farm_grid_manager.is_plot_unlocked(tile_pos):
		_cycle_debug_state(tile_pos)
	_update_debug_labels(tile_pos)
	grid_canvas.queue_redraw()


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


func _on_grid_canvas_draw() -> void:
	_draw_map_tiles()
	_draw_debug_overlays()


func _draw_map_tiles() -> void:
	for y in range(farm_grid_manager.MAP_HEIGHT):
		for x in range(farm_grid_manager.MAP_WIDTH):
			var tile_pos := Vector2i(x, y)
			var rect := Rect2(farm_grid_manager.grid_to_world(tile_pos), Vector2.ONE * farm_grid_manager.TILE_SIZE)
			grid_canvas.draw_rect(rect, _get_tile_color(tile_pos), true)
			grid_canvas.draw_rect(rect, Color(0, 0, 0, 0.18), false, 1.0)


func _draw_debug_overlays() -> void:
	if farm_grid_manager.is_in_map_bounds(farm_grid_manager.hovered_tile):
		var hover_rect := Rect2(farm_grid_manager.grid_to_world(farm_grid_manager.hovered_tile), Vector2.ONE * farm_grid_manager.TILE_SIZE)
		grid_canvas.draw_rect(hover_rect, Color(1, 1, 1, 0.35), false, 2.0)
	if farm_grid_manager.is_in_map_bounds(farm_grid_manager.selected_tile):
		var selected_rect := Rect2(farm_grid_manager.grid_to_world(farm_grid_manager.selected_tile), Vector2.ONE * farm_grid_manager.TILE_SIZE)
		grid_canvas.draw_rect(selected_rect, Color(1, 0.9, 0.1, 0.6), false, 2.0)


func _get_tile_color(tile_pos: Vector2i) -> Color:
	var tile_data: Dictionary = farm_grid_manager.get_tile_data(tile_pos)
	var state := str(tile_data.get("plot_state", "unavailable"))
	if state in _tile_colors:
		return _tile_colors[state]
	var terrain := str(tile_data.get("terrain_type", "grass"))
	return _tile_colors.get(terrain, Color.MAGENTA)
