# PRD10: 种植 / 浇水 / 收获交互流程

> **优先级**: P0 — 色块版可玩原型的核心闭环  
> **美术依赖**: 🟡 最小占位视觉（地块色块 / Label / 简单阶段标记，无正式作物 Sprite）  
> **预计工期**: 5-7 天  
> **前置依赖**: PRD1-9（核心数据、作物状态机、背包、经济、等级、存档、时间、田园网格、角色交互）  
> **产出**: 可在田园场景中完成选择种子、种植、浇水、等待生长、再次浇水、收获、清除枯萎作物的完整玩法闭环 + 调试快捷操作 + 自动化测试场景  
> **最后更新**: 2026-06-02

---

## 1. 目标

实现《像素田园》第一版可玩闭环，将 PRD2-9 已完成的数据系统与占位场景串联起来，包含：

- 在田园场景内选择当前操作工具 / 种子
- 对已解锁空地种植作物
- 对需要浇水的作物浇水，使作物进入生长计时
- 作物阶段推进后再次等待浇水，直到成熟
- 成熟后收获，收获物进入背包，地块恢复可种植
- 枯萎作物可清除，地块恢复可种植
- 同时支持角色面前按 `E` 交互和鼠标左键点击地块交互
- 使用色块、短文本或简单几何标记表达作物阶段与交互结果
- 提供调试面板 / 快捷键以便快速验证完整流程
- 新增自动化 / 半自动化测试覆盖核心闭环

完成后，玩家应能在 `scenes/farm/farm.tscn` 中用占位画面跑通核心循环：

```text
选择种子 -> 种植 -> 选择水壶 -> 浇水 -> 等待阶段推进
-> 再次浇水 -> 成熟 -> 收获入背包 -> 地块恢复空闲
```

PRD10 是第二层最小占位视觉的最终里程碑：不追求正式 UI 和美术表现，但必须证明核心玩法逻辑已经可玩、可测、可存档衔接。

---

## 2. 核心设计决策

| 决策 | 内容 | 来源 |
|------|------|------|
| 编排层 | 新增 `FarmInteractionController` 作为交互编排层 | 避免 `farm.gd` 直接耦合 Crop / Grid / Inventory |
| 输入来源 | 鼠标点击地块 + PlayerController 发出的 `farm_tile_interaction_requested` | GDD 2.1、PRD9 |
| 当前选择 | 暂用轻量运行时选择：种子 ID / 水壶 / 清除模式；后续接 PRD11 / PRD13 快捷栏 UI | PRD10 范围边界 |
| 种植真实逻辑 | 调用 `CropManager.plant_crop(tile_pos, crop_id)`，由 CropManager 扣除种子 | PRD2 / PRD3 |
| 浇水真实逻辑 | 调用 `CropManager.water_crop(tile_pos)` 后同步 `FarmGridManager.mark_tile_watered(tile_pos)` | PRD2 / PRD8 |
| 收获真实逻辑 | 调用 `CropManager.harvest_crop(tile_pos)`，由 CropManager 加入收获物与经验 | PRD2 / PRD3 / PRD5 |
| 地块占用同步 | 种植成功后调用 `FarmGridManager.set_tile_occupied(...)`；收获 / 清除后调用 `FarmGridManager.clear_tile(...)` | PRD8 |
| 作物阶段视觉 | 用地块色块叠加 Label / 小圆点 / 字母表示阶段，后续 PRD16 替换 Sprite | PRD 大纲 |
| 错误反馈 | 通过 `EventBus.ui_notification(message, type)` 与调试 Label 展示 | PRD1 / PRD13 衔接 |
| 业务边界 | 不实现背包 UI、商店 UI、正式 HUD、正式动画和音效 | PRD11-19 |

---

## 3. 系统范围

### 3.1 本 PRD 覆盖内容

