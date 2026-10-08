class_name KabutoGame
extends MinigameBase
## ミニゲーム「カブトムシとり」（6日目、夜明け前のクヌギ林）。会話の @game kabuto で始まる。
## 暗い木の幹を、左右キーで懐中電灯で照らす（照らす場所は SPOTS か所）。カナブン・クワガタ・小さいカブトムシ・
## 大きいオスのカブトムシが、出たり隠れたりする。照らした虫に決定で捕まえる。チャンスは CHANCES 回、いちばん大きいものを持ち帰る。
## 大きいオスを捕まえたら「よくできた」。時間（TIME_LIMIT）がきたら、それまでのいちばん大きいもの。
## 会話で分けられるよう、よくできたらフラグ kabuto_clean、ちがえば kabuto_dropped も立てる（GameState.set_kabuto_result）。

enum Phase { HUNT, DONE }

## 虫（大きさの順）：カナブン・クワガタ・小さいカブトムシ・大きいオス
const BUGS := ["カナブン", "クワガタ", "ちいさい カブトムシ", "おおきい オスの カブトムシ"]
const BIG := 3
## 「よくできた」になる虫（大きいオス）
const GOOD_BUG := BIG
const SPOTS := 5
const CHANCES := 3
const TIME_LIMIT := 45.0
## 虫が出ている時間と、隠れている時間（ばらつく）
const SHOW_TIME := Vector2(1.6, 2.8)
const HIDE_TIME := Vector2(1.0, 3.0)
## 大きいオスは、はじめは BIG_FIRST 秒後、そのあと BIG_EVERY 秒ごとに、どこかに出る（必ずチャンスがあるように）
const BIG_FIRST := 12.0
const BIG_EVERY := 8.0
const BG: Texture2D = preload("res://ui/minigame_bg/kabuto.jpg")
const BG_FOCUS := Vector2(0.6, 0.75)
const P := preload("res://world/world_palette.gd")
## 照らす場所（画面に対する割合。幹の上）
const SPOT_AT := [Vector2(0.52, 0.42), Vector2(0.58, 0.3), Vector2(0.64, 0.46), Vector2(0.7, 0.33), Vector2(0.76, 0.5)]

var phase := Phase.HUNT
var light := 2
var chances := CHANCES
## 持ち帰る虫（いちばん大きいもの。まだなら -1）
var best := -1
## 場所ごとの虫（いなければ -1）と、残りの時間
var bugs: Array[int] = []
var _left_time: Array[float] = []
var _t := 0.0
var _big_t := 0.0
var rng := RandomNumberGenerator.new()


func _setup() -> void:
	intro_text = Strings.KABUTO_INTRO
	arrows = true


func _begin() -> void:
	rng.seed = 6 + round_count
	phase = Phase.HUNT
	light = 2
	chances = CHANCES
	best = -1
	_t = 0.0
	_big_t = BIG_FIRST
	bugs.clear()
	_left_time.clear()
	for i in SPOTS:
		bugs.append(-1)
		_left_time.append(rng.randf_range(0.3, HIDE_TIME.y))
	_refresh_hint()
	show_hint(Strings.KABUTO_HINT_TOUCH % chances, Strings.KABUTO_HINT_KEY % chances)
	set_ambient(KABUTO_AMBIENT)


const KABUTO_AMBIENT := "higurashi_dawn"


func _process_game(delta: float) -> void:
	if phase != Phase.HUNT:
		return
	_t += delta
	_big_t -= delta
	for i in SPOTS:
		_left_time[i] -= delta
		if _left_time[i] > 0.0:
			continue
		if bugs[i] >= 0:
			bugs[i] = -1
			_left_time[i] = rng.randf_range(HIDE_TIME.x, HIDE_TIME.y)
		else:
			var kind := rng.randi_range(0, BIG - 1)
			if _big_t <= 0.0 and not bugs.has(BIG):
				kind = BIG
				_big_t = BIG_EVERY
			bugs[i] = kind
			_left_time[i] = rng.randf_range(SHOW_TIME.x, SHOW_TIME.y)
			SfxPlayer.play("kabuto_rustle")
	if _t >= TIME_LIMIT:
		_end()


