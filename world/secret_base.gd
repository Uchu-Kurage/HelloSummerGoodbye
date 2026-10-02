@tool
class_name SecretBase
extends Node2D
## 秘密基地（親友ルートの 4・8・9日目で使い回す）。足もとが原点。
## すき間5か所（屋根：左・中・右、壁：左・右）に、4日目のミニゲームではめた材料（GameState.base_slots）を描く。
## - BUILD（4日目）：作りかけ。雨の間は、ふさいでいないすき間から雨だれが落ちる。入口は空いたまま
## - QUIET（8日目）：4日目の形のまま。入口に段ボールの戸（6日目にタケルの家の前にあった箱と同じ）
## - NIGHT（9日目）：夜。懐中電灯（プレイヤー）が近づくと、材料ごとに光の見え方が変わる

enum Mode { BUILD, QUIET, NIGHT }

@export var mode: Mode = Mode.BUILD:
	set(v):
		mode = v
		queue_redraw()

const P := preload("res://world/world_palette.gd")
## すき間の場所（足もとが原点）。0〜2 が屋根、3・4 が壁
const GAPS := [
	Rect2(-180, -200, 120, 34), Rect2(-60, -200, 120, 34), Rect2(60, -200, 120, 34),
	Rect2(-146, -166, 88, 166), Rect2(58, -166, 88, 166),
]
const ROOF_GAPS := 3
const INSIDE := Rect2(-150, -166, 300, 166)
const DOOR := Rect2(-50, -140, 100, 140)
## 雨だれの数（すき間1つあたり）と落ちる速さ
const DRIPS := 4
const DRIP_SPEED := 260.0
## 懐中電灯の光が届く距離
const LIGHT_REACH := 520.0

var _t := 0.0
var _rain := 0.0
var _glow: Node2D
var _player: Node2D


static func gap_rect(i: int) -> Rect2:
	return GAPS[i]


static func is_roof(i: int) -> bool:
	return i < ROOF_GAPS


func _ready() -> void:
	add_to_group("secret_base")
	if Engine.is_editor_hint():
		return
	GameState.base_changed.connect(queue_redraw)
	# 「かいいん」の札をもらったら柱に下げる
	GameState.item_collected.connect(func(_it): queue_redraw())
	GameState.item_gone.connect(func(_it): queue_redraw())
	if mode == Mode.NIGHT:
		var layer := GlowLayer.new()
		add_child(layer)
		_glow = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = m
		_glow.draw.connect(_draw_night)
		layer.add_child(_glow)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if mode == Mode.BUILD:
		var tod := get_tree().get_first_node_in_group("time_of_day")
		_rain = tod.rain if tod else 0.0
		if not UiAnim.reduced():
			_t += delta
		if _rain > 0.0:
			queue_redraw()
	elif _glow:
		_glow.queue_redraw()


## そのすき間の材料。8・9日目に何も記録がない（4日目を通っていない）ときは板にしておく
func _slot(i: int) -> BaseMaterial:
	if Engine.is_editor_hint():
		return null
	var m := GameState.base_slot(i)
	if m == null and mode != Mode.BUILD:
		m = GameState.base_material(&"wood")
	return m


func _uses(look: BaseMaterial.Look) -> bool:
	for i in GAPS.size():
		var m := _slot(i)
		if m and m.look == look:
			return true
	return false


func _draw() -> void:
	# 中（入口や、ふさいでいない壁から見える）。ブルーシートを使うと中が少し青くなる
	var inside := P.SHOP_DARK
	if _uses(BaseMaterial.Look.SHEET):
		inside = inside.lerp(P.BLUE_SHEET, 0.35)
	draw_rect(INSIDE, inside)
	for i in range(ROOF_GAPS, GAPS.size()):
		_draw_gap(i)
	# 入口：4日目は空いたまま（タケルが「あとで つくる」）、8日目からは段ボールの戸
	if mode != Mode.BUILD:
		draw_rect(DOOR, P.CARDBOARD)
		draw_rect(DOOR, P.CARDBOARD_DARK, false, 2.0)
		draw_line(Vector2(DOOR.position.x, -70), Vector2(DOOR.end.x, -70), P.CARDBOARD_DARK, 4.0)
		draw_line(Vector2(0, DOOR.position.y), Vector2(0, DOOR.position.y + 14), P.CARDBOARD_DARK, 5.0)
	# 骨組み（柱と梁）
	draw_rect(Rect2(-56, -166, 112, 26), P.WOOD)
	for x in [-154, -58, 50, 146]:
		draw_rect(Rect2(x, -166, 8, 166), P.WOOD_DARK)
	for i in ROOF_GAPS:
		_draw_gap(i)
	draw_rect(Rect2(-186, -168, 372, 6), P.WOOD_DARK)
	for x in [-182, -62, 58, 178]:
		draw_rect(Rect2(x, -204, 6, 38), P.WOOD_DARK)
	# 「かいいん」の札（入口の柱に下げる）
	if not Engine.is_editor_hint() and GameState.holds(&"base_plaque"):
		draw_line(Vector2(-54, -132), Vector2(-74, -112), P.WOOD_DARK, 2.0)
		draw_line(Vector2(-54, -132), Vector2(-34, -112), P.WOOD_DARK, 2.0)
		draw_rect(Rect2(-84, -112, 60, 28), P.SIGN_BOARD)
		draw_rect(Rect2(-84, -112, 60, 28), P.WOOD_DARK, false, 2.0)
	if mode == Mode.BUILD and _rain > 0.0:
		_draw_drips()


