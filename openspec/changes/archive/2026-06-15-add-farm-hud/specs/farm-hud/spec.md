## ADDED Requirements

### Requirement: 田园场景提供非模态常驻 HUD
系统 MUST 在田园场景的 UI 层挂载常驻 `HUD`，展示核心状态且禁止因 HUD 可见而暂停游戏、阻塞玩家控制或拦截 HUD 空白区域的场景输入。

#### Scenario: 进入田园场景
- **WHEN** 田园场景进入 `PLAYING` 状态
- **THEN** HUD MUST 可见并覆盖在场景画面之上
- **AND** HUD MUST 位于背包和商店模态遮罩之下
- **AND** `SceneTree.paused`、`TimeManager` 和玩家控制状态 MUST NOT 因 HUD 初始化而改变

#### Scenario: 点击 HUD 空白区域
- **WHEN** 玩家点击 HUD 中非快捷栏控件覆盖的空白区域
- **THEN** 鼠标事件 MUST 能继续到达田园场景
- **AND** HUD MUST NOT 发射 `ui_input_block_changed`

### Requirement: HUD 展示时间日期季节和昼夜阶段
HUD MUST 从 `TimeManager` 的公开查询接口读取时钟、日期、季节和昼夜阶段，并将阶段映射为可读中文。

#### Scenario: HUD 初次初始化
- **WHEN** HUD 完成 `_ready()` 初始化
- **THEN** 时钟 MUST 与 `TimeManager.get_time_text()` 一致
- **AND** 日期与季节 MUST 与 `TimeManager.get_date_text()` 和 `get_season_name()` 一致
- **AND** 昼夜阶段 MUST 将 `morning`、`afternoon`、`evening`、`night` 映射为“早晨”“下午”“傍晚”“夜晚”

#### Scenario: 时间和日期变化
- **WHEN** `minute_changed`、`day_started`、`season_changed` 或 `day_phase_changed` 被发射
- **THEN** HUD MUST 只刷新对应的时间、日期、季节或阶段显示
- **AND** 显示 MUST 与事件后的 `TimeManager` 权威状态一致

### Requirement: HUD 展示权威金币和等级经验
HUD MUST 只读展示 `GameManager.gold`、`GameManager.level` 和等级系统公开的经验进度，禁止直接修改金币、经验、等级或升级阈值。

#### Scenario: 金币变化
- **WHEN** `EventBus.gold_changed(new_amount, delta)` 被发射
- **THEN** HUD 金币文本 MUST 更新为 `new_amount`
- **AND** HUD MUST NOT 再次增加或扣除金币

#### Scenario: 获得经验或升级
- **WHEN** `EventBus.xp_gained` 或 `EventBus.level_up` 被发射
- **THEN** 等级文本 MUST 与 `GameManager.level` 一致
- **AND** 经验条 MUST 使用 `LevelManager.get_xp_progress()` 或等价公开接口返回的进度
- **AND** HUD MUST NOT 在本地复制升级判定

#### Scenario: 玩家达到满级
- **WHEN** 经验进度结果表明 `is_max_level` 为 `true`
- **THEN** HUD MUST 显示 `MAX`
- **AND** 经验条 MUST 显示满值或按设计隐藏
- **AND** HUD MUST NOT 因下一等级数据为空而报错

### Requirement: 快捷栏展示背包前九格
HUD MUST 提供 9 个固定快捷栏槽位，按索引 0 至 8 映射 `InventoryManager.get_hotbar_slots()`，并通过 `InventoryManager.get_selected_hotbar()` 展示唯一选中高亮。

#### Scenario: 展示非空快捷栏槽位
- **WHEN** 快捷栏索引 2 包含 `{ "item_id": "seed_carrot", "quantity": 12 }`
- **THEN** 第 3 个槽位 MUST 显示快捷键编号 `3`
- **AND** MUST 使用 `DataManager.get_item("seed_carrot")` 的元数据展示占位图形或短文本
- **AND** MUST 显示数量 `12`

#### Scenario: 展示空槽和单件物品
- **WHEN** 某快捷栏槽位为空或物品数量等于 1
- **THEN** 空槽 MUST 保留快捷键编号并显示空槽样式
- **AND** 数量等于 1 的槽位 MUST 隐藏数量文本

#### Scenario: 物品元数据缺失
- **WHEN** 槽位 `item_id` 在 `DataManager` 中不存在
- **THEN** 槽位 MUST 回退显示 `item_id` 和未知类型样式
- **AND** 快捷栏 MUST NOT 抛出错误或停止刷新其他槽位

### Requirement: 玩家可通过数字键或点击选择快捷栏
系统 MUST 定义 `hotbar_1` 至 `hotbar_9` InputMap Action，并使数字键和槽位点击统一调用 `InventoryManager.select_hotbar(index)`；HUD 禁止维护独立选中状态。

