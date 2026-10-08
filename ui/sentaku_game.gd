class_name SentakuGame
extends MinigameBase
## ミニゲーム「洗濯物の取り込み」（4日目、ノーマルルート）。会話の @game sentaku で始まる。
## 祖父母の家の庭。物干しに6枚。左から夕立の雲が近づいてきて、RAIN_TIME 秒で降りだす。
## 左右で物干しの下を動いて、決定で取り込む（取り込むあいだは少し手が止まる）。布団は重いので2回押す。
## 降りだしたら、残りは少しぬれて、おばあちゃんが取り込んでくれる（ふつう）。雨の前に全部取り込めたら「よくできた」。
## HUD がフラグ sentaku_good／sentaku_miss を立てる（直後のおばあちゃんのせりふが変わる）。

enum Phase { PICK, TAKING, RAIN, END }

## 降りだすまでの時間（秒）。この前に全部取り込めたら「よくできた」
const RAIN_TIME := 20.0
## 取り込む手の止まる時間（1回押すごと）と、1つとなりへ動く時間
const TAKE_TIME := 1.5
const STEP_TIME := 0.3
## 布団（Strings.SENTAKU_CLOTHES の番号）と、取り込むのに押す回数
const FUTON := 5
const FUTON_PRESSES := 2
const END_TIME := 2.2
const P := preload("res://world/world_palette.gd")
## 背景の絵（夏の昼の庭。空は透明なので、うしろに空と夕立の雲を描く）と、残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/sentaku.png")
const BG_FOCUS := Vector2(0.4, 0.6)
## 洗濯物の絵（布団いがい。Strings.SENTAKU_CLOTHES の順）
const CLOTHES: Array[Texture2D] = [
	preload("res://world/scenery/painted/sentaku_cloth_1.png"),
	preload("res://world/scenery/painted/sentaku_cloth_2.png"),
	preload("res://world/scenery/painted/sentaku_cloth_3.png"),
	preload("res://world/scenery/painted/sentaku_cloth_4.png"),
	preload("res://world/scenery/painted/sentaku_cloth_5.png"),
]
const FUTON_COLOR := Color("#D8C3A6")
const FUTON_PATTERN := Color("#B7684F")
const STREAKS := 60

var phase := Phase.PICK
var spot := 0
## 取り込んだか・ぬれたか・押した回数（布団は2回）
var taken: Array[bool] = []
var wet: Array[bool] = []
var presses: Array[int] = []
var _clock := 0.0
var _t := 0.0
var _x := 0.0


func _setup() -> void:
	intro_text = Strings.SENTAKU_INTRO
	arrows = true


func _begin() -> void:
	phase = Phase.PICK
	spot = 0
	_x = 0.0
	_clock = 0.0
	_t = 0.0
	taken.clear()
	wet.clear()
	presses.clear()
	for i in Strings.SENTAKU_CLOTHES.size():
		taken.append(false)
		wet.append(false)
		presses.append(0)
	_count_caption()
	show_hint(Strings.SENTAKU_HINT_TOUCH, Strings.SENTAKU_HINT_KEY)


func taken_count() -> int:
	return taken.count(true)


func _count_caption() -> void:
	caption(Strings.SENTAKU_COUNT % [taken_count(), taken.size()])


## 雲の近づきぐあい（0 晴れ〜1 降りだし）
func cloud_amount() -> float:
	return clampf(_clock / RAIN_TIME, 0.0, 1.0)


func _process_game(delta: float) -> void:
	_t += delta
	_x = move_toward(_x, spot, delta / STEP_TIME)
	if phase in [Phase.PICK, Phase.TAKING]:
		_clock += delta
	match phase:
		Phase.TAKING:
			if _t >= TAKE_TIME:
				phase = Phase.PICK
				if presses[spot] >= (FUTON_PRESSES if spot == FUTON else 1):
					taken[spot] = true
					SfxPlayer.play("pickup")
					_count_caption()
					if taken_count() == taken.size():
						_end(false)
						return
	if phase in [Phase.PICK, Phase.TAKING] and _clock >= RAIN_TIME:
		_end(true)
	if phase in [Phase.RAIN, Phase.END] and _t >= END_TIME:
		end_game(not wet.has(true), taken_count())


func _end(rain: bool) -> void:
	_t = 0.0
	hide_hint()
	if rain:
		phase = Phase.RAIN
		for i in taken.size():
			if not taken[i]:
				wet[i] = true
		SfxPlayer.play("rain_start")
		caption(Strings.SENTAKU_RAIN)
	else:
		phase = Phase.END
		caption(Strings.SENTAKU_ALL)


func _left() -> void:
	if phase == Phase.PICK and spot > 0:
		spot -= 1
		SfxPlayer.play("cursor")


func _right() -> void:
	if phase == Phase.PICK and spot < taken.size() - 1:
		spot += 1
		SfxPlayer.play("cursor")


func _accept(pos: Variant = null) -> void:
	if phase in [Phase.RAIN, Phase.END]:
		speed = UiTokens.SKIP_SPEED
		return
	if phase != Phase.PICK:
		return
	# タッチは、洗濯物をタップすると、そこへ行って取り込む
	if pos is Vector2:
		var hit := _spot_at(pos)
		if hit < 0:
			return
		spot = hit
		_x = hit
	take(spot)


## 取り込む（自動の動作確認からも呼べる）。布団は2回
func take(i: int) -> void:
	if phase != Phase.PICK or i < 0 or i >= taken.size() or taken[i]:
		return
	spot = i
	presses[i] += 1
	phase = Phase.TAKING
	_t = 0.0
	SfxPlayer.play("accept")
	if i == FUTON and presses[i] < FUTON_PRESSES:
		caption(Strings.SENTAKU_FUTON)


