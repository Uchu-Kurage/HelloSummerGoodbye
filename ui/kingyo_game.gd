class_name KingyoGame
extends MinigameBase
## ミニゲーム「金魚すくい」（5日目、初恋ルート）。会話の @game kingyo で始まる。
## 夜店の水槽を上から見る。左右でポイを動かし、金魚の真上で決定を押してすくう。
## すくうたびにポイが弱り、BREAK_AT 回目か、MAX_MISSES 回外すと破れる（破れたらおしまい）。
## GOOD_COUNT 匹以上すくえたら「よくできた」（好感度 +1、フラグ kingyo_good。アイテムの一言「2ひき」と合わせる）。

enum Phase { PLAY, SCOOP, BROKEN }

## 「よくできた」になる、すくった数（仮の値。アイテムの一言「あかいのが 2ひき」と合わせる）
const GOOD_COUNT := 2
## この回目にすくうと破れる／この回数外すと破れる
const BREAK_AT := 4
const MAX_MISSES := 2
## 破れなくても、この時間でおしまい（金魚がいなくなったときも）
const TIME_LIMIT := 50.0
const FISH_COUNT := 6
## ポイの止まる場所の数と、ポイの半径（水槽の短い辺に対する割合）、すくう動きの時間
const LANES := 5
const POI_R := 0.13
const SCOOP_TIME := 0.7
const BROKEN_TIME := 1.6
const P := preload("res://world/world_palette.gd")
## 背景の絵（水槽を真上から）と、切り取るとき残したいところ、絵の中の水のところ（0〜1）
const BG: Texture2D = preload("res://ui/minigame_bg/kingyo.jpg")
const BG_FOCUS := Vector2(0.5, 0.5)
const WATER := Rect2(0.22, 0.2, 0.56, 0.58)

var phase := Phase.PLAY
var caught := 0
var scoops := 0
var misses := 0
var lane := 2
var rng := RandomNumberGenerator.new()
## 金魚：{x: 横の位置（0〜1）, y: 縦の位置（0〜1）, v: 横の速さ, black: 黒い金魚か, gone: すくった}
var fish: Array = []
var _t := 0.0
var _clock := 0.0
var _scoop_t := 0.0
var _tub := Rect2()


func _setup() -> void:
	intro_text = Strings.KINGYO_INTRO
	arrows = true


func _begin() -> void:
	rng.seed = 5 + round_count
	phase = Phase.PLAY
	caught = 0
	scoops = 0
	misses = 0
	lane = 2
	_clock = 0.0
	fish.clear()
	for i in FISH_COUNT:
		fish.append({
			"x": rng.randf(),
			"y": rng.randf_range(0.3, 0.7),
			"v": rng.randf_range(0.07, 0.14) * (1.0 if i % 2 == 0 else -1.0),
			"wy": rng.randf_range(0.6, 1.2),
			"black": i == FISH_COUNT - 1,
			"gone": false,
		})
	_count_caption()
	show_hint(Strings.KINGYO_HINT_TOUCH, Strings.KINGYO_HINT_KEY)


func _count_caption() -> void:
	caption(Strings.KINGYO_COUNT % [caught, BREAK_AT - 1 - scoops if misses < MAX_MISSES else 0])


func _process_game(delta: float) -> void:
	_t += delta
	_clock += delta
	for f in fish:
		if f.gone:
			continue
		f.x += f.v * delta
		if f.x < 0.05 or f.x > 0.95:
			f.v = -f.v
			f.x = clampf(f.x, 0.05, 0.95)
		f.y = clampf(f.y + sin(_clock * f.wy) * 0.02 * delta, 0.25, 0.75)
	match phase:
		Phase.PLAY:
			if _clock >= TIME_LIMIT or fish.all(func(f): return f.gone):
				_finish_round()
		Phase.SCOOP:
			_scoop_t -= delta
			if _scoop_t <= 0.0:
				phase = Phase.PLAY
		Phase.BROKEN:
			_scoop_t -= delta
			if _scoop_t <= 0.0:
				_finish_round()


func _finish_round() -> void:
	end_game(caught >= GOOD_COUNT, caught)


func _left() -> void:
	if phase != Phase.BROKEN and lane > 0:
		lane -= 1
		SfxPlayer.play("cursor")


func _right() -> void:
	if phase != Phase.BROKEN and lane < LANES - 1:
		lane += 1
		SfxPlayer.play("cursor")


func _accept(_pos: Variant = null) -> void:
	if phase == Phase.BROKEN:
		speed = UiTokens.SKIP_SPEED
	elif phase == Phase.PLAY:
		scoop()


## ポイの位置
func _poi_center() -> Vector2:
	var u := (lane + 0.5) / LANES
	return _tub.position + Vector2(u, 0.5) * _tub.size


