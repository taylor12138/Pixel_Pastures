extends PanelContainer
## ShopItemRow — 购买/出售列表共用商品行。

signal row_clicked(item_id: String)

enum RowMode {
	BUY,
	SELL,
}

const TYPE_COLORS := {
	"seed": Color("#78B86B"),
	"harvest": Color("#D9A441"),
	"consumable": Color("#916BB3"),
	"decoration": Color("#B58A52"),
	"unknown": Color("#686868"),
}

@export var mode: RowMode = RowMode.BUY

var item_id: String = ""
var crop_id: String = ""
var item_type: String = "unknown"
var unit_price: int = 0
var owned_count: int = 0
var sellable_quantity: int = 0
var is_unlocked: bool = true
var unlock_level: int = 1
var is_selected: bool = false
var is_affordable: bool = true
var has_capacity: bool = true

@onready var type_color: ColorRect = $Margin/Content/TypeColor
@onready var name_label: Label = $Margin/Content/NameLabel
@onready var price_label: Label = $Margin/Content/PriceLabel
@onready var count_label: Label = $Margin/Content/CountLabel
@onready var lock_label: Label = $Margin/Content/LockLabel


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visual()


func set_buy_data(data: Dictionary) -> void:
	mode = RowMode.BUY
	item_id = str(data.get("item_id", ""))
	crop_id = str(data.get("crop_id", ""))
	item_type = str(data.get("type", "unknown"))
	if item_type == "":
		item_type = "unknown"
	unit_price = int(data.get("price", -1))
	owned_count = maxi(int(data.get("owned_count", 0)), 0)
	sellable_quantity = 0
	is_unlocked = bool(data.get("unlocked", true))
	unlock_level = maxi(int(data.get("unlock_level", 1)), 1)
	is_affordable = bool(data.get("can_afford_one", true))
	name_label.text = str(data.get("name", item_id if item_id != "" else "未知商品"))
	_refresh_visual()


func set_sell_data(data: Dictionary) -> void:
	mode = RowMode.SELL
	item_id = str(data.get("item_id", ""))
	crop_id = str(data.get("crop_id", ""))
	item_type = "harvest"
	unit_price = int(data.get("unit_price", -1))
	owned_count = 0
	sellable_quantity = maxi(int(data.get("quantity", 0)), 0)
	is_unlocked = true
	unlock_level = 1
	is_affordable = true
	has_capacity = true
	name_label.text = str(data.get("name", item_id if item_id != "" else "未知物品"))
	_refresh_visual()


func set_selected(value: bool) -> void:
	is_selected = value
	_refresh_visual()


func set_trade_state(affordable: bool, capacity_available: bool) -> void:
	is_affordable = affordable
	has_capacity = capacity_available
	_refresh_visual()


func is_selectable() -> bool:
	return item_id != ""


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	type_color.color = TYPE_COLORS.get(item_type, TYPE_COLORS["unknown"])
	price_label.text = "%d 金" % unit_price if unit_price > 0 else "价格无效"
	count_label.text = "已有 %d" % owned_count if mode == RowMode.BUY else "库存 %d" % sellable_quantity
	lock_label.visible = mode == RowMode.BUY and not is_unlocked
	lock_label.text = "Lv.%d 解锁" % unlock_level

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#25302A") if not is_selected else Color("#405846")
	style.border_width_left = 2 if is_selected else 1
	style.border_width_top = 2 if is_selected else 1
	style.border_width_right = 2 if is_selected else 1
	style.border_width_bottom = 2 if is_selected else 1
	style.border_color = Color("#E9E1B3") if is_selected else Color("#4D5A50")
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	add_theme_stylebox_override("panel", style)

	var dimmed := not is_unlocked
	name_label.modulate = Color(0.6, 0.6, 0.6, 1.0) if dimmed else Color.WHITE
	type_color.modulate = Color(0.5, 0.5, 0.5, 1.0) if dimmed else Color.WHITE
	price_label.add_theme_color_override(
		"font_color",
		Color("#E16B62") if mode == RowMode.BUY and (not is_affordable or not has_capacity) else Color("#F2D35C")
	)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and is_selectable():
			row_clicked.emit(item_id)
			accept_event()


func _on_mouse_entered() -> void:
	if not is_selected:
		modulate = Color(1.08, 1.08, 1.08, 1.0)


func _on_mouse_exited() -> void:
	modulate = Color.WHITE
