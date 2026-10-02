@tool
extends Node2D
## 親友ルートの場所の仮素材（駄菓子屋・川原・秘密基地・夏祭り・バス停など）を図形で描く。足もと（地面）が原点。
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

const P := preload("res://world/world_palette.gd")


func _ready() -> void:
	if not Engine.is_editor_hint() and show_on_event != "":
		visible = false


func on_talk_event(event_name: String) -> void:
	if show_on_event != "" and event_name == show_on_event:
		modulate.a = 0.0
		UiAnim.fade(self, 1.0, UiTokens.TIME_FADE * 2)


func _draw() -> void:
	match kind:
		Kind.SHOP: _shop()
		Kind.MARBLE_RING: _marble_ring()
		Kind.RIVER: _river()
		Kind.BIG_ROCK: _rock(Vector2(240, 96))
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


func _poly(points: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), c)


func _shop() -> void:
	# 建物
	draw_rect(Rect2(-260, -250, 520, 250), P.SHOP_WALL)
	_poly([Vector2(-300, -240), Vector2(-240, -320), Vector2(240, -320), Vector2(300, -240)], P.HOUSE_ROOF)
	# 店先（ひさし、のれん、たな）
	draw_rect(Rect2(-280, -240, 560, 14), P.WOOD_DARK)
	draw_rect(Rect2(-200, -200, 300, 200), P.SHOP_DARK)
	for i in 3:
		var y := -170 + i * 50
		draw_rect(Rect2(-190, y + 30, 280, 6), P.WOOD)
		for j in 6:
			var c: Color = [P.LANTERN, P.MARBLE_BLUE, P.CANOPY_STRIPE, P.MARBLE_GREEN][(i + j) % 4]
			draw_rect(Rect2(-180 + j * 45, y + 8, 28, 22), c)
	for j in 5:
		draw_rect(Rect2(-200 + j * 60, -226, 54, 46), P.NOREN)
	# アイスの冷凍庫（店の前）
	draw_rect(Rect2(140, -78, 96, 78), P.FREEZER)
	draw_rect(Rect2(136, -86, 104, 12), P.CLOUD_SHADE)
	draw_rect(Rect2(150, -64, 76, 30), P.WATER_LIGHT)
	# ベンチ
	draw_rect(Rect2(-250, -52, 150, 10), P.WOOD)
	draw_rect(Rect2(-244, -42, 8, 42), P.WOOD_DARK)
	draw_rect(Rect2(-114, -42, 8, 42), P.WOOD_DARK)


func _marble_ring() -> void:
	draw_arc(Vector2(0, 14), 70, 0, TAU, 40, P.CHALK, 3.0)
	for m in [[-30, 8, P.MARBLE_BLUE], [12, 22, P.MARBLE_GREEN], [34, 4, P.MARBLE_BLUE], [-6, 30, P.LANTERN]]:
		draw_circle(Vector2(m[0], m[1]), 6, m[2])
		draw_circle(Vector2(m[0] - 2, m[1] - 2), 2, P.CLOUD)


func _river() -> void:
	# 道の向こうを流れる浅瀬。手前は丸い石の岸
	draw_rect(Rect2(0, -70, width, 66), P.WATER)
	draw_rect(Rect2(0, -74, width, 6), P.STONE_LIGHT)
	for i in int(width / 120):
		var x := 40.0 + i * 120.0
		var y := -56.0 + (i % 3) * 14.0
		draw_line(Vector2(x, y), Vector2(x + 50, y), P.WATER_LIGHT, 3.0)
	for i in int(width / 46):
		var x := 12.0 + i * 46.0 + (i % 2) * 14
		draw_circle(Vector2(x, -6), 9 + (i % 3) * 3, P.ROCK if i % 2 else P.STONE_LIGHT)


func _rock(size: Vector2) -> void:
	var w := size.x / 2.0
	var h := size.y
	_poly([Vector2(-w, 0), Vector2(-w * 0.9, -h * 0.6), Vector2(-w * 0.4, -h), Vector2(w * 0.5, -h * 0.92),
		Vector2(w, -h * 0.4), Vector2(w * 0.95, 0)], P.ROCK)
	_poly([Vector2(-w * 0.4, -h), Vector2(w * 0.5, -h * 0.92), Vector2(w * 0.2, -h * 0.7), Vector2(-w * 0.3, -h * 0.78)], P.STONE_LIGHT)
	draw_line(Vector2(-w * 0.2, -h * 0.5), Vector2(w * 0.3, -h * 0.3), P.ROCK_DARK, 3.0)


func _stones() -> void:
	for s in [[-60, 10, 18], [-20, 14, 12], [24, 8, 22], [70, 12, 14], [110, 6, 10]]:
		draw_circle(Vector2(s[0], -s[2] * 0.6 + s[1]), s[2], P.STONE_LIGHT)
		draw_arc(Vector2(s[0], -s[2] * 0.6 + s[1]), s[2], 0.2, PI - 0.2, 10, P.ROCK, 2.0)


