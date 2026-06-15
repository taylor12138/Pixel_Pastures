## 1. HUD 场景骨架与输入配置

- [x] 1.1 创建 `pixel-farm/scenes/ui/hud/` 和 `pixel-farm/scripts/ui/hud/` 目录，并建立 `hud.tscn`、`hotbar.tscn`、`hotbar_slot.tscn` 及对应脚本骨架
- [x] 1.2 在 `pixel-farm/project.godot` 中添加使用物理数字键的 `hotbar_1` 至 `hotbar_9` InputMap Action，并验证 9 个 Action 均可被 Godot 识别
- [x] 1.3 在 `hud.tscn` 中完成 480×320 锚点布局，包含顶部时间面板、金币等级面板、中下方交互提示和底部快捷栏挂载点
- [x] 1.4 配置 HUD 根节点不拦截空白区域鼠标事件，并为快捷栏槽位保留可点击输入

## 2. 快捷栏槽位组件

- [x] 2.1 实现 `hotbar_slot.gd` 的 `set_slot_data()`、`set_selected()`、`set_hotkey_number()` 和 `slot_clicked(slot_index)` 接口
- [x] 2.2 实现空槽、数量大于 1、数量等于 1、不同物品类型和选中高亮的占位视觉
- [x] 2.3 使用 `DataManager.get_item(item_id)` 读取元数据，并为缺失元数据提供 `item_id` 文本和灰色未知类型回退
- [x] 2.4 验证单个 `HotbarSlot` 点击只发射索引信号，不直接修改 `InventoryManager`

## 3. 快捷栏集合与选择

- [x] 3.1 实现 `hotbar.gd` 收集固定 9 个槽位，并通过 `InventoryManager.get_hotbar_slots()` 完成 `refresh_all()` 和 `refresh_slot(index)`
- [x] 3.2 实现 `refresh_selection()`，以 `InventoryManager.get_selected_hotbar()` 为唯一选中来源并保证仅一个槽位高亮
- [x] 3.3 实现数字 Action 与槽位点击共用的 `select_slot(index)`，统一调用 `InventoryManager.select_hotbar(index)`
- [x] 3.4 监听 `inventory_changed`、`item_added`、`item_removed`、`hotbar_selected` 和 `game_loaded`，对可定位变化局部刷新，对无法定位的移除变化执行保守同步
- [x] 3.5 监听 `ui_input_block_changed` 实现热键启停，并验证阻塞期间数字键不改变选中索引、解除后恢复

## 4. HUD 数据展示与事件联动

- [x] 4.1 实现 `hud.gd` 的 `setup()`、`refresh_all()`、`refresh_time()`、`refresh_gold()`、`refresh_level()`、`refresh_hotbar()`、`set_interaction_prompt()` 和 `set_hud_visible()`
- [x] 4.2 连接时间相关信号，使用 `TimeManager` 公开接口展示时钟、日期、季节及早晨/下午/傍晚/夜晚中文阶段
- [x] 4.3 连接 `gold_changed`，展示 `GameManager.gold` 并验证 0 和百万级数值不会破坏顶部布局
- [x] 4.4 连接 `xp_gained` 与 `level_up`，使用 `LevelManager.get_xp_progress()` 展示等级、经验数值、进度条和满级 `MAX` 状态
- [x] 4.5 连接玩家目标与农田动作预览信号，将 `plant`、`water`、`harvest`、`clear` 映射为交互提示，并在无目标、`none`、未知动作或不可执行原因时隐藏
- [x] 4.6 为所有 EventBus 连接添加幂等检查，并验证 HUD 脚本不通过 `_process()` 轮询权威数据

## 5. 田园场景集成

- [x] 5.1 在 `pixel-farm/scenes/farm/farm.tscn` 的 `UILayer` 中实例化 HUD，并保证其绘制顺序低于 `InventoryPanel` 和 `ShopPanel`
- [x] 5.2 在 `farm.gd` 中按需获取 HUD 引用并调用 `setup()`，保持 HUD 初始化不修改暂停、时间或玩家控制状态
- [x] 5.3 验证田园空白区域点击仍可选择地块，快捷栏槽位可点击，背包和商店遮罩可覆盖并阻止对 HUD 的鼠标穿透
- [x] 5.4 验证选择快捷栏后现有农田交互选择同步链路仍使用 `InventoryManager` 权威状态且无调试数字键冲突

## 6. 自动化测试与回归

- [x] 6.1 创建 `pixel-farm/scenes/test/test_hud.tscn` 和 `test_hud.gd`，使用真实 Autoload 并公开 `_passed`、`_failed` 结果
- [x] 6.2 添加初始化、时间日期季节阶段、金币、等级经验和满级显示测试
- [x] 6.3 添加快捷栏填充、数量显示、空槽、缺失元数据、选中高亮、数字键选择和点击选择测试
- [x] 6.4 添加输入阻塞、交互提示显示隐藏、单槽局部刷新、读档全量刷新和重复信号连接测试
- [x] 6.5 将 HUD 测试场景加入 `test_regression_runner.gd`，运行 HUD 独立测试和完整核心回归并修复所有失败
- [x] 6.6 按 PRD13 手测清单验证田园场景中的时间推进、交易、升级、背包变化、快捷栏输入、模态共存、交互提示和读档同步
