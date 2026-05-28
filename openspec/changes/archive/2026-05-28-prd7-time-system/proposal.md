## 为什么

《像素田园》目前已有作物、背包、经济、等级与存档基础，但缺少统一的游戏内日期、小时、昼夜与季节数据源。PRD7 需要补齐 TimeManager，让作物跨日枯萎、季节种植限制、后续 HUD、场景氛围与音频切换都能依赖同一套可存档、可广播事件的时间系统。

## 变更内容

- 新增 `time-system` 能力：提供 `TimeManager` Autoload，维护游戏内年份、季节、日期、小时、分钟、昼夜阶段、暂停状态与时间倍率。
- 修改 `event-bus` 能力：扩展时间相关信号，支持分钟、小时、跨日、跨季、跨年、昼夜阶段、倍率与暂停状态广播，并将新一天事件升级为包含年份、季节与日期的语义。
- 修改 `game-state` 能力：在 Autoload 注册与新游戏初始化流程中纳入 `TimeManager`，并确保时间只在游戏处于 `PLAYING` 状态时推进。
- 修改 `save-system` 能力：在存档根结构中加入可选 `time` 字段，保存和恢复 `TimeManager` 状态，同时兼容 PRD6 旧存档。
- 修改 `crop-state-machine` 能力：作物枯萎检查可由游戏内 `midnight_crossed` 事件触发，而不是仅依赖自然日期轮询。
- 修改 `data-loading` 能力：时间系统可基于作物配置中的 `seasons` 字段提供当前季节可种植作物查询。

## 功能 (Capabilities)

### 新增功能
- `time-system`: 游戏内时间、日期、昼夜、季节、时间倍率、暂停、跳时、格式化、季节作物查询以及时间存档导入导出。

### 修改功能
- `event-bus`: 扩展并规范时间相关事件广播，包括 `minute_changed`、`hour_changed`、`day_started`、`season_changed`、`year_changed`、`day_phase_changed`、`midnight_crossed`、`time_scale_changed`、`time_paused_changed`。
- `game-state`: Autoload 注册顺序和新游戏初始化流程需要包含 `TimeManager`，并将 `GameManager.current_state == PLAYING` 作为时间推进条件。
- `save-system`: 存档结构新增 `time` 字段，读档时恢复时间状态；旧存档缺少该字段时使用默认新游戏时间。
- `crop-state-machine`: `CropManager` 监听游戏内跨日事件并触发 `check_wither_all()`，成熟作物枯萎以游戏内跨日作为主触发源。
- `data-loading`: 季节作物查询能力需支持 `TimeManager` 根据 `DataManager` 作物季节配置返回当前季节可种植作物。

## 影响

- 新增代码文件：`pixel-farm/scripts/autoload/time_manager.gd`。
- 修改代码文件：`pixel-farm/project.godot`、`pixel-farm/scripts/autoload/event_bus.gd`、`pixel-farm/scripts/autoload/save_manager.gd`、`pixel-farm/scripts/autoload/crop_manager.gd`，可选修改 `pixel-farm/scripts/autoload/game_manager.gd`。
- 新增测试文件：`pixel-farm/scenes/test/test_time_manager.tscn`、`pixel-farm/scenes/test/test_time_manager.gd`。
- 新增或修改规范：`openspec/changes/prd7-time-system/specs/time-system/spec.md` 以及现有 `event-bus`、`game-state`、`save-system`、`crop-state-machine`、`data-loading` 的增量规范。
- 对外接口影响：新增 `TimeManager` 全局单例与时间查询/控制 API；`EventBus.day_started` 由单参数语义升级为 `day_started(year, season, day)`，属于规范层面的兼容性变更。