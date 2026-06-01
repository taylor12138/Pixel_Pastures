extends Node
## FarmGridManager — 田园网格与地块状态管理器
## 管理 30×20 地图、20×12 可耕区域、地块状态、坐标转换与存档数据。

const TILE_SIZE: int = 16
const MAP_WIDTH: int = 30
const MAP_HEIGHT: int = 20
const FARM_ORIGIN: Vector2i = Vector2i(5, 5)
const FARM_AREA_WIDTH: int = 20
const FARM_AREA_HEIGHT: int = 12
const INITIAL_UNLOCKED_WIDTH: int = 3
const INITIAL_UNLOCKED_HEIGHT: int = 4
const MAX_UNLOCKED_FARM_WIDTH: int = 8
const MAX_UNLOCKED_FARM_HEIGHT: int = 10
const DEFAULT_UNLOCKED_PLOT_COUNT: int = INITIAL_UNLOCKED_WIDTH * INITIAL_UNLOCKED_HEIGHT
const MAX_UNLOCKED_PLOT_COUNT: int = MAX_UNLOCKED_FARM_WIDTH * MAX_UNLOCKED_FARM_HEIGHT

const TERRAIN_GRASS := "grass"
const TERRAIN_PATH := "path"
const TERRAIN_FARM_PLOT := "farm_plot"
const TERRAIN_BLOCKED := "blocked"

const PLOT_UNAVAILABLE := "unavailable"
const PLOT_LOCKED := "locked"
const PLOT_EMPTY := "empty"
const PLOT_DRY_SOIL := "dry_soil"
const PLOT_WET_SOIL := "wet_soil"
const PLOT_OCCUPIED := "occupied"

const VALID_PLOT_STATES: Array[String] = [
	PLOT_UNAVAILABLE,
	PLOT_LOCKED,
	PLOT_EMPTY,
	PLOT_DRY_SOIL,
	PLOT_WET_SOIL,
	PLOT_OCCUPIED,
]
const OPERABLE_PLOT_STATES: Array[String] = [
	PLOT_EMPTY,
	PLOT_DRY_SOIL,
	PLOT_WET_SOIL,
	PLOT_OCCUPIED,
]

var tiles: Dictionary = {}
var unlocked_plot_count: int = DEFAULT_UNLOCKED_PLOT_COUNT
var hovered_tile: Vector2i = Vector2i(-1, -1)
var selected_tile: Vector2i = Vector2i(-1, -1)
var debug_mode: bool = true


## 初始化完整田园网格。
func initialize_grid() -> void:
	tiles.clear()
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var tile_pos := Vector2i(x, y)
			tiles[tile_pos_to_key(tile_pos)] = _create_default_tile_data(tile_pos)
	_initialize_default_unlocked_plots()
	_emit_grid_initialized()
	_emit_grid_changed()


## 根据数量刷新已解锁地块。
func initialize_unlocked_plots(plot_count: int = DEFAULT_UNLOCKED_PLOT_COUNT) -> void:
	var target_count: int = clampi(plot_count, 0, MAX_UNLOCKED_PLOT_COUNT)
	unlocked_plot_count = target_count
	var index := 0
	for tile_pos in _get_unlockable_positions():
		var key := tile_pos_to_key(tile_pos)
		var tile_data: Dictionary = tiles.get(key, _create_default_tile_data(tile_pos))
		var unlocked := index < target_count
		tile_data["unlocked"] = unlocked
		tile_data["plot_state"] = PLOT_EMPTY if unlocked else PLOT_LOCKED
		if not unlocked:
			tile_data["occupied"] = false
			tile_data["crop_tile_ref"] = ""
		tiles[key] = tile_data
		index += 1


## 重置为新游戏默认地块状态。
func reset_to_default() -> void:
	initialize_grid()


## 判断网格坐标是否在地图范围内。
func is_in_map_bounds(tile_pos: Vector2i) -> bool:
	return tile_pos.x >= 0 and tile_pos.x < MAP_WIDTH and tile_pos.y >= 0 and tile_pos.y < MAP_HEIGHT


## 判断网格坐标是否在 20×12 可耕区域内。
func is_in_farm_area(tile_pos: Vector2i) -> bool:
	return tile_pos.x >= FARM_ORIGIN.x and tile_pos.x < FARM_ORIGIN.x + FARM_AREA_WIDTH and tile_pos.y >= FARM_ORIGIN.y and tile_pos.y < FARM_ORIGIN.y + FARM_AREA_HEIGHT


