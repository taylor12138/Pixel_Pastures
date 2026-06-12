## 1. 事件与场景基础

- [x] 1.1 在 `pixel-farm/scripts/autoload/event_bus.gd` 增加 `shop_panel_opened`、`shop_panel_closed`、`shop_tab_changed`、`shop_item_selected` 和 `shop_quantity_changed` 信号
- [x] 1.2 确认现有 `cancel` InputMap 可由 Escape 与鼠标右键触发，并补充缺失的静态或自动化断言
- [x] 1.3 创建 `pixel-farm/scenes/ui/shop/` 和 `pixel-farm/scripts/ui/shop/` 目录结构，并确定商店场景资源路径

## 2. ShopItemRow 商品行组件

- [x] 2.1 创建 `shop_item_row.tscn` 和 `shop_item_row.gd`，搭建类型占位、名称、价格、拥有/库存和锁定提示节点
- [x] 2.2 实现 `BUY` / `SELL` 模式以及 `set_buy_data()`、`set_sell_data()` 数据填充接口
- [x] 2.3 实现普通、选中、锁定、买不起、空间不足和未知类型的占位视觉状态
- [x] 2.4 实现 `row_clicked(item_id)` 信号，确保行组件只上报选择而不调用交易接口
- [x] 2.5 实现元数据缺失、字段缺失和非法价格的安全回退

## 3. ShopPanel 布局与基础状态

- [x] 3.1 创建 `shop_panel.tscn` 和 `shop_panel.gd`，按 480×320 视口搭建全屏遮罩、440×288 主窗口、标题、余额、双 Tab、滚动列表、详情区和底部提示
- [x] 3.2 实现 `setup()`、`open_panel()`、`close_panel()`、`toggle_panel()` 和 `is_panel_open()`，保证初始关闭与重复调用幂等
- [x] 3.3 连接关闭、取消、Tab、数量预设、最大数量和确认按钮，确保信号只在 `_ready()` 注册一次
- [x] 3.4 实现 `set_tab()`、`rebuild_list()`、空列表提示和动态商品行的创建/销毁
- [x] 3.5 实现 `select_item()`、`clear_selection()`、行选中高亮与 `shop_item_selected` 广播

## 4. 购买与出售列表

- [x] 4.1 使用 `EconomyManager.get_shop_items()` 构建购买列表，展示种子、消耗品和装饰
- [x] 4.2 使用 `EconomyManager.get_sellable_inventory_items()` 构建出售列表，并过滤数量为 0 的条目
- [x] 4.3 使用 `get_shop_item_info()`、列表数据和物品元数据填充名称、类型、单价、拥有/库存、描述与解锁详情
- [x] 4.4 对锁定种子显示 `Lv.N 解锁`，允许查看详情但禁用数量与购买
- [x] 4.5 实现 `refresh_item_row(item_id)`，并在条目消失时清空失效选择

## 5. 数量、总价与预校验

- [x] 5.1 实现购买最大值计算：取金币可购买数量与 `InventoryManager.get_addable_count(item_id)` 的较小值
- [x] 5.2 实现出售最大值计算：读取当前可售物品的聚合库存数量
- [x] 5.3 实现 `set_quantity()` 和 `set_quantity_max()`，使 1/5/10/最大数量自动收敛到合法范围
- [x] 5.4 在数量变化后刷新总价并发射 `shop_quantity_changed(item_id, quantity)`
- [x] 5.5 使用 `can_buy_item()` / `can_sell_item()` 控制确认按钮，并将 `error_code` 映射为金币不足、空间不足、未解锁、库存不足等提示
- [x] 5.6 处理单价无效、最大值为 0、外部金币变化和库存变化后的数量重新收敛

## 6. 交易提交与事件刷新

- [x] 6.1 实现 `confirm_transaction()`，按当前 Tab 调用 `EconomyManager.buy_item()` 或 `sell_item()`
- [x] 6.2 统一处理成功与失败结果字典，显示反馈且禁止 UI 二次修改金币、库存或经验
- [x] 6.3 监听 `transaction_completed`、`transaction_failed` 和 `gold_changed`，刷新余额、相关行、数量上限和可交易性
- [x] 6.4 监听 `inventory_changed`，更新当前商品拥有数量、购买容量和出售聚合库存
- [x] 6.5 在出售库存归零后移除对应行、清空详情并显示空列表状态
- [x] 6.6 监听 `level_up`、`crop_unlocked` 和 `unlocks_changed`，重新查询并刷新购买列表锁定状态
- [x] 6.7 监听 `game_loaded`，全量重建列表、余额、详情和数量状态
- [x] 6.8 验证同步返回值与 EventBus 连续回调不会重复反馈或重复连接节点信号

## 7. 场景挂载与输入阻塞

- [x] 7.1 在 `pixel-farm/scenes/shop/shop.tscn` 创建占位商店场景，挂载高层 `CanvasLayer` 与 `ShopPanel`
- [x] 7.2 在现有田园场景增加可移除的商店临时入口，或通过占位按钮/调试入口打开同一 `ShopPanel`
- [x] 7.3 打开商店时发射 `ui_input_block_changed(true)`，阻止玩家移动、E 交互、农田点击和调试数字键
- [x] 7.4 关闭商店时发射 `ui_input_block_changed(false)`，并恢复打开前的玩家与场景输入状态
- [x] 7.5 配置全屏遮罩消费鼠标事件，验证点击商店窗口外不会穿透到玩法场景
- [x] 7.6 验证商店打开不会修改 `SceneTree.paused` 或 `TimeManager` 原运行状态

## 8. 自动化测试

- [x] 8.1 创建 `pixel-farm/scenes/test/test_shop_panel.tscn` 和 `test_shop_panel.gd`，使用真实 Autoload 和明确的通过/失败输出
- [x] 8.2 测试默认购买 Tab、余额同步、开关幂等和商店状态信号
- [x] 8.3 测试购买列表、出售聚合列表、Tab 切换、空列表和元数据缺失回退
- [x] 8.4 测试锁定种子显示、选择详情、解锁事件刷新和选择事件安全副本
- [x] 8.5 测试 1/5/10/最大数量、金币上限、容量上限、库存上限、数量事件和总价
- [x] 8.6 测试购买成功、金币不足、空间不足、锁定拒绝以及失败时数据不变
- [x] 8.7 测试出售成功、库存不足、库存归零移除行、金币与经验结果以及失败时数据不变
- [x] 8.8 测试 `gold_changed`、`inventory_changed`、升级解锁和 `game_loaded` 后的刷新行为
- [x] 8.9 测试商店打开时玩法输入被阻止、鼠标不穿透、时间继续和关闭后按原状态恢复
- [x] 8.10 将商店 UI 测试接入 `test_regression_runner`，运行 PRD1-11 现有回归并修复本变更导致的失败

## 9. 手动验收与整理

- [x] 9.1 在 480×320 基础视口手测列表滚动、详情文本、锁定/选中/禁用状态和中英文可读性
- [x] 9.2 跑通“打开商店 -> 购买种子 -> 切换出售 -> 卖出收获物 -> 关闭并恢复玩法输入”的完整流程
- [x] 9.3 手测金币不足、背包满、数量超限、库存归零、升级解锁和读档刷新边界
- [x] 9.4 检查控制台无重复信号连接、无效节点引用、持续报错和输入穿透
- [x] 9.5 更新 `pixel-farm/README.md` 或相关开发说明，记录商店测试入口与 PRD17 正式场景接入点
