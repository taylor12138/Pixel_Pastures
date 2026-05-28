## ADDED Requirements

### Requirement: TimeManager Autoload singleton
系统 SHALL 提供 `TimeManager` Autoload 单例，位于 `res://scripts/autoload/time_manager.gd`，用于维护游戏内日期、小时、分钟、季节、年份、昼夜阶段、时间倍率与暂停状态。

#### Scenario: TimeManager globally available
- **WHEN** Godot 项目加载 Autoload 单例
- **THEN** `TimeManager` SHALL 可作为全局单例访问
- **AND** 其加载顺序 SHALL 位于 `EventBus` 之后

#### Scenario: New game default time
- **WHEN** `TimeManager.initialize_new_game()` 被调用
- **THEN** 当前时间 SHALL 被设置为第 1 年 `spring` 第 1 天 06:00
- **AND** `TimeManager.get_day_phase()` SHALL 返回 `morning`
- **AND** `TimeManager.get_time_scale()` SHALL 返回 `60.0`

### Requirement: Game time progression
`TimeManager` SHALL 以游戏分钟为最小推进单位，根据 `_process(delta)`、`time_scale` 和累计器推进游戏内时间。

#### Scenario: Default scale advances one game hour per real minute
- **WHEN** `TimeManager` 处于未暂停状态且 `GameManager.current_state == GameManager.GameState.PLAYING`
- **AND** `_process(delta)` 累计收到 60 现实秒
- **THEN** 游戏内时间 SHALL 推进 1 小时

#### Scenario: Time does not advance while paused
- **WHEN** `TimeManager.pause_time()` 被调用
- **AND** `_process(delta)` 继续执行
- **THEN** 游戏内分钟、小时、日期、季节与年份 SHALL 保持不变

#### Scenario: Time does not advance outside PLAYING state
- **WHEN** `GameManager.current_state` 不是 `GameManager.GameState.PLAYING`
- **AND** `_process(delta)` 执行
- **THEN** `TimeManager` SHALL NOT 推进游戏内时间

#### Scenario: Large delta preserves minute events
- **WHEN** `_process(delta)` 收到足以推进多个游戏分钟的大 `delta`
- **THEN** `TimeManager` SHALL 使用累计器逐分钟补偿
- **AND** 不得丢失跨小时、跨日、跨季或跨年事件

### Requirement: Time control APIs
`TimeManager` SHALL 提供暂停、恢复、倍率设置、倍率查询、跳时与调试设置接口。

#### Scenario: Pause and resume APIs update state
- **WHEN** `TimeManager.pause_time()` 被调用
- **THEN** `TimeManager.is_time_paused()` SHALL 返回 `true`
- **WHEN** `TimeManager.resume_time()` 被调用
- **THEN** `TimeManager.is_time_paused()` SHALL 返回 `false`

#### Scenario: Time scale clamps invalid values
- **WHEN** `TimeManager.set_time_scale(scale)` 收到小于等于 0 的值
- **THEN** `TimeManager` SHALL 拒绝或修正为默认倍率 `60.0`
- **AND** 后续时间推进 SHALL 使用合法正数倍率

#### Scenario: Advance minutes emits boundary events
- **WHEN** `TimeManager.advance_minutes(minutes)` 推进跨越小时、日期、季节或年份边界
- **THEN** `TimeManager` SHALL 按实际边界顺序发射对应 `EventBus` 时间事件

#### Scenario: Debug set datetime validates state
- **WHEN** `TimeManager.debug_set_datetime(year, season, day, hour, minute)` 被调用
- **THEN** `TimeManager` SHALL 设置合法化后的日期时间
- **AND** 当前昼夜阶段 SHALL 根据新小时重新计算

### Requirement: Calendar and season model
`TimeManager` SHALL 实现四季循环日历：`spring`、`summer`、`autumn`、`winter`，每季默认 28 天，每天 24 小时，每小时 60 分钟。

#### Scenario: Midnight advances to next day
- **WHEN** 当前时间为第 1 年 `spring` 第 1 天 23:59
- **AND** `TimeManager.advance_minutes(1)` 被调用
- **THEN** 当前时间 SHALL 变为第 1 年 `spring` 第 2 天 00:00

#### Scenario: Season changes after day 28
- **WHEN** 当前时间为第 1 年 `spring` 第 28 天 23:59
- **AND** `TimeManager.advance_minutes(1)` 被调用
- **THEN** 当前时间 SHALL 变为第 1 年 `summer` 第 1 天 00:00

#### Scenario: Year changes after winter ends
- **WHEN** 当前时间为第 1 年 `winter` 第 28 天 23:59
- **AND** `TimeManager.advance_minutes(1)` 被调用
- **THEN** 当前时间 SHALL 变为第 2 年 `spring` 第 1 天 00:00