## 判断网格坐标是否在最大 8×10 可解锁区域内。
func is_in_unlockable_plot_area(tile_pos: Vector2i) -> bool:
	return tile_pos.x >= FARM_ORIGIN.x and tile_pos.x < FARM_ORIGIN.x + MAX_UNLOCKED_FARM_WIDTH and tile_pos.y >= FARM_ORIGIN.y and tile_pos.y < FARM_ORIGIN.y + MAX_UNLOCKED_FARM_HEIGHT


## 获取地块数据；不存在返回空 Dictionary。
func get_tile_data(tile_pos: Vector2i) -> Dictionary:
	if not is_in_map_bounds(tile_pos):
		return {}
	return tiles.get(tile_pos_to_key(tile_pos), {}).duplicate(true)


## 获取地形类型。
func get_terrain_type(tile_pos: Vector2i) -> String:
	var tile_data := get_tile_data(tile_pos)
	return str(tile_data.get("terrain_type", ""))


## 获取地块状态。
func get_plot_state(tile_pos: Vector2i) -> String:
	var tile_data := get_tile_data(tile_pos)
	return str(tile_data.get("plot_state", ""))


## 判断地块是否已解锁。
func is_plot_unlocked(tile_pos: Vector2i) -> bool:
	var tile_data := get_tile_data(tile_pos)
	return bool(tile_data.get("unlocked", false))


## 判断是否可种植。
func can_plant_on_tile(tile_pos: Vector2i) -> bool:
	var tile_data := get_tile_data(tile_pos)
	if tile_data.is_empty():
		return false
	if tile_data.get("terrain_type", "") != TERRAIN_FARM_PLOT:
		return false
	if not bool(tile_data.get("unlocked", false)):
		return false
	if bool(tile_data.get("occupied", false)):
		return false
	return str(tile_data.get("plot_state", "")) in [PLOT_EMPTY, PLOT_DRY_SOIL, PLOT_WET_SOIL]


## 判断是否可浇水。
func can_water_tile(tile_pos: Vector2i) -> bool:
	var tile_data := get_tile_data(tile_pos)
	if tile_data.is_empty():
		return false
	if tile_data.get("terrain_type", "") != TERRAIN_FARM_PLOT:
		return false
	if not bool(tile_data.get("unlocked", false)):
		return false
	var state := str(tile_data.get("plot_state", ""))
	if state == PLOT_WET_SOIL:
		return false
	return state == PLOT_DRY_SOIL or bool(tile_data.get("occupied", false))


## 判断是否可清理。
func can_clear_tile(tile_pos: Vector2i) -> bool:
	var tile_data := get_tile_data(tile_pos)
	if tile_data.is_empty():
		return false
	if tile_data.get("terrain_type", "") != TERRAIN_FARM_PLOT:
		return false
	if not bool(tile_data.get("unlocked", false)):
		return false
	return bool(tile_data.get("occupied", false)) or str(tile_data.get("plot_state", "")) in [PLOT_DRY_SOIL, PLOT_WET_SOIL, PLOT_OCCUPIED]


## 获取全部已解锁可耕地坐标。
func get_unlocked_plot_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile_pos in _get_unlockable_positions():
		if is_plot_unlocked(tile_pos):
			result.append(tile_pos)
	return result


## 获取全部可种植坐标。
func get_plantable_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile_pos in _get_unlockable_positions():
		if can_plant_on_tile(tile_pos):
			result.append(tile_pos)
	return result


