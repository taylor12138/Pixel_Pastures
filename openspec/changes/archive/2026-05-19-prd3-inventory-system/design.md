## Context

PRD1 已完成 Godot 项目骨架、JSON 数据加载、`EventBus`、`DataManager`、`GameManager` 等基础设施；PRD2 已完成 `CropManager` 作物状态机，并临时通过 `GameManager.add_item()` / `remove_item()` 处理种子消耗和收获物入包。

当前 `GameManager.inventory` 是简单的 `Dictionary`（`item_id -> quantity`），无法表达固定 20 格容量、每格数量、快捷栏映射、不可堆叠工具、拖拽排序、槽位交换/合并等背包系统需求。PRD3 将新增 `InventoryManager` 作为背包运行时权威，并让 `GameManager.inventory` 保持兼容性同步。

项目目录：`/Users/linzizhan/Desktop/coco_project/像素风田园游戏/pixel-farm/`

**现有相关文件:**
- `pixel-farm/project.godot`: 当前 Autoload 顺序为 `EventBus → DataManager → GameManager → CropManager → SceneManager → AudioManager`
- `pixel-farm/scripts/autoload/event_bus.gd`: 已有 `inventory_changed(slot_index)` / `inventory_full()`，缺少 PRD3 新增库存事件
- `pixel-farm/scripts/autoload/game_manager.gd`: 当前持有兼容字段 `inventory: Dictionary` 和简单 `add_item/remove_item/has_item/get_item_count`
- `pixel-farm/scripts/autoload/crop_manager.gd`: 当前种植/收获直接调用 `GameManager.remove_item()` / `GameManager.add_item()`
- `pixel-farm/data/items.json`: 需要补齐种子/收获物数据和 `stackable` / `max_stack` 字段

**约束条件:**
- 引擎: Godot 4.6, GDScript
- Autoload 脚本不使用 `class_name`
- 使用静态类型和 Godot 默认 Tab 缩进
- 查询接口返回 `.duplicate(true)`，避免外部直接修改内部状态
- 所有跨系统通知通过 `EventBus` 发射信号
- PRD3 仅实现数据层，不实现 UI 面板、拖拽视觉、商店买卖、物品使用效果

## Goals / Non-Goals

**Goals:**
- 新增 `InventoryManager` Autoload，作为背包/库存运行时唯一权威。
- 实现固定 20 格背包，空格为 `null`，非空格为 `{ "item_id": String, "quantity": int }`。
- 实现可堆叠/不可堆叠规则，并从 `DataManager.get_item()` 读取 `stackable` / `max_stack`。
- 实现添加、移除、指定格移除、交换、移动、合并、智能放置、丢弃等核心 API。
- 实现查询 API：指定格、全部格、物品总数、是否拥有、是否已满、空格数、可添加数量、快捷栏数据、按类型筛选、查找首个格。
- 实现 9 格快捷栏数据层：slot 0-8 映射、选中索引、选中物品、使用当前物品。
- 实现 `export_save_data()` / `import_save_data()`，并同步维护 `GameManager.inventory` 兼容字典。
- 扩展 `EventBus` 库存相关信号。
- 补齐 `items.json` 中 PRD3 需要的种子/收获物和堆叠字段。
- 修改 `CropManager` 种植/收获集成点，统一通过 `InventoryManager` 操作物品。
- 新增测试场景覆盖 PRD3 测试清单。

**Non-Goals:**
- 不实现背包 UI 面板（PRD11）。
- 不实现拖拽排序视觉交互（PRD11）。
- 不实现快捷栏输入监听；数字键 1-9 由 PRD13 HUD 调用 `select_hotbar()`。
- 不实现商店购买/出售逻辑（PRD4）。
- 不实现肥料、工具等物品具体使用效果。
- 不移除 `GameManager.inventory` 字段；本 PRD 保留它作为兼容快照。

## Decisions

### 1. 数据权威: InventoryManager 内部 slots vs GameManager.inventory

**决定**: `InventoryManager._slots` 是运行时唯一权威；`GameManager.inventory` 只作为兼容汇总快照维护。

**理由**: PRD3 需要按格管理、快捷栏映射、交换/合并/拖拽准备能力，简单字典无法表达 slot 级状态。保留 `GameManager.inventory` 可避免破坏 PRD1/PRD2 既有存档和临时代码，并为后续迁移提供兼容层。

**备选方案**: 直接删除 `GameManager.inventory`。拒绝原因：会破坏现有 `GameManager.save_game()` 结构和 `CropManager` 现有依赖，迁移风险更高。

### 2. 槽位结构: Array 固定长度 vs Dictionary keyed by slot index

**决定**: 使用固定长度 `Array`，长度恒为 `MAX_SLOTS = 20`，元素为 `Dictionary` 或 `null`。

**理由**: 背包是固定格数，快捷栏直接映射前 9 格；Array 更自然表达顺序、交换、移动、切片和 UI 渲染顺序。

**备选方案**: 使用 `Dictionary[int, Dictionary]` 只存非空格。拒绝原因：需要额外维护空格和顺序，快捷栏切片不直观。

### 3. 快捷栏模型: 背包前 9 格映射 vs 独立 hotbar 存储

**决定**: 快捷栏不独立存储，`get_hotbar_slots()` 返回 `_slots[0..8]` 的副本，`_selected_hotbar` 只记录选中索引。

**理由**: PRD3 明确“前 9 格 = 快捷栏”，避免双源同步问题。后续 HUD 只负责监听信号和渲染，不拥有数据。

**备选方案**: 独立 `_hotbar_slots`。拒绝原因：会产生背包与快捷栏同步复杂度，且与 PRD3 约束不一致。

