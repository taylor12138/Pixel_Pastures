extends Node
## LevelManager — 等级、经验与内容解锁业务入口
## GameManager 保存 XP/Level 数值，本管理器负责规则、信号与查询。

const ERR_INVALID_XP_AMOUNT := "INVALID_XP_AMOUNT"
const ERR_INVALID_SOURCE := "INVALID_SOURCE"
const ERR_INVALID_DATA := "INVALID_DATA"

const XP_SOURCE_PLANT := "plant"
const XP_SOURCE_HARVEST := "harvest"
const XP_SOURCE_SELL := "sell"
const XP_SOURCE_STEAL := "steal"
const XP_SOURCE_MANUAL := "manual"


func _ready() -> void:
	print("[LevelManager] 初始化完成")


# ─── XP 与等级核心 ───

func add_xp(amount: int, source: String = XP_SOURCE_MANUAL) -> Dictionary:
	var xp_before := GameManager.xp
	var level_before := GameManager.level
	var result := _make_xp_result(false, amount, 0, xp_before, xp_before, level_before, level_before, [], _empty_unlocks(), "")

	if amount <= 0:
		result["error_code"] = ERR_INVALID_XP_AMOUNT
		return result
	if source.strip_edges() == "":
		result["error_code"] = ERR_INVALID_SOURCE
		return result
	if DataManager.get_all_levels().is_empty():
		result["error_code"] = ERR_INVALID_DATA
		push_warning("[LevelManager] Missing level configuration")
		return result

	GameManager.xp += amount
	var levels_gained := check_level_up()
	var merged_unlocks := _merge_unlocks_for_levels(levels_gained)

	GameManager.stats["total_xp_gained"] = int(GameManager.stats.get("total_xp_gained", 0)) + amount
	EventBus.xp_gained.emit(amount, source)
	_emit_unlock_signals(levels_gained, merged_unlocks)

	return _make_xp_result(true, amount, amount, xp_before, GameManager.xp, level_before, GameManager.level, levels_gained, merged_unlocks, "")


func check_level_up() -> Array[int]:
	var levels_gained: Array[int] = []
	var max_level := get_max_level()
	while GameManager.level < max_level:
		var next_level_data := DataManager.get_level_data(GameManager.level + 1)
		if next_level_data.is_empty():
			break
		var required_xp := int(next_level_data.get("xp_required", 999999999))
		if GameManager.xp < required_xp:
			break
		GameManager.level += 1
		levels_gained.append(GameManager.level)
		EventBus.level_up.emit(GameManager.level)
		EventBus.ui_notification.emit("升级了！当前等级: %d" % GameManager.level, "success")
		print("[LevelManager] Level up! Now level %d" % GameManager.level)
	return levels_gained


func recalculate_level() -> Dictionary:
	var previous_level := GameManager.level
	var new_level := 1
	for level_data in DataManager.get_all_levels():
		if not level_data is Dictionary:
			continue
		var level := int(level_data.get("level", 1))
		var xp_required := int(level_data.get("xp_required", 0))
		if GameManager.xp >= xp_required:
			new_level = maxi(new_level, level)
	GameManager.level = clampi(new_level, 1, get_max_level())
	return {
		"previous_level": previous_level,
		"new_level": GameManager.level,
		"corrected": previous_level != GameManager.level,
	}


func set_progress(xp_value: int, level_value: int = -1) -> Dictionary:
	GameManager.xp = maxi(xp_value, 0)
	if level_value > 0:
		GameManager.level = clampi(level_value, 1, get_max_level())
	return recalculate_level()


func get_current_level_data() -> Dictionary:
	return DataManager.get_level_data(GameManager.level)


func get_next_level_data() -> Dictionary:
	if is_max_level():
		return {}
	return DataManager.get_level_data(GameManager.level + 1)


func get_max_level() -> int:
	return DataManager.get_max_level()


func is_max_level() -> bool:
	return GameManager.level >= get_max_level()