func _draw_gap(i: int) -> void:
	var r: Rect2 = GAPS[i]
	var m := _slot(i)
	if m == null:
		# まだふさいでいない：屋根は空が見え、壁は中が見える。ふちだけうすく
		draw_rect(r, Color(P.WOOD_DARK, 0.5), false, 2.0)
		return
	if m.texture:
		draw_texture_rect(m.texture, r, false)
		return
	draw_material(self, m, r)


## 材料の仮の絵（ミニゲームのボタンでも使う）
static func draw_material(ci: CanvasItem, m: BaseMaterial, r: Rect2) -> void:
	ci.draw_rect(r, m.color)
	match m.look:
		BaseMaterial.Look.WOOD:
			var x := r.position.x + 22.0
			while x < r.end.x:
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), m.color_2, 2.0)
				x += 22.0
		BaseMaterial.Look.TIN:
			var x := r.position.x + 5.0
			while x < r.end.x:
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), m.color_2, 2.0)
				x += 10.0
		BaseMaterial.Look.SHEET:
			ci.draw_line(r.position + Vector2(r.size.x * 0.2, 0), r.position + Vector2(r.size.x * 0.5, r.size.y), m.color_2, 3.0)
			ci.draw_line(r.position + Vector2(r.size.x * 0.75, 0), r.position + Vector2(r.size.x * 0.6, r.size.y), m.color_2, 2.0)
		BaseMaterial.Look.SUDARE:
			var y := r.position.y + 4.0
			while y < r.end.y:
				ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), m.color_2, 1.0)
				y += 6.0
			for x in [r.position.x + 3.0, r.end.x - 3.0]:
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), m.color_2, 2.0)


## ふさいでいないすき間（と、すだれ）から、雨がぽたぽた落ちる
func _draw_drips() -> void:
	var c := Color(P.RAIN_STREAK, P.RAIN_STREAK.a * _rain)
	for i in GAPS.size():
		var m := _slot(i)
		if m and not m.leaks:
			continue
		var r: Rect2 = GAPS[i]
		var n := DRIPS if m == null else 2
		var top := r.end.y if is_roof(i) else r.position.y
		for k in n:
			var x := r.position.x + r.size.x * (k + 0.5) / n
			var fall := -top
			var y := top + fposmod(_t * DRIP_SPEED + k * 53.0 + i * 31.0, fall)
			draw_line(Vector2(x, y), Vector2(x, y + 10), c, 2.0)


## 夜（9日目）。懐中電灯（プレイヤー）が近いほど、材料ごとの光がはっきり見える
func _draw_night() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var k := 0.35
	if _player:
		k += 0.65 * clampf(1.0 - absf(_player.global_position.x - global_position.x) / LIGHT_REACH, 0.0, 1.0)
	for i in GAPS.size():
		var m := _slot(i)
		if m == null:
			continue
		var r: Rect2 = GAPS[i]
		match m.look:
			BaseMaterial.Look.WOOD:
				# 木目が照らされ、板のすき間から細い光が漏れる
				var x := r.position.x + 22.0
				while x < r.end.x:
					_glow.draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), Color(P.LAMP_GLOW, 0.5 * k), 1.0)
					x += 22.0
			BaseMaterial.Look.TIN:
				if is_roof(i):
					# くぎの穴から星が見える
					for n in 5:
						_glow.draw_circle(r.position + Vector2(r.size.x * (n + 0.5) / 5.0, r.size.y * (0.3 + 0.4 * (n % 2))), 1.8, Color(P.STAR, k))
				else:
					_glow.draw_line(r.position + Vector2(4, 8), r.position + Vector2(4, r.size.y - 8), Color(P.LAMP_GLOW, 0.4 * k), 2.0)
			BaseMaterial.Look.SHEET:
				# 光が外まで青く透ける
				_glow.draw_rect(r.grow(10), Color(0.42, 0.62, 1.0, 0.08 * k))
				_glow.draw_rect(r, Color(0.42, 0.62, 1.0, 0.14 * k))
			BaseMaterial.Look.SUDARE:
				# 編み目のむこうに星空が透ける
				for n in 6:
					_glow.draw_circle(r.position + Vector2(r.size.x * fposmod(n * 0.618, 1.0), r.size.y * fposmod(n * 0.414 + 0.2, 1.0)), 1.5, Color(P.STAR, 0.9 * k))
