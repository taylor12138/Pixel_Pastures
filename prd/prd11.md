# PRD11: 背包 UI 面板

> **优先级**: P0 — 核心玩法从调试操作进入正式 UI 操作的第一步  
> **美术依赖**: 🔵 Godot Control 节点简易搭建（允许纯色面板、Label、ColorRect 和占位图标，不依赖正式 UI 美术）  
> **预计工期**: 5-7 天  
> **前置依赖**: PRD3（背包/库存数据层）；建议已完成 PRD9-10（角色交互与农田玩法闭环）  
> **产出**: 20 格背包面板 + 物品槽位组件 + 物品详情 + 分类筛选 + 拖拽移动/合并/交换 + 前 9 格快捷栏同步 + Tab 打开/关闭 + 农田选种联动 + 自动化/半自动化测试  
> **最后更新**: 2026-06-10

---

## 1. 目标

实现《像素田园》的第一套正式功能面板，将 PRD3 已完成的 `InventoryManager` 数据能力转化为玩家可操作的背包 UI，包含：

- 使用 `Tab` 打开或关闭背包
- 以 5 列 × 4 行网格展示全部 20 个背包槽位
- 展示物品名称、数量、类型和占位图标
- 点击槽位查看物品详情
- 拖拽物品完成移动、同类堆叠和不同物品交换
- 清晰标记前 9 格属于快捷栏
- 背包前 9 格变化时与 `InventoryManager` 快捷栏数据保持同步
- 双击或“选择”按钮将种子、水壶设为当前农田交互物
- 支持按类型筛选：全部、种子、收获物、工具、消耗品、装饰
- 背包数据变化后通过 EventBus 局部刷新对应槽位
- 面板打开时阻止角色移动、农田点击和数字键调试操作
- 提供空背包、满背包、堆叠上限和无效拖拽等反馈
- 使用 Godot 内置 Control 节点完成可用的占位视觉

完成后，玩家应能在田园场景中按 `Tab` 打开背包，查看当前物品并通过拖拽整理物品；将种子或水壶放入前 9 格后，可以在背包中直接选择该物品供 PRD10 农田交互使用。

本 PRD 只实现“背包功能面板”。常驻屏幕的快捷栏视觉与数字键切换由 PRD13 HUD 负责，但两者必须共享同一份 `InventoryManager` 数据和选中索引。

---

## 2. 核心设计决策

| 决策 | 内容 | 来源 |
|------|------|------|
| 背包容量 | 固定 20 格，布局为 5 列 × 4 行 | PRD3、GDD 角色属性 |
| 快捷栏映射 | 背包 slot 0-8 即快捷栏，不复制数据、不建立第二份数组 | PRD3 |
| UI 技术 | Godot `Control` + `CanvasLayer` + `PanelContainer` + `GridContainer` | PRD 大纲、框架调研 |
| 数据权威 | `InventoryManager` 是唯一数据源；UI 不直接修改槽位数组 | PRD3 |
| 拖拽提交 | 释放时统一调用 `InventoryManager.smart_place(from, to)` | PRD3 |
| 拖拽结果 | 目标为空则移动，同类且可堆叠则合并，否则交换 | PRD3 |
| 分类筛选 | 只改变显示状态，不改变槽位索引和真实排列 | 防止筛选后拖拽错位 |
| 物品图标 | 当前阶段允许用颜色块、首字或文本占位；正式图标后续替换 | 第三层 UI 占位策略 |
| 农田选种 | 选择快捷栏中的种子/水壶后，调用 `FarmInteractionController.sync_selection_from_hotbar()` | PRD10 当前接口 |
| 面板打开行为 | 暂停角色输入和农田交互，但默认不暂停游戏时间 | 保持世界连续性，避免 UI 与全局暂停耦合 |
| 常驻快捷栏 | PRD11 只做背包内快捷栏标识；屏幕 HUD 快捷栏属于 PRD13 | PRD 大纲 |
| 丢弃功能 | 本期提供确认后丢弃；不生成地面掉落物 | PRD3 `discard_slot()` |

---

## 3. 系统范围

### 3.1 本 PRD 覆盖内容

- 新增背包 UI 主场景 `inventory_panel.tscn`
- 新增可复用物品槽位场景 `inventory_slot.tscn`
- 新增背包面板控制脚本 `inventory_panel.gd`
- 新增槽位组件脚本 `inventory_slot.gd`
- 在田园场景增加 UI CanvasLayer 并挂载背包面板
- 20 格槽位渲染与局部刷新
- 空槽位、普通槽位、快捷栏槽位、选中槽位、拖拽目标槽位状态
- 物品名称、数量、描述、类型、价格等详情展示
- 全部/种子/收获物/工具/消耗品/装饰分类筛选
- 鼠标点击、双击、拖拽、右键取消
- 移动、合并、交换、丢弃
- 快捷栏选中索引同步
- 种子和水壶与 PRD10 农田交互选择同步
- UI 打开期间的输入拦截
- EventBus UI 信号扩展
- 自动化逻辑测试与半自动化 UI 测试

