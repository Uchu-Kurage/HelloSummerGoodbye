class_name DiveGame
extends MinigameBase
## ミニゲーム「飛び込み」（7日目、川の淵の飛び込み岩からタケルと二人で）。会話の @game dive で始まる。
## 1. タケルの「せー……の！」に合わせて、踏み切りのゲージ（左右に揺れる）を決定で止める
## 2. 落ちていき、水面に近づいたら決定で膝を抱える（近いほど良い）
## 2つのタイミングで、しぶきの大きさ（小・中・大）が決まる。タケルと同時に飛び、タケルのしぶきは「中」。
## JUMPS 回飛ぶ（岩にのぼりなおして、もう一回）。いちばん大きかったしぶきで決まり、「大」（タケルより大きい）なら「よくできた」。
## 会話で分けられるよう、GameState.dive_result とフラグも入れる（大 = perfect、中 = late、小 = early）。

enum Phase { COUNT, FALL, SPLASH, CLIMB }
enum Splash { SMALL, MID, LARGE }

## 「よくできた」になるしぶき（大）
const GOOD_SPLASH := Splash.LARGE
## 踏み切りのゲージの片道の秒数と、満点の幅（まん中から ±JUMP_BEST）
const JUMP_PERIOD := 0.7
const JUMP_BEST := 0.1
## 落ちる時間と、膝を抱えるのに満点になる水面までの残り（0〜1 のうち、0〜TUCK_BEST）
const FALL_TIME := 2.0
const TUCK_BEST := 0.12
const SPLASH_TIME := 1.8
## 飛ぶ回数と、岩にのぼりなおす時間
const JUMPS := 3
const CLIMB_TIME := 2.2
const BG: Texture2D = preload("res://ui/minigame_bg/dive.jpg")
const BG_FOCUS := Vector2(0.45, 0.5)
const ME_AIR: Texture2D = preload("res://world/scenery/painted/player_mg1_2.png")
const TK_AIR: Texture2D = preload("res://world/scenery/painted/takeru_mg1_2.png")
const ME_STAND: Texture2D = preload("res://world/scenery/painted/player_mg1_1.png")
const TK_STAND: Texture2D = preload("res://world/scenery/painted/takeru_mg1_1.png")
const P := preload("res://world/world_palette.gd")

var phase := Phase.COUNT
var jump_at := 0.0
var jump_ok := false
var tuck_ok := false
var tucked := false
var fall := 0.0
var splash := Splash.SMALL
## いちばん大きかったしぶきと、飛びおわった回数
var best := Splash.SMALL
var jumps_done := 0
var _t := 0.0


func _setup() -> void:
	intro_text = Strings.DIVE_INTRO


func _begin() -> void:
	best = Splash.SMALL
	jumps_done = 0
	_ready_jump()


func _ready_jump() -> void:
	phase = Phase.COUNT
	speed = 1.0
	jump_ok = false
	tuck_ok = false
	tucked = false
	fall = 0.0
	_t = 0.0
	say(Strings.DIVE_COUNT_SE, Strings.TAKERU)
	show_hint(Strings.DIVE_JUMP_TOUCH, Strings.DIVE_JUMP_KEY)


func _process_game(delta: float) -> void:
	_t += delta
	match phase:
		Phase.COUNT:
			jump_at = swing(_t, JUMP_PERIOD)
		Phase.FALL:
			fall = clampf(_t / FALL_TIME, 0.0, 1.0)
			if fall >= 1.0:
				_land()
		Phase.SPLASH:
			if _t >= SPLASH_TIME and state == State.PLAY:
				jumps_done += 1
				best = maxi(best, splash) as Splash
				if jumps_done < JUMPS:
					phase = Phase.CLIMB
					_t = 0.0
					hush()
				else:
					GameState.set_dive_result([&"early", &"late", &"perfect"][best])
					caption([Strings.DIVE_SMALL, Strings.DIVE_MID, Strings.DIVE_LARGE][best])
					end_game(best == GOOD_SPLASH)
		Phase.CLIMB:
			if _t >= CLIMB_TIME:
				_ready_jump()


