# PRD3: 背包/库存系统 (数据层)

> **优先级**: P0 — 核心玩法基础
> **美术依赖**: 无（纯逻辑/数据层，无视觉表现）
> **预计工期**: 3-4 天
> **前置依赖**: PRD1（项目骨架 + 核心数据系统）
> **产出**: InventoryManager 全局单例 + 背包数据结构 + 快捷栏系统 + 单元测试场景
> **最后更新**: 2026-05-08

---

## 1. 目标

实现《像素田园》的背包/库存数据层系统，包含：
- 20 格背包容量管理（固定格数）
- 物品堆叠规则（种子/收获物可堆叠，工具不可堆叠）
- 快捷栏映射（9 格快捷栏 = 背包前 9 格）
- 增删改查 API（添加/移除/交换/查询物品）
- 背包满载检测与信号通知
- 与 GameManager 存档数据的同步

完成后，可通过代码调用完成完整的「物品获取 → 存入背包 → 查询/使用 → 移除/出售」流程，并通过 EventBus 广播所有背包状态变更。

**额外职责**：补齐 `data/items.json` 中缺失的种子和收获物条目（PRD1 遗留），确保背包系统有完整数据可操作。

---

## 2. 核心设计决策（已确认）

| 决策 | 内容 | 来源 |
|------|------|------|
| 固定 20 格 | 背包容量固定为 20 格，不可扩展 | 《游戏设计文档》表格 |
| 前 9 格 = 快捷栏 | 快捷栏直接映射背包 slot 0-8，非独立存储 | 《游戏设计文档》UI 布局 |
| 堆叠上限 99 | 可堆叠物品最大数量为 99 | PRD1 items.json 定义 |
| 工具不可堆叠 | type=tool 的物品 max_stack=1 | PRD1 items.json 定义 |
| 按格管理 | 每格存储 {item_id, quantity}，空格为 null | 设计决定 |

---

## 3. 功能需求

### 3.1 数据结构

#### 3.1.1 背包槽位定义

```gdscript
## 单个背包槽位数据
## null 表示空格
## Dictionary 格式: {"item_id": String, "quantity": int}

const MAX_SLOTS: int = 20
const HOTBAR_SIZE: int = 9

var _slots: Array = []  ## 长度固定为 MAX_SLOTS, 元素为 Dictionary 或 null
var _selected_hotbar: int = 0  ## 当前选中的快捷栏索引 (0-8)
```

#### 3.1.2 物品数据查询

物品的元数据（name, type, stackable, max_stack 等）从 DataManager.get_item() 获取，InventoryManager 仅存储 item_id + quantity。

### 3.2 核心操作 API

#### 3.2.1 添加物品

```gdscript
## 向背包添加物品
## 返回实际添加的数量（可能因满载而少于请求数量）
func add_item(item_id: String, quantity: int = 1) -> int

## 逻辑:
## 1. 从 DataManager 获取物品配置（stackable, max_stack）
## 2. 如果可堆叠: 先尝试合并到已有同类物品的格子
## 3. 如果还有剩余: 放入第一个空格
## 4. 如果背包已满: 返回实际添加数量，发射 inventory_full 信号
## 5. 每次变更发射 inventory_changed 信号
```

#### 3.2.2 移除物品

```gdscript
## 从背包移除指定数量的物品
## 返回实际移除的数量
func remove_item(item_id: String, quantity: int = 1) -> int

## 逻辑:
## 1. 遍历所有格子，找到包含该 item_id 的格子
## 2. 从找到的格子中依次扣除，直到满足 quantity
## 3. 如果某格扣到 0，将该格设为 null
## 4. 发射 inventory_changed 信号
```

#### 3.2.3 从指定格移除

```gdscript
## 从指定格子移除物品
## 返回实际移除的数量
func remove_from_slot(slot_index: int, quantity: int = 1) -> int
```

#### 3.2.4 交换格子

```gdscript
## 交换两个格子的内容（用于拖拽排序）
func swap_slots(from_index: int, to_index: int) -> bool
```

