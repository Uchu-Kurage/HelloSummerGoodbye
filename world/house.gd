@tool
extends Node2D
## 祖父母の家。足もとが原点。軒先に風鈴（Furin）を吊るす。
## 絵は手描き風（Google Gemini で生成し、背景を切り抜いたもの）。

const HOUSE_TEX: Texture2D = preload("res://world/scenery/painted/prop_house.png")
const HOUSE_SCALE := 0.66
## 絵のいちばん下は透明な影なので、少し地面にしずめる
const HOUSE_SINK := 14.0
## 風鈴を吊るす場所（左の軒の下）
const FURIN_AT := Vector2(-262, -160)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var f := Furin.new()
	f.position = FURIN_AT
	add_child(f)


func _draw() -> void:
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 12.0 / 300.0))
	draw_circle(Vector2.ZERO, 300.0, Color(0.12, 0.16, 0.08, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sz := HOUSE_TEX.get_size() * HOUSE_SCALE
	draw_texture_rect(HOUSE_TEX, Rect2(Vector2(-sz.x / 2.0, -sz.y + HOUSE_SINK), sz), false)
