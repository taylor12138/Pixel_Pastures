extends Node2D
## CropManager 自动化测试脚本

@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []


func _ready() -> void:
	# 确保游戏处于 PLAYING 状态
	GameManager.start_new_game("测试农夫")

	print("=== CropManager 自动化测试 ===")

	# 准备测试种子
	GameManager.add_item("seed_carrot", 100)
	GameManager.add_item("seed_tomato", 5)

	test_plant_success()
	test_plant_no_seed()
	test_plant_occupied()
	test_plant_invalid_crop()
	test_water_success()
	test_water_already_watered()
	test_water_mature()
	test_water_withered()
	test_harvest_not_mature()
	test_harvest_mature()
	test_clear_crop()
	test_clear_empty()
	test_query_has_crop()
	test_query_needs_water()
	test_query_is_harvestable()
	test_query_get_crop_data()
	test_query_get_all_crops()
	test_query_get_mature_crops()
	test_query_get_crops_needing_water()
	test_growth_progress()
	test_debug_advance_time()
	test_export_import()

	# 输出总结
	var summary := "=== 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


# ─── 测试用例 ───

func test_plant_success() -> void:
	var pos := Vector2i(0, 0)
	_ensure_empty(pos)
	var result := CropManager.plant_crop(pos, "carrot")
	_assert(result == true, "plant_crop 成功返回 true")
	_assert(CropManager.has_crop(pos), "种植后 has_crop 返回 true")
	var data := CropManager.get_crop_data(pos)
	_assert(data["crop_id"] == "carrot", "种植后 crop_id 正确")
	_assert(data["stage"] == CropManager.CropStage.SEED, "种植后阶段为 SEED")
	_assert(data["watered"] == false, "种植后 watered 为 false")
	_cleanup(pos)


func test_plant_no_seed() -> void:
	var pos := Vector2i(1, 0)
	_ensure_empty(pos)
	# 确保没有 pumpkin 种子
	var result := CropManager.plant_crop(pos, "pumpkin")
	_assert(result == false, "无种子时 plant_crop 返回 false")
	_assert(not CropManager.has_crop(pos), "无种子时地块仍为空")


