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
## 走るお面の子（水彩の絵。右向き）
const FOX_TEX: Texture2D = preload("res://world/scenery/painted/fox_mg1_1.png")
## 背景の絵（村の通り）。走ると横に流れる（左右を交互に反転してつなぐ）。色はシェーダーで抜く
const BG: Texture2D = preload("res://ui/minigame_bg/onigokko.jpg")
const DESATURATE := preload("res://world/shaders/desaturate.gdshader")
## 地面（足もと）の高さ（画面の高さに対する割合）
const FOOT_Y := 0.88
const P := preload("res://world/world_palette.gd")


var phase := Phase.CHASE
var gap := START_GAP
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _dash_in := 1.6
var _dash_left := 0.0
var _scroll := 0.0
var _hold: HoldInput
## 主人公を描く層（色のまま。この画面そのものは色を抜くので、子の層に分ける）
var _me_layer: Control


func _build() -> void:
	rng.randomize()
	set_ambient(WorldPalette.OTHERWORLD_AMBIENT)
	# 色の抜けた村：この画面の絵（背景とお面の子）だけ色を抜く。子の部品（小札・主人公）は色のまま
	var mat := ShaderMaterial.new()
	mat.shader = DESATURATE
	mat.set_shader_parameter("amount", 1.0)
	material = mat
	_me_layer = Control.new()
	_me_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_me_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_me_layer.draw.connect(_draw_me_layer)
	add_child(_me_layer)
	# 小札より奥に描く
	move_child(_me_layer, 0)
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
	_me_layer.queue_redraw()


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
	# 村の通り（走るとうしろへ流れる。動きを減らす設定でも、位置だけはかわる）
	var k := s.y / BG.get_height()
	var tw := BG.get_width() * k
	var off := fposmod(_scroll * 0.5, tw * 2.0)
	var x := -off
	var i := 0
	while x < s.x:
		# となりの絵は左右を反転して、つなぎ目を目立たせない
		if i % 2 == 0:
			draw_texture_rect(BG, Rect2(x, 0, tw, s.y), false)
		else:
			draw_set_transform(Vector2(x + tw, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect(BG, Rect2(0, 0, tw, s.y), false)
			draw_set_transform(Vector2.ZERO)
		x += tw
		i += 1
	# お面の子（村といっしょに色が抜ける）。gap が小さいほど近い。どちらも右へ走る（鬼のときは ぼくがうしろ）
	var fox_x := _me_x() + _dir() * (90.0 + gap * s.x * 0.32)
	var fh := 160.0
	var fw := FOX_TEX.get_width() * fh / FOX_TEX.get_height()
	var bob := absf(sin(clock() * 12.0)) * 5.0 if phase != Phase.END else 0.0
	draw_texture_rect(FOX_TEX, Rect2(fox_x - fw / 2.0, s.y * FOOT_Y - fh - bob, fw, fh), false)


func _me_x() -> float:
	return size.x * (0.36 if phase in [Phase.CHASE, Phase.SWAP] else 0.62)


func _dir() -> float:
	return 1.0 if phase in [Phase.CHASE, Phase.SWAP] else -1.0


## ぼく（色のまま）
func _draw_me_layer() -> void:
	if size.x < 1.0:
		return
	var foot := Vector2(_me_x(), size.y * FOOT_Y)
	var running := phase in [Phase.CHASE, Phase.FLEE] and _hold.is_down
	var frames := Player.FRAMES
	var f := 1 + int(clock() * 10.0) % 4 if running and not UiAnim.reduced() else 0
	var tex: Texture2D = frames[f]
	var h := Player.BODY_HEIGHT
	var w := tex.get_width() * h / tex.get_height()
	_me_layer.draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false)
