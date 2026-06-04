extends Node2D
## RegressionRunner — 一键顺序运行核心测试场景并汇总结果。

@onready var label: Label = $Label

const TEST_SCENES: Array[Dictionary] = [
	{"name": "CropManager", "path": "res://scenes/test/test_crop_manager.tscn"},
	{"name": "InventoryManager", "path": "res://scenes/test/test_inventory_manager.tscn"},
	{"name": "LevelManager", "path": "res://scenes/test/test_level_manager.tscn"},
	{"name": "EconomyManager", "path": "res://scenes/test/test_economy_manager.tscn"},
	{"name": "FarmGridManager", "path": "res://scenes/test/test_farm_grid_manager.tscn"},
	{"name": "PlayerController", "path": "res://scenes/test/test_player_controller.tscn"},
	{"name": "FarmInteractionController", "path": "res://scenes/test/test_farm_interaction_controller.tscn"},
	{"name": "SaveManager", "path": "res://scenes/test/test_save_manager.tscn"},
	{"name": "TimeManager", "path": "res://scenes/test/test_time_manager.tscn"},
]

var _current_index: int = -1
var _current_scene: Node = null
var _total_passed: int = 0
var _total_failed: int = 0
var _lines: PackedStringArray = []


func _ready() -> void:
	_lines.append("=== 核心回归测试开始 ===")
	_update_label()
	call_deferred("_run_next_test")


func _run_next_test() -> void:
	if _current_scene != null:
		_collect_current_result()
		_current_scene.queue_free()
		_current_scene = null
		await get_tree().process_frame
	_current_index += 1
	if _current_index >= TEST_SCENES.size():
		_finish()
		return
	var test_info: Dictionary = TEST_SCENES[_current_index]
	_lines.append("")
	_lines.append("Running %s..." % str(test_info["name"]))
	_update_label()
	var packed: PackedScene = load(str(test_info["path"]))
	if packed == null:
		_lines.append("[FAIL] %s 场景加载失败: %s" % [str(test_info["name"]), str(test_info["path"])])
		_total_failed += 1
		call_deferred("_run_next_test")
		return
	_current_scene = packed.instantiate()
	add_child(_current_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	call_deferred("_run_next_test")


func _collect_current_result() -> void:
	var test_info: Dictionary = TEST_SCENES[_current_index]
	var passed := _read_int_property(_current_scene, "_passed")
	var failed := _read_int_property(_current_scene, "_failed")
	_total_passed += passed
	_total_failed += failed
	var status := "PASS" if failed == 0 else "FAIL"
	_lines.append("[%s] %s: %d 通过, %d 失败" % [status, str(test_info["name"]), passed, failed])
	_update_label()


func _finish() -> void:
	_lines.append("")
	_lines.append("=== 核心回归测试完成: %d 通过, %d 失败 ===" % [_total_passed, _total_failed])
	_update_label()
	print("\n".join(_lines))


func _read_int_property(node: Node, property_name: String) -> int:
	if node == null:
		return 0
	var value = node.get(property_name)
	if value == null:
		return 0
	return int(value)


func _update_label() -> void:
	if label != null:
		label.text = "\n".join(_lines)
