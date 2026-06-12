# PRD12: 商店 UI 面板

> **优先级**: P1 — 经济闭环从调试调用进入正式 UI 操作的关键一步
> **美术依赖**: 🔵 Godot Control 节点简易搭建（允许纯色面板、Label、ColorRect 和占位图标，不依赖正式 UI 美术）
> **预计工期**: 5-7 天
> **前置依赖**: PRD4（经济系统 + 商店逻辑数据层，`EconomyManager`）、PRD5（等级/解锁系统，`LevelManager`）；建议已完成 PRD11（背包 UI，可复用槽位/详情组件与 UI 输入阻塞约定）
> **产出**: 商店面板（购买 / 出售双 Tab）+ 商品列表行组件 + 可售物品聚合列表 + 数量选择 + 购买/出售确认 + 余额与等级锁定显示 + 交易结果反馈 + 自动化/半自动化测试
> **最后更新**: 2026-06-11

---

## 1. 目标

实现《像素田园》的第二套正式功能面板，将 PRD4 已完成的 `EconomyManager` 数据能力转化为玩家可操作的商店 UI，包含：

- 打开/关闭商店面板（进入种子商店场景或与店主"老陈"交互时打开）
- 以「购买」「出售」两个 Tab 切换交易模式
- 购买 Tab 展示可购买商品（种子、消耗品、装饰），含名称、单价、已拥有数量、解锁状态
- 出售 Tab 展示背包中可出售物品（收获物），聚合显示总数量与单价
- 选择商品后可调整购买/出售数量（1 / 5 / 10 / 最大）
- 实时显示玩家当前金币余额与本次交易总价
- 对未达解锁等级的种子显示锁定状态与所需等级，禁止购买
- 购买前校验金币与背包空间，出售前校验持有数量
- 交易成功/失败通过结果反馈与 `EventBus` 通知
- 交易后局部刷新对应商品行、余额与背包关联状态
- 面板打开时阻止角色移动、农田点击和数字键调试操作
- 使用 Godot 内置 Control 节点完成可用的占位视觉

完成后，玩家应能进入商店打开面板，在「购买」中选购已解锁种子并扣除金币、入背包，在「出售」中卖出背包内收获物并获得金币；锁定种子明确提示所需等级，金币/容量不足时给出清晰反馈。

本 PRD 只实现"商店功能面板"。金币常驻 HUD 显示与种子商店场景美术分别由 PRD13、PRD17 负责，但三者必须共享同一份 `GameManager.gold` 和 `EconomyManager` 数据。

---

## 2. 核心设计决策

| 决策 | 内容 | 来源 |
|------|------|------|
| 数据权威 | `EconomyManager` 是唯一交易数据源；UI 不直接增减金币或修改背包 | PRD4 |
| 价格来源 | 通过 `get_buy_price()` / `get_sell_price()` 查询，不在 UI 复制价格表 | PRD4 |
| 商品列表 | 购买列表来自 `get_shop_items()`，出售列表来自 `get_sellable_inventory_items()` | PRD4 |
| 交易提交 | 购买调用 `buy_item()`/`buy_seed()`，出售调用 `sell_item()`/`sell_harvest()` | PRD4 |
| 交易预校验 | 选择/调数量时调用 `can_buy_item()` / `can_sell_item()` 决定按钮可用性 | PRD4 |
| 解锁判定 | 种子解锁状态以 `LevelManager.is_crop_unlocked()` 为准，UI 只读不改 | PRD5 |
| 可买类型 | 仅 `seed` / `consumable` / `decoration` 进入购买列表 | PRD4 `BUYABLE_TYPES` |
| 可卖类型 | 仅 `harvest` 进入出售列表 | PRD4 `SELLABLE_TYPES` |
| UI 技术 | Godot `Control` + `CanvasLayer` + `PanelContainer` + `TabBar/VBox` + `ScrollContainer` | PRD 大纲、框架调研 |
| 商品图标 | 当前阶段允许用颜色块、首字或文本占位；正式图标后续替换 | 第三层 UI 占位策略 |
| 面板打开行为 | 暂停角色输入和农田交互，但默认不暂停游戏时间 | 与 PRD11 一致 |
| 余额刷新 | 监听 `EventBus.gold_changed` 局部刷新余额与可买性，不轮询 | PRD4 |
| 数量上限 | 购买受金币与背包空间约束，出售受持有数量约束，UI 自动收敛"最大值" | 防止提交注定失败的交易 |
| 锁定商品 | 锁定种子仍展示在列表中（灰显），但不可选数量、不可购买 | 引导玩家升级 |