func get_xp_progress() -> Dictionary:
	var current_data := get_current_level_data()
	var next_data := get_next_level_data()
	var current_xp_base := int(current_data.get("xp_required", 0))
	var next_xp_required := int(next_data.get("xp_required", current_xp_base))
	var progress_amount := maxi(GameManager.xp - current_xp_base, 0)
	var required_delta := maxi(next_xp_required - current_xp_base, 1)
	var ratio := 1.0 if is_max_level() else clampf(float(progress_amount) / float(required_delta), 0.0, 1.0)
	return {
		"current_xp": GameManager.xp,
		"current_level": GameManager.level,
		"xp_for_current_level": current_xp_base,
		"xp_for_next_level": next_xp_required,
		"progress_amount": progress_amount,
		"progress_ratio": ratio,
		"progress": ratio,
		"is_max_level": is_max_level(),
	}.duplicate(true)


func calculate_xp(source: String, context: Dictionary = {}) -> int:
	match source:
		XP_SOURCE_PLANT:
			return 5
		XP_SOURCE_HARVEST:
			return 10
		XP_SOURCE_SELL:
			return int(floor(float(context.get("total_price", 0)) * 0.5))
		XP_SOURCE_STEAL:
			return 15
		XP_SOURCE_MANUAL:
			return int(context.get("amount", 0))
		_:
			return -1


func grant_xp(source: String, context: Dictionary = {}) -> Dictionary:
	var amount := calculate_xp(source, context)
	if amount <= 0:
		var xp_before := GameManager.xp
		var level_before := GameManager.level
		var error_code := ERR_INVALID_SOURCE if amount < 0 else ERR_INVALID_XP_AMOUNT
		return _make_xp_result(false, amount, 0, xp_before, xp_before, level_before, level_before, [], _empty_unlocks(), error_code)
	return add_xp(amount, source)


# ─── 存档与调试 ───

func export_save_data() -> Dictionary:
	return {
		"xp": GameManager.xp,
		"level": GameManager.level,
		"unlocked_crops": get_unlocked_crops(),
		"unlocked_features": get_unlocked_features(),
		"farm_slots": get_unlocked_farm_slots(),
	}.duplicate(true)


func import_save_data(data: Dictionary) -> Dictionary:
	GameManager.xp = maxi(int(data.get("xp", GameManager.xp)), 0)
	GameManager.level = clampi(int(data.get("level", GameManager.level)), 1, get_max_level())
	return recalculate_level()


func debug_reset_progress() -> void:
	GameManager.xp = 0
	GameManager.level = 1


# ─── 解锁查询 ───

func get_level_unlocks(level: int) -> Dictionary:
	var level_data := DataManager.get_level_data(level)
	if level_data.is_empty():
		return _empty_unlocks()
	var unlocks: Dictionary = level_data.get("unlocks", {})
	return _normalize_unlocks(unlocks)


func get_accumulated_unlocks(level: int = -1) -> Dictionary:
	var target_level := GameManager.level if level < 0 else level
	target_level = clampi(target_level, 1, get_max_level())
	var result := _empty_unlocks()
	for current_level in range(1, target_level + 1):
		var unlocks := get_level_unlocks(current_level)
		_append_unique(result["crops"], unlocks.get("crops", []))
		_append_unique(result["features"], unlocks.get("features", []))
		var farm_slots := int(unlocks.get("farm_slots", 0))
		if farm_slots > 0:
			result["farm_slots"] = farm_slots
	return result.duplicate(true)


func is_crop_unlocked(crop_id: String) -> bool:
	if crop_id == "":
		return false
	var unlock_level := get_crop_unlock_level(crop_id)
	return unlock_level > 0 and GameManager.level >= unlock_level


func get_crop_unlock_level(crop_id: String) -> int:
	if crop_id == "":
		return -1
	for level_data in DataManager.get_all_levels():
		if not level_data is Dictionary:
			continue
		var level := int(level_data.get("level", 1))
		var unlocks: Dictionary = level_data.get("unlocks", {})
		var crops: Array = unlocks.get("crops", [])
		if crop_id in crops:
			return level
	var crop_data := DataManager.get_crop(crop_id)
	if crop_data.is_empty():
		return -1
	return int(crop_data.get("unlock_level", 1))


