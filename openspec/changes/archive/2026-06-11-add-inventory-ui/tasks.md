## 1. 输入与事件基础

- [x] 1.1 在 `project.godot` 增加 `open_bag`（Tab）和 `cancel`（Escape、鼠标右键）InputMap，并确认不复用 `ui_pause`
- [x] 1.2 在 `EventBus` 增加背包面板打开/关闭、槽位选择、筛选、拖拽、丢弃请求和 `ui_input_block_changed` 信号
- [x] 1.3 为新增 InputMap 和 EventBus 信号补充自动化断言或静态检查

## 2. InventorySlot 槽位组件

- [x] 2.1 创建 `scenes/ui/inventory/inventory_slot.tscn` 和 `scripts/ui/inventory/inventory_slot.gd`
- [x] 2.2 实现真实 `slot_index` 绑定，以及空槽、占用槽、数量和快捷栏编号显示
- [x] 2.3 实现种子、收获物、工具、消耗品、装饰和未知类型的占位视觉状态
- [x] 2.4 实现单击、双击、右键请求和悬停反馈信号
- [x] 2.5 实现 `_get_drag_data()`、拖拽预览、`_can_drop_data()` 和 `_drop_data()`
- [x] 2.6 将有效释放统一接入 `InventoryManager.smart_place()`，并处理原槽位、面板外和非法目标取消
- [x] 2.7 实现快捷栏选中、详情选中、拖拽源、可放置和不可放置视觉状态

## 3. InventoryPanel 面板主体

- [x] 3.1 创建 `scenes/ui/inventory/inventory_panel.tscn` 和 `scripts/ui/inventory/inventory_panel.gd`
- [x] 3.2 按 480×320 视口搭建全屏遮罩、420×276 主窗口、标题、筛选栏、5×4 网格、详情区和底部提示
- [x] 3.3 初始化并绑定固定 20 个 InventorySlot，确保索引始终为 0-19
- [x] 3.4 实现 `open_panel()`、`close_panel()`、`toggle_panel()` 和幂等状态事件
- [x] 3.5 实现 `refresh_slot()`、`refresh_all_slots()`、容量显示和物品元数据安全回退
- [x] 3.6 监听 `inventory_changed`、`inventory_full`、`hotbar_selected`、`item_added`、`item_removed` 和 `game_loaded`
- [x] 3.7 实现槽位单击后的名称、类型、数量、价格、描述、作物关联和堆叠详情
- [x] 3.8 实现全部、种子、收获物、工具、消耗品和装饰筛选，保持真实槽位位置与索引不变

## 4. 快捷栏与农田选择联动

- [x] 4.1 在背包中标记 slot 0-8 为快捷栏 1-9，并根据 `selected_hotbar_index` 高亮
- [x] 4.2 实现双击快捷栏槽位和详情区“选择”按钮调用 `InventoryManager.select_hotbar()`
- [x] 4.3 对 slot 9-19 的直接选择显示“请先拖到前 9 格”，且不修改选中索引
- [x] 4.4 修改 `FarmInteractionController.sync_selection_from_hotbar()`，使空槽、已移除物品和不支持物品清空旧选择
- [x] 4.5 在 hotbar 选择或选中槽位内容变化后同步 `FarmInteractionController`

## 5. 丢弃与确认流程

- [x] 5.1 在详情区增加丢弃按钮并为非空槽位构造确认文案
- [x] 5.2 使用 `ConfirmationDialog` 实现取消与确认流程
- [x] 5.3 确认后调用 `InventoryManager.discard_slot(slot_index, -1)`，刷新槽位、详情和农田选择
- [x] 5.4 确保拖到面板外不会触发丢弃或生成地面物品

## 6. 田园场景与输入阻塞

- [x] 6.1 在 `farm.tscn` 增加高于玩法层的 `UILayer` 并实例化 InventoryPanel
- [x] 6.2 在 `farm.gd` 绑定 InventoryPanel、FarmInteractionController 和 PlayerController 引用
- [x] 6.3 处理 `open_bag` / `cancel` 输入，并确保背包打开时 UI 鼠标事件不穿透到地块
- [x] 6.4 背包打开时保存并禁用玩家移动与交互状态，关闭时恢复打开前状态
- [x] 6.5 背包打开时阻止鼠标地块交互、E 交互和 PRD10 调试数字键
- [x] 6.6 验证背包打开不会设置 `get_tree().paused`，TimeManager 保持原运行状态

## 7. 自动化测试与回归

- [x] 7.1 创建 `scenes/test/test_inventory_panel.tscn` 和 `test_inventory_panel.gd`
- [x] 7.2 测试 20 格初始化、真实索引、空槽和占用槽渲染
- [x] 7.3 测试面板开关幂等、Tab/Cancel 输入和 EventBus 状态信号
- [x] 7.4 测试移动到空格、同类完全/部分合并、不同物品交换和无效拖拽
- [x] 7.5 测试分类筛选不重排索引，切回全部恢复原显示
- [x] 7.6 测试快捷栏编号、选择高亮、种子/水壶同步及空槽清除旧选择
- [x] 7.7 测试丢弃取消、确认丢弃和当前选中物被丢弃后的状态
- [x] 7.8 测试读档全量刷新、缺失元数据回退和背包满提示
- [x] 7.9 测试背包打开时角色、农田点击、E 交互和调试键均被阻止，关闭后按原状态恢复
- [x] 7.10 运行 PRD1-10 现有回归测试并修复本变更导致的失败

## 8. 手动验收与整理

- [x] 8.1 在 480×320 基础视口手测面板布局、文本可读性、拖拽反馈和确认框
- [x] 8.2 在田园场景跑通“打开背包 -> 整理种子 -> 选择快捷栏 -> 关闭背包 -> 种植/浇水”流程
- [x] 8.3 检查控制台无重复信号连接、无效节点引用和持续报错
- [x] 8.4 更新相关 README 或开发说明，记录 PRD13 接管数字键后需移除的 PRD10 调试直选逻辑