---

## 3. 系统范围

### 3.1 本 PRD 覆盖内容

- 新增商店 UI 主场景 `shop_panel.tscn`
- 新增可复用商品行场景 `shop_item_row.tscn`（购买/出售共用，按 mode 区分）
- 新增商店面板控制脚本 `shop_panel.gd`
- 新增商品行组件脚本 `shop_item_row.gd`
- 商店面板挂载点（种子商店场景或田园场景临时入口）
- 购买/出售双 Tab 切换
- 购买列表渲染：种子 + 消耗品 + 装饰
- 出售列表渲染：背包可售收获物聚合
- 商品行状态：普通、选中、锁定、买不起、空间不足、无可售
- 数量选择（1 / 5 / 10 / 最大）与总价计算
- 余额、总价、解锁等级显示
- 购买/出售确认与结果反馈
- 交易后局部刷新与列表重算
- UI 打开期间的输入拦截
- EventBus 商店 UI 信号扩展
- 自动化逻辑测试与半自动化 UI 测试

### 3.2 本 PRD 不覆盖内容

- 金币、时间、季节常驻 HUD -> PRD13
- 种子商店场景正式美术、店主 NPC 立绘与动画 -> PRD15、PRD17
- 背包功能面板本体 -> PRD11
- 存档槽、设置面板和系统暂停菜单 -> PRD14
- 正式像素 UI 面板、按钮和商品图标资源 -> 后续美术替换
- 限时折扣、季节性商品、公告板活动
- 批量"一键出售全部"高级操作（本期仅按物品逐项出售）
- 道具实际使用效果（肥料、装饰摆放等）
- 店主对话系统与种植小贴士
- 移动端触屏专项适配

---

## 4. 场景与文件设计

### 4.1 需要新增/修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `scenes/ui/shop/shop_panel.tscn` | 新增 | 商店主面板 |
| `scenes/ui/shop/shop_item_row.tscn` | 新增 | 单个商品/可售物品行组件 |
| `scripts/ui/shop/shop_panel.gd` | 新增 | 面板状态、Tab、列表刷新、数量、输入和结果控制 |
| `scripts/ui/shop/shop_item_row.gd` | 新增 | 商品行显示、选中、数量与购买/出售按钮 |
| `scenes/shop/shop.tscn` | 新增/修改 | 种子商店场景，挂载 `UILayer` 与商店面板 |
| `scripts/autoload/event_bus.gd` | 修改 | 增加商店面板 UI 状态信号 |
| `scenes/test/test_shop_panel.tscn` | 新增 | 商店 UI 测试场景 |
| `scenes/test/test_shop_panel.gd` | 新增 | 自动化逻辑和节点状态测试 |

建议目录：

```text
pixel-farm/
├── scenes/
│   ├── ui/
│   │   └── shop/
│   │       ├── shop_panel.tscn
│   │       └── shop_item_row.tscn
│   └── shop/
│       └── shop.tscn
├── scripts/
│   └── ui/
│       └── shop/
│           ├── shop_panel.gd
│           └── shop_item_row.gd
└── scenes/
    └── test/
        ├── test_shop_panel.tscn
        └── test_shop_panel.gd
```

### 4.2 商店面板节点结构

```text
ShopPanel (Control)
├── DimBackground (ColorRect)
├── Window (PanelContainer)
│   └── MarginContainer
│       └── MainVBox (VBoxContainer)
│           ├── Header (HBoxContainer)
│           │   ├── TitleLabel              # "种子商店"
│           │   ├── GoldLabel               # 当前金币
│           │   └── CloseButton
│           ├── TabBar (HBoxContainer)
│           │   ├── BuyTabButton            # 购买
│           │   └── SellTabButton           # 出售
│           ├── Content (HBoxContainer)
│           │   ├── ListSection (VBoxContainer)
│           │   │   └── ListScroll (ScrollContainer)
│           │   │       └── ItemList (VBoxContainer)   # 动态填充 ShopItemRow
│           │   └── DetailPanel (PanelContainer)
│           │       └── DetailVBox (VBoxContainer)
│           │           ├── ItemIconPlaceholder
│           │           ├── ItemNameLabel
│           │           ├── ItemTypeLabel
│           │           ├── UnitPriceLabel
│           │           ├── OwnedCountLabel
│           │           ├── UnlockLabel           # 锁定时显示所需等级
│           │           ├── DescriptionLabel
│           │           ├── QuantitySelector (HBoxContainer)
│           │           │   ├── Qty1Button
│           │           │   ├── Qty5Button
│           │           │   ├── Qty10Button
│           │           │   └── QtyMaxButton
│           │           ├── TotalPriceLabel
│           │           └── ConfirmButton         # 购买 / 出售
│           └── FooterHintLabel
└── ConfirmDialog (ConfirmationDialog)            # 大额/装饰等可选二次确认
```