- 新增交互编排脚本 `scripts/farm/farm_interaction_controller.gd`
- 在 `farm.tscn` 挂载交互控制器
- 连接 `EventBus.farm_tile_interaction_requested`
- 支持鼠标左键直接请求地块交互
- 支持当前种子 / 当前工具选择
- 支持种植、浇水、收获、清除枯萎作物
- 同步 CropManager 与 FarmGridManager 的地块状态
- 展示作物阶段、浇水状态、生长进度与交互结果
- 提供调试快捷键或按钮切换：胡萝卜种子、水壶、清除模式
- 提供调试加速成熟 / 推进时间能力，仅测试场景或 Debug 模式启用
- 新增测试场景 `test_farm_interaction_controller`

### 3.2 本 PRD 不覆盖内容

- 背包 UI 面板、拖拽、格子展示 -> PRD11
- 商店 UI、购买确认、等级锁定提示 -> PRD12
- 正式 HUD、快捷栏视觉、时间金币常驻显示 -> PRD13
- 正式作物 Sprite 与生长阶段动画 -> PRD16
- 种植 / 浇水 / 收获角色动画 -> PRD15
- 种植、浇水、收获音效与粒子 -> PRD18 / PRD19
- 作物售卖流程与商店交互 -> PRD12
- 好友田园偷菜 -> PRD22
- 移动端触屏专项适配 -> 后续移动端 PRD

---

## 4. 场景与文件设计

### 4.1 需要新增 / 修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `scripts/farm/farm_interaction_controller.gd` | 新增 | 种植 / 浇水 / 收获交互编排核心 |
| `scenes/farm/farm.tscn` | 修改 | 挂载 FarmInteractionController，增加作物占位视觉层 |
| `scenes/farm/farm.gd` | 修改 | 接入交互控制器，移除或关闭 PRD8 调试点击循环状态 |
| `scripts/farm/farm_grid_manager.gd` | 小幅修改 | 如有必要，补充占用 / 清理 / 浇水同步接口 |
| `scripts/autoload/event_bus.gd` | 修改 | 增加交互结果与工具选择相关信号 |
| `scenes/test/test_farm_interaction_controller.tscn` | 新增 | PRD10 自动化测试场景 |
| `scenes/test/test_farm_interaction_controller.gd` | 新增 | 闭环测试脚本 |

### 4.2 推荐场景节点结构

在 PRD8 / PRD9 的 `farm.tscn` 基础上扩展：

```text
Farm (Node2D)
├── BackgroundLayer
├── GridRoot
│   ├── GridCanvas
│   └── CropOverlay (Node2D)                 # 新增：作物阶段占位绘制
├── EntityLayer
│   └── Player
├── Controllers
│   └── FarmInteractionController (Node)     # 新增：交互编排层
├── DebugLayer (CanvasLayer)
│   ├── CoordinateLabel
│   ├── TileStateLabel
│   ├── PlayerDebugLabel
│   └── InteractionDebugLabel                # 新增：当前工具 / 结果提示
└── FarmGridManager
```

如果不新增 `Controllers` 容器，也允许将 `FarmInteractionController` 直接挂在 `Farm` 下；验收重点是职责清晰，不把完整业务闭环堆在 `farm.gd`。

---

## 5. 交互模型

### 5.1 操作模式

```gdscript
enum InteractionMode {
	NONE,
	PLANT,
	WATER,
	HARVEST,
	CLEAR,
}
```

| 模式 | 触发方式 | 目标地块 | 成功动作 |
|------|----------|----------|----------|
| `PLANT` | 当前选择种子 | 已解锁、可种植、无作物 | 调用 CropManager 种植并扣种子 |
| `WATER` | 当前选择水壶 | 有作物、未浇水、未成熟、未枯萎 | 调用 CropManager 浇水并刷新湿土表现 |
| `HARVEST` | 自动判断或当前无工具时点击成熟作物 | 成熟作物 | 收获入背包并清空地块 |
| `CLEAR` | 当前选择清除模式 | 枯萎作物或调试占用地块 | 清除作物并恢复空地 |
| `NONE` | 未选择工具 / 种子 | 任意 | 只显示提示，不改变状态 |

