extends Node2D
## FarmGridManager 自动化测试脚本

@onready var farm_grid_manager: Node = $FarmGridManager
@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []

var _grid_initialized_count: int = 0
var _grid_changed_count: int = 0
var _tile_hovered_count: int = 0
var _tile_selected_count: int = 0
var _tile_state_changed_count: int = 0
var _tile_unlocked_count: int = 0
var _tile_occupied_changed_count: int = 0
var _last_initialized_size: Vector2i = Vector2i.ZERO
var _last_hovered_tile: Vector2i = Vector2i(-1, -1)
var _last_selected_tile: Vector2i = Vector2i(-1, -1)
var _last_state_change: Dictionary = {}
var _last_unlocked_tile: Vector2i = Vector2i(-1, -1)
var _last_occupied_change: Dictionary = {}


func _ready() -> void:
	_connect_signals_once()
	print("=== FarmGridManager 自动化测试 ===")

	test_grid_initialization_and_bounds()
	test_initial_plot_states_and_terrain()
	test_coordinate_and_key_conversions()
	test_tile_queries_and_state_mutations()
	test_tile_actions()
	test_unlock_count_and_row_major_order()
	test_save_export_import()
	test_event_bus_signals()

	var summary := "=== FarmGridManager 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_grid_initialization_and_bounds() -> void:
	farm_grid_manager.initialize_grid()
	_assert(farm_grid_manager.tiles.size() == farm_grid_manager.MAP_WIDTH * farm_grid_manager.MAP_HEIGHT, "初始化生成 600 个 tile")
	_assert(farm_grid_manager.is_in_map_bounds(Vector2i(0, 0)), "地图左上角在范围内")
	_assert(farm_grid_manager.is_in_map_bounds(Vector2i(29, 19)), "地图右下角在范围内")
	_assert(not farm_grid_manager.is_in_map_bounds(Vector2i(-1, 0)), "负 x 坐标越界")
	_assert(not farm_grid_manager.is_in_map_bounds(Vector2i(30, 20)), "地图尺寸外坐标越界")
	_assert(farm_grid_manager.is_in_farm_area(Vector2i(5, 5)), "可耕区域左上角在范围内")
	_assert(farm_grid_manager.is_in_farm_area(Vector2i(24, 16)), "可耕区域右下角在范围内")
	_assert(not farm_grid_manager.is_in_farm_area(Vector2i(4, 5)), "可耕区域左侧外坐标不在范围内")
	_assert(not farm_grid_manager.is_in_farm_area(Vector2i(25, 17)), "可耕区域右下外坐标不在范围内")
	_assert(farm_grid_manager.is_in_unlockable_plot_area(Vector2i(5, 5)), "最大可解锁区域左上角在范围内")
	_assert(farm_grid_manager.is_in_unlockable_plot_area(Vector2i(12, 14)), "最大可解锁区域右下角在范围内")
	_assert(not farm_grid_manager.is_in_unlockable_plot_area(Vector2i(13, 14)), "最大可解锁区域右侧外坐标不在范围内")
	_assert(not farm_grid_manager.is_in_unlockable_plot_area(Vector2i(12, 15)), "最大可解锁区域下方外坐标不在范围内")


func test_initial_plot_states_and_terrain() -> void:
	farm_grid_manager.initialize_grid()
	_assert(farm_grid_manager.unlocked_plot_count == farm_grid_manager.DEFAULT_UNLOCKED_PLOT_COUNT, "初始解锁数量为 12")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 12, "初始已解锁坐标数量为 12")
	_assert(farm_grid_manager.get_plot_state(Vector2i(5, 5)) == farm_grid_manager.PLOT_EMPTY, "初始已解锁地块为空闲")
	_assert(farm_grid_manager.is_plot_unlocked(Vector2i(7, 8)), "3×4 初始区域最后一格已解锁")
	_assert(farm_grid_manager.get_plot_state(Vector2i(8, 5)) == farm_grid_manager.PLOT_LOCKED, "最大可解锁区域中未解锁地块为 locked")
	_assert(farm_grid_manager.get_plot_state(Vector2i(13, 5)) == farm_grid_manager.PLOT_UNAVAILABLE, "可耕预留区中非最大可解锁地块为 unavailable")
	_assert(farm_grid_manager.get_terrain_type(Vector2i(0, 0)) == farm_grid_manager.TERRAIN_GRASS, "非可耕地图区域为 grass")
	_assert(farm_grid_manager.get_plot_state(Vector2i(0, 0)) == farm_grid_manager.PLOT_UNAVAILABLE, "非可耕地图区域状态为 unavailable")
	_assert(farm_grid_manager.get_terrain_type(Vector2i(5, 5)) == farm_grid_manager.TERRAIN_FARM_PLOT, "可耕区域地形为 farm_plot")