### 4.3 商店场景挂载

```text
Shop
├── ShopBackground (占位)
├── ShopkeeperPlaceholder (ColorRect/Node2D，店主占位)
├── UILayer (CanvasLayer)
│   └── ShopPanel
└── DebugLayer
```

要求：

- `UILayer.layer` 高于场景绘制
- 面板关闭时 `visible = false`
- `ShopPanel` 使用全屏锚点，基础视口为 480×320
- 背景遮罩覆盖全屏，阻止鼠标事件落到场景
- 商店面板可在 `farm.tscn` 临时入口或独立测试场景中通过 `setup()` 复用

---

## 5. 布局与占位视觉规范

### 5.1 基础分辨率

项目基础分辨率为 480×320，商店面板建议占用：

| 区域 | 建议尺寸 |
|------|----------|
| 全屏遮罩 | 480×320 |
| 主窗口 | 440×288 |
| 单个商品行 | 宽 240-260 × 高 28-32 |
| 行间距 | 2-4px |
| 详情区域宽度 | 150-170px |
| 正文字号 | 12-14px |
| 标题字号 | 16-18px |

### 5.2 商品行视觉状态

| 状态 | 占位表现 |
|------|----------|
| 普通商品 | 类型色块 + 名称 + 单价 + 右侧已拥有数量 |
| 当前选中 | 白色或浅绿色高亮边框 |
| 锁定（种子未解锁） | 整行灰显 + 锁图标/文字 + "Lv.N 解锁" |
| 买不起 | 价格标红，行可选但确认按钮禁用 |
| 背包空间不足 | 行可选，确认禁用并提示 |
| 出售行无库存 | 不出现在出售列表（库存为 0 即过滤） |

推荐类型占位颜色（沿用 PRD11 约定）：

| 类型 | 颜色 |
|------|------|
| `seed` | 浅绿色 |
| `harvest` | 橙黄色 |
| `consumable` | 紫色 |
| `decoration` | 棕黄色 |
| 未知类型 | 灰色 |

### 5.3 像素 UI 约束

- UI 坐标和尺寸尽量使用整数
- 不使用模糊缩放和线性过滤
- 图标区域预留 16×16 或 24×24 像素
- 当前阶段不要求引入外部字体；需确保中文可读
- 后续替换正式 Theme 时，不改变节点职责和脚本接口

---

## 6. ShopPanel

新增 `scripts/ui/shop/shop_panel.gd`。

### 6.1 职责

- 管理商店面板打开/关闭状态
- 管理购买/出售 Tab 切换
- 从 `EconomyManager` 读取购买与出售列表并构建商品行
- 管理选中商品与数量选择
- 计算并展示总价、余额、解锁状态
- 调用 `EconomyManager` 执行购买/出售并处理结果
- 监听交易、金币、等级解锁事件做局部刷新
- 控制 UI 打开期间的玩家和场景输入
- 向其他 UI 广播面板状态

### 6.2 核心属性

```gdscript
enum ShopTab {
	BUY,
	SELL,
}

const QUANTITY_PRESETS: Array[int] = [1, 5, 10]

@export var close_on_cancel: bool = true
@export var pause_world_time_when_open: bool = false

var is_open: bool = false
var current_tab: ShopTab = ShopTab.BUY
var selected_item_id: String = ""
var selected_quantity: int = 1
var row_views: Array[Control] = []
```

### 6.3 公共接口

```gdscript
## 绑定可选上下文（如店主节点）；其他场景允许传 null
func setup(context: Node = null) -> void

## 打开商店
func open_panel() -> void

## 关闭商店
func close_panel() -> void

## 切换打开/关闭
func toggle_panel() -> void

## 当前是否打开
func is_panel_open() -> bool

## 切换 Tab 并重建列表
func set_tab(tab: ShopTab) -> void

## 重建当前 Tab 的全部商品行
func rebuild_list() -> void

## 只刷新指定 item 的行（交易后）
func refresh_item_row(item_id: String) -> void

## 选择商品并刷新详情
func select_item(item_id: String) -> void

## 清空选择
func clear_selection() -> void

## 设置购买/出售数量（自动收敛到合法上限）
func set_quantity(quantity: int) -> void

## 将数量设为当前可交易最大值
func set_quantity_max() -> void

## 提交当前交易（按 current_tab 决定买/卖）
func confirm_transaction() -> Dictionary

## 刷新余额显示
func refresh_gold() -> void
```