### 5.2 自动交互优先级

当 `auto_resolve_action = true` 时，点击地块或按 `E` 不强制依赖模式，而是按以下顺序自动判断：

1. 地块存在成熟作物 -> 收获
2. 地块存在枯萎作物 -> 清除
3. 当前选择的是水壶，且作物需要浇水 -> 浇水
4. 当前选择的是种子，且地块可种植 -> 种植
5. 其他情况 -> 失败提示

默认建议：

- 调试原型中启用 `auto_resolve_action`
- 当后续 PRD13 正式快捷栏完成后，可改为更严格的工具模式

### 5.3 当前选择来源

PRD10 暂不要求正式 UI，但必须提供可测试的选择入口：

```gdscript
var current_mode: InteractionMode = InteractionMode.NONE
var selected_seed_item_id: String = "seed_carrot"
var selected_crop_id: String = "carrot"
var selected_tool_id: String = ""
var auto_resolve_action: bool = true
```

临时调试输入建议：

| 输入 | 行为 |
|------|------|
| `1` | 选择胡萝卜种子：`seed_carrot` / `carrot` |
| `2` | 选择白菜种子：`seed_cabbage` / `cabbage` |
| `3` | 选择玉米种子：`seed_corn` / `corn` |
| `4` | 选择水壶：`watering_can` |
| `5` | 选择清除模式 |
| `0` | 清空当前选择 |
| `E` | 对玩家面前地块执行交互 |
| 鼠标左键 | 对点击地块执行交互 |

> 如果数字键已经被 `InventoryManager.select_hotbar()` 使用，PRD10 应优先复用快捷栏选中物品：选中物品类型为 `seed` 时进入 `PLANT`，为 `tool` 且 `item_id == "watering_can"` 时进入 `WATER`。调试直选只作为无 UI 阶段的兜底。

---

## 6. FarmInteractionController

新增 `scripts/farm/farm_interaction_controller.gd`。

### 6.1 职责

- 持有当前交互模式和当前选择物
- 接收鼠标点击 / 玩家面前交互请求
- 判断地块、作物、背包、等级、季节等前置条件
- 调用 CropManager / InventoryManager / FarmGridManager 完成真实操作
- 同步地块占用、湿土、清理状态
- 监听作物阶段事件并刷新占位视觉
- 对失败原因做统一提示
- 提供测试用接口

### 6.2 核心属性

```gdscript
@export var auto_resolve_action: bool = true
@export var debug_mode: bool = true
@export var default_seed_crop_id: String = "carrot"

var current_mode: InteractionMode = InteractionMode.NONE
var selected_crop_id: String = ""
var selected_item_id: String = ""
var last_result: Dictionary = {}
var farm_grid_manager: Node = null
var crop_overlay: Node2D = null
```

### 6.3 初始化接口

```gdscript
func setup(grid_manager: Node, overlay: Node2D = null) -> void
func reset_controller() -> void
func connect_events() -> void
func disconnect_events() -> void
```

### 6.4 选择接口

```gdscript
func select_seed(crop_id: String) -> bool
func select_tool(tool_id: String) -> bool
func select_clear_mode() -> void
func clear_selection() -> void
func sync_selection_from_hotbar() -> void
func get_current_selection() -> Dictionary
```

选择规则：

- `select_seed(crop_id)` 必须验证 `DataManager.get_crop(crop_id)` 存在
- 若存在 `LevelManager`，必须检查 `LevelManager.is_crop_unlocked(crop_id)`
- 种子物品 ID 固定为 `"seed_" + crop_id`
- `select_tool("watering_can")` 必须验证 `DataManager.get_item("watering_can")` 存在
- 选择变化必须发出事件，便于 PRD13 HUD 接入