### 3.2 本 PRD 不覆盖内容

- 常驻 HUD 快捷栏、数字键 1-9 切换视觉 -> PRD13
- 金币、时间、季节、天气 HUD -> PRD13
- 商店购买、出售界面 -> PRD12
- 存档槽、设置面板和系统暂停菜单 -> PRD14
- 正式像素 UI 面板、按钮和物品图标资源 -> 后续美术替换
- 物品地面掉落、拾取和掉落物实体
- 装备系统
- 背包扩容
- 多格物品
- 物品拆分堆叠窗口
- 肥料、装饰物等物品的完整使用效果
- 移动端触屏拖拽专项适配

---

## 4. 场景与文件设计

### 4.1 需要新增/修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `scenes/ui/inventory/inventory_panel.tscn` | 新增 | 背包主面板 |
| `scenes/ui/inventory/inventory_slot.tscn` | 新增 | 单个物品槽位组件 |
| `scripts/ui/inventory/inventory_panel.gd` | 新增 | 面板状态、筛选、刷新、输入和详情控制 |
| `scripts/ui/inventory/inventory_slot.gd` | 新增 | 槽位显示、点击、拖拽与放置 |
| `scenes/farm/farm.tscn` | 修改 | 增加 `UILayer` 并实例化背包面板 |
| `scenes/farm/farm.gd` | 修改 | 绑定农田交互控制器，响应 UI 输入阻塞 |
| `scripts/autoload/event_bus.gd` | 修改 | 增加背包面板和 UI 输入状态信号 |
| `project.godot` | 修改 | 补齐 `open_bag` / `cancel` InputMap（若当前工程尚未配置） |
| `scenes/test/test_inventory_panel.tscn` | 新增 | 背包 UI 测试场景 |
| `scenes/test/test_inventory_panel.gd` | 新增 | 自动化逻辑和节点状态测试 |

建议目录：

```text
pixel-farm/
├── scenes/
│   └── ui/
│       └── inventory/
│           ├── inventory_panel.tscn
│           └── inventory_slot.tscn
├── scripts/
│   └── ui/
│       └── inventory/
│           ├── inventory_panel.gd
│           └── inventory_slot.gd
└── scenes/
    └── test/
        ├── test_inventory_panel.tscn
        └── test_inventory_panel.gd
```

### 4.2 背包面板节点结构

```text
InventoryPanel (Control)
├── DimBackground (ColorRect)
├── Window (PanelContainer)
│   └── MarginContainer
│       └── MainVBox (VBoxContainer)
│           ├── Header (HBoxContainer)
│           │   ├── TitleLabel
│           │   ├── CapacityLabel
│           │   └── CloseButton
│           ├── FilterBar (HBoxContainer)
│           │   ├── AllButton
│           │   ├── SeedButton
│           │   ├── HarvestButton
│           │   ├── ToolButton
│           │   ├── ConsumableButton
│           │   └── DecorationButton
│           ├── Content (HBoxContainer)
│           │   ├── InventorySection (VBoxContainer)
│           │   │   ├── HotbarHintLabel
│           │   │   └── SlotsGrid (GridContainer, columns = 5)
│           │   └── DetailPanel (PanelContainer)
│           │       └── DetailVBox (VBoxContainer)
│           │           ├── ItemIconPlaceholder
│           │           ├── ItemNameLabel
│           │           ├── ItemTypeLabel
│           │           ├── QuantityLabel
│           │           ├── PriceLabel
│           │           ├── DescriptionLabel
│           │           ├── SelectButton
│           │           └── DiscardButton
│           └── FooterHintLabel
└── DiscardConfirmDialog (ConfirmationDialog)
```

### 4.3 田园场景挂载

在现有 `farm.tscn` 中增加：

```text
Farm
├── ...
├── UILayer (CanvasLayer)
│   └── InventoryPanel
└── DebugLayer
```

要求：

- `UILayer.layer` 高于场景和调试地块绘制
- 背包关闭时 `visible = false`
- `InventoryPanel` 使用全屏锚点，基础视口为 480×320
- 背景遮罩覆盖全屏，阻止鼠标事件落到农田
- 不把背包节点放在会随相机移动的 `Node2D` 下

---

## 5. 布局与占位视觉规范

### 5.1 基础分辨率

项目基础分辨率为 480×320，背包面板建议占用：

