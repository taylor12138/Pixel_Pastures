extends Node2D
## TimeManager 自动化测试脚本

@onready var label: Label = $Label

var _passed: int = 0
var _failed: int = 0
var _results: PackedStringArray = []

var _minute_signal_count: int = 0
var _hour_signal_count: int = 0
var _day_signal_count: int = 0
var _season_signal_count: int = 0
var _year_signal_count: int = 0
var _phase_signal_count: int = 0
var _midnight_signal_count: int = 0
var _scale_signal_count: int = 0
var _paused_signal_count: int = 0


func _ready() -> void:
	_connect_signals_once()
	print("=== TimeManager 自动化测试 ===")
	GameManager.current_state = GameManager.GameState.PLAYING

	test_initial_state_and_formatting()
	test_time_scale_and_pause()
	test_process_progression()
	test_hour_day_season_year_boundaries()
	test_day_phase_helpers()
	test_season_crop_queries()
	test_save_import_export_and_invalid_data()
	test_old_save_without_time_compatibility()

	var summary := "=== TimeManager 测试完成: %d 通过, %d 失败 ===" % [_passed, _failed]
	print(summary)
	_results.append(summary)
	label.text = "\n".join(_results)


func test_initial_state_and_formatting() -> void:
	TimeManager.initialize_new_game()
	_assert(TimeManager.get_year() == 1, "初始年份为 1")
	_assert(TimeManager.get_season() == "spring", "初始季节为 spring")
	_assert(TimeManager.get_day() == 1, "初始日期为第 1 天")
	_assert(TimeManager.get_hour() == 6 and TimeManager.get_minute() == 0, "初始时间为 06:00")
	_assert(TimeManager.get_day_phase() == "morning", "初始昼夜阶段为 morning")
	_assert(is_equal_approx(TimeManager.get_time_scale(), 60.0), "初始倍率为 60.0")
	_assert(TimeManager.get_time_text() == "06:00", "时间文本为 HH:MM")
	_assert(TimeManager.get_date_text().contains("第1年") and TimeManager.get_date_text().contains("春季") and TimeManager.get_date_text().contains("1日"), "日期文本包含中文年月日")
	_assert(TimeManager.get_time_state().has("datetime_text"), "完整状态包含 datetime_text")


func test_time_scale_and_pause() -> void:
	TimeManager.initialize_new_game()
	TimeManager.set_time_scale(120.0)
	_assert(is_equal_approx(TimeManager.get_time_scale(), 120.0), "设置合法倍率成功")
	_assert(_scale_signal_count >= 1, "倍率变化发射信号")
	TimeManager.set_time_scale(-1.0)
	_assert(is_equal_approx(TimeManager.get_time_scale(), TimeManager.DEFAULT_TIME_SCALE), "非法倍率重置为默认值")
	TimeManager.pause_time()
	_assert(TimeManager.is_time_paused(), "暂停接口设置 paused=true")
	TimeManager.resume_time()
	_assert(not TimeManager.is_time_paused(), "恢复接口设置 paused=false")
	_assert(_paused_signal_count >= 2, "暂停恢复发射信号")


func test_process_progression() -> void:
	TimeManager.initialize_new_game()
	GameManager.current_state = GameManager.GameState.PLAYING
	TimeManager._process(60.0)
	_assert(TimeManager.get_hour() == 7 and TimeManager.get_minute() == 0, "默认倍率 60 秒推进 1 游戏小时")
	TimeManager.pause_time()
	TimeManager._process(60.0)
	_assert(TimeManager.get_hour() == 7, "暂停时 _process 不推进")
	TimeManager.resume_time()
	GameManager.current_state = GameManager.GameState.PAUSED
	TimeManager._process(60.0)
	_assert(TimeManager.get_hour() == 7, "非 PLAYING 状态不推进")
	GameManager.current_state = GameManager.GameState.PLAYING


func test_hour_day_season_year_boundaries() -> void:
	TimeManager.debug_set_datetime(1, "spring", 1, 6, 59)
	TimeManager.advance_minutes(1)
	_assert(TimeManager.get_hour() == 7 and TimeManager.get_minute() == 0, "跨小时推进正确")
	_assert(_minute_signal_count >= 1 and _hour_signal_count >= 1, "分钟和小时信号已发射")
	TimeManager.debug_set_datetime(1, "spring", 1, 23, 59)
	TimeManager.advance_minutes(1)
	_assert(TimeManager.get_day() == 2 and TimeManager.get_hour() == 0 and TimeManager.get_minute() == 0, "跨日推进到次日 00:00")
	_assert(_midnight_signal_count >= 1 and _day_signal_count >= 1, "跨日信号已发射")
	TimeManager.debug_set_datetime(1, "spring", 28, 23, 59)
	TimeManager.advance_minutes(1)
	_assert(TimeManager.get_season() == "summer" and TimeManager.get_day() == 1, "春季结束后进入夏季")
	_assert(_season_signal_count >= 1, "季节变化信号已发射")
	TimeManager.debug_set_datetime(1, "winter", 28, 23, 59)
	TimeManager.advance_minutes(1)
	_assert(TimeManager.get_year() == 2 and TimeManager.get_season() == "spring" and TimeManager.get_day() == 1, "冬季结束后进入下一年春季")
	_assert(_year_signal_count >= 1, "年份变化信号已发射")


