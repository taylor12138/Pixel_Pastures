extends CharacterBody2D
## PlayerController — 玩家移动、方向与交互请求控制器。

const PLAYER_WIDTH: int = 32
const PLAYER_HEIGHT: int = 48
const COLLISION_WIDTH: int = 16
const COLLISION_HEIGHT: int = 12
const DEFAULT_MOVE_SPEED: float = 80.0
const INTERACTION_DISTANCE: int = 16
const INTERACTION_RADIUS: float = 20.0
const SPAWN_GRID_POS: Vector2i = Vector2i(8, 13)
const MAP_MIN: Vector2 = Vector2(0, 0)
const MAP_MAX: Vector2 = Vector2(480, 320)

## 玩家四方向面朝枚举。
enum FacingDirection {
	DOWN,
	UP,
	LEFT,
	RIGHT,
}

const FACING_TO_VECTOR := {
	FacingDirection.DOWN: Vector2i(0, 1),
	FacingDirection.UP: Vector2i(0, -1),
	FacingDirection.LEFT: Vector2i(-1, 0),
	FacingDirection.RIGHT: Vector2i(1, 0),
}

const FACING_TO_ID := {
	FacingDirection.DOWN: "down",
	FacingDirection.UP: "up",
	FacingDirection.LEFT: "left",
	FacingDirection.RIGHT: "right",
}

const ID_TO_FACING := {
	"down": FacingDirection.DOWN,
	"up": FacingDirection.UP,
	"left": FacingDirection.LEFT,
	"right": FacingDirection.RIGHT,
}

@export var move_speed: float = DEFAULT_MOVE_SPEED
@export var can_move: bool = true
@export var can_interact: bool = true
@export var default_spawn_grid: Vector2i = SPAWN_GRID_POS

var input_vector: Vector2 = Vector2.ZERO
var facing_direction: FacingDirection = FacingDirection.DOWN
var last_non_zero_direction: Vector2 = Vector2.DOWN
var current_grid_pos: Vector2i = Vector2i.ZERO
var front_grid_pos: Vector2i = Vector2i.ZERO
var current_interaction_target: Dictionary = {}
var farm_grid_manager: Node = null

var _last_emitted_world_pos: Vector2 = Vector2.INF
var _last_emitted_grid_pos: Vector2i = Vector2i(-999999, -999999)
var _last_target_signature: String = ""
var _ui_input_blocked: bool = false
var _move_enabled_before_ui_block: bool = true
var _interact_enabled_before_ui_block: bool = true

@onready var debug_label: Label = get_node_or_null("DebugLabel") as Label
@onready var direction_marker: ColorRect = get_node_or_null("BodyPivot/DirectionMarker") as ColorRect


func _ready() -> void:
	reset_player()
	if _has_event_bus() and not EventBus.ui_input_block_changed.is_connected(_on_ui_input_block_changed):
		EventBus.ui_input_block_changed.connect(_on_ui_input_block_changed)


func _exit_tree() -> void:
	if _has_event_bus() and EventBus.ui_input_block_changed.is_connected(_on_ui_input_block_changed):
		EventBus.ui_input_block_changed.disconnect(_on_ui_input_block_changed)


func _physics_process(_delta: float) -> void:
	input_vector = _read_input() if can_move else Vector2.ZERO
	_update_facing_direction(input_vector)
	velocity = input_vector * move_speed
	move_and_slide()
	_clamp_to_map_bounds()
	_update_grid_positions()
	update_interaction_target()
	_emit_player_moved_if_needed()
	_update_debug_label()


func _unhandled_input(event: InputEvent) -> void:
	if not _ui_input_blocked and event.is_action_pressed("interact"):
		try_interact()


## 设置角色出生位置为指定网格中心。
func set_spawn_grid(tile_pos: Vector2i) -> void:
	default_spawn_grid = tile_pos
	set_world_position(_grid_to_world_center(tile_pos))