func _thicket() -> void:
	for b in [[-110, -50, 60], [-50, -80, 78], [20, -60, 70], [80, -90, 72], [140, -50, 56]]:
		draw_circle(Vector2(b[0], b[1]), b[2], P.GROUND_DARK if int(b[0]) % 20 == 0 else P.NEAR_BUSH)
	draw_rect(Rect2(-170, -50, 370, 50), P.GROUND_DARK)


func _woods() -> void:
	var n := maxi(1, int(width / 180))
	for i in n:
		var x := width * (i + 0.5) / n
		var h := 300.0 + (i % 3) * 60.0
		draw_rect(Rect2(x - 12, -h, 24, h), P.WOODS_TRUNK)
		draw_circle(Vector2(x, -h - 30), 100 + (i % 2) * 20, P.WOODS_DARK)
		draw_circle(Vector2(x - 60, -h + 30), 70, P.GROUND_DARK)
		draw_circle(Vector2(x + 64, -h + 20), 76, P.WOODS_DARK)


func _torii() -> void:
	draw_rect(Rect2(-130, -330, 22, 330), P.SHRINE_RED)
	draw_rect(Rect2(108, -330, 22, 330), P.SHRINE_RED)
	draw_rect(Rect2(-170, -350, 340, 22), P.SHRINE_RED)
	draw_rect(Rect2(-150, -300, 300, 16), P.SHRINE_RED)
	draw_rect(Rect2(-176, -362, 352, 12), P.SHOP_DARK)


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
	var pts := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		pts.append(Vector2(width * t, -404 + 40.0 * 4.0 * t * (1.0 - t)))
	draw_polyline(pts, P.WIRE, 2.0)
	for p in _lantern_points():
		draw_line(p + Vector2(0, -24), p + Vector2(0, -18), P.SHOP_DARK, 2.0)
		draw_circle(p, 18, P.LANTERN)
		draw_rect(Rect2(p.x - 10, p.y - 20, 20, 5), P.SHOP_DARK)
		draw_rect(Rect2(p.x - 10, p.y + 15, 20, 5), P.SHOP_DARK)
		draw_line(p + Vector2(-16, 0), p + Vector2(16, 0), P.LANTERN_LINE, 2.0)


func _stall() -> void:
	draw_rect(Rect2(-150, -90, 300, 90), P.WOOD)
	draw_rect(Rect2(-150, -96, 300, 10), P.WOOD_DARK)
	draw_rect(Rect2(-146, -260, 8, 170), P.WOOD_DARK)
	draw_rect(Rect2(138, -260, 8, 170), P.WOOD_DARK)
	# しまのひさし
	for i in 6:
		var c := P.CANOPY if i % 2 == 0 else P.CANOPY_STRIPE
		_poly([Vector2(-170 + i * 57, -270), Vector2(-113 + i * 57, -270), Vector2(-113 + i * 57, -226), Vector2(-170 + i * 57, -226)], c)
	draw_rect(Rect2(-170, -276, 342, 8), P.SHOP_DARK)


func _streetlight(glow: bool) -> void:
	if glow:
		draw_circle(Vector2(36, -296), 70, P.LAMP_GLOW)
		draw_circle(Vector2(36, -296), 30, P.LAMP_GLOW)
		_poly([Vector2(20, -290), Vector2(52, -290), Vector2(110, 0), Vector2(-38, 0)], Color(P.LAMP_GLOW, 0.1))
		return
	draw_rect(Rect2(-6, -320, 12, 320), P.POLE)
	draw_rect(Rect2(-6, -320, 50, 8), P.POLE)
	draw_rect(Rect2(24, -312, 26, 14), P.FREEZER)


func _takeru_house() -> void:
	draw_rect(Rect2(-240, -240, 480, 240), P.WOOD)
	for i in 8:
		draw_line(Vector2(-240 + i * 60, -240), Vector2(-240 + i * 60, 0), P.WOOD_DARK, 2.0)
	_poly([Vector2(-290, -230), Vector2(0, -380), Vector2(290, -230)], P.TIN_ROOF)
	draw_rect(Rect2(-50, -150, 100, 150), P.SHOP_DARK)
	draw_rect(Rect2(-190, -190, 90, 60), P.SIGN_BOARD)


func _boxes() -> void:
	for b in [[-90, 0, 90, 70], [4, 0, 100, 76], [-60, -70, 96, 64], [-30, -134, 80, 58], [106, 0, 70, 54]]:
		var r := Rect2(b[0], b[1] - b[3], b[2], b[3])
		draw_rect(r, P.CARDBOARD)
		draw_rect(r, P.CARDBOARD_DARK, false, 2.0)
		draw_line(Vector2(r.position.x + r.size.x / 2, r.position.y), Vector2(r.position.x + r.size.x / 2, r.position.y + 14), P.CARDBOARD_DARK, 4.0)


