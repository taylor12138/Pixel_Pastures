## ADDED Requirements

### Requirement: 商店 UI 状态通过 EventBus 广播

`EventBus` MUST 定义商店面板打开、关闭和 Tab 切换信号，使宿主场景、音频、HUD、测试和未来 UI 管理器无需依赖 `ShopPanel` 内部实现即可观察商店状态。

#### Scenario: 商店面板打开事件
- **WHEN** `ShopPanel` 状态从关闭变为打开
- **THEN** `EventBus.shop_panel_opened()` MUST 被发射一次

#### Scenario: 商店面板关闭事件
- **WHEN** `ShopPanel` 状态从打开变为关闭
- **THEN** `EventBus.shop_panel_closed()` MUST 被发射一次

#### Scenario: 商店 Tab 切换事件
- **WHEN** 当前商店 Tab 在购买与出售之间发生变化
- **THEN** `EventBus.shop_tab_changed(tab: String)` MUST 被发射
- **AND** `tab` MUST 为 `"buy"` 或 `"sell"`

### Requirement: 商店选择和数量变化通过 EventBus 广播

`EventBus` MUST 定义商品选择与数量变化信号，且传递给观察者的数据 MUST 不允许观察者修改商店内部权威状态。

#### Scenario: 商品选择事件
- **WHEN** 玩家选择一个购买或出售条目
- **THEN** `EventBus.shop_item_selected(item_id: String, info: Dictionary)` MUST 被发射
- **AND** `info` MUST 为安全副本或空字典

#### Scenario: 数量变化事件
- **WHEN** 当前选中商品的合法交易数量发生变化
- **THEN** `EventBus.shop_quantity_changed(item_id: String, quantity: int)` MUST 被发射
- **AND** `quantity` MUST 为经过上限收敛后的非负整数
