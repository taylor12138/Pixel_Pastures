## ADDED Requirements

### Requirement: 背包 UI 事件通过 EventBus 广播
`EventBus` MUST 定义背包面板状态、槽位选择、筛选、拖拽、丢弃请求和 UI 输入阻塞相关信号。

#### Scenario: 面板状态广播
- **WHEN** 背包面板从关闭变为打开或从打开变为关闭
- **THEN** EventBus MUST 分别发射 `inventory_panel_opened()` 或 `inventory_panel_closed()`

#### Scenario: 槽位选择广播
- **WHEN** 玩家选择背包槽位
- **THEN** EventBus MUST 发射 `inventory_slot_selected(slot_index: int, slot_data: Variant)`

#### Scenario: 筛选变化广播
- **WHEN** 背包分类筛选发生变化
- **THEN** EventBus MUST 发射 `inventory_filter_changed(filter_type: String)`

#### Scenario: 拖拽结果广播
- **WHEN** 一次槽位拖拽结束
- **THEN** EventBus MUST 发射 `inventory_drag_completed(from_index: int, to_index: int, success: bool)`

#### Scenario: 丢弃请求广播
- **WHEN** 玩家请求丢弃非空槽位
- **THEN** EventBus MUST 发射 `inventory_discard_requested(slot_index: int, item_id: String, quantity: int)`

#### Scenario: UI 输入阻塞广播
- **WHEN** 功能面板开始或结束阻塞玩法输入
- **THEN** EventBus MUST 发射 `ui_input_block_changed(blocked: bool)`
