## ADDED Requirements

### Requirement: 商店面板可稳定打开和关闭

系统 MUST 提供 `ShopPanel`，支持宿主场景调用 `open_panel()`、`close_panel()`、`toggle_panel()` 和 `is_panel_open()`；面板初始 MUST 为关闭状态，重复开关调用 MUST 保持幂等。

#### Scenario: 打开商店面板
- **WHEN** 商店面板关闭且调用 `open_panel()`
- **THEN** 面板 MUST 变为可见
- **AND** `is_panel_open()` MUST 返回 `true`
- **AND** `EventBus.shop_panel_opened()` MUST 仅发射一次

#### Scenario: 关闭商店面板
- **WHEN** 商店面板打开且玩家点击关闭按钮或触发 `cancel`
- **THEN** 面板 MUST 隐藏
- **AND** `is_panel_open()` MUST 返回 `false`
- **AND** `EventBus.shop_panel_closed()` MUST 仅发射一次

#### Scenario: 重复开关保持幂等
- **WHEN** 已打开面板再次调用 `open_panel()` 或已关闭面板再次调用 `close_panel()`
- **THEN** 面板状态 MUST 保持不变
- **AND** 对应 opened 或 closed 信号 MUST NOT 重复发射

### Requirement: 商店提供购买与出售双 Tab

`ShopPanel` MUST 提供购买和出售两个 Tab；购买列表 MUST 来自 `EconomyManager.get_shop_items()`，出售列表 MUST 来自 `EconomyManager.get_sellable_inventory_items()`。

#### Scenario: 默认显示购买列表
- **WHEN** 商店面板初始化或首次打开
- **THEN** 当前 Tab MUST 为购买
- **AND** 列表行 MUST 对应 `get_shop_items()` 返回的种子、消耗品和装饰商品

#### Scenario: 切换到出售列表
- **WHEN** 玩家切换到出售 Tab
- **THEN** 列表 MUST 只显示背包中数量大于 0 的可售收获物
- **AND** 同一 `item_id` 跨槽位库存 MUST 聚合为一行
- **AND** 当前选择 MUST 被清空
- **AND** 数量 MUST 重置为 `1` 或在无可售物时重置为 `0`

#### Scenario: 当前 Tab 列表为空
- **WHEN** 当前数据源没有任何可显示条目
- **THEN** 面板 MUST 显示明确的空列表提示
- **AND** 确认按钮 MUST 禁用

### Requirement: 商品行展示权威数据和安全回退

系统 MUST 提供可复用 `ShopItemRow`，展示名称、单价、拥有或库存数量、类型、选中状态和锁定状态；商品行 MUST NOT 直接执行交易。

#### Scenario: 展示购买商品
- **WHEN** 商品行接收 `get_shop_items()` 的一项数据
- **THEN** 行 MUST 显示商品名称、买入单价、已拥有数量和类型占位视觉
- **AND** 点击行 MUST 仅发射包含 `item_id` 的选择信号

#### Scenario: 展示出售物品
- **WHEN** 商品行接收 `get_sellable_inventory_items()` 的一项数据
- **THEN** 行 MUST 显示物品名称、卖出单价和聚合库存数量
- **AND** 行 MUST 使用收获物类型视觉

#### Scenario: 商品元数据缺失
- **WHEN** 商品名称、描述或类型元数据缺失
- **THEN** UI MUST 回退显示 `item_id`、未知类型样式和安全的空描述
- **AND** 面板 MUST NOT 抛出错误或停止构建其他行

### Requirement: 锁定商品可查看但不可购买

购买列表 MUST 保留未达到等级要求的种子，并以 `LevelManager` 或 `EconomyManager` 返回的解锁状态和等级为准；UI MUST NOT 自行修改解锁状态。

#### Scenario: 展示未解锁种子
- **WHEN** 种子商品的 `unlocked` 为 `false`
- **THEN** 商品行 MUST 灰显并展示 `Lv.N 解锁`
- **AND** 玩家 MUST 可以选择该行查看详情
- **AND** 数量控件和购买确认按钮 MUST 禁用

#### Scenario: 升级后解除锁定
- **WHEN** `level_up`、`crop_unlocked` 或 `unlocks_changed` 表明商品已解锁
- **THEN** 购买列表 MUST 重新查询权威数据
- **AND** 对应商品行 MUST 解除锁定状态

### Requirement: 商品详情与余额使用最新数据

选择商品后，详情区 MUST 展示名称、类型、单价、拥有或库存数量、描述、解锁信息、当前数量和总价；余额 MUST 与当前玩家金币一致。

#### Scenario: 选择可购买商品
- **WHEN** 玩家选择一个已解锁购买商品
- **THEN** 详情 MUST 使用 `EconomyManager.get_shop_item_info(item_id)` 和最新列表数据
- **AND** 总价 MUST 等于最新单价乘以当前数量
- **AND** `EventBus.shop_item_selected(item_id, info)` MUST 被发射

#### Scenario: 金币发生外部变化
- **WHEN** `EventBus.gold_changed(new_amount, delta)` 被发射
- **THEN** 余额显示 MUST 更新为 `new_amount`
- **AND** 当前商品的最大可购买数量和确认可用性 MUST 重新计算

#### Scenario: 读档后刷新
- **WHEN** `EventBus.game_loaded(slot, metadata)` 被发射
- **THEN** 当前列表、余额、选择详情和数量上限 MUST 从权威数据全量刷新

### Requirement: 数量选择自动收敛到合法上限