### Requirement: Day phase calculation
`TimeManager` SHALL 根据当前小时计算昼夜阶段：06:00-11:59 为 `morning`，12:00-17:59 为 `afternoon`，18:00-20:59 为 `evening`，21:00-05:59 为 `night`。

#### Scenario: Morning phase range
- **WHEN** 当前小时为 6 到 11
- **THEN** `TimeManager.get_day_phase()` SHALL 返回 `morning`

#### Scenario: Afternoon phase range
- **WHEN** 当前小时为 12 到 17
- **THEN** `TimeManager.get_day_phase()` SHALL 返回 `afternoon`

#### Scenario: Evening phase range
- **WHEN** 当前小时为 18 到 20
- **THEN** `TimeManager.get_day_phase()` SHALL 返回 `evening`

#### Scenario: Night phase range
- **WHEN** 当前小时为 21 到 23 或 0 到 5
- **THEN** `TimeManager.get_day_phase()` SHALL 返回 `night`

### Requirement: Time query and formatting APIs
`TimeManager` SHALL 提供时间状态查询、单字段查询、昼夜判断和中文格式化文本接口。

#### Scenario: Full time state contains required fields
- **WHEN** `TimeManager.get_time_state()` 被调用
- **THEN** 返回 Dictionary SHALL 包含 `year`、`season`、`season_index`、`season_name`、`day`、`hour`、`minute`、`day_phase`、`time_scale`、`paused`、`total_game_minutes`、`time_text`、`date_text`、`datetime_text`

#### Scenario: Time text uses HHMM format
- **WHEN** 当前时间为 06:05
- **THEN** `TimeManager.get_time_text()` SHALL 返回 `06:05`

#### Scenario: Date text uses Chinese format
- **WHEN** 当前日期为第 1 年春季第 1 天
- **THEN** `TimeManager.get_date_text()` SHALL 返回包含 `第1年`、`春季` 和 `1日` 的中文文本

### Requirement: Season crop query helpers
`TimeManager` SHALL 基于 `DataManager` 的作物 `seasons` 字段提供季节种植查询辅助，但 SHALL NOT 检查等级解锁、背包种子数量或地块状态。

#### Scenario: Can plant crop in current season
- **WHEN** 当前季节包含在 `DataManager.get_crop(crop_id).seasons` 中
- **THEN** `TimeManager.can_plant_crop_in_current_season(crop_id)` SHALL 返回 `true`

#### Scenario: Cannot plant crop outside season
- **WHEN** 当前季节不在 `DataManager.get_crop(crop_id).seasons` 中
- **THEN** `TimeManager.can_plant_crop_in_current_season(crop_id)` SHALL 返回 `false`

#### Scenario: Current season crops query
- **WHEN** `TimeManager.get_current_season_crops()` 被调用
- **THEN** 返回 Array SHALL 包含当前季节可种植作物数据
- **AND** 当 `DataManager` 无作物数据时 SHALL 返回空 Array 且不崩溃

### Requirement: Time save data import and export
`TimeManager` SHALL 提供 `export_save_data()` 和 `import_save_data(data)`，用于导出和恢复 JSON 可序列化时间状态。

#### Scenario: Export time save data
- **WHEN** `TimeManager.export_save_data()` 被调用
- **THEN** 返回 Dictionary SHALL 包含 `year`、`season`、`season_index`、`day`、`hour`、`minute`、`time_scale`、`paused`、`total_game_minutes`、`day_phase`
- **AND** 所有值 SHALL 可被 JSON 序列化

#### Scenario: Import valid time save data
- **WHEN** `TimeManager.import_save_data(data)` 收到有效时间数据
- **THEN** `TimeManager` SHALL 恢复年份、季节、日期、小时、分钟、倍率、暂停状态与累计游戏分钟
- **AND** 昼夜阶段 SHALL 根据恢复后的小时保持一致

#### Scenario: Import invalid time save data clamps values
- **WHEN** `TimeManager.import_save_data(data)` 收到无效季节、越界日期、越界小时、越界分钟或非法倍率
- **THEN** `TimeManager` SHALL 将字段修正到合法范围
- **AND** 不得导致游戏崩溃

### Requirement: TimeManager automated tests
系统 SHALL 包含 `TimeManager` 自动化测试场景和脚本，覆盖初始化、推进、信号、昼夜、季节、存档和非法输入。

#### Scenario: TimeManager test scene exists
- **WHEN** 项目文件被检查
- **THEN** `res://scenes/test/test_time_manager.tscn` 和 `res://scenes/test/test_time_manager.gd` SHALL 存在

#### Scenario: TimeManager tests cover PRD7 acceptance
- **WHEN** `test_time_manager.tscn` 运行
- **THEN** 测试 SHALL 覆盖初始时间、倍率、暂停恢复、跨小时、跨日、跨季、跨年、昼夜阶段、格式化、季节作物查询、存档导入导出和非法数据兜底