### 6.4 初始化流程

```text
ShopPanel._ready()
  -> 收集 Header / TabBar / 列表容器 / 详情控件引用
  -> 连接 Tab 按钮、数量按钮、确认/关闭按钮
  -> 连接 EventBus.transaction_completed
  -> 连接 EventBus.transaction_failed
  -> 连接 EventBus.gold_changed
  -> 连接 EventBus.level_up / crop_unlocked / unlocks_changed
  -> 连接 EventBus.game_loaded
  -> set_tab(ShopTab.BUY)
  -> refresh_gold()
  -> close_panel()
```

要求：

- 切换 Tab 时清空当前选择并重建列表
- 解锁状态变化（升级）时重建购买列表
- 交易完成后局部刷新相关行、余额，并按需收敛数量
- 读档后全量重建列表与余额

---

## 7. ShopItemRow

新增 `scripts/ui/shop/shop_item_row.gd`。

### 7.1 职责

- 显示单个商品（购买）或可售物品（出售）的数据
- 显示价格、已拥有数量、锁定状态
- 响应点击选中
- 只发出选中信号与 item_id，不直接执行交易

### 7.2 核心属性

```gdscript
enum RowMode {
	BUY,
	SELL,
}

@export var mode: RowMode = RowMode.BUY

var item_id: String = ""
var crop_id: String = ""
var item_type: String = ""
var unit_price: int = 0
var owned_count: int = 0
var sellable_quantity: int = 0
var is_unlocked: bool = true
var unlock_level: int = 1
var is_selected: bool = false
```

### 7.3 行信号

```gdscript
signal row_clicked(item_id: String)
```

### 7.4 公共接口

```gdscript
## 用购买数据填充行：来自 EconomyManager.get_shop_items() 单项
func set_buy_data(data: Dictionary) -> void

## 用出售数据填充行：来自 EconomyManager.get_sellable_inventory_items() 单项
func set_sell_data(data: Dictionary) -> void

## 设置选中状态
func set_selected(value: bool) -> void

## 当前行是否可被选择（锁定行可显示但不可交易）
func is_selectable() -> bool
```

约束：

- 行不缓存价格表，价格随传入数据刷新
- 锁定行仍可点击查看详情，但详情区禁用数量与确认
- 出售行库存为 0 时不应被构建（由面板过滤）

---

## 8. 数据展示规则

### 8.1 购买列表数据来源

```gdscript
var items: Array = EconomyManager.get_shop_items()
# 每项：
# {
#   "item_id": "seed_carrot",
#   "crop_id": "carrot",
#   "name": "胡萝卜种子",
#   "type": "seed",
#   "price": 10,
#   "unlocked": true,
#   "unlock_level": 1,
#   "owned_count": 0,
#   "can_afford_one": true,
# }
```

### 8.2 出售列表数据来源

```gdscript
var items: Array = EconomyManager.get_sellable_inventory_items()
# 每项：
# {
#   "item_id": "harvest_carrot",
#   "name": "胡萝卜",
#   "quantity": 12,            # 背包内总数量
#   "unit_price": 25,
#   "total_price": 300,
#   "slot_indexes": [3, 7],
# }
```

### 8.3 商品行显示字段

| 字段 | 购买来源 | 出售来源 | 显示规则 |
|------|----------|----------|----------|
| 名称 | `name` | `name` | 行内短名，完整名在详情 |
| 单价 | `price` | `unit_price` | 买不起时标红 |
| 已拥有/库存 | `owned_count` | `quantity` | 购买显示"已有 N"，出售显示"库存 N" |
| 类型 | `type` | 固定 `harvest` | 决定占位颜色 |
| 锁定 | `unlocked` + `unlock_level` | 不适用 | 锁定时灰显并显示所需等级 |

### 8.4 详情面板字段

| 字段 | 展示内容 |
|------|----------|
| 物品名 | `name`，缺失回退 `item_id` |
| 类型 | 中文映射：种子/消耗品/装饰/收获物 |
| 单价 | 购买为买入价，出售为卖出价 |
| 已拥有/库存 | 购买显示已有数量，出售显示可售数量 |
| 解锁 | 购买锁定时显示"Lv.N 解锁"，出售不显示 |
| 描述 | 来自 `get_shop_item_info().description`（购买）或物品元数据 |
| 总价 | `单价 × 当前数量` |

