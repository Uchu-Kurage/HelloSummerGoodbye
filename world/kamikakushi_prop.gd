@tool
class_name KamikakushiProp
extends Node2D
## 神隠しルートの場所の小物。足もと（地面）が原点。
## 絵は Google Gemini で生成した水彩の絵（背景を切り抜いたもの。res://world/scenery/painted/。プロンプトは tools/art/prompts_kamikakushi.md）。
## 知らない村の明かり・山の上の草は図形で描く。
## 灯りの光（*_GLOW）は GlowLayer の下に置くと、夜でも暗くならない（異界でも色が抜けない）。
## 灯籠・狛犬・大木・さい銭箱・店の人の描き方は、かくれんぼと夜市の物々交換の画面でも使う。

enum Kind {
	HOKORA,         ## バス停の脇の、苔むした小さな祠
	STONE_LANTERN,  ## 石の灯籠
	KOMAINU,        ## 狛犬（台座つき）
	BIG_TREE,       ## しめ縄を巻いた大木
	STALL,          ## 夜市の屋台（青い提灯と、ふしぎな品物）
	VENDOR,         ## 顔の見えない店の人
	BLUE_LANTERNS,  ## 青い提灯の列（width の幅）
	BLUE_LANTERNS_GLOW,
	SUNFLOWERS,     ## ひまわりの列（width の幅）
	VILLAGE_LIGHTS, ## 山の上から見える、知らない村の明かり（GlowLayer の下に置く）
	HILLTOP,        ## 山の上のひらけた草はら（width の幅）
}

const P := preload("res://world/world_palette.gd")
const HOKORA_TEX: Texture2D = preload("res://world/scenery/painted/prop_hokora.png")
const STONE_LANTERN_TEX: Texture2D = preload("res://world/scenery/painted/prop_stone_lantern.png")
const KOMAINU_TEX: Texture2D = preload("res://world/scenery/painted/prop_komainu.png")
const BIG_TREE_TEX: Texture2D = preload("res://world/scenery/painted/prop_big_tree.png")
const SAISEN_TEX: Texture2D = preload("res://world/scenery/painted/prop_saisen.png")
const STALL_TEX: Texture2D = preload("res://world/scenery/painted/prop_yomise_stall.png")
const VENDOR_TEX: Texture2D = preload("res://world/scenery/painted/prop_yomise_vendor.png")
const SUNFLOWER_TEX: Array[Texture2D] = [
	preload("res://world/scenery/painted/sunflower_1.png"),
	preload("res://world/scenery/painted/sunflower_2.png"),
	preload("res://world/scenery/painted/sunflower_3.png"),
	preload("res://world/scenery/painted/sunflower_4.png"),
]
const LANTERN_TEX: Texture2D = preload("res://world/scenery/painted/lantern_blue.png")
## 青い提灯の絵：本体（上下の黒い輪まで）のまん中（絵の上から px）と、本体の高さ
const LANTERN_CENTER := 537.0
const LANTERN_BODY := 533.0
const LANTERN_SIZE := 46.0
## 祠の高さ（大きさの倍率 1.0 のとき）・屋台の高さ
const HOKORA_H := 150.0
const STALL_H := 270.0
const SHADOW := Color(0.12, 0.16, 0.08, 0.22)

@export var kind: Kind = Kind.HOKORA:
	set(v):
		kind = v
		queue_redraw()
## 横に広がるもの（提灯・ひまわり・草はら）の幅
@export var width := 600.0:
	set(v):
		width = v
		queue_redraw()
## 左右の向き（狛犬など）
@export var flip := false:
	set(v):
		flip = v
		queue_redraw()


func _ready() -> void:
	# 絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	match kind:
		Kind.HOKORA: draw_hokora(self, Vector2.ZERO, 1.0)
		Kind.STONE_LANTERN: draw_stone_lantern(self, Vector2.ZERO, 150.0)
		Kind.KOMAINU: draw_komainu(self, Vector2.ZERO, 120.0)
		# 絵の上のふちで葉が切れているので、上が画面の外に出るくらい大きく描く
		Kind.BIG_TREE: draw_big_tree(self, Vector2.ZERO, 720.0)
		Kind.STALL: _stall()
		Kind.VENDOR: draw_vendor(self, Vector2.ZERO, 170.0)
		Kind.BLUE_LANTERNS: _lanterns(false)
		Kind.BLUE_LANTERNS_GLOW: _lanterns(true)
		Kind.SUNFLOWERS: _sunflowers()
		Kind.VILLAGE_LIGHTS: _village_lights()
		Kind.HILLTOP: _hilltop()