### 6.5 交互入口

```gdscript
func request_tile_interaction(tile_pos: Vector2i, source: String = "unknown") -> Dictionary
func request_mouse_tile_interaction(mouse_world_pos: Vector2) -> Dictionary
func can_interact_with_tile(tile_pos: Vector2i) -> bool
```

返回结果结构：

```gdscript
{
	"success": true,
	"action": "plant",
	"tile_pos": Vector2i(5, 5),
	"crop_id": "carrot",
	"item_id": "seed_carrot",
	"reason": "",
	"message": "种下了胡萝卜",
}
```

失败示例：

```gdscript
{
	"success": false,
	"action": "water",
	"tile_pos": Vector2i(5, 5),
	"crop_id": "",
	"item_id": "watering_can",
	"reason": "crop_does_not_need_water",
	"message": "这块地暂时不需要浇水",
}
```

### 6.6 业务操作接口

```gdscript
func try_plant(tile_pos: Vector2i, crop_id: String) -> Dictionary
func try_water(tile_pos: Vector2i) -> Dictionary
func try_harvest(tile_pos: Vector2i) -> Dictionary
func try_clear(tile_pos: Vector2i) -> Dictionary
func resolve_action(tile_pos: Vector2i) -> Dictionary
```

---

## 7. 业务规则

### 7.1 种植规则

种植前置条件：

1. 地块在地图范围内
2. 地块为已解锁 `farm_plot`
3. `FarmGridManager.can_plant_on_tile(tile_pos)` 返回 true
4. `CropManager.has_crop(tile_pos)` 返回 false
5. `DataManager.get_crop(crop_id)` 存在
6. 当前等级已解锁该作物
7. 背包中存在 `seed_<crop_id>` 至少 1 个

成功后：

```gdscript
var ok := CropManager.plant_crop(tile_pos, crop_id)
if ok:
	FarmGridManager.set_tile_occupied(tile_pos, true, FarmGridManager.tile_pos_to_key(tile_pos))
```

结果：

- 背包种子数量减少 1
- CropManager 创建作物数据，阶段为 `SEED`
- 地块状态变为 `occupied`
- 发出 `crop_planted`、`farm_tile_occupied_changed`、`farm_interaction_completed`
- 占位视觉显示种子阶段

### 7.2 浇水规则

浇水前置条件：

1. 地块存在作物
2. 作物阶段不是 `MATURE` / `WITHERED`
3. `CropManager.needs_water(tile_pos)` 返回 true
4. 当前选择水壶，或自动交互判断为浇水

成功后：

```gdscript
var ok := CropManager.water_crop(tile_pos)
if ok:
	FarmGridManager.mark_tile_watered(tile_pos)
```

结果：

- 作物 `watered = true`
- `water_count += 1`
- 生长计时开始
- 占位视觉增加湿润效果或蓝色小标记
- 发出 `crop_watered`、`farm_interaction_completed`

### 7.3 生长推进规则

PRD10 不重写生长状态机，沿用 `CropManager`：

- 作物只有在 `watered = true` 时推进阶段
- 每阶段生长时间来自 `DataManager.get_crop(crop_id)["growth_time_per_stage"]`
- 阶段推进后 `watered` 重置为 false，需要再次浇水
- 阶段序列：`SEED -> SPROUT -> GROWING -> MATURE -> WITHERED`
- 成熟后隔天未收获由 PRD7 / PRD2 的零点检查触发枯萎

PRD10 需要监听：

```gdscript
EventBus.crop_grown
EventBus.crop_matured
EventBus.crop_withered
```

并刷新作物占位视觉。

### 7.4 收获规则

收获前置条件：

1. 地块存在作物
2. `CropManager.is_harvestable(tile_pos)` 返回 true
3. 背包可加入 `harvest_<crop_id>` 至少 1 个

