@tool
extends Node2D
## 親友ルートの場所（駄菓子屋・川原・秘密基地・夏祭り・バス停など）を描く。足もと（地面）が原点。
## ほとんどは手描き風の絵（Google Gemini で生成し、背景を切り抜いたもの。res://world/scenery/painted/）。
## ビー玉の輪・星空・缶を埋めた土は図形で描く。
## 灯りの光（*_GLOW）は GlowLayer の下に置くと、夜でも暗くならない。

enum Kind {
	SHOP,          ## 駄菓子屋（ベンチ、アイスの冷凍庫つき）
	MARBLE_RING,   ## 地面のビー玉あそびの輪
	RIVER,         ## 川の浅瀬（width の幅）
	BIG_ROCK,      ## 川原の大きな岩（タケルが座る）
	STONES,        ## 丸い石
	THICKET,       ## しげみ
	WOODS,         ## 雑木林（width の幅に木を並べる）
	TORII,         ## 神社の鳥居
	LANTERNS,      ## 提灯の列（width の幅）
	LANTERNS_GLOW, ## 提灯の光
	STALL,         ## 屋台
	STREETLIGHT,   ## 帰り道の街灯
	STREETLIGHT_GLOW,
	TAKERU_HOUSE,  ## タケルの家
	BOXES,         ## 積んである段ボール箱
	KUNUGI,        ## クヌギの木（バナナの罠とカブトムシ）
	DIVE_ROCK,     ## 飛び込み岩と深い淵
	OKURIBI,       ## 門口の送り火
	OKURIBI_GLOW,
	ENGAWA,        ## 縁側（家の前の板張り）
	BUS_STOP,      ## バス停
	SLOPE,         ## 後ろの坂道
	STARS,         ## 星空（width の幅）
	SOIL_MOUND,    ## 基地の下の土（缶を埋めた場所）
	# --- 初恋ルート（なつみ） ---
	KOMINKAN,      ## 公民館（ラジオ体操・映画会・台風の軒下）
	KOMINKAN_GLOW, ## 夜の公民館の窓の明かりと、映画のスクリーンのちらつき
	RADIO_KIDS,    ## ラジオ体操：台の上のラジオと、体操する村の子どもたち（width の幅）
	GAKUBAN,       ## あぜ道に置いた画板（描きかけの絵）
	SHRINE,        ## 小さな社（軒下で雨宿りする）
	PUDDLES,       ## 雨上がりの水たまり（width の幅）
	SEA,           ## 道の向こうの海（width の幅）
	SAND,          ## 砂浜（道の上に重ねる。width の幅）
	SWIM_FLAG,     ## 遊泳禁止の旗
	SHELLS,        ## 波打ちぎわの貝がら
	BUCKET,        ## 水を入れたバケツ（線香花火の）
}

@export var kind: Kind = Kind.SHOP:
	set(v):
		kind = v
		queue_redraw()
## 横に広がるもの（川・林・提灯・星）の幅
@export var width := 600.0:
	set(v):
		width = v
		queue_redraw()

## 空でなければ、はじめは隠しておき、会話の @event でこの名前が来たら現れる
@export var show_on_event := ""
## 空でなければ、会話の @event でこの名前が来たら消える（なつみが画板を持って走り去る、など）
@export var hide_on_event := ""

const P := preload("res://world/world_palette.gd")
const ART := "res://world/scenery/painted/%s.png"
const EDGE_FADE := preload("res://world/shaders/strip_edge_fade.gdshader")
## 川の帯の高さ
const RIVER_H := 90.0
## 絵に地面の影はないので、足もとにうすい影を描く
const SHADOW := Color(0.12, 0.16, 0.08, 0.22)
## 提灯の絵：本体のまん中（絵の上から px）と、本体の高さ
const LANTERN_CENTER := 289.0
const LANTERN_BODY := 234.0
const LANTERN_SIZE := 44.0
## 飛び込み岩の深い淵の色（川の絵にかける）
const DEEP_POOL := Color(0.45, 0.68, 0.66)
## 送り火：絵の高さと、皿のまん中（絵の中の px。火と光はここから）
const OKURIBI_H := 220.0
const OKURIBI_DISH := Vector2(479, 320)
## 街灯の絵の高さと、電球の位置（絵の中の px）
const STREETLIGHT_H := 340.0
const STREETLIGHT_BULB := Vector2(129, 126)
const STREETLIGHT_FOOT := 130.0

var _tex_cache := {}