static func _shadow(ci: CanvasItem, center: Vector2, radius: Vector2) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	ci.draw_circle(Vector2.ZERO, radius.x, SHADOW)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 絵を高さ h で、下のふちのまん中を foot にそろえて描く
static func draw_art(ci: CanvasItem, tex: Texture2D, foot: Vector2, h: float, tint := Color.WHITE) -> void:
	var w := tex.get_width() * h / tex.get_height()
	ci.draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false, tint)


## 苔むした小さな祠（石の台に、小さな木の社）。k は大きさの倍率
static func draw_hokora(ci: CanvasItem, foot: Vector2, k: float) -> void:
	_shadow(ci, foot + Vector2(0, -2), Vector2(80, 7) * k)
	draw_art(ci, HOKORA_TEX, foot + Vector2(0, 4), HOKORA_H * k)


## 石の灯籠
static func draw_stone_lantern(ci: CanvasItem, foot: Vector2, h: float) -> void:
	draw_art(ci, STONE_LANTERN_TEX, foot + Vector2(0, 4), h)


## 狛犬（台座つき。右を向いて座っている）
static func draw_komainu(ci: CanvasItem, foot: Vector2, h: float) -> void:
	draw_art(ci, KOMAINU_TEX, foot + Vector2(0, 4), h)


## しめ縄を巻いた大木（ご神木）
static func draw_big_tree(ci: CanvasItem, foot: Vector2, h: float) -> void:
	_shadow(ci, foot + Vector2(0, -2), Vector2(150, 12) * (h / 520.0))
	draw_art(ci, BIG_TREE_TEX, foot + Vector2(0, 6), h)


## さい銭箱（かくれんぼの画面で使う）
static func draw_saisen(ci: CanvasItem, foot: Vector2, h: float) -> void:
	draw_art(ci, SAISEN_TEX, foot + Vector2(0, 4), h)


## 顔の見えない店の人（顔は白くのっぺりして、目も口もない。手もとに台がある）
static func draw_vendor(ci: CanvasItem, foot: Vector2, h: float) -> void:
	draw_art(ci, VENDOR_TEX, foot, h)


func _stall() -> void:
	# 屋台の絵には、足もとの草と、ふしぎな品物（青いあめ玉のびん・お面・ひかる玉）が入っている
	draw_art(self, STALL_TEX, Vector2(0, 8), STALL_H)


func _lantern_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := maxi(2, int(width / 110))
	for i in n:
		var t := (i + 0.5) / n
		out.append(Vector2(width * t, -360 + 36.0 * 4.0 * t * (1.0 - t)))
	return out


func _lanterns(glow: bool) -> void:
	if glow:
		for p in _lantern_points():
			draw_circle(p, 50, P.BLUE_LANTERN_GLOW)
			draw_circle(p, 22, P.BLUE_LANTERN_GLOW)
		return
	# 電線は提灯の吊りひもの上の端にそろえる
	var k := LANTERN_SIZE / LANTERN_BODY
	var hang := LANTERN_CENTER * k
	var pts := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		pts.append(Vector2(width * t, -360.0 - hang + 36.0 * 4.0 * t * (1.0 - t)))
	draw_polyline(pts, P.WIRE, 2.0)
	var h := LANTERN_TEX.get_height() * k
	for p in _lantern_points():
		draw_art(self, LANTERN_TEX, p + Vector2(0, h - hang), h)


func _sunflowers() -> void:
	# 4本の絵を、高さを少しずつかえて並べる（8日目は色を抜くので、ふつうの色の絵のまま）
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var n := maxi(1, int(width / 110))
	for i in n:
		var x := width * (i + 0.5) / n + rng.randf_range(-14, 14)
		draw_art(self, SUNFLOWER_TEX[i % SUNFLOWER_TEX.size()], Vector2(x, 6), rng.randf_range(190, 240))


func _village_lights() -> void:
	# 谷のむこう、遠くの低いところに、ぽつぽつと明かり（あたたかい色と、青い色がまじる）
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 38:
		var p := Vector2(rng.randf_range(0, width), -150 - rng.randf_range(0, 90) - 40.0 * sin(rng.randf() * PI))
		var c := P.BLUE_LANTERN_GLOW if i % 3 == 0 else Color(1.0, 0.82, 0.5, 0.35)
		draw_circle(p, rng.randf_range(4, 9), c)
		draw_circle(p, 2.0, Color(c, 0.9))


func _hilltop() -> void:
	# 山の上のひらけた草はら。手前に背の低い草
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in int(width / 26):
		var x := rng.randf_range(0, width)
		var h := rng.randf_range(10, 26)
		draw_line(Vector2(x, 6), Vector2(x + rng.randf_range(-6, 6), 6 - h), P.GROUND_DARK, 2.0)