成功后：

```gdscript
var crop_id := CropManager.harvest_crop(tile_pos)
if crop_id != "":
	FarmGridManager.clear_tile(tile_pos)
```

结果：

- 背包增加 `harvest_<crop_id>` 1 个
- 作物从 CropManager 移除
- 地块恢复 `empty`
- 获得收获经验
- 发出 `crop_harvested`、`farm_interaction_completed`

若背包满导致 `CropManager.harvest_crop()` 返回空字符串，地块不得清空。

### 7.5 清除枯萎作物规则

清除前置条件：

1. 地块存在作物
2. 作物阶段为 `WITHERED`
3. 当前为清除模式，或自动交互判断为枯萎清除

成功后：

```gdscript
var ok := CropManager.clear_crop(tile_pos)
if ok:
	FarmGridManager.clear_tile(tile_pos)
```

结果：

- 作物从 CropManager 移除
- 不获得收获物
- 地块恢复 `empty`
- 发出 `crop_cleared`、`farm_interaction_completed`

---

## 8. 占位视觉

### 8.1 地块颜色

沿用 PRD8 基础颜色，并按作物状态叠加：

| 状态 | 表现 |
|------|------|
| 空地 | 棕色空地 |
| 已种植未浇水 | 棕色地块 + 小字 `S` / 小黄点 |
| 已浇水 | 深棕 / 蓝色边框 + 小字 `W` |
| 发芽 | 小绿点或 `1` |
| 生长中 | 两个绿点或 `2` |
| 成熟 | 黄色边框 / `M` |
| 枯萎 | 灰色覆盖 / `X` |

### 8.2 CropOverlay 绘制

推荐使用 `Node2D._draw()` 在 `CropOverlay` 中按地块绘制：

```gdscript
for tile_pos in CropManager.get_all_crops():
	var crop_data := CropManager.get_crop_data(tile_pos)
	var center := FarmGridManager.grid_to_world_center(tile_pos)
	draw_circle(center, 4.0, _get_stage_color(crop_data))
```

若需要显示字母，可使用 `Label` 池或 `draw_string()`；PRD10 不要求像素字体。

### 8.3 调试信息

`InteractionDebugLabel` 至少显示：

```text
Mode: PLANT
Selected: seed_carrot
Last: planted carrot at (5, 5)
Tile Crop: carrot stage=SEED watered=false progress=0.00
```

---

## 9. EventBus 扩展

在 `scripts/autoload/event_bus.gd` 中新增：

```gdscript
# ─── 农田交互闭环 ───
signal farm_interaction_mode_changed(mode: String, selected_item_id: String, selected_crop_id: String)
signal farm_interaction_completed(result: Dictionary)
signal farm_interaction_failed(result: Dictionary)
signal farm_tile_action_preview_changed(tile_pos: Vector2i, action: String, reason: String)
```

触发要求：

- 每次选择种子 / 工具 / 清除模式时发出 `farm_interaction_mode_changed`
- 每次种植 / 浇水 / 收获 / 清除成功时发出 `farm_interaction_completed`
- 每次请求失败时发出 `farm_interaction_failed`
- 鼠标悬停或玩家面前目标变化时，可选发出 `farm_tile_action_preview_changed`

---

## 10. 存档衔接

PRD10 不新增新的持久化数据结构，但必须保持以下状态可由既有系统保存：

| 数据 | 来源 | 要求 |
|------|------|------|
| 作物数据 | `CropManager.export_save_data()` | 种植、浇水、生长阶段、成熟时间可保存 |
| 地块数据 | `FarmGridManager.export_save_data()` | 地块占用、解锁、状态可保存 |
| 背包数据 | `InventoryManager.export_save_data()` | 种子扣除、收获物增加可保存 |
| 玩家进度 | `GameManager` / `LevelManager` | 经验和统计可保存 |

实现要求：

