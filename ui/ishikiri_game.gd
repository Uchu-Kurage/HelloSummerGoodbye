class_name IshikiriGame
extends MinigameBase
## ミニゲーム「石切り」（3日目、川原でタケルと勝負）。会話の @game ishikiri で始まる。
## 1. タケルが先に投げて5回跳ねる（「いち、にー、さん、しー、ご！」）
## 2. 投げる角度のゲージ（上下に揺れる。低いほど良い）を決定で止める
## 3. 力のゲージ（左右に揺れる。まん中ほど良い）を決定で止める
## 4. 2つの精度から跳ねる回数が決まる（1〜9回）。跳ねるたびにタケルが数える
## 5. THROWS 回投げる（タケルが「もう一回」投げさせてくれる）。いちばん多く跳ねた回数を記録する
## 跳ねた回数を GameState.ishikiri_best に、勝負（かち／ひきわけ／まけ）をフラグ ishikiri_win / _draw / _lose に入れる。
## GOOD_SKIPS 回以上なら「よくできた」（アイテムの一言は実際の回数で「Nかい はねた。」）。

enum Phase { DEMO, ANGLE, POWER, THROW, SHOW }

## 「よくできた」になる跳ねた回数（仮の値）
const GOOD_SKIPS := 7
## タケルの回数と、勝ち負けの境目（タケルより多ければ かち、同じなら ひきわけ）
const TAKERU_SKIPS := 5
const WIN_AT := 6
const DRAW_AT := 5
const MAX_SKIPS := 9
## 投げる回数（いちばん多く跳ねた回で決まる）
const THROWS := 3
## ゲージの片道の秒数と、満点の幅（角度は下から ANGLE_BEST まで、力はまん中から ±POWER_BEST）
const ANGLE_PERIOD := 0.9
const POWER_PERIOD := 0.75
const ANGLE_BEST := 0.15
const POWER_BEST := 0.08
## 1回跳ねる時間（だんだん短く）と、投げおわって眺める時間
const HOP := 0.34
const HOP_DECAY := 0.9
const SHOW_TIME := 1.4
const BG: Texture2D = preload("res://ui/minigame_bg/ishikiri.jpg")
const BG_FOCUS := Vector2(0.3, 0.6)
const PLAYER_TEX: Texture2D = preload("res://world/scenery/painted/player_mg1_5.png")
const TAKERU_TEX: Texture2D = preload("res://world/scenery/painted/takeru_mg1_5.png")
const P := preload("res://world/world_palette.gd")
const COUNT := ["いち", "にー", "さん", "しー", "ご", "ろく", "なな", "はち", "きゅう"]
## 水面の高さ（画面の高さに対する割合）
const SKIM_Y := 0.66

var phase := Phase.DEMO
var angle := 0.0
var power := 0.0
## いま投げている石の跳ねる回数（タケルのお手本も）
var skips := 0
## 跳ねた回数（いちばん多かった回）と、投げおわった回数
var thrown := 0
var throws_done := 0
var _t := 0.0
var _hops: Array[float] = []
var _counted := 0
var _demo := true


func _setup() -> void:
	intro_text = Strings.ISHI_INTRO


func _begin() -> void:
	_demo = true
	thrown = 0
	throws_done = 0
	_throw(TAKERU_SKIPS)
	say(Strings.ISHI_DEMO)
	hide_hint()


## 角度と力の精度から、跳ねる回数（1〜9）
static func skips_for(angle_at: float, power_at: float) -> int:
	var a := 1.0 if angle_at <= ANGLE_BEST else clampf(1.0 - (angle_at - ANGLE_BEST) / (1.0 - ANGLE_BEST), 0.0, 1.0)
	var off := absf(power_at - 0.5)
	var p := 1.0 if off <= POWER_BEST else clampf(1.0 - (off - POWER_BEST) / (0.5 - POWER_BEST), 0.0, 1.0)
	return clampi(1 + roundi((MAX_SKIPS - 1) * a * p), 1, MAX_SKIPS)


static func result_for(n: int) -> StringName:
	if n >= WIN_AT:
		return &"win"
	if n >= DRAW_AT:
		return &"draw"
	return &"lose"


func _throw(n: int) -> void:
	skips = n
	phase = Phase.THROW if not _demo else Phase.DEMO
	_t = 0.0
	_counted = 0
	_hops.clear()
	var at := 0.5
	var hop := HOP
	for i in n:
		_hops.append(at)
		at += hop
		hop *= HOP_DECAY
	SfxPlayer.play("throw")


