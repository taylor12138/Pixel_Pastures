## ADDED Requirements

### Requirement: 背包面板可打开和关闭
系统 MUST 提供 `InventoryPanel` 功能面板，并允许玩家通过 `open_bag` Action 打开或关闭；面板初始 MUST 为关闭状态。

#### Scenario: Tab 打开背包
- **WHEN** 背包关闭且玩家触发 `open_bag`
- **THEN** `InventoryPanel` MUST 变为可见
- **AND** `is_panel_open()` MUST 返回 `true`
- **AND** `EventBus.inventory_panel_opened()` MUST 被发射一次

#### Scenario: Tab 或取消操作关闭背包
- **WHEN** 背包打开且玩家再次触发 `open_bag`、`cancel` 或关闭按钮
- **THEN** `InventoryPanel` MUST 隐藏
- **AND** `is_panel_open()` MUST 返回 `false`
- **AND** `EventBus.inventory_panel_closed()` MUST 被发射一次

#### Scenario: 重复调用保持幂等
- **WHEN** 已打开的面板再次调用 `open_panel()` 或已关闭的面板再次调用 `close_panel()`
- **THEN** 面板状态 MUST 保持不变
- **AND** 对应状态事件 MUST NOT 重复发射

### Requirement: 背包固定展示真实 20 格
`InventoryPanel` MUST 展示 5 列 × 4 行共 20 个槽位，并使每个 `InventorySlot` 永久绑定真实索引 0-19。

#### Scenario: 初始化槽位
- **WHEN** 背包面板初始化
- **THEN** `SlotsGrid` MUST 包含 20 个槽位组件
- **AND** 槽位索引 MUST 依次为 0 到 19

#### Scenario: 槽位读取权威数据
- **WHEN** 刷新任意槽位
- **THEN** UI MUST 通过 `InventoryManager.get_slot(slot_index)` 或等价公开接口读取数据
- **AND** UI MUST NOT 直接读取或修改 `InventoryManager._slots`

### Requirement: 槽位和详情展示物品数据
系统 MUST 使用 `InventoryManager` 槽位数据与 `DataManager.get_item(item_id)` 元数据展示物品名称、数量、类型和详情；缺失元数据 MUST 使用安全回退。

#### Scenario: 展示占用槽位
- **WHEN** 槽位包含 `{ "item_id": "seed_carrot", "quantity": 12 }`
- **THEN** 槽位 MUST 显示胡萝卜种子的占位图形或短文本
- **AND** MUST 显示数量 `12`

#### Scenario: 选择物品查看详情
- **WHEN** 玩家单击非空槽位
- **THEN** 详情区 MUST 显示名称、类型、数量、描述、堆叠上限及存在的价格字段
- **AND** `EventBus.inventory_slot_selected(slot_index, slot_data)` MUST 被发射

#### Scenario: 元数据缺失
- **WHEN** 槽位 item_id 在 DataManager 中不存在
- **THEN** UI MUST 使用 item_id 和未知类型占位样式
- **AND** MUST NOT 抛出错误或阻止面板继续使用

### Requirement: 分类筛选保持真实索引
系统 MUST 支持全部、种子、收获物、工具、消耗品和装饰筛选，并禁止筛选改变槽位顺序、真实索引或库存数据。

#### Scenario: 筛选种子
- **WHEN** 玩家选择种子筛选
- **THEN** `type == "seed"` 的物品内容 MUST 可见
- **AND** 不匹配物品 MUST 显示为隐藏或禁用内容
- **AND** 20 个槽位位置和索引 MUST 保持不变

#### Scenario: 切回全部
- **WHEN** 玩家从任意筛选切回全部
- **THEN** 所有物品 MUST 按原真实槽位恢复显示
- **AND** InventoryManager 数据 MUST 未因筛选发生变化

### Requirement: 拖拽提交给 InventoryManager
`InventorySlot` MUST 使用 Godot Control 拖放接口，并将有效释放统一提交给 `InventoryManager.smart_place(from_index, to_index)`。

#### Scenario: 移动到空槽位
- **WHEN** 玩家将占用槽拖到空槽
- **THEN** UI MUST 调用 `smart_place(from_index, to_index)`
- **AND** 数据层 MUST 将源内容移动到目标
- **AND** 两个槽位显示 MUST 随 `inventory_changed` 刷新

