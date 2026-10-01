@tool
extends Node2D
## 横にくり返せる仮の景色（山並み・しげみ・電柱）。width で一周する形にする。

enum Kind { HILLS, BUSHES }

@export var kind: Kind = Kind.HILLS
@export var width := 2560.0
@export var base_y := 600.0
@export var height := 160.0
@export var color := WorldPalette.HILL_FAR
@export var color_2 := WorldPalette.HILL_FAR_2


func _draw() -> void:
	match kind:
		Kind.HILLS:
			_hills(color_2, height * 1.15, 2, 0.7)
			_hills(color, height, 3, 0.0)
		Kind.BUSHES:
			_bushes()


func _hills(c: Color, h: float, waves: int, phase: float) -> void:
	var pts := PackedVector2Array()
	var steps := 96
	for i in steps + 1:
		var x := width * i / steps
		var t := TAU * x / width
		var y := base_y - h * (0.55 + 0.3 * sin(t * waves + phase) + 0.15 * sin(t * waves * 3 + phase * 2))
		pts.append(Vector2(x, y))
	pts.append(Vector2(width, base_y + 800))
	pts.append(Vector2(0, base_y + 800))
	draw_colored_polygon(pts, c)


func _bushes() -> void:
	var n := 7
	for i in n:
		var x := width * (i + 0.5) / n
		var r := height * (0.5 + 0.25 * sin(i * 2.3))
		draw_circle(Vector2(x, base_y), r, color)
		draw_circle(Vector2(x + r * 0.8, base_y + r * 0.2), r * 0.7, color_2)
	draw_rect(Rect2(0, base_y, width, 800), color)
