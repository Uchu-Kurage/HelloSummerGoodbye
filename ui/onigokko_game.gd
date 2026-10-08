class_name OnigokkoGame
extends MinigameBase
## ミニゲーム「鬼ごっこ」（8日目、神隠しルート）。会話の @game onigokko で始まる。
## 色の抜けた村の道。ぼくが鬼で、前を走るお面の子を追いかける（走るのは自動）。
## 塀や水たまりが来たら、その前で決定を押して飛び越える（このミニゲームだけの動き）。飛び越えると近づき、ぶつかると離される。
## 距離のゲージが0になったら つかまえる。GOOD_TIME 秒以内につかまえたら「よくできた」。
## 間に合わなければ、お面の子が止まって振り返る（そこへ追いついて おわり。ふつう）。

enum Phase { CHASE, TURN, CAUGHT }

## 「よくできた」になる、つかまえるまでの秒数（仮の値）
const GOOD_TIME := 45.0
## 距離（1 から 0 へ）。走っているだけで近づく速さ、飛び越えたとき近づく量、ぶつかったとき離される量
const START_GAP := 1.0
const CLOSE_RATE := 0.018
const JUMP_GAIN := 0.034
const BUMP_LOSS := 0.05
## 障害物の間隔（秒。ばらつく）と、近づく速さ（画面の px／秒）、飛んでいる時間、ぶつかって止まる時間
const OBSTACLE_EVERY := Vector2(2.2, 3.0)
const OBSTACLE_SPEED := 300.0
const JUMP_TIME := 0.7
const BUMP_TIME := 0.8
## 振り返ったお面の子へ追いつく時間と、つかまえてから終わるまでの時間
const TURN_TIME := 2.4
const CAUGHT_TIME := 2.0
## 走るお面の子（水彩の絵。右向き）と、振り返った絵
const FOX_TEX: Texture2D = preload("res://world/scenery/painted/fox_mg1_1.png")
const FOX_TURN: Texture2D = preload("res://world/scenery/painted/fox_mg1_4.png")
## 背景の絵（村の通り）。走ると横に流れる（左右を交互に反転してつなぐ）。色はシェーダーで抜く
const BG: Texture2D = preload("res://ui/minigame_bg/onigokko.jpg")
const DESATURATE := preload("res://world/shaders/desaturate.gdshader")
const FOOT_Y := 0.88
const P := preload("res://world/world_palette.gd")

var phase := Phase.CHASE
var gap := START_GAP
var jumps := 0
var bumps := 0
## 障害物：{t: ぼくの足もとに来るまでの秒, kind: 0 塀／1 水たまり}
var obstacles: Array = []
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _clock := 0.0
var _next := 1.5
var _jump := 0.0
var _bump := 0.0
var _scroll := 0.0
## 主人公を描く層（色のまま。この画面そのものは色を抜くので、子の層に分ける）
var _me_layer: Control


func _setup() -> void:
	intro_text = Strings.ONI_INTRO
	set_ambient(WorldPalette.OTHERWORLD_AMBIENT)
	var mat := ShaderMaterial.new()
	mat.shader = DESATURATE
	mat.set_shader_parameter("amount", 1.0)
	material = mat
	_me_layer = Control.new()
	_me_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_me_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_me_layer.draw.connect(_draw_me_layer)
	add_child(_me_layer)
	move_child(_me_layer, 0)


func _begin() -> void:
	rng.seed = 88 + round_count
	phase = Phase.CHASE
	gap = START_GAP
	jumps = 0
	bumps = 0
	obstacles.clear()
	_t = 0.0
	_clock = 0.0
	_next = 1.5
	_jump = 0.0
	_bump = 0.0
	show_hint(Strings.ONI_HINT_TOUCH, Strings.ONI_HINT_KEY)


func _process_game(delta: float) -> void:
	_t += delta
	_jump = maxf(_jump - delta, 0.0)
	_bump = maxf(_bump - delta, 0.0)
	_me_layer.queue_redraw()
	match phase:
		Phase.CHASE:
			_clock += delta
			var moving := _bump <= 0.0
			if moving:
				_scroll += delta * OBSTACLE_SPEED
				gap -= CLOSE_RATE * delta
				_next -= delta
				for o in obstacles:
					o.t -= delta
			if _next <= 0.0:
				obstacles.append({"t": 2.0, "kind": rng.randi_range(0, 1)})
				_next = rng.randf_range(OBSTACLE_EVERY.x, OBSTACLE_EVERY.y)
			for o in obstacles.duplicate():
				if o.t <= 0.0:
					obstacles.erase(o)
					if _jump > 0.0:
						jumps += 1
						gap -= JUMP_GAIN
					else:
						bumps += 1
						gap += BUMP_LOSS
						_bump = BUMP_TIME
						SfxPlayer.play("cancel")
			gap = clampf(gap, 0.0, START_GAP)
			if gap <= 0.0:
				_catch()
			elif _clock >= GOOD_TIME:
				# 間に合わなかった：お面の子が止まって振り返る
				phase = Phase.TURN
				_t = 0.0
				obstacles.clear()
				hide_hint()
				caption(Strings.ONI_TURN)
		Phase.TURN:
			_scroll += delta * OBSTACLE_SPEED * 0.6
			gap = maxf(gap - delta / TURN_TIME, 0.0)
			if gap <= 0.0:
				_catch()
		Phase.CAUGHT:
			if _t >= CAUGHT_TIME:
				end_game(_clock < GOOD_TIME, int(_clock))


