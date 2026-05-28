## 1. TimeManager 基础

- [x] 1.1 新增 `pixel-farm/scripts/autoload/time_manager.gd`，定义时间常量、季节数组、昼夜阶段和运行时状态字段
- [x] 1.2 实现 `initialize_new_game()`、`get_time_state()`、单字段查询、`get_time_text()`、`get_date_text()`、`get_datetime_text()`
- [x] 1.3 实现 `_process(delta)` 累计器逻辑，仅在未暂停且 `GameManager.current_state == PLAYING` 时推进游戏分钟
- [x] 1.4 实现分钟、小时、日期、季节、年份推进逻辑，并保证跨边界事件顺序正确

## 2. 时间控制与昼夜

- [x] 2.1 实现 `pause_time()`、`resume_time()`、`set_time_paused(value)`、`is_time_paused()` 并发射暂停状态信号
- [x] 2.2 实现 `set_time_scale(scale)`、`get_time_scale()`，处理非法倍率并发射倍率变化信号
- [x] 2.3 实现 `advance_minutes()`、`advance_hours()`、`advance_to_next_day()`、`debug_set_datetime()`、`debug_print_time()`
- [x] 2.4 实现昼夜阶段计算、`is_night()`、`is_after_midnight()`，并在阶段变化时发射 `day_phase_changed`

## 3. EventBus 与 Autoload 集成

- [x] 3.1 修改 `pixel-farm/scripts/autoload/event_bus.gd`，新增或调整 `minute_changed`、`hour_changed`、`day_started`、`season_changed`、`year_changed`、`day_phase_changed`、`midnight_crossed`、`time_scale_changed`、`time_paused_changed`
- [x] 3.2 修改 `pixel-farm/project.godot` 注册 `TimeManager` Autoload，加载顺序位于 `EventBus`、`DataManager`、`GameManager` 之后并尽量位于 `CropManager` 之前
- [x] 3.3 检查并更新现有 `day_started` 调用点，适配 `day_started(year, season, day)` 新签名
- [x] 3.4 可选修改 `GameManager.start_new_game()` 或重置流程，在新游戏开始时调用 `TimeManager.initialize_new_game()`

## 4. SaveManager 集成

- [x] 4.1 在 `TimeManager` 中实现 `export_save_data()`，返回 JSON 可序列化时间状态
- [x] 4.2 在 `TimeManager` 中实现 `import_save_data(data)`，恢复并校正非法年份、季节、日期、小时、分钟、倍率和暂停状态
- [x] 4.3 修改 `SaveManager.build_save_data(slot)`，在存档根结构中加入 `time: TimeManager.export_save_data()`
- [x] 4.4 修改 `SaveManager.apply_save_data(data)` 或读档流程，优先导入 `time`，缺失时初始化默认时间并保持旧存档兼容
- [x] 4.5 修改 SaveManager metadata 构建逻辑，加入日期、时间、季节、日期摘要字段

## 5. 作物与季节查询联动

- [x] 5.1 在 `TimeManager` 中实现 `can_plant_crop_in_current_season(crop_id)`、`can_plant_crop_in_season(crop_id, season_id)`、`get_current_season_crops()`
- [x] 5.2 修改 `CropManager` 初始化逻辑，连接 `EventBus.midnight_crossed` 到 `_on_midnight_crossed()`
- [x] 5.3 实现或复用 `_on_midnight_crossed()` 调用 `check_wither_all()`，确保成熟作物可在游戏内跨日后枯萎
- [x] 5.4 保留现有离线补偿或轮询兜底，避免重复枯萎事件

## 6. 自动化测试与验证

- [x] 6.1 新增 `pixel-farm/scenes/test/test_time_manager.gd`，覆盖初始状态、倍率、暂停恢复、跨小时、跨日、跨季、跨年、昼夜阶段、格式化、季节作物查询、存档导入导出和非法数据
- [x] 6.2 新增 `pixel-farm/scenes/test/test_time_manager.tscn`，挂载测试脚本并显示测试结果
- [x] 6.3 运行 Godot 项目或测试场景，确认无语法错误、Autoload 缺失或信号签名错误
- [x] 6.4 验证旧存档缺少 `time` 字段时读档不失败，并使用默认新游戏时间