func test_day_phase_helpers() -> void:
	TimeManager.debug_set_datetime(1, "spring", 1, 12, 0)
	_assert(TimeManager.get_day_phase() == "afternoon", "12 点为 afternoon")
	TimeManager.debug_set_datetime(1, "spring", 1, 18, 0)
	_assert(TimeManager.get_day_phase() == "evening", "18 点为 evening")
	TimeManager.debug_set_datetime(1, "spring", 1, 21, 0)
	_assert(TimeManager.get_day_phase() == "night" and TimeManager.is_night(), "21 点为 night")
	TimeManager.debug_set_datetime(1, "spring", 1, 3, 0)
	_assert(TimeManager.is_after_midnight(), "凌晨属于午夜后")
	_assert(_phase_signal_count >= 1, "昼夜阶段变化发射信号")


func test_season_crop_queries() -> void:
	TimeManager.debug_set_datetime(1, "spring", 1, 6, 0)
	_assert(TimeManager.can_plant_crop_in_current_season("carrot"), "春季可种胡萝卜")
	_assert(not TimeManager.can_plant_crop_in_current_season("tomato"), "春季不可种番茄")
	var spring_crops := TimeManager.get_current_season_crops()
	_assert(spring_crops.size() >= 4, "当前季节作物查询返回春季作物")
	_assert(not TimeManager.can_plant_crop_in_season("missing_crop", "spring"), "缺失作物查询返回 false")


func test_save_import_export_and_invalid_data() -> void:
	TimeManager.debug_set_datetime(2, "autumn", 7, 14, 5)
	TimeManager.set_time_scale(30.0)
	TimeManager.pause_time()
	var data := TimeManager.export_save_data()
	TimeManager.initialize_new_game()
	TimeManager.import_save_data(data)
	_assert(TimeManager.get_year() == 2 and TimeManager.get_season() == "autumn" and TimeManager.get_day() == 7, "导入恢复日期")
	_assert(TimeManager.get_hour() == 14 and TimeManager.get_minute() == 5, "导入恢复时间")
	_assert(TimeManager.is_time_paused() and is_equal_approx(TimeManager.get_time_scale(), 30.0), "导入恢复暂停与倍率")
	TimeManager.import_save_data({"year": -3, "season": "bad", "day": 99, "hour": 99, "minute": 99, "time_scale": 0.0})
	_assert(TimeManager.get_year() == 1 and TimeManager.get_season() == "spring", "非法年份季节被修正")
	_assert(TimeManager.get_day() == 28 and TimeManager.get_hour() == 23 and TimeManager.get_minute() == 59, "非法日期时间被夹取")
	_assert(is_equal_approx(TimeManager.get_time_scale(), TimeManager.DEFAULT_TIME_SCALE), "非法倍率导入被修正")


func test_old_save_without_time_compatibility() -> void:
	var data := SaveManager.build_save_data(0)
	data.erase("time")
	var result := SaveManager.apply_save_data(data)
	_assert(result["success"] == true, "旧存档缺少 time 字段仍可应用")
	_assert(TimeManager.get_year() == 1 and TimeManager.get_season() == "spring" and TimeManager.get_day() == 1, "旧存档缺少 time 时初始化默认时间")


func _connect_signals_once() -> void:
	if not EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.connect(_on_minute_changed)
	if not EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.connect(_on_hour_changed)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.connect(_on_season_changed)
	if not EventBus.year_changed.is_connected(_on_year_changed):
		EventBus.year_changed.connect(_on_year_changed)
	if not EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.connect(_on_day_phase_changed)
	if not EventBus.midnight_crossed.is_connected(_on_midnight_crossed):
		EventBus.midnight_crossed.connect(_on_midnight_crossed)
	if not EventBus.time_scale_changed.is_connected(_on_time_scale_changed):
		EventBus.time_scale_changed.connect(_on_time_scale_changed)
	if not EventBus.time_paused_changed.is_connected(_on_time_paused_changed):
		EventBus.time_paused_changed.connect(_on_time_paused_changed)


func _on_minute_changed(_hour: int, _minute: int) -> void:
	_minute_signal_count += 1


func _on_hour_changed(_new_hour: int) -> void:
	_hour_signal_count += 1


func _on_day_started(_year: int, _season: String, _day: int) -> void:
	_day_signal_count += 1


func _on_season_changed(_new_season: String) -> void:
	_season_signal_count += 1


func _on_year_changed(_new_year: int) -> void:
	_year_signal_count += 1


func _on_day_phase_changed(_new_phase: String) -> void:
	_phase_signal_count += 1


func _on_midnight_crossed() -> void:
	_midnight_signal_count += 1


func _on_time_scale_changed(_new_scale: float) -> void:
	_scale_signal_count += 1


func _on_time_paused_changed(_paused: bool) -> void:
	_paused_signal_count += 1


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_results.append("[PASS] " + message)
		print("[PASS] " + message)
	else:
		_failed += 1
		_results.append("[FAIL] " + message)
		print("[FAIL] " + message)
