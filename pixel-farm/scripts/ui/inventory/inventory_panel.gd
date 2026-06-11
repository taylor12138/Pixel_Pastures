extends Control
## InventoryPanel — 20 格背包功能面板。

enum FilterType {
	ALL,
	SEED,
	HARVEST,
	TOOL,
	CONSUMABLE,
	DECORATION,
}

const FILTER_IDS := {
	FilterType.ALL: "all",
	FilterType.SEED: "seed",
	FilterType.HARVEST: "harvest",
	FilterType.TOOL: "tool",
	FilterType.CONSUMABLE: "consumable",
	FilterType.DECORATION: "decoration",
}
const TYPE_NAMES := {
	"seed": "种子",
	"harvest": "收获物",
	"tool": "工具",
	"consumable": "消耗品",
	"decoration": "装饰",
	"unknown": "未知",
}
const SLOT_SCENE := preload("res://scenes/ui/inventory/inventory_slot.tscn")

@export var close_on_cancel: bool = true
@export var pause_world_time_when_open: bool = false

var is_open: bool = false
var current_filter: FilterType = FilterType.ALL
var selected_slot_index: int = -1
var pending_discard_slot_index: int = -1
var farm_interaction_controller: Node = null
var player_controller: Node = null
var slot_views: Array[Control] = []

@onready var window: PanelContainer = $Window
@onready var capacity_label: Label = $Window/Margin/MainVBox/Header/CapacityLabel
@onready var slots_grid: GridContainer = $Window/Margin/MainVBox/Content/InventorySection/SlotsGrid
@onready var detail_icon: ColorRect = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ItemIconPlaceholder
@onready var item_name_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ItemNameLabel
@onready var item_type_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ItemTypeLabel
@onready var quantity_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/QuantityLabel
@onready var price_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/PriceLabel
@onready var description_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/DescriptionLabel
@onready var select_button: Button = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ActionButtons/SelectButton
@onready var discard_button: Button = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ActionButtons/DiscardButton
@onready var footer_hint_label: Label = $Window/Margin/MainVBox/FooterHintLabel
@onready var discard_confirm_dialog: ConfirmationDialog = $DiscardConfirmDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_slots()
	_connect_ui()
	_connect_events()
	refresh_all_slots()
	_apply_filter_buttons()
	_clear_detail()
	visible = false
	is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if _is_open_bag_event(event):
		toggle_panel()
		get_viewport().set_input_as_handled()
	elif is_open and close_on_cancel and event.is_action_pressed("cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _is_open_bag_event(event: InputEvent) -> bool:
	if InputMap.has_action("open_bag") and event.is_action_pressed("open_bag"):
		return true
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and (key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB)
	)


func setup(interaction_controller: Node = null, player: Node = null) -> void:
	farm_interaction_controller = interaction_controller
	player_controller = player


func open_panel() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	refresh_all_slots()
	EventBus.ui_input_block_changed.emit(true)
	EventBus.inventory_panel_opened.emit()
	footer_hint_label.text = "拖拽整理物品 · 双击前 9 格选择 · Tab/Esc 关闭"
	window.grab_focus()


func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	EventBus.ui_input_block_changed.emit(false)
	EventBus.inventory_panel_closed.emit()


func toggle_panel() -> void:
	if is_open:
		close_panel()
	else:
		open_panel()


func is_panel_open() -> bool:
	return is_open


func refresh_all_slots() -> void:
	for index in range(InventoryManager.MAX_SLOTS):
		refresh_slot(index)
	_refresh_capacity()
	_refresh_hotbar_highlight()
	if selected_slot_index >= 0:
		_refresh_detail()


func refresh_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_views.size():
		return
	var data = InventoryManager.get_slot(slot_index)
	var metadata: Dictionary = {}
	if data is Dictionary:
		metadata = DataManager.get_item(str(data.get("item_id", "")))
	slot_views[slot_index].set_slot_data(data, metadata)
	slot_views[slot_index].set_filtered_out(_is_filtered_out(data, metadata))
	slot_views[slot_index].set_detail_selected(slot_index == selected_slot_index)
	slot_views[slot_index].set_hotbar_selected(slot_index == InventoryManager.get_selected_hotbar())
	_refresh_capacity()
	if slot_index == selected_slot_index:
		_refresh_detail()
	if slot_index == InventoryManager.get_selected_hotbar():
		_sync_farm_selection()


