# PRD13: HUD（时间 / 金币 / 快捷栏 / 等级 / 交互提示）

> **优先级**: P1 — 玩家在田园场景中持续可见的核心信息层，打通时间、经济、背包数据到屏幕常驻显示
> **美术依赖**: 🔵 Godot Control 节点简易搭建（允许纯色面板、Label、ColorRect 和占位图标，不依赖正式 UI 美术）
> **预计工期**: 4-6 天
> **前置依赖**: PRD7（时间系统，`TimeManager`）、PRD3（背包/快捷栏，`InventoryManager`）、PRD5（等级系统，`LevelManager` / `GameManager` 经验）；建议已完成 PRD11（背包 UI，复用 UI 输入阻塞约定与槽位占位风格）、PRD12（商店 UI，共享 `GameManager.gold` 与 `gold_changed`）
> **产出**: 田园场景常驻 HUD（时间/日期/季节 + 金币 + 等级/经验 + 快捷栏 9 格 + 交互提示）+ 各信息控件 + 快捷栏数字键选择 + 事件驱动局部刷新 + 自动化/半自动化测试
> **最后更新**: 2026-06-12

---

## 1. 目标

实现《像素田园》的常驻抬头显示（HUD），把 PRD7、PRD3、PRD5 已完成的数据能力转化为玩家在田园场景中**持续可见、实时刷新**的信息层，包含：

- 屏幕常驻显示游戏内时间（时:分）、日期（年/季节/日）、昼夜阶段
- 常驻显示玩家当前金币余额，随交易实时刷新
- 常驻显示玩家等级与经验进度（经验条 + 当前/下一级所需）
- 快捷栏（Hotbar）显示背包前 9 格物品、数量、当前选中高亮
- 支持数字键 1-9 选择快捷栏槽位，鼠标点击选择
- 显示当前交互提示（如「按 E 浇水 / 收获 / 种植」）
- 所有信息通过 `EventBus` 信号事件驱动局部刷新，不在 `_process()` 轮询
- 使用 Godot 内置 Control 节点完成可用的占位视觉

完成后，玩家在田园场景中无需打开任何面板即可随时看到时间、金币、等级与手持工具，并能用数字键快速切换快捷栏物品；时间流逝、金币变动、升级、背包变化都会即时反映在 HUD 上。

本 PRD 只实现「常驻 HUD 信息层」。HUD 是**非模态、不阻断输入**的常驻层，与背包面板（PRD11）、商店面板（PRD12）等模态面板共存。金币数据源与商店面板共享同一份 `GameManager.gold` 和 `gold_changed` 信号。

---

## 2. 核心设计决策

| 决策 | 内容 | 来源 |
|------|------|------|
| 数据权威 | HUD 是纯展示层，不写入任何状态；金币、时间、等级、背包均只读 | PRD3/4/5/7 |
| 时间来源 | 通过 `TimeManager.get_time_text()` / `get_date_text()` / `get_season_name()` / `get_day_phase()` 查询 | PRD7 |
| 时间刷新 | 监听 `minute_changed` / `day_started` / `season_changed` / `day_phase_changed`，不轮询 | PRD7 |
| 金币来源 | 读取 `GameManager.gold`，监听 `gold_changed` 局部刷新 | PRD4 |
| 等级/经验来源 | 读取 `GameManager.level` 与 `GameManager.get_xp_progress()`，监听 `level_up` / `xp_gained` | PRD5 |
| 快捷栏来源 | `InventoryManager.get_hotbar_slots()`（前 9 格），选中态 `get_selected_hotbar()` | PRD3 |
| 快捷栏刷新 | 监听 `inventory_changed` / `item_added` / `item_removed` / `hotbar_selected` 局部刷新 | PRD3 |
| 快捷栏选择 | 数字键 1-9 与点击均调用 `InventoryManager.select_hotbar(index)`，HUD 不自行维护选中态 | PRD3 |
| 交互提示来源 | 监听 `player_interaction_target_changed` / `farm_tile_action_preview_changed`，HUD 只显示文案 | PRD9/PRD10 |
| 非模态 | HUD 常驻 `visible`，不发 `ui_input_block_changed`，不暂停游戏与角色 | 本 PRD |
| 输入共存 | 数字键选择仅在「无模态面板打开」时生效（监听 `ui_input_block_changed` 暂停热键） | PRD11/12 |
| UI 技术 | Godot `Control` + `CanvasLayer` + 锚点布局 + `ProgressBar` + 自定义槽位 | PRD 大纲、框架调研 |
| 占位视觉 | 颜色块、首字、文本占位；正式图标后续替换 | 第三层 UI 占位策略 |
| 图标复用 | 快捷栏槽位复用 PRD11 类型占位色与图标约定 | PRD11 |

