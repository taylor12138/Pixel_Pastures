extends Node
## 作物生长管理器 - 管理所有地块的作物状态、生长计时、枯萎判定

# ─── 枚举 ───

enum CropStage {
	SEED = 0,      ## 种子/待浇水
	SPROUT = 1,    ## 发芽
	GROWING = 2,   ## 生长中
	MATURE = 3,    ## 成熟
	WITHERED = 4,  ## 枯萎
}

# ─── 常量 ───

const CHECK_INTERVAL: float = 1.0  ## 生长检查间隔（秒）

# ─── 内部数据 ───

var _crops: Dictionary = {}  ## Vector2i -> crop_data Dictionary
var _check_timer: float = 0.0

# ─── 生命周期 ───

func _ready() -> void:
	_load_from_game_manager()
	print("[CropManager] 初始化完成，已加载 %d 块地作物数据" % _crops.size())


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_update_all_crops()

# ─── 核心操作 ───

## 在指定地块种植作物
func plant_crop(tile_pos: Vector2i, crop_id: String) -> bool:
	if has_crop(tile_pos):
		return false
	var crop_config := DataManager.get_crop(crop_id)
	if crop_config.is_empty():
		return false
	if has_node("/root/LevelManager") and not LevelManager.is_crop_unlocked(crop_id):
		return false
	var seed_id := "seed_" + crop_id
	if not InventoryManager.has_item(seed_id):
		return false

	if InventoryManager.remove_item(seed_id, 1) != 1:
		return false

	var crop_data := {
		"crop_id": crop_id,
		"stage": CropStage.SEED,
		"watered": false,
		"water_timestamp": 0.0,
		"water_count": 0,
		"planted_timestamp": Time.get_unix_time_from_system(),
		"mature_timestamp": 0.0,
	}
	_crops[tile_pos] = crop_data
	_sync_to_game_manager()
	EventBus.crop_planted.emit(tile_pos, crop_id)
	if has_node("/root/LevelManager"):
		LevelManager.grant_xp("plant", {"crop_id": crop_id})
	return true


## 对指定地块浇水
func water_crop(tile_pos: Vector2i) -> bool:
	if not has_crop(tile_pos):
		return false
	var crop_data: Dictionary = _crops[tile_pos]
	var stage: int = crop_data["stage"]
	if stage == CropStage.MATURE or stage == CropStage.WITHERED:
		return false
	if crop_data["watered"]:
		return false

	crop_data["watered"] = true
	crop_data["water_timestamp"] = Time.get_unix_time_from_system()
	crop_data["water_count"] += 1
	GameManager.stats["total_water_count"] += 1
	_sync_to_game_manager()
	EventBus.crop_watered.emit(tile_pos, crop_data["crop_id"])
	return true


## 收获指定地块的成熟作物
func harvest_crop(tile_pos: Vector2i) -> String:
	if not has_crop(tile_pos):
		return ""
	var crop_data: Dictionary = _crops[tile_pos]
	if crop_data["stage"] != CropStage.MATURE:
		return ""

	var crop_id: String = crop_data["crop_id"]
	var added := InventoryManager.add_item("harvest_" + crop_id, 1)
	if added != 1:
		return ""
	if has_node("/root/LevelManager"):
		LevelManager.grant_xp("harvest", {"crop_id": crop_id})
	else:
		GameManager.add_xp(10, "harvest")
	GameManager.stats["total_harvests"] += 1
	_crops.erase(tile_pos)
	_sync_to_game_manager()
	EventBus.crop_harvested.emit(tile_pos, crop_id, 1)
	return crop_id


## 清除指定地块
func clear_crop(tile_pos: Vector2i) -> bool:
	if not has_crop(tile_pos):
		return false
	_crops.erase(tile_pos)
	_sync_to_game_manager()
	EventBus.crop_cleared.emit(tile_pos)
	return true

# ─── 查询接口 ───

## 获取指定地块的作物数据
func get_crop_data(tile_pos: Vector2i) -> Dictionary:
	if _crops.has(tile_pos):
		return _crops[tile_pos].duplicate(true)
	return {}


## 指定地块是否有作物
func has_crop(tile_pos: Vector2i) -> bool:
	return _crops.has(tile_pos)


## 指定地块的作物是否可收获
func is_harvestable(tile_pos: Vector2i) -> bool:
	if not has_crop(tile_pos):
		return false
	return _crops[tile_pos]["stage"] == CropStage.MATURE


## 指定地块的作物是否需要浇水
func needs_water(tile_pos: Vector2i) -> bool:
	if not has_crop(tile_pos):
		return false
	var crop_data: Dictionary = _crops[tile_pos]
	var stage: int = crop_data["stage"]
	if stage == CropStage.MATURE or stage == CropStage.WITHERED:
		return false
	return not crop_data["watered"]