func _kunugi() -> void:
	draw_rect(Rect2(-26, -360, 52, 360), P.WOODS_TRUNK)
	for i in 6:
		draw_line(Vector2(-18 + (i % 3) * 14, -340 + i * 50), Vector2(-14 + (i % 3) * 14, -310 + i * 50), P.BEETLE, 2.0)
	draw_circle(Vector2(0, -400), 140, P.WOODS_DARK)
	draw_circle(Vector2(-110, -320), 90, P.GROUND_DARK)
	draw_circle(Vector2(110, -330), 96, P.WOODS_DARK)
	# バナナの罠（ネットに入れて幹に結んである）
	draw_arc(Vector2(34, -170), 18, -0.4, PI * 0.9, 12, P.BANANA, 10.0)
	draw_line(Vector2(26, -196), Vector2(26, -150), P.CHALK, 1.5)
	draw_line(Vector2(46, -196), Vector2(46, -150), P.CHALK, 1.5)
	# カブトムシ
	draw_circle(Vector2(-6, -210), 12, P.BEETLE)
	draw_line(Vector2(-6, -222), Vector2(-14, -240), P.BEETLE, 4.0)


func _dive_rock() -> void:
	# 深い淵（岩の右、道の向こう）
	draw_rect(Rect2(60, -96, 560, 92), P.WATER_DEEP)
	draw_rect(Rect2(60, -100, 560, 8), P.WATER)
	for i in 4:
		var y := -70.0 + (i % 2) * 26.0
		draw_line(Vector2(120 + i * 120, y), Vector2(170 + i * 120, y), P.WATER, 3.0)
	# 高い岩
	_poly([Vector2(-180, 0), Vector2(-150, -180), Vector2(-90, -270), Vector2(40, -280), Vector2(90, -230),
		Vector2(110, -40), Vector2(80, 0)], P.ROCK)
	_poly([Vector2(-90, -270), Vector2(40, -280), Vector2(20, -250), Vector2(-80, -246)], P.STONE_LIGHT)
	draw_line(Vector2(-120, -150), Vector2(-40, -100), P.ROCK_DARK, 3.0)
	draw_line(Vector2(0, -200), Vector2(70, -150), P.ROCK_DARK, 3.0)


func _okuribi(glow: bool) -> void:
	if glow:
		draw_circle(Vector2(0, -26), 38, P.FIRE_GLOW)
		draw_circle(Vector2(0, -22), 18, P.FIRE_GLOW)
		_poly([Vector2(-12, -14), Vector2(0, -52), Vector2(12, -14)], Color(P.FIRE, 0.9))
		return
	# 門口：門柱と、おがらを焚く素焼きの皿
	draw_rect(Rect2(-110, -200, 18, 200), P.WOOD_DARK)
	draw_rect(Rect2(92, -200, 18, 200), P.WOOD_DARK)
	draw_rect(Rect2(-26, -12, 52, 12), P.ROCK_DARK)
	for i in 5:
		draw_line(Vector2(-16 + i * 8, -12), Vector2(-10 + i * 6, -26), P.WOOD, 2.0)


func _engawa() -> void:
	draw_rect(Rect2(-260, -60, 520, 14), P.WOOD)
	draw_rect(Rect2(-260, -46, 520, 6), P.WOOD_DARK)
	for x in [-250, -80, 80, 240]:
		draw_rect(Rect2(x, -40, 10, 40), P.WOOD_DARK)


func _bus_stop() -> void:
	draw_rect(Rect2(-5, -230, 10, 230), P.POLE)
	draw_circle(Vector2(0, -240), 30, P.SIGN_BOARD)
	draw_arc(Vector2(0, -240), 30, 0, TAU, 24, P.BUS_STRIPE, 4.0)
	# 小さな待合（トタン屋根とベンチ）
	draw_rect(Rect2(60, -200, 8, 200), P.WOOD_DARK)
	draw_rect(Rect2(232, -200, 8, 200), P.WOOD_DARK)
	_poly([Vector2(44, -196), Vector2(256, -210), Vector2(256, -196), Vector2(44, -184)], P.TIN_ROOF)
	draw_rect(Rect2(80, -54, 140, 10), P.WOOD)
	draw_rect(Rect2(88, -44, 8, 44), P.WOOD_DARK)
	draw_rect(Rect2(204, -44, 8, 44), P.WOOD_DARK)


func _slope() -> void:
	# 後ろの坂道：左の丘から道が下りてくる
	_poly([Vector2(-width, -220), Vector2(-width * 0.4, -170), Vector2(0, -20), Vector2(0, 0), Vector2(-width, 0)], P.GROUND_DARK)
	_poly([Vector2(-width, -196), Vector2(-width * 0.4, -150), Vector2(0, -6), Vector2(0, 8), Vector2(-width * 0.4, -130), Vector2(-width, -176)], P.ROAD)


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
