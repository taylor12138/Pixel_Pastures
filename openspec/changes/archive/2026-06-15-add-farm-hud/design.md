## 上下文

Godot 工程位于 `pixel-farm/`。时间、金币、等级经验、背包前 9 格、交互目标和农田动作预览已经分别由 Autoload 与交互控制器维护，并通过 `EventBus` 发射变更信号。当前田园场景仅挂载背包和商店面板，没有持续展示这些状态的非模态 UI。

HUD 横跨时间、经济、等级、库存和交互模块，但必须保持纯展示职责。它不能复制升级公式、库存状态或交互判定，也不能因常驻显示而阻塞农田鼠标操作。工程基础分辨率为 480×320，现阶段允许使用 Godot 内置 `Control`、纯色和文本占位。

## 目标 / 非目标

**目标：**

- 在田园场景提供可独立实例化的常驻 HUD，展示时间、金币、等级经验、9 格快捷栏和交互提示。
- 以各 Manager 的公开查询接口作为权威数据源，以 `EventBus` 作为刷新触发源。
- 普通状态变化只更新相关控件，读档时执行全量同步。
- 数字键和鼠标选择统一提交给 `InventoryManager.select_hotbar()`，并与模态 UI 输入阻塞约定共存。
- 提供稳定的空数据、缺失元数据、满级和重复进入场景处理。

**非目标：**

- 不实现背包、商店、暂停菜单、Toast、小地图、天气或精力消耗闭环。
- 不新增独立 HUD 状态模型，不修改存档格式，不改变时间、经济、等级、库存或交互规则。
- 不引入正式像素美术、外部字体、动画框架或 HUD 自定义布局。
- 不由 HUD 暂停 `SceneTree`、时间或玩家控制。

## 决策

### 1. 使用三层可复用场景拆分

新增 `HUD`、`Hotbar`、`HotbarSlot` 三个场景。`HUD` 负责跨域信息和信号连接，`Hotbar` 负责 9 格集合、输入与选择同步，`HotbarSlot` 只负责单槽显示和点击信号。

选择该拆分是为了让单槽回退视觉、快捷栏输入和全局信息刷新可分别测试。将所有逻辑集中在 `hud.gd` 虽然文件更少，但会把输入、集合更新和展示细节耦合在一起。

### 2. HUD 只读权威数据并采用事件驱动刷新

初次 `_ready()` 和 `game_loaded` 后调用 `refresh_all()`；其他事件按领域局部刷新：

- 时间相关信号只更新对应 Label。
- `gold_changed` 只更新金币。
- `xp_gained`、`level_up` 只更新等级和经验。
- `inventory_changed(index)` 在 `index < 9` 时只刷新该槽。
- `item_added(..., slot_index)` 可刷新已知槽；`item_removed` 无槽位参数，因此以随后出现的 `inventory_changed` 为主，必要时保守刷新 9 格。
- `hotbar_selected` 只更新选中高亮。

HUD 禁止在 `_process()` 中轮询。相比轮询，这一方案保持已有 `EventBus` 解耦方式，并降低持续 UI 开销。

### 3. 经验展示直接消费 LevelManager 的进度结果

等级文本读取 `GameManager.level`，经验数据优先读取 `LevelManager.get_xp_progress()`，使用其 `progress_ratio`、`progress_amount`、`xp_for_next_level` 和 `is_max_level` 字段；仅在测试上下文缺少 `LevelManager` 时回退到 `GameManager.get_xp_progress()`。

HUD 不重复计算等级阈值。满级时显示 `MAX` 并将进度条设为满值，避免下一等级数据为空造成除零或越界。

### 4. 快捷栏映射现有库存前 9 格

`Hotbar` 固定持有 9 个 `HotbarSlot`，每次刷新通过 `InventoryManager.get_hotbar_slots()` 读取副本，通过 `get_selected_hotbar()` 读取选中索引。槽位元数据通过 `DataManager.get_item(item_id)` 查询，仅用于名称、类型和占位颜色。

空槽保留快捷键编号；数量不大于 1 时隐藏数量；元数据缺失时显示 `item_id` 与未知类型灰色。HUD 不保存另一份选中索引或物品数据。

