extends Node
## InventoryManager — 背包/库存数据层
## 维护 20 格库存槽位、9 格快捷栏映射、堆叠规则与 GameManager 兼容汇总

const MAX_SLOTS: int = 20
const HOTBAR_SIZE: int = 9
const DEFAULT_STACKABLE: bool = true
const DEFAULT_MAX_STACK: int = 99

var _slots: Array = []
var selected_hotbar_index: int = 0


func _ready() -> void:
	_reset_slots()
	if GameManager.inventory.size() > 0:
		_import_legacy_inventory(GameManager.inventory.duplicate(true))
	else:
		_sync_to_game_manager()
	print("[InventoryManager] 初始化完成，槽位数: %d" % _slots.size())


## 添加物品，返回实际添加数量
func add_item(item_id: String, quantity: int = 1) -> int:
	if item_id == "" or quantity <= 0:
		return 0

	var meta := _get_item_stack_meta(item_id)
	var stackable: bool = bool(meta["stackable"])
	var max_stack: int = int(meta["max_stack"])
	var remaining: int = quantity
	var total_added: int = 0

	if stackable:
		for index in range(MAX_SLOTS):
			if remaining <= 0:
				break
			var slot = _slots[index]
			if not _is_slot_for_item(slot, item_id):
				continue
			var current_quantity: int = int(slot["quantity"])
			if current_quantity >= max_stack:
				continue
			var add_count: int = mini(remaining, max_stack - current_quantity)
			slot["quantity"] = current_quantity + add_count
			remaining -= add_count
			total_added += add_count
			_emit_slot_added(index, item_id, add_count)

	while remaining > 0:
		var empty_index := _find_empty_slot()
		if empty_index == -1:
			break
		var add_to_slot: int = 1
		if stackable:
			add_to_slot = mini(remaining, max_stack)
		_slots[empty_index] = {
			"item_id": item_id,
			"quantity": add_to_slot,
		}
		remaining -= add_to_slot
		total_added += add_to_slot
		_emit_slot_added(empty_index, item_id, add_to_slot)

	if total_added > 0:
		_sync_to_game_manager()
	if total_added < quantity:
		EventBus.inventory_full.emit()
	return total_added


## 按 item_id 移除物品，返回实际移除数量
func remove_item(item_id: String, quantity: int = 1) -> int:
	if item_id == "" or quantity <= 0:
		return 0
	var remaining: int = quantity
	var total_removed: int = 0
	var changed_slots: Array[int] = []

	for index in range(MAX_SLOTS):
		if remaining <= 0:
			break
		var slot = _slots[index]
		if not _is_slot_for_item(slot, item_id):
			continue
		var remove_count: int = mini(remaining, int(slot["quantity"]))
		slot["quantity"] = int(slot["quantity"]) - remove_count
		if int(slot["quantity"]) <= 0:
			_slots[index] = null
		remaining -= remove_count
		total_removed += remove_count
		changed_slots.append(index)

	if total_removed > 0:
		for index in changed_slots:
			EventBus.inventory_changed.emit(index)
		EventBus.item_removed.emit(item_id, total_removed)
		_sync_to_game_manager()
	return total_removed


## 从指定槽位移除物品，返回实际移除数量
func remove_from_slot(slot_index: int, quantity: int = 1) -> int:
	if not _is_valid_slot_index(slot_index) or quantity <= 0:
		return 0
	var slot = _slots[slot_index]
	if not slot is Dictionary:
		return 0
	var item_id: String = str(slot["item_id"])
	var removed: int = mini(quantity, int(slot["quantity"]))
	slot["quantity"] = int(slot["quantity"]) - removed
	if int(slot["quantity"]) <= 0:
		_slots[slot_index] = null
	EventBus.inventory_changed.emit(slot_index)
	EventBus.item_removed.emit(item_id, removed)
	_sync_to_game_manager()
	return removed


## 交换两个槽位
func swap_slots(from_index: int, to_index: int) -> bool:
	if not _are_valid_distinct_slots(from_index, to_index):
		return false
	var temp = _slots[from_index]
	_slots[from_index] = _slots[to_index]
	_slots[to_index] = temp
	_emit_slots_changed([from_index, to_index])
	_sync_to_game_manager()
	return true


## 移动源槽位到空目标槽位
func move_to_slot(from_index: int, to_index: int) -> bool:
	if not _are_valid_distinct_slots(from_index, to_index):
		return false
	if _slots[from_index] == null or _slots[to_index] != null:
		return false
	_slots[to_index] = _slots[from_index]
	_slots[from_index] = null
	_emit_slots_changed([from_index, to_index])
	_sync_to_game_manager()
	return true


