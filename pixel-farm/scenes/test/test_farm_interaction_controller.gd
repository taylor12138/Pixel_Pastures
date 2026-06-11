extends Node2D
## FarmInteractionController 自动化测试脚本

@onready var farm_grid_manager: Node = $FarmGridManager
@onready var farm_interaction_controller: Node = $FarmInteractionController
@onready var crop_overlay: Node2D = $CropOverlay
@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []


func _ready() -> void:
	print("=== FarmInteractionController 自动化测试 ===")
	_prepare_base_state()

	test_plant_success()
	test_plant_failures()
	test_water_success_and_repeat_failure()
	test_growth_stage_needs_water_again()
	test_harvest_flow()
	test_harvest_inventory_full()
	test_clear_withered()
	test_auto_resolve_priority()
	test_reconcile_grid_with_crops()
	test_reconcile_unlocks_legacy_crop_tile()
	test_reconcile_preserves_unoccupied_soil_states()
	test_hotbar_sync_and_debug_selection()

	var summary := "=== FarmInteractionController 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_plant_success() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	farm_interaction_controller.select_seed("carrot")
	var before_seeds := InventoryManager.get_item_count("seed_carrot")
	var result: Dictionary = farm_interaction_controller.try_plant(tile_pos, "carrot")
	_assert(result["success"] == true and result["action"] == "plant", "空地种植成功返回 plant success")
	_assert(CropManager.has_crop(tile_pos), "种植后 CropManager 有作物")
	_assert(farm_grid_manager.is_tile_occupied(tile_pos), "种植后 Grid 标记 occupied")
	_assert(InventoryManager.get_item_count("seed_carrot") == before_seeds - 1, "种植成功消耗 1 个种子")


func test_plant_failures() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	InventoryManager.remove_item("seed_carrot", InventoryManager.get_item_count("seed_carrot"))
	var no_seed: Dictionary = farm_interaction_controller.try_plant(tile_pos, "carrot")
	_assert(no_seed["reason"] == "seed_missing", "无种子种植失败返回 seed_missing")
	_assert(not CropManager.has_crop(tile_pos) and not farm_grid_manager.is_tile_occupied(tile_pos), "无种子失败不修改作物和地块")

	_prepare_base_state()
	var locked: Dictionary = farm_interaction_controller.try_plant(Vector2i(8, 5), "carrot")
	_assert(locked["reason"] == "tile_locked" or locked["reason"] == "tile_not_plantable", "锁定地块种植失败")

	_prepare_base_state()
	var first: Dictionary = farm_interaction_controller.try_plant(tile_pos, "carrot")
	var repeat: Dictionary = farm_interaction_controller.try_plant(tile_pos, "carrot")
	_assert(first["success"] and repeat["reason"] == "crop_exists", "重复种植失败返回 crop_exists")


func test_water_success_and_repeat_failure() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	farm_interaction_controller.try_plant(tile_pos, "carrot")
	farm_interaction_controller.select_tool("watering_can")
	var water: Dictionary = farm_interaction_controller.try_water(tile_pos)
	var crop_data := CropManager.get_crop_data(tile_pos)
	_assert(water["success"] == true and water["action"] == "water", "浇水成功返回 water success")
	_assert(crop_data["watered"] == true and crop_data["water_count"] == 1, "浇水后 watered=true 且 water_count+1")
	var repeat: Dictionary = farm_interaction_controller.try_water(tile_pos)
	_assert(repeat["reason"] == "crop_does_not_need_water", "重复浇水失败返回 crop_does_not_need_water")


func test_growth_stage_needs_water_again() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	farm_interaction_controller.try_plant(tile_pos, "carrot")
	farm_interaction_controller.try_water(tile_pos)
	CropManager.debug_advance_time(tile_pos, 20.0)
	var crop_data := CropManager.get_crop_data(tile_pos)
	_assert(crop_data["stage"] == CropManager.CropStage.SPROUT, "调试推进后作物进入 SPROUT")
	_assert(crop_data["watered"] == false and CropManager.needs_water(tile_pos), "阶段推进后需要再次浇水")