func bot(good: bool) -> Dictionary:
	if phase != Phase.PICK:
		return {}
	# よくできた：はしから順に。ふつう：布団だけ残す（1回だけ押して、あとは待つ）
	var want := -1
	for i in taken.size():
		if not taken[i] and (good or i != FUTON or presses[i] == 0):
			want = i
			break
	if want < 0:
		return {}
	if want < spot:
		return {"key": KEY_LEFT, "tap": _spot_tap(want)}
	if want > spot:
		return {"key": KEY_RIGHT, "tap": _spot_tap(want)}
	return {"key": KEY_SPACE, "tap": _spot_tap(want)}


# --- 絵 -----------------------------------------------------------------------

func _line_y() -> float:
	return size.y * 0.3


func _spot_xf(f: float) -> float:
	return size.x * (0.2 + 0.6 * f / float(maxi(taken.size() - 1, 1)))


func _spot_tap(i: int) -> Vector2:
	return global_position + Vector2(_spot_xf(i), _line_y() + size.y * 0.1)


func _spot_at(pos: Vector2) -> int:
	var local: Vector2 = pos - global_position
	if local.y < _line_y() - 20.0 or local.y > size.y * 0.95:
		return -1
	var best := -1
	var best_d := size.x * 0.07
	for i in taken.size():
		var d := absf(local.x - _spot_xf(i))
		if d < best_d:
			best_d = d
			best = i
	return best


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	var k := cloud_amount()
	var sky := P.SENTAKU_SKY.lerp(P.RAIN_SKY, smoothstep(0.4, 1.0, k))
	draw_rect(Rect2(Vector2.ZERO, s), sky)
	# 左から近づいてくる夕立の雲
	var front := -s.x * 0.3 + s.x * 1.3 * k
	var c := clock()
	for i in 7:
		var r := s.y * (0.12 + 0.03 * (i % 3))
		var x := front - i * s.x * 0.16 + sin(c * 0.6 + i) * 6.0
		draw_circle(Vector2(x, s.y * 0.12 + (i % 2) * r * 0.5), r, P.SENTAKU_CLOUD)
	draw_rect(Rect2(-10, 0, maxf(0.0, front - s.x * 0.9), s.y * 0.24), P.SENTAKU_CLOUD)
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS, Color.WHITE.lerp(P.RAIN_LIGHT, k * 0.6))
	if taken.is_empty():
		return
	# 物干し（両はしの柱と、ひも）
	var ground := s.y * 0.9
	var top := _line_y()
	var left := _spot_xf(0) - s.x * 0.07
	var right := _spot_xf(taken.size() - 1) + s.x * 0.07
	for x in [left, right]:
		draw_rect(Rect2(x - 6, top - 20, 12, ground - top + 20), P.SENTAKU_POLE)
	draw_line(Vector2(left, top), Vector2(right, top), P.SENTAKU_LINE, 3.0)
	var cw := s.x * 0.09
	for i in taken.size():
		var x := _spot_xf(i)
		draw_rect(Rect2(x - cw * 0.3 - 3, top - 6, 6, 12), P.SENTAKU_POLE)
		draw_rect(Rect2(x + cw * 0.3 - 3, top - 6, 6, 12), P.SENTAKU_POLE)
		if taken[i]:
			continue
		var tint := Color(0.82, 0.86, 0.95) if wet[i] else Color.WHITE
		var sway := 0.0 if UiAnim.reduced() else sin(c * 2.0 + i) * 0.04
		draw_set_transform(Vector2(x, top - 4.0), sway, Vector2.ONE)
		if i == FUTON:
			# 布団（大きくて重い。1回押すと半分たたまれる）
			var fh := s.y * (0.26 if presses[i] == 0 else 0.14)
			draw_rect(Rect2(-cw * 0.62, 0, cw * 1.24, fh), FUTON_COLOR * tint)
			# 布団の柄（たてのしま）と、ふちの線
			for d in 4:
				draw_rect(Rect2(-cw * 0.5 + d * cw * 0.3, 0, cw * 0.1, fh), FUTON_PATTERN * tint)
			draw_rect(Rect2(-cw * 0.62, 0, cw * 1.24, fh), (FUTON_PATTERN * tint).darkened(0.3), false, 2.0)
		else:
			var tex: Texture2D = CLOTHES[i % CLOTHES.size()]
			var kk := minf(cw / tex.get_width(), s.y * 0.2 / tex.get_height())
			var sz := tex.get_size() * kk
			draw_texture_rect(tex, Rect2(-sz.x / 2.0, 0, sz.x, sz.y), false, tint)
		draw_set_transform(Vector2.ZERO)
	# ぼく（物干しの下）と、選んでいる場所の印
	var me := Vector2(_spot_xf(_x), ground)
	var frames := Player.FRAMES
	var moving := absf(_x - spot) > 0.01
	var tex2: Texture2D = frames[1 + int(c * 10.0) % 4] if moving and not UiAnim.reduced() else frames[0]
	var h := s.y * 0.34
	draw_sprite(tex2, me, h, _x > spot)
	if phase == Phase.PICK:
		draw_arc(Vector2(_spot_xf(spot), top + s.y * 0.12), cw * 0.6, 0.15 * PI, 0.85 * PI, 18, UiTokens.ACCENT_INK, 4.0)
	# 雨のすじ
	if phase == Phase.RAIN:
		for i in STREAKS:
			var fx := fposmod(i * 0.6180339, 1.0)
			var fy := fposmod(i * 0.4142135 + c * 1.3, 1.0)
			var p := Vector2(fx * s.x, fy * s.y)
			draw_line(p, p + Vector2(-5, 22), Color(P.RAIN_STREAK, 0.45), 2.0)
