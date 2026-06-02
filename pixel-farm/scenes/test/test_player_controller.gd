extends Node2D
## PlayerController 自动化 / 半自动化测试脚本。

@onready var farm_grid_manager: Node = $FarmGridManager
@onready var player: CharacterBody2D = $Player
@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []

var _spawned_count: int = 0
var _moved_count: int = 0
var _direction_changed_count: int = 0
var _movement_enabled_changed_count: int = 0
var _target_changed_count: int = 0
var _interacted_count: int = 0
var _interaction_failed_count: int = 0
var _farm_tile_requested_count: int = 0
var _last_spawned: Dictionary = {}
var _last_moved: Dictionary = {}
var _last_direction: Dictionary = {}
var _last_movement_enabled: bool = true
var _last_target: Dictionary = {}
var _last_interacted_target: Dictionary = {}
var _last_failure_reason: String = ""
var _last_tile_request: Dictionary = {}


func _ready() -> void:
	_connect_signals_once()
	farm_grid_manager.initialize_grid()
	player.set_farm_grid_manager(farm_grid_manager)
	print("=== PlayerController 自动化测试 ===")

	test_initial_spawn()
	test_facing_direction_defaults_to_down()
	test_set_world_position_updates_grid()
	test_set_spawn_grid()
	test_get_front_grid_pos_down()
	test_get_front_grid_pos_up()
	test_get_front_grid_pos_left()
	test_get_front_grid_pos_right()
	test_move_speed_setter()
	test_movement_enable_disable()
	test_interaction_enable_disable()
	test_interaction_target_from_front_tile()
	test_interaction_target_out_of_bounds()
	test_try_interact_with_tile_target()
	test_try_interact_without_target()
	test_event_bus_signals()

	var summary := "=== PlayerController 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_initial_spawn() -> void:
	player.set_spawn_grid(Vector2i(8, 13))
	_assert(player.get_current_grid_pos() == Vector2i(8, 13), "出生点网格为 (8,13)")
	_assert(player.global_position == farm_grid_manager.grid_to_world_center(Vector2i(8, 13)), "出生点世界坐标为格子中心")


func test_facing_direction_defaults_to_down() -> void:
	player.reset_player()
	_assert(player.get_facing_direction_id() == "down", "默认面朝方向为 down")
	_assert(player.get_facing_vector() == Vector2i(0, 1), "默认面朝向量为向下")


func test_set_world_position_updates_grid() -> void:
	player.set_world_position(Vector2(136, 216))
	_assert(player.get_current_grid_pos() == farm_grid_manager.world_to_grid(Vector2(136, 216)), "设置世界坐标后刷新当前格")


func test_set_spawn_grid() -> void:
	player.set_spawn_grid(Vector2i(5, 5))
	_assert(player.get_current_grid_pos() == Vector2i(5, 5), "set_spawn_grid 设置当前格")
	_assert(player.global_position == farm_grid_manager.grid_to_world_center(Vector2i(5, 5)), "set_spawn_grid 设置世界中心")


func test_get_front_grid_pos_down() -> void:
	player.set_spawn_grid(Vector2i(8, 13))
	player.debug_set_facing_direction("down")
	_assert(player.get_front_grid_pos() == Vector2i(8, 14), "面朝 down 时面前格正确")


func test_get_front_grid_pos_up() -> void:
	player.set_spawn_grid(Vector2i(8, 13))
	player.debug_set_facing_direction("up")
	_assert(player.get_front_grid_pos() == Vector2i(8, 12), "面朝 up 时面前格正确")


func test_get_front_grid_pos_left() -> void:
	player.set_spawn_grid(Vector2i(8, 13))
	player.debug_set_facing_direction("left")
	_assert(player.get_front_grid_pos() == Vector2i(7, 13), "面朝 left 时面前格正确")


func test_get_front_grid_pos_right() -> void:
	player.set_spawn_grid(Vector2i(8, 13))
	player.debug_set_facing_direction("right")
	_assert(player.get_front_grid_pos() == Vector2i(9, 13), "面朝 right 时面前格正确")


func test_move_speed_setter() -> void:
	player.set_move_speed(120.0)
	_assert(is_equal_approx(player.get_move_speed(), 120.0), "移动速度 setter 生效")


func test_movement_enable_disable() -> void:
	player.set_can_move(false)
	_assert(not player.is_movement_enabled(), "移动禁用状态生效")
	_assert(player.get_input_vector() == Vector2.ZERO, "移动禁用时输入向量清零")
	player.set_can_move(true)
	_assert(player.is_movement_enabled(), "移动启用状态恢复")


func test_interaction_enable_disable() -> void:
	player.set_can_interact(false)
	_assert(not player.is_interaction_enabled(), "交互禁用状态生效")
	player.set_can_interact(true)
	_assert(player.is_interaction_enabled(), "交互启用状态恢复")


func test_interaction_target_from_front_tile() -> void:
	player.set_spawn_grid(Vector2i(5, 5))
	player.debug_set_facing_direction("right")
	player.update_interaction_target()
	var target: Dictionary = player.get_current_interaction_target()
	_assert(target.get("type", "") == "farm_tile", "面前地块生成 farm_tile 目标")
	_assert(target.get("grid_pos", Vector2i.ZERO) == Vector2i(6, 5), "交互目标坐标为面前格")
	_assert(target.has("terrain_type") and target.has("plot_state") and target.has("unlocked") and target.has("occupied"), "交互目标包含地块状态字段")