#### 3.2.5 查询接口

```gdscript
## 获取指定格子的数据（null 表示空格）
func get_slot(slot_index: int) -> Variant

## 获取所有格子数据（返回完整数组副本）
func get_all_slots() -> Array

## 查询某物品的总数量（跨格合计）
func get_item_count(item_id: String) -> int

## 查询是否拥有指定数量的物品
func has_item(item_id: String, quantity: int = 1) -> bool

## 查询背包是否已满（无空格且所有格均达上限）
func is_full() -> bool

## 获取剩余可用格数
func get_empty_slot_count() -> int

## 查询指定物品可以再添加多少个
func get_addable_count(item_id: String) -> int

## 获取快捷栏数据（slot 0-8 的子数组）
func get_hotbar_slots() -> Array

## 按物品类型筛选背包中的物品（为 PRD11 UI 准备）
## type: "seed" / "harvest" / "tool" / "decoration" / "consumable"
func get_items_by_type(type: String) -> Array

## 查找包含指定物品的第一个格子索引，未找到返回 -1
func find_item_slot(item_id: String) -> int
```

#### 3.2.6 格子移动与合并

```gdscript
## 将指定格物品移动到目标空格
## 目标格必须为空，否则返回 false
func move_to_slot(from_index: int, to_index: int) -> bool

## 将 from 格的物品合并到 to 格（仅同 item_id 且可堆叠时有效）
## 合并后如果 from 格数量归零则设为 null
## 返回实际合并的数量
func merge_slots(from_index: int, to_index: int) -> int

## 智能放置：如果目标格为空则移动，如果同类则合并，如果不同类则交换
## UI 拖拽释放时统一调用此方法
func smart_place(from_index: int, to_index: int) -> bool

## 丢弃指定格物品（销毁，不保留到地面）
## quantity = -1 表示全部丢弃
func discard_slot(slot_index: int, quantity: int = -1) -> bool
```

### 3.3 快捷栏系统

#### 3.3.1 快捷栏选择

```gdscript
## 当前选中的快捷栏索引
var selected_hotbar_index: int = 0

## 切换快捷栏选中项
func select_hotbar(index: int) -> void

## 获取当前选中的物品数据
func get_selected_item() -> Variant

## 使用当前选中物品（消耗 1 个）
## 返回被使用的 item_id，失败返回空字符串
func use_selected_item() -> String
```

#### 3.3.2 快捷栏约束

- 快捷栏 = 背包 slot[0] ~ slot[8]，不是独立存储
- 数字键 1-9 对应 index 0-8
- 切换时发射信号通知 UI 更新
- **输入监听归属**: 数字键 1-9 的监听由 PRD13 (HUD) 负责，InventoryManager 只提供 `select_hotbar()` 被动接口，不主动处理 Input

### 3.4 信号发射

所有操作完成后通过 EventBus 广播：

```gdscript
## 已在 EventBus 中定义:
signal inventory_changed(slot_index: int)  ## 某格内容变更
signal inventory_full()                     ## 添加失败，背包已满

## 新增信号（需添加到 EventBus）:
signal hotbar_selected(index: int)          ## 快捷栏切换
signal item_added(item_id: String, quantity: int, slot_index: int)  ## 物品入包
signal item_removed(item_id: String, quantity: int)  ## 物品出包
```

### 3.5 存档集成

#### 3.5.1 数据导出

```gdscript
## 导出为可序列化数据（用于存档）
func export_save_data() -> Dictionary:
    return {
        "slots": _slots.duplicate(true),
        "selected_hotbar": _selected_hotbar,
    }
```

#### 3.5.2 数据导入

```gdscript
## 从存档数据恢复
func import_save_data(data: Dictionary) -> void:
    _slots = data.get("slots", _create_empty_slots())
    _selected_hotbar = data.get("selected_hotbar", 0)
    # 确保 slots 长度正确
    _slots.resize(MAX_SLOTS)
```

### 3.6 与现有系统交互

