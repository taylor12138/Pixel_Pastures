extends Node
## TimeManager — 游戏内时间、日期、季节与昼夜管理器

const DEFAULT_YEAR := 1
const DEFAULT_SEASON := "spring"
const DEFAULT_SEASON_INDEX := 0
const DEFAULT_DAY := 1
const DEFAULT_HOUR := 6
const DEFAULT_MINUTE := 0
const DEFAULT_TIME_SCALE := 60.0
const MIN_TIME_SCALE := 0.01
const DAYS_PER_SEASON := 28
const HOURS_PER_DAY := 24
const MINUTES_PER_HOUR := 60
const GAME_SECONDS_PER_MINUTE := 60.0

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := {
	"spring": "春季",
	"summer": "夏季",
	"autumn": "秋季",
	"winter": "冬季",
}

const PHASE_MORNING := "morning"
const PHASE_AFTERNOON := "afternoon"
const PHASE_EVENING := "evening"
const PHASE_NIGHT := "night"

var year: int = DEFAULT_YEAR
var season_index: int = DEFAULT_SEASON_INDEX
var season: String = DEFAULT_SEASON
var day: int = DEFAULT_DAY
var hour: int = DEFAULT_HOUR
var minute: int = DEFAULT_MINUTE
var day_phase: String = PHASE_MORNING
var time_scale: float = DEFAULT_TIME_SCALE
var paused: bool = false
var total_game_minutes: int = 0
var _game_second_accumulator: float = 0.0


func _ready() -> void:
	initialize_new_game()
	set_process(true)


func _process(delta: float) -> void:
	if paused:
		return
	if not _is_game_playing():
		return
	_game_second_accumulator += delta * time_scale
	while _game_second_accumulator >= GAME_SECONDS_PER_MINUTE:
		_game_second_accumulator -= GAME_SECONDS_PER_MINUTE
		_advance_one_minute()


## 初始化新游戏默认时间。
func initialize_new_game() -> void:
	year = DEFAULT_YEAR
	season_index = DEFAULT_SEASON_INDEX
	season = DEFAULT_SEASON
	day = DEFAULT_DAY
	hour = DEFAULT_HOUR
	minute = DEFAULT_MINUTE
	time_scale = DEFAULT_TIME_SCALE
	paused = false
	total_game_minutes = 0
	_game_second_accumulator = 0.0
	day_phase = _calculate_day_phase(hour)


## 返回完整时间状态副本。
func get_time_state() -> Dictionary:
	return {
		"year": year,
		"season": season,
		"season_index": season_index,
		"season_name": get_season_name(),
		"day": day,
		"hour": hour,
		"minute": minute,
		"day_phase": day_phase,
		"time_scale": time_scale,
		"paused": paused,
		"total_game_minutes": total_game_minutes,
		"time_text": get_time_text(),
		"date_text": get_date_text(),
		"datetime_text": get_datetime_text(),
	}.duplicate(true)


func get_year() -> int:
	return year


func get_season() -> String:
	return season


func get_season_index() -> int:
	return season_index


func get_season_name() -> String:
	return str(SEASON_NAMES.get(season, season))


func get_day() -> int:
	return day


func get_hour() -> int:
	return hour


func get_minute() -> int:
	return minute


func get_day_phase() -> String:
	return day_phase


func get_total_game_minutes() -> int:
	return total_game_minutes


func get_time_text() -> String:
	return "%02d:%02d" % [hour, minute]


func get_date_text() -> String:
	return "第%d年 %s %d日" % [year, get_season_name(), day]


func get_datetime_text() -> String:
	return "%s %s" % [get_date_text(), get_time_text()]


## 暂停游戏内时间推进。
func pause_time() -> void:
	set_time_paused(true)


## 恢复游戏内时间推进。
func resume_time() -> void:
	set_time_paused(false)


## 设置时间暂停状态并广播变化。
func set_time_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	if has_node("/root/EventBus"):
		EventBus.time_paused_changed.emit(paused)


func is_time_paused() -> bool:
	return paused


## 设置时间倍率，非法值会修正为默认倍率。
func set_time_scale(scale: float) -> void:
	var next_scale := float(scale)
	if next_scale <= 0.0:
		push_warning("[TimeManager] 非法时间倍率 %.2f，已重置为默认倍率" % next_scale)
		next_scale = DEFAULT_TIME_SCALE
	next_scale = maxf(next_scale, MIN_TIME_SCALE)
	if is_equal_approx(time_scale, next_scale):
		return
	time_scale = next_scale
	if has_node("/root/EventBus"):
		EventBus.time_scale_changed.emit(time_scale)


func get_time_scale() -> float:
	return time_scale


## 按分钟推进游戏内时间。
func advance_minutes(minutes_to_advance: int) -> void:
	var count := maxi(minutes_to_advance, 0)
	for i in range(count):
		_advance_one_minute()


## 按小时推进游戏内时间。
func advance_hours(hours_to_advance: int) -> void:
	advance_minutes(maxi(hours_to_advance, 0) * MINUTES_PER_HOUR)


## 推进到下一天 00:00。
func advance_to_next_day() -> void:
	var minutes_until_next_day := ((HOURS_PER_DAY - hour - 1) * MINUTES_PER_HOUR) + (MINUTES_PER_HOUR - minute)
	advance_minutes(minutes_until_next_day)


