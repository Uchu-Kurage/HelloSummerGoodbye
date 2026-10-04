class_name KingyoGame
extends NatsumiScreen
## ミニゲーム「金魚すくい」（5日目、初恋ルート）。会話の @game kingyo で始まる。
## 夜店の水槽を上から見る。ポイは水槽のまん中にかまえている。金魚がポイの上に来たら、タップ（Space）ですくう。
## すくうたびにポイの紙が弱り、金魚の重さでも弱る。破れたらおしまい。失敗はない。
## GOOD_COUNT 匹以上すくえたら高得点（好感度 +1、フラグ kingyo_good）。

enum Phase { READY, PLAY, SCOOP, BROKEN, DONE }

const GOOD_COUNT := 3
## 1回すくうと弱る量と、金魚 1 匹ぶんの重さで弱る量（1.0 で破れる）
const WEAR_SCOOP := 0.17
const WEAR_FISH := 0.1
const FISH_COUNT := 7
## ポイの半径（水槽の短い辺に対する割合）と、すくう動きの時間
const POI_R := 0.16
const SCOOP_TIME := 0.5
const READY_TIME := 1.2
const BROKEN_TIME := 1.8
const P := preload("res://world/world_palette.gd")

var phase := Phase.READY
var caught := 0
var wear := 0.0
var rng := RandomNumberGenerator.new()
## 金魚：{c: 回る中心（0〜1）, r: 半径, w: 角速度, a: 角度, black: 黒い金魚か, gone: すくった}
var fish: Array = []
var _t := 0.0
var _scoop_t := 0.0
var _tub := Rect2()


func _build() -> void:
	rng.randomize()
	for i in FISH_COUNT:
		fish.append({
			"c": Vector2(rng.randf_range(0.35, 0.65), rng.randf_range(0.38, 0.62)),
			"r": Vector2(rng.randf_range(0.12, 0.32), rng.randf_range(0.1, 0.26)),
			"w": rng.randf_range(0.5, 1.0) * (1.0 if i % 2 == 0 else -1.0),
			"a": rng.randf() * TAU,
			"black": i == FISH_COUNT - 1,
			"gone": false,
		})
	say(Strings.KINGYO_START)


func _process(delta: float) -> void:
	var d := delta * speed
	_t += d
	for f in fish:
		if not f.gone:
			f.a += f.w * d
	match phase:
		Phase.READY:
			if _t >= READY_TIME:
				phase = Phase.PLAY
				show_hint(Strings.KINGYO_HINT_TOUCH, Strings.KINGYO_HINT_KEY)
		Phase.SCOOP:
			_scoop_t -= d
			if _scoop_t <= 0.0:
				if wear >= 1.0:
					_broke()
				else:
					phase = Phase.PLAY
		Phase.BROKEN:
			_scoop_t -= d
			if _scoop_t <= 0.0 and not done:
				phase = Phase.DONE
				GameState.set_natsumi_game(&"kingyo", caught >= GOOD_COUNT)
				finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_tap(event):
		return
	if phase == Phase.PLAY:
		scoop()
		get_viewport().set_input_as_handled()
	elif phase == Phase.BROKEN:
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


## 水槽の中の位置（0〜1）を画面の位置に
func _at(f: Dictionary) -> Vector2:
	var u: Vector2 = f.c + Vector2(cos(f.a) * f.r.x, sin(f.a) * f.r.y)
	return _tub.position + u * _tub.size


func _poi_center() -> Vector2:
	return _tub.get_center()


func _poi_radius() -> float:
	return minf(_tub.size.x, _tub.size.y) * POI_R


## いまポイの上にいる金魚の番号
func fish_under_poi() -> Array[int]:
	var out: Array[int] = []
	for i in fish.size():
		var f: Dictionary = fish[i]
		if not f.gone and _at(f).distance_to(_poi_center()) <= _poi_radius():
			out.append(i)
	return out


## すくう（自動の動作確認からも呼べる）
func scoop() -> void:
	if phase != Phase.PLAY:
		return
	var under := fish_under_poi()
	wear += WEAR_SCOOP + WEAR_FISH * under.size()
	SfxPlayer.play("splash")
	if under.is_empty():
		say(Strings.KINGYO_MISS)
	elif wear < 1.0:
		for i in under:
			fish[i].gone = true
		caught += under.size()
		SfxPlayer.play("pickup")
		say(Strings.KINGYO_GOT)
	phase = Phase.SCOOP
	_scoop_t = SCOOP_TIME


