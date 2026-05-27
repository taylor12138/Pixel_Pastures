extends Node2D
## LevelManager 自动化测试脚本

@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []

var _xp_signal_count: int = 0
var _level_up_values: Array[int] = []
var _unlocks_changed_count: int = 0
var _crop_unlocked_values: Array[String] = []
var _feature_unlocked_values: Array[String] = []
var _farm_slots_values: Array[int] = []


func _ready() -> void:
	_connect_signals_once()
	print("=== LevelManager 自动化测试 ===")

	test_initial_state()
	test_xp_gain_without_level_up()
	test_invalid_xp()
	test_single_level_up()
	test_multi_level_up()
	test_max_level_accumulates_xp()
	test_xp_source_calculation()
	test_crop_unlock_queries()
	test_unlock_lists_and_farm_slots()
	test_signal_emissions()
	test_save_import_and_recalculate()
	test_safe_copies()

	var summary := "=== LevelManager 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_initial_state() -> void:
	_reset_state()
	_assert(GameManager.level == 1, "初始等级为 1")
	_assert(GameManager.xp == 0, "初始 XP 为 0")
	_assert(LevelManager.get_max_level() == 7, "最大等级为 7")
	_assert(not LevelManager.is_max_level(), "初始不是满级")


func test_xp_gain_without_level_up() -> void:
	_reset_state()
	GameManager.xp = 50
	var result := LevelManager.add_xp(10, "manual")
	_assert(result["success"] == true, "XP 增加成功")
	_assert(result["xp_added"] == 10, "XP 增加量正确")
	_assert(result["xp_before"] == 50 and result["xp_after"] == 60, "XP 前后值正确")
	_assert(result["level_before"] == 1 and result["level_after"] == 1, "未升级等级保持")
	_assert(result["leveled_up"] == false, "未达到阈值不升级")
	_assert(_xp_signal_count == 1, "成功 XP 操作发射 xp_gained")


func test_invalid_xp() -> void:
	_reset_state()
	var result_zero := LevelManager.add_xp(0, "manual")
	var result_negative := LevelManager.add_xp(-1, "manual")
	var result_empty_source := LevelManager.add_xp(10, "")
	_assert(result_zero["success"] == false and result_zero["error_code"] == LevelManager.ERR_INVALID_XP_AMOUNT, "0 XP 被拒绝")
	_assert(result_negative["success"] == false and result_negative["error_code"] == LevelManager.ERR_INVALID_XP_AMOUNT, "负 XP 被拒绝")
	_assert(result_empty_source["success"] == false and result_empty_source["error_code"] == LevelManager.ERR_INVALID_SOURCE, "空来源被拒绝")
	_assert(GameManager.xp == 0 and GameManager.level == 1, "无效 XP 无副作用")
	_assert(_xp_signal_count == 0, "无效 XP 不发射信号")


func test_single_level_up() -> void:
	_reset_state()
	GameManager.xp = 90
	var result := LevelManager.add_xp(10, "manual")
	_assert(GameManager.level == 2, "达到阈值升到 2 级")
	_assert(result["leveled_up"] == true, "升级结果标记正确")
	_assert(result["levels_gained"] == [2], "单次升级 levels_gained 正确")
	_assert("tomato" in result["unlocks"]["crops"], "升级结果包含 2 级作物解锁")


func test_multi_level_up() -> void:
	_reset_state()
	var result := LevelManager.add_xp(500, "manual")
	_assert(GameManager.level == 4, "一次 XP 可连升到 4 级")
	_assert(result["levels_gained"] == [2, 3, 4], "连升 levels_gained 正确")
	_assert("tomato" in result["unlocks"]["crops"] and "strawberry" in result["unlocks"]["crops"], "连升合并作物解锁")
	_assert(result["unlocks"]["farm_slots"] == 36, "连升保留最终农田格数")