func get_unlocked_crops() -> Array:
	return get_accumulated_unlocks().get("crops", []).duplicate(true)


func get_locked_crops() -> Array:
	var result: Array = []
	for crop_data in DataManager.get_all_crops():
		if not crop_data is Dictionary:
			continue
		var crop_id := str(crop_data.get("id", ""))
		if crop_id == "" or is_crop_unlocked(crop_id):
			continue
		var entry: Dictionary = crop_data.duplicate(true)
		entry["unlock_level"] = get_crop_unlock_level(crop_id)
		result.append(entry)
	return result.duplicate(true)


func is_feature_unlocked(feature_id: String) -> bool:
	if feature_id == "":
		return false
	return feature_id in get_unlocked_features()


func get_unlocked_features() -> Array:
	return get_accumulated_unlocks().get("features", []).duplicate(true)


func get_unlocked_farm_slots() -> int:
	return int(get_accumulated_unlocks().get("farm_slots", 0))


# ─── 内部 helper ───

func _make_xp_result(
	success: bool,
	amount: int,
	xp_added: int,
	xp_before: int,
	xp_after: int,
	level_before: int,
	level_after: int,
	levels_gained: Array[int],
	unlocks: Dictionary,
	error_code: String
) -> Dictionary:
	return {
		"success": success,
		"amount": amount,
		"xp_added": xp_added,
		"xp_before": xp_before,
		"xp_after": xp_after,
		"level_before": level_before,
		"level_after": level_after,
		"leveled_up": not levels_gained.is_empty(),
		"levels_gained": levels_gained.duplicate(true),
		"unlocks": unlocks.duplicate(true),
		"error_code": error_code,
	}.duplicate(true)


func _empty_unlocks() -> Dictionary:
	return {
		"crops": [],
		"features": [],
		"farm_slots": 0,
	}.duplicate(true)


func _normalize_unlocks(unlocks: Dictionary) -> Dictionary:
	var result := _empty_unlocks()
	_append_unique(result["crops"], unlocks.get("crops", []))
	_append_unique(result["features"], unlocks.get("features", []))
	result["farm_slots"] = int(unlocks.get("farm_slots", 0))
	return result.duplicate(true)


func _merge_unlocks_for_levels(levels: Array[int]) -> Dictionary:
	var result := _empty_unlocks()
	for level in levels:
		var unlocks := get_level_unlocks(level)
		_append_unique(result["crops"], unlocks.get("crops", []))
		_append_unique(result["features"], unlocks.get("features", []))
		var farm_slots := int(unlocks.get("farm_slots", 0))
		if farm_slots > 0:
			result["farm_slots"] = farm_slots
	return result.duplicate(true)


func _append_unique(target: Array, values: Array) -> void:
	for value in values:
		if value == null:
			continue
		var string_value := str(value)
		if string_value != "" and string_value not in target:
			target.append(string_value)


func _emit_unlock_signals(levels_gained: Array[int], merged_unlocks: Dictionary) -> void:
	if levels_gained.is_empty():
		return
	var has_unlocks: bool = not merged_unlocks.get("crops", []).is_empty() \
		or not merged_unlocks.get("features", []).is_empty() \
		or int(merged_unlocks.get("farm_slots", 0)) > 0
	if has_unlocks:
		EventBus.unlocks_changed.emit(merged_unlocks.duplicate(true))
	for level in levels_gained:
		var unlocks := get_level_unlocks(level)
		for crop_id in unlocks.get("crops", []):
			EventBus.crop_unlocked.emit(str(crop_id), level)
		for feature_id in unlocks.get("features", []):
			EventBus.feature_unlocked.emit(str(feature_id), level)
		var farm_slots := int(unlocks.get("farm_slots", 0))
		if farm_slots > 0:
			EventBus.farm_slots_changed.emit(farm_slots)
