extends Control
## ShopPanel — 商店购买/出售功能面板。

enum ShopTab {
	BUY,
	SELL,
}

const SHOP_ROW_SCENE := preload("res://scenes/ui/shop/shop_item_row.tscn")
const TAB_IDS := {
	ShopTab.BUY: "buy",
	ShopTab.SELL: "sell",
}
const TYPE_NAMES := {
	"seed": "种子",
	"harvest": "收获物",
	"consumable": "消耗品",
	"decoration": "装饰",
	"unknown": "未知",
}
const TYPE_COLORS := {
	"seed": Color("#78B86B"),
	"harvest": Color("#D9A441"),
	"consumable": Color("#916BB3"),
	"decoration": Color("#B58A52"),
	"unknown": Color("#686868"),
}
const ERROR_MESSAGES := {
	"INVALID_ITEM": "商品不存在",
	"INVALID_CROP": "作物不存在",
	"INVALID_QUANTITY": "请选择有效数量",
	"NOT_SELLABLE": "该物品不可出售",
	"NOT_BUYABLE": "该物品不可购买",
	"NOT_ENOUGH_GOLD": "金币不足",
	"NOT_ENOUGH_ITEMS": "库存不足",
	"INVENTORY_FULL": "背包空间不足",
	"LOCKED": "商品尚未解锁",
}

@export var close_on_cancel: bool = true
@export var pause_world_time_when_open: bool = false

var is_open: bool = false
var current_tab: ShopTab = ShopTab.BUY
var selected_item_id: String = ""
var selected_quantity: int = 0
var row_views: Array[Control] = []
var current_items: Array[Dictionary] = []
var context_node: Node = null
var _suppress_transaction_event_feedback: bool = false