## 设置角色世界坐标。
func set_world_position(world_pos: Vector2) -> void:
	global_position = world_pos
	_clamp_to_map_bounds()
	_update_grid_positions()
	update_interaction_target()
	_update_debug_label()


## 绑定 FarmGridManager，用于边界、地块查询和交互目标识别。
func set_farm_grid_manager(manager: Node) -> void:
	farm_grid_manager = manager
	_update_grid_positions()
	update_interaction_target()
	_update_debug_label()


## 重置玩家到默认状态。
func reset_player() -> void:
	can_move = true
	can_interact = true
	facing_direction = FacingDirection.DOWN
	last_non_zero_direction = Vector2.DOWN
	input_vector = Vector2.ZERO
	velocity = Vector2.ZERO
	set_world_position(_grid_to_world_center(default_spawn_grid))
	_emit_player_spawned()
	_update_direction_marker()


## 启用 / 禁用移动。
func set_can_move(value: bool) -> void:
	if can_move == value:
		return
	can_move = value
	if not can_move:
		input_vector = Vector2.ZERO
		velocity = Vector2.ZERO
	if _has_event_bus():
		EventBus.player_movement_enabled_changed.emit(can_move)


## 当前是否允许移动。
func is_movement_enabled() -> bool:
	return can_move


## 获取当前输入向量。
func get_input_vector() -> Vector2:
	return input_vector


## 获取当前移动速度。
func get_move_speed() -> float:
	return move_speed


## 设置移动速度。
func set_move_speed(value: float) -> void:
	move_speed = maxf(0.0, value)


## 获取当前是否正在移动。
func is_moving() -> bool:
	return input_vector != Vector2.ZERO or velocity != Vector2.ZERO


## 获取面朝方向枚举。
func get_facing_direction() -> FacingDirection:
	return facing_direction


## 获取面朝方向 ID：down / up / left / right。
func get_facing_direction_id() -> String:
	return FACING_TO_ID.get(facing_direction, "down")


## 获取面朝方向向量。
func get_facing_vector() -> Vector2i:
	return FACING_TO_VECTOR.get(facing_direction, Vector2i(0, 1))


## 获取玩家当前脚下网格坐标。
func get_current_grid_pos() -> Vector2i:
	return current_grid_pos


## 获取玩家面前一格坐标。
func get_front_grid_pos() -> Vector2i:
	return front_grid_pos


## 获取玩家脚底世界坐标，用于网格换算。
func get_feet_world_position() -> Vector2:
	return global_position


## 启用 / 禁用交互。
func set_can_interact(value: bool) -> void:
	can_interact = value


## 当前是否允许交互。
func is_interaction_enabled() -> bool:
	return can_interact


## 刷新当前可交互目标。
func update_interaction_target() -> void:
	var old_signature := _get_target_signature(current_interaction_target)
	current_interaction_target = {}
	if farm_grid_manager == null:
		_emit_target_changed_if_needed(old_signature)
		return
	var target_pos := get_front_grid_pos()
	if not _farm_grid_call_bool("is_in_map_bounds", target_pos):
		_emit_target_changed_if_needed(old_signature)
		return
	var tile_data := _farm_grid_call_dictionary("get_tile_data", target_pos)
	if tile_data.is_empty():
		_emit_target_changed_if_needed(old_signature)
		return
	current_interaction_target = {
		"type": "farm_tile",
		"grid_pos": target_pos,
		"world_pos": _grid_to_world_center(target_pos),
		"terrain_type": str(tile_data.get("terrain_type", "")),
		"plot_state": str(tile_data.get("plot_state", "")),
		"unlocked": bool(tile_data.get("unlocked", false)),
		"occupied": bool(tile_data.get("occupied", false)),
		"node": null,
		"priority": 10,
	}
	_emit_target_changed_if_needed(old_signature)