func test_coordinate_and_key_conversions() -> void:
	_assert(farm_grid_manager.grid_to_world(Vector2i(2, 3)) == Vector2(32, 48), "grid_to_world 返回 tile 左上角")
	_assert(farm_grid_manager.grid_to_world_center(Vector2i(2, 3)) == Vector2(40, 56), "grid_to_world_center 返回 tile 中心")
	_assert(farm_grid_manager.world_to_grid(Vector2(0, 0)) == Vector2i(0, 0), "world_to_grid 处理原点")
	_assert(farm_grid_manager.world_to_grid(Vector2(15, 15)) == Vector2i(0, 0), "world_to_grid 处理 tile 内边界 15")
	_assert(farm_grid_manager.world_to_grid(Vector2(16, 16)) == Vector2i(1, 1), "world_to_grid 处理 tile 边界 16")
	_assert(farm_grid_manager.world_to_grid(Vector2(-1, -1)) == Vector2i(-1, -1), "world_to_grid 处理负坐标")
	_assert(farm_grid_manager.screen_to_grid(Vector2(32, 48)) == Vector2i(2, 3), "screen_to_grid 无 Camera2D 时按屏幕坐标转换")
	_assert(farm_grid_manager.tile_pos_to_key(Vector2i(12, 14)) == "12,14", "tile_pos_to_key 输出 x,y")
	_assert(farm_grid_manager.key_to_tile_pos("12,14") == Vector2i(12, 14), "key_to_tile_pos 解析合法 key")
	_assert(farm_grid_manager.key_to_tile_pos("bad") == Vector2i(-999999, -999999), "key_to_tile_pos 对非法 key 返回安全坐标")


func test_tile_queries_and_state_mutations() -> void:
	farm_grid_manager.initialize_grid()
	var unlocked_tile := Vector2i(5, 5)
	var locked_tile := Vector2i(8, 5)
	var grass_tile := Vector2i(0, 0)
	_assert(not farm_grid_manager.get_tile_data(unlocked_tile).is_empty(), "地图内地块查询返回数据")
	_assert(farm_grid_manager.get_tile_data(Vector2i(-1, -1)).is_empty(), "地图外地块查询返回空 Dictionary")
	_assert(farm_grid_manager.set_plot_state(unlocked_tile, farm_grid_manager.PLOT_DRY_SOIL), "已解锁地块可设置 dry_soil")
	_assert(farm_grid_manager.get_plot_state(unlocked_tile) == farm_grid_manager.PLOT_DRY_SOIL, "地块状态修改后可查询")
	_assert(not farm_grid_manager.set_plot_state(unlocked_tile, "invalid_state"), "非法状态修改返回 false")
	_assert(not farm_grid_manager.set_plot_state(locked_tile, farm_grid_manager.PLOT_DRY_SOIL), "锁定地块拒绝可操作状态")
	_assert(not farm_grid_manager.set_plot_state(grass_tile, farm_grid_manager.PLOT_EMPTY), "非可耕地拒绝可操作状态")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 12, "get_unlocked_plot_positions 返回初始 12 格")
	_assert(farm_grid_manager.get_plantable_positions().size() == 12, "get_plantable_positions 返回初始可种植 12 格")


func test_tile_actions() -> void:
	farm_grid_manager.initialize_grid()
	var tile_pos := Vector2i(5, 5)
	_assert(farm_grid_manager.can_plant_on_tile(tile_pos), "空闲已解锁地块可种植")
	_assert(not farm_grid_manager.can_water_tile(tile_pos), "空闲地块不可浇水")
	_assert(farm_grid_manager.set_plot_state(tile_pos, farm_grid_manager.PLOT_DRY_SOIL), "地块可设置为干土")
	_assert(farm_grid_manager.can_water_tile(tile_pos), "干土地块可浇水")
	_assert(farm_grid_manager.mark_tile_watered(tile_pos), "干土地块浇水成功")
	_assert(farm_grid_manager.get_plot_state(tile_pos) == farm_grid_manager.PLOT_WET_SOIL, "浇水后状态为 wet_soil")
	_assert(farm_grid_manager.set_tile_occupied(tile_pos, true, "crop:5,5"), "地块可设置为占用")
	_assert(farm_grid_manager.is_tile_occupied(tile_pos), "占用状态可查询")
	_assert(farm_grid_manager.get_plot_state(tile_pos) == farm_grid_manager.PLOT_OCCUPIED, "占用后 plot_state 为 occupied")
	_assert(farm_grid_manager.can_water_tile(tile_pos), "占用地块可浇水")
	_assert(farm_grid_manager.mark_tile_watered(tile_pos), "占用地块浇水保留合法湿润表现")
	_assert(farm_grid_manager.can_clear_tile(tile_pos), "占用地块可清理")
	_assert(farm_grid_manager.clear_tile(tile_pos), "清理地块成功")
	_assert(not farm_grid_manager.is_tile_occupied(tile_pos), "清理后 occupied=false")
	_assert(farm_grid_manager.get_plot_state(tile_pos) == farm_grid_manager.PLOT_EMPTY, "清理后恢复 empty")
	_assert(not farm_grid_manager.set_tile_occupied(Vector2i(8, 5), true, "locked"), "锁定地块不能占用")