---

## 3. 系统范围

### 3.1 本 PRD 覆盖内容

- 新增 HUD 主场景 `hud.tscn` 与控制脚本 `hud.gd`
- 新增快捷栏组件 `hotbar.tscn` / `hotbar.gd`（含 9 个槽位）
- 新增快捷栏槽位组件 `hotbar_slot.tscn` / `hotbar_slot.gd`
- 时间/日期/季节信息控件
- 金币信息控件
- 等级/经验信息控件（经验条）
- 交互提示控件
- 快捷栏数字键 1-9 选择 + 点击选择
- 事件驱动的局部刷新逻辑
- `project.godot` 补充 `hotbar_1` ~ `hotbar_9` InputMap action
- HUD 在 `farm.tscn` 挂载
- EventBus 无需新增信号（复用已有），如需 HUD 显隐则新增最小信号
- 自动化逻辑测试与半自动化 UI 测试

### 3.2 本 PRD 不覆盖内容

- 背包功能面板本体 -> PRD11
- 商店功能面板本体 -> PRD12
- 设置/存档/暂停菜单 -> PRD14
- 小地图 / 大地图（`open_map`）-> 后续
- 天气系统与天气图标（设计文档提及，本期仅季节/昼夜）-> 后续
- 精力值（Energy）消耗逻辑与 HUD 体力条**功能闭环**（本期可显示静态值，但不实现消耗）
- 通知 / Toast 消息队列 -> PRD24
- 正式像素 UI 面板、按钮、图标资源 -> 后续美术替换
- 移动端触屏专项适配
- HUD 缩放设置 / 自定义布局

---

## 4. 场景与文件设计

### 4.1 需要新增/修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `scenes/ui/hud/hud.tscn` | 新增 | HUD 主场景（锚点布局，覆盖全屏角落） |
| `scripts/ui/hud/hud.gd` | 新增 | HUD 总控：收集子控件、连接信号、局部刷新 |
| `scenes/ui/hud/hotbar.tscn` | 新增 | 快捷栏容器（9 槽位） |
| `scripts/ui/hud/hotbar.gd` | 新增 | 快捷栏刷新、选中高亮、数字键/点击选择 |
| `scenes/ui/hud/hotbar_slot.tscn` | 新增 | 单个快捷栏槽位 |
| `scripts/ui/hud/hotbar_slot.gd` | 新增 | 槽位显示物品、数量、快捷键编号、选中态 |
| `scenes/farm/farm.tscn` | 修改 | 在 `UILayer` 下挂载 `HUD` |
| `scenes/farm/farm.gd` | 修改 | 引用 HUD，必要时调用 `setup()` |
| `project.godot` | 修改 | 增加 `hotbar_1` ~ `hotbar_9` 输入映射 |
| `scenes/test/test_hud.tscn` | 新增 | HUD 测试场景 |
| `scenes/test/test_hud.gd` | 新增 | 自动化逻辑与节点状态测试 |
| `scenes/test/test_regression_runner.gd` | 修改 | 纳入 HUD 测试（如回归框架支持） |

建议目录：

```text
pixel-farm/
├── scenes/
│   └── ui/
│       └── hud/
│           ├── hud.tscn
│           ├── hotbar.tscn
│           └── hotbar_slot.tscn
├── scripts/
│   └── ui/
│       └── hud/
│           ├── hud.gd
│           ├── hotbar.gd
│           └── hotbar_slot.gd
└── scenes/
    └── test/
        ├── test_hud.tscn
        └── test_hud.gd
```

### 4.2 HUD 节点结构