| 区域 | 建议尺寸 |
|------|----------|
| 全屏遮罩 | 480×320 |
| 主窗口 | 420×276 |
| 单个槽位 | 40×40 |
| 槽位间距 | 4px |
| 详情区域宽度 | 140-160px |
| 正文字号 | 12-14px |
| 标题字号 | 16-18px |

### 5.2 槽位视觉状态

| 状态 | 占位表现 |
|------|----------|
| 空槽位 | 深灰/棕色底，无图标 |
| 有物品 | 类型色块 + 物品名首字/短文本 + 右下角数量 |
| 快捷栏槽位 0-8 | 左上角显示数字 1-9，边框颜色不同 |
| 当前快捷栏选中 | 黄色或浅绿色高亮边框 |
| 当前详情选中 | 白色边框 |
| 正在拖拽 | 源槽位降低透明度 |
| 可放置目标 | 绿色边框 |
| 不可放置目标 | 红色边框 |
| 筛选隐藏 | 不显示物品内容，但槽位位置仍保留 |

推荐类型占位颜色：

| 类型 | 颜色 |
|------|------|
| `seed` | 浅绿色 |
| `harvest` | 橙黄色 |
| `tool` | 蓝灰色 |
| `consumable` | 紫色 |
| `decoration` | 棕黄色 |
| 未知类型 | 灰色 |

### 5.3 像素 UI 约束

- UI 坐标和尺寸尽量使用整数
- 不使用模糊缩放和线性过滤
- 图标区域预留 24×24 或 32×32 像素
- 当前阶段不要求引入外部字体；需确保中文可读
- 后续替换正式 Theme 时，不改变节点职责和脚本接口

---

## 6. InventoryPanel

新增 `scripts/ui/inventory/inventory_panel.gd`。

### 6.1 职责

- 管理背包面板打开/关闭状态
- 创建并绑定 20 个 `InventorySlot` 实例
- 从 `InventoryManager` 读取槽位数据
- 监听背包、快捷栏和读档事件
- 管理分类筛选
- 管理详情选中槽位
- 管理丢弃确认流程
- 向农田交互控制器同步快捷栏选择
- 控制 UI 打开期间的玩家和场景输入
- 向其他 UI 广播面板状态

### 6.2 核心属性

```gdscript
enum FilterType {
	ALL,
	SEED,
	HARVEST,
	TOOL,
	CONSUMABLE,
	DECORATION,
}

@export var close_on_cancel: bool = true
@export var pause_world_time_when_open: bool = false

var is_open: bool = false
var current_filter: FilterType = FilterType.ALL
var selected_slot_index: int = -1
var pending_discard_slot_index: int = -1
var farm_interaction_controller: Node = null
var slot_views: Array[Control] = []
```

### 6.3 公共接口

```gdscript
## 绑定农田交互控制器；其他场景允许传 null
func setup(interaction_controller: Node = null) -> void

## 打开背包
func open_panel() -> void

## 关闭背包
func close_panel() -> void

## 切换打开/关闭
func toggle_panel() -> void

## 当前是否打开
func is_panel_open() -> bool

## 刷新全部 20 格
func refresh_all_slots() -> void

## 只刷新指定真实槽位
func refresh_slot(slot_index: int) -> void

## 设置分类筛选
func set_filter(filter_type: FilterType) -> void

## 选择槽位并刷新详情
func select_slot(slot_index: int) -> void

## 清空详情选择
func clear_selection() -> void

## 将指定快捷栏槽位设为当前选中项
func select_hotbar_slot(slot_index: int) -> bool

## 请求丢弃指定槽位
func request_discard(slot_index: int) -> void

## 确认丢弃
func confirm_discard() -> bool
```

### 6.4 初始化流程

```text
InventoryPanel._ready()
  -> 创建/收集 20 个槽位节点
  -> 为每个槽位设置真实 slot_index
  -> 连接槽位点击/双击/拖拽结果信号
  -> 连接 EventBus.inventory_changed
  -> 连接 EventBus.hotbar_selected
  -> 连接 EventBus.game_loaded
  -> refresh_all_slots()
  -> close_panel()
```

要求：

- 槽位组件始终绑定真实索引 0-19
- 筛选不能重新编号
- 读档后必须全量刷新
- 面板关闭后保留当前筛选和详情选择，除非该物品已不存在

---

## 7. InventorySlot

新增 `scripts/ui/inventory/inventory_slot.gd`。

### 7.1 职责

- 显示单个槽位的物品数据
- 显示快捷栏编号和选中状态
- 响应单击、双击和鼠标悬停
- 提供 Godot Control 拖放接口
- 只提交槽位索引，不直接修改库存数据

### 7.2 核心属性

