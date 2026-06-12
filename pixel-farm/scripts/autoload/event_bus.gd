## EventBus — 全局信号总线
## 所有跨系统通信均通过此 Autoload 解耦
extends Node

# ─── 作物系统 ───
signal crop_planted(tile_pos: Vector2i, crop_id: String)
signal crop_watered(tile_pos: Vector2i, crop_id: String)
signal crop_grown(tile_pos: Vector2i, crop_id: String, stage: int)
signal crop_matured(tile_pos: Vector2i, crop_id: String)
signal crop_harvested(tile_pos: Vector2i, crop_id: String, amount: int)
signal crop_withered(tile_pos: Vector2i, crop_id: String)
signal crop_cleared(tile_pos: Vector2i)

# ─── 经济系统 ───
signal gold_changed(new_amount: int, delta: int)
signal item_purchased(item_id: String, price: int)
signal item_sold(item_id: String, price: int)
signal transaction_completed(result: Dictionary)
signal transaction_failed(result: Dictionary)

# ─── 玩家进度 ───
signal xp_gained(amount: int, source: String)
signal level_up(new_level: int)
signal unlocks_changed(unlocks: Dictionary)
signal crop_unlocked(crop_id: String, level: int)
signal feature_unlocked(feature_id: String, level: int)
signal farm_slots_changed(new_slots: int)
signal achievement_unlocked(achievement_id: String)

# ─── 时间系统 ───
signal minute_changed(hour: int, minute: int)
signal hour_changed(new_hour: int)
signal day_started(year: int, season: String, day: int)
signal season_changed(new_season: String)
signal year_changed(new_year: int)
signal day_phase_changed(new_phase: String)
signal midnight_crossed()
signal time_scale_changed(new_scale: float)
signal time_paused_changed(paused: bool)

# ─── 田园网格系统 ───
signal farm_grid_initialized(width: int, height: int)
signal farm_tile_hovered(tile_pos: Vector2i, tile_data: Dictionary)
signal farm_tile_selected(tile_pos: Vector2i, tile_data: Dictionary)
signal farm_tile_state_changed(tile_pos: Vector2i, old_state: String, new_state: String)
signal farm_tile_unlocked(tile_pos: Vector2i)
signal farm_tile_occupied_changed(tile_pos: Vector2i, occupied: bool)
signal farm_grid_changed()

# ─── 农田交互闭环 ───
signal farm_interaction_mode_changed(mode: String, selected_item_id: String, selected_crop_id: String)
signal farm_interaction_completed(result: Dictionary)
signal farm_interaction_failed(result: Dictionary)
signal farm_tile_action_preview_changed(tile_pos: Vector2i, action: String, reason: String)

# ─── 玩家移动与交互 ───
signal player_spawned(world_pos: Vector2, grid_pos: Vector2i)
signal player_moved(world_pos: Vector2, grid_pos: Vector2i)
signal player_direction_changed(direction: String, direction_vector: Vector2i)
signal player_movement_enabled_changed(enabled: bool)
signal player_interaction_target_changed(target: Dictionary)
signal player_interacted(target: Dictionary)
signal player_interaction_failed(reason: String)
signal farm_tile_interaction_requested(tile_pos: Vector2i, target: Dictionary)

# ─── UI 交互 ───
signal ui_notification(message: String, type: String)
signal dialog_opened(dialog_id: String)
signal dialog_closed(dialog_id: String)
signal inventory_panel_opened()
signal inventory_panel_closed()
signal inventory_slot_selected(slot_index: int, slot_data: Variant)
signal inventory_filter_changed(filter_type: String)
signal inventory_drag_completed(from_index: int, to_index: int, success: bool)
signal inventory_discard_requested(slot_index: int, item_id: String, quantity: int)
signal shop_panel_opened()
signal shop_panel_closed()
signal shop_tab_changed(tab: String)
signal shop_item_selected(item_id: String, info: Dictionary)
signal shop_quantity_changed(item_id: String, quantity: int)
signal ui_input_block_changed(blocked: bool)

# ─── 背包系统 ───
signal inventory_changed(slot_index: int)
signal inventory_full()
signal hotbar_selected(index: int)
signal item_added(item_id: String, quantity: int, slot_index: int)
signal item_removed(item_id: String, quantity: int)

# ─── 社交系统 ───
signal friend_visited(friend_id: String)
signal crop_stolen(thief_id: String, crop_id: String)

# ─── 游戏状态 ───
signal game_saved(slot: int, metadata: Dictionary)
signal game_loaded(slot: int, metadata: Dictionary)
signal game_save_failed(slot: int, error_code: String, message: String)
signal game_load_failed(slot: int, error_code: String, message: String)
signal save_deleted(slot: int)
signal auto_save_completed(result: Dictionary)
signal auto_save_failed(result: Dictionary)
signal game_paused()
signal game_resumed()