详情数据可用 `EconomyManager.get_shop_item_info(item_id)` 补全描述与卖价。

---

## 9. Tab 与数量选择

### 9.1 Tab 行为

| Tab | 列表来源 | 确认动作 |
|-----|----------|----------|
| 购买 | `get_shop_items()` | `buy_item(item_id, qty)` |
| 出售 | `get_sellable_inventory_items()` | `sell_item(item_id, qty)` |

切换 Tab 时：

- 清空 `selected_item_id` 与详情
- 重置 `selected_quantity = 1`
- 重建列表
- 发射 `shop_tab_changed`

### 9.2 数量收敛规则

设置数量时必须收敛到合法范围，避免提交注定失败的交易：

**购买最大值**：

```text
max_by_gold  = floor(player_gold / unit_price)
max_by_space = InventoryManager.get_addable_count(item_id)
max_buy      = min(max_by_gold, max_by_space)
```

**出售最大值**：

```text
max_sell = 背包内该物品总数量 (sellable item.quantity)
```

规则：

- 预设按钮 1/5/10 超过最大值时，自动夹取为最大值
- "最大"按钮直接取上述 `max_buy` / `max_sell`
- 最大值为 0 时，数量显示 0，确认按钮禁用
- 锁定商品不可调整数量

### 9.3 确认可用性

确认按钮可用当且仅当：

- 已选中合法商品
- `selected_quantity > 0`
- 购买：`EconomyManager.can_buy_item(item_id, qty).success == true`
- 出售：`EconomyManager.can_sell_item(item_id, qty).success == true`

不可用时按钮禁用并在 `FooterHintLabel` 显示原因（金币不足/空间不足/未解锁/库存不足）。

---

## 10. 购买与出售流程

### 10.1 购买

```text
选中已解锁种子 seed_carrot
  -> 选择数量 5（自动收敛到 max_buy）
  -> 点击"购买"
  -> EconomyManager.buy_item("seed_carrot", 5)
  -> 成功：扣金币、入背包
     -> EventBus.item_purchased / transaction_completed / gold_changed
     -> 局部刷新行 owned_count、余额、可买性
     -> FooterHintLabel 显示"购买成功"
  -> 失败：transaction_failed + ui_notification，列表与余额不变
```

### 10.2 出售

```text
出售 Tab 选中 harvest_carrot（库存 12）
  -> 选择数量 10
  -> 点击"出售"
  -> EconomyManager.sell_item("harvest_carrot", 10)
  -> 成功：扣背包、加金币、给经验
     -> EventBus.item_sold / transaction_completed / gold_changed / xp_gained
     -> 刷新行库存（剩 2）、余额；库存为 0 时移除该行
     -> 收敛数量到新上限
  -> 失败：transaction_failed + ui_notification，列表与余额不变
```

### 10.3 交易结果处理

`EconomyManager` 的买/卖均返回结果字典：

```gdscript
{
	"success": true,
	"type": "buy",            # 或 "sell"
	"item_id": "seed_carrot",
	"crop_id": "carrot",
	"quantity": 5,
	"unit_price": 10,
	"total_price": 50,
	"gold_before": 100,
	"gold_after": 50,
	"message": "购买成功",
	"error_code": "",
}
```

UI 必须：

- 仅依据 `success` 与 `error_code` 决定反馈
- 不自行二次扣费/加钱
- 失败时不修改任何显示数据，等待数据层信号

---

## 11. 面板输入与游戏状态

### 11.1 打开/关闭来源

- 进入种子商店场景自动打开，或在商店内与店主"老陈"按 `E` 交互打开
- 当前阶段允许在 `farm.tscn` 临时入口（调试键或占位按钮）打开，便于验证
- 关闭通过 `CloseButton`、`cancel`（右键/Esc）触发

### 11.2 输入优先级

```text
商店关闭：
  场景输入正常

商店打开：
  Escape / 右键 -> 取消选择或关闭面板
  鼠标事件 -> 仅由商店 UI 消费
  WASD / E / 数字键调试 -> 不传给角色和场景
```

### 11.3 打开/关闭控制

打开时：

- `visible = true`
- 设置 UI 输入阻塞状态（沿用 `EventBus.ui_input_block_changed(true)`）
- 调用 PlayerController 的移动/交互禁用接口
- 默认不暂停 `TimeManager`
- 发射 `shop_panel_opened`

关闭时：

- `visible = false`
- 恢复玩家移动和交互
- 清理选择与数量
- 发射 `shop_panel_closed`
- 发射 `ui_input_block_changed(false)`