```gdscript
@export var slot_index: int = -1

var slot_data: Variant = null
var item_data: Dictionary = {}
var is_hotbar_slot: bool = false
var is_hotbar_selected: bool = false
var is_detail_selected: bool = false
var filtered_out: bool = false
```

### 7.3 槽位信号

```gdscript
signal slot_clicked(slot_index: int)
signal slot_double_clicked(slot_index: int)
signal slot_context_requested(slot_index: int)
signal drag_finished(from_index: int, to_index: int, success: bool)
```

### 7.4 公共接口

```gdscript
## 设置真实槽位索引
func setup(index: int) -> void

## 刷新槽位数据与物品元数据
func set_slot_data(data: Variant, metadata: Dictionary) -> void

## 设置是否因筛选隐藏内容
func set_filtered_out(value: bool) -> void

## 设置快捷栏选中状态
func set_hotbar_selected(value: bool) -> void

## 设置详情选中状态
func set_detail_selected(value: bool) -> void

## 清空显示
func clear_display() -> void
```

### 7.5 Godot 拖放接口

```gdscript
func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_data == null or filtered_out:
		return null
	var payload := {
		"source": "inventory",
		"slot_index": slot_index,
		"item_id": str(slot_data.get("item_id", "")),
	}
	set_drag_preview(_build_drag_preview())
	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.get("source", "") == "inventory"
		and int(data.get("slot_index", -1)) != slot_index
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_index := int(data.get("slot_index", -1))
	var success := InventoryManager.smart_place(from_index, slot_index)
	drag_finished.emit(from_index, slot_index, success)
```

约束：

- UI 不自行实现移动、合并和交换算法
- 释放到原槽位时不操作
- 释放到面板外时默认取消，不自动丢弃
- 筛选隐藏的物品不可作为拖拽源
- 空槽位即使在筛选模式下仍可作为目标

---

## 8. 数据展示规则

### 8.1 槽位数据来源

槽位运行时数据：

```gdscript
{
	"item_id": "seed_carrot",
	"quantity": 12,
}
```

物品元数据来自：

```gdscript
var item_data: Dictionary = DataManager.get_item(item_id)
```

### 8.2 槽位显示字段

| 字段 | 来源 | 显示规则 |
|------|------|----------|
| 名称 | `item_data.name` | 槽位可显示首字或短名，完整名称在详情区 |
| 数量 | `slot_data.quantity` | 数量 > 1 时显示；工具数量 1 可隐藏 |
| 类型 | `item_data.type` | 决定占位颜色与筛选 |
| 图标 | 未来 `icon_path` | 当前无资源时使用类型色块和文字 |
| 快捷键 | 真实索引 0-8 | 显示 1-9 |

### 8.3 详情面板字段

| 字段 | 展示内容 |
|------|----------|
| 物品名 | `name`，缺失时回退 `item_id` |
| 类型 | 中文映射：种子/收获物/工具/消耗品/装饰 |
| 数量 | 当前槽位数量；可附加全背包总数量 |
| 描述 | `description` |
| 买入价 | `price` 存在时显示 |
| 卖出价 | `sell_price` 存在时显示 |
| 作物关联 | `crop_id` 存在时可显示对应作物名 |
| 堆叠 | `quantity / max_stack` |

空槽位被选中时，详情面板显示“空槽位”，并隐藏选择和丢弃按钮。

---

## 9. 分类筛选

### 9.1 筛选类型映射

| UI 分类 | `items.json` type |
|---------|-------------------|
| 全部 | 不筛选 |
| 种子 | `seed` |
| 收获物 | `harvest` |
| 工具 | `tool` |
| 消耗品 | `consumable` |
| 装饰 | `decoration` |

### 9.2 筛选行为

- 筛选只影响物品内容是否可见
- 20 个槽位的网格位置不改变
- 空槽位始终显示
- 被筛掉的物品槽位显示为禁用/半透明占位，不允许作为拖拽源
- 筛选后不得压缩物品到前面，也不得改变真实索引
- 如果当前详情物品被筛掉，清空详情选择
- 切回“全部”后恢复原排列

此规则的目的，是保证快捷栏 slot 0-8 和拖拽索引始终稳定。

---

## 10. 快捷栏同步

### 10.1 数据关系

```text
背包槽位 0-8
    = InventoryManager.get_hotbar_slots()
    = PRD13 HUD 快捷栏的数据源
```

禁止：

- 在背包 UI 中维护独立快捷栏数组
- 将物品“复制”到快捷栏
- 仅保存 HUD 快捷栏而不保存背包槽位

### 10.2 选中规则