商店 MUST 提供 1、5、10 和最大数量选择。购买上限 MUST 同时受金币和库存可添加容量限制，出售上限 MUST 受当前聚合库存限制。

#### Scenario: 购买数量取金币和容量较小值
- **WHEN** 当前商品按金币最多可购买 8 个且库存最多可添加 3 个
- **THEN** 最大购买数量 MUST 为 3
- **AND** 选择 5、10 或最大 MUST 收敛为 3

#### Scenario: 出售数量不超过库存
- **WHEN** 当前可售物品聚合库存为 6
- **THEN** 选择 10 或最大 MUST 收敛为 6

#### Scenario: 当前无法交易任何数量
- **WHEN** 商品锁定、金币不足、库存无空间或可售库存为 0
- **THEN** 当前数量 MUST 为 0
- **AND** 确认按钮 MUST 禁用
- **AND** 面板 MUST 显示对应原因

#### Scenario: 数量变化事件
- **WHEN** 合法收敛后的数量与原数量不同
- **THEN** `EventBus.shop_quantity_changed(item_id, quantity)` MUST 被发射
- **AND** 总价和确认状态 MUST 同步刷新

### Requirement: 交易必须通过 EconomyManager 校验和提交

商店 UI MUST 使用 `can_buy_item()` / `can_sell_item()` 进行最终预校验，并仅通过 `buy_item()` / `sell_item()` 提交交易；UI MUST NOT 直接修改金币、库存、价格或经济统计。

#### Scenario: 购买成功
- **WHEN** 已选择合法商品和数量且 `EconomyManager.buy_item(item_id, quantity)` 成功
- **THEN** UI MUST 显示成功反馈
- **AND** 余额、已拥有数量、数量上限和确认状态 MUST 刷新
- **AND** UI MUST NOT 再次扣除金币或添加物品

#### Scenario: 出售成功
- **WHEN** 已选择可售物品和数量且 `EconomyManager.sell_item(item_id, quantity)` 成功
- **THEN** UI MUST 显示成功反馈
- **AND** 余额、库存数量和数量上限 MUST 刷新
- **AND** UI MUST NOT 再次移除物品、增加金币或授予经验

#### Scenario: 预校验失败
- **WHEN** `can_buy_item()` 或 `can_sell_item()` 返回失败
- **THEN** 确认按钮 MUST 禁用
- **AND** 面板 MUST 根据稳定 `error_code` 显示金币不足、空间不足、未解锁或库存不足提示
- **AND** 交易提交方法 MUST NOT 被调用

#### Scenario: 交易提交失败
- **WHEN** 交易提交返回 `success=false`
- **THEN** UI MUST 显示失败反馈
- **AND** UI MUST NOT 修改本地显示数据来模拟成功
- **AND** 余额和库存 MUST 保持权威数据状态

### Requirement: 交易与外部状态变化驱动局部刷新

商店面板 MUST 监听经济、金币、库存、解锁和读档事件；普通交易后 SHOULD 局部刷新相关行，条目集合变化或读档时 MUST 全量重建。

#### Scenario: 购买后刷新相关行
- **WHEN** `transaction_completed(result)` 表示购买成功
- **THEN** 面板 MUST 刷新对应商品的拥有数量、余额和可买性
- **AND** 不相关商品的节点 MUST NOT 因局部刷新被重复连接事件

#### Scenario: 出售后库存归零
- **WHEN** 出售成功后对应物品库存变为 0
- **THEN** 该行 MUST 从出售列表移除
- **AND** 若该行被选中，详情 MUST 清空且数量 MUST 归零

#### Scenario: 外部库存变化影响当前商品
- **WHEN** `inventory_changed(slot_index)` 改变当前商品的拥有数量、容量或可售库存
- **THEN** 面板 MUST 重新查询受影响状态
- **AND** 当前数量 MUST 收敛到新的合法上限

### Requirement: 商店打开期间阻止玩法输入但不暂停时间

商店面板打开期间系统 MUST 阻止鼠标和键盘玩法输入穿透，且默认 MUST NOT 暂停 `SceneTree` 或 `TimeManager`。

#### Scenario: 打开商店阻塞玩法
- **WHEN** 商店面板打开
- **THEN** `EventBus.ui_input_block_changed(true)` MUST 被发射
- **AND** 玩家移动、E 交互、农田点击和调试数字键 MUST 不产生玩法效果
- **AND** 全屏遮罩 MUST 消费落在商店外区域的鼠标事件

#### Scenario: 关闭商店恢复控制
- **WHEN** 商店面板关闭
- **THEN** `EventBus.ui_input_block_changed(false)` MUST 被发射
- **AND** 玩家和场景输入 MUST 恢复到商店打开前的启用状态

#### Scenario: 游戏时间继续
- **WHEN** 商店面板打开且没有其他系统暂停时间
- **THEN** `SceneTree.paused` MUST NOT 因商店而改变
- **AND** `TimeManager` MUST 继续按原状态运行

### Requirement: 商店 UI 提供独立测试场景

系统 MUST 提供可独立运行的商店 UI 测试场景，使用真实 Autoload 验证核心显示、交易和联动行为。

#### Scenario: 自动化测试场景运行
- **WHEN** `scenes/test/test_shop_panel.tscn` 运行
- **THEN** 测试 MUST 覆盖初始化、开关幂等、双 Tab、列表构建、锁定状态、详情、数量收敛、买卖成功与失败、事件刷新、读档和输入阻塞
- **AND** 测试 MUST 输出明确的通过或失败结果