不建议使用 `get_tree().paused = true`，理由同 PRD11（避免影响时间、作物推进与自动存档）。

---

## 12. EventBus 扩展

在 `scripts/autoload/event_bus.gd` 增加：

```gdscript
# ─── 商店 UI ───
signal shop_panel_opened()
signal shop_panel_closed()
signal shop_tab_changed(tab: String)            # "buy" / "sell"
signal shop_item_selected(item_id: String, info: Dictionary)
signal shop_quantity_changed(item_id: String, quantity: int)
```

### 12.1 已有信号监听

| 信号 | UI 行为 |
|------|---------|
| `gold_changed(new_amount, delta)` | 刷新余额与全部行可买性 |
| `transaction_completed(result)` | 刷新相关行、余额、数量上限、显示成功提示 |
| `transaction_failed(result)` | 显示失败原因，不改数据 |
| `item_purchased(...)` / `item_sold(...)` | 可选高亮对应行 |
| `level_up(new_level)` | 重建购买列表（可能新解锁种子） |
| `crop_unlocked(crop_id, level)` | 刷新对应种子行解锁状态 |
| `unlocks_changed(unlocks)` | 重建购买列表 |
| `game_loaded(...)` | 全量重建列表与余额 |

### 12.2 信号发射规则

- 面板状态只有变化时才发射 opened/closed
- Tab 切换发射 `shop_tab_changed`
- 选中商品发射 `shop_item_selected`，info 为副本或空字典
- 数量变化发射 `shop_quantity_changed`

---

## 13. 错误提示与边界情况

| 场景 | 预期行为 |
|------|----------|
| 快速连续打开/关闭 | 最终状态确定，不重复连接信号、不重复构建列表 |
| 选中锁定种子 | 显示"Lv.N 解锁"，数量与确认禁用 |
| 金币不足 | 确认禁用，提示"金币不足"；不发起交易 |
| 背包空间不足 | 确认禁用，提示"背包空间不足" |
| 购买数量超上限 | 自动收敛到 max_buy，不报错 |
| 出售数量超库存 | 自动收敛到库存数量 |
| 出售物品库存归零 | 该行从列表移除，清空详情选择 |
| 升级新解锁种子 | 购买列表刷新，原锁定行解除灰显 |
| 商品元数据缺失 | 显示 item_id、未知类型与灰色，不崩溃 |
| 出售列表为空 | 显示"暂无可出售物品" |
| 购买列表为空 | 理论不会发生（始终有基础种子）；若空则显示占位文案 |
| 读档期间面板打开 | 读档完成后全量重建列表与余额 |
| 面板打开时点击场景/按 E | UI 消费事件，不触发场景交互 |
| 交易失败回滚 | 依赖数据层（已实现回滚），UI 不重复处理 |

---

## 14. 测试需求

### 14.1 自动化测试场景

创建：

```text
scenes/test/test_shop_panel.tscn
scenes/test/test_shop_panel.gd
```

测试场景应包含：

- 独立 `ShopPanel`
- 真实 `EconomyManager` / `LevelManager` / `InventoryManager` / `GameManager` autoload
- 结果 Label
- 可直接运行的测试入口

### 14.2 自动化测试用例

| 用例 | 预期 |
|------|------|
| 初始化 | 默认 BUY Tab，余额与 GameManager.gold 一致 |
| 打开/关闭 | visible 与 is_open 一致，状态信号各发射一次 |
| 构建购买列表 | 行数量与 `get_shop_items()` 一致 |
| 构建出售列表 | 行数量与 `get_sellable_inventory_items()` 一致 |
| Tab 切换 | 列表来源切换、选择清空、数量重置 |
| 锁定种子显示 | 未解锁种子灰显并显示 unlock_level |
| 选中商品 | 详情字段与数据一致，发射 shop_item_selected |
| 数量预设 | 1/5/10 正确设置，超上限自动收敛 |
| 数量最大值（购买） | 取 min(金币上限, 空间上限) |
| 数量最大值（出售） | 取背包持有数量 |
| 购买成功 | 金币减少、背包增加、行与余额刷新 |
| 购买金币不足 | 确认禁用或返回失败，数据不变 |
| 购买空间不足 | 确认禁用或返回失败，数据不变 |
| 购买锁定种子 | 被拒绝（error_code = LOCKED），数据不变 |
| 出售成功 | 背包减少、金币增加、给经验、行刷新 |
| 出售清空库存 | 行被移除，详情清空 |
| 出售数量不足 | 返回失败，数据不变 |
| 余额信号刷新 | gold_changed 后余额与可买性更新 |
| 升级解锁刷新 | level_up / crop_unlocked 后列表重建 |
| 读档刷新 | game_loaded 后列表与余额全量同步 |
| 缺失元数据 | 回退显示，不崩溃 |

