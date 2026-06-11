extends Node2D
## SaveManager 自动化测试脚本

@onready var label: Label = $Label
@onready var farm_grid_manager: Node = $FarmGridManager

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []

var _save_signal_count: int = 0
var _load_signal_count: int = 0
var _delete_signal_count: int = 0
var _auto_save_completed_count: int = 0
var _auto_save_failed_count: int = 0
var _save_failed_count: int = 0
var _load_failed_count: int = 0


func _ready() -> void:
	_connect_signals_once()
	print("=== SaveManager 自动化测试 ===")
	SaveManager.debug_delete_all_saves()
	_reset_runtime_state()

	test_directory_creation_and_paths()
	test_invalid_slots()
	test_save_success_and_metadata()
	test_load_success_round_trip()
	test_farm_grid_provider_round_trip()
	test_farm_grid_cache_survives_scene_exit()
	test_legacy_save_without_farm_grid()
	test_backup_overwrite()
	test_listing_metadata_has_save()
	test_delete_and_empty_delete()
	test_missing_corrupted_validation_and_migration()
	test_future_schema_rejected()
	test_auto_save_and_signals()

	SaveManager.debug_delete_all_saves()
	SaveManager.debug_reset_farm_grid_state()
	var summary := "=== SaveManager 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_directory_creation_and_paths() -> void:
	var result := SaveManager.ensure_save_dirs()
	_assert(result["success"] == true, "创建存档目录成功")
	_assert(DirAccess.dir_exists_absolute(SaveManager.SAVE_DIR), "user://saves/ 存在")
	_assert(DirAccess.dir_exists_absolute(SaveManager.BACKUP_DIR), "user://saves/backup/ 存在")
	_assert(SaveManager.get_save_path(0) == "user://saves/slot_0.json", "手动槽 0 路径正确")
	_assert(SaveManager.get_save_path(-1) == "user://saves/auto_save.json", "自动存档路径正确")


func test_invalid_slots() -> void:
	var save_result := SaveManager.save_game(9)
	var load_result := SaveManager.load_game(9)
	var delete_result := SaveManager.delete_save(9)
	_assert(save_result["success"] == false and save_result["error_code"] == SaveManager.ERR_INVALID_SLOT, "无效槽位保存被拒绝")
	_assert(load_result["success"] == false and load_result["error_code"] == SaveManager.ERR_INVALID_SLOT, "无效槽位读取被拒绝")
	_assert(delete_result["success"] == false and delete_result["error_code"] == SaveManager.ERR_INVALID_SLOT, "无效槽位删除被拒绝")


func test_save_success_and_metadata() -> void:
	_reset_runtime_state()
	InventoryManager.add_item("seed_carrot", 3)
	EconomyManager.buy_item("seed_carrot", 1)
	var result := SaveManager.save_game(0)
	_assert(result["success"] == true and result["operation"] == "save", "手动保存成功")
	_assert(FileAccess.file_exists(SaveManager.get_save_path(0)), "槽 0 存档文件已写入")
	_assert(_save_signal_count >= 1, "保存成功发射 game_saved")
	var data := SaveManager.build_save_data(0)
	_assert(data.has("schema_version") and data.has("metadata") and data.has("game"), "构建数据包含必要根字段")
	_assert(data.has("inventory") and data.has("crops") and data.has("economy") and data.has("level_system"), "构建数据包含管理器数据")
	_assert(data.has("farm_grid") and data["farm_grid"] is Dictionary, "构建数据包含 farm_grid 根字段")
	_assert(data["metadata"].has("level") and data["metadata"].has("summary"), "元数据包含等级与摘要")


func test_load_success_round_trip() -> void:
	_reset_runtime_state()
	GameManager.gold = 321
	LevelManager.add_xp(250, "manual")
	InventoryManager.add_item("seed_carrot", 5)
	CropManager.import_save_data({"tiles": {"2,3": {"crop_id": "carrot", "stage": 1, "watered": true, "water_timestamp": Time.get_unix_time_from_system(), "water_count": 1, "planted_timestamp": Time.get_unix_time_from_system(), "mature_timestamp": 0.0}}})
	EconomyManager.import_save_data({"total_gold_spent": 7, "total_gold_earned_from_sales": 8, "total_items_bought": 9, "total_items_sold": 10, "total_transactions": 11})
	var save_result := SaveManager.save_game(1)
	_assert(save_result["success"] == true, "保存复杂运行时状态成功")
	_reset_runtime_state()
	var load_result := SaveManager.load_game(1)
	_assert(load_result["success"] == true, "读取复杂运行时状态成功")
	_assert(GameManager.gold == 321, "读取恢复金币")
	_assert(GameManager.level == 3 and GameManager.xp == 250, "读取恢复并重算等级")
	_assert(InventoryManager.get_item_count("seed_carrot") == 5, "读取恢复背包物品")
	_assert(CropManager.has_crop(Vector2i(2, 3)), "读取恢复作物地块")
	_assert(EconomyManager.stats["total_transactions"] == 11, "读取恢复经济统计")
	_assert(_load_signal_count >= 1, "读取成功发射 game_loaded")


