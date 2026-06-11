extends PanelContainer
## InventorySlot — 单个背包槽位的显示与拖放入口。

signal slot_clicked(slot_index: int)
signal slot_double_clicked(slot_index: int)
signal slot_context_requested(slot_index: int)
signal drag_finished(from_index: int, to_index: int, success: bool)

const TYPE_COLORS := {
	"seed": Color("#78B86B"),
	"harvest": Color("#D9A441"),
	"tool": Color("#70889A"),
	"consumable": Color("#916BB3"),
	"decoration": Color("#B58A52"),
	"unknown": Color("#686868"),
}

@export var slot_index: int = -1

var slot_data: Variant = null
var item_data: Dictionary = {}
var is_hotbar_slot: bool = false
var is_hotbar_selected: bool = false
var is_detail_selected: bool = false
var filtered_out: bool = false
var _drag_source: bool = false
var _drop_state: int = 0

@onready var item_color: ColorRect = $Margin/Stack/ItemColor
@onready var item_label: Label = $Margin/Stack/ItemLabel
@onready var quantity_label: Label = $Margin/Stack/QuantityLabel
@onready var hotbar_label: Label = $HotbarLabel


func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visual()


func setup(index: int) -> void:
	slot_index = index
	is_hotbar_slot = index >= 0 and index < InventoryManager.HOTBAR_SIZE
	if is_node_ready():
		_refresh_visual()


func set_slot_data(data: Variant, metadata: Dictionary) -> void:
	slot_data = data.duplicate(true) if data is Dictionary else null
	item_data = metadata.duplicate(true)
	_refresh_visual()


func set_filtered_out(value: bool) -> void:
	filtered_out = value
	_refresh_visual()


func set_hotbar_selected(value: bool) -> void:
	is_hotbar_selected = value
	_refresh_visual()


func set_detail_selected(value: bool) -> void:
	is_detail_selected = value
	_refresh_visual()


func clear_display() -> void:
	slot_data = null
	item_data = {}
	filtered_out = false
	_refresh_visual()


func get_displayed_item_id() -> String:
	return str(slot_data.get("item_id", "")) if slot_data is Dictionary else ""


func is_item_content_visible() -> bool:
	return slot_data is Dictionary and not filtered_out


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not slot_data is Dictionary or filtered_out:
		return null
	_drag_source = true
	_refresh_visual()
	var preview := _build_drag_preview()
	set_drag_preview(preview)
	return {
		"source": "inventory",
		"slot_index": slot_index,
		"item_id": str(slot_data.get("item_id", "")),
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid: bool = (
		data is Dictionary
		and data.get("source", "") == "inventory"
		and int(data.get("slot_index", -1)) >= 0
		and int(data.get("slot_index", -1)) != slot_index
	)
	_drop_state = 1 if valid else -1
	_refresh_visual()
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_index := int(data.get("slot_index", -1))
	var success := false
	if from_index >= 0 and from_index != slot_index:
		success = InventoryManager.smart_place(from_index, slot_index)
	_drag_source = false
	_drop_state = 0
	_refresh_visual()
	drag_finished.emit(from_index, slot_index, success)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_source = false
		_drop_state = 0
		if is_node_ready():
			_refresh_visual()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				slot_double_clicked.emit(slot_index)
			else:
				slot_clicked.emit(slot_index)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			slot_context_requested.emit(slot_index)
			accept_event()


func _on_mouse_entered() -> void:
	tooltip_text = _build_tooltip()


func _on_mouse_exited() -> void:
	_drop_state = 0
	_refresh_visual()


func _build_drag_preview() -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(40, 40)
	var label := Label.new()
	label.text = _short_item_name()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	preview.add_child(label)
	var style := StyleBoxFlat.new()
	style.bg_color = _get_item_color()
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	preview.add_theme_stylebox_override("panel", style)
	return preview


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	var has_visible_item := slot_data is Dictionary and not filtered_out
	item_color.visible = has_visible_item
	item_label.visible = has_visible_item
	quantity_label.visible = has_visible_item and int(slot_data.get("quantity", 0)) > 1
	if has_visible_item:
		item_color.color = _get_item_color()
		item_label.text = _short_item_name()
		quantity_label.text = str(slot_data.get("quantity", 0))
	else:
		item_label.text = ""
		quantity_label.text = ""
	hotbar_label.visible = is_hotbar_slot
	hotbar_label.text = str(slot_index + 1) if is_hotbar_slot else ""
	modulate.a = 0.45 if filtered_out else (0.55 if _drag_source else 1.0)
	add_theme_stylebox_override("panel", _make_panel_style())


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#262B2A") if slot_data == null else Color("#343B38")
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	var border_color := Color("#59615D")
	var border_width := 1
	if _drop_state > 0:
		border_color = Color("#78D67B")
		border_width = 2
	elif _drop_state < 0:
		border_color = Color("#E36B62")
		border_width = 2
	elif is_hotbar_selected:
		border_color = Color("#F2D35C")
		border_width = 2
	elif is_detail_selected:
		border_color = Color.WHITE
		border_width = 2
	elif is_hotbar_slot:
		border_color = Color("#79A9D1")
	style.border_color = border_color
	style.set_border_width_all(border_width)
	return style


func _get_item_color() -> Color:
	return TYPE_COLORS.get(str(item_data.get("type", "unknown")), TYPE_COLORS["unknown"])


func _short_item_name() -> String:
	var name := str(item_data.get("name", get_displayed_item_id()))
	return name.left(2)


func _build_tooltip() -> String:
	if not slot_data is Dictionary:
		return "空槽位"
	var name := str(item_data.get("name", get_displayed_item_id()))
	var quantity := int(slot_data.get("quantity", 0))
	if filtered_out:
		return "%s ×%d（当前筛选隐藏）" % [name, quantity]
	return "%s ×%d" % [name, quantity]