### 14.3 半自动化手测清单

在商店场景（或临时入口）中验证：

1. 打开商店，默认显示「购买」Tab 与种子列表
2. 余额正确显示当前金币
3. 未解锁种子灰显并标注所需等级，无法选数量
4. 选中胡萝卜种子，右侧显示名称、单价、已有数量、描述
5. 切换数量 1/5/10，总价随之变化
6. 点"最大"，数量收敛到金币/空间允许的上限
7. 金币不足或背包将满时，确认按钮禁用并提示
8. 购买成功后金币减少、已有数量增加
9. 切到「出售」Tab，显示背包内收获物及库存
10. 选中并出售部分收获物，金币增加、库存减少
11. 出售到库存为 0 后，该行从列表消失
12. 升级解锁新种子后，购买列表对应行解除锁定
13. 按 `Escape` 或关闭按钮关闭面板并恢复角色控制
14. 保存、读档后商店列表与余额一致

---

## 15. 验收标准

### 15.1 功能验收

- [ ] 可稳定打开/关闭商店面板
- [ ] 购买/出售双 Tab 正确切换
- [ ] 购买列表展示种子、消耗品、装饰，数据来自 EconomyManager
- [ ] 出售列表展示背包可售收获物并正确聚合
- [ ] 余额实时显示并随交易刷新
- [ ] 锁定种子灰显并显示所需等级，不可购买
- [ ] 数量选择 1/5/10/最大正确，且自动收敛合法上限
- [ ] 总价随单价与数量正确计算
- [ ] 购买扣金币、入背包；出售扣背包、加金币
- [ ] 金币不足、空间不足、库存不足、未解锁均有明确反馈
- [ ] 交易后相关行、余额、数量上限正确刷新
- [ ] 升级解锁新种子后购买列表正确更新

### 15.2 输入与体验验收

- [ ] 面板打开时不会误触角色移动、场景点击或 E 键交互
- [ ] 鼠标事件不会穿透遮罩
- [ ] 关闭面板后角色和场景交互恢复
- [ ] 锁定/买不起/库存不足等状态有清晰提示
- [ ] 480×320 基础分辨率下文字可读、窗口不超出屏幕
- [ ] 无正式美术资源也能清晰识别商品类型与状态

### 15.3 工程验收

- [ ] UI 不直接增减 `GameManager.gold` 或修改背包槽位
- [ ] 买/卖统一调用 `EconomyManager` 接口
- [ ] 价格、解锁判定均来自数据层查询
- [ ] 事件连接不会因重复打开面板而重复注册
- [ ] 读档后商店 UI 可正确全量刷新
- [ ] 新增测试场景可独立运行
- [ ] 不破坏 PRD1-11 已有测试
- [ ] 控制台无持续报错和无效节点引用

---

## 16. 实施建议

建议按以下顺序开发：

1. 创建 `ShopItemRow` 场景，完成购买/出售两种 mode 的数据渲染
2. 创建 `ShopPanel`，构建购买列表并连接 `EconomyManager`
3. 实现 Tab 切换与出售列表构建
4. 实现选中详情、数量选择与总价计算
5. 实现购买/出售确认与 `can_buy_item`/`can_sell_item` 预校验
6. 接入交易结果与 `EventBus` 信号局部刷新
7. 接入 `level_up`/`crop_unlocked` 解锁刷新
8. 实现 UI 输入阻塞、打开/关闭与读档刷新
9. 补齐自动化测试与商店场景手测

---

## 17. 风险与注意事项

| 风险 | 说明 | 应对 |
|------|------|------|
| UI 与数据双写 | UI 自行扣钱/加物会与数据层不同步 | 所有交易先调 EconomyManager，再由信号刷新 |
| 数量越界提交 | 提交超额交易导致频繁失败 | 选择/调数量时即收敛到 can_buy/can_sell 上限 |
| 解锁状态过期 | 升级后列表未刷新仍显示锁定 | 监听 level_up/crop_unlocked/unlocks_changed 重建 |
| 出售空行残留 | 库存归零仍显示 | 交易后过滤库存为 0 的物品并清详情 |
| 价格双源不一致 | UI 缓存价格与数据层不符 | 每次刷新用 get_buy_price/get_sell_price |
| 余额未同步 | 其他系统改金币后商店未更新 | 监听 gold_changed 刷新余额与可买性 |
| 输入穿透 | 点击商品同时触发场景交互 | 全屏遮罩设为 Stop，并广播 UI 输入阻塞 |
| 重复信号注册 | 反复打开面板重复 connect | 连接前判断 is_connected 或仅在 _ready 连接 |
| 缺少正式图标 | items.json 当前无 icon_path | 使用类型色块和短文本占位，保留接口 |