## 调试设置日期时间，输入会被合法化。
func debug_set_datetime(new_year: int, new_season: String, new_day: int, new_hour: int, new_minute: int) -> void:
	year = maxi(new_year, 1)
	season_index = _normalize_season_index(new_season)
	season = SEASONS[season_index]
	day = clampi(new_day, 1, DAYS_PER_SEASON)
	hour = clampi(new_hour, 0, HOURS_PER_DAY - 1)
	minute = clampi(new_minute, 0, MINUTES_PER_HOUR - 1)
	_game_second_accumulator = 0.0
	_update_day_phase(true)


## 调试输出当前时间。
func debug_print_time() -> void:
	print("[TimeManager] %s | phase=%s | scale=%.2f | paused=%s" % [get_datetime_text(), day_phase, time_scale, str(paused)])


func is_night() -> bool:
	return day_phase == PHASE_NIGHT


func is_after_midnight() -> bool:
	return hour >= 0 and hour < DEFAULT_HOUR


## 导出 JSON 可序列化时间状态。
func export_save_data() -> Dictionary:
	return {
		"year": year,
		"season": season,
		"season_index": season_index,
		"day": day,
		"hour": hour,
		"minute": minute,
		"time_scale": time_scale,
		"paused": paused,
		"total_game_minutes": total_game_minutes,
		"day_phase": day_phase,
	}.duplicate(true)


## 导入时间存档数据，非法值会被修正。
func import_save_data(data: Dictionary) -> void:
	if data.is_empty():
		initialize_new_game()
		return
	year = maxi(int(data.get("year", DEFAULT_YEAR)), 1)
	if data.has("season"):
		season_index = _normalize_season_index(str(data.get("season", DEFAULT_SEASON)))
	else:
		season_index = clampi(int(data.get("season_index", DEFAULT_SEASON_INDEX)), 0, SEASONS.size() - 1)
	season = SEASONS[season_index]
	day = clampi(int(data.get("day", DEFAULT_DAY)), 1, DAYS_PER_SEASON)
	hour = clampi(int(data.get("hour", DEFAULT_HOUR)), 0, HOURS_PER_DAY - 1)
	minute = clampi(int(data.get("minute", DEFAULT_MINUTE)), 0, MINUTES_PER_HOUR - 1)
	time_scale = float(data.get("time_scale", DEFAULT_TIME_SCALE))
	if time_scale <= 0.0:
		push_warning("[TimeManager] 存档时间倍率非法，已重置为默认倍率")
		time_scale = DEFAULT_TIME_SCALE
	paused = bool(data.get("paused", false))
	total_game_minutes = maxi(int(data.get("total_game_minutes", total_game_minutes)), 0)
	_game_second_accumulator = 0.0
	day_phase = _calculate_day_phase(hour)


func can_plant_crop_in_current_season(crop_id: String) -> bool:
	return can_plant_crop_in_season(crop_id, season)


func can_plant_crop_in_season(crop_id: String, season_id: String) -> bool:
	if not has_node("/root/DataManager"):
		return false
	var crop := DataManager.get_crop(crop_id)
	if crop.is_empty() or not crop.get("seasons", []) is Array:
		return false
	return season_id in crop.get("seasons", [])


func get_current_season_crops() -> Array:
	if not has_node("/root/DataManager"):
		return []
	return DataManager.get_crops_by_season(season)


func _advance_one_minute() -> void:
	minute += 1
	total_game_minutes += 1
	if minute >= MINUTES_PER_HOUR:
		minute = 0
		_advance_one_hour()
	if has_node("/root/EventBus"):
		EventBus.minute_changed.emit(hour, minute)
	_update_day_phase()


func _advance_one_hour() -> void:
	hour += 1
	if hour >= HOURS_PER_DAY:
		hour = 0
		_advance_one_day()
	if has_node("/root/EventBus"):
		EventBus.hour_changed.emit(hour)


func _advance_one_day() -> void:
	if has_node("/root/EventBus"):
		EventBus.midnight_crossed.emit()
	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		_advance_one_season()
	if has_node("/root/EventBus"):
		EventBus.day_started.emit(year, season, day)


func _advance_one_season() -> void:
	season_index += 1
	if season_index >= SEASONS.size():
		season_index = 0
		_advance_one_year()
	season = SEASONS[season_index]
	if has_node("/root/EventBus"):
		EventBus.season_changed.emit(season)


func _advance_one_year() -> void:
	year += 1
	if has_node("/root/EventBus"):
		EventBus.year_changed.emit(year)


func _update_day_phase(force_emit: bool = false) -> void:
	var new_phase := _calculate_day_phase(hour)
	if day_phase == new_phase and not force_emit:
		return
	day_phase = new_phase
	if has_node("/root/EventBus"):
		EventBus.day_phase_changed.emit(day_phase)


func _calculate_day_phase(value_hour: int) -> String:
	if value_hour >= 6 and value_hour <= 11:
		return PHASE_MORNING
	if value_hour >= 12 and value_hour <= 17:
		return PHASE_AFTERNOON
	if value_hour >= 18 and value_hour <= 20:
		return PHASE_EVENING
	return PHASE_NIGHT


func _normalize_season_index(value: String) -> int:
	var normalized := value.strip_edges().to_lower()
	var index := SEASONS.find(normalized)
	if index == -1:
		push_warning("[TimeManager] 未知季节 %s，已重置为 spring" % value)
		return DEFAULT_SEASON_INDEX
	return index


func _is_game_playing() -> bool:
	return has_node("/root/GameManager") and GameManager.current_state == GameManager.GameState.PLAYING