func _accept(_pos: Variant = null) -> void:
	match phase:
		Phase.COUNT:
			jump_ok = absf(jump_at - 0.5) <= JUMP_BEST
			SfxPlayer.play("jump")
			say(Strings.DIVE_COUNT_NO, Strings.TAKERU)
			phase = Phase.FALL
			_t = 0.0
			show_hint(Strings.DIVE_TUCK_TOUCH, Strings.DIVE_TUCK_KEY)
		Phase.FALL:
			if not tucked:
				tucked = true
				tuck_ok = 1.0 - fall <= TUCK_BEST
				SfxPlayer.play("cursor")
		Phase.SPLASH, Phase.CLIMB:
			speed = UiTokens.SKIP_SPEED


func _land() -> void:
	phase = Phase.SPLASH
	_t = 0.0
	hide_hint()
	var n := int(jump_ok) + int(tuck_ok)
	splash = [Splash.SMALL, Splash.MID, Splash.LARGE][n]
	SfxPlayer.play("splash")
	caption([Strings.DIVE_SMALL, Strings.DIVE_MID, Strings.DIVE_LARGE][splash])


func _on_quit() -> void:
	GameState.set_dive_result(&"early")


func bot(good: bool) -> Dictionary:
	var hit := false
	match phase:
		Phase.COUNT:
			hit = absf(jump_at - 0.5) <= 0.04 if good else jump_at <= 0.1
		Phase.FALL:
			hit = not tucked and (fall >= 0.94 if good else fall <= 0.3)
	return {"key": KEY_SPACE, "tap": center_tap()} if hit else {}


func _draw() -> void:
	var s := size
	if s.x < 1.0:
		return
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var edge := Vector2(s.x * 0.36, s.y * 0.36)
	var water_y := s.y * 0.8
	var h := s.y * 0.2
	# のこりの回数（右上）
	for i in JUMPS - jumps_done:
		draw_circle(Vector2(s.x - UiTokens.SCREEN_MARGIN - 120.0 - i * 22.0, UiTokens.SCREEN_MARGIN + 20.0), 7.0, Color(1, 1, 1, 0.85))
	match phase:
		Phase.COUNT:
			draw_sprite(TK_STAND, edge + Vector2(-60, 0), h)
			draw_sprite(ME_STAND, edge, h)
			draw_gauge(Rect2(s.x * 0.3, s.y * 0.72, s.x * 0.4, 26), jump_at, 0.5 - JUMP_BEST, 0.5 + JUMP_BEST)
		Phase.FALL:
			var y := lerpf(edge.y, water_y, fall * fall)
			var x := edge.x + s.x * 0.12 * fall
			draw_sprite(TK_AIR, Vector2(x - 70, y), h)
			draw_sprite(ME_AIR, Vector2(x, y), h * (0.8 if tucked else 1.0))
			# 水面が近い印（決定のタイミング）
			draw_line(Vector2(s.x * 0.2, water_y), Vector2(s.x * 0.8, water_y), Color(1, 1, 1, 0.6), 3.0)
		Phase.CLIMB:
			# 岩にのぼりなおす（下から崖の上へ）
			var k := clampf(_t / CLIMB_TIME, 0.0, 1.0)
			var y := lerpf(water_y, edge.y, k)
			draw_sprite(TK_STAND, Vector2(edge.x - 60, y), h)
			draw_sprite(ME_STAND, Vector2(edge.x, y + 20.0 * (1.0 - k)), h)
		Phase.SPLASH:
			var k := clampf(_t / 0.8, 0.0, 1.0)
			var base := Vector2(edge.x + s.x * 0.12, water_y)
			_splash(base + Vector2(-70, 0), 1, k)
			_splash(base, splash, k)


## しぶき（大きさ 0 小 / 1 中 / 2 大）
func _splash(at: Vector2, kind: int, k: float) -> void:
	var r := (24.0 + kind * 22.0) * k
	var a := 1.0 - clampf((_t - 0.8) / 1.0, 0.0, 1.0)
	for i in 7:
		var ang := PI + PI * (i + 0.5) / 7.0
		draw_circle(at + Vector2(cos(ang), sin(ang)) * r, 5.0 + kind * 2.0, Color(1, 1, 1, 0.8 * a))
	draw_arc(at, r * 1.2, 0, TAU, 28, Color(P.WATER_LIGHT, 0.7 * a), 3.0)