func _broke() -> void:
	phase = Phase.BROKEN
	_scoop_t = BROKEN_TIME
	hide_hint()
	SfxPlayer.play("plop")
	say(Strings.KINGYO_BROKE)


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	# 夜店の台の上（暗い木）と、提灯の明かりのにじみ
	draw_rect(Rect2(Vector2.ZERO, s), P.SHOP_DARK)
	for i in 4:
		draw_circle(Vector2(s.x * (0.12 + 0.25 * i), 0), 120, Color(P.LANTERN_GLOW, 0.2))
	var top := UiTokens.SCREEN_MARGIN + 64.0
	var bot := s.y - UiTokens.SCREEN_MARGIN - 56.0
	var h := bot - top
	var w := minf(h * 1.7, s.x - UiTokens.SCREEN_MARGIN * 2)
	_tub = Rect2((s.x - w) / 2.0, top, w, h)
	draw_rect(_tub.grow(10), P.KINGYO_TUB)
	draw_rect(_tub, P.KINGYO_WATER)
	# 水のゆらぎ
	var c := clock()
	for i in 6:
		var y := _tub.position.y + _tub.size.y * (0.12 + 0.15 * i)
		var x := _tub.position.x + fposmod(c * 20.0 + i * 90.0, _tub.size.x - 80.0)
		draw_line(Vector2(x, y), Vector2(x + 60, y), Color(P.WATER_LIGHT, 0.5), 2.0)
	for f in fish:
		if not f.gone:
			_draw_fish(_at(f), f.a + (PI / 2.0 if f.w > 0 else -PI / 2.0), f.black)
	_draw_poi()
	# すくった数（水槽の右下）
	var n := Strings.KINGYO_COUNT % caught
	var font := get_theme_default_font()
	var fs := UiTokens.FONT_BODY
	var tw := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var chip := Rect2(_tub.end.x - tw - 40, _tub.end.y - 56, tw + 24, 44)
	draw_rect(chip, UiTokens.PAPER)
	draw_string(font, chip.position + Vector2(12, 32), n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.INK)


func _draw_fish(p: Vector2, dir: float, black: bool) -> void:
	var col := P.KINGYO_BLACK if black else P.KINGYO_RED
	var k := minf(_tub.size.x, _tub.size.y) / 300.0
	draw_set_transform(p, dir, Vector2(k, k))
	draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(6, -8), Vector2(-8, -6), Vector2(-12, 0), Vector2(-8, 6), Vector2(6, 8)]), col)
	var wag := sin(_t * 10.0) * 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-24, -9 + wag), Vector2(-21, 0), Vector2(-24, 9 + wag)]), col.lightened(0.15))
	draw_set_transform(Vector2.ZERO)


func _draw_poi() -> void:
	var p := _poi_center()
	var r := _poi_radius()
	var dip := 0.0
	if phase == Phase.SCOOP:
		dip = sin(clampf(1.0 - _scoop_t / SCOOP_TIME, 0.0, 1.0) * PI) * 10.0
	# 紙（弱るほど、うすく、しみが広がる。破れたら穴）
	if phase == Phase.BROKEN or phase == Phase.DONE:
		draw_arc(p, r * 0.6, 0.3, PI * 1.6, 16, P.POI_PAPER, 3.0)
	else:
		draw_circle(p + Vector2(0, -dip), r, Color(P.POI_PAPER, P.POI_PAPER.a * (1.0 - wear * 0.6)))
		if wear > 0.3:
			draw_circle(p + Vector2(r * 0.2, -dip), r * wear * 0.5, Color(P.KINGYO_WATER, 0.25))
	draw_arc(p + Vector2(0, -dip), r, 0, TAU, 32, P.POI_FRAME, 6.0)
	# 持ち手（右下へ）
	draw_line(p + Vector2(r * 0.7, r * 0.7 - dip), p + Vector2(r * 2.0, r * 1.9 - dip), P.POI_FRAME, 10.0)