func set_filter(filter_type: FilterType) -> void:
	if current_filter == filter_type:
		return
	current_filter = filter_type
	for index in range(slot_views.size()):
		var data = InventoryManager.get_slot(index)
		var metadata: Dictionary = {}
		if data is Dictionary:
			metadata = DataManager.get_item(str(data.get("item_id", "")))
		slot_views[index].set_filtered_out(_is_filtered_out(data, metadata))
	if selected_slot_index >= 0 and slot_views[selected_slot_index].filtered_out:
		clear_selection()
	_apply_filter_buttons()
	EventBus.inventory_filter_changed.emit(FILTER_IDS[current_filter])


func select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_views.size():
		return
	selected_slot_index = slot_index
	for index in range(slot_views.size()):
		slot_views[index].set_detail_selected(index == selected_slot_index)
	_refresh_detail()
	EventBus.inventory_slot_selected.emit(slot_index, InventoryManager.get_slot(slot_index))


func clear_selection() -> void:
	selected_slot_index = -1
	for slot in slot_views:
		slot.set_detail_selected(false)
	_clear_detail()


func select_hotbar_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= InventoryManager.HOTBAR_SIZE:
		_notify("请先将物品拖到前 9 格", "warning")
		return false
	InventoryManager.select_hotbar(slot_index)
	_refresh_hotbar_highlight()
	_sync_farm_selection()
	var data = InventoryManager.get_slot(slot_index)
	if data is Dictionary:
		var item_id := str(data.get("item_id", ""))
		var metadata := DataManager.get_item(item_id)
		_notify("已选择：%s（快捷栏 %d）" % [str(metadata.get("name", item_id)), slot_index + 1], "info")
	else:
		_notify("已选择空快捷栏 %d" % (slot_index + 1), "info")
	return true


func request_discard(slot_index: int) -> void:
	var data = InventoryManager.get_slot(slot_index)
	if not data is Dictionary:
		return
	pending_discard_slot_index = slot_index
	var item_id := str(data.get("item_id", ""))
	var metadata := DataManager.get_item(item_id)
	var item_name := str(metadata.get("name", item_id))
	var quantity := int(data.get("quantity", 0))
	EventBus.inventory_discard_requested.emit(slot_index, item_id, quantity)
	discard_confirm_dialog.dialog_text = "确定丢弃 %s ×%d 吗？\n此操作不会生成地面掉落物。" % [item_name, quantity]
	discard_confirm_dialog.popup_centered(Vector2i(260, 110))


func confirm_discard() -> bool:
	if pending_discard_slot_index < 0:
		return false
	var discarded_index := pending_discard_slot_index
	pending_discard_slot_index = -1
	var success := InventoryManager.discard_slot(discarded_index, -1)
	if success:
		refresh_slot(discarded_index)
		if selected_slot_index == discarded_index:
			clear_selection()
		_sync_farm_selection()
	return success


func simulate_drag(from_index: int, to_index: int) -> bool:
	if from_index < 0 or to_index < 0 or from_index == to_index:
		return false
	var success := InventoryManager.smart_place(from_index, to_index)
	EventBus.inventory_drag_completed.emit(from_index, to_index, success)
	return success


func get_slot_view(slot_index: int) -> Control:
	if slot_index < 0 or slot_index >= slot_views.size():
		return null
	return slot_views[slot_index]


func get_filter_id() -> String:
	return FILTER_IDS[current_filter]


func _create_slots() -> void:
	for child in slots_grid.get_children():
		child.queue_free()
	slot_views.clear()
	for index in range(InventoryManager.MAX_SLOTS):
		var slot: Control = SLOT_SCENE.instantiate()
		slots_grid.add_child(slot)
		slot.setup(index)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_double_clicked.connect(_on_slot_double_clicked)
		slot.slot_context_requested.connect(_on_slot_context_requested)
		slot.drag_finished.connect(_on_drag_finished)
		slot_views.append(slot)