```text
HUD (Control)                                # 全屏锚点 Full Rect，mouse_filter=Pass
├── TopBar (HBoxContainer/MarginContainer)   # 顶部信息条，锚点 Top
│   ├── TimePanel (PanelContainer)
│   │   └── TimeVBox (VBoxContainer)
│   │       ├── ClockLabel                   # "06:00"
│   │       ├── DateLabel                    # "第1年 春季 1日"
│   │       └── PhaseLabel / PhaseIcon       # 昼夜阶段（早晨/下午/傍晚/夜晚）
│   ├── Spacer (Control, size_flags expand)
│   └── StatsPanel (PanelContainer)
│       └── StatsVBox (VBoxContainer)
│           ├── GoldRow (HBoxContainer)
│           │   ├── GoldIconPlaceholder (ColorRect)
│           │   └── GoldLabel               # "1234"
│           ├── LevelRow (HBoxContainer)
│           │   ├── LevelLabel              # "Lv.3"
│           │   └── XpBar (ProgressBar)      # 当前级经验进度
│           └── XpLabel                      # "120 / 250"（可选）
├── InteractionPrompt (PanelContainer)       # 屏幕中下方，默认隐藏
│   └── PromptLabel                          # "按 E 浇水"
└── HotbarRoot (CenterContainer/Control)     # 底部居中，锚点 Bottom
    └── Hotbar (HBoxContainer)
        ├── HotbarSlot0
        ├── HotbarSlot1
        ├── ...
        └── HotbarSlot8                       # 共 9 个
```

### 4.3 快捷栏槽位节点结构

```text
HotbarSlot (PanelContainer / Control)         # 建议 24×24 或 28×28
├── Background (ColorRect)                     # 类型占位色 / 空槽底色
├── IconPlaceholder (ColorRect / TextureRect)  # 16×16 图标占位
├── HotkeyLabel (Label)                        # 左上角快捷键编号 1-9
├── QuantityLabel (Label)                      # 右下角数量（>1 才显示）
└── SelectedHighlight (ColorRect / NinePatch)  # 选中边框，默认隐藏
```

### 4.4 farm 场景挂载

```text
Farm
├── ...
├── UILayer (CanvasLayer)
│   ├── InventoryPanel
│   ├── ShopPanel
│   └── HUD                # 新增；layer 低于模态面板或同层但靠前由模态遮罩覆盖
└── DebugLayer
```

要求：

- HUD 始终 `visible = true`（游戏处于 `PLAYING` 时）
- HUD 根节点 `mouse_filter = MOUSE_FILTER_PASS`（不拦截穿过空白区的鼠标事件），仅快捷栏槽位 `Stop`
- 背包/商店面板打开时，其全屏遮罩会盖在 HUD 之上 → HUD 视觉被遮挡属预期
- HUD 不发 `ui_input_block_changed`，不暂停时间或角色

---

## 5. 布局与占位视觉规范

### 5.1 基础分辨率

项目基础分辨率为 480×320，HUD 建议占用：

| 区域 | 锚点 | 建议尺寸 |
|------|------|----------|
| 顶部信息条 | Top（左右贴边） | 宽 480 × 高 28-40 |
| 时间面板 | 左上 | 宽 90-110 × 高 28-40 |
| 数值面板（金币/等级） | 右上 | 宽 110-140 × 高 28-40 |
| 快捷栏 | Bottom 居中 | 9 槽 × (24-28) + 间距 |
| 单个快捷栏槽位 | — | 24×24 或 28×28 |
| 交互提示 | 底部居中（快捷栏上方） | 自适应宽 × 高 16-20 |
| 经验条 | 数值面板内 | 宽 60-90 × 高 4-6 |
| 正文字号 | — | 10-14px |

### 5.2 视觉状态

| 元素 | 占位表现 |
|------|----------|
| 时间 | `ClockLabel` 显示 HH:MM，整点/分钟刷新 |
| 昼夜阶段 | 文本「早晨/下午/傍晚/夜晚」或对应色块（黄/橙/紫/深蓝） |
| 金币 | 金黄色块 + 数字，变动时可短暂闪烁（可选） |
| 等级 | "Lv.N" + 经验条按 0-1 进度填充 |
| 快捷栏空槽 | 灰底，仅显示快捷键编号 |
| 快捷栏有物品 | 类型占位色 + 首字/图标 + 数量（>1） |
| 快捷栏选中 | 白/浅绿高亮边框 |
| 交互提示无目标 | 隐藏 |
| 交互提示有目标 | 显示「按 E <动作>」 |

类型占位颜色（沿用 PRD11/12 约定）：

| 类型 | 颜色 |
|------|------|
| `tool` | 蓝灰色 |
| `seed` | 浅绿色 |
| `harvest` | 橙黄色 |
| `consumable` | 紫色 |
| `decoration` | 棕黄色 |
| 空槽 / 未知 | 灰色 |

### 5.3 像素 UI 约束

- 坐标与尺寸尽量使用整数
- 不使用模糊缩放和线性过滤
- 图标区域预留 16×16
- 当前阶段不要求引入外部字体；需确保中文可读
- 后续替换正式 Theme 时不改变节点职责与脚本接口