### 4. 添加物品策略: 先合并再放空格

**决定**: `add_item()` 对可堆叠物品先遍历已有同类未满格并填充，再将剩余数量放入空格；不可堆叠物品每个占用一个空格。

**理由**: 符合常见背包行为，能最大化利用容量，并满足“向已满格堆叠时先填满该格，剩余尝试下一格”的边界要求。

**备选方案**: 总是放入第一个空格。拒绝原因：会浪费格子且不满足堆叠需求。

### 5. 未知 item_id 处理

**决定**: 当 `DataManager.get_item(item_id)` 返回空字典时，`InventoryManager` 使用默认规则 `stackable = true`、`max_stack = 99`，并 `push_warning()`。

**理由**: PRD3 指定该行为，允许开发期缺失数据时系统继续运行，同时通过 warning 暴露数据问题。

**备选方案**: 返回失败并拒绝添加。拒绝原因：会让数据表缺漏直接阻断测试和调试流程，不符合 PRD3 边界表。

### 6. 信号粒度

**决定**: 每个发生变化的 slot 发射 `EventBus.inventory_changed(slot_index)`；添加成功发射 `item_added(item_id, quantity, slot_index)`；移除成功发射 `item_removed(item_id, quantity)`；背包无法完全接收时发射 `inventory_full()`；快捷栏切换发射 `hotbar_selected(index)`。

**理由**: slot 级信号便于 PRD11 局部刷新 UI；物品级信号便于 PRD4/通知/成就系统监听；满包和快捷栏事件便于 HUD 提示。

**备选方案**: 只发射全局 `inventory_changed()`。拒绝原因：后续 UI 无法精准刷新，且缺少物品增删语义。

### 7. 存档导入导出

**决定**: `InventoryManager.export_save_data()` 返回 `{ "slots": _slots.duplicate(true), "selected_hotbar": _selected_hotbar }`；`import_save_data()` 负责修正 slots 长度并清理非法数量；同步汇总到 `GameManager.inventory`。

**理由**: 保留 slot 级数据可恢复排序和快捷栏状态；同步汇总字典保证旧存档字段和其他系统读取兼容。

**备选方案**: 仅存 `GameManager.inventory` 字典并启动时重新排布。拒绝原因：会丢失格子顺序和快捷栏排列，不满足 PRD3。

### 8. Autoload 加载顺序

**决定**: 在 `project.godot` 中将 `InventoryManager` 注册在 `CropManager` 之后、`SceneManager` 之前，即 `EventBus → DataManager → GameManager → CropManager → InventoryManager → SceneManager → AudioManager`。

**理由**: PRD3 明确该顺序；`InventoryManager` 依赖 `EventBus`、`DataManager`、`GameManager`，而 `SceneManager`/`AudioManager` 不应成为背包数据层前置依赖。

**注意**: `CropManager` 后续运行时会调用 `InventoryManager`，虽然 Autoload 初始化顺序中 `CropManager._ready()` 早于 `InventoryManager._ready()`，但调用发生在玩家操作阶段。实现时避免在 `CropManager._ready()` 内访问 `InventoryManager`。

**备选方案**: 将 `InventoryManager` 放在 `CropManager` 之前。拒绝原因：不符合 PRD3 指定加载顺序；如果后续发现 ready 阶段依赖问题，可在实现中延迟加载或调整设计并更新 spec。

### 9. CropManager 集成方式

**决定**: `CropManager.plant_crop()` 使用 `InventoryManager.remove_item(seed_id, 1)` 扣除种子，`harvest_crop()` 使用 `InventoryManager.add_item("harvest_" + crop_id, 1)` 入包；如果收获时背包无法接收，按 PRD3 `add_item()` 返回值判断是否成功入包。

**理由**: 统一物品入口，避免 `GameManager.inventory` 与 `_slots` 双写冲突。

**备选方案**: `CropManager` 继续调用 `GameManager`，由 `GameManager` 转发到 `InventoryManager`。暂不采用，因为会模糊权威边界；如果为了兼容旧 API，可让 `GameManager` 方法成为薄转发，但新代码应直接依赖 `InventoryManager`。

## Risks

| 风险 | 缓解 |
|------|------|
| `GameManager.inventory` 与 `InventoryManager._slots` 出现双源不一致 | 只允许 `InventoryManager` 写入物品状态；每次变更后统一 `_sync_to_game_manager()` 生成汇总快照 |
| Autoload 顺序中 `CropManager` 早于 `InventoryManager`，运行时引用可能出错 | 避免在 `CropManager._ready()` 访问 `InventoryManager`；仅在玩家操作函数内调用；测试场景覆盖集成路径 |
| 旧存档只有字典 inventory，没有 slot 数据 | `InventoryManager` 可提供从 `GameManager.inventory` 初始化 slots 的兼容路径，按堆叠规则自动排布 |
| `items.json` 数据缺漏导致堆叠规则错误 | `DataManager.get_item()` 为空时 `push_warning()` 并使用默认规则；PRD3 同时补齐物品表和测试覆盖 |
| 添加物品部分成功时用户感知不清 | `add_item()` 返回实际添加数量；不足时发射 `inventory_full()`，后续 UI/HUD 可提示 |
| 快捷栏使用当前物品可能误删工具 | `use_selected_item()` 只做数据层消耗 1 个；工具等不可消耗物品的具体使用效果后续 PRD 再定义，测试需明确当前行为 |
| 查询接口返回内部引用导致外部篡改 | 所有 slot/数组/筛选结果查询统一返回 `.duplicate(true)` |
