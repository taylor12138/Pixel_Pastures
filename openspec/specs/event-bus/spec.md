# event-bus Specification

## Purpose
This specification defines the event-bus capability.
## Requirements
### Requirement: Crop lifecycle signals
EventBus SHALL define signals for the complete crop lifecycle: planted, watered, grown, matured, harvested, withered, and cleared.

#### Scenario: Crop planted signal emitted
- **WHEN** a crop is planted at a tile position
- **THEN** EventBus SHALL emit `crop_planted(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop watered signal emitted
- **WHEN** a crop is watered
- **THEN** EventBus SHALL emit `crop_watered(tile_pos: Vector2i)`

#### Scenario: Crop growth stage signal emitted
- **WHEN** a crop advances to a new growth stage
- **THEN** EventBus SHALL emit `crop_grown(tile_pos: Vector2i, new_stage: int)`

#### Scenario: Crop matured signal emitted
- **WHEN** a crop reaches the mature (harvestable) stage
- **THEN** EventBus SHALL emit `crop_matured(tile_pos: Vector2i, crop_id: String)`

#### Scenario: Crop harvested signal emitted
- **WHEN** a mature crop is harvested by the player
- **THEN** EventBus SHALL emit `crop_harvested(tile_pos: Vector2i, crop_id: String, amount: int)`

#### Scenario: Crop withered signal emitted
- **WHEN** a mature crop withers due to not being harvested before midnight
- **THEN** EventBus SHALL emit `crop_withered(tile_pos: Vector2i)`

#### Scenario: Crop cleared signal emitted
- **WHEN** a withered crop is cleared from the tile
- **THEN** EventBus SHALL emit `crop_cleared(tile_pos: Vector2i)`

### Requirement: Economy signals
EventBus SHALL define signals for gold changes, purchases, and sales.

#### Scenario: Gold changed signal emitted
- **WHEN** the player's gold amount changes (increase or decrease)
- **THEN** EventBus SHALL emit `gold_changed(new_amount: int, delta: int)`

#### Scenario: Item purchased signal emitted
- **WHEN** the player buys an item from the shop
- **THEN** EventBus SHALL emit `item_purchased(item_id: String, price: int)`

#### Scenario: Item sold signal emitted
- **WHEN** the player sells an item
- **THEN** EventBus SHALL emit `item_sold(item_id: String, price: int)`

### Requirement: Inventory signals
EventBus SHALL define signals for inventory state changes.

#### Scenario: Inventory changed signal emitted
- **WHEN** an inventory slot's content changes (add/remove/swap)
- **THEN** EventBus SHALL emit `inventory_changed(slot_index: int)`

#### Scenario: Inventory full signal emitted
- **WHEN** an item cannot be added because all 20 inventory slots are occupied
- **THEN** EventBus SHALL emit `inventory_full()`

### Requirement: Level and XP signals
EventBus SHALL define signals for experience gain and level progression while preserving PRD5-compatible signatures.

#### Scenario: XP gained signal emitted
- **WHEN** `LevelManager.add_xp(amount, source)` successfully adds experience points
- **THEN** EventBus SHALL emit `xp_gained(amount: int, source: String)`
- **AND** the signal SHALL NOT be emitted for failed XP operations

#### Scenario: Level up signal emitted
- **WHEN** the player's XP reaches the threshold for the next level and `LevelManager.check_level_up()` raises the level
- **THEN** EventBus SHALL emit `level_up(new_level: int)` once for each level gained
- **AND** a multi-level upgrade SHALL emit one `level_up` signal per gained level in ascending order

### Requirement: Time system signals
EventBus SHALL define signals for game time progression and time-control state, including minute changes, hour changes, game-day starts, season changes, year changes, day-phase changes, midnight crossing, time-scale changes, and time-paused changes.

#### Scenario: Minute changed signal emitted
- **WHEN** the in-game minute advances
- **THEN** EventBus SHALL emit `minute_changed(hour: int, minute: int)`

#### Scenario: Hour changed signal emitted
- **WHEN** the in-game hour advances
- **THEN** EventBus SHALL emit `hour_changed(new_hour: int)`

#### Scenario: Day started signal emitted
- **WHEN** a new in-game day begins
- **THEN** EventBus SHALL emit `day_started(year: int, season: String, day: int)`

#### Scenario: Season changed signal emitted
- **WHEN** the in-game season transitions
- **THEN** EventBus SHALL emit `season_changed(new_season: String)`

#### Scenario: Year changed signal emitted
- **WHEN** the in-game year advances after winter ends
- **THEN** EventBus SHALL emit `year_changed(new_year: int)`

#### Scenario: Midnight crossed signal emitted
- **WHEN** the in-game clock advances from 23:59 to 00:00
- **THEN** EventBus SHALL emit `midnight_crossed()` for wither detection

#### Scenario: Day phase changed signal emitted
- **WHEN** the calculated day phase changes between `morning`, `afternoon`, `evening`, and `night`
- **THEN** EventBus SHALL emit `day_phase_changed(new_phase: String)`

#### Scenario: Time scale changed signal emitted
- **WHEN** `TimeManager.set_time_scale(scale)` accepts a new legal time scale
- **THEN** EventBus SHALL emit `time_scale_changed(new_scale: float)`

#### Scenario: Time paused changed signal emitted
- **WHEN** `TimeManager.set_time_paused(value)` changes the paused state
- **THEN** EventBus SHALL emit `time_paused_changed(paused: bool)`

### Requirement: Interaction signals
EventBus SHALL define signals for generic interaction start and end, and MUST also define player-driven interaction request signals for PRD9 player movement and farm-tile interaction flow.

#### Scenario: Interaction started
- **WHEN** the player begins interacting with a game object
- **THEN** EventBus SHALL emit `interaction_started(target: Node)`

#### Scenario: Interaction ended
- **WHEN** the player finishes or cancels an interaction
- **THEN** EventBus SHALL emit `interaction_ended()`

#### Scenario: Player spawned signal emitted
- **WHEN** `PlayerController` initializes or resets the player spawn position
- **THEN** EventBus SHALL emit `player_spawned(world_pos: Vector2, grid_pos: Vector2i)`

#### Scenario: Player moved signal emitted
- **WHEN** `PlayerController` detects an effective player world position or grid position change
- **THEN** EventBus SHALL emit `player_moved(world_pos: Vector2, grid_pos: Vector2i)`

#### Scenario: Player direction changed signal emitted
- **WHEN** `PlayerController` changes the player's facing direction
- **THEN** EventBus SHALL emit `player_direction_changed(direction: String, direction_vector: Vector2i)`
- **AND** `direction` SHALL be one of `down`, `up`, `left`, or `right`

#### Scenario: Player movement enabled changed signal emitted
- **WHEN** `PlayerController.set_can_move(value)` changes movement enabled state
- **THEN** EventBus SHALL emit `player_movement_enabled_changed(enabled: bool)`

#### Scenario: Player interaction target changed signal emitted
- **WHEN** `PlayerController` changes the current interaction target
- **THEN** EventBus SHALL emit `player_interaction_target_changed(target: Dictionary)`
- **AND** `target` SHALL be an empty Dictionary when no target is available

#### Scenario: Player interacted signal emitted
- **WHEN** `PlayerController.try_interact()` succeeds with any interaction target
- **THEN** EventBus SHALL emit `player_interacted(target: Dictionary)`

#### Scenario: Player interaction failed signal emitted
- **WHEN** `PlayerController.try_interact()` fails because interaction is disabled or no target exists
- **THEN** EventBus SHALL emit `player_interaction_failed(reason: String)`
- **AND** `reason` SHALL be a stable non-empty error code such as `interaction_disabled` or `no_target`

#### Scenario: Farm tile interaction request signal emitted
- **WHEN** `PlayerController.try_interact()` succeeds and the target type is `farm_tile`
- **THEN** EventBus SHALL emit `farm_tile_interaction_requested(tile_pos: Vector2i, target: Dictionary)`
- **AND** this signal SHALL represent that the player requested a farm-tile interaction, not that planting, watering, harvesting, or clearing has completed

### Requirement: Save/Load signals
EventBus SHALL define typed signals for save, load, delete, and auto-save operations.

#### Scenario: Game saved signal emitted
- **WHEN** the game is successfully saved to a slot
- **THEN** EventBus SHALL emit `game_saved(slot: int, metadata: Dictionary)`

#### Scenario: Game loaded signal emitted
- **WHEN** a save file is successfully loaded from a slot
- **THEN** EventBus SHALL emit `game_loaded(slot: int, metadata: Dictionary)`

#### Scenario: Game save failed signal emitted
- **WHEN** a manual save operation fails
- **THEN** EventBus SHALL emit `game_save_failed(slot: int, error_code: String, message: String)`
- **AND** `error_code` SHALL be a stable non-empty error code

#### Scenario: Game load failed signal emitted
- **WHEN** a load operation fails
- **THEN** EventBus SHALL emit `game_load_failed(slot: int, error_code: String, message: String)`
- **AND** `error_code` SHALL be a stable non-empty error code

#### Scenario: Save deleted signal emitted
- **WHEN** a save slot delete operation succeeds
- **THEN** EventBus SHALL emit `save_deleted(slot: int)`

#### Scenario: Auto-save result signal emitted
- **WHEN** an auto-save operation succeeds
- **THEN** EventBus SHALL emit `auto_save_completed(result: Dictionary)`
- **WHEN** an auto-save operation fails
- **THEN** EventBus SHALL emit `auto_save_failed(result: Dictionary)`

### Requirement: Signal naming convention
All EventBus signals SHALL use past tense naming (e.g., `crop_planted` not `plant_crop`) to indicate events that have already occurred.

#### Scenario: All signals follow past tense convention
- **WHEN** the EventBus script is inspected
- **THEN** every signal name SHALL be in past tense or passive form (e.g., `_planted`, `_changed`, `_gained`, `_crossed`)

---

<!-- Synced from prd3-inventory-system -->

### Requirement: Inventory and hotbar events are broadcast through EventBus

`EventBus` SHALL define typed signals for inventory slot changes, inventory full state, hotbar selection, item addition, and item removal.

#### Scenario: Inventory slot changes are broadcast
- **WHEN** an inventory operation changes a slot
- **THEN** `EventBus.inventory_changed(slot_index: int)` is emitted with the changed slot index

#### Scenario: Inventory full is broadcast
- **WHEN** `InventoryManager.add_item()` cannot add the full requested quantity because capacity is exhausted
- **THEN** `EventBus.inventory_full()` is emitted

#### Scenario: Hotbar selection is broadcast
- **WHEN** `InventoryManager.select_hotbar(index)` successfully changes the selected hotbar index
- **THEN** `EventBus.hotbar_selected(index: int)` is emitted

#### Scenario: Item addition is broadcast
- **WHEN** `InventoryManager.add_item()` adds one or more items to a slot
- **THEN** `EventBus.item_added(item_id: String, quantity: int, slot_index: int)` is emitted
- **AND** `quantity` is the amount added to that slot

#### Scenario: Item removal is broadcast
- **WHEN** `InventoryManager.remove_item()`, `remove_from_slot()`, `discard_slot()`, or `use_selected_item()` removes one or more items
- **THEN** `EventBus.item_removed(item_id: String, quantity: int)` is emitted
- **AND** `quantity` is the actual removed quantity

### Requirement: EventBus remains the cross-system communication boundary

Inventory-related UI, HUD, economy, and achievement systems SHALL observe inventory state changes through `EventBus` instead of directly patching inventory internals.

#### Scenario: Future UI updates inventory display
- **WHEN** inventory data changes
- **THEN** future UI systems can refresh affected slots by listening to `inventory_changed(slot_index)`
- **AND** they do not need to own or mutate `InventoryManager._slots`

### Requirement: Economy transaction events are broadcast through EventBus

`EventBus` SHALL define typed signals for completed and failed economy transactions so UI, HUD, achievement, logging, and tests can observe transaction outcomes without coupling to `EconomyManager` internals.

#### Scenario: Successful transaction is broadcast
- **WHEN** `EconomyManager.buy_item()`, `EconomyManager.buy_seed()`, `EconomyManager.sell_item()`, or `EconomyManager.sell_harvest()` completes successfully
- **THEN** `EventBus.transaction_completed(result: Dictionary)` is emitted
- **AND** `result.success` is `true`
- **AND** the signal is emitted only after gold, inventory, and economy stats have been updated

#### Scenario: Failed transaction is broadcast
- **WHEN** an economy transaction fails validation or fails after rollback
- **THEN** `EventBus.transaction_failed(result: Dictionary)` is emitted
- **AND** `result.success` is `false`
- **AND** `result.error_code` contains a stable non-empty error code
- **AND** no successful transaction signal is emitted for the same failed transaction

#### Scenario: Purchase-specific signal remains success-only
- **WHEN** a purchase succeeds
- **THEN** `EventBus.item_purchased(item_id: String, price: int)` is emitted
- **AND** `EventBus.transaction_completed(result: Dictionary)` is emitted
- **WHEN** a purchase fails
- **THEN** `EventBus.item_purchased` is not emitted
- **AND** `EventBus.transaction_failed(result: Dictionary)` is emitted

#### Scenario: Sale-specific signal remains success-only
- **WHEN** a sale succeeds
- **THEN** `EventBus.item_sold(item_id: String, price: int)` is emitted
- **AND** `EventBus.transaction_completed(result: Dictionary)` is emitted
- **WHEN** a sale fails
- **THEN** `EventBus.item_sold` is not emitted
- **AND** `EventBus.transaction_failed(result: Dictionary)` is emitted

### Requirement: EventBus remains the economy UI communication boundary

Economy UI, HUD, notifications, and future analytics systems SHALL observe economy outcomes through `EventBus` rather than mutating `EconomyManager`, `GameManager`, or `InventoryManager` internals.

#### Scenario: Future shop UI displays a failed purchase
- **WHEN** `EconomyManager.buy_item()` returns a failed transaction
- **THEN** future UI systems can display the failure by listening to `transaction_failed(result)`
- **AND** they do not need to parse console logs or inspect private manager state

### Requirement: Level unlock signals are broadcast through EventBus
`EventBus` SHALL define typed signals for level-system unlock changes: `unlocks_changed(unlocks: Dictionary)`, `crop_unlocked(crop_id: String, level: int)`, `feature_unlocked(feature_id: String, level: int)`, and `farm_slots_changed(new_slots: int)`.

#### Scenario: Unlocks changed signal is emitted for upgrade unlocks
- **WHEN** `LevelManager.add_xp()` causes one or more level-ups with unlocked content
- **THEN** `EventBus.unlocks_changed(unlocks: Dictionary)` SHALL be emitted once with the merged unlocks for that XP operation

#### Scenario: Crop unlock signals are emitted per crop
- **WHEN** a level-up unlocks one or more crops
- **THEN** `EventBus.crop_unlocked(crop_id: String, level: int)` SHALL be emitted once for each newly unlocked crop

#### Scenario: Feature unlock signals are emitted per feature
- **WHEN** a level-up unlocks one or more features
- **THEN** `EventBus.feature_unlocked(feature_id: String, level: int)` SHALL be emitted once for each newly unlocked feature

#### Scenario: Farm slot change is emitted when capacity increases
- **WHEN** a level-up increases the unlocked farm-slot capacity
- **THEN** `EventBus.farm_slots_changed(new_slots: int)` SHALL be emitted with the new capacity

---

<!-- Synced from prd8-farm-grid-system -->

### Requirement: Farm grid signals
EventBus SHALL 定义田园网格与地块状态相关的类型化信号，使场景、UI、测试和后续交互系统能够通过事件观察地块变化，而不是直接依赖 FarmGridManager 内部数据。

#### 场景:田园网格初始化信号
- **WHEN** FarmGridManager 完成 30×20 网格初始化
- **THEN** EventBus SHALL emit `farm_grid_initialized(width: int, height: int)`
- **AND** `width` SHALL be `30`
- **AND** `height` SHALL be `20`

#### 场景:田园地块悬停信号
- **WHEN** 鼠标悬停地块发生变化且新地块位于地图范围内
- **THEN** EventBus SHALL emit `farm_tile_hovered(tile_pos: Vector2i, tile_data: Dictionary)`
- **AND** `tile_data` SHALL describe the hovered tile

#### 场景:田园地块选中信号
- **WHEN** 玩家或调试交互选中地图范围内地块
- **THEN** EventBus SHALL emit `farm_tile_selected(tile_pos: Vector2i, tile_data: Dictionary)`
- **AND** 地图外点击 SHALL NOT emit `farm_tile_selected`

#### 场景:田园地块状态变化信号
- **WHEN** FarmGridManager changes a tile `plot_state` from one value to another
- **THEN** EventBus SHALL emit `farm_tile_state_changed(tile_pos: Vector2i, old_state: String, new_state: String)`
- **AND** the signal SHALL NOT be emitted when the requested state equals the current state

#### 场景:田园地块解锁信号
- **WHEN** a farm plot changes from locked to unlocked
- **THEN** EventBus SHALL emit `farm_tile_unlocked(tile_pos: Vector2i)` once for that tile

#### 场景:田园地块占用变化信号
- **WHEN** FarmGridManager changes a tile occupied flag
- **THEN** EventBus SHALL emit `farm_tile_occupied_changed(tile_pos: Vector2i, occupied: bool)`
- **AND** `occupied` SHALL match the tile's new occupied state

#### 场景:田园网格整体变化信号
- **WHEN** an operation changes grid-wide state such as initialization, import, reset, bulk unlock, or a tile mutation that affects rendered grid state
- **THEN** EventBus SHALL emit `farm_grid_changed()`

### Requirement: Farm grid signals do not replace crop lifecycle signals
田园网格事件 SHALL 只描述场景网格、地块状态、解锁和占用变化，禁止替代或移除既有作物生命周期信号。

#### 场景:作物信号保持可用
- **WHEN** PRD8 farm grid signals are added
- **THEN** EventBus SHALL still define crop lifecycle signals including `crop_planted`, `crop_watered`, `crop_harvested`, and `crop_cleared`
- **AND** farm grid signals SHALL NOT change those existing crop signal signatures

#### 场景:后续种植交互可以同时广播作物和地块事件
- **WHEN** a future planting, watering, harvesting, or clearing interaction changes both crop state and tile state
- **THEN** crop lifecycle signals SHALL remain responsible for crop behavior
- **AND** farm grid signals SHALL remain responsible for tile state, unlock, occupancy, and grid rendering behavior

### Requirement: Player interaction signals do not replace crop lifecycle signals
玩家交互请求信号 SHALL 只表达玩家发起交互的事实，禁止替代或移除既有作物生命周期信号和田园网格状态变化信号。

#### 场景:作物生命周期信号保持独立
- **WHEN** `farm_tile_interaction_requested` is emitted for a farm tile
- **THEN** EventBus SHALL NOT imply that `crop_planted`, `crop_watered`, `crop_harvested`, or `crop_cleared` has occurred
- **AND** crop lifecycle signals SHALL remain emitted only by the systems that actually complete those crop operations

#### 场景:地块状态变化信号保持独立
- **WHEN** `player_interacted` or `farm_tile_interaction_requested` is emitted
- **THEN** EventBus SHALL NOT imply that `farm_tile_state_changed` has occurred
- **AND** farm grid mutation signals SHALL remain emitted only when FarmGridManager or an equivalent owner changes tile state

### Requirement: Farm interaction result signals
EventBus MUST define PRD10 farm interaction signals for mode changes, completed actions, failed actions, and action preview changes.

#### Scenario: Farm interaction mode changed signal emitted
- **WHEN** `FarmInteractionController` changes the current interaction mode or selected item
- **THEN** EventBus MUST emit `farm_interaction_mode_changed(mode: String, selected_item_id: String, selected_crop_id: String)`
- **AND** `mode` MUST be a stable mode name such as `NONE`, `PLANT`, `WATER`, `HARVEST`, or `CLEAR`

#### Scenario: Farm interaction completed signal emitted
- **WHEN** `FarmInteractionController` successfully plants, waters, harvests, or clears a farm tile
- **THEN** EventBus MUST emit `farm_interaction_completed(result: Dictionary)`
- **AND** `result.success` MUST be `true`

#### Scenario: Farm interaction failed signal emitted
- **WHEN** `FarmInteractionController` rejects a farm-tile request or a business operation fails
- **THEN** EventBus MUST emit `farm_interaction_failed(result: Dictionary)`
- **AND** `result.success` MUST be `false`
- **AND** `result.reason` MUST be a stable non-empty error code

#### Scenario: Farm tile action preview changed signal emitted
- **WHEN** the hovered or targeted farm tile changes and the controller can infer a preview action or reason
- **THEN** EventBus MUST be able to emit `farm_tile_action_preview_changed(tile_pos: Vector2i, action: String, reason: String)`

### Requirement: Farm request and result event semantics remain distinct
EventBus MUST keep player farm-tile requests distinct from completed PRD10 farm business actions.

#### Scenario: Farm tile request does not mean business completion
- **WHEN** `farm_tile_interaction_requested(tile_pos, target)` is emitted by `PlayerController`
- **THEN** listeners MUST treat it only as an interaction request
- **AND** planting, watering, harvesting, or clearing completion MUST only be represented by crop lifecycle signals and `farm_interaction_completed(result)`

#### Scenario: Farm interaction failure does not replace player interaction failure
- **WHEN** `PlayerController.try_interact()` cannot produce a target
- **THEN** `player_interaction_failed(reason)` MUST remain the event for player-side failure
- **WHEN** `FarmInteractionController` receives a target but rejects the business action
- **THEN** `farm_interaction_failed(result)` MUST be the event for business-side failure

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
