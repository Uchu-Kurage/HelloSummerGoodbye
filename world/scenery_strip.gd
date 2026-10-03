@tool
extends Node2D
## 横にくり返せる景色（山並み・入道雲・田んぼ・電柱・木立ち）。width で一周する形にする。
## 山並み・入道雲・田んぼ・木立ちは手描き風の絵（Google Gemini で生成し、背景を切り抜いたもの。res://world/scenery/painted/、
## 切り抜きは tools/art/process_painted.py）。帯の絵は height の高さで、width にちょうど収まる枚数だけ並べる。
## 電柱と電線は図形で描く。時間帯の色は CanvasModulate が上からかける。出典は res://CREDITS.md。

enum Kind { HILLS, CLOUDS, FIELDS, WIRES, TREES }

const MOUNTAINS_TEX: Texture2D = preload("res://world/scenery/painted/mountains.png")
const PADDIES_TEX: Texture2D = preload("res://world/scenery/painted/paddies.png")
const TREES_TEX: Texture2D = preload("res://world/scenery/painted/trees.png")
const CLOUD_TEX: Array[Texture2D] = [
	preload("res://world/scenery/painted/cloud_tower.png"),
	preload("res://world/scenery/painted/cloud_wide.png"),
	preload("res://world/scenery/painted/cloud_small_1.png"),
	preload("res://world/scenery/painted/cloud_small_2.png"),
	preload("res://world/scenery/painted/cloud_small_3.png"),
]
## 雲：[絵（CLOUD_TEX の番号）, x（割合）, 底の高さ（base_y から）, 大きさ]。入道雲は底が山並みのうしろに沈む
const CLOUD_SPECS := [
	[0, 0.78, 70.0, 0.85],
	[1, 0.3, -90.0, 0.55],
	[2, 0.52, -250.0, 0.6],
	[3, 0.07, -210.0, 0.75],
	[4, 0.95, -270.0, 0.7],
]
## 帯の絵の下のふち（半透明）を、塗りつぶしと重ねる幅
const STRIP_OVERLAP := 6.0

@export var kind: Kind = Kind.HILLS
@export var width := 2560.0
## 帯の下の端（山並み・木立ち）／上の端（田んぼ）／雲の底の基準
@export var base_y := 600.0
@export var height := 160.0
## 帯の絵より下を塗る色
@export var color := WorldPalette.HILL_FAR


func _draw() -> void:
	match kind:
		Kind.HILLS:
			_strip(MOUNTAINS_TEX, base_y - height)
		Kind.CLOUDS:
			_clouds()
		Kind.FIELDS:
			_strip(PADDIES_TEX, base_y)
		Kind.WIRES:
			_wires()
		Kind.TREES:
			_strip(TREES_TEX, base_y - height)


## 帯の絵（高さ height）を top から描き、width にちょうど収まる枚数だけ横に並べる。下は color で塗りつぶす
func _strip(tex: Texture2D, top: float) -> void:
	var aspect := float(tex.get_width()) / tex.get_height()
	var n := maxi(1, roundi(width / (height * aspect)))
	var tile := width / n
	var bottom := top + height
	draw_rect(Rect2(0, bottom - STRIP_OVERLAP, width, 800 + STRIP_OVERLAP), color)
	for i in range(-1, n + 1):
		# つなぎ目に細い線が出ないよう、となりと少し重ねる
		draw_texture_rect(tex, Rect2(i * tile - 1.0, top, tile + 2.0, height), false)


## 雲：絵の雲を、大きさと高さをかえて置く（光は左上から）
func _clouds() -> void:
	for sp in CLOUD_SPECS:
		var tex := CLOUD_TEX[int(sp[0])]
		var sz := tex.get_size() * float(sp[3])
		var pos := Vector2(width * float(sp[1]) - sz.x * 0.5, base_y + float(sp[2]) - sz.y)
		draw_texture_rect(tex, Rect2(pos, sz), false)


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