#### Scenario: 数字键选择第三格
- **WHEN** 快捷栏热键启用且玩家触发 `hotbar_3`
- **THEN** HUD MUST 调用 `InventoryManager.select_hotbar(2)`
- **AND** 输入 MUST 被标记为已处理
- **AND** `hotbar_selected` 后仅索引 2 MUST 显示选中高亮

#### Scenario: 点击快捷栏槽位
- **WHEN** 玩家点击索引 5 的快捷栏槽位
- **THEN** 槽位组件 MUST 将索引 5 提交给 `Hotbar`
- **AND** `Hotbar` MUST 调用 `InventoryManager.select_hotbar(5)`

#### Scenario: 选择已选中的槽位
- **WHEN** 玩家再次选择当前已选中的快捷栏索引
- **THEN** 权威选中索引 MUST 保持不变
- **AND** HUD MUST 保持唯一高亮且不得产生第二份选择状态

### Requirement: 模态输入阻塞期间停用快捷栏热键
`Hotbar` MUST 监听 `EventBus.ui_input_block_changed(blocked)`，在阻塞期间禁止数字键选择，并在阻塞解除后恢复热键。

#### Scenario: 背包或商店打开
- **WHEN** `EventBus.ui_input_block_changed(true)` 被发射
- **THEN** `hotbar_1` 至 `hotbar_9` MUST NOT 调用 `InventoryManager.select_hotbar()`
- **AND** 当前选中索引 MUST 保持不变

#### Scenario: 模态面板关闭
- **WHEN** 阻塞状态随后通过 `ui_input_block_changed(false)` 解除
- **THEN** 快捷栏数字键 MUST 恢复生效
- **AND** 下一次合法数字键输入 MUST 能选择对应槽位

### Requirement: HUD 展示当前可执行交互提示
HUD MUST 根据玩家交互目标和农田动作预览展示当前可执行动作，动作判定 MUST 以既有交互系统事件为准，禁止在 HUD 中复制农田规则。

#### Scenario: 存在可执行农田动作
- **WHEN** 当前交互目标有效且 `farm_tile_action_preview_changed` 给出 `plant`、`water`、`harvest` 或 `clear`
- **THEN** HUD MUST 分别显示“按 E 种植”“按 E 浇水”“按 E 收获”或“按 E 清除”

#### Scenario: 没有可执行动作
- **WHEN** 玩家交互目标变为空、预览动作是 `none`、动作未知或预览表明动作不可执行
- **THEN** 交互提示 MUST 隐藏
- **AND** HUD MUST NOT 根据地块字段自行推测一个动作

### Requirement: HUD 使用事件驱动的局部刷新
HUD 和 `Hotbar` MUST 监听既有 `EventBus` 信号并按受影响区域刷新，禁止在 `_process()` 中轮询时间、金币、等级、库存或交互状态。

#### Scenario: 单个快捷栏槽位变化
- **WHEN** `EventBus.inventory_changed(slot_index)` 被发射且 `slot_index` 位于 0 至 8
- **THEN** `Hotbar` MUST 重新读取并刷新该索引槽位
- **AND** 不相关槽位 MUST NOT 被重建

#### Scenario: 非快捷栏库存槽位变化
- **WHEN** `EventBus.inventory_changed(slot_index)` 被发射且 `slot_index` 大于 8
- **THEN** 快捷栏槽位 MUST 保持不变

#### Scenario: 读档完成
- **WHEN** `EventBus.game_loaded(slot, metadata)` 被发射
- **THEN** HUD MUST 全量刷新时间、金币、等级经验和快捷栏
- **AND** 快捷栏高亮 MUST 与读档后的权威选中索引一致

#### Scenario: 重复进入田园场景
- **WHEN** HUD 被释放后重新实例化或初始化逻辑被再次执行
- **THEN** 每个事件回调 MUST 最多连接一次
- **AND** 单次事件 MUST NOT 导致重复刷新副作用

### Requirement: HUD 提供独立自动化测试场景
系统 MUST 提供可独立运行的 HUD 测试场景，并将其纳入现有核心回归测试汇总。

#### Scenario: 运行 HUD 测试
- **WHEN** `scenes/test/test_hud.tscn` 被运行
- **THEN** 测试 MUST 覆盖初始化、时间、金币、等级经验、快捷栏填充与选择、输入阻塞、交互提示、缺失元数据、读档和重复连接
- **AND** 测试 MUST 输出明确的通过或失败结果
- **AND** `test_regression_runner.gd` MUST 能读取并汇总 HUD 测试的 `_passed` 与 `_failed`