func test_farm_grid_provider_round_trip() -> void:
	_reset_runtime_state()
	farm_grid_manager.initialize_grid()
	farm_grid_manager.unlock_plots_by_count(20)
	farm_grid_manager.set_plot_state(Vector2i(5, 5), farm_grid_manager.PLOT_DRY_SOIL)
	farm_grid_manager.set_plot_state(Vector2i(6, 5), farm_grid_manager.PLOT_DRY_SOIL)
	farm_grid_manager.mark_tile_watered(Vector2i(6, 5))
	_assert(not SaveManager.register_farm_grid_manager(farm_grid_manager), "首次注册无缓存时不误报恢复")
	var save_result := SaveManager.save_game(0)
	_assert(save_result["success"] == true, "注册 FarmGridManager 后保存成功")
	farm_grid_manager.initialize_grid()
	var load_result := SaveManager.load_game(0)
	_assert(load_result["success"] == true, "活动 FarmGridManager 时加载成功")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 20, "加载立即恢复扩展解锁数量")
	_assert(farm_grid_manager.get_plot_state(Vector2i(5, 5)) == farm_grid_manager.PLOT_DRY_SOIL, "加载立即恢复 dry_soil")
	_assert(farm_grid_manager.get_plot_state(Vector2i(6, 5)) == farm_grid_manager.PLOT_WET_SOIL, "加载立即恢复 wet_soil")
	SaveManager.unregister_farm_grid_manager(farm_grid_manager)


func test_farm_grid_cache_survives_scene_exit() -> void:
	_reset_runtime_state()
	farm_grid_manager.initialize_grid()
	farm_grid_manager.unlock_plots_by_count(18)
	farm_grid_manager.set_plot_state(Vector2i(5, 5), farm_grid_manager.PLOT_DRY_SOIL)
	SaveManager.register_farm_grid_manager(farm_grid_manager)
	SaveManager.unregister_farm_grid_manager(farm_grid_manager)
	farm_grid_manager.initialize_grid()
	var restored := SaveManager.register_farm_grid_manager(farm_grid_manager)
	_assert(restored, "重新进入农场时注册会应用离场缓存")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 18, "重新进入农场恢复解锁数量")
	_assert(farm_grid_manager.get_plot_state(Vector2i(5, 5)) == farm_grid_manager.PLOT_DRY_SOIL, "重新进入农场恢复地块状态")
	SaveManager.unregister_farm_grid_manager(farm_grid_manager)
	var data := SaveManager.build_save_data(0)
	_assert(data["farm_grid"]["unlocked_plot_count"] == 18, "离开农场后保存仍保留缓存网格")


func test_legacy_save_without_farm_grid() -> void:
	_reset_runtime_state()
	var legacy_data := SaveManager.build_save_data(0)
	legacy_data.erase("farm_grid")
	_assert(SaveManager.validate_save_data(legacy_data)["success"], "旧存档缺少 farm_grid 仍通过校验")
	farm_grid_manager.initialize_grid()
	farm_grid_manager.unlock_plots_by_count(20)
	SaveManager.register_farm_grid_manager(farm_grid_manager)
	var apply_result := SaveManager.apply_save_data(legacy_data)
	_assert(apply_result["success"] == true, "旧存档缺少 farm_grid 仍可应用")
	_assert(farm_grid_manager.get_unlocked_plot_positions().size() == 12, "活动农场加载旧存档回退默认网格")
	SaveManager.unregister_farm_grid_manager(farm_grid_manager)
	SaveManager.debug_reset_farm_grid_state()


func test_backup_overwrite() -> void:
	_reset_runtime_state()
	SaveManager.save_game(2)
	GameManager.gold = 999
	var overwrite := SaveManager.save_game(2)
	_assert(overwrite["success"] == true, "覆盖存档成功")
	_assert(FileAccess.file_exists("user://saves/backup/slot_2.bak.json"), "覆盖前创建备份")


func test_listing_metadata_has_save() -> void:
	_reset_runtime_state()
	SaveManager.save_game(0)
	var metadata_result := SaveManager.get_save_metadata(0)
	var list := SaveManager.list_saves(true)
	_assert(SaveManager.has_save(0), "has_save 对有效存档返回 true")
	_assert(metadata_result["success"] == true and metadata_result["metadata"].has("gold"), "读取存档元数据成功")
	_assert(list.size() == 4, "列出 3 个手动槽和 1 个自动槽")


func test_delete_and_empty_delete() -> void:
	_reset_runtime_state()
	SaveManager.save_game(0)
	var delete_result := SaveManager.delete_save(0)
	var empty_result := SaveManager.delete_save(0)
	_assert(delete_result["success"] == true and not FileAccess.file_exists(SaveManager.get_save_path(0)), "删除已有存档成功")
	_assert(empty_result["success"] == true, "删除空槽也成功")
	_assert(_delete_signal_count >= 2, "删除成功发射 save_deleted")


