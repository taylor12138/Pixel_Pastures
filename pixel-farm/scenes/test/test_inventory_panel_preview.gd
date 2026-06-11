extends Node
## InventoryPanel 视觉预览场景。

@onready var panel: Control = $InventoryPanel


func _ready() -> void:
	GameManager.start_new_game("背包预览")
	InventoryManager.import_save_data({
		"slots": [
			{"item_id": "seed_carrot", "quantity": 12},
			{"item_id": "seed_tomato", "quantity": 5},
			{"item_id": "watering_can", "quantity": 1},
			{"item_id": "harvest_carrot", "quantity": 24},
			{"item_id": "fertilizer", "quantity": 8},
			{"item_id": "fence_wood", "quantity": 16},
			{"item_id": "harvest_pumpkin", "quantity": 3},
			null,
			{"item_id": "stone_path", "quantity": 20},
		],
		"selected_hotbar": 0,
	})
	panel.open_panel()
	panel.select_slot(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("/tmp/inventory-panel-preview.png")
	get_tree().quit()
