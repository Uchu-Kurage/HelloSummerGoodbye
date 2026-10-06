@tool
class_name KamikakushiProp
extends Node2D
## 神隠しルートの場所の小物。足もと（地面）が原点。
## いまは図形で描いた仮の絵（本番の水彩の絵のプロンプトは tools/art/prompts_kamikakushi.md）。
## 灯りの光（*_GLOW）は GlowLayer の下に置くと、夜でも暗くならない（異界でも色が抜けない）。
## 灯籠・狛犬・大木の描き方は、かくれんぼの画面（ui/kakurenbo_game.gd）でも使う。

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
const STONE := Color("#A7A39A")
const STONE_DARK := Color("#7C786F")
const MOSS := Color("#6F8A4E")
const TRUNK := Color("#5E4A3A")
const LEAF := Color("#4E6A44")
const LEAF_DARK := Color("#3E5638")
const ROPE := Color("#D9C79A")
const SHIDE := Color("#F4F1E8")
const VENDOR := Color("#2E3446")
const VENDOR_FACE := Color("#D9D6CC")
const STALL_CLOTH := Color("#3E5878")
const STALL_WOOD := Color("#5E4A3A")
const SUNFLOWER := Color("#E8B83A")
const SUNFLOWER_CORE := Color("#5E4430")
const STEM := Color("#6E8A4A")
const LANTERN_TEX: Texture2D = preload("res://world/scenery/painted/lantern_1.png")
## 提灯の絵：本体のまん中（絵の上から px）と、本体の高さ（scenery_prop.gd と同じ）
const LANTERN_CENTER := 289.0
const LANTERN_BODY := 234.0
const LANTERN_SIZE := 44.0
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


func _draw() -> void:
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	match kind:
		Kind.HOKORA: draw_hokora(self, Vector2.ZERO, 1.0)
		Kind.STONE_LANTERN: draw_stone_lantern(self, Vector2.ZERO, 150.0)
		Kind.KOMAINU: draw_komainu(self, Vector2.ZERO, 110.0)
		Kind.BIG_TREE: draw_big_tree(self, Vector2.ZERO, 520.0)
		Kind.STALL: _stall()
		Kind.VENDOR: draw_vendor(self, Vector2.ZERO, 150.0)
		Kind.BLUE_LANTERNS: _lanterns(false)
		Kind.BLUE_LANTERNS_GLOW: _lanterns(true)
		Kind.SUNFLOWERS: _sunflowers()
		Kind.VILLAGE_LIGHTS: _village_lights()
		Kind.HILLTOP: _hilltop()


static func _shadow(ci: CanvasItem, center: Vector2, radius: Vector2) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	ci.draw_circle(Vector2.ZERO, radius.x, SHADOW)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _poly(ci: CanvasItem, pts: Array, c: Color, at := Vector2.ZERO, k := 1.0) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(at + (p as Vector2) * k)
	ci.draw_colored_polygon(out, c)


## 苔むした小さな祠（石の台に、小さな木の社。鈴をつるしていた跡）
static func draw_hokora(ci: CanvasItem, foot: Vector2, k: float) -> void:
	_shadow(ci, foot + Vector2(0, -2), Vector2(70, 7) * k)
	# 石の台
	_poly(ci, [Vector2(-56, 0), Vector2(56, 0), Vector2(50, -30), Vector2(-50, -30)], STONE_DARK, foot, k)
	_poly(ci, [Vector2(-46, -30), Vector2(46, -30), Vector2(42, -46), Vector2(-42, -46)], STONE, foot, k)
	# 社
	ci.draw_rect(Rect2(foot + Vector2(-32, -104) * k, Vector2(64, 58) * k), P.WOOD_DARK)
	ci.draw_rect(Rect2(foot + Vector2(-20, -92) * k, Vector2(40, 40) * k), Color("#2E2620"))
	ci.draw_line(foot + Vector2(0, -92) * k, foot + Vector2(0, -52) * k, P.WOOD, 3.0 * k)
	# 屋根
	_poly(ci, [Vector2(-50, -100), Vector2(50, -100), Vector2(0, -140)], Color("#5A544E"), foot, k)
	_poly(ci, [Vector2(-54, -100), Vector2(54, -100), Vector2(48, -94), Vector2(-48, -94)], Color("#47423E"), foot, k)
	# 苔
	for m in [[-40, -32, 10], [30, -44, 8], [-24, -128, 9], [18, -118, 7], [44, -6, 8], [-50, -8, 6]]:
		ci.draw_circle(foot + Vector2(m[0], m[1]) * k, m[2] * k, MOSS)
	# 色あせた赤い布
	_poly(ci, [Vector2(-12, -46), Vector2(12, -46), Vector2(0, -32)], Color("#A8574A"), foot, k)


