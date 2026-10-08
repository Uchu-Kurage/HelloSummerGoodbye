class_name SenkoGame
extends MinigameBase
## ミニゲーム「線香花火」（9日目、初恋ルート）。会話の @game senko で始まる。
## 夜の田んぼ道で、なつみと二人だけの花火大会。押し続けは使わない。
## 火の玉が左右にゆっくり揺れ、揺れはだんだん大きくなる。端に寄りすぎる前に、決定・タップで真ん中へ戻す
## （まん中にあるときに押すと、手がぶれて かえって揺れる）。端まで行くと落ちる。
## ぼたん → まつば → やなぎ → ちりぎく と進む（BURN_TIME 秒）。
## ちりぎくまで落とさなければ「よくできた」（好感度 +1、フラグ senko_good）。なつみの火の玉が先に落ちる。
## ふつうのときは、主人公の火の玉が先に落ちる（フラグ senko_miss）。

enum Phase { BURN, OUTRO }

## 燃えている時間と、移りかわり（[ここから, 名前, 揺れが大きくなる速さ（1秒あたり）]）
const BURN_TIME := 30.0
const STAGES := [[0.0, &"botan", 0.22], [0.2, &"matsuba", 0.36], [0.5, &"yanagi", 0.3], [0.8, &"chirigiku", 0.2]]
## 「よくできた」：この段（ちりぎく）まで落とさない
const GOOD_STAGE := &"chirigiku"
## 揺れの往復の速さと、まん中で押したときに手がぶれる量・まん中とみなす幅
const SWAY_SPEED := 2.4
const JOLT := 0.3
const CENTER := 0.22
## なつみの火の玉が落ちる時（燃えている時間に対する割合。ちりぎくの途中）
const HERS_FALL := 0.9
## 主人公が先に落としたとき、なつみの火が燃えつきるまでの時間
const AFTER_MINE := 3.0
const OUTRO_TIME := 2.4
const P := preload("res://world/world_palette.gd")
## 背景の絵（夜の田んぼ道）と、しゃがんだふたりの絵
const BG: Texture2D = preload("res://ui/minigame_bg/senko.jpg")
const BG_FOCUS := Vector2(0.5, 0.5)
const PAIR: Texture2D = preload("res://world/scenery/painted/senko_pair.png")
## ふたりの絵の高さと足もと（画面の高さに対する割合）、こよりの先（絵の中の 0〜1。左がなつみ、右がぼく）
const PAIR_H := 0.74
const PAIR_FOOT := 0.98
const TIP_HERS := Vector2(0.4685, 0.6467)
const TIP_MINE := Vector2(0.5455, 0.6467)
## 揺れの端（こよりの先から、絵の px で）
const SWAY_PX := 22.0

var phase := Phase.BURN
var burn := 0.0
var mine_fell := false
var hers_fell := false
var held_to_end := false
## 揺れの大きさ（1 で端）と、いまの位置（-1〜1）
var amp := 0.0
var off := 0.0
var _swing := 0.0
var _back := 0.0
var _t := 0.0
var _mine_fall_t := -1.0
var _hers_fall_t := -1.0


func _setup() -> void:
	intro_text = Strings.SENKO_INTRO
	set_ambient(WorldPalette.CAPSULE_AMBIENT)


func _begin() -> void:
	phase = Phase.BURN
	burn = 0.0
	mine_fell = false
	hers_fell = false
	held_to_end = false
	amp = 0.0
	off = 0.0
	_swing = 0.0
	_back = 0.0
	_t = 0.0
	_mine_fall_t = -1.0
	_hers_fall_t = -1.0
	SfxPlayer.play("accept")
	show_hint(Strings.SENKO_HINT_TOUCH, Strings.SENKO_HINT_KEY)


func _stage_info() -> Array:
	var out: Array = STAGES[0]
	for st in STAGES:
		if burn / BURN_TIME >= st[0]:
			out = st
	return out


func stage() -> StringName:
	return _stage_info()[1]


func _process_game(delta: float) -> void:
	_t += delta
	match phase:
		Phase.BURN:
			burn += delta
			if not mine_fell:
				amp += float(_stage_info()[2]) * delta
				_swing += delta * SWAY_SPEED
				# まん中へ戻しているあいだは、なめらかに
				_back = maxf(_back - delta * 4.0, 0.0)
				off = sin(_swing) * amp * (1.0 - _back)
				if absf(off) >= 1.0:
					_drop_mine()
			if not hers_fell and not mine_fell and burn >= BURN_TIME * HERS_FALL:
				_drop_hers()
			if burn >= BURN_TIME:
				_end_burn()
		Phase.OUTRO:
			if _t >= OUTRO_TIME:
				end_game(held_to_end)


## 決定・タップ：火の玉を真ん中へ戻す。まん中にあるときに押すと、手がぶれて揺れる
func _accept(_pos: Variant = null) -> void:
	if phase == Phase.OUTRO:
		speed = UiTokens.SKIP_SPEED
		return
	if mine_fell:
		return
	if absf(off) < CENTER:
		amp += JOLT
	else:
		amp = 0.15
		_back = 1.0
		SfxPlayer.play("cursor")


func _drop_mine() -> void:
	mine_fell = true
	_mine_fall_t = _t
	SfxPlayer.play("plop")
	caption(Strings.SENKO_MINE_FELL)
	hide_hint()
	# 先に落としたときは、なつみの火が燃えつきて、そのまま終わる
	burn = maxf(burn, BURN_TIME - AFTER_MINE)