---

## 6. HUD 主控（hud.gd）

新增 `scripts/ui/hud/hud.gd`。

### 6.1 职责

- 收集时间/金币/等级/交互提示子控件与快捷栏引用
- `_ready()` 时连接所有需要的 `EventBus` 信号
- 初次进入时做一次全量刷新（时间、金币、等级、快捷栏）
- 各信号回调中做**局部刷新**，不重建整个 HUD
- 管理交互提示的显示/隐藏
- 不写入任何游戏状态

### 6.2 公共接口

```gdscript
## 绑定可选上下文（如玩家/交互控制器）；测试场景允许传 null
func setup(context: Node = null) -> void

## 全量刷新所有 HUD 元素
func refresh_all() -> void

## 刷新时间与日期显示
func refresh_time() -> void

## 刷新金币显示
func refresh_gold() -> void

## 刷新等级与经验条
func refresh_level() -> void

## 刷新快捷栏（委托 Hotbar）
func refresh_hotbar() -> void

## 设置交互提示文案（空字符串则隐藏）
func set_interaction_prompt(text: String) -> void

## 显隐整个 HUD（如进入菜单时可隐藏，本期默认常显）
func set_hud_visible(value: bool) -> void
```

### 6.3 初始化流程

```text
HUD._ready()
  -> 收集子控件引用（时间/金币/等级/提示/Hotbar）
  -> 连接 EventBus.minute_changed / hour_changed
  -> 连接 EventBus.day_started / season_changed / day_phase_changed
  -> 连接 EventBus.gold_changed
  -> 连接 EventBus.level_up / xp_gained
  -> 连接 EventBus.game_loaded
  -> 连接 EventBus.player_interaction_target_changed / farm_tile_action_preview_changed
  -> Hotbar 自行连接背包相关信号（见 §7）
  -> refresh_all()
  -> set_interaction_prompt("")
```

要求：

- 连接前判断 `is_connected` 避免重复注册
- `minute_changed` 高频触发 → 时间刷新仅更新 Label 文本，开销极小
- 读档 `game_loaded` 后全量刷新

---

## 7. Hotbar（hotbar.gd）

新增 `scripts/ui/hud/hotbar.gd`。

### 7.1 职责

- 持有 9 个 `HotbarSlot`，对应背包前 9 格
- 从 `InventoryManager.get_hotbar_slots()` 取数据填充
- 高亮 `get_selected_hotbar()` 选中槽
- 处理数字键 1-9 与点击选择，调用 `InventoryManager.select_hotbar()`
- 监听背包变化局部刷新对应槽位

### 7.2 核心属性

```gdscript
const HOTBAR_SIZE: int = 9   # 与 InventoryManager.HOTBAR_SIZE 对齐

var slot_views: Array[Control] = []
var _hotkeys_enabled: bool = true   # 模态面板打开时置 false
```

### 7.3 公共接口

```gdscript
## 全量刷新所有快捷栏槽位
func refresh_all() -> void

## 刷新单个槽位
func refresh_slot(index: int) -> void

## 刷新选中高亮
func refresh_selection() -> void

## 设置数字键热键是否生效（模态面板打开时禁用）
func set_hotkeys_enabled(value: bool) -> void

## 选择指定槽位（点击或数字键调用）
func select_slot(index: int) -> bool
```

### 7.4 输入处理

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not _hotkeys_enabled:
        return
    for i in range(HOTBAR_SIZE):
        if event.is_action_pressed("hotbar_%d" % (i + 1)):
            select_slot(i)
            get_viewport().set_input_as_handled()
            return
```

要求：

- 选择仅调 `InventoryManager.select_hotbar(index)`，高亮由 `hotbar_selected` 信号回调统一处理（单一数据源）
- 监听 `ui_input_block_changed(true/false)` → `set_hotkeys_enabled(not blocked)`，避免在背包/商店打开时数字键穿透
- 点击槽位也调用 `select_slot`

### 7.5 信号连接

```text
Hotbar._ready()
  -> 创建/收集 9 个 HotbarSlot
  -> 连接 EventBus.inventory_changed -> refresh_slot
  -> 连接 EventBus.item_added / item_removed -> refresh 相关槽位
  -> 连接 EventBus.hotbar_selected -> refresh_selection
  -> 连接 EventBus.ui_input_block_changed -> set_hotkeys_enabled
  -> 连接 EventBus.game_loaded -> refresh_all
  -> refresh_all()