func _poi_radius() -> float:
	return minf(_tub.size.x, _tub.size.y) * POI_R


func _at(f: Dictionary) -> Vector2:
	return _tub.position + Vector2(f.x, f.y) * _tub.size


## いまポイの真上にいる金魚の番号（いちばん近いもの。いなければ -1）
func fish_under_poi() -> int:
	var best := -1
	var best_d := _poi_radius()
	for i in fish.size():
		var f: Dictionary = fish[i]
		var d := _at(f).distance_to(_poi_center())
		if not f.gone and d <= best_d:
			best_d = d
			best = i
	return best


## すくう。BREAK_AT 回目は破れる。外すと MAX_MISSES 回で破れる
func scoop() -> void:
	if phase != Phase.PLAY:
		return
	scoops += 1
	SfxPlayer.play("splash")
	var under := fish_under_poi()
	if scoops >= BREAK_AT:
		_broke()
		return
	if under < 0:
		misses += 1
		if misses >= MAX_MISSES:
			_broke()
			return
	else:
		fish[under].gone = true
		caught += 1
		SfxPlayer.play("pickup")
	_count_caption()
	phase = Phase.SCOOP
	_scoop_t = SCOOP_TIME


func _broke() -> void:
	phase = Phase.BROKEN
	_scoop_t = BROKEN_TIME
	hide_hint()
	SfxPlayer.play("plop")
	caption(Strings.KINGYO_BROKE % caught)


func bot(good: bool) -> Dictionary:
	if phase != Phase.PLAY:
		return {}
	var under := fish_under_poi()
	if not good and caught >= 1:
		# ふつう：1ぴき すくったら、あとは外して破る
		return {"key": KEY_SPACE, "tap": center_tap()} if under < 0 else {}
	if under >= 0 and _at(fish[under]).distance_to(_poi_center()) < _poi_radius() * 0.6:
		return {"key": KEY_SPACE, "tap": center_tap()}
	# いちばん近い金魚の上へ動く
	var target := -1
	var best_d := INF
	for i in fish.size():
		if fish[i].gone:
			continue
		var d := absf(_at(fish[i]).x - _poi_center().x)
		if d < best_d:
			best_d = d
			target = i
	if target < 0:
		return {}
	var want := clampi(int(fish[target].x * LANES), 0, LANES - 1)
	if want < lane:
		return {"key": KEY_LEFT, "tap": center_tap()}
	if want > lane:
		return {"key": KEY_RIGHT, "tap": center_tap()}
	return {}


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	if s.x < 1.0:
		return
	# 夜店の水槽を真上から見た絵。金魚が泳ぐのは、その水のところ
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var a := _img(WATER.position, s)
	var b := _img(WATER.end, s)
	_tub = Rect2(a, b - a)
	for f in fish:
		if not f.gone:
			_draw_fish(_at(f), 0.0 if f.v > 0 else PI, f.black)
	# ポイの止まる場所（うすい印）
	for i in LANES:
		var p := _tub.position + Vector2((i + 0.5) / LANES, 0.5) * _tub.size
		draw_circle(p, 4.0, Color(1, 1, 1, 0.35))
	_draw_poi()


## 絵の中の点（0〜1）が、画面のどこに来るか（MinigameBg.draw_cover と同じ切り取りかた）
func _img(f: Vector2, s: Vector2) -> Vector2:
	var ts := BG.get_size()
	var k := maxf(s.x / ts.x, s.y / ts.y)
	var src_pos := (ts - s / k) * BG_FOCUS
	return (f * ts - src_pos) * k


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
	var wear := float(scoops) / BREAK_AT + float(misses) / (MAX_MISSES * 2.0)
	# 紙（弱るほど、うすく、しみが広がる。破れたら穴）
	if phase == Phase.BROKEN or state == State.RESULT:
		draw_arc(p, r * 0.6, 0.3, PI * 1.6, 16, P.POI_PAPER, 3.0)
	else:
		draw_circle(p + Vector2(0, -dip), r, Color(P.POI_PAPER, P.POI_PAPER.a * (1.0 - wear * 0.6)))
		if wear > 0.2:
			draw_circle(p + Vector2(r * 0.2, -dip), r * minf(wear, 1.0) * 0.5, Color(P.KINGYO_WATER, 0.25))
	draw_arc(p + Vector2(0, -dip), r, 0, TAU, 32, P.POI_FRAME, 6.0)
	# 持ち手（右下へ）
	draw_line(p + Vector2(r * 0.7, r * 0.7 - dip), p + Vector2(r * 2.0, r * 1.9 - dip), P.POI_FRAME, 10.0)
