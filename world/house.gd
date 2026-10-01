@tool
extends Node2D
## 祖父母の家（仮）。足もとが原点。


func _draw() -> void:
	draw_rect(Rect2(-260, -260, 520, 260), WorldPalette.HOUSE_WALL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-320, -250), Vector2(0, -420), Vector2(320, -250)]), WorldPalette.HOUSE_ROOF)
	draw_rect(Rect2(-60, -150, 120, 150), WorldPalette.SIGN_POST)
	draw_rect(Rect2(-210, -200, 100, 70), WorldPalette.SIGN_BOARD)
	draw_rect(Rect2(110, -200, 100, 70), WorldPalette.SIGN_BOARD)