---

## 18. 技术约束

1. **Godot 版本**
   - 兼容项目当前 Godot 4.6 配置
   - 列表使用 `ScrollContainer` + `VBoxContainer` 动态填充

2. **数据边界**
   - UI 只使用 `EconomyManager` 公开查询/交易接口
   - 不直接访问 `GameManager.gold` 写入或 `InventoryManager._slots`
   - 不在 UI 复制价格表与解锁规则

3. **事件驱动**
   - 余额、解锁、交易结果通过信号刷新
   - 不在 `_process()` 中轮询列表

4. **可复用性**
   - `ShopItemRow` 不依赖具体场景
   - `ShopPanel.setup(null)` 时仍可在测试场景运行
   - 可复用 PRD11 的 UI 输入阻塞约定

5. **输入**
   - 商店打开时消费对应输入
   - 不由 EconomyManager 监听键盘

6. **视觉**
   - 当前阶段使用内置节点和 ThemeOverride 即可
   - 不要求下载或生成正式美术资源
   - 后续替换素材不得改变核心节点接口

---

## 19. 与后续 PRD 的衔接

- **PRD13 HUD**：金币常驻显示与商店余额读取同一 `GameManager.gold`，监听同一 `gold_changed`
- **PRD14 设置/存档 UI**：可建立统一 `UIManager` 管理背包、商店、菜单的互斥与焦点
- **PRD15 角色动画 / PRD17 场景美术**：店主"老陈"立绘动画与种子商店正式场景接入，不改变商店面板接口
- **PRD19 音频**：监听面板打开、关闭、购买、出售、按钮事件播放 UI 音效（`sfx_ui_open` / `sfx_coin` / `sfx_ui_click`）
- **PRD25 装饰系统**：购买装饰物后进入布置模式

---

## 附录 A: 商店交互流程

### A.1 打开商店

```text
进入商店 / 与店主交互
  -> ShopPanel.open_panel()
  -> 阻塞玩法输入
  -> set_tab(BUY) + rebuild_list()
  -> refresh_gold()
  -> 显示面板
  -> EventBus.shop_panel_opened
```

### A.2 购买种子

```text
选中 seed_carrot
  -> select_item("seed_carrot")
  -> set_quantity(5)（收敛到 max_buy）
  -> 点击购买
  -> EconomyManager.buy_item("seed_carrot", 5)
  -> transaction_completed + gold_changed
  -> refresh_item_row + refresh_gold
```

### A.3 出售收获物

```text
切到 SELL Tab
  -> 选中 harvest_carrot（库存 12）
  -> set_quantity(10)
  -> 点击出售
  -> EconomyManager.sell_item("harvest_carrot", 10)
  -> transaction_completed + gold_changed + xp_gained
  -> 行库存刷新为 2，余额刷新
```

---

## 附录 B: 与 PRD4 数据层接口对应

| PRD12 UI 行为 | PRD4 接口 |
|---------------|-----------|
| 构建购买列表 | `get_shop_items()` / `get_seed_shop_items()` |
| 构建出售列表 | `get_sellable_inventory_items()` |
| 商品详情 | `get_shop_item_info(item_id)` |
| 买入价 | `get_buy_price(item_id)` |
| 卖出价 | `get_sell_price(item_id)` |
| 购买预校验 | `can_buy_item(item_id, qty)` |
| 出售预校验 | `can_sell_item(item_id, qty)` |
| 执行购买 | `buy_item(item_id, qty)` / `buy_seed(crop_id, qty)` |
| 执行出售 | `sell_item(item_id, qty)` / `sell_harvest(crop_id, qty)` |
| 余额 | `GameManager.gold`（只读） |
| 可加入数量 | `InventoryManager.get_addable_count(item_id)` |

---

## 附录 C: 与 PRD5 解锁接口对应

| PRD12 UI 行为 | PRD5 接口 |
|---------------|-----------|
| 种子是否解锁 | `LevelManager.is_crop_unlocked(crop_id)` |
| 种子解锁等级 | `LevelManager.get_crop_unlock_level(crop_id)` |
| 升级解锁刷新 | 监听 `EventBus.level_up` / `crop_unlocked` / `unlocks_changed` |