## 获取指定地块作物的生长进度（0.0 ~ 1.0）
func get_growth_progress(tile_pos: Vector2i) -> float:
	if not has_crop(tile_pos):
		return 0.0
	var crop_data: Dictionary = _crops[tile_pos]
	var stage: int = crop_data["stage"]
	if stage == CropStage.MATURE or stage == CropStage.WITHERED:
		return 1.0
	if not crop_data["watered"]:
		return 0.0
	var crop_config := DataManager.get_crop(crop_data["crop_id"])
	if crop_config.is_empty():
		return 0.0
	var growth_time: float = float(crop_config["growth_time_per_stage"])
	var elapsed: float = Time.get_unix_time_from_system() - crop_data["water_timestamp"]
	return clampf(elapsed / growth_time, 0.0, 1.0)


## 获取所有地块数据
func get_all_crops() -> Dictionary:
	return _crops.duplicate(true)


## 获取所有成熟作物的地块列表
func get_mature_crops() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in _crops:
		if _crops[pos]["stage"] == CropStage.MATURE:
			result.append(pos)
	return result


## 获取所有需要浇水的地块列表
func get_crops_needing_water() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in _crops:
		var crop_data: Dictionary = _crops[pos]
		var stage: int = crop_data["stage"]
		if stage != CropStage.MATURE and stage != CropStage.WITHERED and not crop_data["watered"]:
			result.append(pos)
	return result

# ─── 批量操作 ───

## 离线补偿：根据离线时长批量推进所有作物状态
func process_offline_time(last_online_timestamp: float) -> void:
	var current_time := Time.get_unix_time_from_system()
	for pos in _crops:
		var crop_data: Dictionary = _crops[pos]
		var stage: int = crop_data["stage"]

		# 已浇水的生长中作物：尝试推进一个阶段
		if crop_data["watered"] and stage in [CropStage.SEED, CropStage.SPROUT, CropStage.GROWING]:
			var crop_config := DataManager.get_crop(crop_data["crop_id"])
			if crop_config.is_empty():
				continue
			var growth_time: float = float(crop_config["growth_time_per_stage"])
			var effective_start: float = max(float(last_online_timestamp), float(crop_data["water_timestamp"]))
			var elapsed: float = current_time - effective_start

			if elapsed >= growth_time:
				crop_data["stage"] += 1
				crop_data["watered"] = false
				if crop_data["stage"] == CropStage.MATURE:
					crop_data["mature_timestamp"] = effective_start + growth_time
					EventBus.crop_matured.emit(pos, crop_data["crop_id"])
				else:
					# 进入下一阶段，但离线无法浇水，重置 watered
					EventBus.crop_grown.emit(pos, crop_data["crop_id"], crop_data["stage"])

		# 成熟作物：枯萎判定
		if crop_data["stage"] == CropStage.MATURE:
			_check_wither_single(pos, crop_data, current_time)

	_sync_to_game_manager()


## 零点检查：将所有成熟超期作物标记为枯萎
func check_wither_all() -> void:
	var current_time := Time.get_unix_time_from_system()
	for pos in _crops:
		var crop_data: Dictionary = _crops[pos]
		if crop_data["stage"] == CropStage.MATURE:
			_check_wither_single(pos, crop_data, current_time)
	_sync_to_game_manager()

# ─── 存档集成 ───

## 导出所有作物数据
func export_save_data() -> Dictionary:
	var tiles: Dictionary = {}
	for pos in _crops:
		var key := "%d,%d" % [pos.x, pos.y]
		tiles[key] = _crops[pos].duplicate(true)
	return {"tiles": tiles}


## 导入作物数据
func import_save_data(data: Dictionary) -> void:
	_crops.clear()
	var source: Dictionary = {}
	if data.get("tiles", data) is Dictionary:
		source = data.get("tiles", data)
	for key in source:
		var key_string := str(key)
		var parts := key_string.split(",")
		if parts.size() != 2 or not source[key] is Dictionary:
			continue
		var crop_data: Dictionary = source[key].duplicate(true)
		var crop_id := str(crop_data.get("crop_id", ""))
		if crop_id == "" or DataManager.get_crop(crop_id).is_empty():
			continue
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		_crops[pos] = _normalize_crop_data(crop_data)
	_sync_to_game_manager()

# ─── 调试接口 ───

## [调试] 手动推进指定地块的时间
func debug_advance_time(tile_pos: Vector2i, seconds: float) -> void:
	if not OS.is_debug_build():
		return
	if not has_crop(tile_pos):
		return
	var crop_data: Dictionary = _crops[tile_pos]
	if crop_data["watered"]:
		crop_data["water_timestamp"] -= seconds
	if crop_data["mature_timestamp"] > 0.0:
		crop_data["mature_timestamp"] -= seconds
	# 立即触发一次检查
	_update_single_crop(tile_pos, crop_data)
	_sync_to_game_manager()


