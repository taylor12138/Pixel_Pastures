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
signal achievement_unlocked(achievement_id: String)

# ─── 时间系统 ───
signal hour_changed(new_hour: int)
signal day_started(day: int)
signal season_changed(new_season: String)
signal midnight_crossed()

# ─── UI 交互 ───
signal ui_notification(message: String, type: String)
signal dialog_opened(dialog_id: String)
signal dialog_closed(dialog_id: String)

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
signal game_saved()
signal game_loaded()
signal game_paused()
signal game_resumed()