### 5. 输入统一走 InputMap 和 InventoryManager

`project.godot` 新增 `hotbar_1` 至 `hotbar_9`，使用物理数字键。`Hotbar._unhandled_input()` 将 Action 映射为索引 0 至 8，鼠标点击也走同一个 `select_slot(index)`，最终只调用 `InventoryManager.select_hotbar(index)`。

`Hotbar` 监听 `ui_input_block_changed` 并维护 `_hotkeys_enabled`。阻塞期间数字键不提交选择；槽位被模态面板遮罩覆盖，因此鼠标也不会穿透。选择高亮只响应权威查询和 `hotbar_selected`，不在输入处理后乐观修改。

### 6. 交互提示以动作预览为主并安全清空

HUD 同时监听 `player_interaction_target_changed(target)` 与 `farm_tile_action_preview_changed(tile_pos, action, reason)`。非空目标用于判断当前是否存在可交互上下文；有效 `action` 映射为“按 E 种植/浇水/收获/清除”。当目标为空、动作是 `none`、动作未知或预览给出不可执行原因时隐藏提示。

动作预览由 `FarmInteractionController` 产生，最接近实际交互判定，因此优先于 HUD 自行根据地块字段推断。这样不会在 UI 中复制农田规则。

### 7. HUD 位于模态面板下方且不拦截空白区域

HUD 根节点使用全屏 `Control` 和 `MOUSE_FILTER_IGNORE` 或等价的不拦截设置；仅快捷栏槽位接收点击。田园 `UILayer` 中 HUD 的绘制顺序必须低于 `InventoryPanel` 和 `ShopPanel`，确保模态遮罩覆盖 HUD。

HUD 不发射 `ui_input_block_changed`，也不修改暂停状态。田园场景只负责实例化并在需要时调用 `setup()`。

### 8. 信号连接必须幂等

每次连接前使用 `is_connected()` 检查，并在节点生命周期结束时依赖 Godot 对已释放接收者的连接清理；若显式连接到非自身长期对象，则在 `_exit_tree()` 中断开。反复进入田园或独立运行测试场景不得产生重复回调。

### 9. 测试沿用现有独立场景和回归 Runner

新增 `test_hud.tscn` 与 `test_hud.gd`，使用真实 Autoload，公开 `_passed`/`_failed` 供 `test_regression_runner.gd` 汇总。测试覆盖初始化、各领域事件刷新、快捷栏显示与选择、输入阻塞、交互提示、读档、缺失元数据和重复连接。

## 风险 / 权衡

- [不同事件可能连续触发并造成重复刷新] → 以 `inventory_changed(index)` 作为精确槽位刷新主路径，其他库存事件只在无法保证该信号时作保守补偿。
- [交互目标与鼠标地块预览可能来自不同上下文] → 只展示 `FarmInteractionController` 给出的有效动作，并在目标或预览失效时立即隐藏，禁止 HUD 自行猜测动作。
- [480×320 下中文和大额金币可能挤压布局] → 顶部两侧面板设置最小尺寸与裁切/自适应策略，测试 0、百万级金币和 `MAX` 状态。
- [同一 CanvasLayer 的节点顺序导致 HUD 覆盖模态面板] → 在场景中明确将 HUD 放在两个模态面板之前，并通过手工回归检查遮罩层级与点击穿透。
- [PRD 建议接口与真实接口存在差异] → 实现以当前公开接口为准，特别是 `select_hotbar()` 的 `void` 返回值和 `LevelManager.get_xp_progress()` 的实际字段。

## 迁移计划

1. 新增 HUD 三层场景和脚本，不修改现有权威数据。
2. 补充 InputMap，并先通过 HUD 独立测试场景验证。
3. 将 HUD 挂载到 `farm.tscn` 的 `UILayer`，放置在背包与商店面板下方。
4. 将 HUD 测试加入回归 Runner，执行核心回归与田园场景手测。
5. 如需回滚，移除田园 HUD 实例、输入 Action 和新增文件即可；无数据迁移或存档回滚要求。

## 开放问题

无。交互提示文案、视觉占位和信号优先级均按 PRD13 与当前代码接口确定。