func test_plant_occupied() -> void:
	var pos := Vector2i(2, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	var result := CropManager.plant_crop(pos, "carrot")
	_assert(result == false, "已有作物时 plant_crop 返回 false")
	_cleanup(pos)


func test_plant_invalid_crop() -> void:
	var pos := Vector2i(3, 0)
	_ensure_empty(pos)
	var result := CropManager.plant_crop(pos, "nonexistent_crop_xyz")
	_assert(result == false, "无效 crop_id 时 plant_crop 返回 false")


func test_water_success() -> void:
	var pos := Vector2i(4, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	var result := CropManager.water_crop(pos)
	_assert(result == true, "water_crop 成功返回 true")
	var data := CropManager.get_crop_data(pos)
	_assert(data["watered"] == true, "浇水后 watered 为 true")
	_assert(data["water_count"] == 1, "浇水后 water_count 为 1")
	_cleanup(pos)


func test_water_already_watered() -> void:
	var pos := Vector2i(5, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	CropManager.water_crop(pos)
	var result := CropManager.water_crop(pos)
	_assert(result == false, "已浇水时再次浇水返回 false")
	_cleanup(pos)


func test_water_mature() -> void:
	var pos := Vector2i(6, 0)
	_ensure_empty(pos)
	_plant_and_force_mature(pos, "carrot")
	var result := CropManager.water_crop(pos)
	_assert(result == false, "MATURE 阶段浇水返回 false")
	_cleanup(pos)


func test_water_withered() -> void:
	var pos := Vector2i(7, 0)
	_ensure_empty(pos)
	_plant_and_force_wither(pos, "carrot")
	var result := CropManager.water_crop(pos)
	_assert(result == false, "WITHERED 阶段浇水返回 false")
	_cleanup(pos)


func test_harvest_not_mature() -> void:
	var pos := Vector2i(8, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	var result := CropManager.harvest_crop(pos)
	_assert(result == "", "非 MATURE 阶段收获返回空字符串")
	_cleanup(pos)


func test_harvest_mature() -> void:
	var pos := Vector2i(9, 0)
	_ensure_empty(pos)
	_plant_and_force_mature(pos, "carrot")
	var before_harvests: int = GameManager.stats["total_harvests"]
	var result := CropManager.harvest_crop(pos)
	_assert(result == "carrot", "收获 MATURE 作物返回 crop_id")
	_assert(not CropManager.has_crop(pos), "收获后地块为空")
	_assert(GameManager.stats["total_harvests"] == before_harvests + 1, "收获后 total_harvests 增加")
	_assert(GameManager.has_item("harvest_carrot"), "收获后背包有 harvest_carrot")


func test_clear_crop() -> void:
	var pos := Vector2i(10, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	var result := CropManager.clear_crop(pos)
	_assert(result == true, "clear_crop 成功返回 true")
	_assert(not CropManager.has_crop(pos), "清除后地块为空")


func test_clear_empty() -> void:
	var pos := Vector2i(11, 0)
	_ensure_empty(pos)
	var result := CropManager.clear_crop(pos)
	_assert(result == false, "空地块 clear_crop 返回 false")


func test_query_has_crop() -> void:
	var pos := Vector2i(12, 0)
	_ensure_empty(pos)
	_assert(not CropManager.has_crop(pos), "空地块 has_crop 返回 false")
	CropManager.plant_crop(pos, "carrot")
	_assert(CropManager.has_crop(pos), "种植后 has_crop 返回 true")
	_cleanup(pos)


func test_query_needs_water() -> void:
	var pos := Vector2i(13, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	_assert(CropManager.needs_water(pos), "SEED 未浇水 needs_water 返回 true")
	CropManager.water_crop(pos)
	_assert(not CropManager.needs_water(pos), "浇水后 needs_water 返回 false")
	_cleanup(pos)


func test_query_is_harvestable() -> void:
	var pos := Vector2i(14, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	_assert(not CropManager.is_harvestable(pos), "SEED 阶段 is_harvestable 返回 false")
	_plant_and_force_mature(pos, "carrot")
	_assert(CropManager.is_harvestable(pos), "MATURE 阶段 is_harvestable 返回 true")
	_cleanup(pos)


func test_query_get_crop_data() -> void:
	var pos := Vector2i(15, 0)
	_ensure_empty(pos)
	var empty_data := CropManager.get_crop_data(pos)
	_assert(empty_data.is_empty(), "空地块 get_crop_data 返回空字典")
	CropManager.plant_crop(pos, "carrot")
	var data := CropManager.get_crop_data(pos)
	_assert(data.has("crop_id"), "get_crop_data 包含 crop_id")
	_assert(data.has("stage"), "get_crop_data 包含 stage")
	_assert(data.has("watered"), "get_crop_data 包含 watered")
	_cleanup(pos)


func test_query_get_all_crops() -> void:
	_cleanup(Vector2i(20, 0))
	_cleanup(Vector2i(21, 0))
	CropManager.plant_crop(Vector2i(20, 0), "carrot")
	CropManager.plant_crop(Vector2i(21, 0), "carrot")
	var all_crops := CropManager.get_all_crops()
	_assert(all_crops.has(Vector2i(20, 0)), "get_all_crops 包含 (20,0)")
	_assert(all_crops.has(Vector2i(21, 0)), "get_all_crops 包含 (21,0)")
	_cleanup(Vector2i(20, 0))
	_cleanup(Vector2i(21, 0))


func test_query_get_mature_crops() -> void:
	var pos := Vector2i(22, 0)
	_ensure_empty(pos)
	_plant_and_force_mature(pos, "carrot")
	var mature_list := CropManager.get_mature_crops()
	_assert(pos in mature_list, "get_mature_crops 包含成熟作物位置")
	_cleanup(pos)


func test_query_get_crops_needing_water() -> void:
	var pos := Vector2i(23, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	var need_water := CropManager.get_crops_needing_water()
	_assert(pos in need_water, "get_crops_needing_water 包含未浇水作物位置")
	CropManager.water_crop(pos)
	need_water = CropManager.get_crops_needing_water()
	_assert(pos not in need_water, "浇水后不在 needing_water 列表中")
	_cleanup(pos)


func test_growth_progress() -> void:
	var pos := Vector2i(24, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	var progress := CropManager.get_growth_progress(pos)
	_assert(progress == 0.0, "未浇水时 progress 为 0.0")
	CropManager.water_crop(pos)
	progress = CropManager.get_growth_progress(pos)
	_assert(progress >= 0.0 and progress <= 1.0, "浇水后 progress 在 0~1 之间")
	_cleanup(pos)


func test_debug_advance_time() -> void:
	var pos := Vector2i(25, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	CropManager.water_crop(pos)
	# 推进足够时间让作物从 SEED 到 SPROUT (growth_time_per_stage = 10)
	CropManager.debug_advance_time(pos, 15.0)
	var data := CropManager.get_crop_data(pos)
	_assert(data["stage"] == CropManager.CropStage.SPROUT, "debug_advance_time 后阶段推进到 SPROUT")
	_assert(data["watered"] == false, "推进后 watered 重置为 false")
	_cleanup(pos)


func test_export_import() -> void:
	var pos := Vector2i(26, 0)
	_ensure_empty(pos)
	CropManager.plant_crop(pos, "carrot")
	CropManager.water_crop(pos)
	var exported := CropManager.export_save_data()
	_assert(exported.has("tiles") and exported["tiles"].has("26,0"), "export_save_data 包含 tiles 与正确 key")
	CropManager.clear_crop(pos)
	_assert(not CropManager.has_crop(pos), "清除后无作物")
	CropManager.import_save_data(exported)
	_assert(CropManager.has_crop(pos), "import 后作物恢复")
	var data := CropManager.get_crop_data(pos)
	_assert(data["crop_id"] == "carrot", "import 后 crop_id 正确")
	_assert(data["watered"] == true, "import 后 watered 状态正确")
	_cleanup(pos)


# ─── 辅助方法 ───

func _ensure_empty(pos: Vector2i) -> void:
	if CropManager.has_crop(pos):
		CropManager.clear_crop(pos)


func _cleanup(pos: Vector2i) -> void:
	if CropManager.has_crop(pos):
		CropManager.clear_crop(pos)


func _plant_and_force_mature(pos: Vector2i, crop_id: String) -> void:
	_ensure_empty(pos)
	var planted := CropManager.plant_crop(pos, crop_id)
	if not planted:
		push_error("[TestCropManager] 无法种植作物用于强制成熟测试: %s at %s" % [crop_id, pos])
		return
	# 直接修改内部数据强制设为 MATURE（测试用）
	var data: Dictionary = CropManager._crops[pos]
	data["stage"] = CropManager.CropStage.MATURE
	data["mature_timestamp"] = Time.get_unix_time_from_system()
	CropManager._sync_to_game_manager()


func _plant_and_force_wither(pos: Vector2i, crop_id: String) -> void:
	_ensure_empty(pos)
	var planted := CropManager.plant_crop(pos, crop_id)
	if not planted:
		push_error("[TestCropManager] 无法种植作物用于强制枯萎测试: %s at %s" % [crop_id, pos])
		return
	# 直接修改内部数据强制设为 WITHERED
	var data: Dictionary = CropManager._crops[pos]
	data["stage"] = CropManager.CropStage.WITHERED
	CropManager._sync_to_game_manager()


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
