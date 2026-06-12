extends Node2D
## Shop — PRD12 占位商店场景。

@onready var shop_panel: Control = $UILayer/ShopPanel


func _ready() -> void:
	if shop_panel.has_method("setup"):
		shop_panel.call("setup", self)
	if shop_panel.has_method("open_panel"):
		shop_panel.call_deferred("open_panel")
