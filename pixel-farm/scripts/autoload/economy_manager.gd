extends Node
## EconomyManager — 经济系统与商店数据层
## 统一处理购买、出售、价格查询、商店列表、交易统计与交易信号

const ERR_INVALID_ITEM := "INVALID_ITEM"
const ERR_INVALID_CROP := "INVALID_CROP"
const ERR_INVALID_QUANTITY := "INVALID_QUANTITY"
const ERR_NOT_SELLABLE := "NOT_SELLABLE"
const ERR_NOT_BUYABLE := "NOT_BUYABLE"
const ERR_NOT_ENOUGH_GOLD := "NOT_ENOUGH_GOLD"
const ERR_NOT_ENOUGH_ITEMS := "NOT_ENOUGH_ITEMS"
const ERR_INVENTORY_FULL := "INVENTORY_FULL"
const ERR_LOCKED := "LOCKED"

const BUYABLE_TYPES: Array[String] = ["seed", "consumable", "decoration"]
const SELLABLE_TYPES: Array[String] = ["harvest"]

var stats: Dictionary = {}


func _ready() -> void:
	debug_reset_stats()
	print("[EconomyManager] 初始化完成")


# ─── 购买相关 ───

func buy_seed(crop_id: String, quantity: int = 1) -> Dictionary:
	var gold_before := GameManager.gold
	if quantity <= 0:
		return _emit_failed_result(_make_result(false, "buy", "", crop_id, quantity, -1, 0, gold_before, gold_before, "购买数量无效", ERR_INVALID_QUANTITY))
	var crop_data := DataManager.get_crop(crop_id)
	if crop_id == "" or crop_data.is_empty():
		return _emit_failed_result(_make_result(false, "buy", "", crop_id, quantity, -1, 0, gold_before, gold_before, "作物不存在", ERR_INVALID_CROP))
	var item_id := "seed_" + crop_id
	return buy_item(item_id, quantity)


func buy_item(item_id: String, quantity: int = 1) -> Dictionary:
	var validation := can_buy_item(item_id, quantity)
	if not bool(validation.get("success", false)):
		return _emit_failed_result(validation)

	var gold_before: int = int(validation["gold_before"])
	var unit_price: int = int(validation["unit_price"])
	var total_price: int = int(validation["total_price"])
	var crop_id: String = str(validation.get("crop_id", ""))

	if not GameManager.spend_gold(total_price):
		return _emit_failed_result(_make_result(false, "buy", item_id, crop_id, quantity, unit_price, total_price, gold_before, GameManager.gold, "金币不足", ERR_NOT_ENOUGH_GOLD))

	var added := InventoryManager.add_item(item_id, quantity)
	if added != quantity:
		if added > 0:
			InventoryManager.remove_item(item_id, added)
		GameManager.add_gold(total_price, "transaction_rollback")
		return _emit_failed_result(_make_result(false, "buy", item_id, crop_id, quantity, unit_price, total_price, gold_before, GameManager.gold, "背包空间不足", ERR_INVENTORY_FULL))

	stats["total_gold_spent"] = int(stats.get("total_gold_spent", 0)) + total_price
	stats["total_items_bought"] = int(stats.get("total_items_bought", 0)) + quantity
	stats["total_transactions"] = int(stats.get("total_transactions", 0)) + 1

	var result := _make_result(true, "buy", item_id, crop_id, quantity, unit_price, total_price, gold_before, GameManager.gold, "购买成功", "")
	EventBus.item_purchased.emit(item_id, total_price)
	EventBus.transaction_completed.emit(result)
	return result