- 单击任意槽位：只查看详情
- 双击 slot 0-8：调用 `InventoryManager.select_hotbar(slot_index)`
- 详情区点击“选择”：仅当槽位位于 0-8 时可直接选择
- 非快捷栏物品点击“选择”时，提示“请先拖到前 9 格”
- 当前选中索引通过 `EventBus.hotbar_selected(index)` 刷新高亮
- 选中的快捷栏为空时允许保留索引，但农田交互模式应变为 `NONE`

### 10.3 与农田交互联动

当快捷栏选择变化时：

```gdscript
func _on_hotbar_selected(index: int) -> void:
	_refresh_hotbar_highlight(index)
	if farm_interaction_controller != null:
		farm_interaction_controller.sync_selection_from_hotbar()
```

物品映射：

| 选中物品 | PRD10 行为 |
|----------|------------|
| `type == "seed"` | 调用 `select_seed(crop_id)`，进入种植模式 |
| `item_id == "watering_can"` | 调用 `select_tool("watering_can")`，进入浇水模式 |
| 空槽位 | 清空当前交互选择 |
| 其他物品 | 当前 PRD 不执行使用效果，显示“暂不可在农田使用” |

实现时需补齐 PRD10 的空槽位同步行为：如果 `sync_selection_from_hotbar()` 当前对空槽位直接返回，应改为调用清空选择接口，避免 UI 显示已选空格但交互控制器仍保留旧种子。

---

## 11. 面板输入与游戏状态

### 11.1 InputMap

确认 `project.godot` 存在：

```text
open_bag: Tab
cancel: Mouse Right, Escape
```

当前工程若只有 `ui_pause`，PRD11 必须新增独立 `open_bag`，不能复用保存或暂停操作。

### 11.2 输入优先级

```text
背包关闭：
  Tab -> 打开背包
  场景输入正常

背包打开：
  Tab -> 关闭背包
  Escape / 右键 -> 取消拖拽或关闭背包
  鼠标事件 -> 仅由背包 UI 消费
  WASD / E / 数字键调试 -> 不传给角色和农田
```

### 11.3 打开面板时的控制

打开时：

- `visible = true`
- 设置 UI 输入阻塞状态
- 调用 PlayerController 的移动/交互禁用接口
- 禁止 `farm.gd` 处理地块点击
- 默认不暂停 `TimeManager`
- 发射 `inventory_panel_opened`
- 将焦点交给关闭按钮或第一个槽位

关闭时：

- `visible = false`
- 恢复玩家移动和交互
- 恢复农田点击
- 清理拖拽视觉
- 发射 `inventory_panel_closed`

不建议直接使用 `get_tree().paused = true`，因为：

- 会影响 TimeManager、作物推进和自动存档的运行语义
- 后续多个功能面板可能需要统一管理暂停策略
- PRD14 系统菜单才负责真正的全局暂停

---

## 12. 拖拽与槽位操作规则

### 12.1 移动到空槽位

```text
源：seed_carrot × 12
目标：空
结果：源为空，目标为 seed_carrot × 12
```

调用：

```gdscript
InventoryManager.smart_place(from_index, to_index)
```

### 12.2 同类合并

```text
源：seed_carrot × 20
目标：seed_carrot × 70
max_stack：99
结果：源为空，目标为 seed_carrot × 90
```

部分合并：

```text
源：seed_carrot × 20
目标：seed_carrot × 90
结果：源为 seed_carrot × 11，目标为 seed_carrot × 99
```

### 12.3 不同物品交换

```text
源：seed_carrot × 12
目标：watering_can × 1
结果：两格互换
```

### 12.4 同类但目标已满

现有 `smart_place()` 在同类合并数量为 0 时会回退到交换。UI 必须明确遵循当前数据层行为：

- 目标堆叠已满时，两个同类堆叠交换位置
- 不视为操作失败
- 如果后续产品希望“满堆叠同类不操作”，应先修改 PRD3 数据层契约，再调整 UI

### 12.5 丢弃

- 选中非空槽位后可点击“丢弃”
- 弹出确认对话框，展示物品名和数量
- 当前版本默认丢弃整格
- 确认后调用 `InventoryManager.discard_slot(slot_index, -1)`
- 取消不改变数据
- 工具也允许丢弃，但需使用更明确的确认文案
- 背包面板外释放不触发丢弃

---

## 13. EventBus 扩展

在 `scripts/autoload/event_bus.gd` 增加：

```gdscript
# ─── 背包 UI ───
signal inventory_panel_opened()
signal inventory_panel_closed()
signal inventory_slot_selected(slot_index: int, slot_data: Variant)
signal inventory_filter_changed(filter_type: String)
signal inventory_drag_completed(from_index: int, to_index: int, success: bool)
signal inventory_discard_requested(slot_index: int, item_id: String, quantity: int)
signal ui_input_block_changed(blocked: bool)
```

