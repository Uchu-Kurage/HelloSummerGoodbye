class_name ShoryoumaGame
extends MinigameBase
## ミニゲーム「精霊馬づくり」（6日目、ノーマルルート）。会話の @game shoryouma で始まる。
## ちゃぶ台の上で、きゅうり（うま）となす（うし）に、割りばしの足を4本ずつさす。
## 割りばし（印）が野菜の下を左右に行き来する。足をさすところ（●）の上に来たら決定（タップ）でさす。4本さしたら、なすも同じ。
## ずれても、少しななめの足になるだけ（失敗で止まらない）。8本のうち GOOD_LEGS 本以上まっすぐなら「よくできた」
## （馬も牛も、4本ともまっすぐ立つ。HUD がフラグ shoryouma_good／ちがえば shoryouma_miss を立てる）。

enum Phase { INTRO, PLACE, STAND, END }

## 足をさすところ（野菜の長さに対する割合。左から順にさす）
const LEG_AT := [0.2, 0.36, 0.64, 0.8]
## ●からこのくらい（野菜の長さに対する割合）までなら、まっすぐ
const GOOD_TOL := 0.06
## 割りばしが野菜の左はしから右はしまで行く時間（秒）
const SWEEP_TIME := 2.2
const INTRO_TIME := 2.0
const STAND_TIME := 2.4
## 「よくできた」になる、まっすぐの足の数（8本のうち。仮の値）
const GOOD_LEGS := 8
## 出てすぐの決定は受けつけない（つづけて押して、さしてしまわないように）
const TAP_GUARD := 0.3
const P := preload("res://world/world_palette.gd")
## 背景の絵（お盆の夕方の座敷とちゃぶ台。窓の外は透明なので、うしろに夕方の空の色をぬる）と、残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/shoryouma.png")
const BG_FOCUS := Vector2(0.5, 0.5)
## 足をさす前の、きゅうりとなすの絵（veg の順）
const VEG_TEX: Array[Texture2D] = [
	preload("res://world/scenery/painted/shoryouma_veg_1.png"),
	preload("res://world/scenery/painted/shoryouma_veg_2.png"),
]

var phase := Phase.INTRO
## いまの野菜（0 きゅうり、1 なす）
var veg := 0
## さした足の位置（野菜の長さに対する割合）。野菜ごと
var legs: Array = [[], []]
var good := 0
var _t := 0.0
## 割りばしの位置（0.0〜1.0。行ったり来たり）
var _sweep := 0.0
var _dir := 1.0


func _setup() -> void:
	intro_text = Strings.SHORYOUMA_INTRO


func _begin() -> void:
	legs = [[], []]
	good = 0
	_start_veg(0)


func _start_veg(i: int) -> void:
	veg = i
	phase = Phase.INTRO
	_t = 0.0
	_sweep = 0.0
	_dir = 1.0
	say(Strings.SHORYOUMA_VEG[i][1])
	hide_hint()


## いまさす足の、ねらうところ
func target() -> float:
	return LEG_AT[mini((legs[veg] as Array).size(), LEG_AT.size() - 1)]


## 割りばしのいまの位置
func sweep() -> float:
	return _sweep


## いまの位置で足をさす（自動の動作確認からも呼べる）
func stick() -> void:
	if phase != Phase.PLACE or _t < TAP_GUARD:
		return
	var aim: float = target()
	var ok := absf(_sweep - aim) <= GOOD_TOL
	# ずれたときは、ねらいのとなりに少しななめにささる
	var at := _sweep if ok else aim + clampf(_sweep - aim, -GOOD_TOL * 2.0, GOOD_TOL * 2.0)
	(legs[veg] as Array).append(at)
	if ok:
		good += 1
	SfxPlayer.play("place_wood")
	caption(Strings.SHORYOUMA_GOOD if ok else Strings.SHORYOUMA_TILT)
	if (legs[veg] as Array).size() >= LEG_AT.size():
		phase = Phase.STAND
		_t = 0.0
		hide_hint()
		caption(Strings.SHORYOUMA_DONE_UMA if veg == 0 else Strings.SHORYOUMA_DONE_USHI)