## 合并两个相同可堆叠物品槽位，返回实际合并数量
func merge_slots(from_index: int, to_index: int) -> int:
	if not _are_valid_distinct_slots(from_index, to_index):
		return 0
	var source = _slots[from_index]
	var target = _slots[to_index]
	if not source is Dictionary or not target is Dictionary:
		return 0
	var item_id: String = str(source["item_id"])
	if item_id != str(target["item_id"]):
		return 0
	var meta := _get_item_stack_meta(item_id)
	if not bool(meta["stackable"]):
		return 0
	var max_stack: int = int(meta["max_stack"])
	var target_quantity: int = int(target["quantity"])
	if target_quantity >= max_stack:
		return 0
	var merged: int = mini(int(source["quantity"]), max_stack - target_quantity)
	target["quantity"] = target_quantity + merged
	source["quantity"] = int(source["quantity"]) - merged
	if int(source["quantity"]) <= 0:
		_slots[from_index] = null
	_emit_slots_changed([from_index, to_index])
	_sync_to_game_manager()
	return merged


## 智能放置：空槽移动、同类合并、否则交换
func smart_place(from_index: int, to_index: int) -> bool:
	if not _are_valid_distinct_slots(from_index, to_index):
		return false
	if _slots[from_index] == null:
		return false
	if _slots[to_index] == null:
		return move_to_slot(from_index, to_index)
	var source: Dictionary = _slots[from_index]
	var target: Dictionary = _slots[to_index]
	if str(source["item_id"]) == str(target["item_id"]):
		var merged := merge_slots(from_index, to_index)
		if merged > 0:
			return true
	return swap_slots(from_index, to_index)


## 丢弃指定槽位物品；quantity = -1 丢弃整格
func discard_slot(slot_index: int, quantity: int = -1) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	var slot = _slots[slot_index]
	if not slot is Dictionary:
		return false
	var item_id: String = str(slot["item_id"])
	var removed: int = int(slot["quantity"])
	if quantity > 0:
		removed = mini(quantity, int(slot["quantity"]))
	slot["quantity"] = int(slot["quantity"]) - removed
	if int(slot["quantity"]) <= 0:
		_slots[slot_index] = null
	EventBus.inventory_changed.emit(slot_index)
	EventBus.item_removed.emit(item_id, removed)
	_sync_to_game_manager()
	return true


func get_slot(slot_index: int) -> Variant:
	if not _is_valid_slot_index(slot_index):
		return null
	var slot = _slots[slot_index]
	if slot is Dictionary:
		return slot.duplicate(true)
	return null


func get_all_slots() -> Array:
	return _slots.duplicate(true)


func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in _slots:
		if _is_slot_for_item(slot, item_id):
			total += int(slot["quantity"])
	return total


func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity


func is_full() -> bool:
	if get_empty_slot_count() > 0:
		return false
	for slot in _slots:
		if not slot is Dictionary:
			return false
		var item_id: String = str(slot["item_id"])
		var meta := _get_item_stack_meta(item_id)
		if bool(meta["stackable"]) and int(slot["quantity"]) < int(meta["max_stack"]):
			return false
	return true


func get_empty_slot_count() -> int:
	var count: int = 0
	for slot in _slots:
		if slot == null:
			count += 1
	return count


func get_addable_count(item_id: String) -> int:
	if item_id == "":
		return 0
	var meta := _get_item_stack_meta(item_id)
	var stackable: bool = bool(meta["stackable"])
	var max_stack: int = int(meta["max_stack"])
	var count: int = 0
	for slot in _slots:
		if slot == null:
			count += max_stack if stackable else 1
		elif stackable and _is_slot_for_item(slot, item_id):
			count += maxi(max_stack - int(slot["quantity"]), 0)
	return count


func get_items_by_type(item_type: String) -> Array:
	var result: Array = []
	for index in range(MAX_SLOTS):
		var slot = _slots[index]
		if not slot is Dictionary:
			continue
		var item_data := DataManager.get_item(str(slot["item_id"]))
		if item_data.get("type", "") == item_type:
			var slot_copy: Dictionary = slot.duplicate(true)
			slot_copy["slot_index"] = index
			result.append(slot_copy)
	return result.duplicate(true)


func find_item_slot(item_id: String) -> int:
	for index in range(MAX_SLOTS):
		if _is_slot_for_item(_slots[index], item_id):
			return index
	return -1


func get_hotbar_slots() -> Array:
	var hotbar: Array = []
	for index in range(HOTBAR_SIZE):
		var slot = _slots[index]
		if slot is Dictionary:
			hotbar.append(slot.duplicate(true))
		else:
			hotbar.append(null)
	return hotbar


