@tool
extends Node2D
## 横にくり返せる仮の景色（山並み・しげみ・電柱）。width で一周する形にする。

enum Kind { HILLS, BUSHES, CLOUDS, FIELDS, WIRES }

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
		Kind.CLOUDS:
			_clouds()
		Kind.FIELDS:
			_fields()
		Kind.WIRES:
			_wires()


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


## 入道雲：もこもこの丸を積み上げ、底は平らにする
func _clouds() -> void:
	var specs := [[0.14, 0.75], [0.52, 0.45], [0.8, 0.6]]
	for sp in specs:
		var cx: float = width * sp[0]
		var k: float = sp[1]
		var bottom := base_y
		var bumps := [[-150, -40, 70], [-70, -110, 95], [30, -170, 115], [130, -95, 90], [210, -40, 65], [60, -260, 85]]
		for b in bumps:
			draw_circle(Vector2(cx + b[0] * k, bottom + b[1] * k + 6), b[2] * k, WorldPalette.CLOUD_SHADE)
		for b in bumps:
			draw_circle(Vector2(cx + b[0] * k, bottom + b[1] * k), b[2] * k * 0.94, WorldPalette.CLOUD)
		# 底を平らにそろえる
		draw_rect(Rect2(cx - 150 * k, bottom - 90 * k, 360 * k, 98 * k), WorldPalette.CLOUD)


## 田んぼ：あぜ道で区切られた、すじのある緑の帯
func _fields() -> void:
	draw_rect(Rect2(0, base_y, width, height + 800), WorldPalette.PADDY)
	var rows := 5
	for r in rows:
		var y := base_y + height * (r + 0.5) / rows
		draw_line(Vector2(0, y), Vector2(width, y), WorldPalette.PADDY_ROW, 2.0)
	var plots := 4
	for i in plots:
		var x := width * i / plots
		draw_rect(Rect2(x, base_y, 6, height), WorldPalette.PADDY_PATH)


## 遠くの電柱と、たるんだ電線（width ごとに電柱が1本）
func _wires() -> void:
	var top := base_y - height
	for side in [0.0, width]:
		draw_rect(Rect2(side - 3, top, 6, height), WorldPalette.POLE_FAR)
		draw_rect(Rect2(side - 22, top + 14, 44, 4), WorldPalette.POLE_FAR)
	for k in 2:
		var y0 := top + 16 + k * 2.0
		var sag := 34.0 + k * 6.0
		var pts := PackedVector2Array()
		var steps := 32
		for i in steps + 1:
			var t := float(i) / steps
			pts.append(Vector2(width * t, y0 + sag * 4.0 * t * (1.0 - t)))
		draw_polyline(pts, WorldPalette.WIRE, 1.5, true)
