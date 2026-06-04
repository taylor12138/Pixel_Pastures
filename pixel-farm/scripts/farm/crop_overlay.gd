extends Node2D
## CropOverlay — PRD10 作物阶段占位绘制。

var farm_grid_manager: Node = null

var _stage_colors := {
	0: Color("#E9C46A"),
	1: Color("#7BC96F"),
	2: Color("#2EAD4B"),
	3: Color("#FFD447"),
	4: Color("#7A7A7A"),
}


func setup(grid_manager: Node) -> void:
	farm_grid_manager = grid_manager
	queue_redraw()


func _draw() -> void:
	if farm_grid_manager == null or not has_node("/root/CropManager"):
		return
	var crops: Dictionary = CropManager.get_all_crops()
	for tile_pos in crops.keys():
		if not tile_pos is Vector2i:
			continue
		var crop_data: Dictionary = crops[tile_pos]
		var center: Vector2 = farm_grid_manager.grid_to_world_center(tile_pos)
		var stage := int(crop_data.get("stage", CropManager.CropStage.SEED))
		var watered := bool(crop_data.get("watered", false))
		var color: Color = _stage_colors.get(stage, Color.WHITE)
		draw_circle(center, 4.5, color)
		if watered:
			draw_arc(center, 7.0, 0.0, TAU, 20, Color("#55A8FF"), 2.0)
		if stage == CropManager.CropStage.MATURE:
			var rect := Rect2(center - Vector2(7, 7), Vector2(14, 14))
			draw_rect(rect, Color("#FFD447"), false, 1.5)
		elif stage == CropManager.CropStage.WITHERED:
			draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), Color("#2F2F2F"), 1.5)
			draw_line(center + Vector2(5, -5), center + Vector2(-5, 5), Color("#2F2F2F"), 1.5)
