## 为什么

时间、金币、等级、经验和背包快捷栏已经具备权威数据源，但玩家在田园场景中无法持续查看这些核心状态，也缺少快捷选择物品和理解当前可执行交互的常驻入口。现在需要补齐非模态 HUD，将已有系统能力组织成实时、可见且不干扰场景操作的信息层。

## 变更内容

- 新增田园场景常驻 HUD，展示游戏时间、日期、季节、昼夜阶段、金币、等级和经验进度。
- 新增 9 格快捷栏视图，映射背包前 9 格，并支持数字键 `1` 至 `9` 和鼠标点击选择。
- 新增交互提示，根据当前玩家交互目标和农田动作预览显示或隐藏动作文本。
- HUD 与快捷栏通过 `EventBus` 监听状态变化并局部刷新，不在 `_process()` 中轮询权威数据。
- 快捷栏热键在 `ui_input_block_changed(true)` 时停用，避免与背包、商店等模态面板输入冲突。
- 在 `project.godot` 中补齐 `hotbar_1` 至 `hotbar_9` 输入映射，并将 HUD 挂载到田园场景 UI 层。
- 增加 HUD 独立测试场景、自动化逻辑测试和田园场景手工回归检查。

## 功能 (Capabilities)

### 新增功能

- `farm-hud`: 定义田园场景常驻信息展示、事件驱动刷新、快捷栏选择、交互提示和模态输入共存行为。

### 修改功能

无。

## 影响

- 新增 `scenes/ui/hud/` 与 `scripts/ui/hud/` 下的 HUD、快捷栏和快捷栏槽位场景及脚本。
- 修改 `scenes/farm/farm.tscn`，必要时调整 `scenes/farm/farm.gd` 以完成 HUD 初始化。
- 修改 `project.godot`，补充 9 个快捷栏输入动作。
- 读取 `TimeManager`、`GameManager`、`InventoryManager` 和 `DataManager` 的既有公开接口，并监听 `EventBus` 的时间、经济、等级、背包、交互、输入阻塞和读档信号。
- 新增 `scenes/test/test_hud.tscn`、`scenes/test/test_hud.gd`，并按现有回归框架接入 HUD 测试。
- 不引入新的外部依赖，不改变现有存档格式和权威游戏状态。