func _left() -> void:
	if phase == Phase.HUNT and light > 0:
		light -= 1
		SfxPlayer.play("cursor")


func _right() -> void:
	if phase == Phase.HUNT and light < SPOTS - 1:
		light += 1
		SfxPlayer.play("cursor")


func _accept(pos: Variant = null) -> void:
	if phase != Phase.HUNT:
		return
	# タッチは、場所をタップすると、そこを照らして、虫がいれば そのまま捕まえる
	if pos is Vector2:
		var near := _spot_at(pos)
		if near < 0:
			return
		light = near
	var kind := bugs[light]
	if kind < 0:
		SfxPlayer.play("cancel")
		return
	SfxPlayer.play("kabuto_grab")
	chances -= 1
	best = maxi(best, kind)
	bugs[light] = -1
	_left_time[light] = rng.randf_range(HIDE_TIME.x, HIDE_TIME.y)
	caption(Strings.KABUTO_GOT % BUGS[kind])
	show_hint(Strings.KABUTO_HINT_TOUCH % chances, Strings.KABUTO_HINT_KEY % chances)
	if chances <= 0 or kind == BIG:
		_end()


func _spot_at(pos: Vector2) -> int:
	var best_i := -1
	var best_d := 90.0
	for i in SPOTS:
		var d := (_spot_pos(i) - (pos - global_position)).length()
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _spot_pos(i: int) -> Vector2:
	return size * SPOT_AT[i]


func _end() -> void:
	phase = Phase.DONE
	if best < 0:
		best = 0
	var good := best >= GOOD_BUG
	GameState.set_kabuto_result(0 if good else 1)
	caption(Strings.KABUTO_TAKE % BUGS[best])
	end_game(good)


func _on_quit() -> void:
	GameState.set_kabuto_result(1)


func bot(good: bool) -> Dictionary:
	if phase != Phase.HUNT:
		return {}
	var target := bugs.find(BIG) if good else _small_spot()
	if target < 0:
		return {}
	if target < light:
		return {"key": KEY_LEFT, "tap": global_position + _spot_pos(target)}
	if target > light:
		return {"key": KEY_RIGHT, "tap": global_position + _spot_pos(target)}
	return {"key": KEY_SPACE, "tap": global_position + _spot_pos(target)}


func _small_spot() -> int:
	for i in SPOTS:
		if bugs[i] >= 0 and bugs[i] < BIG:
			return i
	return -1


func _draw() -> void:
	var s := size
	if s.x < 1.0:
		return
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	# 夜明け前の暗さ。懐中電灯の丸い光のところだけ明るく
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.08, 0.55))
	var lp := _spot_pos(light)
	if phase == Phase.HUNT:
		draw_circle(lp, 74, Color(1.0, 0.95, 0.75, 0.16))
		draw_circle(lp, 52, Color(1.0, 0.95, 0.75, 0.2))
	for i in bugs.size():
		var p := _spot_pos(i)
		var lit := i == light and phase == Phase.HUNT
		if bugs[i] >= 0:
			_draw_bug(p, bugs[i], 1.0 if lit else 0.3)
		elif lit:
			draw_arc(p, 18, 0, TAU, 16, Color(1, 1, 1, 0.25), 2.0)


func _draw_bug(p: Vector2, kind: int, a: float) -> void:
	var r := (9.0 + kind * 4.0) * maxf(size.y / 420.0, 1.0)
	var col := Color(P.BEETLE, a) if kind != 0 else Color(0.25, 0.42, 0.28, a)
	draw_set_transform(p, 0.0, Vector2(0.75, 1.0))
	draw_circle(Vector2.ZERO, r, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(p + Vector2(0, -r * 0.9), r * 0.45, col)
	if kind == 1:
		draw_line(p + Vector2(-4, -r * 1.2), p + Vector2(-8, -r * 1.8), col, 3.0)
		draw_line(p + Vector2(4, -r * 1.2), p + Vector2(8, -r * 1.8), col, 3.0)
	elif kind >= 2:
		draw_line(p + Vector2(0, -r * 1.2), p + Vector2(0, -r * (1.6 + 0.4 * (kind - 2))), col, 3.0 + kind)