```

---

## 8. HotbarSlot（hotbar_slot.gd）

新增 `scripts/ui/hud/hotbar_slot.gd`。

### 8.1 职责

- 显示单个槽位：物品图标占位、数量、快捷键编号、选中态
- 响应点击发出选中信号
- 不直接修改背包

### 8.2 核心属性

```gdscript
var slot_index: int = 0
var item_id: String = ""
var item_type: String = ""
var quantity: int = 0
var is_selected: bool = false
```

### 8.3 信号

```gdscript
signal slot_clicked(slot_index: int)
```

### 8.4 公共接口

```gdscript
## 用槽位数据填充（来自 get_hotbar_slots() 单项，可能为 null=空槽）
func set_slot_data(data: Variant) -> void

## 设置选中高亮
func set_selected(value: bool) -> void

## 设置快捷键编号显示（1-9）
func set_hotkey_number(num: int) -> void
```

约束：

- `data` 为 `null` 时显示空槽（仅快捷键编号）
- 数量 ≤ 1 时隐藏数量 Label
- 元数据缺失时回退显示 item_id 与灰色，不崩溃

---

## 9. 数据展示规则

### 9.1 时间显示

| 字段 | 来源 | 显示 |
|------|------|------|
| 时钟 | `TimeManager.get_time_text()` | "06:00" |
| 日期 | `TimeManager.get_date_text()` | "第1年 春季 1日" |
| 季节 | `TimeManager.get_season_name()` | "春季/夏季/秋季/冬季" |
| 昼夜阶段 | `TimeManager.get_day_phase()` | morning/afternoon/evening/night → 中文/色块 |

阶段→中文映射：`morning=早晨`、`afternoon=下午`、`evening=傍晚`、`night=夜晚`。

### 9.2 金币显示

- 来源 `GameManager.gold`，监听 `gold_changed(new_amount, delta)`
- 仅更新数字；`delta` 可用于可选的 +N/-N 飘字或闪烁（可选增强）

### 9.3 等级 / 经验显示

- 等级 `GameManager.level`
- 进度 `GameManager.get_xp_progress()` 返回字典，含当前级基准、下一级所需等字段
- 经验条 `value = (当前xp - 当前级基准) / (下一级所需 - 当前级基准)`，夹取到 [0,1]
- 满级时经验条显示满或隐藏，并显示「MAX」

> 注：以 `GameManager.get_xp_progress()` 实际返回字段为准（含 `xp_for_current_level` / `xp_for_next_level` 等），UI 不复制升级规则。

### 9.4 快捷栏显示

- 数据 `InventoryManager.get_hotbar_slots()` → 9 项数组，每项为槽位字典或 `null`
- 槽位字典含 `item_id` / `quantity` 等；类型经 `DataManager.get_item(item_id)` 查 `type` 决定占位色
- 选中态 `InventoryManager.get_selected_hotbar()`

### 9.5 交互提示显示

- 监听 `player_interaction_target_changed(target: Dictionary)` 与 `farm_tile_action_preview_changed(tile_pos, action, reason)`
- 根据 `action`（如 `plant` / `water` / `harvest` / `clear`）映射文案：「按 E 种植 / 浇水 / 收获 / 清除」
- 无可用目标或动作为空 → 隐藏提示

> 注：具体字段以 PRD9/PRD10 实际信号载荷为准；HUD 只读取并映射文案，不做交互判定。

---

## 10. 输入与游戏状态

### 10.1 HUD 是非模态层

- HUD 不调用 `get_tree().paused`
- HUD 不发 `ui_input_block_changed`
- HUD 根节点 `mouse_filter = Pass`，让点击穿过空白区到达场景（农田点击）
- 仅快捷栏槽位、可点击控件设 `Stop`

### 10.2 数字键与模态面板共存

```text
无模态面板打开：
  数字键 1-9 -> 选择快捷栏槽位

背包 / 商店面板打开（ui_input_block_changed(true)）：
  数字键 1-9 -> 由 Hotbar 暂停热键，不选择
  （或交由面板内热键逻辑处理）
