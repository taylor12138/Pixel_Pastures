## Main — 入口场景脚本
## 负责初始化游戏流程：加载存档 → 显示状态
extends Node2D

@onready var debug_label: Label = $CanvasLayer/DebugLabel


func _ready() -> void:
	print("=== 像素田园 ===")
	print("[Main] Game starting...")

	# 尝试加载存档
	var load_result := SaveManager.load_game(0) if SaveManager.has_save(0) else {}
	var loaded := bool(load_result.get("success", false))

	# 更新调试标签
	_update_debug_info(loaded)

	# 连接信号用于实时调试
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.level_up.connect(_on_level_up)

	print("[Main] Ready! Press F5 in Godot to run.")


func _update_debug_info(loaded: bool) -> void:
	var status := "已加载存档" if loaded else "新游戏"
	debug_label.text = "像素田园 | %s | Lv.%d | 金币:%d | 第%d天" % [
		status,
		GameManager.level,
		GameManager.gold,
		GameManager.current_day,
	]


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	_update_debug_info(true)


func _on_level_up(_new_level: int) -> void:
	_update_debug_info(true)


func _input(event: InputEvent) -> void:
	# Esc 键暂停/保存
	if event.is_action_pressed("ui_pause"):
		var result := SaveManager.save_game(0)
		EventBus.ui_notification.emit("游戏已保存" if bool(result.get("success", false)) else "保存失败", "info" if bool(result.get("success", false)) else "warning")