func _drop_hers() -> void:
	hers_fell = true
	_hers_fall_t = _t
	SfxPlayer.play("plop")
	caption(Strings.SENKO_HERS_FELL)


func _end_burn() -> void:
	held_to_end = not mine_fell
	hide_hint()
	phase = Phase.OUTRO
	_t = 0.0


func _on_quit() -> void:
	mine_fell = true


func bot(good: bool) -> Dictionary:
	if phase != Phase.BURN or mine_fell or not good:
		return {}
	return {"key": KEY_SPACE, "tap": center_tap()} if absf(off) >= 0.6 else {}


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	# 夜の田んぼ道（Gemini の水彩）と、しゃがんで線香花火を持つふたり（左がなつみ、右がぼく）
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var h := s.y * PAIR_H
	var w := PAIR.get_width() * h / PAIR.get_height()
	var r := Rect2(s.x * 0.5 - w / 2.0, s.y * PAIR_FOOT - h, w, h)
	draw_texture_rect(PAIR, r, false)
	# 火の玉は、絵のこよりの先につく
	var k := h / PAIR.get_height()
	_draw_senko(r.position + TIP_HERS * r.size, true, k)
	_draw_senko(r.position + TIP_MINE * r.size, false, k)


## 火の玉を描く。tip はこよりの先、k は絵の 1px が画面で何 px か
func _draw_senko(tip: Vector2, hers: bool, k: float) -> void:
	var fell := hers_fell if hers else mine_fell
	var fall_t := _hers_fall_t if hers else _mine_fall_t
	# ぼくの火の玉は左右に揺れる（端まで行くと落ちる）。なつみのは小さくゆれるだけ
	var sway := off * SWAY_PX * k if not hers else sin(_t * 1.3) * 2.0 * k
	var ball := tip + Vector2(sway, 0)
	if not hers and not mine_fell and phase == Phase.BURN:
		# 揺れの端の目安（うすい線）
		for side in [-1.0, 1.0]:
			var x: float = tip.x + side * SWAY_PX * k
			draw_line(Vector2(x, tip.y - 10.0 * k), Vector2(x, tip.y + 10.0 * k), Color(1, 1, 1, 0.25), 2.0)
	var u := burn / BURN_TIME
	if fell:
		# 落ちていく火の玉が、すぐに消える
		var ft := _t - fall_t
		if ft < 0.6:
			var p := ball + Vector2(0, ft * ft * 900.0)
			draw_circle(p, 5.0 * k * (1.0 - ft / 0.6), P.SENKO_BALL)
		return
	if not hers and phase == Phase.OUTRO:
		# 最後まで燃えきった火の玉は、しずかに暗くなって消える
		var fade := clampf(1.0 - _t / OUTRO_TIME, 0.0, 1.0)
		draw_circle(ball, 5.0 * k * fade, Color(P.SENKO_BALL, fade))
		return
	if hers and phase == Phase.OUTRO:
		return
	# 光のにじみ（顔のあたりまで）
	var size_k: float = clampf(0.4 + u * 1.4, 0.4, 1.0) * (1.0 - smoothstep(0.9, 1.0, u) * 0.6)
	for g in [[60.0, 0.25], [38.0, 0.35], [20.0, 0.5]]:
		draw_circle(ball, g[0] * size_k * k, Color(P.SENKO_GLOW, P.SENKO_GLOW.a * g[1]))
	draw_circle(ball, (6.0 * size_k + 2.0) * k, P.SENKO_BALL)
	draw_circle(ball + Vector2(-1, -1) * k, 2.0 * k, P.SENKO_CORE)
	_sparks(ball, hers, u, k)


## 火花。段ごとに量と長さがかわる（ぼたん：少し、まつば：はげしく、やなぎ：長くたれる、ちりぎく：まばら）
func _sparks(ball: Vector2, hers: bool, u: float, k: float) -> void:
	var st := stage()
	var n := 0
	var reach := 0.0
	match st:
		&"botan":
			n = 4
			reach = 22.0
		&"matsuba":
			n = 12
			reach = 70.0
		&"yanagi":
			n = 8
			reach = 50.0
		&"chirigiku":
			n = 3
			reach = 26.0
	var rng := RandomNumberGenerator.new()
	# 動きを減らす設定では、火花の形を止める
	rng.seed = (0 if UiAnim.reduced() else int(_t * 14.0)) * 2 + (1 if hers else 0)
	for i in n:
		var a := rng.randf() * TAU
		var r := reach * 0.7 * k * (0.5 + rng.randf() * 0.5)
		var dir := Vector2(cos(a), sin(a))
		if st == &"yanagi":
			dir = Vector2(cos(a) * 0.6, absf(sin(a)) + 0.4).normalized()
		var tip := ball + dir * r
		draw_line(ball + dir * 6.0 * k, tip, Color(P.SENKO_SPARK, 0.85), 1.5)
		if st == &"matsuba":
			# 松葉のように先が分かれる
			var side := dir.orthogonal() * 8.0
			draw_line(tip, tip + dir * 6.0 * k + side, Color(P.SENKO_SPARK, 0.7), 1.2)
			draw_line(tip, tip + dir * 6.0 * k - side, Color(P.SENKO_SPARK, 0.7), 1.2)
