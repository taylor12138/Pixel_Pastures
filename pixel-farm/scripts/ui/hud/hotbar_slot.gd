extends PanelContainer
## HotbarSlot — 常驻快捷栏中的单个只读物品槽位。

signal slot_clicked(slot_index: int)

const TYPE_COLORS := {
	"tool": Color("#70889A"),
	"seed": Color("#78B86B"),
	"harvest": Color("#D9A441"),
	"consumable": Color("#916BB3"),
	"decoration": Color("#B58A52"),
	"unknown": Color("#686868"),
}

@export var slot_index: int = 0

var item_id: String = ""
var item_type: String = "unknown"
var quantity: int = 0
var is_selected: bool = false
var item_data: Dictionary = {}

@onready var item_color: ColorRect = $Margin/Stack/ItemColor
@onready var item_label: Label = $Margin/Stack/ItemLabel
@onready var quantity_label: Label = $Margin/Stack/QuantityLabel
@onready var hotkey_label: Label = $Margin/Stack/HotkeyBadge/HotkeyLabel


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	_refresh_visual()


func setup(index: int) -> void:
	slot_index = index
	set_hotkey_number(index + 1)


func set_slot_data(data: Variant) -> void:
	item_id = ""
	item_type = "unknown"
	quantity = 0
	item_data = {}
	if data is Dictionary:
		item_id = str(data.get("item_id", ""))
		quantity = maxi(int(data.get("quantity", 0)), 0)
		if item_id != "":
			item_data = DataManager.get_item(item_id)
			item_type = str(item_data.get("type", "unknown"))
			if item_type == "":
				item_type = "unknown"
	_refresh_visual()


func set_selected(value: bool) -> void:
	is_selected = value
	_refresh_visual()


func set_hotkey_number(num: int) -> void:
	if is_node_ready():
		hotkey_label.text = str(num)


func get_displayed_item_id() -> String:
	return item_id


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(slot_index)
			accept_event()


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	var has_item := item_id != "" and quantity > 0
	item_color.visible = has_item
	item_label.visible = has_item
	quantity_label.visible = has_item and quantity > 1
	if has_item:
		item_color.color = TYPE_COLORS.get(item_type, TYPE_COLORS["unknown"])
		item_label.text = _short_item_name()
		quantity_label.text = str(quantity)
		tooltip_text = "%s ×%d" % [_display_name(), quantity]
	else:
		item_label.text = ""
		quantity_label.text = ""
		tooltip_text = "空槽位"
	hotkey_label.text = str(slot_index + 1)
	add_theme_stylebox_override("panel", _make_panel_style(has_item))


func _make_panel_style(has_item: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#343B38") if has_item else Color("#262B2A")
	style.border_color = Color("#F5E7A1") if is_selected else Color("#647069")
	style.set_border_width_all(2 if is_selected else 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _display_name() -> String:
	return str(item_data.get("name", item_id))


func _short_item_name() -> String:
	return _display_name().left(2)
