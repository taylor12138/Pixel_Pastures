## DataManager — JSON 数据表加载与缓存
## 启动时加载所有 res://data/*.json 至内存字典
extends Node

## 缓存字典：key = 表名(不含扩展名), value = 解析后的数据
var _tables: Dictionary = {}

## 数据目录路径
const DATA_DIR := "res://data/"

## 需要在启动时加载的数据表列表
const TABLE_LIST: Array[String] = [
	"crops",
	"items",
	"levels",
	"achievements",
]


func _ready() -> void:
	_load_all_tables()
	print("[DataManager] All data tables loaded: ", _tables.keys())


## 加载所有配置表
func _load_all_tables() -> void:
	for table_name in TABLE_LIST:
		var data = _load_json(DATA_DIR + table_name + ".json")
		if data != null:
			_tables[table_name] = data


## 加载单个 JSON 文件
func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[DataManager] File not found: " + path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] Cannot open: " + path)
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[DataManager] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null

	return json.data


# ─── 公共 API ───

## 获取整张表
func get_table(table_name: String) -> Variant:
	if _tables.has(table_name):
		return _tables[table_name]
	push_warning("[DataManager] Table not found: " + table_name)
	return null


## 获取表中某条记录 (适用于 Dictionary 类型的表)
func get_entry(table_name: String, entry_id: String) -> Variant:
	var table = get_table(table_name)
	if table == null:
		return null
	if table is Dictionary and table.has(entry_id):
		return table[entry_id]
	push_warning("[DataManager] Entry '%s' not found in table '%s'" % [entry_id, table_name])
	return null


## 获取作物数据（便捷方法，返回副本保证不可变性）
func get_crop(crop_id: String) -> Dictionary:
	var entry = get_entry("crops", crop_id)
	if entry is Dictionary:
		return entry.duplicate(true)
	return {}


## 获取指定季节可种植的作物列表
func get_crops_by_season(season: String) -> Array:
	var result: Array = []
	var crops = get_table("crops")
	if crops is Dictionary:
		for crop_id in crops:
			var crop: Dictionary = crops[crop_id]
			if crop.has("seasons") and season in crop["seasons"]:
				result.append(crop.duplicate(true))
	return result


## 获取指定等级已解锁的作物列表
func get_unlocked_crops(player_level: int) -> Array:
	var result: Array = []
	var crops = get_table("crops")
	if crops is Dictionary:
		for crop_id in crops:
			var crop: Dictionary = crops[crop_id]
			if crop.get("unlock_level", 999) <= player_level:
				result.append(crop.duplicate(true))
	return result


## 获取所有作物列表
func get_all_crops() -> Array:
	var result: Array = []
	var crops = get_table("crops")
	if crops is Dictionary:
		for crop_id in crops:
			result.append(crops[crop_id].duplicate(true))
	return result


## 获取物品数据（便捷方法，返回副本保证不可变性）
func get_item(item_id: String) -> Dictionary:
	var entry = get_entry("items", item_id)
	if entry is Dictionary:
		return entry.duplicate(true)
	return {}


## 获取等级数据（便捷方法，返回副本保证不可变性）
func get_level_data(level: int) -> Dictionary:
	var levels = get_table("levels")
	if levels is Array:
		for lvl in levels:
			if lvl is Dictionary and lvl.get("level", -1) == level:
				return lvl.duplicate(true)
	return {}


## 获取所有等级数据（返回副本保证不可变性）
func get_all_levels() -> Array:
	var result: Array = []
	var levels = get_table("levels")
	if levels is Array:
		for lvl in levels:
			if lvl is Dictionary:
				result.append(lvl.duplicate(true))
	return result


## 获取最大等级
func get_max_level() -> int:
	var max_level := 1
	var levels = get_table("levels")
	if levels is Array:
		for lvl in levels:
			if lvl is Dictionary:
				max_level = maxi(max_level, int(lvl.get("level", 1)))
	return max_level


## 热重载数据表（调试用）
func reload_table(table_name: String) -> void:
	var data = _load_json(DATA_DIR + table_name + ".json")
	if data != null:
		_tables[table_name] = data
		print("[DataManager] Reloaded: " + table_name)
