@tool
class_name NormalProp
extends Node2D
## ノーマルルート（祖父母と過ごす夏）の場所の小物。足もと（地面）が原点。
## まだ仮の絵（図形）。あとで水彩の絵に差し替える。
## 会話の @event で、現れる（show_on_event）・消える（hide_on_event）・走り去る（車の drive_on_event）。

enum Kind {
	SASA,        ## 川べりの笹
	SASABUNE,    ## 帆のついた笹舟（現れると、川を右へ流れていく）
	LAUNDRY,     ## 物干しと洗濯物（hide_on_event で洗濯物だけ消える）
	MASK_STALL,  ## お面の屋台（きつね・ひょっとこ・おかめ）
	ZASHIKI,     ## 祖父母の家の座敷（開けはなした障子、たたみ、ちゃぶ台）
	RELATIVES,   ## 座敷に集まった親戚（width の幅に、すわった人のかげ）
	SHORYOUMA,   ## 精霊馬（きゅうりの馬・なすの牛）
	CAR,         ## 親戚の車（drive_on_event で走り去る）
	HOZUKI,      ## ほおずきの株
	KAYARI,      ## 蚊取り線香（けむりがゆれる）
	WHISTLE,     ## 口笛の「♪」（音素材が入るまでの吹き出しのかわり）
}

@export var kind: Kind = Kind.SASA:
	set(v):
		kind = v
		queue_redraw()
## 横に広がるもの（親戚）の幅
@export var width := 300.0:
	set(v):
		width = v
		queue_redraw()
## 車の色など（なければ決まった色）
@export var tint: Color = Color("#C9D3D6")
## 空でなければ、はじめは隠しておき、会話の @event でこの名前が来たら現れる
@export var show_on_event := ""
## 空でなければ、会話の @event でこの名前が来たら消える
@export var hide_on_event := ""
## 車：この名前の @event で走り去る
@export var drive_on_event := ""
## 現れたときに鳴らす音（口笛など。素材がなければ無音）
@export var sfx := ""

const P := preload("res://world/world_palette.gd")
const MASKS := ["kitsune", "hyottoko", "okame"]
const MASK_ICON := "res://data/items/icons/mask_%s.svg"
const STALL_TEX := "res://world/scenery/painted/prop_stall.png"
const SHADOW := Color(0.12, 0.16, 0.08, 0.22)
const FONT: Font = preload("res://ui/theme/fonts/ZenMaruGothic-Regular.ttf")
## 笹舟が流れる速さ（px/秒）と、流れていく距離
const SASABUNE_SPEED := 46.0
const SASABUNE_TRAVEL := 1400.0
## 車が走り去る速さ
const CAR_SPEED := 260.0

var _hidden_part := false
var _t := 0.0
var _moving := false
var _x := 0.0
var _masks: Array[Texture2D] = []
var _stall: Texture2D


func _ready() -> void:
	if kind == Kind.MASK_STALL:
		for m in MASKS:
			_masks.append(load(MASK_ICON % m))
		_stall = load(STALL_TEX)
	if not Engine.is_editor_hint() and show_on_event != "":
		visible = false


func on_talk_event(event_name: String) -> void:
	if show_on_event != "" and event_name == show_on_event:
		modulate.a = 0.0
		show()
		UiAnim.fade(self, 1.0, UiTokens.TIME_FADE * 2)
		if sfx != "":
			SfxPlayer.play(sfx)
		if kind == Kind.SASABUNE:
			_moving = true
	if hide_on_event != "" and event_name == hide_on_event:
		if kind == Kind.LAUNDRY:
			# 物干しは残して、洗濯物だけ取り込む
			_hidden_part = true
			queue_redraw()
		else:
			UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 2)
	if drive_on_event != "" and event_name == drive_on_event:
		_moving = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not UiAnim.reduced():
		_t += delta
	if _moving:
		match kind:
			Kind.SASABUNE:
				_x += SASABUNE_SPEED * delta
				if _x >= SASABUNE_TRAVEL:
					_moving = false
					UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 3)
			Kind.CAR:
				_x += CAR_SPEED * delta
				modulate.a = maxf(0.0, 1.0 - _x / 1600.0)
				if modulate.a <= 0.0:
					_moving = false
					hide()
	if kind in [Kind.SASABUNE, Kind.KAYARI, Kind.WHISTLE, Kind.LAUNDRY, Kind.CAR] and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.SASA: _sasa()
		Kind.SASABUNE: _sasabune()
		Kind.LAUNDRY: _laundry()
		Kind.MASK_STALL: _mask_stall()
		Kind.ZASHIKI: _zashiki()
		Kind.RELATIVES: _relatives()
		Kind.SHORYOUMA: _shoryouma()
		Kind.CAR: _car()
		Kind.HOZUKI: _hozuki()
		Kind.KAYARI: _kayari()
		Kind.WHISTLE: _whistle()