func test_max_level_accumulates_xp() -> void:
	_reset_state()
	GameManager.xp = 1800
	GameManager.level = 7
	var result := LevelManager.add_xp(100, "manual")
	_assert(result["success"] == true, "满级仍可增加 XP")
	_assert(GameManager.xp == 1900, "满级 XP 继续累计")
	_assert(GameManager.level == 7, "满级等级保持")
	_assert(_level_up_values.is_empty(), "满级加 XP 不发射 level_up")


func test_xp_source_calculation() -> void:
	_reset_state()
	_assert(LevelManager.calculate_xp("plant") == 5, "plant XP 为 5")
	_assert(LevelManager.calculate_xp("harvest") == 10, "harvest XP 为 10")
	_assert(LevelManager.calculate_xp("sell", {"total_price": 50}) == 25, "sell XP 为总价一半")
	var manual_result := LevelManager.grant_xp("manual", {"amount": 20})
	_assert(manual_result["success"] == true and GameManager.xp == 20, "manual grant_xp 使用 amount")
	var missing_result := LevelManager.grant_xp("missing_source", {})
	_assert(missing_result["success"] == false and missing_result["error_code"] == LevelManager.ERR_INVALID_SOURCE, "未知 XP 来源被拒绝")


func test_crop_unlock_queries() -> void:
	_reset_state()
	GameManager.level = 2
	_assert(LevelManager.is_crop_unlocked("tomato"), "2 级解锁 tomato")
	_assert(LevelManager.get_crop_unlock_level("tomato") == 2, "tomato 解锁等级为 2")
	GameManager.level = 1
	_assert(not LevelManager.is_crop_unlocked("tomato"), "1 级未解锁 tomato")
	_assert(not LevelManager.is_crop_unlocked("missing_crop"), "缺失作物不解锁")
	var locked := LevelManager.get_locked_crops()
	var has_tomato := false
	for crop in locked:
		if crop["id"] == "tomato" and crop["unlock_level"] == 2:
			has_tomato = true
	_assert(has_tomato, "锁定作物列表包含 tomato 与等级")


func test_unlock_lists_and_farm_slots() -> void:
	_reset_state()
	var level_1 := LevelManager.get_accumulated_unlocks(1)
	_assert("carrot" in level_1["crops"] and "basic_farm" in level_1["features"], "1 级累计解锁正确")
	_assert(level_1["farm_slots"] == 12, "1 级农田格数为 12")
	var level_4 := LevelManager.get_accumulated_unlocks(4)
	_assert("pepper" in level_4["crops"] and "eggplant" in level_4["crops"], "4 级累计作物解锁正确")
	_assert("steal_crops" in level_4["features"] and "expand_land" in level_4["features"], "4 级累计功能解锁正确")
	_assert(level_4["farm_slots"] == 36, "4 级农田格数为 36")
	var level_4_only := LevelManager.get_level_unlocks(4)
	_assert(level_4_only["crops"] == ["pepper", "eggplant"], "单级解锁仅包含新增作物")
	_assert(LevelManager.is_feature_unlocked("basic_farm"), "basic_farm 1 级可用")
	GameManager.level = 2
	_assert(not LevelManager.is_feature_unlocked("decoration_mode"), "2 级未解锁 decoration_mode")
	GameManager.level = 3
	_assert(LevelManager.is_feature_unlocked("decoration_mode"), "3 级解锁 decoration_mode")
	var expected_slots_by_level: Array[int] = [0, 12, 16, 24, 36, 48, 64, 80]
	for level in range(1, 8):
		GameManager.level = level
		var expected_slots: int = expected_slots_by_level[level]
		_assert(LevelManager.get_unlocked_farm_slots() == expected_slots, "%d 级农田格数正确" % level)


