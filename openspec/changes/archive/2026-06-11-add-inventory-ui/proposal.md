## 为什么

PRD3 已提供完整的 20 格库存与 9 格快捷栏数据层，但玩家目前只能依赖调试逻辑操作物品，无法查看、整理或选择背包内容。现在需要补齐正式背包面板，把现有库存能力接入可玩的 UI 流程，并为后续商店、HUD 与设置界面建立统一的 Control 节点和输入阻塞模式。

## 变更内容

- 新增 5 列 × 4 行的 20 格背包面板，展示物品、数量、类型、详情与容量。
- 新增可复用的物品槽位组件，支持点击、双击、悬停、拖拽预览和目标反馈。
- 支持通过 `InventoryManager.smart_place()` 完成移动、同类合并和不同物品交换。
- 支持全部、种子、收获物、工具、消耗品和装饰分类筛选，筛选不改变真实槽位索引。
- 标记背包前 9 格为快捷栏，并同步 `selected_hotbar_index` 与农田交互选择。
- 新增整格丢弃确认流程，不生成地面掉落物。
- 新增 `open_bag` 与 `cancel` 输入，并在面板打开时阻止角色移动、农田点击、`E` 交互和调试数字键穿透。
- 新增背包面板、筛选、拖拽和 UI 输入阻塞相关 EventBus 信号。
- 补强空快捷栏同步规则：当前选中快捷栏为空或物品被移除时，必须清空旧的农田交互选择。
- 新增背包 UI 自动化测试场景，并覆盖打开关闭、渲染、筛选、拖拽、快捷栏同步、丢弃和读档刷新。

## 功能 (Capabilities)

### 新增功能

- `inventory-ui`: 定义背包面板、槽位组件、详情、筛选、拖拽、丢弃、快捷栏展示、输入阻塞和刷新行为。

### 修改功能

- `project-config`: 新增独立的 `open_bag` 和 `cancel` InputMap，避免背包开关复用保存或系统暂停输入。
- `event-bus`: 新增背包面板状态、槽位选择、筛选、拖拽、丢弃请求和 UI 输入阻塞信号。
- `inventory-hotbar`: 收紧快捷栏与农田交互同步规则，空槽位或已移除物品必须清空旧选择。
- `player-movement`: UI 输入阻塞期间禁止角色移动，并在面板关闭后恢复原控制状态。
- `farm-interaction-loop`: UI 输入阻塞期间禁止农田点击、玩家交互和调试直选输入。

## 影响

- 新增 `pixel-farm/scenes/ui/inventory/` 和 `pixel-farm/scripts/ui/inventory/` 下的面板与槽位资源。
- 修改 `pixel-farm/scenes/farm/farm.tscn`、`pixel-farm/scenes/farm/farm.gd`，挂载 `UILayer` 并接入输入阻塞。
- 修改 `pixel-farm/project.godot` 的 InputMap。
- 修改 `pixel-farm/scripts/autoload/event_bus.gd`，增加 UI 事件。
- 小幅修改 `pixel-farm/scripts/farm/farm_interaction_controller.gd`，确保空快捷栏清空选择并响应 UI 阻塞。
- 复用现有 `InventoryManager`、`DataManager` 和 `FarmInteractionController` API，不引入第三方依赖，不建立第二份快捷栏数据。
- 新增 `pixel-farm/scenes/test/test_inventory_panel.tscn` 与对应测试脚本。