## 获取当前可交互目标。
func get_current_interaction_target() -> Dictionary:
	return current_interaction_target.duplicate(true)


## 是否存在可交互目标。
func has_interaction_target() -> bool:
	return not current_interaction_target.is_empty()


## 尝试执行交互；成功触发事件时返回 true。
func try_interact() -> bool:
	if _ui_input_blocked or not can_interact:
		_emit_interaction_failed("interaction_disabled")
		return false
	update_interaction_target()
	if current_interaction_target.is_empty():
		_emit_interaction_failed("no_target")
		return false
	var target := get_current_interaction_target()
	if _has_event_bus():
		EventBus.player_interacted.emit(target)
		if str(target.get("type", "")) == "farm_tile":
			EventBus.farm_tile_interaction_requested.emit(target.get("grid_pos", Vector2i(-1, -1)), target)
	return true


## [调试] 直接设置面朝方向。
func debug_set_facing_direction(direction_id: String) -> void:
	if not ID_TO_FACING.has(direction_id):
		push_warning("未知面朝方向: %s" % direction_id)
		return
	var old_direction := facing_direction
	facing_direction = ID_TO_FACING[direction_id]
	last_non_zero_direction = Vector2(get_facing_vector())
	front_grid_pos = current_grid_pos + get_facing_vector()
	_update_direction_marker()
	if facing_direction != old_direction:
		_emit_direction_changed()
	update_interaction_target()
	_update_debug_label()


## [调试] 强制刷新坐标与交互目标。
func debug_refresh_state() -> void:
	_update_grid_positions()
	update_interaction_target()
	_update_debug_label()


## [调试] 打印玩家状态。
func debug_print_state() -> void:
	print("Player: world=%s grid=%s facing=%s front=%s target=%s" % [global_position, current_grid_pos, get_facing_direction_id(), front_grid_pos, current_interaction_target])


func _read_input() -> Vector2:
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if direction.length() > 1.0:
		direction = direction.normalized()
	return direction


func _update_facing_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var old_direction := facing_direction
	if absf(direction.x) >= absf(direction.y):
		facing_direction = FacingDirection.RIGHT if direction.x > 0.0 else FacingDirection.LEFT
	else:
		facing_direction = FacingDirection.DOWN if direction.y > 0.0 else FacingDirection.UP
	last_non_zero_direction = direction
	_update_direction_marker()
	if facing_direction != old_direction:
		_emit_direction_changed()


func _clamp_to_map_bounds() -> void:
	global_position = Vector2(
		clampf(global_position.x, MAP_MIN.x, MAP_MAX.x),
		clampf(global_position.y, MAP_MIN.y, MAP_MAX.y)
	)


func _update_grid_positions() -> void:
	current_grid_pos = _world_to_grid(get_feet_world_position())
	front_grid_pos = current_grid_pos + get_facing_vector()


func _grid_to_world_center(tile_pos: Vector2i) -> Vector2:
	if farm_grid_manager != null and farm_grid_manager.has_method("grid_to_world_center"):
		return farm_grid_manager.call("grid_to_world_center", tile_pos)
	return Vector2(tile_pos.x * INTERACTION_DISTANCE + INTERACTION_DISTANCE * 0.5, tile_pos.y * INTERACTION_DISTANCE + INTERACTION_DISTANCE * 0.5)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	if farm_grid_manager != null and farm_grid_manager.has_method("world_to_grid"):
		return farm_grid_manager.call("world_to_grid", world_pos)
	return Vector2i(floori(world_pos.x / float(INTERACTION_DISTANCE)), floori(world_pos.y / float(INTERACTION_DISTANCE)))


func _farm_grid_call_bool(method_name: String, tile_pos: Vector2i) -> bool:
	if farm_grid_manager == null or not farm_grid_manager.has_method(method_name):
		return false
	return bool(farm_grid_manager.call(method_name, tile_pos))