## 石の灯籠
static func draw_stone_lantern(ci: CanvasItem, foot: Vector2, h: float) -> void:
	var k := h / 150.0
	_shadow(ci, foot + Vector2(0, -2), Vector2(34, 5) * k)
	ci.draw_rect(Rect2(foot + Vector2(-26, -14) * k, Vector2(52, 14) * k), STONE_DARK)
	ci.draw_rect(Rect2(foot + Vector2(-10, -70) * k, Vector2(20, 56) * k), STONE)
	ci.draw_rect(Rect2(foot + Vector2(-22, -80) * k, Vector2(44, 10) * k), STONE_DARK)
	ci.draw_rect(Rect2(foot + Vector2(-18, -112) * k, Vector2(36, 32) * k), STONE)
	ci.draw_rect(Rect2(foot + Vector2(-9, -104) * k, Vector2(18, 16) * k), Color("#3E3A36"))
	_poly(ci, [Vector2(-34, -112), Vector2(34, -112), Vector2(16, -136), Vector2(-16, -136)], STONE_DARK, foot, k)
	ci.draw_circle(foot + Vector2(0, -142) * k, 8 * k, STONE)
	ci.draw_circle(foot + Vector2(-20, -18) * k, 6 * k, MOSS)


## 狛犬（台座つき。右を向いて座っている）
static func draw_komainu(ci: CanvasItem, foot: Vector2, h: float) -> void:
	var k := h / 110.0
	_shadow(ci, foot + Vector2(0, -2), Vector2(42, 6) * k)
	ci.draw_rect(Rect2(foot + Vector2(-38, -30) * k, Vector2(76, 30) * k), STONE_DARK)
	# 体（座った後ろ足）と前足
	_poly(ci, [Vector2(-30, -30), Vector2(-30, -62), Vector2(-14, -80), Vector2(10, -78), Vector2(16, -30)], STONE, foot, k)
	ci.draw_rect(Rect2(foot + Vector2(8, -66) * k, Vector2(12, 36) * k), STONE)
	# 頭とたてがみ
	ci.draw_circle(foot + Vector2(10, -88) * k, 18 * k, STONE)
	for c in [Vector2(-6, -98), Vector2(-8, -80), Vector2(0, -106), Vector2(-14, -90)]:
		ci.draw_circle(foot + c * k, 9 * k, STONE_DARK)
	ci.draw_circle(foot + Vector2(18, -92) * k, 3 * k, Color("#3E3A36"))
	ci.draw_line(foot + Vector2(20, -80) * k, foot + Vector2(28, -82) * k, Color("#3E3A36"), 2.0 * k)
	# しっぽ
	ci.draw_circle(foot + Vector2(-34, -70) * k, 10 * k, STONE_DARK)
	ci.draw_circle(foot + Vector2(-26, -28) * k, 7 * k, MOSS)


## しめ縄を巻いた大木（ご神木）
static func draw_big_tree(ci: CanvasItem, foot: Vector2, h: float) -> void:
	var k := h / 520.0
	_shadow(ci, foot + Vector2(0, -2), Vector2(130, 12) * k)
	_poly(ci, [Vector2(-70, 0), Vector2(70, 0), Vector2(46, -40), Vector2(40, -330), Vector2(-40, -330), Vector2(-46, -40)], TRUNK, foot, k)
	ci.draw_line(foot + Vector2(-12, -40) * k, foot + Vector2(-16, -300) * k, Color("#4A3A2E"), 4.0 * k)
	ci.draw_line(foot + Vector2(18, -60) * k, foot + Vector2(14, -280) * k, Color("#4A3A2E"), 3.0 * k)
	for c in [[-110, -360, 110, LEAF_DARK], [100, -380, 110, LEAF_DARK], [0, -440, 130, LEAF], [-70, -460, 90, LEAF], [80, -470, 90, LEAF], [0, -340, 90, LEAF]]:
		ci.draw_circle(foot + Vector2(c[0], c[1]) * k, c[2] * k, c[3])
	# しめ縄と紙垂
	ci.draw_line(foot + Vector2(-46, -178) * k, foot + Vector2(46, -170) * k, ROPE, 12.0 * k)
	for x in [-26, 4, 30]:
		var z := PackedVector2Array()
		for p in [Vector2(x, -170), Vector2(x + 8, -160), Vector2(x - 2, -150), Vector2(x + 8, -140), Vector2(x - 2, -130)]:
			z.append(foot + p * k)
		ci.draw_polyline(z, SHIDE, 5.0 * k)


