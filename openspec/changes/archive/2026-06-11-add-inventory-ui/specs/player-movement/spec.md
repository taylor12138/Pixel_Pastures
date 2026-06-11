## ADDED Requirements

### Requirement: UI 输入阻塞期间禁止玩家移动
`PlayerController` MUST respond to the shared UI input blocking state and stop gameplay movement while a blocking functional panel is open.

#### Scenario: 背包打开停止移动
- **WHEN** `EventBus.ui_input_block_changed(true)` is emitted
- **THEN** PlayerController MUST stop current velocity
- **AND** movement input MUST NOT change player position

#### Scenario: 背包关闭恢复打开前状态
- **WHEN** UI blocking begins while player movement is enabled
- **AND** `EventBus.ui_input_block_changed(false)` is later emitted
- **THEN** PlayerController MUST restore movement enabled state

#### Scenario: 不覆盖其他系统的移动锁
- **WHEN** player movement was already disabled before UI blocking begins
- **AND** UI blocking later ends
- **THEN** PlayerController MUST remain disabled