```

要求：

- Hotbar 监听 `ui_input_block_changed`，打开模态面板时 `set_hotkeys_enabled(false)`，关闭时恢复
- 避免与 PRD11 背包内快捷栏选择逻辑冲突（背包打开时以背包为准）

### 10.3 InputMap 补充

PRD1 规划了 `hotbar_1` ~ `hotbar_9` 但 `project.godot` 当前未定义。本 PRD 需补充：

```text
hotbar_1: 物理键 1
hotbar_2: 物理键 2
...
hotbar_9: 物理键 9
```

要求：使用 `physical_keycode`，与现有移动键风格一致；补充后 `Input.is_action_pressed("hotbar_1")` 可用。

---

## 11. EventBus 监听

HUD 复用已有信号，**原则上无需新增**。如需 HUD 整体显隐控制（PRD14 菜单联动），可新增最小信号：

```gdscript
# ─── HUD（可选，按需）───
signal hud_visibility_changed(visible: bool)
```

### 11.1 已有信号监听

| 信号 | HUD 行为 |
|------|----------|
| `minute_changed(hour, minute)` | 刷新时钟文本 |
| `hour_changed(new_hour)` | 刷新时钟（与 minute 同步即可） |
| `day_started(year, season, day)` | 刷新日期 |
| `season_changed(new_season)` | 刷新季节显示 |
| `day_phase_changed(new_phase)` | 刷新昼夜阶段图标/文案 |
| `gold_changed(new_amount, delta)` | 刷新金币数字 |
| `level_up(new_level)` | 刷新等级与经验条 |
| `xp_gained(amount, source)` | 刷新经验条 |
| `inventory_changed(slot_index)` | 刷新对应快捷栏槽位（index < 9 时） |
| `item_added(...)` / `item_removed(...)` | 刷新相关快捷栏槽位 |
| `hotbar_selected(index)` | 刷新快捷栏选中高亮 |
| `player_interaction_target_changed(target)` | 更新交互提示 |
| `farm_tile_action_preview_changed(...)` | 更新交互提示 |
| `ui_input_block_changed(blocked)` | 启停快捷栏数字键 |
| `game_loaded(slot, metadata)` | 全量刷新 HUD |

### 11.2 刷新规则

- 时间高频 → 仅改文本，禁止重建节点
- 背包变化 → 只刷新 index < 9 的受影响槽位
- 避免在 `_process()` 中轮询任何数据

---

## 12. 错误提示与边界情况

| 场景 | 预期行为 |
|------|----------|
| 时间快速推进（debug 跳天） | 时间/日期/季节均正确刷新，无残留 |
| 金币变为 0 或大额（百万） | 数字正常显示，必要时缩写或允许溢出布局 |
| 满级 | 经验条满或显示「MAX」，不越界 |
| 快捷栏空 | 9 格全显示空槽与编号，无报错 |
| 背包某格物品元数据缺失 | 回退显示 item_id + 灰色 |
| 数量为 1 | 不显示数量 Label |
| 模态面板打开时按数字键 | 不切换快捷栏（热键暂停） |
| 交互无目标 | 提示隐藏 |
| HUD 在测试场景独立运行（无 farm） | `setup(null)` 仍可刷新已有 autoload 数据 |
| 读档 | 全量刷新与存档数据一致 |
| 游戏处于 MAIN_MENU/PAUSED | HUD 可隐藏或冻结刷新（本期：farm 内默认 PLAYING，常显） |
| 反复进入/退出 farm 场景 | 不重复连接信号、无悬空引用 |

---

## 13. 测试需求

### 13.1 自动化测试场景

创建：

```text
scenes/test/test_hud.tscn
scenes/test/test_hud.gd
```

测试场景应包含：

- 独立 `HUD`（含 Hotbar）
- 真实 `TimeManager` / `GameManager` / `InventoryManager` / `LevelManager` autoload
- 结果 Label
- 可直接运行的测试入口

### 13.2 自动化测试用例

| 用例 | 预期 |
|------|------|
| 初始化 | 时间/金币/等级/快捷栏与各 autoload 当前值一致 |
| 时间刷新 | `advance_minutes` / `minute_changed` 后时钟文本更新 |
| 日期刷新 | 跨天后 `day_started` 触发日期更新 |
| 季节刷新 | `season_changed` 后季节文案更新 |
| 昼夜阶段 | `day_phase_changed` 后阶段显示更新 |
| 金币刷新 | `add_gold` / `spend_gold` 后金币数字与 `GameManager.gold` 一致 |
| 等级刷新 | `level_up` 后等级文案更新 |
| 经验条 | `xp_gained` 后经验条进度按 `get_xp_progress()` 正确 |
| 快捷栏填充 | `get_hotbar_slots()` 9 项与槽位显示一致 |
| 快捷栏数量 | 数量 >1 显示数量，=1 隐藏 |
| 快捷栏选中 | `select_hotbar(i)` 后仅第 i 槽高亮 |
| 数字键选择 | 模拟 `hotbar_3` 后选中 index=2（热键启用时）|
| 热键暂停 | `ui_input_block_changed(true)` 后数字键不切换 |
| 背包变化刷新 | `add_item` / `remove_item` 后受影响槽位刷新 |
| 交互提示 | 收到目标信号显示文案，无目标隐藏 |
| 元数据缺失 | 回退显示，不崩溃 |
| 读档刷新 | `game_loaded` 后全量同步 |
| 信号不重复 | 重复 `_ready`/重进场景不重复连接 |

### 13.3 半自动化手测清单

在田园场景中验证：

1. 进入田园，顶部显示时间、日期、季节，底部显示 9 格快捷栏
2. 等待/调试推进时间，时钟分钟跳动、跨天日期更新、季节切换显示
3. 昼夜阶段随小时变化（早晨→下午→傍晚→夜晚）
4. 出售/购买后金币数字实时刷新（与商店面板一致）
5. 获得经验/升级后等级与经验条更新
6. 背包获得物品后快捷栏对应格显示物品与数量
7. 按数字键 1-9 切换选中槽，高亮跟随
8. 点击快捷栏槽位也能选中
9. 打开背包/商店面板时按数字键不误切快捷栏
10. 靠近可交互农田时显示「按 E …」提示，离开后隐藏
11. 保存读档后 HUD 全部信息与存档一致
12. HUD 不拦截农田点击（空白区点击仍能操作农田）

---

## 14. 验收标准

### 14.1 功能验收

- [ ] 田园场景常驻显示时间、日期、季节、昼夜阶段
- [ ] 时间流逝时时钟/日期/季节实时刷新
- [ ] 金币常驻显示并随交易实时刷新（与商店共享数据源）
- [ ] 等级与经验条显示并随升级/获经验刷新
- [ ] 快捷栏显示背包前 9 格物品、数量与选中态
- [ ] 数字键 1-9 与点击均可选择快捷栏槽位
- [ ] 选中态由 `hotbar_selected` 统一驱动，单一数据源
- [ ] 交互提示根据当前目标显示/隐藏
- [ ] 读档后 HUD 全量刷新一致

### 14.2 输入与体验验收

- [ ] HUD 为非模态层，不暂停游戏与角色
- [ ] HUD 不拦截农田空白区点击
- [ ] 模态面板（背包/商店）打开时数字键不误切快捷栏
- [ ] 480×320 基础分辨率下文字可读、布局不超出屏幕
- [ ] 无正式美术资源也能清晰识别时间/金币/快捷栏物品类型

### 14.3 工程验收

- [ ] HUD 不写入任何游戏状态（金币/时间/背包/等级均只读）
- [ ] 信息刷新通过 `EventBus` 信号，不在 `_process()` 轮询
- [ ] 事件连接不会因重进场景而重复注册
- [ ] `hotbar_1` ~ `hotbar_9` InputMap 已补充且可用
- [ ] 新增测试场景可独立运行
- [ ] 不破坏 PRD1-12 已有测试
- [ ] 控制台无持续报错和无效节点引用

---

## 15. 实施建议

建议按以下顺序开发：

1. 补 `project.godot` 的 `hotbar_1`~`hotbar_9` 输入映射
2. 创建 `HotbarSlot`，完成空槽/有物品/选中/数量四态渲染
3. 创建 `Hotbar`，填充 9 槽、连接背包信号、实现点击与数字键选择
4. 创建 `HUD`，搭建时间/金币/等级/提示控件并连接信号
5. 实现各局部刷新方法与 `refresh_all()`
6. 接入交互提示信号映射
7. 接入 `ui_input_block_changed` 热键开关与读档刷新
8. 在 `farm.tscn` 挂载 HUD 并联调
9. 补齐自动化测试与手测

---

## 16. 风险与注意事项

| 风险 | 说明 | 应对 |
|------|------|------|
| 时间高频刷新性能 | `minute_changed` 频繁触发 | 仅更新 Label 文本，禁止重建节点 |
| 快捷栏选中双源 | HUD 与背包各自维护选中态导致不一致 | 选中只调 `select_hotbar`，统一由 `hotbar_selected` 刷新 |
| 数字键穿透 | 面板打开时数字键误切快捷栏 | 监听 `ui_input_block_changed` 暂停热键 |
| 鼠标拦截农田 | HUD 全屏 Control 拦截点击 | 根节点 `mouse_filter=Pass`，仅槽位 `Stop` |
| 经验字段不符 | UI 复制升级规则导致偏差 | 仅用 `get_xp_progress()` 返回值 |
| 信号重复注册 | 重进场景反复 connect | 连接前判断 `is_connected` |
| 缺图标 | items.json 无 icon_path | 类型色块 + 首字占位，保留接口 |
| 交互提示字段未定 | PRD9/10 载荷差异 | 以实际信号字段为准，HUD 只映射文案，缺失则隐藏 |
| HUD 与模态面板 z 序 | HUD 盖住模态面板 | 模态遮罩层级高于 HUD，或同 CanvasLayer 内顺序在后 |

---

## 17. 技术约束

1. **Godot 版本**
   - 兼容项目当前 Godot 4.x 配置
   - 使用锚点布局适配 480×320；经验条用 `ProgressBar`

2. **数据边界**
   - HUD 只读 `TimeManager` / `GameManager` / `InventoryManager` / `LevelManager` 公开查询接口
   - 不写入金币、不修改背包槽位、不推进时间
   - 不复制价格表、升级规则、季节表

3. **事件驱动**
   - 时间、金币、等级、背包通过信号刷新
   - 不在 `_process()` 中轮询

4. **可复用性**
   - `HotbarSlot` / `Hotbar` 不依赖具体场景
   - `HUD.setup(null)` 时仍可在测试场景运行
   - 复用 PRD11 的类型占位色与 UI 输入阻塞约定

5. **输入**
   - 仅 Hotbar 监听数字键热键，且受 `ui_input_block_changed` 约束
   - HUD 不监听移动/交互键

6. **视觉**
   - 当前阶段使用内置节点和 ThemeOverride
   - 不要求下载或生成正式美术资源
   - 后续替换素材不得改变核心节点接口

---

## 18. 与后续 PRD 的衔接

- **PRD14 设置/存档 UI**：可建立统一 `UIManager` 管理 HUD、背包、商店、菜单的显隐与焦点；菜单打开时可调用 `HUD.set_hud_visible(false)`
- **PRD15 角色动画**：交互提示与角色朝向动作联动，不改 HUD 接口
- **PRD16 作物视觉**：成熟提示可与 HUD 交互提示协同
- **PRD18 特效**：金币飘字、升级特效可叠加在 HUD 之上
- **PRD19 音频**：升级、选中快捷栏、金币变动播放 UI 音效
- **PRD24 通知系统**：Toast/通知队列可作为 HUD 的扩展层
- **天气系统（后续）**：在时间面板旁扩展天气图标，复用 `day_phase_changed` 模式

---

## 附录 A: HUD 刷新流程

### A.1 进入田园

```text
farm._ready()
  -> HUD._ready() 连接信号
  -> HUD.refresh_all()
     -> refresh_time / refresh_gold / refresh_level / refresh_hotbar
  -> set_interaction_prompt("")