func _ready() -> void:
	# 川は左右の端と上のふちをぼかす（切れ目を見せない）
	if kind == Kind.RIVER:
		var mat := ShaderMaterial.new()
		mat.shader = EDGE_FADE
		mat.set_shader_parameter("width", width)
		mat.set_shader_parameter("top_y", -RIVER_H + 4.0)
		material = mat
	# 海も左右の端をぼかす（海辺の道から、だんだん海が見えてくる）
	if kind == Kind.SEA:
		var sea_mat := ShaderMaterial.new()
		sea_mat.shader = EDGE_FADE
		sea_mat.set_shader_parameter("width", width)
		sea_mat.set_shader_parameter("fade_x", 400.0)
		sea_mat.set_shader_parameter("top_y", -SEA_H + 6.0)
		sea_mat.set_shader_parameter("fade_top", 40.0)
		material = sea_mat
	# 子どもの絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	if kind == Kind.RADIO_KIDS:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not Engine.is_editor_hint() and show_on_event != "":
		visible = false


func on_talk_event(event_name: String) -> void:
	if show_on_event != "" and event_name == show_on_event:
		modulate.a = 0.0
		UiAnim.fade(self, 1.0, UiTokens.TIME_FADE * 2)
	if hide_on_event != "" and event_name == hide_on_event:
		UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 2)


## ゆれるもの（スクリーンのちらつき）だけ描きなおす。動きを減らす設定では止める
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or UiAnim.reduced():
		return
	if kind == Kind.KOMINKAN_GLOW:
		queue_redraw()


func _clock() -> float:
	if Engine.is_editor_hint() or UiAnim.reduced():
		return 0.0
	return Time.get_ticks_msec() / 1000.0


func _draw() -> void:
	match kind:
		Kind.SHOP: _shop()
		Kind.MARBLE_RING: _marble_ring()
		Kind.RIVER: _river()
		Kind.BIG_ROCK: _big_rock()
		Kind.STONES: _stones()
		Kind.THICKET: _thicket()
		Kind.WOODS: _woods()
		Kind.TORII: _torii()
		Kind.LANTERNS: _lanterns(false)
		Kind.LANTERNS_GLOW: _lanterns(true)
		Kind.STALL: _stall()
		Kind.STREETLIGHT: _streetlight(false)
		Kind.STREETLIGHT_GLOW: _streetlight(true)
		Kind.TAKERU_HOUSE: _takeru_house()
		Kind.BOXES: _boxes()
		Kind.KUNUGI: _kunugi()
		Kind.DIVE_ROCK: _dive_rock()
		Kind.OKURIBI: _okuribi(false)
		Kind.OKURIBI_GLOW: _okuribi(true)
		Kind.ENGAWA: _engawa()
		Kind.BUS_STOP: _bus_stop()
		Kind.SLOPE: _slope()
		Kind.STARS: _stars()
		Kind.SOIL_MOUND: _soil_mound()
		Kind.KOMINKAN: _kominkan()
		Kind.KOMINKAN_GLOW: _kominkan_glow()
		Kind.RADIO_KIDS: _radio_kids()
		Kind.GAKUBAN: _gakuban()
		Kind.SHRINE: _shrine()
		Kind.PUDDLES: _puddles()
		Kind.SEA: _sea()
		Kind.SAND: _sand()
		Kind.SWIM_FLAG: _swim_flag()
		Kind.SHELLS: _shells()
		Kind.BUCKET: _bucket()


func _poly(points: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), c)


func _tex(art_name: String) -> Texture2D:
	if not _tex_cache.has(art_name):
		_tex_cache[art_name] = load(ART % art_name)
	return _tex_cache[art_name]


## 絵を高さ h で描く。foot は足もと（絵の下のふち）の位置。foot_x は絵の中の足もとの x（px。負なら絵のまん中）
func _art(art_name: String, foot: Vector2, h: float, foot_x := -1.0, tint := Color.WHITE) -> void:
	var tex := _tex(art_name)
	var k := h / tex.get_height()
	var fx := (tex.get_width() / 2.0 if foot_x < 0.0 else foot_x) * k
	draw_texture_rect(tex, Rect2(foot + Vector2(-fx, -h), tex.get_size() * k), false, tint)