## 设置地块状态。
func set_plot_state(tile_pos: Vector2i, new_state: String) -> bool:
	if not _is_valid_plot_state(new_state):
		push_warning("无效地块状态: %s" % new_state)
		return false
	if not is_in_map_bounds(tile_pos):
		push_warning("设置地块状态失败，坐标越界: %s" % tile_pos)
		return false
	var key := tile_pos_to_key(tile_pos)
	var tile_data: Dictionary = tiles.get(key, {})
	if tile_data.is_empty():
		push_warning("设置地块状态失败，地块不存在: %s" % tile_pos)
		return false
	if new_state in OPERABLE_PLOT_STATES and tile_data.get("terrain_type", "") != TERRAIN_FARM_PLOT:
		push_warning("非可耕地不能设置为可操作状态: %s" % tile_pos)
		return false
	if not bool(tile_data.get("unlocked", false)) and new_state in [PLOT_DRY_SOIL, PLOT_WET_SOIL, PLOT_OCCUPIED]:
		push_warning("未解锁地块不能设置为可操作状态: %s" % tile_pos)
		return false
	var old_state := str(tile_data.get("plot_state", PLOT_UNAVAILABLE))
	if old_state == new_state:
		return true
	tile_data["plot_state"] = new_state
	if new_state == PLOT_OCCUPIED:
		tile_data["occupied"] = true
	elif old_state == PLOT_OCCUPIED and new_state != PLOT_OCCUPIED:
		tile_data["occupied"] = false
		tile_data["crop_tile_ref"] = ""
	tile_data["last_updated_at"] = Time.get_unix_time_from_system()
	tiles[key] = tile_data
	_emit_tile_state_changed(tile_pos, old_state, new_state)
	_emit_grid_changed()
	return true


## 设置地块是否解锁。
func set_plot_unlocked(tile_pos: Vector2i, unlocked: bool) -> bool:
	if not is_in_unlockable_plot_area(tile_pos):
		push_warning("设置地块解锁失败，坐标不在最大可解锁区域: %s" % tile_pos)
		return false
	var key := tile_pos_to_key(tile_pos)
	var tile_data: Dictionary = tiles.get(key, {})
	if tile_data.is_empty():
		push_warning("设置地块解锁失败，地块不存在: %s" % tile_pos)
		return false
	var was_unlocked := bool(tile_data.get("unlocked", false))
	if was_unlocked == unlocked:
		return true
	var old_state := str(tile_data.get("plot_state", PLOT_LOCKED))
	tile_data["unlocked"] = unlocked
	tile_data["plot_state"] = PLOT_EMPTY if unlocked else PLOT_LOCKED
	if not unlocked:
		tile_data["occupied"] = false
		tile_data["crop_tile_ref"] = ""
	tile_data["last_updated_at"] = Time.get_unix_time_from_system()
	tiles[key] = tile_data
	if unlocked:
		_emit_tile_unlocked(tile_pos)
	_emit_tile_state_changed(tile_pos, old_state, str(tile_data["plot_state"]))
	_emit_grid_changed()
	return true


## 标记地块被占用。
func set_tile_occupied(tile_pos: Vector2i, occupied: bool, crop_tile_ref: String = "") -> bool:
	if not is_in_map_bounds(tile_pos):
		push_warning("设置地块占用失败，坐标越界: %s" % tile_pos)
		return false
	var key := tile_pos_to_key(tile_pos)
	var tile_data: Dictionary = tiles.get(key, {})
	if tile_data.is_empty() or tile_data.get("terrain_type", "") != TERRAIN_FARM_PLOT or not bool(tile_data.get("unlocked", false)):
		push_warning("设置地块占用失败，地块不可用: %s" % tile_pos)
		return false
	var old_state := str(tile_data.get("plot_state", PLOT_EMPTY))
	var old_occupied := bool(tile_data.get("occupied", false))
	tile_data["occupied"] = occupied
	tile_data["crop_tile_ref"] = crop_tile_ref if occupied else ""
	tile_data["plot_state"] = PLOT_OCCUPIED if occupied else PLOT_EMPTY
	tile_data["last_updated_at"] = Time.get_unix_time_from_system()
	tiles[key] = tile_data
	if old_state != tile_data["plot_state"]:
		_emit_tile_state_changed(tile_pos, old_state, str(tile_data["plot_state"]))
	if old_occupied != occupied:
		_emit_tile_occupied_changed(tile_pos, occupied)
	_emit_grid_changed()
	return true


## 将地块恢复为空闲。
func clear_tile(tile_pos: Vector2i) -> bool:
	if not is_in_map_bounds(tile_pos):
		push_warning("清理地块失败，坐标越界: %s" % tile_pos)
		return false
	var key := tile_pos_to_key(tile_pos)
	var tile_data: Dictionary = tiles.get(key, {})
	if tile_data.is_empty() or tile_data.get("terrain_type", "") != TERRAIN_FARM_PLOT or not bool(tile_data.get("unlocked", false)):
		push_warning("清理地块失败，地块不可用: %s" % tile_pos)
		return false
	var old_state := str(tile_data.get("plot_state", PLOT_EMPTY))
	var old_occupied := bool(tile_data.get("occupied", false))
	tile_data["plot_state"] = PLOT_EMPTY
	tile_data["occupied"] = false
	tile_data["crop_tile_ref"] = ""
	tile_data["last_updated_at"] = Time.get_unix_time_from_system()
	tiles[key] = tile_data
	if old_state != PLOT_EMPTY:
		_emit_tile_state_changed(tile_pos, old_state, PLOT_EMPTY)
	if old_occupied:
		_emit_tile_occupied_changed(tile_pos, false)
	_emit_grid_changed()
	return true