func _farm_grid_call_dictionary(method_name: String, tile_pos: Vector2i) -> Dictionary:
	if farm_grid_manager == null or not farm_grid_manager.has_method(method_name):
		return {}
	var result: Variant = farm_grid_manager.call(method_name, tile_pos)
	if result is Dictionary:
		return (result as Dictionary).duplicate(true)
	return {}


func _emit_player_spawned() -> void:
	if _has_event_bus():
		EventBus.player_spawned.emit(global_position, current_grid_pos)
	_last_emitted_world_pos = global_position
	_last_emitted_grid_pos = current_grid_pos


func _emit_player_moved_if_needed() -> void:
	if global_position == _last_emitted_world_pos and current_grid_pos == _last_emitted_grid_pos:
		return
	_last_emitted_world_pos = global_position
	_last_emitted_grid_pos = current_grid_pos
	if _has_event_bus():
		EventBus.player_moved.emit(global_position, current_grid_pos)


func _emit_direction_changed() -> void:
	if _has_event_bus():
		EventBus.player_direction_changed.emit(get_facing_direction_id(), get_facing_vector())


func _emit_interaction_failed(reason: String) -> void:
	if _has_event_bus():
		EventBus.player_interaction_failed.emit(reason)


func _on_ui_input_block_changed(blocked: bool) -> void:
	if _ui_input_blocked == blocked:
		return
	_ui_input_blocked = blocked
	if blocked:
		_move_enabled_before_ui_block = can_move
		_interact_enabled_before_ui_block = can_interact
		set_can_move(false)
		set_can_interact(false)
	else:
		set_can_move(_move_enabled_before_ui_block)
		set_can_interact(_interact_enabled_before_ui_block)


func _emit_target_changed_if_needed(old_signature: String) -> void:
	var new_signature := _get_target_signature(current_interaction_target)
	if new_signature == old_signature and new_signature == _last_target_signature:
		return
	_last_target_signature = new_signature
	if _has_event_bus():
		EventBus.player_interaction_target_changed.emit(get_current_interaction_target())


func _get_target_signature(target: Dictionary) -> String:
	if target.is_empty():
		return "none"
	return "%s:%s:%s:%s" % [
		str(target.get("type", "")),
		str(target.get("grid_pos", Vector2i(-1, -1))),
		str(target.get("plot_state", "")),
		str(target.get("occupied", false)),
	]


func _update_debug_label() -> void:
	if debug_label == null:
		return
	var target_text := "Target: none"
	if not current_interaction_target.is_empty():
		target_text = "Target: %s %s unlocked=%s" % [
			str(current_interaction_target.get("type", "")),
			str(current_interaction_target.get("plot_state", "")),
			str(current_interaction_target.get("unlocked", false)),
		]
	debug_label.text = "Player: (%.0f, %.0f)\nGrid: (%d, %d)\nFacing: %s\nFront Tile: (%d, %d)\n%s" % [
		global_position.x,
		global_position.y,
		current_grid_pos.x,
		current_grid_pos.y,
		get_facing_direction_id(),
		front_grid_pos.x,
		front_grid_pos.y,
		target_text,
	]


func _update_direction_marker() -> void:
	if direction_marker == null:
		return
	var marker_center := Vector2(0, -PLAYER_HEIGHT * 0.5)
	match facing_direction:
		FacingDirection.UP:
			marker_center = Vector2(0, -PLAYER_HEIGHT + 6)
		FacingDirection.DOWN:
			marker_center = Vector2(0, -6)
		FacingDirection.LEFT:
			marker_center = Vector2(-PLAYER_WIDTH * 0.5 + 6, -PLAYER_HEIGHT * 0.5)
		FacingDirection.RIGHT:
			marker_center = Vector2(PLAYER_WIDTH * 0.5 - 6, -PLAYER_HEIGHT * 0.5)
	direction_marker.position = marker_center


func _has_event_bus() -> bool:
	return has_node("/root/EventBus")