- PRD10 操作完成后必须让上述管理器内部状态保持一致
- 读取存档后，如果 CropManager 某地块有作物，FarmGridManager 对应地块应恢复为 `occupied`
- 如果 CropManager 没有作物但 FarmGridManager 标记 occupied，加载或初始化时应清理为 `empty`
- 可新增 `FarmInteractionController.reconcile_grid_with_crops()` 做一致性修复

---

## 11. 错误码与提示

| reason | 场景 | 提示 |
|--------|------|------|
| `tile_out_of_bounds` | 坐标越界 | 不在可操作范围内 |
| `tile_locked` | 地块未解锁 | 这块地还没有解锁 |
| `tile_not_plantable` | 地块不可种植 | 这里不能种植 |
| `crop_exists` | 已有作物 | 这块地已经有作物 |
| `crop_missing` | 没有作物 | 这里还没有作物 |
| `crop_locked` | 作物等级未解锁 | 这种作物还没有解锁 |
| `seed_missing` | 没有种子 | 背包里没有这种种子 |
| `tool_missing` | 没有工具 | 需要先选择水壶 |
| `crop_does_not_need_water` | 已浇水或已成熟 | 这株作物暂时不需要浇水 |
| `crop_not_mature` | 未成熟收获 | 作物还没有成熟 |
| `inventory_full` | 背包无法加入收获物 | 背包已满 |
| `crop_not_withered` | 清除非枯萎作物 | 只能清除枯萎作物 |
| `no_action_available` | 自动判断无动作 | 这里暂时没有可执行操作 |

---

## 12. 测试要求

### 12.1 自动化测试场景

新增：

```text
scenes/test/test_farm_interaction_controller.tscn
scenes/test/test_farm_interaction_controller.gd
```

测试脚本需在 `_ready()` 中准备：

- `GameManager.start_new_game(...)`
- `FarmGridManager.initialize_grid()`
- 背包加入基础种子：`seed_carrot`、`seed_cabbage`
- 绑定 `FarmInteractionController.setup(farm_grid_manager, crop_overlay)`

### 12.2 必测用例

| 用例 | 预期 |
|------|------|
| 空地种植成功 | 返回 success，CropManager 有作物，Grid occupied，种子 -1 |
| 无种子种植失败 | 返回 `seed_missing`，地块不变 |
| 未解锁地块种植失败 | 返回 `tile_locked` 或 `tile_not_plantable` |
| 已占用地块重复种植失败 | 返回 `crop_exists` |
| 作物浇水成功 | `watered = true`，`water_count +1` |
| 重复浇水失败 | 返回 `crop_does_not_need_water` |
| 未成熟收获失败 | 返回 `crop_not_mature` |
| 成熟收获成功 | 背包增加收获物，CropManager 移除作物，Grid empty |
| 背包满时收获失败 | 作物和地块保持不变 |
| 枯萎作物清除成功 | CropManager 移除作物，Grid empty，无收获物 |
| 自动交互优先级 | 成熟优先收获，枯萎优先清除，需要水时浇水 |
| 存档一致性修复 | Crop / Grid 不一致时可修复 |

### 12.3 半自动化手测清单

在 `farm.tscn` 中验证：

1. 启动进入田园场景，可看到玩家和可耕地
2. 按 `1` 选择胡萝卜种子
3. 面向空地按 `E`，地块出现种子占位
4. 按 `4` 选择水壶，再按 `E` 浇水
5. 调试推进时间后，作物阶段变化且需要再次浇水
6. 重复浇水直到成熟
7. 点击成熟作物或按 `E` 收获，背包出现 `harvest_carrot`
8. 强制枯萎后，按清除模式可恢复空地
9. 错误操作会显示明确提示，不会破坏数据

---

## 13. 验收标准

### 13.1 功能验收