func _shadow(center: Vector2, radius: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shop() -> void:
	# 店先のベンチとアイスの冷凍庫も絵に入っている
	_shadow(Vector2(0, -2), Vector2(300, 12))
	_art("prop_shop", Vector2(0, 4), 333.0)


func _marble_ring() -> void:
	draw_arc(Vector2(0, 14), 70, 0, TAU, 40, P.CHALK, 3.0)
	for m in [[-30, 8, P.MARBLE_BLUE], [12, 22, P.MARBLE_GREEN], [34, 4, P.MARBLE_BLUE], [-6, 30, P.LANTERN]]:
		draw_circle(Vector2(m[0], m[1]), 6, m[2])
		draw_circle(Vector2(m[0] - 2, m[1] - 2), 2, P.CLOUD)


func _river() -> void:
	# 道の向こうを流れる浅瀬。手前は丸い石の岸。絵の帯を width いっぱいに並べる
	var tex := _tex("river")
	var h := RIVER_H
	var n := maxi(1, roundi(width / (h * tex.get_width() / tex.get_height())))
	var tile := width / n
	for i in n:
		draw_texture_rect(tex, Rect2(i * tile - 1.0, -h + 4.0, tile + 2.0, h), false)


## 川原の大きな岩（タケルが座る）
func _big_rock() -> void:
	# タケルが上に立つ（足もとが -88）ので、てっぺんが -96 くらいの高さにする
	_shadow(Vector2(0, -2), Vector2(80, 9))
	_art("stone_3", Vector2.ZERO, 98.0)


func _stones() -> void:
	for s in [["stone_1", -60, 30], ["stone_2", -14, 24], ["stone_4", 34, 32], ["stone_5", 84, 22], ["stone_2", 120, 18]]:
		_shadow(Vector2(s[1], -1), Vector2(s[2] * 0.7, 4))
		_art(s[0], Vector2(s[1], 2), s[2])


func _thicket() -> void:
	_shadow(Vector2(20, -2), Vector2(190, 10))
	_art("thicket_1", Vector2(-100, 6), 130.0)
	_art("thicket_3", Vector2(130, 6), 150.0)
	_art("thicket_2", Vector2(10, 6), 175.0)


func _woods() -> void:
	var n := maxi(1, int(width / 180))
	# 奥の木は少し暗く（林の中のかげ）
	var shade := Color(0.78, 0.84, 0.78)
	for i in n:
		var x := width * (i + 0.5) / n
		var h := 380.0 + (i % 3) * 50.0
		if i % 2 == 0:
			_art("prop_kunugi", Vector2(x, 4), h, 287.0, shade)
		else:
			_art("prop_tree", Vector2(x, 4), h, 281.0, shade)


func _torii() -> void:
	_art("prop_torii", Vector2.ZERO, 340.0, 463.0)


func _lantern_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := maxi(2, int(width / 90))
	for i in n:
		var t := (i + 0.5) / n
		out.append(Vector2(width * t, -380 + 40.0 * 4.0 * t * (1.0 - t)))
	return out


func _lanterns(glow: bool) -> void:
	if glow:
		for p in _lantern_points():
			draw_circle(p, 46, P.LANTERN_GLOW)
			draw_circle(p, 24, P.LANTERN_GLOW)
		return
	# 電線は提灯の吊りひもの上の端にそろえる
	var k := LANTERN_SIZE / LANTERN_BODY
	var hang := LANTERN_CENTER * k
	var pts := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		pts.append(Vector2(width * t, -380.0 - hang + 40.0 * 4.0 * t * (1.0 - t)))
	draw_polyline(pts, P.WIRE, 2.0)
	var tex := _tex("lantern_1")
	var h := tex.get_height() * k
	for p in _lantern_points():
		_art("lantern_1", p + Vector2(0, h - hang), h)


func _stall() -> void:
	_shadow(Vector2(0, -2), Vector2(170, 10))
	_art("prop_stall", Vector2.ZERO, 290.0)


func _streetlight(glow: bool) -> void:
	var tex := _tex("prop_streetlight")
	var k := STREETLIGHT_H / tex.get_height()
	var bulb := Vector2((STREETLIGHT_BULB.x - STREETLIGHT_FOOT) * k, -STREETLIGHT_H + STREETLIGHT_BULB.y * k)
	if glow:
		draw_circle(bulb, 70, P.LAMP_GLOW)
		draw_circle(bulb, 30, P.LAMP_GLOW)
		_poly([bulb + Vector2(-18, 6), bulb + Vector2(18, 6), Vector2(bulb.x + 80, 0), Vector2(bulb.x - 80, 0)], Color(P.LAMP_GLOW, 0.1))
		return
	_shadow(Vector2(0, -1), Vector2(18, 4))
	_art("prop_streetlight", Vector2.ZERO, STREETLIGHT_H, STREETLIGHT_FOOT)


func _takeru_house() -> void:
	_shadow(Vector2(0, -2), Vector2(300, 12))
	_art("prop_takeru_house", Vector2(0, 4), 340.0)


func _boxes() -> void:
	_shadow(Vector2(20, -2), Vector2(170, 9))
	_art("box_1", Vector2(-50, 2), 120.0)
	_art("box_2", Vector2(70, 2), 96.0)
	_art("box_3", Vector2(158, 2), 70.0)
	# 上に積んだ箱
	_art("box_3", Vector2(-44, -112), 72.0)


func _kunugi() -> void:
	_shadow(Vector2(0, -2), Vector2(130, 12))
	_art("prop_kunugi", Vector2(0, 4), 560.0, 287.0)
	# バナナの罠（ネットに入れて幹に結んである）
	draw_arc(Vector2(34, -170), 18, -0.4, PI * 0.9, 12, P.BANANA, 10.0)
	draw_line(Vector2(26, -196), Vector2(26, -150), P.CHALK, 1.5)
	draw_line(Vector2(46, -196), Vector2(46, -150), P.CHALK, 1.5)
	# カブトムシ
	draw_circle(Vector2(-6, -210), 12, P.BEETLE)
	draw_line(Vector2(-6, -222), Vector2(-14, -240), P.BEETLE, 4.0)


func _dive_rock() -> void:
	# 深い淵（岩の右、道の向こう）。川の帯を暗い緑にして使う
	var tex := _tex("river")
	var h := 98.0
	var tile := h * tex.get_width() / tex.get_height()
	var x := 60.0
	while x < 620.0:
		var w := minf(tile, 620.0 - x)
		draw_texture_rect_region(tex, Rect2(x, -h + 2.0, w, h), Rect2(0, 0, w / tile * tex.get_width(), tex.get_height()), DEEP_POOL)
		x += tile
	# 高い岩
	_art("prop_diverock", Vector2(-30, 4), 300.0)


func _okuribi(glow: bool) -> void:
	var tex := _tex("prop_okuribi")
	var k := OKURIBI_H / tex.get_height()
	var dish := Vector2((OKURIBI_DISH.x - tex.get_width() / 2.0) * k, -OKURIBI_H + OKURIBI_DISH.y * k)
	if glow:
		draw_circle(dish + Vector2(0, -16), 38, P.FIRE_GLOW)
		draw_circle(dish + Vector2(0, -12), 18, P.FIRE_GLOW)
		_poly([dish + Vector2(-12, -4), dish + Vector2(0, -42), dish + Vector2(12, -4)], Color(P.FIRE, 0.9))
		return
	# 門口：門柱と、おがらを井桁に組んだ素焼きの皿
	_art("prop_okuribi", Vector2(0, 6), OKURIBI_H)


func _engawa() -> void:
	# 家の前の縁側（手前のふちと脚）
	_art("prop_engawa", Vector2(0, 2), 89.0)


func _bus_stop() -> void:
	# 左の丸い看板の柱が原点。右に待合所
	_shadow(Vector2(200, -2), Vector2(240, 10))
	_art("prop_busstop", Vector2.ZERO, 260.0, 85.0)


func _slope() -> void:
	# 後ろの坂道：左の丘から道が下りてくる（絵の右下が原点）
	var tex := _tex("prop_slope")
	var h := width * tex.get_height() / tex.get_width()
	draw_texture_rect(tex, Rect2(-width, -h + 8.0, width, h), false)


func _stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in int(width / 22):
		var p := Vector2(rng.randf() * width, -720 + rng.randf() * 420)
		var r := 1.2 + rng.randf() * 1.8
		draw_circle(p, r, P.STAR)


func _soil_mound() -> void:
	_poly([Vector2(-70, 4), Vector2(-40, -18), Vector2(30, -22), Vector2(72, 4)], P.SOIL)
	draw_line(Vector2(-20, -14), Vector2(18, -12), P.WOOD_DARK, 2.0)


# --- 初恋ルート（なつみ）の場所 ---------------------------------------------------
# 公民館・ラジオ体操・画板・社・海・旗・貝がら・バケツは Gemini の絵。水たまりと砂浜は図形で描く

## 公民館の絵の高さと、窓・入口のガラスの場所（絵の幅・高さに対する割合：[左, 上, 右, 下]）。夜の明かり（KOMINKAN_GLOW）も同じ場所に描く
const KOMINKAN_H := 230.0
const KOMINKAN_WINDOWS := [[0.124, 0.49, 0.249, 0.73], [0.752, 0.49, 0.877, 0.73]]
const KOMINKAN_DOOR := [0.396, 0.467, 0.673, 0.685]
## ラジオ体操：台の上のラジオと、子どもたちの高さ
const RADIO_H := 92.0
const RADIO_KID_H := [98.0, 92.0, 96.0, 76.0]
const RADIO_KIDS := 4
## 海の帯の高さ（下のふちは波打ちぎわ）
const SEA_H := 230.0


## 絵の中の割合の四角（[左, 上, 右, 下]）を、足もとが原点の座標に
func _art_rect(art_name: String, h: float, r: Array) -> Rect2:
	var tex := _tex(art_name)
	var w := tex.get_width() * h / tex.get_height()
	var left := -w / 2.0
	return Rect2(left + w * r[0], -h + h * r[1], w * (r[2] - r[0]), h * (r[3] - r[1]))


func _kominkan() -> void:
	_shadow(Vector2(0, -2), Vector2(260, 12))
	_art("prop_kominkan", Vector2(0, 4), KOMINKAN_H)


func _kominkan_glow() -> void:
	# 窓の明かり
	for w in KOMINKAN_WINDOWS:
		draw_rect(_art_rect("prop_kominkan", KOMINKAN_H, w).grow(-2), P.KOMINKAN_LIGHT)
	# 入口のガラスごしに、スクリーンの青白い光がちらつく
	var t := _clock()
	var flick := 0.7 + 0.3 * sin(t * 7.0) * sin(t * 2.3 + 1.0)
	var d := _art_rect("prop_kominkan", KOMINKAN_H, KOMINKAN_DOOR)
	draw_rect(d, Color(P.SCREEN_LIGHT, 0.32 * flick))
	_poly([Vector2(d.position.x, 0), Vector2(d.end.x, 0), Vector2(d.end.x + 60, 70), Vector2(d.position.x - 60, 70)], Color(P.SCREEN_LIGHT, 0.08 * flick))


func _radio_kids() -> void:
	# 台の上のラジオ（左のはし）と、体操する村の子どもたち
	_shadow(Vector2(0, -1), Vector2(60, 6))
	_art("prop_radio", Vector2(0, 4), RADIO_H)
	var n := mini(RADIO_KIDS, maxi(1, int((width - 80) / 100)))
	for i in n:
		var x := 120.0 + i * (width - 120.0) / n
		_shadow(Vector2(x, -1), Vector2(26, 4))
		_art("radio_kid_%d" % (i + 1), Vector2(x, 4), RADIO_KID_H[i])


func _gakuban() -> void:
	# あぜ道にななめに立てかけた画板（描きかけの絵）と、色えんぴつの缶
	_art("prop_gakuban", Vector2(0, 8), 96.0)


func _shrine() -> void:
	# 小さな社。右の軒下（鈴の下）で雨宿りする
	_art("prop_shrine", Vector2(0, 8), 300.0)


func _puddles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := maxi(1, int(width / 260))
	for i in n:
		var c := Vector2(width * (i + 0.3 + rng.randf() * 0.4) / n, 26 + rng.randf() * 28)
		var r := 34.0 + rng.randf() * 30.0
		draw_set_transform(c, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, r, Color(P.WATER, 0.7))
		draw_circle(Vector2(-r * 0.3, -r * 0.2), r * 0.45, Color(P.SKY_REFLECT, 0.6))
		draw_set_transform(Vector2.ZERO)


func _sea() -> void:
	# 道の向こうの海（絵の帯を width いっぱいに並べる。下のふちが波打ちぎわ）
	var tex := _tex("sea")
	var h := SEA_H
	var n := maxi(1, roundi(width / (h * tex.get_width() / tex.get_height())))
	var tile := width / n
	for i in n:
		draw_texture_rect(tex, Rect2(i * tile - 1.0, -h + 6.0, tile + 2.0, h), false)


func _sand() -> void:
	# 道の上に砂を重ねる（両はしは、ななめにぼかす）
	_poly([Vector2(-60, 76), Vector2(0, -14), Vector2(width, -14), Vector2(width + 60, 76)], P.SAND)
	_poly([Vector2(0, -14), Vector2(width, -14), Vector2(width, -4), Vector2(0, -4)], P.SAND_WET)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in int(width / 14):
		draw_circle(Vector2(rng.randf() * width, rng.randf() * 80 - 6), 1.5, Color(P.WOOD_DARK, 0.25))


func _swim_flag() -> void:
	_art("prop_swim_flag", Vector2(0, 6), 290.0, 140.0)


func _shells() -> void:
	for s in [[-40, 10, "shell_1", 18.0], [12, 26, "shell_4", 14.0], [58, 8, "shell_3", 16.0], [100, 30, "shell_2", 20.0]]:
		_art(s[2], Vector2(s[0], s[1]), s[3])


func _bucket() -> void:
	_art("prop_bucket", Vector2(0, 8), 96.0)