func select_hotbar(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	if selected_hotbar_index == index:
		return
	selected_hotbar_index = index
	EventBus.hotbar_selected.emit(index)


func get_selected_hotbar() -> int:
	return selected_hotbar_index


func get_selected_item() -> Variant:
	return get_slot(selected_hotbar_index)


func use_selected_item() -> String:
	var slot = _slots[selected_hotbar_index]
	if not slot is Dictionary:
		return ""
	var item_id: String = str(slot["item_id"])
	var removed := remove_from_slot(selected_hotbar_index, 1)
	if removed <= 0:
		return ""
	return item_id


func export_save_data() -> Dictionary:
	return {
		"slots": _slots.duplicate(true),
		"selected_hotbar": selected_hotbar_index,
	}


func import_save_data(data: Dictionary) -> void:
	_reset_slots()
	if data.has("slots") and data["slots"] is Array:
		var source_slots: Array = data["slots"]
		for index in range(mini(source_slots.size(), MAX_SLOTS)):
			_slots[index] = _normalize_slot(source_slots[index])
	else:
		var legacy: Dictionary = data
		if data.has("inventory") and data["inventory"] is Dictionary:
			legacy = data["inventory"]
		_import_legacy_inventory(legacy, false)
	selected_hotbar_index = clampi(int(data.get("selected_hotbar", selected_hotbar_index)), 0, HOTBAR_SIZE - 1)
	_sync_to_game_manager()
	_emit_all_slots_changed()


func debug_print_all() -> void:
	print("=== InventoryManager 槽位状态 ===")
	for index in range(MAX_SLOTS):
		print("  [%02d] %s" % [index, str(_slots[index])])
	print("=== 选中快捷栏: %d ===" % selected_hotbar_index)


func debug_clear() -> void:
	_reset_slots()
	selected_hotbar_index = 0
	_sync_to_game_manager()
	_emit_all_slots_changed()


func debug_fill_random() -> void:
	debug_clear()
	var sample_items: Array[String] = ["seed_carrot", "seed_tomato", "harvest_carrot", "fertilizer"]
	for item_id in sample_items:
		add_item(item_id, randi_range(1, 20))


func _reset_slots() -> void:
	_slots.clear()
	for _index in range(MAX_SLOTS):
		_slots.append(null)


func _get_item_stack_meta(item_id: String) -> Dictionary:
	var item_data := DataManager.get_item(item_id)
	if item_data.is_empty():
		push_warning("[InventoryManager] Unknown item_id: %s, fallback stack rule used" % item_id)
		return {"stackable": DEFAULT_STACKABLE, "max_stack": DEFAULT_MAX_STACK}
	var stackable: bool = bool(item_data.get("stackable", DEFAULT_STACKABLE))
	var max_stack: int = int(item_data.get("max_stack", DEFAULT_MAX_STACK))
	if max_stack < 1:
		push_warning("[InventoryManager] Invalid max_stack for %s, fallback to 1" % item_id)
		max_stack = 1
	if not stackable:
		max_stack = 1
	return {"stackable": stackable, "max_stack": max_stack}


func _sync_to_game_manager() -> void:
	var summary: Dictionary = {}
	for slot in _slots:
		if not slot is Dictionary:
			continue
		var item_id: String = str(slot["item_id"])
		var quantity: int = int(slot["quantity"])
		if quantity <= 0:
			continue
		summary[item_id] = int(summary.get(item_id, 0)) + quantity
	GameManager.inventory = summary


func _import_legacy_inventory(legacy_inventory: Dictionary, clear_first: bool = true) -> void:
	if clear_first:
		_reset_slots()
	for item_id in legacy_inventory:
		var quantity: int = int(legacy_inventory[item_id])
		if quantity > 0:
			add_item(str(item_id), quantity)
	_sync_to_game_manager()


func _normalize_slot(value: Variant) -> Variant:
	if not value is Dictionary:
		return null
	var item_id: String = str(value.get("item_id", ""))
	var quantity: int = int(value.get("quantity", 0))
	if item_id == "" or quantity <= 0:
		return null
	var meta := _get_item_stack_meta(item_id)
	var max_stack: int = int(meta["max_stack"])
	return {
		"item_id": item_id,
		"quantity": mini(quantity, max_stack),
	}


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < MAX_SLOTS


func _are_valid_distinct_slots(from_index: int, to_index: int) -> bool:
	return _is_valid_slot_index(from_index) and _is_valid_slot_index(to_index) and from_index != to_index


func _find_empty_slot() -> int:
	for index in range(MAX_SLOTS):
		if _slots[index] == null:
			return index
	return -1


func _is_slot_for_item(slot: Variant, item_id: String) -> bool:
	return slot is Dictionary and str(slot.get("item_id", "")) == item_id


func _emit_slot_added(slot_index: int, item_id: String, quantity: int) -> void:
	EventBus.inventory_changed.emit(slot_index)
	EventBus.item_added.emit(item_id, quantity, slot_index)


func _emit_slots_changed(slot_indexes: Array[int]) -> void:
	for slot_index in slot_indexes:
		EventBus.inventory_changed.emit(slot_index)


func _emit_all_slots_changed() -> void:
	for index in range(MAX_SLOTS):
		EventBus.inventory_changed.emit(index)