### 13.1 已有信号监听

| 信号 | UI 行为 |
|------|---------|
| `inventory_changed(slot_index)` | 局部刷新指定槽位 |
| `inventory_full()` | 显示“背包已满”提示 |
| `hotbar_selected(index)` | 刷新快捷栏选中边框和农田选择 |
| `item_added(...)` | 可选：短暂高亮入包槽位 |
| `item_removed(...)` | 刷新详情数量，数量为 0 时清空详情 |
| `game_loaded(...)` | 全量刷新 20 格、筛选和快捷栏高亮 |

### 13.2 信号发射规则

- 面板状态只有发生变化时才发射 opened/closed
- 拖拽结束无论成功失败都发射 `inventory_drag_completed`
- 槽位选中发射的数据必须是副本或 `null`
- `ui_input_block_changed(true)` 在面板完全显示前发射
- `ui_input_block_changed(false)` 在面板关闭后发射

---

## 14. 错误提示与边界情况

| 场景 | 预期行为 |
|------|----------|
| `Tab` 快速连按 | 最终状态确定，不重复连接信号、不创建重复槽位 |
| 空槽位点击 | 显示空详情，不报错 |
| 空槽位拖拽 | 不启动拖拽 |
| 拖到原槽位 | 取消操作，不发出数据变化 |
| 拖到面板外 | 取消操作，不丢弃 |
| 拖到筛选隐藏槽位 | 允许作为目标，因为真实槽位仍存在；目标内容应在释放后按筛选规则显示/隐藏 |
| 物品元数据缺失 | 显示 `item_id`、未知类型和默认灰色，不崩溃 |
| 数量达到上限 | 显示 `99/99`，同类拖入按数据层规则处理 |
| 读档期间面板打开 | 读档完成后全量刷新，失效详情选择自动清除 |
| 当前选中物品被移除 | 快捷栏索引保留，交互模式同步为空 |
| 面板打开时点击农田 | UI 消费事件，地块状态不改变 |
| 面板打开时按 E | 不触发农田交互 |
| 面板打开时按 1-9 | PRD11 不处理快捷栏数字键，也不得触发 PRD10 调试直选 |
| 丢弃最后一个当前选中物品 | 清空详情并同步农田交互选择 |
| 背包已满 | 面板容量显示 20/20，监听 `inventory_full` 提示 |

---

## 15. 测试需求

### 15.1 自动化测试场景

创建：

```text
scenes/test/test_inventory_panel.tscn
scenes/test/test_inventory_panel.gd
```

测试场景应包含：

- 独立 `InventoryPanel`
- 可选的 FarmInteractionController 测试替身或真实节点
- 结果 Label
- 可直接运行的测试入口

### 15.2 自动化测试用例

| 用例 | 预期 |
|------|------|
| 初始化槽位 | 创建并绑定 20 个槽位，索引 0-19 |
| 打开/关闭 | visible 与 is_open 一致，状态信号各发射一次 |
| Tab 切换 | 连续触发能正确开关 |
| 全量刷新 | UI 与 `InventoryManager.get_all_slots()` 一致 |
| 局部刷新 | `inventory_changed(3)` 只需更新 slot 3 |
| 空槽位显示 | 无物品名、数量和拖拽数据 |
| 物品显示 | 名称、数量、类型与元数据一致 |
| 快捷栏标记 | slot 0-8 显示 1-9，slot 9 不显示 |
| 快捷栏选择 | 调用 select 后索引和高亮一致 |
| 移动到空格 | 两个槽位显示与数据层一致 |
| 同类完全合并 | 源槽为空，目标数量正确 |
| 同类部分合并 | 目标达上限，源保留余量 |
| 不同物品交换 | 两格内容互换 |
| 无效拖拽 | 数据不变，不崩溃 |
| 分类筛选 | 仅目标类型可见，真实索引不改变 |
| 清除筛选 | 原排列完整恢复 |
| 详情显示 | 选中物品字段完整 |
| 丢弃取消 | 数据不变 |
| 丢弃确认 | 整格清空并刷新详情 |
| 读档刷新 | 导入新槽位数据后 UI 全量同步 |
| 缺失元数据 | 使用回退显示，不崩溃 |
| 空快捷栏同步 | 农田交互选择被清空 |

### 15.3 半自动化手测清单

在 `farm.tscn` 中验证：

