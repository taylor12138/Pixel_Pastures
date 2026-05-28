extends Node
## SaveManager — 本地 JSON 存档编排层
## 负责 PRD1-5 管理器状态的保存、读取、校验、迁移、备份、删除、列表与自动保存。

const SAVE_DIR := "user://saves/"
const BACKUP_DIR := "user://saves/backup/"
const MANUAL_SLOT_COUNT := 3
const AUTO_SAVE_SLOT := -1
const CURRENT_SCHEMA_VERSION := 1
const GAME_VERSION := "0.1.0"

const ERR_INVALID_SLOT := "INVALID_SLOT"
const ERR_SAVE_NOT_FOUND := "SAVE_NOT_FOUND"
const ERR_FILE_OPEN_FAILED := "FILE_OPEN_FAILED"
const ERR_FILE_WRITE_FAILED := "FILE_WRITE_FAILED"
const ERR_FILE_READ_FAILED := "FILE_READ_FAILED"
const ERR_JSON_PARSE_FAILED := "JSON_PARSE_FAILED"
const ERR_INVALID_SAVE_DATA := "INVALID_SAVE_DATA"
const ERR_UNSUPPORTED_SCHEMA_VERSION := "UNSUPPORTED_SCHEMA_VERSION"
const ERR_BACKUP_FAILED := "BACKUP_FAILED"
const ERR_APPLY_FAILED := "APPLY_FAILED"

var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0
var _auto_save_elapsed: float = 0.0
var _initialized: bool = false


func _ready() -> void:
	initialize()
	set_process(true)
	# Godot 会在关闭请求时发送通知；这里不强制修改工程级退出策略。


func _process(delta: float) -> void:
	if not auto_save_enabled:
		return
	if not _is_game_playing():
		return
	_auto_save_elapsed += delta
	if _auto_save_elapsed >= auto_save_interval:
		_auto_save_elapsed = 0.0
		auto_save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if auto_save_enabled:
			auto_save_now()
		get_tree().quit()


func initialize() -> Dictionary:
	var result := ensure_save_dirs()
	_initialized = bool(result.get("success", false))
	return result


func ensure_save_dirs() -> Dictionary:
	var dir := DirAccess.open("user://")
	if dir == null:
		return _failure_result("ensure_save_dirs", AUTO_SAVE_SLOT, "user://", ERR_FILE_OPEN_FAILED, "无法打开 user:// 目录")
	var error := dir.make_dir_recursive("saves/backup")
	if error != OK:
		return _failure_result("ensure_save_dirs", AUTO_SAVE_SLOT, BACKUP_DIR, ERR_FILE_WRITE_FAILED, "无法创建存档目录")
	return _success_result("ensure_save_dirs", AUTO_SAVE_SLOT, BACKUP_DIR, {}, "存档目录已就绪")


func is_valid_slot(slot: int) -> bool:
	return slot == AUTO_SAVE_SLOT or (slot >= 0 and slot < MANUAL_SLOT_COUNT)


func get_save_path(slot: int) -> String:
	if slot == AUTO_SAVE_SLOT:
		return SAVE_DIR + "auto_save.json"
	if slot >= 0 and slot < MANUAL_SLOT_COUNT:
		return SAVE_DIR + "slot_%d.json" % slot
	return ""


func build_save_data(slot: int) -> Dictionary:
	var now := _now_timestamp()
	var metadata := _build_metadata(slot, now)
	return _json_safe({
		"schema_version": CURRENT_SCHEMA_VERSION,
		"game_version": GAME_VERSION,
		"created_at": now,
		"updated_at": now,
		"slot": slot,
		"metadata": metadata,
		"game": _call_manager_export("GameManager"),
		"time": _call_manager_export("TimeManager"),
		"inventory": _call_manager_export("InventoryManager"),
		"crops": _normalize_crop_export(_call_manager_export("CropManager")),
		"economy": _call_manager_export("EconomyManager"),
		"level_system": _call_manager_export("LevelManager"),
		"settings": {},
		"future": {},
	})


