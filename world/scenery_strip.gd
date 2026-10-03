@tool
extends Node2D
## 横にくり返せる景色（山並み・木立ち・しげみ・雲・田んぼ・電柱）。width で一周する形にする。
## 山並み・木・雲は Kenney「Background Elements」（CC0）の絵を使う。白い影絵にしてあるので、color をかけて色をつける
## （時間帯の色は CanvasModulate が上からかける）。しげみ・田んぼ・電柱・入道雲は図形で描く。出典は res://CREDITS.md。

enum Kind { HILLS, BUSHES, CLOUDS, FIELDS, WIRES, TREES }

const HILLS_TEX: Texture2D = preload("res://world/scenery/hills_1.png")
const HILLS_TEX_2: Texture2D = preload("res://world/scenery/hills_2.png")
const TREE_TEX: Array[Texture2D] = [
	preload("res://world/scenery/tree_round.png"),
	preload("res://world/scenery/tree_cedar.png"),
	preload("res://world/scenery/tree_bushy.png"),
]
const CLOUD_TEX: Array[Texture2D] = [
	preload("res://world/scenery/cloud_1.png"),
	preload("res://world/scenery/cloud_4.png"),
	preload("res://world/scenery/cloud_6.png"),
	preload("res://world/scenery/cloud_2.png"),
	preload("res://world/scenery/cloud_8.png"),
]
## 絵の山並みの下のふち（半透明）を、塗りつぶしと重ねる幅
const HILL_OVERLAP := 6.0

@export var kind: Kind = Kind.HILLS
@export var width := 2560.0
@export var base_y := 600.0
@export var height := 160.0
@export var color := WorldPalette.HILL_FAR
@export var color_2 := WorldPalette.HILL_FAR_2


func _draw() -> void:
	match kind:
		Kind.HILLS:
			_hill_strip(HILLS_TEX_2, color_2, height * 1.3, 0.37)
			_hill_strip(HILLS_TEX, color, height, 0.0)
		Kind.BUSHES:
			_bushes()
		Kind.CLOUDS:
			_clouds()
		Kind.FIELDS:
			_fields()
		Kind.WIRES:
			_wires()
		Kind.TREES:
			_trees()


## 絵の山並みを width にちょうど収まる枚数だけ横に並べる。phase（0〜1）で1枚ぶんの中をずらす
func _hill_strip(tex: Texture2D, c: Color, h: float, phase: float) -> void:
	var aspect := float(tex.get_width()) / tex.get_height()
	var n := maxi(1, roundi(width / (h * aspect)))
	var tile := width / n
	var top := base_y - h
	for i in range(-1, n + 1):
		# つなぎ目に細い線が出ないよう、となりと少し重ねる
		draw_texture_rect(tex, Rect2((i + phase) * tile - 1.0, top, tile + 2.0, h), false, c)
	draw_rect(Rect2(0, base_y - HILL_OVERLAP, width, 800 + HILL_OVERLAP), c)


## 木立ち：丸い木・杉・こんもりした木を、すこしずつ間をかえて並べる（同じ並びで一周する）
func _trees() -> void:
	var n := 9
	for i in n:
		var tex := TREE_TEX[(i * 2 + i / 3) % TREE_TEX.size()]
		var h := height * (0.75 + 0.25 * (0.5 + 0.5 * sin(i * 2.7)))
		var w := h * tex.get_width() / tex.get_height()
		var x := width * (i + 0.5 + 0.3 * sin(i * 1.9)) / n
		var c := color if i % 2 == 0 else color_2
		draw_texture_rect(tex, Rect2(x - w * 0.5, base_y - h, w, h), false, c)


func _bushes() -> void:
	var n := 7
	for i in n:
		var x := width * (i + 0.5) / n
		var r := height * (0.5 + 0.25 * sin(i * 2.3))
		draw_circle(Vector2(x, base_y), r, color)
		draw_circle(Vector2(x + r * 0.8, base_y + r * 0.2), r * 0.7, color_2)
	draw_rect(Rect2(0, base_y, width, 800), color)


## 雲：絵の雲を高さと大きさをかえて散らす。いちばん大きいのは入道雲として図形で描く
func _clouds() -> void:
	var specs := [[0.33, -170.0, 0.9], [0.58, -60.0, 1.25], [0.95, -210.0, 0.75], [0.24, 10.0, 1.1], [0.43, -260.0, 0.6]]
	for i in specs.size():
		var tex := CLOUD_TEX[i % CLOUD_TEX.size()]
		var sp: Array = specs[i]
		var sz := tex.get_size() * float(sp[2])
		var pos := Vector2(width * float(sp[0]) - sz.x * 0.5, base_y + float(sp[1]) - sz.y)
		draw_texture_rect(tex, Rect2(pos, sz), false, WorldPalette.CLOUD)
	_cumulus()


## 入道雲：もこもこの丸を積み上げ、底は平らにする。光は左上から：影の側は青みの灰色、日の当たる側は白（3段の重ね）
func _cumulus() -> void:
	# 地平線の上にそびえる大きな入道雲（底は山並みのうしろに沈む）
	_draw_cumulus(width * 0.8, base_y + 90.0, 1.3, TOWER_BUMPS)
	_draw_cumulus(width * 0.14, base_y, 0.75, SMALL_BUMPS)


const SMALL_BUMPS := [[-150, -40, 70], [-70, -110, 95], [30, -170, 115], [130, -95, 90], [210, -40, 65], [60, -260, 85]]
const TOWER_BUMPS := [
	[-260, -50, 80], [-150, -70, 100], [-30, -80, 110], [100, -70, 105], [220, -50, 85],
	[-120, -170, 100], [0, -200, 120], [120, -170, 95],
	[-60, -300, 105], [60, -310, 100], [-110, -380, 65], [-10, -400, 95], [90, -390, 70],
	[-70, -470, 55], [0, -480, 80], [70, -465, 60],
]


func _draw_cumulus(cx: float, bottom: float, k: float, bumps: Array) -> void:
	var left := INF
	var right := -INF
	for b in bumps:
		left = minf(left, cx + (b[0] - b[2] * 0.8) * k)
		right = maxf(right, cx + (b[0] + b[2] * 0.8) * k)
	# 影（いちばん外側）と、平らな底
	for b in bumps:
		draw_circle(Vector2(cx + b[0] * k, bottom + b[1] * k), b[2] * k, WorldPalette.CLOUD_SHADOW)
	draw_rect(Rect2(left, bottom - 70 * k, right - left, 70 * k), WorldPalette.CLOUD_SHADOW)
	# 中間の明るさ → 日の当たる面 → いちばん明るいところ。少しずつ左上へずらして重ねる
	for b in bumps:
		var r: float = b[2] * k
		draw_circle(Vector2(cx + b[0] * k - r * 0.08, bottom + b[1] * k - r * 0.1), r * 0.9, WorldPalette.CLOUD_SHADE)
	for b in bumps:
		var r: float = b[2] * k
		draw_circle(Vector2(cx + b[0] * k - r * 0.18, bottom + b[1] * k - r * 0.22), r * 0.72, WorldPalette.CLOUD)
	# 底のあたりはかげる
	draw_rect(Rect2(left, bottom - 34 * k, right - left, 34 * k), Color(WorldPalette.CLOUD_SHADOW, 0.85))


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