@onready var window: PanelContainer = $Window
@onready var gold_label: Label = $Window/Margin/MainVBox/Header/GoldLabel
@onready var buy_tab_button: Button = $Window/Margin/MainVBox/TabBar/BuyTabButton
@onready var sell_tab_button: Button = $Window/Margin/MainVBox/TabBar/SellTabButton
@onready var item_list: VBoxContainer = $Window/Margin/MainVBox/Content/ListSection/ListScroll/ItemList
@onready var empty_label: Label = $Window/Margin/MainVBox/Content/ListSection/ListScroll/ItemList/EmptyLabel
@onready var detail_icon: ColorRect = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ItemIconPlaceholder
@onready var item_name_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ItemNameLabel
@onready var item_type_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ItemTypeLabel
@onready var unit_price_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/UnitPriceLabel
@onready var owned_count_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/OwnedCountLabel
@onready var unlock_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/UnlockLabel
@onready var description_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/DescriptionLabel
@onready var qty_1_button: Button = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/QuantitySelector/Qty1Button
@onready var qty_5_button: Button = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/QuantitySelector/Qty5Button
@onready var qty_10_button: Button = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/QuantitySelector/Qty10Button
@onready var qty_max_button: Button = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/QuantitySelector/QtyMaxButton
@onready var quantity_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/QuantityLabel
@onready var total_price_label: Label = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/TotalPriceLabel
@onready var confirm_button: Button = $Window/Margin/MainVBox/Content/DetailPanel/DetailMargin/DetailVBox/ConfirmButton
@onready var footer_hint_label: Label = $Window/Margin/MainVBox/FooterHintLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_ui()
	_connect_events()
	refresh_gold()
	rebuild_list()
	clear_selection()
	visible = false
	is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open and close_on_cancel and event.is_action_pressed("cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func setup(context: Node = null) -> void:
	context_node = context


func open_panel() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	refresh_gold()
	rebuild_list()
	EventBus.ui_input_block_changed.emit(true)
	EventBus.shop_panel_opened.emit()
	window.grab_focus()


func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	clear_selection()
	EventBus.ui_input_block_changed.emit(false)
	EventBus.shop_panel_closed.emit()


func toggle_panel() -> void:
	if is_open:
		close_panel()
	else:
		open_panel()


func is_panel_open() -> bool:
	return is_open


func set_tab(tab: ShopTab) -> void:
	var changed := current_tab != tab
	current_tab = tab
	clear_selection()
	rebuild_list()
	_apply_tab_buttons()
	if changed:
		EventBus.shop_tab_changed.emit(TAB_IDS[current_tab])


func rebuild_list() -> void:
	for row in row_views:
		if is_instance_valid(row):
			if row.get_parent() == item_list:
				item_list.remove_child(row)
			row.queue_free()
	row_views.clear()
	current_items.clear()

	var source: Array = EconomyManager.get_shop_items() if current_tab == ShopTab.BUY else EconomyManager.get_sellable_inventory_items()
	for raw_item in source:
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item.duplicate(true)
		if current_tab == ShopTab.SELL and int(item.get("quantity", 0)) <= 0:
			continue
		current_items.append(item)
		var row: Control = SHOP_ROW_SCENE.instantiate()
		item_list.add_child(row)
		if current_tab == ShopTab.BUY:
			row.set_buy_data(item)
		else:
			row.set_sell_data(item)
		row.row_clicked.connect(select_item)
		row_views.append(row)

	empty_label.visible = current_items.is_empty()
	empty_label.text = "暂无可购买商品" if current_tab == ShopTab.BUY else "暂无可出售物品"
	_apply_tab_buttons()
	if selected_item_id != "":
		if _find_item(selected_item_id).is_empty():
			clear_selection()
		else:
			_refresh_selected_detail()
	else:
		_refresh_confirm_state()


func refresh_item_row(item_id: String) -> void:
	var was_selected := selected_item_id == item_id
	var latest_items: Array = EconomyManager.get_shop_items() if current_tab == ShopTab.BUY else EconomyManager.get_sellable_inventory_items()
	var latest: Dictionary = {}
	for raw_item in latest_items:
		if raw_item is Dictionary and str(raw_item.get("item_id", "")) == item_id:
			latest = raw_item.duplicate(true)
			break
	if latest.is_empty():
		rebuild_list()
		if was_selected:
			clear_selection()
		return

	var item_index := _find_item_index(item_id)
	if item_index < 0 or item_index >= row_views.size():
		rebuild_list()
		return
	current_items[item_index] = latest
	if current_tab == ShopTab.BUY:
		row_views[item_index].set_buy_data(latest)
	else:
		row_views[item_index].set_sell_data(latest)
	row_views[item_index].set_selected(was_selected)
	_update_row_trade_state(row_views[item_index], latest)
	if was_selected:
		_refresh_selected_detail()


func select_item(item_id: String) -> void:
	var item := _find_item(item_id)
	if item.is_empty():
		clear_selection()
		return
	selected_item_id = item_id
	for row in row_views:
		row.set_selected(row.item_id == item_id)
	var info := _build_detail_info(item)
	var max_quantity := _get_max_quantity(item)
	set_quantity(1 if max_quantity > 0 else 0)
	_refresh_detail(info, item)
	EventBus.shop_item_selected.emit(item_id, info.duplicate(true))


func clear_selection() -> void:
	selected_item_id = ""
	selected_quantity = 0
	for row in row_views:
		row.set_selected(false)
	_clear_detail()
	_refresh_confirm_state()


func set_quantity(quantity: int) -> void:
	var item := _find_item(selected_item_id)
	var maximum := _get_max_quantity(item)
	var clamped_quantity := clampi(quantity, 0, maximum)
	if selected_quantity == clamped_quantity:
		_refresh_confirm_state()
		return
	selected_quantity = clamped_quantity
	if selected_item_id != "":
		EventBus.shop_quantity_changed.emit(selected_item_id, selected_quantity)
	_refresh_confirm_state()


func set_quantity_max() -> void:
	set_quantity(_get_max_quantity(_find_item(selected_item_id)))


func confirm_transaction() -> Dictionary:
	if selected_item_id == "" or selected_quantity <= 0:
		var invalid := {
			"success": false,
			"item_id": selected_item_id,
			"quantity": selected_quantity,
			"message": "请选择可交易商品和数量",
			"error_code": "INVALID_QUANTITY",
		}
		_handle_transaction_feedback(invalid)
		return invalid
	var validation := _get_validation()
	if not bool(validation.get("success", false)):
		_handle_transaction_feedback(validation)
		return validation
	_suppress_transaction_event_feedback = true
	var result: Dictionary
	if current_tab == ShopTab.BUY:
		result = EconomyManager.buy_item(selected_item_id, selected_quantity)
	else:
		result = EconomyManager.sell_item(selected_item_id, selected_quantity)
	_suppress_transaction_event_feedback = false
	_handle_transaction_feedback(result, bool(result.get("success", false)))
	refresh_gold()
	refresh_item_row(str(result.get("item_id", selected_item_id)))
	return result


func refresh_gold() -> void:
	gold_label.text = "金币：%d" % GameManager.gold


func get_current_tab_id() -> String:
	return TAB_IDS[current_tab]


func get_current_items() -> Array:
	return current_items.duplicate(true)


func get_selected_info() -> Dictionary:
	var item := _find_item(selected_item_id)
	return _build_detail_info(item)


func get_max_quantity() -> int:
	return _get_max_quantity(_find_item(selected_item_id))


func _connect_ui() -> void:
	$DimBackground.gui_input.connect(_on_dim_background_gui_input)
	$Window/Margin/MainVBox/Header/CloseButton.pressed.connect(close_panel)
	buy_tab_button.pressed.connect(set_tab.bind(ShopTab.BUY))
	sell_tab_button.pressed.connect(set_tab.bind(ShopTab.SELL))
	qty_1_button.pressed.connect(set_quantity.bind(1))
	qty_5_button.pressed.connect(set_quantity.bind(5))
	qty_10_button.pressed.connect(set_quantity.bind(10))
	qty_max_button.pressed.connect(set_quantity_max)
	confirm_button.pressed.connect(confirm_transaction)


func _connect_events() -> void:
	if not EventBus.transaction_completed.is_connected(_on_transaction_completed):
		EventBus.transaction_completed.connect(_on_transaction_completed)
	if not EventBus.transaction_failed.is_connected(_on_transaction_failed):
		EventBus.transaction_failed.connect(_on_transaction_failed)
	if not EventBus.gold_changed.is_connected(_on_gold_changed):
		EventBus.gold_changed.connect(_on_gold_changed)
	if not EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.connect(_on_inventory_changed)
	if not EventBus.level_up.is_connected(_on_level_up):
		EventBus.level_up.connect(_on_level_up)
	if not EventBus.crop_unlocked.is_connected(_on_crop_unlocked):
		EventBus.crop_unlocked.connect(_on_crop_unlocked)
	if not EventBus.unlocks_changed.is_connected(_on_unlocks_changed):
		EventBus.unlocks_changed.connect(_on_unlocks_changed)
	if not EventBus.game_loaded.is_connected(_on_game_loaded):
		EventBus.game_loaded.connect(_on_game_loaded)


func _find_item(item_id: String) -> Dictionary:
	var index := _find_item_index(item_id)
	if index < 0:
		return {}
	return current_items[index].duplicate(true)


func _find_item_index(item_id: String) -> int:
	for index in range(current_items.size()):
		if str(current_items[index].get("item_id", "")) == item_id:
			return index
	return -1


func _build_detail_info(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var item_id := str(item.get("item_id", ""))
	var info := EconomyManager.get_shop_item_info(item_id)
	var metadata := DataManager.get_item(item_id)
	if info.is_empty():
		info = {
			"item_id": item_id,
			"name": str(item.get("name", item_id)),
			"type": str(item.get("type", metadata.get("type", "unknown"))),
			"description": str(metadata.get("description", "")),
		}
	info["name"] = str(info.get("name", item.get("name", item_id)))
	info["type"] = str(info.get("type", item.get("type", "unknown")))
	if str(info["type"]) == "":
		info["type"] = "unknown"
	info["description"] = str(info.get("description", metadata.get("description", "")))
	info["unlocked"] = bool(item.get("unlocked", info.get("unlocked", true)))
	info["unlock_level"] = int(item.get("unlock_level", info.get("unlock_level", 1)))
	info["unit_price"] = _get_unit_price(item)
	info["owned_count"] = int(item.get("owned_count", info.get("owned_count", 0)))
	info["quantity"] = int(item.get("quantity", 0))
	return info.duplicate(true)


func _refresh_selected_detail() -> void:
	var item := _find_item(selected_item_id)
	if item.is_empty():
		clear_selection()
		return
	var maximum := _get_max_quantity(item)
	var desired := selected_quantity
	if desired <= 0 and maximum > 0:
		desired = 1
	set_quantity(desired)
	_refresh_detail(_build_detail_info(item), item)


func _refresh_detail(info: Dictionary, item: Dictionary) -> void:
	if info.is_empty():
		_clear_detail()
		return
	var item_type := str(info.get("type", "unknown"))
	item_name_label.text = str(info.get("name", selected_item_id))
	item_type_label.text = TYPE_NAMES.get(item_type, TYPE_NAMES["unknown"])
	unit_price_label.text = "单价：%d 金" % int(info.get("unit_price", -1))
	owned_count_label.text = (
		"已有：%d" % int(info.get("owned_count", 0))
		if current_tab == ShopTab.BUY
		else "库存：%d" % int(info.get("quantity", 0))
	)
	var unlocked := bool(info.get("unlocked", true))
	unlock_label.visible = current_tab == ShopTab.BUY and not unlocked
	unlock_label.text = "Lv.%d 解锁" % int(info.get("unlock_level", 1))
	description_label.text = str(info.get("description", "暂无描述"))
	if description_label.text == "":
		description_label.text = "暂无描述"
	detail_icon.color = TYPE_COLORS.get(item_type, TYPE_COLORS["unknown"])
	var controls_enabled := unlocked and _get_max_quantity(item) > 0
	for button in [qty_1_button, qty_5_button, qty_10_button, qty_max_button]:
		button.disabled = not controls_enabled
	_refresh_confirm_state()


func _clear_detail() -> void:
	item_name_label.text = "请选择商品"
	item_type_label.text = ""
	unit_price_label.text = ""
	owned_count_label.text = ""
	unlock_label.visible = false
	description_label.text = "从左侧列表选择商品查看详情。"
	detail_icon.color = TYPE_COLORS["unknown"]
	quantity_label.text = "数量：0"
	total_price_label.text = "总价：0 金"
	for button in [qty_1_button, qty_5_button, qty_10_button, qty_max_button]:
		button.disabled = true


func _get_unit_price(item: Dictionary) -> int:
	if item.is_empty():
		return -1
	return int(item.get("price", -1)) if current_tab == ShopTab.BUY else int(item.get("unit_price", -1))


func _get_max_quantity(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	if current_tab == ShopTab.BUY:
		if not bool(item.get("unlocked", true)):
			return 0
		var price := _get_unit_price(item)
		if price <= 0:
			return 0
		var max_by_gold := GameManager.gold / price
		var max_by_space := InventoryManager.get_addable_count(str(item.get("item_id", "")))
		return maxi(mini(max_by_gold, max_by_space), 0)
	return maxi(int(item.get("quantity", 0)), 0)


func _get_validation() -> Dictionary:
	if selected_item_id == "" or selected_quantity <= 0:
		return {
			"success": false,
			"error_code": "INVALID_QUANTITY",
			"message": "请选择有效数量",
		}
	if current_tab == ShopTab.BUY:
		return EconomyManager.can_buy_item(selected_item_id, selected_quantity)
	return EconomyManager.can_sell_item(selected_item_id, selected_quantity)


func _refresh_confirm_state() -> void:
	quantity_label.text = "数量：%d" % selected_quantity
	var item := _find_item(selected_item_id)
	var price := _get_unit_price(item)
	total_price_label.text = "总价：%d 金" % (maxi(price, 0) * selected_quantity)
	confirm_button.text = "购买" if current_tab == ShopTab.BUY else "出售"
	if selected_item_id == "":
		confirm_button.disabled = true
		footer_hint_label.text = "请选择商品"
		return
	if selected_quantity <= 0:
		confirm_button.disabled = true
		footer_hint_label.text = _get_zero_quantity_reason(item)
		_update_all_row_trade_states()
		return
	var validation := _get_validation()
	confirm_button.disabled = not bool(validation.get("success", false))
	footer_hint_label.text = (
		"确认购买所选商品" if current_tab == ShopTab.BUY else "确认出售所选物品"
	) if not confirm_button.disabled else _message_for_result(validation)
	_update_all_row_trade_states()


func _get_zero_quantity_reason(item: Dictionary) -> String:
	if item.is_empty():
		return "请选择商品"
	if current_tab == ShopTab.SELL:
		return "库存不足"
	if not bool(item.get("unlocked", true)):
		return "Lv.%d 解锁" % int(item.get("unlock_level", 1))
	var price := _get_unit_price(item)
	if price <= 0:
		return "商品价格无效"
	if GameManager.gold < price:
		return "金币不足"
	if InventoryManager.get_addable_count(str(item.get("item_id", ""))) <= 0:
		return "背包空间不足"
	return "当前无法交易"


func _update_all_row_trade_states() -> void:
	for index in range(mini(row_views.size(), current_items.size())):
		_update_row_trade_state(row_views[index], current_items[index])


func _update_row_trade_state(row: Control, item: Dictionary) -> void:
	if current_tab != ShopTab.BUY:
		row.set_trade_state(true, true)
		return
	var price := _get_unit_price(item)
	var item_id := str(item.get("item_id", ""))
	row.set_trade_state(price > 0 and GameManager.gold >= price, InventoryManager.get_addable_count(item_id) > 0)


func _handle_transaction_feedback(result: Dictionary, emit_notification: bool = true) -> void:
	var success := bool(result.get("success", false))
	var message := _message_for_result(result)
	footer_hint_label.text = message
	if emit_notification:
		EventBus.ui_notification.emit(message, "success" if success else "warning")


func _message_for_result(result: Dictionary) -> String:
	var message := str(result.get("message", ""))
	if message != "":
		return message
	return ERROR_MESSAGES.get(str(result.get("error_code", "")), "交易失败")


func _apply_tab_buttons() -> void:
	buy_tab_button.button_pressed = current_tab == ShopTab.BUY
	sell_tab_button.button_pressed = current_tab == ShopTab.SELL


func _on_dim_background_gui_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("cancel"):
		close_panel()
		accept_event()


func _on_transaction_completed(result: Dictionary) -> void:
	refresh_gold()
	refresh_item_row(str(result.get("item_id", "")))
	if not _suppress_transaction_event_feedback:
		footer_hint_label.text = _message_for_result(result)


func _on_transaction_failed(result: Dictionary) -> void:
	if not _suppress_transaction_event_feedback:
		footer_hint_label.text = _message_for_result(result)
	_refresh_confirm_state()


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	refresh_gold()
	if current_tab == ShopTab.BUY:
		for item in current_items:
			var item_id := str(item.get("item_id", ""))
			if item_id != "":
				refresh_item_row(item_id)
		if selected_item_id != "":
			_refresh_selected_detail()


func _on_inventory_changed(_slot_index: int) -> void:
	if current_tab == ShopTab.SELL:
		rebuild_list()
	else:
		for item in current_items:
			var item_id := str(item.get("item_id", ""))
			if item_id != "":
				refresh_item_row(item_id)
	if selected_item_id != "":
		_refresh_selected_detail()


func _on_level_up(_new_level: int) -> void:
	if current_tab == ShopTab.BUY:
		rebuild_list()


func _on_crop_unlocked(_crop_id: String, _level: int) -> void:
	if current_tab == ShopTab.BUY:
		rebuild_list()


func _on_unlocks_changed(_unlocks: Dictionary) -> void:
	if current_tab == ShopTab.BUY:
		rebuild_list()


func _on_game_loaded(_slot: int, _metadata: Dictionary) -> void:
	refresh_gold()
	rebuild_list()
	clear_selection()
