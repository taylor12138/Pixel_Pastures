extends HBoxContainer
## Hotbar — 背包前九格的常驻视图与选择入口。

const HOTBAR_SIZE: int = 9

var slot_views: Array[Control] = []
var _hotkeys_enabled: bool = true


func _ready() -> void:
	_collect_slots()
	_connect_events()
	refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if not _hotkeys_enabled:
		return
	for index in range(HOTBAR_SIZE):
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			select_slot(index)
			get_viewport().set_input_as_handled()
			return


func refresh_all() -> void:
	if slot_views.size() != HOTBAR_SIZE:
		_collect_slots()
	var slots := InventoryManager.get_hotbar_slots()
	for index in range(HOTBAR_SIZE):
		var data: Variant = slots[index] if index < slots.size() else null
		slot_views[index].set_slot_data(data)
	refresh_selection()


func refresh_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE or index >= slot_views.size():
		return
	var slots := InventoryManager.get_hotbar_slots()
	var data: Variant = slots[index] if index < slots.size() else null
	slot_views[index].set_slot_data(data)


func refresh_selection() -> void:
	var selected := InventoryManager.get_selected_hotbar()
	for index in range(slot_views.size()):
		slot_views[index].set_selected(index == selected)


func set_hotkeys_enabled(value: bool) -> void:
	_hotkeys_enabled = value


func are_hotkeys_enabled() -> bool:
	return _hotkeys_enabled


func select_slot(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SIZE:
		return false
	InventoryManager.select_hotbar(index)
	refresh_selection()
	return true


func get_slot_view(index: int) -> Control:
	if index < 0 or index >= slot_views.size():
		return null
	return slot_views[index]


func _collect_slots() -> void:
	slot_views.clear()
	for child in get_children():
		if child.has_method("set_slot_data") and child.has_method("set_selected"):
			slot_views.append(child)
	for index in range(slot_views.size()):
		var slot := slot_views[index]
		slot.setup(index)
		if not slot.slot_clicked.is_connected(_on_slot_clicked):
			slot.slot_clicked.connect(_on_slot_clicked)


func _connect_events() -> void:
	if not EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.connect(_on_inventory_changed)
	if not EventBus.item_added.is_connected(_on_item_added):
		EventBus.item_added.connect(_on_item_added)
	if not EventBus.item_removed.is_connected(_on_item_removed):
		EventBus.item_removed.connect(_on_item_removed)
	if not EventBus.hotbar_selected.is_connected(_on_hotbar_selected):
		EventBus.hotbar_selected.connect(_on_hotbar_selected)
	if not EventBus.ui_input_block_changed.is_connected(_on_ui_input_block_changed):
		EventBus.ui_input_block_changed.connect(_on_ui_input_block_changed)
	if not EventBus.game_loaded.is_connected(_on_game_loaded):
		EventBus.game_loaded.connect(_on_game_loaded)


func _on_slot_clicked(index: int) -> void:
	select_slot(index)


func _on_inventory_changed(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < HOTBAR_SIZE:
		refresh_slot(slot_index)


func _on_item_added(_item_id: String, _quantity: int, slot_index: int) -> void:
	if slot_index >= 0 and slot_index < HOTBAR_SIZE:
		refresh_slot(slot_index)


func _on_item_removed(_item_id: String, _quantity: int) -> void:
	# item_removed does not identify a slot; inventory_changed normally handles
	# precise updates, while this keeps custom emitters and tests synchronized.
	refresh_all()


func _on_hotbar_selected(_index: int) -> void:
	refresh_selection()


func _on_ui_input_block_changed(blocked: bool) -> void:
	set_hotkeys_enabled(not blocked)


func _on_game_loaded(_slot: int, _metadata: Dictionary) -> void:
	refresh_all()