func test_unlock_count_and_row_major_order() -> void:
	farm_grid_manager.initialize_grid()
	var result_count: int = farm_grid_manager.unlock_plots_by_count(14)
	_assert(result_count == 14, "unlock_plots_by_count 返回目标数量")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 14, "解锁后已解锁数量为 14")
	_assert(farm_grid_manager.is_plot_unlocked(Vector2i(5, 5)), "row-major 第 1 格已解锁")
	_assert(farm_grid_manager.is_plot_unlocked(Vector2i(12, 5)), "row-major 第 8 格已解锁")
	_assert(farm_grid_manager.is_plot_unlocked(Vector2i(5, 6)), "row-major 第 9 格已解锁")
	_assert(farm_grid_manager.is_plot_unlocked(Vector2i(10, 6)), "row-major 第 14 格已解锁")
	_assert(not farm_grid_manager.is_plot_unlocked(Vector2i(11, 6)), "row-major 第 15 格仍锁定")
	var capped_count: int = farm_grid_manager.unlock_plots_by_count(999)
	_assert(capped_count == farm_grid_manager.MAX_UNLOCKED_PLOT_COUNT, "解锁数量被限制到最大 80")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == farm_grid_manager.MAX_UNLOCKED_PLOT_COUNT, "最大解锁后数量为 80")
	_assert(not farm_grid_manager.set_plot_unlocked(Vector2i(13, 5), true), "最大可解锁区域外不能直接解锁")


func test_save_export_import() -> void:
	farm_grid_manager.initialize_grid()
	var tile_pos := Vector2i(5, 5)
	farm_grid_manager.set_plot_state(tile_pos, farm_grid_manager.PLOT_DRY_SOIL)
	farm_grid_manager.set_tile_occupied(Vector2i(6, 5), true, "crop:6,5")
	farm_grid_manager.unlock_plots_by_count(20)
	var data: Dictionary = farm_grid_manager.export_save_data()
	_assert(data["schema_version"] == 1, "导出包含 schema_version")
	_assert(data["map_width"] == 30 and data["map_height"] == 20, "导出包含地图尺寸")
	_assert(data["tile_size"] == 16, "导出包含 tile_size")
	_assert(data["farm_origin"]["x"] == 5 and data["farm_origin"]["y"] == 5, "导出 farm_origin 使用 JSON 字典")
	_assert(data["tiles"].size() == 600, "导出包含 600 个 tile")
	_assert(typeof(data["tiles"]["5,5"].get("grid_pos", null)) == TYPE_NIL, "导出 tile 不包含原始 Vector2i")
	farm_grid_manager.initialize_grid()
	farm_grid_manager.import_save_data(data)
	_assert(farm_grid_manager.get_plot_state(tile_pos) == farm_grid_manager.PLOT_DRY_SOIL, "导入恢复地块状态")
	_assert(farm_grid_manager.is_tile_occupied(Vector2i(6, 5)), "导入恢复占用状态")
	_assert(farm_grid_manager.get_tile_data(Vector2i(6, 5))["crop_tile_ref"] == "crop:6,5", "导入恢复 crop_tile_ref")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 20, "导入恢复解锁数量")
	farm_grid_manager.import_save_data({})
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 12, "空数据导入回退默认田园")
	var partial_data := {
		"unlocked_plot_count": 1,
		"tiles": {
			"5,5": {"plot_state": farm_grid_manager.PLOT_WET_SOIL, "unlocked": true},
			"bad": {"plot_state": farm_grid_manager.PLOT_DRY_SOIL},
			"99,99": {"plot_state": farm_grid_manager.PLOT_DRY_SOIL},
		}
	}
	farm_grid_manager.import_save_data(partial_data)
	var restored_tile: Dictionary = farm_grid_manager.get_tile_data(Vector2i(5, 5))
	_assert(restored_tile["plot_state"] == farm_grid_manager.PLOT_WET_SOIL, "导入缺失字段时保留提供状态")
	_assert(restored_tile["terrain_type"] == farm_grid_manager.TERRAIN_FARM_PLOT, "导入缺失字段补默认 terrain_type")


