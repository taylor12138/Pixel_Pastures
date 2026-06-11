## ADDED Requirements

### Requirement: UI 输入阻塞期间禁止农田交互
田园场景和 `FarmInteractionController` MUST 尊重共享 UI 输入阻塞状态，禁止面板操作穿透为农田点击、玩家交互或调试选择。

#### Scenario: 背包打开时点击农田
- **WHEN** `ui_input_block_changed(true)` 后背包面板可见
- **AND** 玩家在农田区域按下鼠标左键
- **THEN** 田园场景 MUST NOT 请求地块交互
- **AND** 作物、地块和库存状态 MUST 保持不变

#### Scenario: 背包打开时按 E
- **WHEN** UI 输入被阻塞
- **AND** 玩家触发 `interact`
- **THEN** `farm_tile_interaction_requested` MUST NOT 因该输入被发射

#### Scenario: 背包打开时调试数字键不生效
- **WHEN** UI 输入被阻塞
- **AND** 玩家按下 PRD10 调试直选或时间推进按键
- **THEN** `FarmInteractionController.handle_debug_key_event()` MUST NOT 改变模式或作物状态

#### Scenario: 背包关闭后恢复交互
- **WHEN** `ui_input_block_changed(false)` 被发射
- **AND** 没有其他系统禁止交互
- **THEN** 鼠标地块交互和玩家 E 键交互 MUST 恢复
