class_name KaigaraGame
extends MinigameBase
## ミニゲーム「貝がら拾い」（6日目、初恋ルート）。会話の @game kaigara で始まる。
## 波打ちぎわを、左右で歩いて、決定で足もとの貝がらを拾う。拾えるのは波が引いているあいだだけ。
## 波が来たら自動で下がる（そのあいだは拾えない）。波が引くたびに、砂の上の貝がらが入れかわる。全部で TIME_LIMIT 秒。
## さくら貝は、SAKURA_TIMES 回だけ顔を出す（1〜2回）。拾えたら「よくできた」（好感度 +1、フラグ kaigara_good）。

enum Phase { OUT, IN }

## 「よくできた」：さくら貝を拾う（拾った数ではない）
const GOOD_SAKURA := 1
const TIME_LIMIT := 30.0
## 波が引いている（拾える）時間と、寄せている時間
const OUT_TIME := 3.6
const IN_TIME := 1.8
## 歩ける場所の数（横に並ぶ）
const SPOTS := 6
## さくら貝が顔を出す回数（1〜2回。何回目の引き波か）
const SAKURA_TIMES := Vector2i(1, 2)
const P := preload("res://world/world_palette.gd")
## 背景の絵（お盆の昼の浜辺）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/kaigara.jpg")
const BG_FOCUS := Vector2(0.4, 0.5)
const PLAYER_TEX: Texture2D = preload("res://world/scenery/painted/player_mg1_5.png")
const NATSUMI_TEX: Texture2D = preload("res://world/scenery/painted/natsumi_mg1_2.png")
## 貝がらの種類：0 しろい二枚貝・1 巻き貝・2 さくら貝（小さくてうすい桃色）。種類ごとの絵と、画面での大きさ
const SHELL_ART := [
	[preload("res://world/scenery/painted/shell_1.png"), preload("res://world/scenery/painted/shell_3.png")],
	[preload("res://world/scenery/painted/shell_2.png"), preload("res://world/scenery/painted/shell_4.png")],
	[preload("res://world/scenery/painted/shell_5.png")],
]
const SAKURA := 2
const SHELL_SIZE := [60.0, 56.0, 38.0]

var phase := Phase.OUT
var spot := 2
var found := false
var picks := 0
var rng := RandomNumberGenerator.new()
## 場所ごとの貝がら（種類の番号。なければ -1）と、その絵
var shells: Array[int] = []
var _art: Array = []
## 引き波の回数と、さくら貝が出る引き波の番号
var waves := 0
var _sakura_waves: Array[int] = []
var _t := 0.0
var _clock := 0.0


func _setup() -> void:
	intro_text = Strings.KAIGARA_INTRO
	arrows = true


func _begin() -> void:
	rng.seed = 6 + round_count
	phase = Phase.OUT
	spot = 2
	found = false
	picks = 0
	waves = 0
	_t = 0.0
	_clock = 0.0
	# 引き波は TIME_LIMIT のあいだに5〜6回。さくら貝はそのうち1〜2回（はじめと終わりは避ける）
	_sakura_waves.clear()
	var n := rng.randi_range(SAKURA_TIMES.x, SAKURA_TIMES.y)
	var candidates := [1, 2, 3, 4]
	for k in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t: int = candidates[k]
		candidates[k] = candidates[j]
		candidates[j] = t
	for i in n:
		_sakura_waves.append(candidates[i])
	_new_shells()
	caption(Strings.KAIGARA_COUNT % picks)
	show_hint(Strings.KAIGARA_HINT_TOUCH, Strings.KAIGARA_HINT_KEY)


func _new_shells() -> void:
	shells.clear()
	_art.clear()
	for i in SPOTS:
		shells.append(rng.randi_range(0, 1) if rng.randf() < 0.55 else -1)
	if waves in _sakura_waves:
		# プレイヤーのいる場所から少し離れたところに、ひとつだけ
		var at := (spot + rng.randi_range(2, SPOTS - 2)) % SPOTS
		shells[at] = SAKURA
	for k in shells:
		if k < 0:
			_art.append(null)
		else:
			var arts: Array = SHELL_ART[k]
			_art.append(arts[rng.randi_range(0, arts.size() - 1)])


## いま、さくら貝がある場所（なければ -1。自動の動作確認から使う）
func sakura_spot() -> int:
	return shells.find(SAKURA) if phase == Phase.OUT else -1