#### Scenario: 合并同类物品
- **WHEN** 玩家将同类可堆叠物品拖到未满的目标堆叠
- **THEN** 数据层 MUST 按 max_stack 合并
- **AND** UI MUST 显示目标新数量和源槽剩余数量或空状态

#### Scenario: 交换不同物品
- **WHEN** 玩家将物品拖到包含不同 item_id 的目标槽
- **THEN** 数据层 MUST 交换两个槽位内容
- **AND** UI MUST 显示交换后的权威数据

#### Scenario: 放回原槽或面板外
- **WHEN** 拖拽释放到原槽位、面板外或非法目标
- **THEN** 库存数据 MUST 保持不变
- **AND** 操作 MUST NOT 自动丢弃物品

### Requirement: 丢弃需要明确确认
系统 MUST 通过详情区丢弃入口和确认对话框丢弃整格物品，并禁止通过拖到面板外直接丢弃。

#### Scenario: 确认丢弃整格
- **WHEN** 玩家选择非空槽位、点击丢弃并确认
- **THEN** UI MUST 调用 `InventoryManager.discard_slot(slot_index, -1)`
- **AND** 槽位 MUST 变为空
- **AND** 系统 MUST NOT 创建地面掉落物

#### Scenario: 取消丢弃
- **WHEN** 玩家在确认对话框取消
- **THEN** 槽位数据和详情 MUST 保持不变

### Requirement: 背包内快捷栏映射和选择
背包槽位 0-8 MUST 标记为快捷栏 1-9，并与 `InventoryManager.selected_hotbar_index` 使用同一份状态。

#### Scenario: 快捷栏编号显示
- **WHEN** 背包面板可见
- **THEN** slot 0-8 MUST 分别显示快捷键编号 1-9
- **AND** slot 9-19 MUST NOT 显示快捷栏编号

#### Scenario: 选择快捷栏槽位
- **WHEN** 玩家双击 slot 0-8 或在详情区点击选择
- **THEN** UI MUST 调用 `InventoryManager.select_hotbar(slot_index)`
- **AND** 当前选中槽位 MUST 显示高亮

#### Scenario: 非快捷栏槽位不可直接选择
- **WHEN** 玩家尝试选择 slot 9-19 的物品作为快捷栏物品
- **THEN** UI MUST 提示先将物品拖入前 9 格
- **AND** selected hotbar index MUST 保持不变

### Requirement: 背包变化事件驱动刷新
背包 UI MUST 监听库存和读档事件；普通槽位变化 MUST 局部刷新，读档 MUST 全量刷新。

#### Scenario: 单槽变化
- **WHEN** `EventBus.inventory_changed(3)` 被发射
- **THEN** 面板 MUST 重新读取并刷新 slot 3
- **AND** 若详情当前指向 slot 3，详情 MUST 同步刷新

#### Scenario: 读档完成
- **WHEN** `EventBus.game_loaded(slot, metadata)` 被发射
- **THEN** 面板 MUST 全量刷新 20 格
- **AND** 快捷栏高亮 MUST 与读档后的 selected hotbar index 一致

### Requirement: 面板打开阻止玩法输入但不暂停时间
背包打开期间系统 MUST 阻止鼠标和键盘玩法输入穿透，同时默认 MUST NOT 暂停 SceneTree 或 TimeManager。

#### Scenario: 打开背包阻塞玩法
- **WHEN** 背包面板打开
- **THEN** `EventBus.ui_input_block_changed(true)` MUST 被发射
- **AND** 玩家移动、E 交互、农田点击和调试数字键 MUST 不产生玩法效果

#### Scenario: 关闭背包恢复原状态
- **WHEN** 背包面板关闭
- **THEN** `EventBus.ui_input_block_changed(false)` MUST 被发射
- **AND** 玩家控制 MUST 恢复到打开前的启用状态

#### Scenario: 游戏时间继续
- **WHEN** 背包打开且未由其他系统暂停时间
- **THEN** SceneTree MUST NOT 因背包面板被设置为 paused
- **AND** TimeManager MUST 继续按原状态运行

### Requirement: 背包 UI 提供自动化测试场景
系统 MUST 提供可独立运行的背包 UI 测试场景，覆盖核心显示、操作和联动行为。

#### Scenario: 测试场景运行
- **WHEN** `test_inventory_panel.tscn` 运行
- **THEN** 测试 MUST 能验证 20 格初始化、开关、筛选、拖拽、快捷栏选择、丢弃和读档刷新
- **AND** 测试 MUST 输出明确通过或失败结果