func _process_game(delta: float) -> void:
	_t += delta
	match phase:
		Phase.DEMO, Phase.THROW:
			while _counted < skips and _t >= _hops[_counted]:
				_counted += 1
				SfxPlayer.play("skip")
				var words: PackedStringArray = []
				for i in _counted:
					words.append(COUNT[i])
				say("、".join(words) + ("！" if _counted == skips else ""), Strings.TAKERU)
			if _t >= _hops[-1] + SHOW_TIME:
				if phase == Phase.DEMO:
					_demo = false
					_aim()
				else:
					throws_done += 1
					thrown = maxi(thrown, skips)
					if throws_done < THROWS:
						_aim()
					else:
						phase = Phase.SHOW
						GameState.set_ishikiri_best(thrown, result_for(thrown))
						end_game(thrown >= GOOD_SKIPS, thrown)
		Phase.ANGLE:
			angle = swing(_t, ANGLE_PERIOD)
		Phase.POWER:
			power = swing(_t, POWER_PERIOD)


func _aim() -> void:
	phase = Phase.ANGLE
	_t = 0.0
	speed = 1.0
	hush()
	show_hint(Strings.ISHI_ANGLE_TOUCH, Strings.ISHI_ANGLE_KEY)


func _accept(_pos: Variant = null) -> void:
	match phase:
		Phase.ANGLE:
			SfxPlayer.play("cursor")
			phase = Phase.POWER
			_t = 0.0
			show_hint(Strings.ISHI_POWER_TOUCH, Strings.ISHI_POWER_KEY)
		Phase.POWER:
			hide_hint()
			_throw(skips_for(angle, power))
		Phase.DEMO, Phase.THROW:
			# 跳ねているところは早送り
			speed = UiTokens.SKIP_SPEED


func _on_quit() -> void:
	GameState.set_ishikiri_best(0, &"lose")


func bot(good: bool) -> Dictionary:
	var hit := false
	match phase:
		Phase.ANGLE:
			hit = angle <= 0.08 if good else angle >= 0.6
		Phase.POWER:
			hit = absf(power - 0.5) <= 0.04 if good else power <= 0.1
	return {"key": KEY_SPACE, "tap": center_tap()} if hit else {}


func _draw() -> void:
	var s := size
	if s.x < 1.0:
		return
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var foot_y := s.y * 0.9
	var kid_h := s.y * 0.3
	draw_sprite(TAKERU_TEX, Vector2(s.x * 0.08, foot_y - 4), kid_h * 1.02)
	draw_sprite(PLAYER_TEX, Vector2(s.x * 0.18, foot_y), kid_h)
	# 水の輪と、跳ねていく石
	var water := s.y * SKIM_Y
	var x0 := s.x * 0.24
	var step := s.x * 0.075
	for i in _counted:
		var age := _t - _hops[i]
		var r := 10.0 + age * 40.0
		var a := clampf(1.0 - age / 3.0, 0.0, 1.0)
		draw_arc(Vector2(x0 + step * (i + 1), water), r, 0, TAU, 24, Color(P.WATER_LIGHT, a), 2.0)
	if phase in [Phase.DEMO, Phase.THROW] and _counted < skips:
		var i := _counted
		var from_t := 0.0 if i == 0 else _hops[i - 1]
		var k := clampf((_t - from_t) / maxf(_hops[i] - from_t, 0.01), 0.0, 1.0)
		var a := Vector2(x0 + step * i, water) if i > 0 else Vector2(s.x * 0.2, foot_y - kid_h * 0.6)
		var b := Vector2(x0 + step * (i + 1), water)
		var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * (40.0 if i == 0 else 22.0))
		draw_circle(p, 7.0, P.ROCK_DARK)
	# のこりの石（右上に、投げられる数だけ）
	for i in THROWS - throws_done:
		draw_circle(Vector2(s.x - UiTokens.SCREEN_MARGIN - 120.0 - i * 22.0, UiTokens.SCREEN_MARGIN + 20.0), 7.0, P.ROCK_DARK)
	# ゲージ（角度：右の縦、力：下の横）
	var gx := s.x - UiTokens.SCREEN_MARGIN - 48.0
	if phase == Phase.ANGLE or phase == Phase.POWER:
		draw_gauge(Rect2(gx, s.y * 0.25, 28, s.y * 0.4), angle, 0.0, ANGLE_BEST, true)
	if phase == Phase.POWER:
		draw_gauge(Rect2(s.x * 0.3, s.y * 0.72, s.x * 0.4, 26), power, 0.5 - POWER_BEST, 0.5 + POWER_BEST)