func test_event_bus_signals() -> void:
	_reset_signal_counters()
	farm_grid_manager.initialize_grid()
	_assert(_grid_initialized_count >= 1 and _last_initialized_size == Vector2i(30, 20), "初始化发射 farm_grid_initialized")
	_assert(_grid_changed_count >= 1, "初始化发射 farm_grid_changed")
	farm_grid_manager.set_hovered_tile(Vector2i(5, 5))
	_assert(_tile_hovered_count >= 1 and _last_hovered_tile == Vector2i(5, 5), "设置悬停发射 farm_tile_hovered")
	farm_grid_manager.set_selected_tile(Vector2i(5, 5))
	_assert(_tile_selected_count >= 1 and _last_selected_tile == Vector2i(5, 5), "设置选中发射 farm_tile_selected")
	farm_grid_manager.set_plot_state(Vector2i(5, 5), farm_grid_manager.PLOT_DRY_SOIL)
	_assert(_tile_state_changed_count >= 1 and _last_state_change["new_state"] == farm_grid_manager.PLOT_DRY_SOIL, "状态变化发射 farm_tile_state_changed")
	farm_grid_manager.set_plot_unlocked(Vector2i(8, 5), true)
	_assert(_tile_unlocked_count >= 1 and _last_unlocked_tile == Vector2i(8, 5), "解锁发射 farm_tile_unlocked")
	farm_grid_manager.set_tile_occupied(Vector2i(5, 5), true, "crop:5,5")
	_assert(_tile_occupied_changed_count >= 1 and _last_occupied_change["occupied"] == true, "占用变化发射 farm_tile_occupied_changed")
	_assert(_grid_changed_count >= 4, "状态修改累计发射 farm_grid_changed")


func _connect_signals_once() -> void:
	if not EventBus.farm_grid_initialized.is_connected(_on_farm_grid_initialized):
		EventBus.farm_grid_initialized.connect(_on_farm_grid_initialized)
	if not EventBus.farm_grid_changed.is_connected(_on_farm_grid_changed):
		EventBus.farm_grid_changed.connect(_on_farm_grid_changed)
	if not EventBus.farm_tile_hovered.is_connected(_on_farm_tile_hovered):
		EventBus.farm_tile_hovered.connect(_on_farm_tile_hovered)
	if not EventBus.farm_tile_selected.is_connected(_on_farm_tile_selected):
		EventBus.farm_tile_selected.connect(_on_farm_tile_selected)
	if not EventBus.farm_tile_state_changed.is_connected(_on_farm_tile_state_changed):
		EventBus.farm_tile_state_changed.connect(_on_farm_tile_state_changed)
	if not EventBus.farm_tile_unlocked.is_connected(_on_farm_tile_unlocked):
		EventBus.farm_tile_unlocked.connect(_on_farm_tile_unlocked)
	if not EventBus.farm_tile_occupied_changed.is_connected(_on_farm_tile_occupied_changed):
		EventBus.farm_tile_occupied_changed.connect(_on_farm_tile_occupied_changed)


func _reset_signal_counters() -> void:
	_grid_initialized_count = 0
	_grid_changed_count = 0
	_tile_hovered_count = 0
	_tile_selected_count = 0
	_tile_state_changed_count = 0
	_tile_unlocked_count = 0
	_tile_occupied_changed_count = 0
	_last_initialized_size = Vector2i.ZERO
	_last_hovered_tile = Vector2i(-1, -1)
	_last_selected_tile = Vector2i(-1, -1)
	_last_state_change = {}
	_last_unlocked_tile = Vector2i(-1, -1)
	_last_occupied_change = {}


func _on_farm_grid_initialized(width: int, height: int) -> void:
	_grid_initialized_count += 1
	_last_initialized_size = Vector2i(width, height)


func _on_farm_grid_changed() -> void:
	_grid_changed_count += 1


func _on_farm_tile_hovered(tile_pos: Vector2i, _tile_data: Dictionary) -> void:
	_tile_hovered_count += 1
	_last_hovered_tile = tile_pos


func _on_farm_tile_selected(tile_pos: Vector2i, _tile_data: Dictionary) -> void:
	_tile_selected_count += 1
	_last_selected_tile = tile_pos


func _on_farm_tile_state_changed(tile_pos: Vector2i, old_state: String, new_state: String) -> void:
	_tile_state_changed_count += 1
	_last_state_change = {
		"tile_pos": tile_pos,
		"old_state": old_state,
		"new_state": new_state,
	}


func _on_farm_tile_unlocked(tile_pos: Vector2i) -> void:
	_tile_unlocked_count += 1
	_last_unlocked_tile = tile_pos


func _on_farm_tile_occupied_changed(tile_pos: Vector2i, occupied: bool) -> void:
	_tile_occupied_changed_count += 1
	_last_occupied_change = {
		"tile_pos": tile_pos,
		"occupied": occupied,
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
