## 上下文

项目已完成 PRD1-6 的核心基础：Autoload 管理器、数据加载、作物状态机、背包、经济、等级与本地 JSON 存档。当前作物系统已有成熟与枯萎概念，但枯萎主要依赖自然日期/真实时间判断；后续 HUD、场景色调、音频切换也缺少统一的游戏内日期、昼夜与季节来源。

PRD7 引入 `TimeManager` 作为纯逻辑层 Autoload，不实现 UI、美术、音频或天气，只负责游戏内时间模型、事件广播、存档导入导出以及季节作物查询。实现必须遵循当前 Godot/GDScript 项目风格：不使用 `class_name`、公开方法保留简短注释、运行时数据保持 JSON 可序列化、跨系统通信优先通过 `EventBus`。

## 目标 / 非目标

**目标：**

- 新增 `TimeManager` Autoload，默认从第 1 年春季第 1 天 06:00 开始。
- 默认时间倍率为 `60.0`，即 1 现实分钟等于 1 游戏小时。
- 支持分钟、小时、跨日、跨季、跨年推进，并发射对应 `EventBus` 信号。
- 支持晨、午、昏、夜四个昼夜阶段计算与变化广播。
- 支持暂停、恢复、倍率调整、调试跳时、格式化文本与完整状态查询。
- 支持基于 `DataManager.get_crop(crop_id).seasons` 的当前季节可种植查询。
- 支持 `export_save_data()` / `import_save_data()`，并由 `SaveManager` 保存和恢复。
- 兼容 PRD6 之前缺少 `time` 字段的旧存档。
- 让 `CropManager` 能监听游戏内 `midnight_crossed` 触发枯萎检查。
- 新增自动化测试场景覆盖时间推进、事件、昼夜、季节、存档和边界输入。

**非目标：**

- 不实现 HUD 时间显示、季节图标或日期面板。
- 不实现天空、光照、场景色调或视觉过渡。
- 不实现晨午昏夜 BGM 或环境音切换。
- 不实现天气、节日、限时活动或睡觉跳过时间。
- 不将作物成长阶段从真实时间戳全面迁移为游戏内时间驱动。
- 不让 `TimeManager` 直接读写存档文件。

## 决策

### 1. 使用独立 `TimeManager` Autoload

`TimeManager` 独立维护时间状态，并通过 `EventBus` 向其他系统广播。它依赖 `EventBus`、`GameManager` 与 `DataManager`，但不直接引用 HUD、场景或音频节点。

替代方案是把时间字段放入 `GameManager`，但会让 `GameManager` 继续膨胀，并让日期、昼夜、季节、跳时和存档逻辑难以独立测试。因此采用独立 Autoload。

### 2. 使用游戏分钟作为推进最小事件单位

`_process(delta)` 将 `delta * time_scale` 累计为游戏秒，累计满 60 秒后推进 1 游戏分钟。`advance_minutes(minutes)` 在 PRD7 阶段优先逐分钟推进，确保跨小时、跨日、跨季、跨年和昼夜阶段事件顺序稳定。

替代方案是批量计算最终时间再补发事件，但实现更复杂，容易遗漏事件顺序。当前规模下逐分钟推进满足性能要求。

### 3. 固定四季与默认每季 28 天

季节顺序固定为 `spring -> summer -> autumn -> winter -> spring`，默认每季 28 天。冬季第 28 天 23:59 后进入下一年第 1 天春季 00:00。

该设计与作物配置中的 `seasons` 字段匹配，后续如需节日、活动或自定义日历，可在不破坏基础 API 的情况下扩展配置。

### 4. 昼夜阶段只做状态计算和广播

`TimeManager` 根据小时返回 `morning`、`afternoon`、`evening`、`night`，并在阶段变化时发射 `day_phase_changed(new_phase)`。视觉、音频和 HUD 只在后续 PRD 中监听该信号，不由 PRD7 实现。

### 5. `SaveManager` 持有落盘职责，`TimeManager` 只导入导出 Dictionary

`TimeManager.export_save_data()` 返回 JSON 可序列化 Dictionary，`SaveManager.build_save_data(slot)` 将其写入根字段 `time`。读档时如果缺少 `time`，`SaveManager` 调用 `TimeManager.initialize_new_game()`，保证旧存档兼容。

### 6. 跨日事件作为作物枯萎主触发源

`EventBus.midnight_crossed` 表示游戏内从 23:59 到 00:00，而不是自然世界日期变化。`CropManager` 监听该信号并调用 `check_wither_all()`。保留原有轮询或离线补偿作为兜底，不在 PRD7 强制移除。

### 7. Autoload 顺序放在核心数据之后、作物之前

推荐顺序为 `EventBus`、`DataManager`、`GameManager`、`TimeManager`、`CropManager`、`InventoryManager`、`EconomyManager`、`LevelManager`、`SceneManager`、`SaveManager`、`AudioManager`。如果为了减少迁移风险，`TimeManager` 也可放在 `CropManager` 后，但必须在 `EventBus` 后，并保证 `SaveManager` 可访问。

## 风险 / 权衡

- `EventBus.day_started` 签名升级可能影响旧调用方 → 实现时需要搜索调用点并同步调整，必要时保留兼容包装信号或适配方法。
- 逐分钟跳时在极大跨度时可能有性能成本 → PRD7 调试跳时规模可接受，后续睡觉/长时间跳过可再优化批量事件补发。
- 作物当前成长仍依赖真实时间戳，时间系统只接管跨日枯萎 → 明确 PRD7 不迁移作物成长时间源，避免一次性改动过大。
- 旧存档缺少 `time` 字段 → `time` 作为可选字段处理，缺失时初始化默认时间，不判定存档损坏。
- 非法读档数据可能导致日期越界 → `import_save_data()` 必须校正年份、季节、日期、小时、分钟和倍率，并用 `push_warning` 提示。
- `GameManager.current_state` 不为 `PLAYING` 时不推进时间，测试中可能需要显式设置状态 → 自动化测试应覆盖暂停和非 PLAYING 两类场景。

## 迁移计划

1. 新增 `time_manager.gd` 并注册 Autoload。
2. 扩展 `EventBus` 时间信号，调整 `day_started` 使用方。
3. 修改 `SaveManager` 保存根结构、读档应用顺序和 metadata 摘要。
4. 修改 `CropManager` 连接 `midnight_crossed` 并触发枯萎检查。
5. 可选修改 `GameManager.start_new_game()` 或重置流程，调用 `TimeManager.initialize_new_game()`。
6. 新增 `test_time_manager` 自动化测试场景。
7. 运行 Godot 无头脚本或测试场景，确认无语法错误和事件顺序异常。

## 开放问题

- `day_started(day)` 的旧单参数信号是否需要临时保留兼容别名，取决于实现时现有调用点数量。
- `TimeManager` 是否在 `_ready()` 自动初始化默认时间，还是只由 `GameManager.start_new_game()` 和旧存档兜底显式初始化；建议两者都安全可重复。