func _shadow(center: Vector2, radius: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sasa() -> void:
	# 細い茎と、ななめに出た細長い葉
	for s in [[-30, 150], [-6, 190], [20, 140], [40, 170]]:
		var x: float = s[0]
		var h: float = s[1]
		draw_line(Vector2(x, 4), Vector2(x + 6, -h), P.CUCUMBER, 3.0)
		for k in 4:
			var y := -h * (0.35 + k * 0.17)
			var dir := -1.0 if k % 2 == 0 else 1.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + 4, y), Vector2(x + 4 + dir * 46, y - 14), Vector2(x + 4 + dir * 44, y - 6)]), P.CUCUMBER_LIGHT)


func _sasabune() -> void:
	# 川の上（道の向こう）を、ゆらゆら流れる。帆が立っている
	var bob := sin(_t * 2.4) * 2.0
	var p := Vector2(_x, -40 + bob)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-26, 0), p + Vector2(26, 0), p + Vector2(18, 8), p + Vector2(-18, 8)]), P.CUCUMBER_LIGHT)
	draw_line(p + Vector2(-26, 0), p + Vector2(26, 0), P.CUCUMBER, 2.0)
	draw_line(p + Vector2(0, 2), p + Vector2(0, -26), P.CUCUMBER, 2.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(1, -26), p + Vector2(18, -6), p + Vector2(1, -4)]), P.CUCUMBER_LIGHT)


func _laundry() -> void:
	# 物干しの柱2本と竿
	_shadow(Vector2(0, -1), Vector2(160, 6))
	for x in [-150.0, 150.0]:
		draw_rect(Rect2(x - 5, -190, 10, 194), P.SENTAKU_POLE)
		draw_line(Vector2(x - 22, -186), Vector2(x + 22, -186), P.SENTAKU_POLE, 6.0)
	draw_line(Vector2(-170, -184), Vector2(170, -184), P.SENTAKU_LINE, 4.0)
	if _hidden_part:
		return
	var sway := sin(_t * 1.8) * 3.0
	var cols: Array = P.SENTAKU_CLOTHES
	for i in 6:
		var x := -125.0 + i * 50.0
		var c: Color = cols[i]
		var h: float = [60.0, 70.0, 40.0, 76.0, 66.0, 50.0][i]
		draw_colored_polygon(PackedVector2Array([Vector2(x - 18, -182), Vector2(x + 18, -182),
			Vector2(x + 18 + sway, -182 + h), Vector2(x - 18 + sway, -182 + h)]), c)
		draw_rect(Rect2(x - 3, -188, 6, 10), P.WOOD_DARK)


func _mask_stall() -> void:
	# 屋台の絵の前に、お面をかけた板
	_shadow(Vector2(0, -2), Vector2(170, 10))
	var k := 290.0 / _stall.get_height()
	draw_texture_rect(_stall, Rect2(Vector2(-_stall.get_width() * k / 2.0, -290.0), _stall.get_size() * k), false)
	draw_rect(Rect2(-120, -250, 240, 92), P.WOOD)
	draw_rect(Rect2(-120, -250, 240, 92), P.WOOD_DARK, false, 3.0)
	for i in _masks.size():
		draw_texture_rect(_masks[i], Rect2(-110 + i * 76, -246, 70, 70), false)


func _zashiki() -> void:
	# 座敷：たたみ、開けた障子、奥の仏だん、ちゃぶ台。ひさしの下（家の中）なので少し暗い
	var w := 520.0
	draw_rect(Rect2(-w / 2.0, -300, w, 300), P.SHOP_DARK)
	draw_rect(Rect2(-w / 2.0, -320, w, 26), P.HOUSE_ROOF)
	draw_rect(Rect2(-w / 2.0, -40, w, 44), P.SHORYOUMA_TATAMI)
	for x in range(-int(w / 2.0), int(w / 2.0), 130):
		draw_line(Vector2(x, -40), Vector2(x, 4), P.SHORYOUMA_TATAMI.darkened(0.15), 2.0)
	# 障子（左右にあけてある）
	for side in [-1.0, 1.0]:
		var x0: float = side * (w / 2.0 - 60.0) - 30.0
		draw_rect(Rect2(x0, -294, 60, 254), Color("#F4EFE2"))
		for k in 4:
			draw_line(Vector2(x0, -294 + k * 64), Vector2(x0 + 60, -294 + k * 64), P.WOOD, 2.0)
		draw_line(Vector2(x0 + 30, -294), Vector2(x0 + 30, -40), P.WOOD, 2.0)
	# 仏だんと、ちょうちん
	draw_rect(Rect2(-40, -230, 80, 190), P.WOOD_DARK)
	draw_rect(Rect2(-30, -220, 60, 60), P.LANTERN)
	draw_circle(Vector2(-90, -200), 18, Color("#F4EFE2"))
	draw_circle(Vector2(90, -200), 18, Color("#F4EFE2"))
	# 縁側のふち
	draw_rect(Rect2(-w / 2.0 - 10, -6, w + 20, 10), P.WOOD)