func test_interaction_target_out_of_bounds() -> void:
	player.set_spawn_grid(Vector2i(29, 19))
	player.debug_set_facing_direction("right")
	player.update_interaction_target()
	_assert(not player.has_interaction_target(), "面前格越界时无交互目标")


func test_try_interact_with_tile_target() -> void:
	_reset_signal_counters()
	player.set_can_interact(true)
	player.set_spawn_grid(Vector2i(5, 5))
	player.debug_set_facing_direction("right")
	_assert(player.try_interact(), "有地块目标时 try_interact 返回 true")
	_assert(_interacted_count >= 1, "成功交互发射 player_interacted")
	_assert(_farm_tile_requested_count >= 1, "地块目标发射 farm_tile_interaction_requested")
	_assert(_last_tile_request.get("tile_pos", Vector2i.ZERO) == Vector2i(6, 5), "地块交互请求坐标正确")


func test_try_interact_without_target() -> void:
	_reset_signal_counters()
	player.set_can_interact(true)
	player.set_spawn_grid(Vector2i(29, 19))
	player.debug_set_facing_direction("right")
	_assert(not player.try_interact(), "无目标时 try_interact 返回 false")
	_assert(_interaction_failed_count >= 1 and _last_failure_reason == "no_target", "无目标交互发射 no_target")


func test_event_bus_signals() -> void:
	_reset_signal_counters()
	player.reset_player()
	_assert(_spawned_count >= 1, "reset_player 发射 player_spawned")
	player.set_world_position(Vector2(120, 120))
	player.debug_refresh_state()
	player._physics_process(0.016)
	_assert(_moved_count >= 1, "位置变化发射 player_moved")
	player.debug_set_facing_direction("left")
	_assert(_direction_changed_count >= 1 and _last_direction.get("direction", "") == "left", "方向变化发射 player_direction_changed")
	player.set_can_move(false)
	_assert(_movement_enabled_changed_count >= 1 and _last_movement_enabled == false, "移动开关变化发射信号")
	player.set_can_move(true)
	player.set_spawn_grid(Vector2i(5, 5))
	player.debug_set_facing_direction("right")
	player.update_interaction_target()
	_assert(_target_changed_count >= 1, "交互目标变化发射信号")
	player.set_can_interact(false)
	player.try_interact()
	_assert(_interaction_failed_count >= 1 and _last_failure_reason == "interaction_disabled", "交互禁用发射失败信号")
	player.set_can_interact(true)


func _connect_signals_once() -> void:
	if not EventBus.player_spawned.is_connected(_on_player_spawned):
		EventBus.player_spawned.connect(_on_player_spawned)
	if not EventBus.player_moved.is_connected(_on_player_moved):
		EventBus.player_moved.connect(_on_player_moved)
	if not EventBus.player_direction_changed.is_connected(_on_player_direction_changed):
		EventBus.player_direction_changed.connect(_on_player_direction_changed)
	if not EventBus.player_movement_enabled_changed.is_connected(_on_player_movement_enabled_changed):
		EventBus.player_movement_enabled_changed.connect(_on_player_movement_enabled_changed)
	if not EventBus.player_interaction_target_changed.is_connected(_on_player_interaction_target_changed):
		EventBus.player_interaction_target_changed.connect(_on_player_interaction_target_changed)
	if not EventBus.player_interacted.is_connected(_on_player_interacted):
		EventBus.player_interacted.connect(_on_player_interacted)
	if not EventBus.player_interaction_failed.is_connected(_on_player_interaction_failed):
		EventBus.player_interaction_failed.connect(_on_player_interaction_failed)
	if not EventBus.farm_tile_interaction_requested.is_connected(_on_farm_tile_interaction_requested):
		EventBus.farm_tile_interaction_requested.connect(_on_farm_tile_interaction_requested)


func _reset_signal_counters() -> void:
	_spawned_count = 0
	_moved_count = 0
	_direction_changed_count = 0
	_movement_enabled_changed_count = 0
	_target_changed_count = 0
	_interacted_count = 0
	_interaction_failed_count = 0
	_farm_tile_requested_count = 0
	_last_spawned = {}
	_last_moved = {}
	_last_direction = {}
	_last_movement_enabled = true
	_last_target = {}
	_last_interacted_target = {}
	_last_failure_reason = ""
	_last_tile_request = {}


func _on_player_spawned(world_pos: Vector2, grid_pos: Vector2i) -> void:
	_spawned_count += 1
	_last_spawned = {"world_pos": world_pos, "grid_pos": grid_pos}


func _on_player_moved(world_pos: Vector2, grid_pos: Vector2i) -> void:
	_moved_count += 1
	_last_moved = {"world_pos": world_pos, "grid_pos": grid_pos}


func _on_player_direction_changed(direction: String, direction_vector: Vector2i) -> void:
	_direction_changed_count += 1
	_last_direction = {"direction": direction, "direction_vector": direction_vector}


func _on_player_movement_enabled_changed(enabled: bool) -> void:
	_movement_enabled_changed_count += 1
	_last_movement_enabled = enabled


func _on_player_interaction_target_changed(target: Dictionary) -> void:
	_target_changed_count += 1
	_last_target = target


func _on_player_interacted(target: Dictionary) -> void:
	_interacted_count += 1
	_last_interacted_target = target


func _on_player_interaction_failed(reason: String) -> void:
	_interaction_failed_count += 1
	_last_failure_reason = reason


func _on_farm_tile_interaction_requested(tile_pos: Vector2i, target: Dictionary) -> void:
	_farm_tile_requested_count += 1
	_last_tile_request = {"tile_pos": tile_pos, "target": target}


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
