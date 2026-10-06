class_name OnigokkoGame
extends NatsumiScreen
## ミニゲーム「鬼ごっこ」（8日目、神隠しルート）。会話の @game onigokko で始まる。
## 色の抜けた村の道。はじめは ぼくが鬼：押しつづけて走り、お面の子に追いつけばタッチ。
## お面の子は、ときどき ぴゅっと走って離れる（離されても、追いつけないことはない）。
## そのあと、お面の子が鬼になる：押しつづけて逃げるが、最後はつかまる。失敗はない。

enum Phase { CHASE, SWAP, FLEE, END }

## 2人のあいだ（0 で追いついた）。はじめの間と、走る速さ（押しているとき）、お面の子のはやさ
const START_GAP := 1.0
const RUN := 0.42
const FOX_PACE := 0.1
const FOX_DASH := 0.55
const DASH_EVERY := Vector2(1.4, 2.4)
const DASH_TIME := 0.6
const TOUCH_GAP := 0.06
## お面の子が鬼のとき：近づいてくる速さ（押して逃げると、ゆっくりになる）
const CHASER := 0.32
const FLEE_SLOW := 0.6
const SWAP_TIME := 1.4
const END_TIME := 1.8
const FOX_TEX: Texture2D = preload("res://world/scenery/kamikakushi/fox_child.svg")
const P := preload("res://world/world_palette.gd")
## 色のない村（灰色の家なみ・道）
const SKY := Color("#C9CBCC")
const HOUSE := Color("#9A9B9C")
const HOUSE_DARK := Color("#7E7F80")
const ROAD := Color("#B1B0AC")
const GRASS := Color("#8F918E")

var phase := Phase.CHASE
var gap := START_GAP
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _dash_in := 1.6
var _dash_left := 0.0
var _scroll := 0.0
var _hold: HoldInput


func _build() -> void:
	rng.randomize()
	set_ambient(WorldPalette.OTHERWORLD_AMBIENT)
	_hold = HoldInput.new()
	add_child(_hold)
	_hold.enabled = true
	_dash_in = rng.randf_range(DASH_EVERY.x, DASH_EVERY.y)
	say(Strings.ONI_START)
	show_hint(Strings.ONI_HINT_TOUCH, Strings.ONI_HINT_KEY)


func _process(delta: float) -> void:
	var d := delta * speed
	_t += d
	var running := _hold.is_down
	match phase:
		Phase.CHASE:
			# お面の子は、ときどき ぴゅっと離れる
			_dash_in -= d
			if _dash_in <= 0.0:
				_dash_left = DASH_TIME
				_dash_in = rng.randf_range(DASH_EVERY.x, DASH_EVERY.y)
			_dash_left = maxf(0.0, _dash_left - d)
			var fox := FOX_PACE + (FOX_DASH if _dash_left > 0.0 else 0.0)
			# 離されすぎないよう、遠いと お面の子は待ってくれる
			if gap > START_GAP:
				fox = 0.0
			gap += (fox - (RUN if running else 0.0)) * d
			gap = maxf(gap, 0.0)
			if running:
				_scroll += d * 400.0
			if gap <= TOUCH_GAP:
				phase = Phase.SWAP
				_t = 0.0
				_hold.release()
				SfxPlayer.play("pat")
				say(Strings.ONI_TOUCHED)
				hide_hint()
		Phase.SWAP:
			if _t >= SWAP_TIME:
				phase = Phase.FLEE
				_t = 0.0
				gap = START_GAP * 0.8
				say(Strings.ONI_SWAP)
				show_hint(Strings.ONI_FLEE_TOUCH, Strings.ONI_FLEE_KEY)
		Phase.FLEE:
			gap -= CHASER * (FLEE_SLOW if running else 1.0) * d
			if running:
				_scroll += d * 400.0
			if gap <= TOUCH_GAP:
				phase = Phase.END
				_t = 0.0
				_hold.release()
				_hold.enabled = false
				SfxPlayer.play("pat")
				say(Strings.ONI_CAUGHT)
				hide_hint()
		Phase.END:
			if _t >= END_TIME and not done:
				finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if phase in [Phase.SWAP, Phase.END] and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


## 押しつづけている（走っている）か（自動の動作確認から使う）
func hold() -> HoldInput:
	return _hold


func _draw() -> void:
	var s := size
	# 並べ終わる前（大きさ 0）は描かない
	if s.x < 1.0 or s.y < 1.0:
		return
	var ground := s.y * 0.72
	draw_rect(Rect2(Vector2.ZERO, s), SKY)
	# 家なみ（走るとうしろへ流れる。動きを減らす設定でも、位置だけはかわる）
	var w := 260.0
	var off := fposmod(_scroll * 0.5, w)
	var i := 0
	var x := -off
	while x < s.x + w:
		var h := 150.0 + float((i * 37) % 60)
		draw_rect(Rect2(x + 20, ground - h, w - 60, h), HOUSE)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 6, ground - h), Vector2(x + w - 26, ground - h), Vector2(x + w - 60, ground - h - 50), Vector2(x + 40, ground - h - 50)]), HOUSE_DARK)
		draw_rect(Rect2(x + 60, ground - 70, 40, 70), HOUSE_DARK)
		x += w
		i += 1
	draw_rect(Rect2(0, ground, s.x, s.y - ground), GRASS)
	draw_rect(Rect2(0, ground + 10, s.x, 60), ROAD)
	# ぼく（色のまま）と、お面の子。gap が小さいほど近い。どちらも右へ走る（鬼のときは ぼくがうしろ）
	var me_x := s.x * (0.36 if phase in [Phase.CHASE, Phase.SWAP] else 0.62)
	var dir := 1.0 if phase in [Phase.CHASE, Phase.SWAP] else -1.0
	var fox_x := me_x + dir * (90.0 + gap * s.x * 0.32)
	var foot_y := ground + 54
	_draw_me(Vector2(me_x, foot_y), phase in [Phase.CHASE, Phase.FLEE] and _hold.is_down)
	var fh := 150.0
	var fw := FOX_TEX.get_width() * fh / FOX_TEX.get_height()
	var bob := absf(sin(clock() * 12.0)) * 5.0 if phase != Phase.END else 0.0
	draw_set_transform(Vector2(fox_x, foot_y - bob))
	draw_texture_rect(FOX_TEX, Rect2(-fw / 2.0, -fh, fw, fh), false, Color(0.86, 0.86, 0.86))
	draw_set_transform(Vector2.ZERO)


func _draw_me(foot: Vector2, running: bool) -> void:
	var frames := Player.FRAMES
	var f := 1 + int(clock() * 10.0) % 4 if running and not UiAnim.reduced() else 0
	var tex: Texture2D = frames[f]
	var h := Player.BODY_HEIGHT
	var w := tex.get_width() * h / tex.get_height()
	draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false)