func can_buy_item(item_id: String, quantity: int = 1) -> Dictionary:
	var gold_before := GameManager.gold
	if quantity <= 0:
		return _make_result(false, "buy", item_id, "", quantity, -1, 0, gold_before, gold_before, "购买数量无效", ERR_INVALID_QUANTITY)
	var item_data := DataManager.get_item(item_id)
	if item_id == "" or item_data.is_empty():
		return _make_result(false, "buy", item_id, "", quantity, -1, 0, gold_before, gold_before, "物品不存在", ERR_INVALID_ITEM)

	var crop_id := _get_crop_id_for_item(item_data)
	var unit_price := get_buy_price(item_id)
	var item_type: String = str(item_data.get("type", ""))
	if not BUYABLE_TYPES.has(item_type) or unit_price <= 0:
		return _make_result(false, "buy", item_id, crop_id, quantity, unit_price, 0, gold_before, gold_before, "物品不可购买", ERR_NOT_BUYABLE)
	if not _is_item_unlocked(item_id):
		return _make_result(false, "buy", item_id, crop_id, quantity, unit_price, unit_price * quantity, gold_before, gold_before, "商品尚未解锁", ERR_LOCKED)

	var total_price := unit_price * quantity
	if not GameManager.can_afford(total_price):
		return _make_result(false, "buy", item_id, crop_id, quantity, unit_price, total_price, gold_before, gold_before, "金币不足", ERR_NOT_ENOUGH_GOLD)
	if InventoryManager.get_addable_count(item_id) < quantity:
		return _make_result(false, "buy", item_id, crop_id, quantity, unit_price, total_price, gold_before, gold_before, "背包空间不足", ERR_INVENTORY_FULL)

	return _make_result(true, "buy", item_id, crop_id, quantity, unit_price, total_price, gold_before, gold_before, "可以购买", "")


# ─── 出售相关 ───

func sell_harvest(crop_id: String, quantity: int = 1) -> Dictionary:
	var gold_before := GameManager.gold
	if quantity <= 0:
		return _emit_failed_result(_make_result(false, "sell", "", crop_id, quantity, -1, 0, gold_before, gold_before, "出售数量无效", ERR_INVALID_QUANTITY))
	var crop_data := DataManager.get_crop(crop_id)
	if crop_id == "" or crop_data.is_empty():
		return _emit_failed_result(_make_result(false, "sell", "", crop_id, quantity, -1, 0, gold_before, gold_before, "作物不存在", ERR_INVALID_CROP))
	var item_id := "harvest_" + crop_id
	return sell_item(item_id, quantity)


func sell_item(item_id: String, quantity: int = 1) -> Dictionary:
	var validation := can_sell_item(item_id, quantity)
	if not bool(validation.get("success", false)):
		return _emit_failed_result(validation)

	var gold_before: int = int(validation["gold_before"])
	var unit_price: int = int(validation["unit_price"])
	var total_price: int = int(validation["total_price"])
	var crop_id: String = str(validation.get("crop_id", ""))

	var removed := InventoryManager.remove_item(item_id, quantity)
	if removed != quantity:
		if removed > 0:
			InventoryManager.add_item(item_id, removed)
		return _emit_failed_result(_make_result(false, "sell", item_id, crop_id, quantity, unit_price, total_price, gold_before, gold_before, "物品数量不足", ERR_NOT_ENOUGH_ITEMS))

	GameManager.add_gold(total_price, "sell")

	if has_node("/root/LevelManager"):
		LevelManager.grant_xp("sell", {"item_id": item_id, "crop_id": crop_id, "quantity": quantity, "total_price": total_price})

	stats["total_gold_earned_from_sales"] = int(stats.get("total_gold_earned_from_sales", 0)) + total_price
	stats["total_items_sold"] = int(stats.get("total_items_sold", 0)) + quantity
	stats["total_transactions"] = int(stats.get("total_transactions", 0)) + 1

	var result := _make_result(true, "sell", item_id, crop_id, quantity, unit_price, total_price, gold_before, GameManager.gold, "出售成功", "")
	EventBus.item_sold.emit(item_id, total_price)
	EventBus.transaction_completed.emit(result)
	return result


func can_sell_item(item_id: String, quantity: int = 1) -> Dictionary:
	var gold_before := GameManager.gold
	if quantity <= 0:
		return _make_result(false, "sell", item_id, "", quantity, -1, 0, gold_before, gold_before, "出售数量无效", ERR_INVALID_QUANTITY)
	var item_data := DataManager.get_item(item_id)
	if item_id == "" or item_data.is_empty():
		return _make_result(false, "sell", item_id, "", quantity, -1, 0, gold_before, gold_before, "物品不存在", ERR_INVALID_ITEM)

	var crop_id := _get_crop_id_for_item(item_data)
	var unit_price := get_sell_price(item_id)
	var item_type: String = str(item_data.get("type", ""))
	if not SELLABLE_TYPES.has(item_type) or unit_price <= 0:
		return _make_result(false, "sell", item_id, crop_id, quantity, unit_price, 0, gold_before, gold_before, "物品不可出售", ERR_NOT_SELLABLE)

	var total_price := unit_price * quantity
	if not InventoryManager.has_item(item_id, quantity):
		return _make_result(false, "sell", item_id, crop_id, quantity, unit_price, total_price, gold_before, gold_before, "物品数量不足", ERR_NOT_ENOUGH_ITEMS)

	return _make_result(true, "sell", item_id, crop_id, quantity, unit_price, total_price, gold_before, gold_before, "可以出售", "")