func validate_save_data(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return _failure_result("validate", AUTO_SAVE_SLOT, "", ERR_INVALID_SAVE_DATA, "存档根对象必须是 Dictionary")
	var schema_version := int(data.get("schema_version", -1))
	if schema_version > CURRENT_SCHEMA_VERSION:
		return _failure_result("validate", int(data.get("slot", AUTO_SAVE_SLOT)), "", ERR_UNSUPPORTED_SCHEMA_VERSION, "存档版本高于当前支持版本")
	if schema_version < 0:
		return _failure_result("validate", int(data.get("slot", AUTO_SAVE_SLOT)), "", ERR_INVALID_SAVE_DATA, "缺少 schema_version")
	var required := ["schema_version", "game_version", "created_at", "updated_at", "slot", "metadata", "game", "inventory", "crops", "economy", "level_system", "settings", "future"]
	for field in required:
		if not data.has(field):
			return _failure_result("validate", int(data.get("slot", AUTO_SAVE_SLOT)), "", ERR_INVALID_SAVE_DATA, "缺少存档字段: %s" % field)
	for dict_field in ["metadata", "game", "inventory", "crops", "economy", "level_system", "settings", "future"]:
		if not (data.get(dict_field) is Dictionary):
			return _failure_result("validate", int(data.get("slot", AUTO_SAVE_SLOT)), "", ERR_INVALID_SAVE_DATA, "存档字段类型无效: %s" % dict_field)
	if data.has("time") and not (data.get("time") is Dictionary):
		return _failure_result("validate", int(data.get("slot", AUTO_SAVE_SLOT)), "", ERR_INVALID_SAVE_DATA, "存档字段类型无效: time")
	var slot := int(data.get("slot", AUTO_SAVE_SLOT))
	if not is_valid_slot(slot):
		return _failure_result("validate", slot, "", ERR_INVALID_SLOT, "存档槽位无效")
	return _success_result("validate", slot, get_save_path(slot), data.get("metadata", {}), "存档校验通过", data)


func migrate_save_data(data: Dictionary) -> Dictionary:
	var schema_version := int(data.get("schema_version", -1))
	var slot := int(data.get("slot", AUTO_SAVE_SLOT))
	if schema_version > CURRENT_SCHEMA_VERSION:
		return _failure_result("migrate", slot, "", ERR_UNSUPPORTED_SCHEMA_VERSION, "不支持未来版本存档")
	if schema_version == CURRENT_SCHEMA_VERSION:
		return _success_result("migrate", slot, get_save_path(slot), data.get("metadata", {}), "无需迁移", data)
	if schema_version == 0:
		var migrated := data.duplicate(true)
		migrated["schema_version"] = CURRENT_SCHEMA_VERSION
		migrated["settings"] = migrated.get("settings", {})
		migrated["future"] = migrated.get("future", {})
		return _success_result("migrate", slot, get_save_path(slot), migrated.get("metadata", {}), "v0 存档已迁移", migrated)
	return _failure_result("migrate", slot, "", ERR_INVALID_SAVE_DATA, "缺少或无效的 schema_version")


func read_save_file(slot: int) -> Dictionary:
	var slot_error := _validate_slot_result("read", slot)
	if not bool(slot_error.get("success", false)):
		return slot_error
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return _failure_result("read", slot, path, ERR_SAVE_NOT_FOUND, "存档文件不存在")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure_result("read", slot, path, ERR_FILE_OPEN_FAILED, "无法打开存档文件")
	var text := file.get_as_text()
	file.close()
	if text == "":
		return _failure_result("read", slot, path, ERR_FILE_READ_FAILED, "存档文件为空或读取失败")
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		return _failure_result("read", slot, path, ERR_JSON_PARSE_FAILED, json.get_error_message())
	if not json.data is Dictionary:
		return _failure_result("read", slot, path, ERR_INVALID_SAVE_DATA, "JSON 根对象不是 Dictionary")
	var migrate_result := migrate_save_data(json.data)
	if not bool(migrate_result.get("success", false)):
		migrate_result["operation"] = "read"
		migrate_result["path"] = path
		return migrate_result
	var migrated: Dictionary = migrate_result.get("data", {})
	var validate_result := validate_save_data(migrated)
	if not bool(validate_result.get("success", false)):
		validate_result["operation"] = "read"
		validate_result["path"] = path
		return validate_result
	return _success_result("read", slot, path, migrated.get("metadata", {}), "读取存档成功", migrated)


func write_save_file(slot: int, data: Dictionary) -> Dictionary:
	var slot_error := _validate_slot_result("write", slot)
	if not bool(slot_error.get("success", false)):
		return slot_error
	var path := get_save_path(slot)
	var dir_result := ensure_save_dirs()
	if not bool(dir_result.get("success", false)):
		dir_result["operation"] = "write"
		dir_result["slot"] = slot
		dir_result["path"] = path
		return dir_result
	var tmp_path := path + ".tmp"
	var backup_result := _create_backup_if_needed(slot)
	if not bool(backup_result.get("success", false)):
		return backup_result
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return _failure_result("write", slot, path, ERR_FILE_OPEN_FAILED, "无法打开临时存档文件")
	file.store_string(JSON.stringify(_json_safe(data), "\t"))
	file.close()
	var verify := _verify_json_file(tmp_path, slot)
	if not bool(verify.get("success", false)):
		_delete_file_if_exists(tmp_path)
		verify["operation"] = "write"
		verify["path"] = path
		return verify
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			_delete_file_if_exists(tmp_path)
			return _failure_result("write", slot, path, ERR_FILE_WRITE_FAILED, "无法替换旧存档")
	var rename_error := DirAccess.rename_absolute(tmp_path, path)
	if rename_error != OK:
		_delete_file_if_exists(tmp_path)
		return _failure_result("write", slot, path, ERR_FILE_WRITE_FAILED, "无法写入目标存档")
	return _success_result("write", slot, path, data.get("metadata", {}), "写入存档成功", data)


func save_game(slot: int = 0) -> Dictionary:
	var slot_error := _validate_slot_result("save", slot)
	if not bool(slot_error.get("success", false)):
		_emit_save_failure(slot_error)
		return slot_error
	var data := build_save_data(slot)
	var validate_result := validate_save_data(data)
	if not bool(validate_result.get("success", false)):
		validate_result["operation"] = "save"
		_emit_save_failure(validate_result)
		return validate_result
	var write_result := write_save_file(slot, data)
	write_result["operation"] = "save"
	if bool(write_result.get("success", false)):
		EventBus.game_saved.emit(slot, write_result.get("metadata", {}))
	else:
		_emit_save_failure(write_result)
	return write_result


func load_game(slot: int = 0) -> Dictionary:
	var read_result := read_save_file(slot)
	if not bool(read_result.get("success", false)):
		read_result["operation"] = "load"
		_emit_load_failure(read_result)
		return read_result
	var data: Dictionary = read_result.get("data", {})
	var apply_result := apply_save_data(data)
	apply_result["operation"] = "load"
	apply_result["slot"] = slot
	apply_result["path"] = get_save_path(slot)
	apply_result["metadata"] = data.get("metadata", {})
	if bool(apply_result.get("success", false)):
		EventBus.game_loaded.emit(slot, data.get("metadata", {}))
	else:
		_emit_load_failure(apply_result)
	return apply_result


func apply_save_data(data: Dictionary) -> Dictionary:
	var validate_result := validate_save_data(data)
	if not bool(validate_result.get("success", false)):
		validate_result["operation"] = "apply"
		return validate_result
	var slot := int(data.get("slot", AUTO_SAVE_SLOT))
	GameManager.import_save_data(data.get("game", {}))
	if has_node("/root/TimeManager"):
		if data.has("time") and data.get("time") is Dictionary:
			TimeManager.import_save_data(data.get("time", {}))
		else:
			TimeManager.initialize_new_game()
	InventoryManager.import_save_data(data.get("inventory", {}))
	CropManager.import_save_data(data.get("crops", {}))
	EconomyManager.import_save_data(data.get("economy", {}))
	LevelManager.import_save_data(data.get("level_system", {}))
	var last_online := float(data.get("game", {}).get("last_online_timestamp", data.get("updated_at", _now_timestamp())))
	CropManager.process_offline_time(last_online)
	LevelManager.recalculate_level()
	return _success_result("apply", slot, get_save_path(slot), data.get("metadata", {}), "应用存档成功", data)


func has_save(slot: int) -> bool:
	var result := read_save_file(slot)
	return bool(result.get("success", false))


func delete_save(slot: int) -> Dictionary:
	var slot_error := _validate_slot_result("delete", slot)
	if not bool(slot_error.get("success", false)):
		return slot_error
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		var empty_result := _success_result("delete", slot, path, {}, "存档槽位已为空")
		EventBus.save_deleted.emit(slot)
		return empty_result
	var error := DirAccess.remove_absolute(path)
	if error != OK:
		return _failure_result("delete", slot, path, ERR_FILE_WRITE_FAILED, "删除存档失败")
	var result := _success_result("delete", slot, path, {}, "删除存档成功")
	EventBus.save_deleted.emit(slot)
	return result


func get_save_metadata(slot: int) -> Dictionary:
	var read_result := read_save_file(slot)
	if not bool(read_result.get("success", false)):
		return read_result
	return _success_result("metadata", slot, get_save_path(slot), read_result.get("metadata", {}), "读取元数据成功", read_result.get("metadata", {}))


func list_saves(include_auto: bool = true) -> Array:
	var slots: Array[int] = [0, 1, 2]
	if include_auto:
		slots.append(AUTO_SAVE_SLOT)
	var result: Array = []
	for slot in slots:
		var path := get_save_path(slot)
		var entry := {
			"slot": slot,
			"path": path,
			"exists": FileAccess.file_exists(path),
			"valid": false,
			"metadata": {},
			"error_code": "",
			"message": "",
		}
		if bool(entry["exists"]):
			var read_result := read_save_file(slot)
			entry["valid"] = bool(read_result.get("success", false))
			entry["metadata"] = read_result.get("metadata", {})
			entry["error_code"] = str(read_result.get("error_code", ""))
			entry["message"] = str(read_result.get("message", ""))
		result.append(entry)
	return result


func set_auto_save_enabled(enabled: bool) -> void:
	auto_save_enabled = enabled
	if not enabled:
		_auto_save_elapsed = 0.0


func set_auto_save_interval(seconds: float) -> void:
	auto_save_interval = maxf(seconds, 1.0)
	_auto_save_elapsed = 0.0


func auto_save_now() -> Dictionary:
	var result := save_game(AUTO_SAVE_SLOT)
	result["operation"] = "auto_save"
	if bool(result.get("success", false)):
		EventBus.auto_save_completed.emit(result)
	else:
		EventBus.auto_save_failed.emit(result)
	return result


func debug_delete_all_saves() -> void:
	for slot in [0, 1, 2, AUTO_SAVE_SLOT]:
		delete_save(slot)


func debug_print_save_slots() -> void:
	print("=== SaveManager 存档槽 ===")
	for entry in list_saves(true):
		print(entry)


func _validate_slot_result(operation: String, slot: int) -> Dictionary:
	if is_valid_slot(slot):
		return _success_result(operation, slot, get_save_path(slot), {}, "槽位有效")
	return _failure_result(operation, slot, "", ERR_INVALID_SLOT, "槽位必须是 0、1、2 或 -1")


func _success_result(operation: String, slot: int, path: String, metadata: Dictionary = {}, message: String = "成功", data: Variant = null) -> Dictionary:
	var result := {
		"success": true,
		"operation": operation,
		"slot": slot,
		"path": path,
		"timestamp": _now_timestamp(),
		"metadata": metadata.duplicate(true),
		"message": message,
		"error_code": "",
	}
	if data != null:
		result["data"] = data
	return result


func _failure_result(operation: String, slot: int, path: String, error_code: String, message: String) -> Dictionary:
	return {
		"success": false,
		"operation": operation,
		"slot": slot,
		"path": path,
		"timestamp": _now_timestamp(),
		"metadata": {},
		"message": message,
		"error_code": error_code,
	}


func _build_metadata(slot: int, now: float) -> Dictionary:
	var scene_path := ""
	if get_tree() != null and get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	var level := GameManager.level
	var xp := GameManager.xp
	var gold := GameManager.gold
	var time_state := _get_time_metadata()
	var summary := "Lv.%d | XP %d | Gold %d" % [level, xp, gold]
	if not time_state.is_empty():
		summary = "%s | %s %s" % [summary, str(time_state.get("date_text", "")), str(time_state.get("time_text", ""))]
	return {
		"level": level,
		"xp": xp,
		"gold": gold,
		"playtime": float(GameManager.stats.get("playtime", 0.0)),
		"current_scene": scene_path,
		"summary": summary,
		"updated_at": now,
		"auto_save": slot == AUTO_SAVE_SLOT,
		"date_text": str(time_state.get("date_text", "")),
		"time_text": str(time_state.get("time_text", "")),
		"season": str(time_state.get("season", "")),
		"day": int(time_state.get("day", 0)),
	}


func _get_time_metadata() -> Dictionary:
	if has_node("/root/TimeManager"):
		return TimeManager.get_time_state()
	return {}


func _call_manager_export(manager_name: String) -> Dictionary:
	var node := get_node_or_null("/root/" + manager_name)
	if node != null and node.has_method("export_save_data"):
		var data = node.call("export_save_data")
		if data is Dictionary:
			return data.duplicate(true)
	return {}


func _normalize_crop_export(data: Dictionary) -> Dictionary:
	if data.has("tiles") and data["tiles"] is Dictionary:
		return data.duplicate(true)
	return {"tiles": data.duplicate(true)}


func _create_backup_if_needed(slot: int) -> Dictionary:
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return _success_result("backup", slot, path, {}, "无需备份")
	var backup_path := _get_backup_path(slot)
	var error := DirAccess.copy_absolute(path, backup_path)
	if error != OK:
		return _failure_result("backup", slot, backup_path, ERR_BACKUP_FAILED, "创建备份失败")
	return _success_result("backup", slot, backup_path, {}, "备份成功")


func _get_backup_path(slot: int) -> String:
	if slot == AUTO_SAVE_SLOT:
		return BACKUP_DIR + "auto_save.bak.json"
	return BACKUP_DIR + "slot_%d.bak.json" % slot


func _verify_json_file(path: String, slot: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure_result("verify", slot, path, ERR_FILE_READ_FAILED, "无法读取临时存档")
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		return _failure_result("verify", slot, path, ERR_JSON_PARSE_FAILED, json.get_error_message())
	if not json.data is Dictionary:
		return _failure_result("verify", slot, path, ERR_INVALID_SAVE_DATA, "临时存档根对象无效")
	return validate_save_data(json.data)


func _delete_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _emit_save_failure(result: Dictionary) -> void:
	EventBus.game_save_failed.emit(int(result.get("slot", AUTO_SAVE_SLOT)), str(result.get("error_code", "")), str(result.get("message", "")))


func _emit_load_failure(result: Dictionary) -> void:
	EventBus.game_load_failed.emit(int(result.get("slot", AUTO_SAVE_SLOT)), str(result.get("error_code", "")), str(result.get("message", "")))


func _is_game_playing() -> bool:
	return has_node("/root/GameManager") and GameManager.current_state == GameManager.GameState.PLAYING


func _now_timestamp() -> float:
	return Time.get_unix_time_from_system()


func _json_safe(value: Variant) -> Variant:
	if value == null or value is bool or value is int or value is float or value is String:
		return value
	if value is Dictionary:
		var result := {}
		for key in value.keys():
			result[str(key)] = _json_safe(value[key])
		return result
	if value is Array:
		var array := []
		for item in value:
			array.append(_json_safe(item))
		return array
	if value is Vector2i:
		return "%d,%d" % [value.x, value.y]
	if value is Vector2:
		return "%s,%s" % [str(value.x), str(value.y)]
	return str(value)
