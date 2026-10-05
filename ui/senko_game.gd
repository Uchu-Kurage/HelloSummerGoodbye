class_name SenkoGame
extends NatsumiScreen
## ミニゲーム「線香花火」（9日目、初恋ルート）。会話の @game senko で始まる。
## 夜の田んぼ道で、なつみと二人だけの花火大会。
## 1. はじめる前に、押しつづける操作を必ず案内する（押すと火がつく）
## 2. 押しつづけているあいだは手が止まっていて、火の玉が保たれる。離すと手がぶれて、少しで落ちる（GRACE 秒）
## 3. つぼみ → ぼたん → まつば → やなぎ → ちりぎく と移っていく。とちゅうで風が吹くと火の玉がゆれる（見た目だけ）
## 4. なつみのほうが先に落ちる。最後まで落とさなければ高得点（好感度 +1、フラグ senko_good。落ちたら senko_miss）
## 入力は HoldInput（キーボードは Space / Enter / E、タッチ・マウスは画面のどこか）

enum Phase { GUIDE, BURN, OUTRO, DONE }

## 燃えている時間と、移りかわり（[ここから, 名前]）。火花の量と長さは段ごとにかわる
const BURN_TIME := 13.0
const STAGES := [[0.0, &"tsubomi"], [0.12, &"botan"], [0.35, &"matsuba"], [0.68, &"yanagi"], [0.9, &"chirigiku"]]
## 離してから火の玉が落ちるまでの猶予（すぐ押しなおせば、だいじょうぶ）
const GRACE := 0.35
## なつみの火の玉が落ちる時（燃えている時間に対する割合）
const HERS_FALL := 0.82
## 風が吹く時（燃えている時間に対する割合）と、その長さ（秒）
const WINDS := [0.3, 0.62]
const WIND_TIME := 1.4
const OUTRO_TIME := 2.2
const P := preload("res://world/world_palette.gd")
## 背景の絵（夜の田んぼ道）と、しゃがんだふたりの絵（Gemini の水彩）
const BG: Texture2D = preload("res://ui/minigame_bg/senko.jpg")
const BG_FOCUS := Vector2(0.5, 0.5)
const PAIR: Texture2D = preload("res://world/scenery/painted/senko_pair.png")
## ふたりの絵の高さと足もと（画面の高さに対する割合）、こよりの先（絵の中の 0〜1。左がなつみ、右がぼく）
const PAIR_H := 0.74
const PAIR_FOOT := 0.98
const TIP_HERS := Vector2(0.4685, 0.6467)
const TIP_MINE := Vector2(0.5455, 0.6467)

var phase := Phase.GUIDE
var burn := 0.0
## 落ちた（主人公の火の玉）
var mine_fell := false
var hers_fell := false
var held_to_end := false
var _off := 0.0
var _t := 0.0
var _mine_fall_t := -1.0
var _hers_fall_t := -1.0
var _wind_said := false
var _hold: HoldInput


func _build() -> void:
	_hold = HoldInput.new()
	_hold.pressed.connect(_on_pressed)
	add_child(_hold)
	_hold.enabled = true
	set_ambient(WorldPalette.CAPSULE_AMBIENT)
	say(Strings.SENKO_GUIDE)
	show_hint(Strings.SENKO_HINT_TOUCH, Strings.SENKO_HINT_KEY)


func _on_pressed() -> void:
	if phase == Phase.GUIDE:
		phase = Phase.BURN
		SfxPlayer.play("accept")
		hush()
		show_hint(Strings.SENKO_HOLD_TOUCH, Strings.SENKO_HOLD_KEY)


func stage() -> StringName:
	var out: StringName = STAGES[0][1]
	for st in STAGES:
		if burn / BURN_TIME >= st[0]:
			out = st[1]
	return out


func _wind() -> float:
	var u := burn / BURN_TIME
	for w in WINDS:
		var dt: float = (u - w) * BURN_TIME
		if dt >= 0.0 and dt < WIND_TIME:
			return sin(dt / WIND_TIME * PI)
	return 0.0


func _process(delta: float) -> void:
	var d := delta * speed
	_t += d
	match phase:
		Phase.BURN:
			burn += d
			# 離すと手がぶれる。猶予をすぎたら落ちる
			if _hold.is_down:
				_off = 0.0
			elif not mine_fell:
				_off += d
				if _off >= GRACE:
					_drop_mine()
			if _wind() > 0.2 and not _wind_said:
				_wind_said = true
				say(Strings.SENKO_WIND)
			elif _wind() <= 0.0 and _wind_said and not hers_fell and not mine_fell:
				_wind_said = false
			if not hers_fell and not mine_fell and burn >= BURN_TIME * HERS_FALL:
				_drop_hers()
			if burn >= BURN_TIME:
				_end_burn()
		Phase.OUTRO:
			if _t >= OUTRO_TIME and not done:
				phase = Phase.DONE
				GameState.set_natsumi_game(&"senko", held_to_end)
				finish()
	queue_redraw()


func _drop_mine() -> void:
	mine_fell = true
	_mine_fall_t = _t
	SfxPlayer.play("plop")
	say(Strings.SENKO_MINE_FELL)
	hide_hint()
	_hold.enabled = false
	# 先に落としたときは、なつみの火は最後まで燃えて、そのまま終わる
	burn = maxf(burn, BURN_TIME * 0.6)


func _drop_hers() -> void:
	hers_fell = true
	_hers_fall_t = _t
	SfxPlayer.play("plop")
	say(Strings.SENKO_HERS_FELL)


func _end_burn() -> void:
	held_to_end = not mine_fell
	if held_to_end:
		say(Strings.SENKO_END)
	hide_hint()
	_hold.enabled = false
	phase = Phase.OUTRO
	_t = 0.0


func _input(event: InputEvent) -> void:
	if phase == Phase.OUTRO and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


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
	# 手がぶれる（主人公が離しているとき）・風でゆれる。こよりの絵から離れすぎないよう、小さく
	var sway := _wind() * 5.0 * k * sin(_t * 2.6 + (1.0 if hers else 0.0))
	var shake := 0.0
	if not hers and not _hold.is_down and phase == Phase.BURN and not mine_fell and not UiAnim.reduced():
		shake = sin(_t * 50.0) * 3.0 * k * (_off / GRACE)
	if UiAnim.reduced():
		sway = 0.0
	var ball := tip + Vector2(sway + shake, 0)
	var lit := phase != Phase.GUIDE
	if not lit:
		return
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