func _relatives() -> void:
	# すわった大人と子どものかげ（顔は描かない）
	var n := maxi(1, int(width / 70))
	var cols := [Color("#7A8CA0"), Color("#B88A7A"), Color("#8E9A72"), Color("#A07A9A"), Color("#C9B086")]
	for i in n:
		var x := width * (i + 0.5) / n - width / 2.0
		var kid := i % 3 == 2
		var h := 70.0 if kid else 96.0
		var c: Color = cols[i % cols.size()]
		draw_colored_polygon(PackedVector2Array([Vector2(x - 26, -38), Vector2(x + 26, -38), Vector2(x + 18, -38 - h * 0.55), Vector2(x - 18, -38 - h * 0.55)]), c)
		draw_circle(Vector2(x, -38 - h * 0.55 - 16), 15 if not kid else 13, P.PLAYER_SKIN.darkened(0.1))
		draw_arc(Vector2(x, -38 - h * 0.55 - 16), 13, PI, TAU, 10, Color("#2E2420"), 8.0)


func _shoryouma() -> void:
	# おぼんの上に、きゅうりの馬と、なすの牛
	draw_rect(Rect2(-70, -10, 140, 12), P.WOOD)
	_veg(Vector2(-34, -30), 56.0, P.CUCUMBER, true)
	_veg(Vector2(36, -30), 46.0, P.EGGPLANT, false)


func _veg(c: Vector2, length: float, col: Color, thin: bool) -> void:
	for dx in [-0.32, -0.14, 0.14, 0.32]:
		var x: float = c.x + dx * length
		draw_line(Vector2(x, c.y + 4), Vector2(x, -10), P.HASHI_EDGE, 3.0)
	var h := 10.0 if thin else 18.0
	draw_set_transform(c, 0.0, Vector2(1.0, h / length))
	draw_circle(Vector2.ZERO, length / 2.0, col)
	draw_set_transform(Vector2.ZERO)


func _car() -> void:
	var x := _x
	_shadow(Vector2(x, -2), Vector2(120, 8))
	var body := tint
	draw_rect(Rect2(x - 120, -70, 240, 50), body)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 70, -70), Vector2(x - 44, -112), Vector2(x + 50, -112), Vector2(x + 80, -70)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 58, -72), Vector2(x - 38, -104), Vector2(x - 2, -104), Vector2(x - 2, -72)]), P.BUS_WINDOW)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 6, -72), Vector2(x + 6, -104), Vector2(x + 44, -104), Vector2(x + 68, -72)]), P.BUS_WINDOW)
	for wx in [x - 70, x + 70]:
		draw_circle(Vector2(wx, -18), 20, Color("#2E2A2A"))
		draw_circle(Vector2(wx, -18), 8, Color("#9AA7AD"))


func _hozuki() -> void:
	_shadow(Vector2(0, -1), Vector2(50, 5))
	for s in [[-20, 90], [6, 120], [28, 80]]:
		var x: float = s[0]
		var h: float = s[1]
		draw_line(Vector2(x, 4), Vector2(x + 4, -h), P.CUCUMBER, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 4, -h * 0.7), Vector2(x - 22, -h * 0.8), Vector2(x - 10, -h * 0.6)]), P.CUCUMBER_LIGHT)
		# 赤い実（ちょうちんの形）
		for k in 2:
			var p := Vector2(x + 10 + k * 4, -h * (0.35 + k * 0.3))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(9, 0), p + Vector2(0, 12), p + Vector2(-9, 0)]), P.FIRE)
			draw_line(p + Vector2(0, -12), p + Vector2(0, 12), P.LANTERN_LINE, 1.5)


func _kayari() -> void:
	# ブタの蚊やりと、ゆれる細いけむり
	draw_circle(Vector2(0, -20), 22, Color("#B8B0A0"))
	draw_circle(Vector2(22, -20), 9, Color("#A8A090"))
	draw_circle(Vector2(-6, -24), 9, Color("#5B4C3E"))
	var pts := PackedVector2Array()
	for k in 16:
		var y := -30.0 - k * 9.0
		pts.append(Vector2(-6 + sin(_t * 1.5 + k * 0.5) * k * 0.9, y))
	draw_polyline(pts, Color(0.92, 0.92, 0.9, 0.45), 2.0)


func _whistle() -> void:
	# 口笛の「♪」が、ふわりと上がる
	for k in 3:
		var f := fposmod(_t * 0.35 + k / 3.0, 1.0)
		var p := Vector2(20 + k * 18 + sin(_t * 2.0 + k) * 8.0, -20 - f * 90.0)
		draw_string(FONT, p, Strings.WHISTLE_NOTE, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(UiTokens.PAPER, 1.0 - f))