#### 3.6.1 替代 GameManager.inventory

当前 GameManager 中有一个简单的 `inventory: Dictionary` (item_id -> quantity)。PRD3 实现后：
- InventoryManager 成为物品管理的唯一权威
- GameManager.inventory 保留但由 InventoryManager 同步维护（向后兼容）
- CropManager 的 `plant_crop()` 和 `harvest_crop()` 改为调用 InventoryManager

#### 3.6.2 CropManager 集成点

```gdscript
## plant_crop 中：
## 旧: GameManager.remove_item(seed_id, 1)
## 新: InventoryManager.remove_item(seed_id, 1)

## harvest_crop 中：
## 旧: GameManager.add_item("harvest_" + crop_id, 1)
## 新: InventoryManager.add_item("harvest_" + crop_id, 1)
```

---

## 4. 数据表补齐（PRD1 遗留）

当前 `data/items.json` 仅有 5 个物品，需补齐种子和收获物条目以支持完整背包流程。

### 4.1 需新增的种子物品（10 个）

| item_id | name | type | crop_id | stackable | max_stack |
|---------|------|------|---------|-----------|-----------|
| seed_carrot | 胡萝卜种子 | seed | carrot | true | 99 |
| seed_tomato | 番茄种子 | seed | tomato | true | 99 |
| seed_cabbage | 白菜种子 | seed | cabbage | true | 99 |
| seed_corn | 玉米种子 | seed | corn | true | 99 |
| seed_potato | 土豆种子 | seed | potato | true | 99 |
| seed_strawberry | 草莓种子 | seed | strawberry | true | 99 |
| seed_pepper | 辣椒种子 | seed | pepper | true | 99 |
| seed_pumpkin | 南瓜种子 | seed | pumpkin | true | 99 |
| seed_eggplant | 茄子种子 | seed | eggplant | true | 99 |
| seed_broccoli | 西兰花种子 | seed | broccoli | true | 99 |

### 4.2 需新增的收获物品（10 个）

| item_id | name | type | sell_price | stackable | max_stack |
|---------|------|------|-----------|-----------|-----------|
| harvest_carrot | 胡萝卜 | harvest | 25 | true | 99 |
| harvest_tomato | 番茄 | harvest | 40 | true | 99 |
| harvest_cabbage | 白菜 | harvest | 20 | true | 99 |
| harvest_corn | 玉米 | harvest | 55 | true | 99 |
| harvest_potato | 土豆 | harvest | 30 | true | 99 |
| harvest_strawberry | 草莓 | harvest | 65 | true | 99 |
| harvest_pepper | 辣椒 | harvest | 45 | true | 99 |
| harvest_pumpkin | 南瓜 | harvest | 90 | true | 99 |
| harvest_eggplant | 茄子 | harvest | 50 | true | 99 |
| harvest_broccoli | 西兰花 | harvest | 60 | true | 99 |

### 4.3 现有物品需补充字段

现有 5 个物品需统一添加 `stackable` 和 `max_stack` 字段：

| item_id | stackable | max_stack |
|---------|-----------|-----------|
| watering_can | false | 1 |
| fertilizer | true | 99 |
| fence_wood | true | 99 |
| scarecrow | true | 99 |
| stone_path | true | 99 |

---

## 5. 边界情况处理

| 场景 | 行为 |
|------|------|
| 添加物品时背包满 | 尽可能堆叠到现有格，剩余丢弃，发射 inventory_full |
| 添加不可堆叠物品时无空格 | 返回 0，发射 inventory_full |
| 移除数量超过持有量 | 移除所有已有的，返回实际移除量 |
| 移除不存在的物品 | 返回 0，不发射信号 |
| 交换时 index 越界 | 返回 false，不执行 |
| 向已满格堆叠物品 | 先填满该格，剩余尝试下一格 |
| item_id 在 DataManager 中不存在 | push_warning，按默认规则处理（stackable=true, max_stack=99） |

---

## 6. 测试需求

### 6.1 自动化测试场景