## [调试] 强制触发枯萎检查
func debug_force_wither_check() -> void:
	if not OS.is_debug_build():
		return
	check_wither_all()


## [调试] 打印所有地块状态
func debug_print_all() -> void:
	if not OS.is_debug_build():
		return
	print("=== CropManager 地块状态 ===")
	for pos in _crops:
		var d: Dictionary = _crops[pos]
		var stage_name := _stage_to_string(d["stage"])
		print("  [%d,%d] %s | 阶段=%s | 已浇水=%s | 浇水次数=%d" % [
			pos.x, pos.y, d["crop_id"], stage_name,
			str(d["watered"]), d["water_count"]
		])
	print("=== 共 %d 块地 ===" % _crops.size())

func _normalize_crop_data(crop_data: Dictionary) -> Dictionary:
	return {
		"crop_id": str(crop_data.get("crop_id", "")),
		"stage": clampi(int(crop_data.get("stage", CropStage.SEED)), CropStage.SEED, CropStage.WITHERED),
		"watered": bool(crop_data.get("watered", false)),
		"water_timestamp": float(crop_data.get("water_timestamp", 0.0)),
		"water_count": maxi(int(crop_data.get("water_count", 0)), 0),
		"planted_timestamp": float(crop_data.get("planted_timestamp", Time.get_unix_time_from_system())),
		"mature_timestamp": float(crop_data.get("mature_timestamp", 0.0)),
	}


# ─── 内部方法 ───

func _update_all_crops() -> void:
	var current_time := Time.get_unix_time_from_system()
	for pos in _crops:
		var crop_data: Dictionary = _crops[pos]
		_update_single_crop(pos, crop_data, current_time)
	_sync_to_game_manager()


func _update_single_crop(pos: Vector2i, crop_data: Dictionary, current_time: float = 0.0) -> void:
	if current_time == 0.0:
		current_time = Time.get_unix_time_from_system()

	var stage: int = crop_data["stage"]

	# 生长推进
	if crop_data["watered"] and stage in [CropStage.SEED, CropStage.SPROUT, CropStage.GROWING]:
		var crop_config := DataManager.get_crop(crop_data["crop_id"])
		if crop_config.is_empty():
			return
		var growth_time: float = float(crop_config["growth_time_per_stage"])
		var elapsed: float = current_time - crop_data["water_timestamp"]

		if elapsed >= growth_time:
			crop_data["stage"] += 1
			crop_data["watered"] = false

			if crop_data["stage"] == CropStage.MATURE:
				crop_data["mature_timestamp"] = current_time
				EventBus.crop_matured.emit(pos, crop_data["crop_id"])
			else:
				EventBus.crop_grown.emit(pos, crop_data["crop_id"], crop_data["stage"])

	# 枯萎判定
	elif stage == CropStage.MATURE:
		_check_wither_single(pos, crop_data, current_time)


func _check_wither_single(pos: Vector2i, crop_data: Dictionary, current_time: float) -> void:
	if crop_data["stage"] != CropStage.MATURE:
		return
	var mature_date := _timestamp_to_date(crop_data["mature_timestamp"])
	var current_date := _get_current_date()
	if _is_different_day(current_date, mature_date):
		crop_data["stage"] = CropStage.WITHERED
		EventBus.crop_withered.emit(pos, crop_data["crop_id"])


func _get_current_date() -> Dictionary:
	return _timestamp_to_date(Time.get_unix_time_from_system())


func _sync_to_game_manager() -> void:
	var save_data: Dictionary = {}
	for pos in _crops:
		var key := "%d,%d" % [pos.x, pos.y]
		save_data[key] = _crops[pos].duplicate(true)
	GameManager.farm_data = save_data


func _load_from_game_manager() -> void:
	_crops.clear()
	for key in GameManager.farm_data:
		var parts := (key as String).split(",")
		if parts.size() == 2:
			var pos := Vector2i(int(parts[0]), int(parts[1]))
			_crops[pos] = GameManager.farm_data[key].duplicate(true)


func _timestamp_to_date(timestamp: float) -> Dictionary:
	var datetime := Time.get_datetime_dict_from_unix_time(int(timestamp))
	return {"year": datetime["year"], "month": datetime["month"], "day": datetime["day"]}


func _is_different_day(date_a: Dictionary, date_b: Dictionary) -> bool:
	return date_a["year"] != date_b["year"] \
		or date_a["month"] != date_b["month"] \
		or date_a["day"] != date_b["day"]


func _stage_to_string(stage: int) -> String:
	match stage:
		CropStage.SEED: return "SEED"
		CropStage.SPROUT: return "SPROUT"
		CropStage.GROWING: return "GROWING"
		CropStage.MATURE: return "MATURE"
		CropStage.WITHERED: return "WITHERED"
		_: return "UNKNOWN"
