## GameManager — 全局游戏状态管理
## 管理玩家核心数据（金币、经验、等级、背包）和存档
extends Node

# ─── 游戏状态枚举 ───
enum GameState { MAIN_MENU, PLAYING, PAUSED }

# ─── 存档路径 ───
const SAVE_PATH := "user://save_data.json"

# ─── 游戏状态 ───
var current_state: GameState = GameState.MAIN_MENU

# ─── 玩家状态 ───
var player_name: String = "农夫"
var gold: int = 100
var xp: int = 0
var level: int = 1
var player_energy: int = 100
var player_max_energy: int = 100
var current_day: int = 1
var current_season: String = "spring"  # spring/summer/autumn/winter
var inventory: Dictionary = {}  # item_id -> quantity
var farm_data: Dictionary = {}  # "x,y" -> {crop_id, stage, watered, ...}
var achievements_unlocked: Array[String] = []

# ─── 统计数据 ───
var stats: Dictionary = {
	"total_harvests": 0,
	"total_gold_earned": 0,
	"total_water_count": 0,
	"crops_planted_types": [],
}

# ─── 初始化 ───
func _ready() -> void:
	print("[GameManager] Initialized")


# ─── 金币操作 ───

func add_gold(amount: int, source: String = "") -> void:
	gold += amount
	if amount > 0:
		stats["total_gold_earned"] += amount
	EventBus.gold_changed.emit(gold, amount)
	if source != "":
		print("[GameManager] Gold +%d from %s (total: %d)" % [amount, source, gold])


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		EventBus.gold_changed.emit(gold, -amount)
		return true
	EventBus.ui_notification.emit("金币不足！", "warning")
	return false


func can_afford(amount: int) -> bool:
	return gold >= amount


# ─── 经验与等级 ───

func add_xp(amount: int, source: String = "") -> void:
	xp += amount
	EventBus.xp_gained.emit(amount, source)
	_check_level_up()


func _check_level_up() -> void:
	var max_level := DataManager.get_max_level()
	while level < max_level:
		var next_level_data := DataManager.get_level_data(level + 1)
		if next_level_data.is_empty():
			break
		var required_xp: int = next_level_data.get("xp_required", 999999)
		if xp >= required_xp:
			level += 1
			EventBus.level_up.emit(level)
			EventBus.ui_notification.emit("升级了！当前等级: %d" % level, "success")
			print("[GameManager] Level up! Now level %d" % level)
		else:
			break


func get_xp_progress() -> Dictionary:
	var current_data := DataManager.get_level_data(level)
	var next_data := DataManager.get_level_data(level + 1)
	var current_xp_base: int = current_data.get("xp_required", 0)
	var next_xp_required: int = next_data.get("xp_required", current_xp_base + 100)
	return {
		"current_xp": xp,
		"xp_for_current_level": current_xp_base,
		"xp_for_next_level": next_xp_required,
		"progress": float(xp - current_xp_base) / float(max(next_xp_required - current_xp_base, 1)),
	}


# ─── 背包操作 ───

func add_item(item_id: String, amount: int = 1) -> void:
	if has_node("/root/InventoryManager"):
		InventoryManager.add_item(item_id, amount)
		return
	_add_item_legacy(item_id, amount)


func remove_item(item_id: String, amount: int = 1) -> bool:
	if has_node("/root/InventoryManager"):
		return InventoryManager.remove_item(item_id, amount) == amount
	return _remove_item_legacy(item_id, amount)


func has_item(item_id: String, amount: int = 1) -> bool:
	if has_node("/root/InventoryManager"):
		return InventoryManager.has_item(item_id, amount)
	return inventory.has(item_id) and inventory[item_id] >= amount


func get_item_count(item_id: String) -> int:
	if has_node("/root/InventoryManager"):
		return InventoryManager.get_item_count(item_id)
	return inventory.get(item_id, 0)


func _add_item_legacy(item_id: String, amount: int = 1) -> void:
	if inventory.has(item_id):
		inventory[item_id] += amount
	else:
		inventory[item_id] = amount


func _remove_item_legacy(item_id: String, amount: int = 1) -> bool:
	if not inventory.has(item_id) or inventory[item_id] < amount:
		return false
	inventory[item_id] -= amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true


# ─── 存档系统 ───

func save_game() -> void:
	var inventory_save_data: Dictionary = {}
	if has_node("/root/InventoryManager"):
		inventory_save_data = InventoryManager.export_save_data()
	var save_data := {
		"version": 2,
		"player_name": player_name,
		"gold": gold,
		"xp": xp,
		"level": level,
		"current_day": current_day,
		"current_season": current_season,
		"inventory": inventory,
		"inventory_slots": inventory_save_data,
		"farm_data": farm_data,
		"achievements_unlocked": achievements_unlocked,
		"stats": stats,
		"timestamp": Time.get_unix_time_from_system(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[GameManager] Cannot write save file")
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	EventBus.game_saved.emit()
	print("[GameManager] Game saved")


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[GameManager] No save file found, starting fresh")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[GameManager] Cannot read save file")
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[GameManager] Save file corrupted: " + json.get_error_message())
		return false

	var data: Dictionary = json.data
	player_name = data.get("player_name", "农夫")
	gold = data.get("gold", 100)
	xp = data.get("xp", 0)
	level = data.get("level", 1)
	current_day = data.get("current_day", 1)
	current_season = data.get("current_season", "spring")
	inventory = data.get("inventory", {})
	if has_node("/root/InventoryManager"):
		var inventory_save_data: Dictionary = data.get("inventory_slots", {})
		if inventory_save_data.is_empty():
			InventoryManager.import_save_data({"inventory": inventory})
		else:
			InventoryManager.import_save_data(inventory_save_data)
	farm_data = data.get("farm_data", {})
	achievements_unlocked = []
	for ach_id in data.get("achievements_unlocked", []):
		achievements_unlocked.append(ach_id)
	stats = data.get("stats", stats)

	EventBus.game_loaded.emit()
	print("[GameManager] Game loaded (Day %d, Level %d)" % [current_day, level])
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[GameManager] Save deleted")


# ─── 游戏状态控制 ───

func start_new_game(name: String = "农夫") -> void:
	new_game(name)
	current_state = GameState.PLAYING


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		EventBus.game_paused.emit()
		print("[GameManager] Game paused")


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		EventBus.game_resumed.emit()
		print("[GameManager] Game resumed")


# ─── 精力系统 ───

func use_energy(amount: int) -> bool:
	if player_energy >= amount:
		player_energy -= amount
		return true
	EventBus.ui_notification.emit("精力不足！", "warning")
	return false


func restore_energy(amount: int) -> void:
	player_energy = mini(player_energy + amount, player_max_energy)


func reset_energy() -> void:
	player_energy = player_max_energy


# ─── 新游戏 / 重置 ───

func new_game(name: String = "农夫") -> void:
	player_name = name
	gold = 100
	xp = 0
	level = 1
	player_energy = 100
	player_max_energy = 100
	current_day = 1
	current_season = "spring"
	inventory = {}
	if has_node("/root/InventoryManager"):
		InventoryManager.debug_clear()
	farm_data = {}
	achievements_unlocked = []
	stats = {
		"total_harvests": 0,
		"total_gold_earned": 0,
		"total_water_count": 0,
		"crops_planted_types": [],
	}
	current_state = GameState.PLAYING
	print("[GameManager] New game started for '%s'" % name)


func reset_to_default() -> void:
	new_game("农夫")
	current_state = GameState.MAIN_MENU
	print("[GameManager] Reset to default")