# ─── 查询相关 ───

func get_buy_price(item_id: String) -> int:
	var item_data := DataManager.get_item(item_id)
	if item_data.is_empty():
		return -1
	var item_type: String = str(item_data.get("type", ""))
	if not BUYABLE_TYPES.has(item_type):
		return -1
	var direct_price := int(item_data.get("price", -1))
	if direct_price > 0:
		return direct_price
	if item_type == "seed":
		var crop_id := _get_crop_id_for_item(item_data)
		var crop_data := DataManager.get_crop(crop_id)
		var seed_price := int(crop_data.get("seed_price", -1))
		if seed_price > 0:
			return seed_price
	return -1


func get_sell_price(item_id: String) -> int:
	var item_data := DataManager.get_item(item_id)
	if item_data.is_empty():
		return -1
	var item_type: String = str(item_data.get("type", ""))
	if not SELLABLE_TYPES.has(item_type):
		return -1
	var direct_price := int(item_data.get("sell_price", -1))
	if direct_price > 0:
		return direct_price
	var crop_id := _get_crop_id_for_item(item_data)
	var crop_data := DataManager.get_crop(crop_id)
	var crop_sell_price := int(crop_data.get("sell_price", -1))
	if crop_sell_price > 0:
		return crop_sell_price
	return -1


func get_seed_shop_items() -> Array:
	var result: Array = []
	for crop_data in DataManager.get_all_crops():
		if not crop_data is Dictionary:
			continue
		var crop_id: String = str(crop_data.get("id", ""))
		if crop_id == "":
			continue
		var item_id := "seed_" + crop_id
		var item_data := DataManager.get_item(item_id)
		if item_data.is_empty():
			continue
		var price := get_buy_price(item_id)
		if price <= 0:
			continue
		var unlock_level := int(crop_data.get("unlock_level", 1))
		var unlocked := GameManager.level >= unlock_level
		if has_node("/root/LevelManager"):
			unlock_level = LevelManager.get_crop_unlock_level(crop_id)
			unlocked = LevelManager.is_crop_unlocked(crop_id)
		result.append({
			"item_id": item_id,
			"crop_id": crop_id,
			"name": str(item_data.get("name", crop_data.get("name", item_id))),
			"type": "seed",
			"price": price,
			"unlocked": unlocked,
			"unlock_level": unlock_level,
			"owned_count": InventoryManager.get_item_count(item_id),
			"can_afford_one": GameManager.gold >= price,
		})
	return result.duplicate(true)


func get_shop_items() -> Array:
	var result: Array = get_seed_shop_items()
	var items = DataManager.get_table("items")
	if items is Dictionary:
		for item_id in items:
			var item_data: Dictionary = DataManager.get_item(str(item_id))
			var item_type: String = str(item_data.get("type", ""))
			if item_type == "seed":
				continue
			if item_type != "consumable" and item_type != "decoration":
				continue
			var price := get_buy_price(str(item_id))
			if price <= 0:
				continue
			result.append({
				"item_id": str(item_id),
				"crop_id": _get_crop_id_for_item(item_data),
				"name": str(item_data.get("name", item_id)),
				"type": item_type,
				"price": price,
				"unlocked": _is_item_unlocked(str(item_id)),
				"unlock_level": 1,
				"owned_count": InventoryManager.get_item_count(str(item_id)),
				"can_afford_one": GameManager.gold >= price,
			})
	return result.duplicate(true)