func test_missing_corrupted_validation_and_migration() -> void:
	SaveManager.delete_save(0)
	var missing := SaveManager.load_game(0)
	_assert(missing["success"] == false and missing["error_code"] == SaveManager.ERR_SAVE_NOT_FOUND, "缺失存档读取失败且错误码稳定")
	var before_gold := GameManager.gold
	_write_raw_file(SaveManager.get_save_path(0), "{bad json")
	var corrupted := SaveManager.load_game(0)
	_assert(corrupted["success"] == false and corrupted["error_code"] == SaveManager.ERR_JSON_PARSE_FAILED, "损坏 JSON 读取失败")
	_assert(GameManager.gold == before_gold, "损坏读取不改变运行时状态")
	var invalid := SaveManager.validate_save_data({"schema_version": 1, "slot": 0})
	_assert(invalid["success"] == false and invalid["error_code"] == SaveManager.ERR_INVALID_SAVE_DATA, "缺少根字段校验失败")
	var current_data := SaveManager.build_save_data(0)
	current_data["schema_version"] = 0
	var migrated := SaveManager.migrate_save_data(current_data)
	_assert(migrated["success"] == true and migrated["data"]["schema_version"] == SaveManager.CURRENT_SCHEMA_VERSION, "v0 迁移到当前版本")


func test_future_schema_rejected() -> void:
	var data := SaveManager.build_save_data(0)
	data["schema_version"] = SaveManager.CURRENT_SCHEMA_VERSION + 1
	var validation := SaveManager.validate_save_data(data)
	_assert(validation["success"] == false and validation["error_code"] == SaveManager.ERR_UNSUPPORTED_SCHEMA_VERSION, "未来 schema 被拒绝")


func test_auto_save_and_signals() -> void:
	_reset_runtime_state()
	SaveManager.set_auto_save_enabled(false)
	SaveManager.set_auto_save_interval(1.0)
	GameManager.gold = 111
	var manual_result := SaveManager.save_game(0)
	GameManager.gold = 222
	var result := SaveManager.auto_save_now()
	var manual_read := SaveManager.read_save_file(0)
	_assert(manual_result["success"] == true, "自动存档前手动槽准备成功")
	_assert(result["success"] == true, "立即自动存档成功")
	_assert(FileAccess.file_exists(SaveManager.get_save_path(SaveManager.AUTO_SAVE_SLOT)), "自动存档写入专用文件")
	_assert(manual_read["success"] == true and int(manual_read["data"]["metadata"]["gold"]) == 111, "自动存档不覆盖手动槽")
	_assert(_auto_save_completed_count >= 1, "自动存档成功发射 auto_save_completed")


func _reset_runtime_state() -> void:
	SaveManager.debug_reset_farm_grid_state()
	GameManager.new_game("测试农夫")
	InventoryManager.debug_clear()
	CropManager.import_save_data({"tiles": {}})
	EconomyManager.debug_reset_stats()
	LevelManager.debug_reset_progress()
	GameManager.current_state = GameManager.GameState.PLAYING


func _write_raw_file(path: String, text: String) -> void:
	SaveManager.ensure_save_dirs()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _connect_signals_once() -> void:
	if not EventBus.game_saved.is_connected(_on_game_saved):
		EventBus.game_saved.connect(_on_game_saved)
	if not EventBus.game_loaded.is_connected(_on_game_loaded):
		EventBus.game_loaded.connect(_on_game_loaded)
	if not EventBus.save_deleted.is_connected(_on_save_deleted):
		EventBus.save_deleted.connect(_on_save_deleted)
	if not EventBus.auto_save_completed.is_connected(_on_auto_save_completed):
		EventBus.auto_save_completed.connect(_on_auto_save_completed)
	if not EventBus.auto_save_failed.is_connected(_on_auto_save_failed):
		EventBus.auto_save_failed.connect(_on_auto_save_failed)
	if not EventBus.game_save_failed.is_connected(_on_game_save_failed):
		EventBus.game_save_failed.connect(_on_game_save_failed)
	if not EventBus.game_load_failed.is_connected(_on_game_load_failed):
		EventBus.game_load_failed.connect(_on_game_load_failed)


func _on_game_saved(_slot: int, _metadata: Dictionary) -> void:
	_save_signal_count += 1


func _on_game_loaded(_slot: int, _metadata: Dictionary) -> void:
	_load_signal_count += 1


func _on_save_deleted(_slot: int) -> void:
	_delete_signal_count += 1


func _on_auto_save_completed(_result: Dictionary) -> void:
	_auto_save_completed_count += 1


func _on_auto_save_failed(_result: Dictionary) -> void:
	_auto_save_failed_count += 1


func _on_game_save_failed(_slot: int, _error_code: String, _message: String) -> void:
	_save_failed_count += 1


func _on_game_load_failed(_slot: int, _error_code: String, _message: String) -> void:
	_load_failed_count += 1


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