func test_signal_emissions() -> void:
	_reset_state()
	LevelManager.add_xp(500, "manual")
	_assert(_xp_signal_count == 1, "XP 信号发射一次")
	_assert(_level_up_values == [2, 3, 4], "level_up 按等级逐次发射")
	_assert(_unlocks_changed_count == 1, "unlocks_changed 发射一次")
	_assert("tomato" in _crop_unlocked_values and "strawberry" in _crop_unlocked_values, "crop_unlocked 逐作物发射")
	_assert("decoration_mode" in _feature_unlocked_values and "steal_crops" in _feature_unlocked_values, "feature_unlocked 逐功能发射")
	_assert(36 in _farm_slots_values, "farm_slots_changed 发射最终容量")


func test_save_import_and_recalculate() -> void:
	_reset_state()
	LevelManager.add_xp(250, "manual")
	var exported := LevelManager.export_save_data()
	_assert(exported.has("xp") and exported.has("level") and exported.has("unlocked_crops"), "导出包含等级系统快照")
	LevelManager.import_save_data({"xp": 500, "level": 1})
	_assert(GameManager.xp == 500 and GameManager.level == 4, "导入后按 XP 修复等级")
	GameManager.xp = 500
	GameManager.level = 1
	var repair := LevelManager.recalculate_level()
	_assert(repair["corrected"] == true and repair["new_level"] == 4, "recalculate_level 修复不一致等级")


func test_safe_copies() -> void:
	_reset_state()
	var crops := LevelManager.get_unlocked_crops()
	crops.append("external_mutation")
	_assert("external_mutation" not in LevelManager.get_unlocked_crops(), "解锁作物数组为安全副本")
	var level_data := DataManager.get_level_data(3)
	level_data["xp_required"] = -1
	_assert(DataManager.get_level_data(3)["xp_required"] == 250, "等级数据查询为安全副本")


func _reset_state() -> void:
	GameManager.xp = 0
	GameManager.level = 1
	GameManager.gold = 100
	GameManager.stats = {
		"total_harvests": 0,
		"total_gold_earned": 0,
		"total_water_count": 0,
		"crops_planted_types": [],
	}
	InventoryManager.debug_clear()
	_reset_signal_counts()


func _reset_signal_counts() -> void:
	_xp_signal_count = 0
	_level_up_values.clear()
	_unlocks_changed_count = 0
	_crop_unlocked_values.clear()
	_feature_unlocked_values.clear()
	_farm_slots_values.clear()


func _connect_signals_once() -> void:
	if not EventBus.xp_gained.is_connected(_on_xp_gained):
		EventBus.xp_gained.connect(_on_xp_gained)
	if not EventBus.level_up.is_connected(_on_level_up):
		EventBus.level_up.connect(_on_level_up)
	if not EventBus.unlocks_changed.is_connected(_on_unlocks_changed):
		EventBus.unlocks_changed.connect(_on_unlocks_changed)
	if not EventBus.crop_unlocked.is_connected(_on_crop_unlocked):
		EventBus.crop_unlocked.connect(_on_crop_unlocked)
	if not EventBus.feature_unlocked.is_connected(_on_feature_unlocked):
		EventBus.feature_unlocked.connect(_on_feature_unlocked)
	if not EventBus.farm_slots_changed.is_connected(_on_farm_slots_changed):
		EventBus.farm_slots_changed.connect(_on_farm_slots_changed)


func _on_xp_gained(_amount: int, _source: String) -> void:
	_xp_signal_count += 1


func _on_level_up(new_level: int) -> void:
	_level_up_values.append(new_level)


func _on_unlocks_changed(_unlocks: Dictionary) -> void:
	_unlocks_changed_count += 1


func _on_crop_unlocked(crop_id: String, _level: int) -> void:
	_crop_unlocked_values.append(crop_id)


func _on_feature_unlocked(feature_id: String, _level: int) -> void:
	_feature_unlocked_values.append(feature_id)


func _on_farm_slots_changed(new_slots: int) -> void:
	_farm_slots_values.append(new_slots)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