func test_harvest_flow() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	farm_interaction_controller.try_plant(tile_pos, "carrot")
	var early: Dictionary = farm_interaction_controller.try_harvest(tile_pos)
	_assert(early["reason"] == "crop_not_mature", "未成熟收获失败返回 crop_not_mature")
	_force_crop_stage(tile_pos, CropManager.CropStage.MATURE)
	var before_harvest := InventoryManager.get_item_count("harvest_carrot")
	var harvest: Dictionary = farm_interaction_controller.try_harvest(tile_pos)
	_assert(harvest["success"] == true and harvest["action"] == "harvest", "成熟收获成功")
	_assert(InventoryManager.get_item_count("harvest_carrot") == before_harvest + 1, "收获后背包增加 harvest_carrot")
	_assert(not CropManager.has_crop(tile_pos) and not farm_grid_manager.is_tile_occupied(tile_pos), "收获后作物移除且地块恢复")


func test_harvest_inventory_full() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	farm_interaction_controller.try_plant(tile_pos, "carrot")
	_force_crop_stage(tile_pos, CropManager.CropStage.MATURE)
	InventoryManager.debug_clear()
	InventoryManager.add_item("watering_can", InventoryManager.MAX_SLOTS)
	var result: Dictionary = farm_interaction_controller.try_harvest(tile_pos)
	_assert(result["reason"] == "inventory_full", "背包满收获失败返回 inventory_full")
	_assert(CropManager.has_crop(tile_pos) and farm_grid_manager.is_tile_occupied(tile_pos), "背包满收获失败不清作物和地块")


func test_clear_withered() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	farm_interaction_controller.try_plant(tile_pos, "carrot")
	var not_withered: Dictionary = farm_interaction_controller.try_clear(tile_pos)
	_assert(not_withered["reason"] == "crop_not_withered", "非枯萎作物清除失败")
	_force_crop_stage(tile_pos, CropManager.CropStage.WITHERED)
	var before_harvest := InventoryManager.get_item_count("harvest_carrot")
	var cleared: Dictionary = farm_interaction_controller.try_clear(tile_pos)
	_assert(cleared["success"] == true and cleared["action"] == "clear", "枯萎作物清除成功")
	_assert(InventoryManager.get_item_count("harvest_carrot") == before_harvest, "清除枯萎作物不增加收获物")
	_assert(not CropManager.has_crop(tile_pos) and not farm_grid_manager.is_tile_occupied(tile_pos), "清除后作物移除且地块恢复")


func test_auto_resolve_priority() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	farm_interaction_controller.auto_resolve_action = true
	farm_interaction_controller.select_seed("carrot")
	var plant: Dictionary = farm_interaction_controller.request_tile_interaction(tile_pos, "test")
	_assert(plant["action"] == "plant" and plant["success"], "自动解析可在空地种植")
	farm_interaction_controller.select_tool("watering_can")
	var water: Dictionary = farm_interaction_controller.request_tile_interaction(tile_pos, "test")
	_assert(water["action"] == "water" and water["success"], "自动解析可对需水作物浇水")
	_force_crop_stage(tile_pos, CropManager.CropStage.MATURE)
	var harvest: Dictionary = farm_interaction_controller.request_tile_interaction(tile_pos, "test")
	_assert(harvest["action"] == "harvest" and harvest["success"], "自动解析成熟优先收获")

	_prepare_base_state()
	farm_interaction_controller.try_plant(tile_pos, "carrot")
	_force_crop_stage(tile_pos, CropManager.CropStage.WITHERED)
	var clear: Dictionary = farm_interaction_controller.request_tile_interaction(tile_pos, "test")
	_assert(clear["action"] == "clear" and clear["success"], "自动解析枯萎优先清除")


func test_reconcile_grid_with_crops() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(5, 5)
	CropManager.plant_crop(tile_pos, "carrot")
	_assert(not farm_grid_manager.is_tile_occupied(tile_pos), "测试准备：只有作物无 grid occupied")
	farm_interaction_controller.reconcile_grid_with_crops()
	_assert(farm_grid_manager.is_tile_occupied(tile_pos), "reconcile 恢复有作物地块 occupied")
	CropManager.clear_crop(tile_pos)
	_assert(farm_grid_manager.is_tile_occupied(tile_pos), "测试准备：只有 occupied 无作物")
	farm_interaction_controller.reconcile_grid_with_crops()
	_assert(not farm_grid_manager.is_tile_occupied(tile_pos), "reconcile 清理无作物 occupied 地块")


