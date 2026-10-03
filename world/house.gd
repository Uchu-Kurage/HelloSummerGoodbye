@tool
extends Node2D
## 祖父母の家（仮）。足もとが原点。軒先に風鈴（Furin）を吊るす。

## 風鈴を吊るす場所（屋根のふちの下）
const FURIN_AT := Vector2(-236, -244)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var f := Furin.new()
	f.position = FURIN_AT
	add_child(f)


func _draw() -> void:
	draw_rect(Rect2(-260, -260, 520, 260), WorldPalette.HOUSE_WALL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-320, -250), Vector2(0, -420), Vector2(320, -250)]), WorldPalette.HOUSE_ROOF)
	draw_rect(Rect2(-60, -150, 120, 150), WorldPalette.SIGN_POST)
	draw_rect(Rect2(-210, -200, 100, 70), WorldPalette.SIGN_BOARD)
	draw_rect(Rect2(110, -200, 100, 70), WorldPalette.SIGN_BOARD)