创建 `scenes/test/test_inventory_manager.tscn` + `test_inventory_manager.gd`

### 6.2 测试用例清单

```gdscript
func _ready() -> void:
    print("=== InventoryManager 自动化测试 ===")

    test_add_item_basic()
    test_add_item_stacking()
    test_add_item_overflow()
    test_add_item_non_stackable()
    test_add_item_full_inventory()
    test_remove_item_basic()
    test_remove_item_partial()
    test_remove_item_not_found()
    test_remove_from_slot()
    test_swap_slots()
    test_swap_empty_slot()
    test_move_to_slot()
    test_merge_slots()
    test_smart_place_empty()
    test_smart_place_same_item()
    test_smart_place_different_item()
    test_discard_slot()
    test_has_item()
    test_get_item_count()
    test_get_items_by_type()
    test_find_item_slot()
    test_is_full()
    test_get_empty_slot_count()
    test_get_addable_count()
    test_hotbar_select()
    test_hotbar_use_item()
    test_hotbar_use_empty()
    test_export_import()
    test_clear_inventory()

    print("=== 全部测试完成 ===")
```

### 6.3 调试辅助接口

```gdscript
## [调试] 打印所有背包格子状态
func debug_print_all() -> void

## [调试] 清空背包
func debug_clear() -> void

## [调试] 填满背包（测试用）
func debug_fill_random() -> void
```

---

## 7. 技术约束

1. **Autoload 注册**:
   - 脚本路径: `scripts/autoload/inventory_manager.gd`
   - 注册名: `InventoryManager`
   - 加载顺序: EventBus → DataManager → GameManager → CropManager → **InventoryManager** → SceneManager → AudioManager
   - **不使用 class_name**（Autoload 限制）

2. **数据不可变**:
   - 查询接口返回副本（.duplicate(true)），防止外部修改内部数据
   - 物品元数据从 DataManager 只读获取

3. **信号优先**:
   - 所有状态变更通过 EventBus 信号通知
   - UI 层（PRD11）仅通过信号监听更新

4. **性能**:
   - 20 格遍历 O(20) 常数级，无性能压力
   - 不使用 _process，纯事件驱动

---

## 8. 需要新增/修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `data/items.json` | **修改** | 补齐 20 个种子/收获物条目 + 现有物品加 stackable 字段 |
| `scripts/autoload/inventory_manager.gd` | **新增** | 背包管理器主体 (~300行) |
| `scripts/autoload/event_bus.gd` | **修改** | 新增 hotbar_selected / item_added / item_removed 信号 |
| `project.godot` | **修改** | [autoload] 新增 InventoryManager 注册 |
| `scenes/test/test_inventory_manager.tscn` | **新增** | 测试场景 |
| `scenes/test/test_inventory_manager.gd` | **新增** | 测试脚本 (~350行) |
| `scripts/autoload/crop_manager.gd` | **修改** | plant/harvest 改用 InventoryManager |

---

## 9. 非目标 (Not in Scope)

- ❌ 背包 UI 面板（PRD11）
- ❌ 拖拽排序的视觉交互（PRD11）
- ❌ 物品图标/描述显示（PRD11）
- ❌ 商店买卖逻辑（PRD4）
- ❌ 物品使用效果（如肥料加速）— 后续 PRD
- ❌ 装备系统（本游戏无装备概念）

PRD3 的目标是：**让背包数据层 100% 就绪，PRD4（经济系统）和 PRD11（背包 UI）可以直接在此基础上开发。**

---

## 10. 后续衔接

| 完成 PRD3 后可启动 | 说明 |
|-------------------|------|
| → PRD4 (经济系统) | 商店买卖操作直接调用 InventoryManager |
| → PRD11 (背包 UI) | 监听 EventBus 信号渲染格子 |
| → PRD10 (种植交互) | 从快捷栏选种子进行种植 |

---

> *本 PRD 完成后，背包系统应处于「可增删改查、可存档恢复、可与种植系统联动」的状态。*
