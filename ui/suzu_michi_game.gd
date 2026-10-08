class_name SuzuMichiGame
extends MinigameBase
## ミニゲーム「鈴の音で道探し」（6日目、神隠しルート）。会話の @game suzu_michi で始まる。
## 暗い森の分かれ道が FORKS か所。先を行くお面の子の鈴が、ひだりか みぎで鳴る。左右キー（タッチは ← → のボタン）で、鳴ったほうへ進む。
## 音が出せない環境でも進めるよう、鈴が鳴るたびに、同じ側で光がゆれる（共通の決まり「音が頼りのもの」）。決定で、もう一度鳴らしてもらえる。
## ちがうほうを選ぶと、同じ分かれ道にもどる。まちがいが GOOD_WRONG 回以内なら「よくできた」。

enum Phase { LISTEN, WALK, BACK, END }

const FORKS := 5
## 「よくできた」になる、まちがいの数（仮の値）
const GOOD_WRONG := 1
## はじめに鈴が鳴るまでと、そのあと鳴る間隔、光がゆれている時間
const FIRST_RING := 1.2
const RING_EVERY := 2.6
const GLOW_TIME := 1.4
## 次の分かれ道まで歩く時間／まちがえて もどる時間
const WALK_TIME := 2.2
const BACK_TIME := 2.0
const END_TIME := 2.0
const P := preload("res://world/world_palette.gd")
const DARK := Color("#0F1420")
## 背景の絵（夜の森の分かれ道）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/suzu_michi.jpg")
const BG_FOCUS := Vector2(0.5, 0.5)

var phase := Phase.LISTEN
var fork := 0
var wrong := 0
## いまの分かれ道で、鈴の鳴るほう（0 ひだり／1 みぎ）と、鳴った回数
var side := 0
var rings := 0
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _ring_t := 0.0
var _glow := 0.0
## 進んだ向き（歩く絵の向き）
var _went := 0


func _setup() -> void:
	intro_text = Strings.SUZU_MICHI_INTRO
	arrows = true
	set_ambient(WorldPalette.OTHERWORLD_AMBIENT)


func _begin() -> void:
	rng.seed = 66 + round_count
	phase = Phase.LISTEN
	fork = 0
	wrong = 0
	_new_fork()
	caption(Strings.SUZU_MICHI_FORK % [fork + 1, FORKS])
	show_hint(Strings.SUZU_MICHI_HINT_TOUCH, Strings.SUZU_MICHI_HINT_KEY)


func _new_fork() -> void:
	side = rng.randi_range(0, 1)
	_listen()


func _listen() -> void:
	phase = Phase.LISTEN
	rings = 0
	_t = 0.0
	_ring_t = RING_EVERY - FIRST_RING
	_glow = 0.0


## 鈴が鳴った（rings > 0）ときの、鳴ったほう。まだなら -1（自動の動作確認から使う）
func heard_side() -> int:
	return side if phase == Phase.LISTEN and rings > 0 else -1


func _ring() -> void:
	rings += 1
	_ring_t = 0.0
	_glow = GLOW_TIME
	SfxPlayer.play("suzu_far")


func _process_game(delta: float) -> void:
	_t += delta
	_glow = maxf(_glow - delta, 0.0)
	match phase:
		Phase.LISTEN:
			_ring_t += delta
			if _ring_t >= RING_EVERY:
				_ring()
		Phase.WALK:
			if _t >= WALK_TIME:
				speed = 1.0
				fork += 1
				if fork >= FORKS:
					phase = Phase.END
					_t = 0.0
					hide_hint()
					caption(Strings.SUZU_MICHI_OUT)
				else:
					_new_fork()
					caption(Strings.SUZU_MICHI_FORK % [fork + 1, FORKS])
		Phase.BACK:
			if _t >= BACK_TIME:
				speed = 1.0
				# 同じ分かれ道にもどる（鈴の鳴るほうは そのまま）
				_listen()
				caption(Strings.SUZU_MICHI_FORK % [fork + 1, FORKS])
		Phase.END:
			if _t >= END_TIME:
				end_game(wrong <= GOOD_WRONG, wrong)


func _left() -> void:
	choose(0)


func _right() -> void:
	choose(1)


## 決定：もう一度、鈴を鳴らしてもらう（タッチは、画面の左右の半分をタップしても進める）
func _accept(pos: Variant = null) -> void:
	if phase != Phase.LISTEN:
		speed = UiTokens.SKIP_SPEED
		return
	if pos is Vector2:
		var local: Vector2 = pos - global_position
		choose(0 if local.x < size.x / 2.0 else 1)
		return
	_ring()


## 分かれ道を選ぶ（0 ひだり／1 みぎ。自動の動作確認からも呼べる）
func choose(i: int) -> void:
	if phase != Phase.LISTEN:
		return
	_went = i
	_t = 0.0
	SfxPlayer.play("accept")
	if i == side:
		phase = Phase.WALK
	else:
		wrong += 1
		phase = Phase.BACK
		caption(Strings.SUZU_MICHI_WRONG)


func bot(good: bool) -> Dictionary:
	var h := heard_side()
	if h < 0:
		return {}
	# ふつう：はじめの分かれ道で、2回 反対へ行く
	var go := h if good or fork > 0 or wrong >= 2 else 1 - h
	return {"key": KEY_LEFT if go == 0 else KEY_RIGHT, "tap": global_position + Vector2(size.x * (0.25 if go == 0 else 0.75), size.y * 0.4), "tap_only": true}


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var c := clock()
	# 鈴の鳴ったほうで、光がゆれる（音が出せないときの印）。分かれた道の先のあたり
	if _glow > 0.0:
		var k := _glow / GLOW_TIME
		var sway := sin(c * 9.0) * 12.0 if not UiAnim.reduced() else 0.0
		var p := Vector2(s.x / 2.0 + (side * 2 - 1) * s.x * 0.3 + sway, s.y * 0.4)
		draw_circle(p, 48, Color(1.0, 0.95, 0.72, 0.18 * k))
		draw_circle(p, 18, Color(1.0, 0.95, 0.72, 0.6 * k))
		draw_circle(p, 7, Color(1.0, 1.0, 0.9, 0.95 * k))
		draw_string(get_theme_default_font(), p + Vector2(-26, -34), Strings.KAKURENBO_BELL_MARK, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_SMALL, Color(1, 1, 1, 0.9 * k))
	# 歩いている（もどっている）あいだは、暗くなって次の（同じ）分かれ道へ
	if phase in [Phase.WALK, Phase.BACK]:
		var dur := WALK_TIME if phase == Phase.WALK else BACK_TIME
		draw_rect(Rect2(Vector2.ZERO, s), Color(DARK, 0.7 * sin(clampf(_t / dur, 0.0, 1.0) * PI)))
	# 分かれ道をいくつ来たか（小さな足あとの印）
	for i in FORKS:
		var col := Color(1, 1, 1, 0.75) if i < fork else Color(1, 1, 1, 0.25)
		draw_circle(Vector2(s.x / 2.0 - (FORKS - 1) * 12 + i * 24, s.y * 0.6), 5, col)
