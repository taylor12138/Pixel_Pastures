extends Control
## HUD — 田园场景常驻信息展示层。

const PHASE_LABELS := {
	"morning": "早晨",
	"afternoon": "下午",
	"evening": "傍晚",
	"night": "夜晚",
}
const ACTION_LABELS := {
	"plant": "种植",
	"water": "浇水",
	"harvest": "收获",
	"clear": "清除",
}

var context: Node = null
var _has_interaction_target: bool = false
var _last_preview_action: String = ""
var _last_preview_reason: String = ""

@onready var clock_label: Label = $TopBar/TimePanel/TimeMargin/TimeVBox/ClockLabel
@onready var date_label: Label = $TopBar/TimePanel/TimeMargin/TimeVBox/DateLabel
@onready var phase_label: Label = $TopBar/TimePanel/TimeMargin/TimeVBox/PhaseLabel
@onready var gold_label: Label = $TopBar/StatsPanel/StatsMargin/StatsVBox/GoldLabel
@onready var level_label: Label = $TopBar/StatsPanel/StatsMargin/StatsVBox/LevelRow/LevelLabel
@onready var xp_bar: ProgressBar = $TopBar/StatsPanel/StatsMargin/StatsVBox/LevelRow/XpBar
@onready var xp_label: Label = $TopBar/StatsPanel/StatsMargin/StatsVBox/XpLabel
@onready var interaction_prompt: PanelContainer = $InteractionPrompt
@onready var prompt_label: Label = $InteractionPrompt/PromptMargin/PromptLabel
@onready var hotbar: HBoxContainer = $HotbarRoot/Hotbar


func _ready() -> void:
	_connect_events()
	refresh_all()
	set_interaction_prompt("")


func setup(value: Node = null) -> void:
	context = value
	refresh_all()


func refresh_all() -> void:
	if not is_node_ready():
		return
	refresh_time()
	refresh_gold()
	refresh_level()
	refresh_hotbar()


func refresh_time() -> void:
	if not is_node_ready():
		return
	clock_label.text = TimeManager.get_time_text()
	date_label.text = TimeManager.get_date_text()
	phase_label.text = PHASE_LABELS.get(TimeManager.get_day_phase(), TimeManager.get_day_phase())


func refresh_gold() -> void:
	if not is_node_ready():
		return
	gold_label.text = "金币 %d" % GameManager.gold


func refresh_level() -> void:
	if not is_node_ready():
		return
	var progress: Dictionary = (
		LevelManager.get_xp_progress()
		if has_node("/root/LevelManager")
		else GameManager.get_xp_progress()
	)
	var is_max_level := bool(progress.get("is_max_level", false))
	level_label.text = "Lv.%d" % GameManager.level
	xp_bar.min_value = 0.0
	xp_bar.max_value = 100.0
	xp_bar.value = 100.0 if is_max_level else clampf(float(progress.get("progress_ratio", progress.get("progress", 0.0))) * 100.0, 0.0, 100.0)
	if is_max_level:
		xp_label.text = "MAX"
	else:
		var current_xp := int(progress.get("current_xp", GameManager.xp))
		var next_xp := int(progress.get("xp_for_next_level", current_xp))
		xp_label.text = "%d / %d" % [current_xp, next_xp]


func refresh_hotbar() -> void:
	if is_node_ready() and hotbar != null:
		hotbar.refresh_all()


func set_interaction_prompt(text: String) -> void:
	if not is_node_ready():
		return
	prompt_label.text = text
	interaction_prompt.visible = text != ""


func set_hud_visible(value: bool) -> void:
	visible = value


func _connect_events() -> void:
	if not EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.connect(_on_minute_changed)
	if not EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.connect(_on_hour_changed)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.connect(_on_season_changed)
	if not EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.connect(_on_day_phase_changed)
	if not EventBus.gold_changed.is_connected(_on_gold_changed):
		EventBus.gold_changed.connect(_on_gold_changed)
	if not EventBus.xp_gained.is_connected(_on_xp_gained):
		EventBus.xp_gained.connect(_on_xp_gained)
	if not EventBus.level_up.is_connected(_on_level_up):
		EventBus.level_up.connect(_on_level_up)
	if not EventBus.player_interaction_target_changed.is_connected(_on_player_interaction_target_changed):
		EventBus.player_interaction_target_changed.connect(_on_player_interaction_target_changed)
	if not EventBus.farm_tile_action_preview_changed.is_connected(_on_farm_tile_action_preview_changed):
		EventBus.farm_tile_action_preview_changed.connect(_on_farm_tile_action_preview_changed)
	if not EventBus.game_loaded.is_connected(_on_game_loaded):
		EventBus.game_loaded.connect(_on_game_loaded)


func _refresh_interaction_prompt() -> void:
	if not _has_interaction_target or _last_preview_reason != "" or not ACTION_LABELS.has(_last_preview_action):
		set_interaction_prompt("")
		return
	set_interaction_prompt("按 E %s" % ACTION_LABELS[_last_preview_action])


func _on_minute_changed(_hour: int, _minute: int) -> void:
	clock_label.text = TimeManager.get_time_text()


func _on_hour_changed(_hour: int) -> void:
	clock_label.text = TimeManager.get_time_text()


func _on_day_started(_year: int, _season: String, _day: int) -> void:
	date_label.text = TimeManager.get_date_text()


func _on_season_changed(_season: String) -> void:
	date_label.text = TimeManager.get_date_text()


func _on_day_phase_changed(phase: String) -> void:
	phase_label.text = PHASE_LABELS.get(phase, phase)


func _on_gold_changed(new_amount: int, _delta: int) -> void:
	gold_label.text = "金币 %d" % new_amount


func _on_xp_gained(_amount: int, _source: String) -> void:
	refresh_level()


func _on_level_up(_new_level: int) -> void:
	refresh_level()


func _on_player_interaction_target_changed(target: Dictionary) -> void:
	_has_interaction_target = not target.is_empty()
	if not _has_interaction_target:
		_last_preview_action = ""
		_last_preview_reason = ""
	_refresh_interaction_prompt()


func _on_farm_tile_action_preview_changed(_tile_pos: Vector2i, action: String, reason: String) -> void:
	_last_preview_action = action
	_last_preview_reason = reason
	_refresh_interaction_prompt()


func _on_game_loaded(_slot: int, _metadata: Dictionary) -> void:
	refresh_all()
	set_interaction_prompt("")