```

### A.2 时间推进

```text
TimeManager._advance_one_minute()
  -> EventBus.minute_changed(hour, minute)
  -> HUD.refresh_time()  # 仅改时钟文本
（跨天）-> day_started -> HUD 刷新日期
（换季）-> season_changed -> HUD 刷新季节
```

### A.3 快捷栏选择

```text
按下数字键 3
  -> Hotbar._unhandled_input -> select_slot(2)
  -> InventoryManager.select_hotbar(2)
  -> EventBus.hotbar_selected(2)
  -> Hotbar.refresh_selection()  # 第 2 槽高亮
```

---

## 附录 B: 与数据层接口对应

| HUD 行为 | 数据层接口 |
|----------|-----------|
| 时钟 | `TimeManager.get_time_text()` |
| 日期 | `TimeManager.get_date_text()` |
| 季节名 | `TimeManager.get_season_name()` |
| 昼夜阶段 | `TimeManager.get_day_phase()` |
| 金币 | `GameManager.gold`（只读） |
| 等级 | `GameManager.level`（只读） |
| 经验进度 | `GameManager.get_xp_progress()` |
| 快捷栏物品 | `InventoryManager.get_hotbar_slots()` |
| 选中槽 | `InventoryManager.get_selected_hotbar()` |
| 选择槽 | `InventoryManager.select_hotbar(index)` |
| 物品类型 | `DataManager.get_item(item_id)` → `type` |

---

> *本 PRD 完成后，玩家在田园场景中拥有完整的常驻信息层（时间/金币/等级/快捷栏/交互提示），为后续美术替换、菜单系统（PRD14）与通知系统（PRD24）提供稳定的 UI 骨架。*
