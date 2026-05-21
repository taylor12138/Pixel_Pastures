## SceneManager — 场景切换与过渡管理
extends Node

## 场景路径常量
const SCENES := {
	"main": "res://scenes/main/main.tscn",
	"farm": "res://scenes/farm/farm.tscn",
	"shop": "res://scenes/ui/shop.tscn",
}

## 当前场景名
var current_scene_name: String = ""

## 是否正在切换
var _is_transitioning: bool = false


func _ready() -> void:
	print("[SceneManager] Initialized")


## 切换场景（直接切换，后续可加过渡动画）
func change_scene(target_scene: String) -> void:
	if _is_transitioning:
		push_warning("[SceneManager] Already transitioning, ignoring request")
		return

	var scene_path: String = ""
	if SCENES.has(target_scene):
		scene_path = SCENES[target_scene]
	elif target_scene.begins_with("res://"):
		scene_path = target_scene
	else:
		push_error("[SceneManager] Unknown scene: " + target_scene)
		return

	_is_transitioning = true
	current_scene_name = target_scene

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[SceneManager] Failed to load scene: " + scene_path)

	_is_transitioning = false


## 重新加载当前场景
func reload_current_scene() -> void:
	get_tree().reload_current_scene()


## 退出游戏
func quit_game() -> void:
	GameManager.save_game()
	get_tree().quit()
