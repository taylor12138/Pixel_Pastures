## 上下文

项目已完成 `InventoryManager`、`DataManager`、`FarmInteractionController` 和田园场景。库存数据层固定为 20 格，前 9 格直接映射快捷栏，并通过 `inventory_changed`、`hotbar_selected` 等 EventBus 信号广播变化。目前没有正式背包面板，农田选种仍主要依赖 PRD10 调试按键。

背包 UI 横跨 Control 场景、库存数据、快捷栏选择、农田交互和玩家输入。实现必须兼容 480×320 基础视口，不依赖正式美术，不复制库存或快捷栏状态，并避免 UI 鼠标和键盘事件穿透到田园玩法。

## 目标 / 非目标

**目标：**

- 提供可在田园场景中打开的 20 格背包面板和可复用槽位组件。
- 通过现有 `InventoryManager` API 完成显示、移动、合并、交换和丢弃。
- 保持真实槽位索引稳定，使分类筛选、快捷栏映射和拖拽目标一致。
- 在面板打开期间统一阻塞角色移动与农田交互，但不暂停游戏时间。
- 将快捷栏选中物同步到 `FarmInteractionController`，并清除失效的旧选择。
- 建立事件驱动刷新和可独立运行的 UI 测试场景。

**非目标：**

- 不实现 PRD13 常驻 HUD 快捷栏和数字键 1-9 正式输入。
- 不实现商店交易、物品拆分堆叠、地面掉落、装备或背包扩容。
- 不引入正式 UI 图集、物品图标或第三方 UI 框架。
- 不使用背包打开作为全局暂停或 TimeManager 暂停。

## 决策

### 1. 固定创建 20 个槽位视图并绑定真实索引

`InventoryPanel` 初始化时创建或收集 20 个 `InventorySlot`，每个组件永久绑定 `slot_index` 0-19。分类筛选只隐藏不匹配槽位的物品内容，不压缩、不排序、不重新编号。

原因：前 9 格具有快捷栏语义，拖放数据也使用真实索引。若筛选后重建紧凑列表，显示位置与数据索引会分离，容易移动错误物品。

替代方案是根据筛选结果动态创建列表，但该方案需要额外的显示索引到真实索引映射，复杂度和误操作风险更高。

### 2. InventoryManager 保持唯一数据权威

UI 只调用 `get_slot()`、`get_all_slots()`、`select_hotbar()`、`smart_place()` 和 `discard_slot()`。槽位组件不直接修改 `_slots`，也不在本地预测交换结果；操作后依赖 EventBus 刷新。

原因：移动、堆叠上限、不可堆叠规则和 GameManager 兼容同步已经集中在数据层。复用数据层可以保证 UI、存档、经济和农田逻辑一致。

### 3. 使用 Godot Control 原生拖放协议

`InventorySlot` 实现 `_get_drag_data()`、`_can_drop_data()` 和 `_drop_data()`。拖拽载荷只包含来源类型、真实槽位索引和用于预览的 `item_id`；释放时统一调用 `InventoryManager.smart_place(from_index, to_index)`。

拖到面板外、原槽位或非法目标时取消操作，不触发丢弃。丢弃必须走详情面板按钮和确认框。

### 4. 事件驱动局部刷新，读档时全量刷新

普通库存操作监听 `inventory_changed(slot_index)` 并只刷新对应槽位。`game_loaded`、首次打开和测试重置允许调用 `refresh_all_slots()`。详情面板在其选中槽位变化后重新查询数据，避免保存失效引用。

不在 `_process()` 中轮询 20 格。虽然数据量小，但事件驱动更符合现有架构，也便于 PRD12/13 复用。

### 5. 背包内快捷栏只展示并选择 slot 0-8

背包不维护独立快捷栏数组。双击或详情区“选择”仅允许对 slot 0-8 调用 `InventoryManager.select_hotbar()`；非快捷栏槽位提示先拖入前 9 格。

收到 `hotbar_selected` 后，面板刷新选中边框并调用 `FarmInteractionController.sync_selection_from_hotbar()`。当选中槽为空、物品被移走或丢弃时，控制器必须调用 `clear_selection()`，禁止沿用旧种子或工具。

### 6. 使用 UI 输入锁，不暂停 SceneTree

`InventoryPanel.open_panel()` 发射 `ui_input_block_changed(true)`，同时通过已绑定的 PlayerController/Farm 场景入口禁用移动、交互和农田鼠标处理；关闭时发射 `false` 并恢复控制。

不使用 `get_tree().paused`，因为背包属于功能面板而非系统暂停菜单。全局暂停会改变 TimeManager、作物推进和自动存档语义，并要求为 UI 配置额外 process mode。

实现应保存打开前的玩家移动/交互状态，关闭时恢复原值，而不是无条件启用，以兼容对话、过场或其他系统锁定。

### 7. UI 场景独立于田园业务

`InventoryPanel.setup(interaction_controller = null, player_controller = null)` 接受可选引用。没有田园控制器时，背包仍可在房间、商店和测试场景中显示与整理物品；只有快捷栏到农田模式的同步被跳过。

田园场景通过 `CanvasLayer/InventoryPanel` 挂载，并使用全屏遮罩 `mouse_filter = MOUSE_FILTER_STOP` 防止鼠标穿透。

### 8. 占位视觉由类型映射生成

`items.json` 当前没有 `icon_path`。槽位使用类型颜色、短文本和数量 Label；详情区展示完整元数据。后续加入正式图标时，在槽位渲染层读取图标字段，不改变数据和拖放接口。

## 风险 / 权衡

- [筛选隐藏后目标内容不可见，玩家可能不清楚释放结果] → 目标槽位仍保留边框和索引；释放后给出成功反馈，切回“全部”可确认结果。
- [同类满堆叠的 `smart_place()` 会回退为交换] → UI 遵循现有数据层契约并在测试中固定行为；若产品规则变化，先修改 inventory-data 规范。
- [打开前玩家已被其他系统禁用，关闭背包后被错误恢复] → 保存并恢复原移动/交互状态，不直接写死为 `true`。
- [快速重复开关导致重复信号连接] → 信号仅在 `_ready()` 连接一次，开关方法必须幂等。
- [当前选中槽位内容被拖走后仍保留农田模式] → 每次相关 `inventory_changed` 后检查 selected hotbar，并同步或清空控制器选择。
- [480×320 下 20 格与详情区拥挤] → 使用 40×40 槽位、5 列布局和 420×276 主窗口；文本采用自动换行和截断。
- [PRD10 调试数字键绕过 UI 锁] → Farm 场景和控制器在处理 debug key 前检查统一的 UI 阻塞状态。

## 迁移计划

1. 补齐 `open_bag`、`cancel` InputMap 和 EventBus UI 信号。
2. 新增独立槽位与背包面板场景，不修改库存存档结构。
3. 在田园场景挂载面板并接入玩家/农田输入锁。
4. 收紧 `sync_selection_from_hotbar()` 的空槽位行为。
5. 加入自动化测试并运行现有回归测试。

该变更不迁移存档 schema。回滚时可移除 UI 场景和新信号，现有 InventoryManager 数据仍保持兼容。

## 开放问题

- 正式物品图标字段名（例如 `icon_path`）留待美术资源接入时确定。
- 常驻 HUD 完成后，数字键选择与 PRD10 调试直选的最终移除由 PRD13 负责。