func _connect_ui() -> void:
	$DimBackground.gui_input.connect(_on_dim_background_gui_input)
	$Window/Margin/MainVBox/Header/CloseButton.pressed.connect(close_panel)
	$Window/Margin/MainVBox/FilterBar/AllButton.pressed.connect(set_filter.bind(FilterType.ALL))
	$Window/Margin/MainVBox/FilterBar/SeedButton.pressed.connect(set_filter.bind(FilterType.SEED))
	$Window/Margin/MainVBox/FilterBar/HarvestButton.pressed.connect(set_filter.bind(FilterType.HARVEST))
	$Window/Margin/MainVBox/FilterBar/ToolButton.pressed.connect(set_filter.bind(FilterType.TOOL))
	$Window/Margin/MainVBox/FilterBar/ConsumableButton.pressed.connect(set_filter.bind(FilterType.CONSUMABLE))
	$Window/Margin/MainVBox/FilterBar/DecorationButton.pressed.connect(set_filter.bind(FilterType.DECORATION))
	select_button.pressed.connect(_on_select_button_pressed)
	discard_button.pressed.connect(_on_discard_button_pressed)
	discard_confirm_dialog.confirmed.connect(confirm_discard)
	discard_confirm_dialog.canceled.connect(_on_discard_canceled)


func _connect_events() -> void:
	if not EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.connect(_on_inventory_changed)
	if not EventBus.inventory_full.is_connected(_on_inventory_full):
		EventBus.inventory_full.connect(_on_inventory_full)
	if not EventBus.hotbar_selected.is_connected(_on_hotbar_selected):
		EventBus.hotbar_selected.connect(_on_hotbar_selected)
	if not EventBus.item_added.is_connected(_on_item_added):
		EventBus.item_added.connect(_on_item_added)
	if not EventBus.item_removed.is_connected(_on_item_removed):
		EventBus.item_removed.connect(_on_item_removed)
	if not EventBus.game_loaded.is_connected(_on_game_loaded):
		EventBus.game_loaded.connect(_on_game_loaded)


func _refresh_capacity() -> void:
	if capacity_label == null:
		return
	var used := InventoryManager.MAX_SLOTS - InventoryManager.get_empty_slot_count()
	capacity_label.text = "%d/%d" % [used, InventoryManager.MAX_SLOTS]


func _refresh_hotbar_highlight() -> void:
	var selected := InventoryManager.get_selected_hotbar()
	for index in range(slot_views.size()):
		slot_views[index].set_hotbar_selected(index == selected)


func _refresh_detail() -> void:
	if selected_slot_index < 0:
		_clear_detail()
		return
	var data = InventoryManager.get_slot(selected_slot_index)
	if not data is Dictionary:
		item_name_label.text = "空槽位"
		item_type_label.text = "可放置物品"
		quantity_label.text = ""
		price_label.text = ""
		description_label.text = "拖拽物品到这里进行整理。"
		detail_icon.color = Color("#3B423F")
		select_button.disabled = true
		discard_button.disabled = true
		return
	var item_id := str(data.get("item_id", ""))
	var metadata := DataManager.get_item(item_id)
	var item_type := str(metadata.get("type", "unknown"))
	var max_stack := int(metadata.get("max_stack", 99))
	var quantity := int(data.get("quantity", 0))
	item_name_label.text = str(metadata.get("name", item_id))
	item_type_label.text = TYPE_NAMES.get(item_type, TYPE_NAMES["unknown"])
	quantity_label.text = "数量：%d / %d（总计 %d）" % [quantity, max_stack, InventoryManager.get_item_count(item_id)]
	price_label.text = _build_price_text(metadata)
	description_label.text = _build_description(metadata)
	detail_icon.color = _type_color(item_type)
	select_button.disabled = false
	discard_button.disabled = false