func test_reconcile_unlocks_legacy_crop_tile() -> void:
	_prepare_base_state()
	var tile_pos := Vector2i(8, 5)
	CropManager.import_save_data({
		"tiles": {
			"8,5": {
				"crop_id": "carrot",
				"stage": CropManager.CropStage.SEED,
				"watered": false,
			},
		},
	})
	_assert(not farm_grid_manager.is_plot_unlocked(tile_pos), "测试准备：旧存档作物格默认锁定")
	farm_interaction_controller.reconcile_grid_with_crops()
	_assert(farm_grid_manager.is_plot_unlocked(tile_pos), "reconcile 解锁旧存档作物格")
	_assert(farm_grid_manager.is_tile_occupied(tile_pos), "reconcile 将旧存档作物格标记 occupied")
	_assert(CropManager.has_crop(tile_pos), "reconcile 不删除旧存档作物")


func test_reconcile_preserves_unoccupied_soil_states() -> void:
	_prepare_base_state()
	var dry_tile := Vector2i(5, 5)
	var wet_tile := Vector2i(6, 5)
	farm_grid_manager.set_plot_state(dry_tile, farm_grid_manager.PLOT_DRY_SOIL)
	farm_grid_manager.set_plot_state(wet_tile, farm_grid_manager.PLOT_DRY_SOIL)
	farm_grid_manager.mark_tile_watered(wet_tile)
	farm_interaction_controller.reconcile_grid_with_crops()
	_assert(farm_grid_manager.get_plot_state(dry_tile) == farm_grid_manager.PLOT_DRY_SOIL, "reconcile 保留无作物 dry_soil")
	_assert(farm_grid_manager.get_plot_state(wet_tile) == farm_grid_manager.PLOT_WET_SOIL, "reconcile 保留无作物 wet_soil")


func test_hotbar_sync_and_debug_selection() -> void:
	_prepare_base_state()
	InventoryManager.select_hotbar(0)
	farm_interaction_controller.sync_selection_from_hotbar()
	var selection: Dictionary = farm_interaction_controller.get_current_selection()
	_assert(selection["mode"] == "PLANT" and selection["selected_crop_id"] == "carrot", "快捷栏选中种子同步为 PLANT")
	InventoryManager.move_to_slot(0, 9)
	selection = farm_interaction_controller.get_current_selection()
	_assert(selection["mode"] == "NONE", "当前快捷栏物品移出后自动清空选择")
	var debug_tool_event := InputEventKey.new()
	debug_tool_event.pressed = true
	debug_tool_event.physical_keycode = KEY_4
	_assert(not farm_interaction_controller.handle_debug_key_event(debug_tool_event), "默认禁用数字键 4 调试直选")
	_assert(farm_interaction_controller.get_current_selection()["mode"] == "NONE", "禁用调试直选后不会恢复旧工具")


func _prepare_base_state() -> void:
	GameManager.start_new_game("交互测试农夫")
	CropManager.import_save_data({"tiles": {}})
	farm_grid_manager.initialize_grid()
	InventoryManager.debug_clear()
	InventoryManager.add_item("seed_carrot", 10)
	InventoryManager.add_item("seed_cabbage", 10)
	InventoryManager.add_item("watering_can", 1)
	farm_interaction_controller.setup(farm_grid_manager, crop_overlay)
	farm_interaction_controller.auto_resolve_action = true
	farm_interaction_controller.debug_mode = true


func _force_crop_stage(tile_pos: Vector2i, stage: int) -> void:
	if not CropManager.has_crop(tile_pos):
		return
	var crop_data: Dictionary = CropManager._crops[tile_pos]
	crop_data["stage"] = stage
	crop_data["watered"] = false
	if stage == CropManager.CropStage.MATURE:
		crop_data["mature_timestamp"] = Time.get_unix_time_from_system()
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