func _catch() -> void:
	phase = Phase.CAUGHT
	_t = 0.0
	hide_hint()
	SfxPlayer.play("accept")
	caption(Strings.ONI_CAUGHT)


## 決定：飛び越える（飛んでいるあいだは、もう一度は飛べない）
func _accept(_pos: Variant = null) -> void:
	if phase == Phase.CAUGHT:
		speed = UiTokens.SKIP_SPEED
		return
	if phase != Phase.CHASE or _jump > 0.0 or _bump > 0.0:
		return
	_jump = JUMP_TIME
	SfxPlayer.play("jump")


## いちばん近い障害物が、足もとに来るまでの秒（なければ大きな値）
func next_obstacle() -> float:
	var best := 99.0
	for o in obstacles:
		best = minf(best, o.t)
	return best


func bot(good: bool) -> Dictionary:
	if not good or phase != Phase.CHASE or _jump > 0.0 or _bump > 0.0:
		return {}
	return {"key": KEY_SPACE, "tap": center_tap()} if next_obstacle() <= 0.4 else {}


# --- 絵 -----------------------------------------------------------------------

func _me_x() -> float:
	return size.x * 0.3


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	# 村の通り（走るとうしろへ流れる）
	var k := s.y / BG.get_height()
	var tw := BG.get_width() * k
	var off := fposmod(_scroll * 0.5, tw * 2.0)
	var x := -off
	var i := 0
	while x < s.x:
		if i % 2 == 0:
			draw_texture_rect(BG, Rect2(x, 0, tw, s.y), false)
		else:
			draw_set_transform(Vector2(x + tw, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect(BG, Rect2(0, 0, tw, s.y), false)
			draw_set_transform(Vector2.ZERO)
		x += tw
		i += 1
	var foot_y := s.y * FOOT_Y
	# 障害物（塀・水たまり）
	for o in obstacles:
		var ox: float = _me_x() + o.t * OBSTACLE_SPEED
		if o.kind == 0:
			draw_rect(Rect2(ox - 14, foot_y - 56, 28, 56), P.WOOD_DARK)
			draw_rect(Rect2(ox - 20, foot_y - 62, 40, 8), P.WOOD)
		else:
			draw_set_transform(Vector2(ox, foot_y - 4), 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, 46, Color(P.WATER_LIGHT, 0.8))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# お面の子（村といっしょに色が抜ける）。gap が小さいほど近い。振り返ったら止まる
	var fox_x := _me_x() + 70.0 + gap * s.x * 0.55
	var fh := s.y * 0.24
	if phase == Phase.TURN or phase == Phase.CAUGHT:
		draw_sprite(FOX_TURN, Vector2(fox_x, foot_y), fh, true)
	else:
		var bob := absf(sin(clock() * 12.0)) * 5.0
		draw_sprite(FOX_TEX, Vector2(fox_x, foot_y - bob), fh)
	# 距離のゲージ（上のまん中。0 になったら つかまえる）
	var gr := Rect2(s.x * 0.3, UiTokens.SCREEN_MARGIN + 70.0, s.x * 0.4, 18)
	draw_rect(gr, Color(UiTokens.PAPER, 0.9))
	draw_rect(Rect2(gr.position, Vector2(gr.size.x * gap / START_GAP, gr.size.y)), UiTokens.INK_SOFT)
	draw_rect(gr, UiTokens.INK_SOFT, false, 2.0)


## ぼく（色のまま）。飛んでいるあいだは上へ
func _draw_me_layer() -> void:
	if size.x < 1.0:
		return
	var lift := sin(clampf(1.0 - _jump / JUMP_TIME, 0.0, 1.0) * PI) * 70.0 if _jump > 0.0 else 0.0
	var foot := Vector2(_me_x(), size.y * FOOT_Y - lift)
	var running := state == State.PLAY and phase != Phase.CAUGHT and _bump <= 0.0
	var frames := Player.FRAMES
	var f := 1 + int(clock() * 10.0) % 4 if running and not UiAnim.reduced() else 0
	var tex: Texture2D = frames[f]
	var h := Player.BODY_HEIGHT
	var w := tex.get_width() * h / tex.get_height()
	_me_layer.draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false)