## 顔の見えない店の人（暗いかげの姿。顔は白くのっぺりして、目も口もない）
static func draw_vendor(ci: CanvasItem, foot: Vector2, h: float) -> void:
	var k := h / 150.0
	_poly(ci, [Vector2(-30, 0), Vector2(30, 0), Vector2(26, -96), Vector2(14, -110), Vector2(-14, -110), Vector2(-26, -96)], VENDOR, foot, k)
	ci.draw_circle(foot + Vector2(0, -128) * k, 20 * k, VENDOR_FACE)
	# 手ぬぐいをかぶっている
	_poly(ci, [Vector2(-24, -132), Vector2(24, -132), Vector2(18, -150), Vector2(-18, -150)], VENDOR, foot, k)


func _stall() -> void:
	_shadow(self, Vector2(0, -2), Vector2(150, 10))
	# 台と柱と屋根の布
	draw_rect(Rect2(-130, -70, 260, 14), STALL_WOOD)
	draw_rect(Rect2(-124, -56, 248, 56), Color("#4A3A30"))
	for x in [-126, 118]:
		draw_rect(Rect2(x, -240, 8, 240), STALL_WOOD)
	_poly(self, [Vector2(-150, -230), Vector2(150, -230), Vector2(140, -200), Vector2(-140, -200)], STALL_CLOTH)
	for i in 6:
		_poly(self, [Vector2(-140 + i * 48, -200), Vector2(-116 + i * 48, -200), Vector2(-128 + i * 48, -186)], STALL_CLOTH)
	# ふしぎな品物：青いあめ玉のびん、お面、ひかる玉
	draw_rect(Rect2(-110, -112, 36, 42), Color(0.75, 0.85, 0.95, 0.6))
	for c in [Vector2(-100, -84), Vector2(-86, -90), Vector2(-94, -100)]:
		draw_circle(c, 6, P.BLUE_LANTERN)
	for x in [-40, -2]:
		draw_circle(Vector2(x, -100), 16, Color("#F2EDE2"))
		draw_line(Vector2(x - 8, -102), Vector2(x - 2, -100), Color("#C8462E"), 2.0)
		draw_line(Vector2(x + 8, -102), Vector2(x + 2, -100), Color("#C8462E"), 2.0)
	for c in [Vector2(50, -80), Vector2(70, -82), Vector2(90, -78), Vector2(62, -94), Vector2(82, -96)]:
		draw_circle(c, 7, Color("#B8D4F0"))


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
	var k := LANTERN_SIZE / LANTERN_BODY
	var hang := LANTERN_CENTER * k
	var pts := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		pts.append(Vector2(width * t, -360.0 - hang + 36.0 * 4.0 * t * (1.0 - t)))
	draw_polyline(pts, P.WIRE, 2.0)
	var h := LANTERN_TEX.get_height() * k
	var w := LANTERN_TEX.get_width() * k
	for p in _lantern_points():
		var foot := p + Vector2(0, h - hang)
		draw_texture_rect(LANTERN_TEX, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false, P.BLUE_LANTERN)


func _sunflowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var n := maxi(1, int(width / 70))
	for i in n:
		var x := width * (i + 0.5) / n + rng.randf_range(-12, 12)
		var h := rng.randf_range(150, 210)
		draw_line(Vector2(x, 0), Vector2(x, -h), STEM, 5.0)
		draw_circle(Vector2(x - 14, -h * 0.5), 12, STEM)
		for j in 10:
			var a := TAU * j / 10.0
			draw_circle(Vector2(x, -h) + Vector2(cos(a), sin(a)) * 18, 9, SUNFLOWER)
		draw_circle(Vector2(x, -h), 13, SUNFLOWER_CORE)


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