func _clear_detail() -> void:
	item_name_label.text = "请选择物品"
	item_type_label.text = ""
	quantity_label.text = ""
	price_label.text = ""
	description_label.text = "点击槽位查看详情。"
	detail_icon.color = Color("#3B423F")
	select_button.disabled = true
	discard_button.disabled = true


func _build_price_text(metadata: Dictionary) -> String:
	var parts: PackedStringArray = []
	if metadata.has("price"):
		parts.append("买入：%d" % int(metadata["price"]))
	if metadata.has("sell_price"):
		parts.append("卖出：%d" % int(metadata["sell_price"]))
	return "  ".join(parts)


func _build_description(metadata: Dictionary) -> String:
	var text := str(metadata.get("description", "暂无描述"))
	var crop_id := str(metadata.get("crop_id", ""))
	if crop_id != "":
		var crop_data := DataManager.get_crop(crop_id)
		text += "\n关联作物：%s" % str(crop_data.get("name", crop_id))
	return text


func _is_filtered_out(data: Variant, metadata: Dictionary) -> bool:
	if current_filter == FilterType.ALL or not data is Dictionary:
		return false
	return str(metadata.get("type", "unknown")) != FILTER_IDS[current_filter]


func _apply_filter_buttons() -> void:
	var buttons := [
		$Window/Margin/MainVBox/FilterBar/AllButton,
		$Window/Margin/MainVBox/FilterBar/SeedButton,
		$Window/Margin/MainVBox/FilterBar/HarvestButton,
		$Window/Margin/MainVBox/FilterBar/ToolButton,
		$Window/Margin/MainVBox/FilterBar/ConsumableButton,
		$Window/Margin/MainVBox/FilterBar/DecorationButton,
	]
	for index in range(buttons.size()):
		buttons[index].button_pressed = index == current_filter


func _sync_farm_selection() -> void:
	if farm_interaction_controller != null and farm_interaction_controller.has_method("sync_selection_from_hotbar"):
		farm_interaction_controller.call("sync_selection_from_hotbar")


func _notify(message: String, type: String) -> void:
	footer_hint_label.text = message
	EventBus.ui_notification.emit(message, type)


func _type_color(item_type: String) -> Color:
	match item_type:
		"seed":
			return Color("#78B86B")
		"harvest":
			return Color("#D9A441")
		"tool":
			return Color("#70889A")
		"consumable":
			return Color("#916BB3")
		"decoration":
			return Color("#B58A52")
		_:
			return Color("#686868")


func _on_slot_clicked(slot_index: int) -> void:
	select_slot(slot_index)


func _on_dim_background_gui_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("cancel"):
		close_panel()
		accept_event()


func _on_slot_double_clicked(slot_index: int) -> void:
	select_slot(slot_index)
	select_hotbar_slot(slot_index)


func _on_slot_context_requested(slot_index: int) -> void:
	select_slot(slot_index)
	request_discard(slot_index)


func _on_drag_finished(from_index: int, to_index: int, success: bool) -> void:
	EventBus.inventory_drag_completed.emit(from_index, to_index, success)
	if not success:
		_notify("无法移动这个物品", "warning")


func _on_select_button_pressed() -> void:
	if selected_slot_index >= 0:
		select_hotbar_slot(selected_slot_index)


func _on_discard_button_pressed() -> void:
	if selected_slot_index >= 0:
		request_discard(selected_slot_index)


func _on_discard_canceled() -> void:
	pending_discard_slot_index = -1


func _on_inventory_changed(slot_index: int) -> void:
	refresh_slot(slot_index)


func _on_inventory_full() -> void:
	_notify("背包已满", "warning")


func _on_hotbar_selected(_index: int) -> void:
	_refresh_hotbar_highlight()
	_sync_farm_selection()


func _on_item_added(_item_id: String, _quantity: int, slot_index: int) -> void:
	refresh_slot(slot_index)


func _on_item_removed(_item_id: String, _quantity: int) -> void:
	if selected_slot_index >= 0:
		_refresh_detail()
	_sync_farm_selection()


func _on_game_loaded(_slot: int, _metadata: Dictionary) -> void:
	refresh_all_slots()
	_sync_farm_selection()