- [ ] 可在 `farm.tscn` 中完成种植 -> 浇水 -> 生长 -> 再浇水 -> 成熟 -> 收获闭环
- [ ] 种植成功会扣除对应种子
- [ ] 种植成功后地块被标记为 occupied
- [ ] 浇水成功后作物进入计时，重复浇水失败
- [ ] 作物成熟后可收获，收获物进入背包
- [ ] 收获后地块恢复可种植
- [ ] 枯萎作物可清除且无收获物
- [ ] 鼠标点击地块与角色面前按 `E` 都能触发同一套业务逻辑
- [ ] 错误操作不会修改作物、地块、背包数据
- [ ] 调试视觉能区分不同作物阶段

### 13.2 工程验收

- [ ] `farm.gd` 不直接承担全部业务闭环，核心逻辑在 `FarmInteractionController`
- [ ] CropManager、InventoryManager、FarmGridManager 的状态在每次操作后保持一致
- [ ] EventBus 新增信号命名清晰，参数可供 UI 后续复用
- [ ] 无正式美术资源依赖
- [ ] 新增测试场景可运行并输出通过 / 失败结果
- [ ] 不破坏 PRD1-9 已有测试

### 13.3 体验验收

- [ ] 玩家无需打开正式 UI，也能通过调试选择跑通闭环
- [ ] 当前选择、目标地块和最后一次操作结果可见
- [ ] 失败提示能说明原因
- [ ] 占位视觉足以判断地块是否已种植、已浇水、成熟或枯萎

---

## 14. 实施建议

建议按以下顺序开发：

1. 新增 `FarmInteractionController`，先实现 `try_plant()`、`try_water()`、`try_harvest()`、`try_clear()`
2. 在测试场景中直接调用接口，确保数据闭环正确
3. 接入 `farm_tile_interaction_requested`，让玩家按 `E` 可触发
4. 接入鼠标点击地块，替换 PRD8 的点击循环状态调试逻辑
5. 增加 `CropOverlay` 占位绘制和 `InteractionDebugLabel`
6. 增加自动交互优先级与错误提示
7. 做存档一致性修复和回归测试

---

## 15. 风险与注意事项

| 风险 | 说明 | 应对 |
|------|------|------|
| CropManager 与 FarmGridManager 状态不一致 | 作物已收获但地块仍 occupied，或反之 | 每次成功操作后同步；加载后 reconcile |
| 背包满导致收获失败 | 若先清地再加物品会丢失作物 | 必须以 CropManager.harvest_crop 返回 crop_id 为准 |
| PRD8 调试点击逻辑冲突 | 现有点击会循环切换地块状态 | PRD10 接入后关闭该调试逻辑或只在 debug flag 下启用 |
| 快捷栏与调试数字键冲突 | PRD3 已有 hotbar 选择 | 优先复用 hotbar，调试直选作为临时兜底 |
| 生长时间等待太久 | 手测闭环效率低 | Debug 模式提供推进时间 / 强制成熟能力 |
| 后续 UI 接入重复造逻辑 | PRD11 / PRD13 可能需要同样判断 | 把判断集中在 FarmInteractionController 公共接口 |

---

## 16. 与后续 PRD 的衔接

- **PRD11 背包 UI**：读取 `InventoryManager` 与 `FarmInteractionController.select_seed()`，实现可视化选种
- **PRD12 商店 UI**：购买种子后，本 PRD 的种植逻辑自动可用
- **PRD13 HUD**：订阅交互模式与交互结果事件，显示快捷栏、提示和作物状态
- **PRD15 角色动画**：在 `farm_interaction_completed` 后播放 plant / water / harvest 动画
- **PRD16 作物视觉**：替换 `CropOverlay` 的色块 / Label 为正式 Sprite 阶段图
- **PRD18 / PRD19 特效音频**：订阅同一交互完成事件播放 VFX / SFX
- **PRD22 偷菜系统**：复用成熟作物判断与收获物入背包规则，但走好友田园权限与偷菜冷却