## 将干土或合法占用地块标记为湿润。
func mark_tile_watered(tile_pos: Vector2i) -> bool:
	if not can_water_tile(tile_pos):
		push_warning("浇水失败，地块不可浇水: %s" % tile_pos)
		return false
	if is_tile_occupied(tile_pos):
		_emit_grid_changed()
		return true
	return set_plot_state(tile_pos, PLOT_WET_SOIL)


## 按数量扩展已解锁地块。
func unlock_plots_by_count(target_count: int) -> int:
	var clamped_count: int = clampi(target_count, 0, MAX_UNLOCKED_PLOT_COUNT)
	var unlocked_total := 0
	for tile_pos in _get_unlockable_positions():
		var should_unlock := unlocked_total < clamped_count
		if should_unlock:
			set_plot_unlocked(tile_pos, true)
		else:
			set_plot_unlocked(tile_pos, false)
		unlocked_total += 1
	unlocked_plot_count = clamped_count
	_emit_grid_changed()
	return clamped_count


## 判断地块是否被占用。
func is_tile_occupied(tile_pos: Vector2i) -> bool:
	var tile_data := get_tile_data(tile_pos)
	return bool(tile_data.get("occupied", false))


## 网格坐标转世界坐标，返回 tile 左上角。
func grid_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)


## 网格坐标转世界中心点。
func grid_to_world_center(tile_pos: Vector2i) -> Vector2:
	return grid_to_world(tile_pos) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


## 世界坐标转网格坐标。
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(TILE_SIZE)), floori(world_pos.y / float(TILE_SIZE)))


## 屏幕或鼠标坐标转网格坐标。
func screen_to_grid(screen_pos: Vector2, camera: Camera2D = null) -> Vector2i:
	var world_pos := screen_pos
	if camera != null:
		world_pos = camera.get_screen_center_position() + (screen_pos - get_viewport().get_visible_rect().size * 0.5) / camera.zoom
	return world_to_grid(world_pos)


## 坐标转 JSON key。
func tile_pos_to_key(tile_pos: Vector2i) -> String:
	return "%d,%d" % [tile_pos.x, tile_pos.y]