func _process_game(delta: float) -> void:
	_t += delta
	_clock += delta
	match phase:
		Phase.OUT:
			if _t >= OUT_TIME:
				# 波が来る。自動で下がる（拾えない）。砂の上の貝がらは持っていかれる
				phase = Phase.IN
				_t = 0.0
				SfxPlayer.play("splash")
		Phase.IN:
			if _t >= IN_TIME:
				phase = Phase.OUT
				_t = 0.0
				waves += 1
				_new_shells()
				SfxPlayer.play("surface")
	if _clock >= TIME_LIMIT:
		end_game(found, picks)


func _left() -> void:
	if phase == Phase.OUT and spot > 0:
		spot -= 1
		SfxPlayer.play("cursor")


func _right() -> void:
	if phase == Phase.OUT and spot < SPOTS - 1:
		spot += 1
		SfxPlayer.play("cursor")


func _accept(_pos: Variant = null) -> void:
	if phase != Phase.OUT:
		return
	var kind := shells[spot]
	if kind < 0:
		SfxPlayer.play("cancel")
		return
	shells[spot] = -1
	picks += 1
	SfxPlayer.play("pickup")
	if kind == SAKURA:
		found = true
		caption(Strings.KAIGARA_GOT_SAKURA)
	else:
		caption(Strings.KAIGARA_COUNT % picks)


func bot(good: bool) -> Dictionary:
	if phase != Phase.OUT:
		return {}
	var target := sakura_spot() if good else _plain_spot()
	if target < 0:
		return {}
	if target < spot:
		return {"key": KEY_LEFT, "tap": center_tap()}
	if target > spot:
		return {"key": KEY_RIGHT, "tap": center_tap()}
	return {"key": KEY_SPACE, "tap": center_tap()}


func _plain_spot() -> int:
	var best := -1
	for i in SPOTS:
		if shells[i] >= 0 and shells[i] != SAKURA and (best < 0 or absi(i - spot) < absi(best - spot)):
			best = i
	return best


# --- 絵 -----------------------------------------------------------------------

## 波の先の高さ（0 = 海のふち、1 = 砂のいちばん手前）
func _wave() -> float:
	match phase:
		Phase.IN:
			return sin(clampf(_t / IN_TIME, 0.0, 1.0) * PI)
		Phase.OUT:
			return 0.0
	return 0.0


func _spot_x(i: int) -> float:
	return size.x * (0.16 + 0.68 * i / float(SPOTS - 1))


func _draw() -> void:
	var s := size
	if s.x < 1.0:
		return
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var shore := s.y * 0.5
	var sand_y := s.y * 0.7
	# 貝がら（波が引いているあいだだけ見える）
	if phase == Phase.OUT:
		for i in shells.size():
			if shells[i] < 0:
				continue
			var tex: Texture2D = _art[i]
			var k: float = SHELL_SIZE[shells[i]] / maxf(tex.get_width(), tex.get_height())
			var sz := tex.get_size() * k
			draw_texture_rect(tex, Rect2(Vector2(_spot_x(i), sand_y) - sz / 2.0, sz), false)
	# 寄せてくる波（白いふちのある、うすい水）
	var front := shore + (s.y - shore) * 0.6 * _wave()
	if front > shore + 6.0:
		var c := clock()
		var pts := PackedVector2Array([Vector2(0, shore)])
		for i in 17:
			var t := i / 16.0
			pts.append(Vector2(s.x * t, maxf(front + sin(t * TAU * 2.0 + c) * 8.0, shore + 1.0)))
		pts.append(Vector2(s.x, shore))
		draw_colored_polygon(pts, Color(P.SEA_NEAR, 0.6))
		draw_polyline(pts.slice(1, pts.size() - 1), Color(P.CLOUD, 0.9), 5.0)
	# ぼく（波が来ると、手前に下がる）と、すこし離れて貝をさがすなつみ
	var back := _wave() * s.y * 0.12
	var kid_h := s.y * 0.26
	draw_sprite(NATSUMI_TEX, Vector2(s.x * 0.06, s.y * 0.97), kid_h * 0.85)
	draw_sprite(PLAYER_TEX, Vector2(_spot_x(spot), sand_y + kid_h * 0.55 + back), kid_h)
	# 足もとの印（拾える場所）
	if phase == Phase.OUT:
		draw_arc(Vector2(_spot_x(spot), sand_y), 30, 0, TAU, 20, UiTokens.ACCENT_INK, 3.0)
	# のこりの時間（右上のうすい線）
	var left := clampf(1.0 - _clock / TIME_LIMIT, 0.0, 1.0)
	draw_rect(Rect2(s.x - UiTokens.SCREEN_MARGIN - 160.0, UiTokens.SCREEN_MARGIN + 70.0, 160.0 * left, 6.0), Color(UiTokens.INK, 0.5))