func get_sellable_inventory_items() -> Array:
	var aggregated: Dictionary = {}
	var slots := InventoryManager.get_all_slots()
	for index in range(slots.size()):
		var slot = slots[index]
		if not slot is Dictionary:
			continue
		var item_id: String = str(slot.get("item_id", ""))
		var quantity := int(slot.get("quantity", 0))
		var unit_price := get_sell_price(item_id)
		if quantity <= 0 or unit_price <= 0:
			continue
		if not aggregated.has(item_id):
			var item_data := DataManager.get_item(item_id)
			aggregated[item_id] = {
				"item_id": item_id,
				"name": str(item_data.get("name", item_id)),
				"quantity": 0,
				"unit_price": unit_price,
				"total_price": 0,
				"slot_indexes": [],
			}
		var entry: Dictionary = aggregated[item_id]
		entry["quantity"] = int(entry["quantity"]) + quantity
		entry["total_price"] = int(entry["quantity"]) * unit_price
		entry["slot_indexes"].append(index)

	var result: Array = []
	for item_id in aggregated:
		result.append(aggregated[item_id].duplicate(true))
	return result


func get_shop_item_info(item_id: String) -> Dictionary:
	var item_data := DataManager.get_item(item_id)
	if item_data.is_empty():
		return {}
	var crop_id := _get_crop_id_for_item(item_data)
	var crop_data := DataManager.get_crop(crop_id)
	var unlock_level := int(crop_data.get("unlock_level", 1))
	return {
		"item_id": item_id,
		"crop_id": crop_id,
		"name": str(item_data.get("name", item_id)),
		"type": str(item_data.get("type", "")),
		"buy_price": get_buy_price(item_id),
		"sell_price": get_sell_price(item_id),
		"unlocked": _is_item_unlocked(item_id),
		"unlock_level": unlock_level,
		"owned_count": InventoryManager.get_item_count(item_id),
		"description": str(item_data.get("description", "")),
	}.duplicate(true)


# ─── 存档/统计相关 ───

func export_save_data() -> Dictionary:
	return {
		"stats": stats.duplicate(true),
	}


func import_save_data(data: Dictionary) -> void:
	debug_reset_stats()
	var source_stats: Dictionary = data.get("stats", data)
	for key in stats.keys():
		stats[key] = maxi(int(source_stats.get(key, stats[key])), 0)


func debug_reset_stats() -> void:
	stats = {
		"total_gold_spent": 0,
		"total_gold_earned_from_sales": 0,
		"total_items_bought": 0,
		"total_items_sold": 0,
		"total_transactions": 0,
	}


# ─── 内部 helper ───

func _make_result(
	success: bool,
	transaction_type: String,
	item_id: String,
	crop_id: String,
	quantity: int,
	unit_price: int,
	total_price: int,
	gold_before: int,
	gold_after: int,
	message: String,
	error_code: String
) -> Dictionary:
	return {
		"success": success,
		"type": transaction_type,
		"item_id": item_id,
		"crop_id": crop_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_price": total_price,
		"gold_before": gold_before,
		"gold_after": gold_after,
		"message": message,
		"error_code": error_code,
	}


func _emit_failed_result(result: Dictionary) -> Dictionary:
	EventBus.transaction_failed.emit(result)
	var message: String = str(result.get("message", "交易失败"))
	if message != "":
		EventBus.ui_notification.emit(message, "warning")
	return result


func _get_crop_id_for_item(item_data: Dictionary) -> String:
	if item_data.has("crop_id"):
		return str(item_data.get("crop_id", ""))
	var item_id: String = str(item_data.get("id", ""))
	if item_id.begins_with("seed_"):
		return item_id.trim_prefix("seed_")
	if item_id.begins_with("harvest_"):
		return item_id.trim_prefix("harvest_")
	return ""


func _is_item_unlocked(item_id: String) -> bool:
	var item_data := DataManager.get_item(item_id)
	if item_data.is_empty():
		return false
	if str(item_data.get("type", "")) != "seed":
		return true
	var crop_id := _get_crop_id_for_item(item_data)
	var crop_data := DataManager.get_crop(crop_id)
	if crop_data.is_empty():
		return false
	if has_node("/root/LevelManager"):
		return LevelManager.is_crop_unlocked(crop_id)
	return GameManager.level >= int(crop_data.get("unlock_level", 1))