1. 启动游戏后按 `Tab`，背包居中打开
2. 面板显示 20 格，前 9 格标有数字 1-9
3. 面板打开时角色不能移动，点击农田不会种植或浇水
4. 点击胡萝卜种子，右侧显示名称、类型、数量、价格和描述
5. 将种子拖到空格，源和目标正确更新
6. 将同类种子拖到一起，数量按 99 上限合并
7. 将不同物品互拖，两格交换
8. 切换“种子”筛选，非种子物品隐藏但位置不重排
9. 将种子拖入前 9 格并双击，快捷栏高亮变化
10. 关闭背包后，对空地按 `E` 可使用刚选中的种子
11. 重新打开背包，选择水壶并关闭，可对作物浇水
12. 丢弃物品时出现确认框，取消和确认行为正确
13. 按 `Tab` 或 `Escape` 可关闭面板并恢复角色控制
14. 保存、读档后背包 UI 与槽位顺序一致

---

## 16. 验收标准

### 16.1 功能验收

- [ ] `Tab` 可稳定打开/关闭背包
- [ ] 背包以 5×4 网格展示固定 20 格
- [ ] 所有槽位数据来自 InventoryManager
- [ ] 物品名称、数量、类型和详情正确显示
- [ ] 前 9 格有快捷栏编号和选中高亮
- [ ] 支持拖拽移动到空格
- [ ] 支持同类物品合并，遵守最大堆叠数量
- [ ] 支持不同物品交换
- [ ] 支持全部、种子、收获物、工具、消耗品、装饰筛选
- [ ] 筛选不改变真实槽位索引和顺序
- [ ] 支持确认后丢弃整格物品
- [ ] 种子和水壶可同步到 PRD10 农田交互
- [ ] 当前快捷栏物品移除后不会继续使用旧选择

### 16.2 输入与体验验收

- [ ] 面板打开时不会误触角色移动、农田点击或 E 键交互
- [ ] 鼠标事件不会穿透遮罩
- [ ] 关闭面板后角色和农田交互恢复
- [ ] 空槽位和无效拖拽不会报错
- [ ] 背包已满、不可使用、丢弃等情况有明确提示
- [ ] 480×320 基础分辨率下文字可读、窗口不超出屏幕
- [ ] 无正式美术资源也能清晰识别槽位状态和物品类型

### 16.3 工程验收

- [ ] UI 不直接访问或修改 InventoryManager `_slots`
- [ ] 移动/合并/交换统一调用 `smart_place()`
- [ ] 背包 UI 与未来 HUD 不维护重复快捷栏数据
- [ ] 事件连接不会因重复打开面板而重复注册
- [ ] 读档后背包 UI 可正确全量刷新
- [ ] 新增测试场景可独立运行
- [ ] 不破坏 PRD1-10 已有测试
- [ ] 控制台无持续报错和无效节点引用

---

## 17. 实施建议

建议按以下顺序开发：

1. 创建 `InventorySlot` 场景，完成空槽和物品数据渲染
2. 创建 `InventoryPanel`，生成固定 20 格并连接 InventoryManager
3. 实现 `Tab` 开关和 UI 输入阻塞
4. 实现单击详情和快捷栏高亮
5. 接入 Godot Control 拖放与 `smart_place()`
6. 实现分类筛选，确认索引不重排
7. 实现丢弃确认
8. 接入 FarmInteractionController 快捷栏同步
9. 增加 EventBus 信号和读档刷新
10. 补齐自动化测试与田园场景手测

---

## 18. 风险与注意事项

| 风险 | 说明 | 应对 |
|------|------|------|
| 筛选后索引错位 | 若只生成筛选结果列表，拖拽会操作错误真实槽位 | 固定保留 20 个槽位，始终绑定原索引 |
| UI 与数据双写 | UI 自己交换显示但数据层未变，会产生不同步 | 所有变更先调用 InventoryManager，再由信号刷新 |
| 快捷栏存在两份数据 | PRD11 和 PRD13 各自维护数组会产生存档与显示冲突 | 明确 slot 0-8 是唯一快捷栏数据 |
| 输入穿透 | 点击槽位同时触发农田种植 | 全屏遮罩设为 Stop，并提供全局 UI 输入阻塞状态 |
| 空快捷栏保留旧种子 | PRD10 同步函数可能对空槽直接返回 | 空槽时显式清空 FarmInteractionController 选择 |
| 调试数字键冲突 | PRD10 当前数字键可直接切换种子/工具 | 面板打开时优先消费键盘输入；PRD13 完成后移除调试直选 |
| 拖拽预览缩放模糊 | Control 预览可能使用非整数尺寸 | 使用整数尺寸和 Nearest 过滤 |
| 缺少正式图标 | items.json 当前没有 icon_path | 使用类型色块和短文本占位，保留后续图标接口 |
| 全局暂停副作用 | `get_tree().paused` 可能停止时间、存档或 UI 自身 | PRD11 默认只禁用玩法输入 |
| 详情引用失效 | 拖拽、出售或读档后原槽位内容变化 | 每次 inventory_changed 后重新读取详情 |