## JSON key 转坐标。
func key_to_tile_pos(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_warning("非法地块 key: %s" % key)
		return Vector2i(-999999, -999999)
	return Vector2i(int(parts[0]), int(parts[1]))


## 导出可 JSON 序列化的存档数据。
func export_save_data() -> Dictionary:
	var save_tiles := {}
	for key in tiles.keys():
		var tile_data: Dictionary = tiles[key]
		save_tiles[key] = {
			"terrain_type": str(tile_data.get("terrain_type", TERRAIN_GRASS)),
			"plot_state": str(tile_data.get("plot_state", PLOT_UNAVAILABLE)),
			"unlocked": bool(tile_data.get("unlocked", false)),
			"occupied": bool(tile_data.get("occupied", false)),
			"crop_tile_ref": str(tile_data.get("crop_tile_ref", "")),
		}
	return {
		"schema_version": 1,
		"map_width": MAP_WIDTH,
		"map_height": MAP_HEIGHT,
		"tile_size": TILE_SIZE,
		"farm_origin": {"x": FARM_ORIGIN.x, "y": FARM_ORIGIN.y},
		"unlocked_plot_count": unlocked_plot_count,
		"tiles": save_tiles,
	}


## 从存档恢复地块状态。
func import_save_data(data: Dictionary) -> void:
	if data.is_empty() or not data.has("tiles"):
		reset_to_default()
		return
	initialize_grid()
	unlocked_plot_count = int(data.get("unlocked_plot_count", DEFAULT_UNLOCKED_PLOT_COUNT))
	var imported_tiles: Dictionary = data.get("tiles", {})
	for key in imported_tiles.keys():
		var tile_pos := key_to_tile_pos(str(key))
		if not is_in_map_bounds(tile_pos):
			push_warning("导入跳过越界或非法地块: %s" % key)
			continue
		var default_data := _create_default_tile_data(tile_pos)
		var imported_data: Dictionary = imported_tiles[key]
		var merged_data := default_data.duplicate(true)
		merged_data["terrain_type"] = str(imported_data.get("terrain_type", default_data["terrain_type"]))
		merged_data["plot_state"] = str(imported_data.get("plot_state", default_data["plot_state"]))
		merged_data["unlocked"] = bool(imported_data.get("unlocked", default_data["unlocked"]))
		merged_data["occupied"] = bool(imported_data.get("occupied", default_data["occupied"]))
		merged_data["crop_tile_ref"] = str(imported_data.get("crop_tile_ref", default_data["crop_tile_ref"]))
		merged_data["last_updated_at"] = int(imported_data.get("last_updated_at", 0))
		tiles[tile_pos_to_key(tile_pos)] = merged_data
	_emit_grid_changed()


## 设置悬停地块并发射事件。
func set_hovered_tile(tile_pos: Vector2i) -> void:
	if hovered_tile == tile_pos:
		return
	hovered_tile = tile_pos
	if is_in_map_bounds(tile_pos):
		_emit_tile_hovered(tile_pos, get_tile_data(tile_pos))


## 设置选中地块并发射事件。
func set_selected_tile(tile_pos: Vector2i) -> void:
	selected_tile = tile_pos
	if is_in_map_bounds(tile_pos):
		_emit_tile_selected(tile_pos, get_tile_data(tile_pos))


func _create_default_tile_data(tile_pos: Vector2i) -> Dictionary:
	var terrain_type := TERRAIN_GRASS
	var plot_state := PLOT_UNAVAILABLE
	var unlocked := false
	if is_in_farm_area(tile_pos):
		terrain_type = TERRAIN_FARM_PLOT
		if is_in_unlockable_plot_area(tile_pos):
			plot_state = PLOT_LOCKED
		else:
			plot_state = PLOT_UNAVAILABLE
	return {
		"grid_pos": tile_pos,
		"terrain_type": terrain_type,
		"plot_state": plot_state,
		"unlocked": unlocked,
		"occupied": false,
		"crop_tile_ref": "",
		"last_updated_at": 0,
	}


func _initialize_default_unlocked_plots() -> void:
	unlocked_plot_count = DEFAULT_UNLOCKED_PLOT_COUNT
	for y_offset in range(INITIAL_UNLOCKED_HEIGHT):
		for x_offset in range(INITIAL_UNLOCKED_WIDTH):
			var tile_pos := FARM_ORIGIN + Vector2i(x_offset, y_offset)
			var key := tile_pos_to_key(tile_pos)
			var tile_data: Dictionary = tiles.get(key, _create_default_tile_data(tile_pos))
			tile_data["unlocked"] = true
			tile_data["plot_state"] = PLOT_EMPTY
			tiles[key] = tile_data


func _get_unlockable_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y_offset in range(MAX_UNLOCKED_FARM_HEIGHT):
		for x_offset in range(MAX_UNLOCKED_FARM_WIDTH):
			result.append(FARM_ORIGIN + Vector2i(x_offset, y_offset))
	return result


func _is_valid_plot_state(state: String) -> bool:
	return state in VALID_PLOT_STATES


func _emit_grid_initialized() -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_grid_initialized.emit(MAP_WIDTH, MAP_HEIGHT)


func _emit_tile_hovered(tile_pos: Vector2i, tile_data: Dictionary) -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_tile_hovered.emit(tile_pos, tile_data)


func _emit_tile_selected(tile_pos: Vector2i, tile_data: Dictionary) -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_tile_selected.emit(tile_pos, tile_data)


func _emit_tile_state_changed(tile_pos: Vector2i, old_state: String, new_state: String) -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_tile_state_changed.emit(tile_pos, old_state, new_state)


func _emit_tile_unlocked(tile_pos: Vector2i) -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_tile_unlocked.emit(tile_pos)


func _emit_tile_occupied_changed(tile_pos: Vector2i, occupied: bool) -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_tile_occupied_changed.emit(tile_pos, occupied)


func _emit_grid_changed() -> void:
	if has_node("/root/EventBus"):
		EventBus.farm_grid_changed.emit()