func _process_game(delta: float) -> void:
	_t += delta
	match phase:
		Phase.INTRO:
			if _t >= INTRO_TIME:
				phase = Phase.PLACE
				_t = 0.0
				show_hint(Strings.SHORYOUMA_HINT_TOUCH, Strings.SHORYOUMA_HINT_KEY)
		Phase.PLACE:
			_sweep += _dir * delta / SWEEP_TIME
			if _sweep >= 1.0:
				_sweep = 1.0
				_dir = -1.0
			elif _sweep <= 0.0:
				_sweep = 0.0
				_dir = 1.0
		Phase.STAND:
			if _t >= STAND_TIME:
				speed = 1.0
				if veg == 0:
					_start_veg(1)
				else:
					phase = Phase.END
					end_game(good >= GOOD_LEGS, good)


func _accept(_pos: Variant = null) -> void:
	if phase == Phase.PLACE:
		stick()
	else:
		speed = UiTokens.SKIP_SPEED


func bot(want_good: bool) -> Dictionary:
	if phase != Phase.PLACE or _t < TAP_GUARD:
		return {}
	# ふつう：1本目だけ、わざと ずらす
	var off := absf(_sweep - target())
	var hit := off <= GOOD_TOL * 0.4 if want_good or good + (legs[0] as Array).size() > 0 else off >= GOOD_TOL * 3.0
	return {"key": KEY_SPACE, "tap": center_tap()} if hit else {}


## 野菜を描く場所（まん中の大きな野菜）：左はし・右はし・おなかの高さ
func _veg_rect() -> Rect2:
	var s := size
	# なすは、きゅうりより短くて太い
	var w := minf(s.x * 0.4, 520.0) * (1.0 if veg == 0 else 0.62)
	return Rect2(s.x / 2.0 - w / 2.0, s.y * 0.42, w, s.y * 0.12)


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	# 座敷とちゃぶ台の絵（窓の外は夕方の空の色）
	draw_rect(Rect2(Vector2.ZERO, s), P.KAKURENBO_EVENING_TOP)
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	# できた うま（きゅうり）は、ちゃぶ台の左の奥に小さく立てておく
	if veg == 1 or phase == Phase.END:
		_draw_veg(0, Rect2(s.x * 0.3, s.y * 0.33, s.x * 0.1, s.y * 0.03), legs[0], 1.0)
	var r := _veg_rect()
	var lift := 0.0
	if phase == Phase.STAND:
		lift = smoothstep(0.0, 0.6, _t)
	_draw_veg(veg, r, legs[veg], lift)
	if phase == Phase.PLACE:
		# ねらうところの ●（紙の色の丸に ACCENT_INK。ちゃぶ台の上でも見えるように）と、行き来する割りばし
		var aim := r.position.x + r.size.x * target()
		draw_circle(Vector2(aim, r.end.y + 10), 13, UiTokens.PAPER)
		draw_circle(Vector2(aim, r.end.y + 10), 8, UiTokens.ACCENT_INK)
		var x := r.position.x + r.size.x * _sweep
		var top := r.end.y + 24
		draw_rect(Rect2(x - 5, top, 10, r.size.y * 1.6), P.HASHI)
		draw_rect(Rect2(x - 5, top, 10, r.size.y * 1.6), P.HASHI_EDGE, false, 2.0)


## 野菜と、さした足。lift（0〜1）で、足で立ち上がる
func _draw_veg(i: int, r: Rect2, leg_list: Array, lift: float) -> void:
	var leg_len := r.size.y * 1.4
	var y := r.position.y - leg_len * 0.6 * lift
	var body := Rect2(r.position.x, y, r.size.x, r.size.y)
	for at in leg_list:
		var x: float = body.position.x + body.size.x * at
		var aim: float = LEG_AT[0]
		for a in LEG_AT:
			if absf(a - at) < absf(aim - at):
				aim = a
		var tilt: float = (at - aim) * body.size.x * 2.0
		var foot := Vector2(x + tilt, body.end.y + leg_len * (0.25 + 0.6 * lift))
		draw_line(Vector2(x, body.end.y - 4), foot, P.HASHI_EDGE, 9.0)
		draw_line(Vector2(x, body.end.y - 4), foot, P.HASHI, 6.0)
	# 野菜の絵を、横の長さを body にそろえて、おなかの高さに置く（足は上で描いた）
	var tex: Texture2D = VEG_TEX[i]
	var h := body.size.x * tex.get_height() / tex.get_width()
	draw_texture_rect(tex, Rect2(body.position.x, body.end.y - h + body.size.y * 0.15, body.size.x, h), false)