---

## 19. 技术约束

1. **Godot 版本**
   - 兼容项目当前 Godot 4.6 配置
   - 不使用已废弃的 Control 拖放 API

2. **数据边界**
   - UI 只使用 `get_slot()` / `get_all_slots()` 等公开查询接口
   - 不访问 `_slots`
   - 不在 UI 脚本中复制堆叠算法

3. **事件驱动**
   - 背包数据变化优先通过 `inventory_changed` 局部刷新
   - 读档等批量变化允许全量刷新
   - 不在 `_process()` 中轮询整个背包

4. **可复用性**
   - `InventorySlot` 不依赖田园场景
   - `InventoryPanel.setup(null)` 时仍可在房间、商店或测试场景运行
   - 农田联动通过可选 controller 引用实现

5. **输入**
   - `open_bag` 与 `ui_pause` 分离
   - UI 打开时必须消费对应输入
   - 不由 InventoryManager 主动监听键盘

6. **视觉**
   - 当前阶段使用内置节点和 ThemeOverride 即可
   - 不要求下载或生成正式美术资源
   - 后续替换素材不得改变核心节点接口

---

## 20. 与后续 PRD 的衔接

- **PRD12 商店 UI**：复用 `InventorySlot` 或其只读变体展示商品和可出售物品
- **PRD13 HUD**：读取相同的 slot 0-8 与 `selected_hotbar_index`，实现常驻快捷栏和数字键切换
- **PRD14 设置/存档 UI**：可建立统一 `UIManager` 管理功能面板互斥、焦点和暂停
- **PRD15 角色动画**：背包打开时可切换角色 idle 或禁止移动，不改变背包接口
- **PRD18 特效**：监听 `item_added` 实现物品飞向背包图标
- **PRD19 音频**：监听面板打开、关闭、拖拽和按钮事件播放 UI 音效
- **PRD25 装饰系统**：选择装饰物后，可从背包进入布置模式

PRD13 接入后应完成以下清理：

1. 由 HUD 统一监听数字键 1-9 并调用 `InventoryManager.select_hotbar()`
2. 删除或关闭 PRD10 中数字键直选胡萝卜、白菜、玉米、水壶的调试逻辑
3. 背包面板与 HUD 同时监听 `inventory_changed` 和 `hotbar_selected`
4. 两套 UI 的选中边框始终指向同一个 `selected_hotbar_index`

---

## 附录 A: 背包交互流程

### A.1 打开背包

```text
玩家按 Tab
  -> InventoryPanel.toggle_panel()
  -> open_panel()
  -> 阻塞玩法输入
  -> refresh_all_slots()
  -> 显示面板
  -> EventBus.inventory_panel_opened
```

### A.2 拖拽物品

```text
从 slot 2 开始拖拽
  -> payload 记录 from_index = 2
  -> 释放到 slot 8
  -> InventoryManager.smart_place(2, 8)
  -> InventoryManager 发射 inventory_changed(2/8)
  -> InventoryPanel 局部刷新
  -> EventBus.inventory_drag_completed
```

### A.3 选择种子

```text
种子位于 slot 3
  -> 双击 slot 3
  -> InventoryManager.select_hotbar(3)
  -> EventBus.hotbar_selected(3)
  -> 背包刷新高亮
  -> FarmInteractionController.sync_selection_from_hotbar()
  -> select_seed(crop_id)
  -> 关闭背包后可在农田种植
```

### A.4 丢弃物品

```text
选中 slot 12
  -> 点击丢弃
  -> ConfirmationDialog
  -> 玩家确认
  -> InventoryManager.discard_slot(12, -1)
  -> inventory_changed(12)
  -> 清空槽位和详情
```

---

## 附录 B: 与 PRD3 数据层接口对应

| PRD11 UI 行为 | PRD3 接口 |
|---------------|-----------|
| 渲染单格 | `get_slot(slot_index)` |
| 渲染全部 | `get_all_slots()` |
| 显示快捷栏 | `get_hotbar_slots()` |
| 选择快捷栏 | `select_hotbar(index)` |
| 获取当前选择 | `get_selected_item()` |
| 拖拽移动/合并/交换 | `smart_place(from_index, to_index)` |
| 丢弃整格 | `discard_slot(slot_index, -1)` |
| 分类查询辅助 | `get_items_by_type(type)` |
| 显示容量 | `get_empty_slot_count()` |
| 满载状态 | `is_full()` |

---

> *本 PRD 完成后，背包应从“仅代码可操作的数据系统”升级为“玩家可查看、整理、选择和管理物品的正式功能面板”，并为 PRD12-14 的完整 UI 阶段建立可复用的 Control 组件与输入管理基础。*
