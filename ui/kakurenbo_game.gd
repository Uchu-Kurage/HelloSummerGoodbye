class_name KakurenboGame
extends MinigameBase
## ミニゲーム「かくれんぼ」。会話の @game kakurenbo（4日目、神隠しルート。夕立の境内でお面の子）と、
## @game kakurenbo_jiji（8日目、ノーマルルート。夕方の境内でおじいちゃん）で始まる。仕組みは同じで、手がかりと相手だけがちがう。
## 境内の隠れ場所6つ（灯籠・大木・狛犬・賽銭箱・鳥居の影・手水舎）を、左右で選んで決定で調べる（タッチは場所をタップ）。
## 相手のいる場所の近くを選ぶと、手がかりが出る：
## - お面の子：かすかに鈴の音がする（音が出なくても分かるよう、画面にも「ちりん」の印を出す）
## - おじいちゃん：麦わら帽子の端が見える
## どちらも狛犬のうしろ（HIDING）。GOOD_TRIES 回以内に見つけたら「よくできた」。
## MAX_MISSES 回はずすと、相手が自分から出てくる（ふつう）。

enum Phase { COUNT, SEEK, LOOK, FOUND, COME_OUT }

## 「よくできた」になる、調べた回数（見つけた回も入れて。仮の値）
const GOOD_TRIES := 3
## この回数はずすと、相手が自分から出てくる
const MAX_MISSES := 5
## 隠れている場所（SPOT_NAMES の番号。こまいぬ）と、手がかりが出る近さ（となりまで）
const HIDING := 2
const NEAR := 1
## 10かぞえる時間、調べに行く時間、見つけてから／出てきてから終わるまでの時間
const COUNT_TIME := 3.0
const LOOK_TIME := 1.4
const FOUND_TIME := 2.4
const COME_OUT_TIME := 1.2
const COME_OUT_END := 2.6
const P := preload("res://world/world_palette.gd")
const K := preload("res://world/kamikakushi_prop.gd")
const FOX_TEX: Texture2D = preload("res://world/scenery/painted/npc_fox_child.png")
const FOX_STAND: Texture2D = preload("res://world/scenery/painted/fox_mg1_4.png")
## 柱のうしろからのぞくおじいちゃん（絵の中の、顔と肩のところだけを使う）と、出てきて立ったおじいちゃん
const JIJI_TEX: Texture2D = preload("res://world/scenery/painted/grandpa_mg1_1.png")
const JIJI_PEEK := Rect2(92, 24, 104, 150)
const JIJI_STAND: Texture2D = preload("res://world/scenery/painted/npc_grandpa.png")
## 夕方の境内の絵（空は透明なので、うしろに夕焼けを描く）
const JIJI_BG: Texture2D = preload("res://ui/minigame_bg/kakurenbo_jiji.png")
const JIJI_BG_FOCUS := Vector2(0.5, 0.45)
## 背景の絵（夕立の境内）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/kakurenbo.jpg")
const BG_FOCUS := Vector2(0.5, 0.4)
const STREAKS := 50
const HAT := Color("#D9B865")
const HAT_BAND := Color("#5A4632")
const TORII := Color("#B5523B")
const TRUNK := Color("#6B5440")
const ROPE := Color("#D9C79A")

var phase := Phase.COUNT
var hiding := HIDING
## おじいちゃんとのかくれんぼ（ノーマルルート。雨なし、夕方の境内）
var jiji := false
var cursor := 0
var tries := 0
var misses := 0
var _checked: Array[bool] = []
var _t := 0.0
var _clue_t := 0.0


func _setup() -> void:
	jiji = game_name == "kakurenbo_jiji"
	intro_text = Strings.KAKURENBO_JIJI_INTRO if jiji else Strings.KAKURENBO_INTRO
	arrows = true
	if not jiji:
		set_ambient(WorldPalette.RAIN_AMBIENT)


func _begin() -> void:
	phase = Phase.COUNT
	cursor = 0
	tries = 0
	misses = 0
	_t = 0.0
	_checked.clear()
	for i in Strings.KAKURENBO_SPOTS.size():
		_checked.append(false)
	caption(Strings.KAKURENBO_COUNT)


## いま選んでいる場所が、相手の近くか（手がかりが出る）
func near() -> bool:
	return phase == Phase.SEEK and absi(cursor - hiding) <= NEAR


func _process_game(delta: float) -> void:
	_t += delta
	_clue_t += delta
	match phase:
		Phase.COUNT:
			if _t >= COUNT_TIME:
				phase = Phase.SEEK
				caption(Strings.KAKURENBO_JIJI_READY if jiji else Strings.KAKURENBO_READY)
				show_hint(Strings.KAKURENBO_HINT_TOUCH, Strings.KAKURENBO_HINT_KEY)
				_on_cursor()
		Phase.LOOK:
			if _t >= LOOK_TIME:
				_reveal()
		Phase.FOUND:
			if _t >= FOUND_TIME:
				end_game(tries <= GOOD_TRIES, tries)
		Phase.COME_OUT:
			if _t >= COME_OUT_END:
				end_game(false, tries)


func _left() -> void:
	if phase == Phase.SEEK and cursor > 0:
		cursor -= 1
		_on_cursor()


func _right() -> void:
	if phase == Phase.SEEK and cursor < _checked.size() - 1:
		cursor += 1
		_on_cursor()


## 選ぶ場所が変わった：相手の近くなら、手がかり（お面の子は鈴の音）
func _on_cursor() -> void:
	SfxPlayer.play("cursor")
	if near() and not jiji:
		SfxPlayer.play("suzu_far")
		_clue_t = 0.0


func _accept(pos: Variant = null) -> void:
	if phase in [Phase.FOUND, Phase.COME_OUT, Phase.LOOK]:
		speed = UiTokens.SKIP_SPEED
		return
	if phase != Phase.SEEK:
		return
	# タッチは、場所をタップすると、そこを調べる
	if pos is Vector2:
		var hit := _spot_at(pos)
		if hit < 0:
			return
		cursor = hit
	check_spot(cursor)


## そこを調べる（自動の動作確認からも呼べる）
func check_spot(i: int) -> void:
	if phase != Phase.SEEK or i < 0 or i >= _checked.size() or _checked[i]:
		return
	cursor = i
	tries += 1
	_checked[i] = true
	phase = Phase.LOOK
	_t = 0.0
	hide_hint()
	caption(Strings.KAKURENBO_LOOK % Strings.KAKURENBO_SPOTS[i])


func _reveal() -> void:
	_t = 0.0
	speed = 1.0
	if cursor == hiding:
		phase = Phase.FOUND
		SfxPlayer.play("accept" if jiji else "suzu")
		caption(Strings.KAKURENBO_FOUND)
		return
	misses += 1
	SfxPlayer.play("cancel")
	if misses >= MAX_MISSES:
		_come_out()
		return
	phase = Phase.SEEK
	caption(Strings.KAKURENBO_MISS)
	show_hint(Strings.KAKURENBO_HINT_TOUCH, Strings.KAKURENBO_HINT_KEY)


## 見つけられなかった：相手が、狛犬のうしろから自分で出てくる
func _come_out() -> void:
	phase = Phase.COME_OUT
	caption(Strings.KAKURENBO_JIJI_CAME_OUT if jiji else Strings.KAKURENBO_CAME_OUT)


## 出てくる進みぐあい（0 狛犬のうしろ〜1 となりに立つ）。動きを減らす設定では、すぐ出てくる
func come_out_k() -> float:
	if phase != Phase.COME_OUT:
		return 0.0
	return 1.0 if UiAnim.reduced() else clampf(_t / COME_OUT_TIME, 0.0, 1.0)


func bot(good: bool) -> Dictionary:
	if phase != Phase.SEEK:
		return {}
	# よくできた：手がかりのほうへ（狛犬）。ふつう：狛犬いがいを はしから調べる
	var want := hiding
	if not good:
		want = -1
		for i in _checked.size():
			if not _checked[i] and i != hiding:
				want = i
				break
		if want < 0:
			want = hiding
	if want < cursor:
		return {"key": KEY_LEFT, "tap": _spot_tap(want)}
	if want > cursor:
		return {"key": KEY_RIGHT, "tap": _spot_tap(want)}
	return {"key": KEY_SPACE, "tap": _spot_tap(want)}


# --- 絵 -----------------------------------------------------------------------

func _spot_foot(i: int) -> Vector2:
	var n := _checked.size() if _checked.size() > 0 else 6
	return Vector2(size.x * (0.1 + 0.8 * i / float(n - 1)), size.y * 0.8)


func _spot_tap(i: int) -> Vector2:
	return global_position + _spot_foot(i) + Vector2(0, -50)


func _spot_at(pos: Vector2) -> int:
	var local: Vector2 = pos - global_position
	var best := -1
	var best_d := size.x * 0.08
	for i in _checked.size():
		var f := _spot_foot(i)
		if local.y < f.y - size.y * 0.4 or local.y > f.y + 60.0:
			continue
		var d := absf(local.x - f.x)
		if d < best_d:
			best_d = d
			best = i
	return best


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	if jiji:
		var top := P.KAKURENBO_EVENING_TOP
		var low := P.KAKURENBO_EVENING_LOW
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), PackedColorArray([top, top, low, low]))
		MinigameBg.draw_cover(self, JIJI_BG, Rect2(Vector2.ZERO, s), JIJI_BG_FOCUS)
	else:
		MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	# 10かぞえているあいだは、目をつぶっている（暗く）
	if phase == Phase.COUNT:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
		return
	var h := s.y * 0.26
	for i in _checked.size():
		var foot := _spot_foot(i)
		if i == hiding:
			_draw_partner(foot, h)
		_draw_prop(i, foot, h)
		if _checked[i] and i != hiding:
			draw_rect(Rect2(foot + Vector2(-h * 0.45, -h * 1.1), Vector2(h * 0.9, h * 1.15)), Color(UiTokens.INK_SOFT, 0.25))
	# 選んでいる場所の印と、名前
	if phase in [Phase.SEEK, Phase.LOOK]:
		var f := _spot_foot(cursor)
		draw_arc(f + Vector2(0, 6), h * 0.42, 0.15 * PI, 0.85 * PI, 18, UiTokens.ACCENT_INK, 4.0)
		var font := get_theme_default_font()
		var name_s: String = Strings.KAKURENBO_SPOTS[cursor]
		var tw := font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_SMALL).x
		var chip := Rect2(f + Vector2(-tw / 2.0 - 10, 18), Vector2(tw + 20, 34))
		draw_rect(chip, UiTokens.PAPER)
		draw_string(font, chip.position + Vector2(10, 25), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_SMALL, UiTokens.INK)
	# 手がかり（お面の子）：鈴の音の印。選んでいる場所のうえに、ゆれる「ちりん」（音が出なくても分かるように）
	if near() and not jiji:
		var f := _spot_foot(cursor) + Vector2(0, -h * 1.35)
		var k := 1.0 if UiAnim.reduced() else 0.6 + 0.4 * sin(_clue_t * 6.0)
		var a := 0.9 if cursor == hiding else 0.5
		var font := get_theme_default_font()
		draw_string(font, f + Vector2(-30, 0), Strings.KAKURENBO_BELL_MARK, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_SMALL, Color(1, 1, 1, a * k))
	if not jiji:
		var c := clock()
		for i in STREAKS:
			var fx := fposmod(i * 0.6180339, 1.0)
			var fy := fposmod(i * 0.4142135 + c * 1.3, 1.0)
			var p := Vector2(fx * s.x, fy * s.y)
			draw_line(p, p + Vector2(-5, 22), Color(P.RAIN_STREAK, 0.35), 2.0)


## 相手：見つけたら、狛犬のうしろからのぞく。出てくるときは、横へ出て立つ。
## おじいちゃんの近くを選んでいるあいだは、麦わら帽子の端が見える
func _draw_partner(foot: Vector2, h: float) -> void:
	if phase == Phase.FOUND or (phase == Phase.LOOK and cursor == hiding and _t > LOOK_TIME * 0.6):
		if jiji:
			var ph := h * 0.8
			var pw := JIJI_PEEK.size.x * ph / JIJI_PEEK.size.y
			draw_texture_rect_region(JIJI_TEX, Rect2(foot.x + h * 0.05, foot.y - h * 1.25, pw, ph), JIJI_PEEK)
		else:
			var fh := h * 1.3
			var fw := FOX_TEX.get_width() * fh / FOX_TEX.get_height()
			draw_texture_rect_region(FOX_TEX, Rect2(foot.x + h * 0.05, foot.y - fh + 4, fw, fh * 0.5), Rect2(0, 0, FOX_TEX.get_width(), FOX_TEX.get_height() * 0.5))
		return
	var k := come_out_k()
	if k > 0.0:
		var tex := JIJI_STAND if jiji else FOX_STAND
		draw_sprite(tex, foot + Vector2(lerpf(0.0, h * 0.75, k), 4), h * (1.9 if jiji else 1.5), false, k)
		return
	if jiji and near():
		# 麦わら帽子の端（狛犬のうしろから、少しだけ）
		var c := foot + Vector2(h * 0.38, -h * 0.82)
		draw_set_transform(c, -0.25, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, h * 0.22, HAT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(c + Vector2(-h * 0.08, -h * 0.02), c + Vector2(h * 0.12, -h * 0.07), HAT_BAND, 3.0)


func _draw_prop(i: int, foot: Vector2, h: float) -> void:
	match i:
		0: K.draw_stone_lantern(self, foot, h * 1.05)
		1:
			# 大木（しめ縄を巻いた太い幹。絵の素材は背景が透けないので、図形で描く）
			var w := h * 0.42
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-w * 0.7, 0), foot + Vector2(-w * 0.45, -h * 1.5), foot + Vector2(w * 0.45, -h * 1.5), foot + Vector2(w * 0.7, 0)]), TRUNK)
			draw_line(foot + Vector2(-w * 0.15, -h * 0.1), foot + Vector2(-w * 0.1, -h * 1.4), TRUNK.darkened(0.25), 3.0)
			draw_line(foot + Vector2(w * 0.25, -h * 0.2), foot + Vector2(w * 0.2, -h * 1.3), TRUNK.darkened(0.25), 3.0)
			draw_rect(Rect2(foot + Vector2(-w * 0.6, -h * 0.85), Vector2(w * 1.2, h * 0.09)), ROPE)
			for k in 3:
				draw_rect(Rect2(foot + Vector2(-w * 0.35 + k * w * 0.3, -h * 0.76), Vector2(w * 0.08, h * 0.16)), Color.WHITE)
		2: K.draw_komainu(self, foot, h * 0.85)
		3: K.draw_saisen(self, foot, h * 0.8)
		4:
			# 鳥居の影（太い柱が1本と、地面にのびる影。鳥居そのものは背景の絵にある）
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-h * 0.05, 0), foot + Vector2(h * 0.12, 0), foot + Vector2(h * 0.75, h * 0.12), foot + Vector2(h * 0.5, h * 0.12)]), Color(0, 0, 0, 0.3))
			draw_rect(Rect2(foot + Vector2(-h * 0.06, -h * 1.3), Vector2(h * 0.17, h * 1.3)), TORII)
			draw_rect(Rect2(foot + Vector2(-h * 0.1, -h * 0.12), Vector2(h * 0.25, h * 0.12)), TORII.darkened(0.35))
		5:
			# 手水舎（屋根と柱と水盤）
			var w := h * 0.9
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-w * 0.6, -h * 0.85), foot + Vector2(0, -h * 1.15), foot + Vector2(w * 0.6, -h * 0.85)]), P.ROCK_DARK)
			draw_rect(Rect2(foot + Vector2(-w * 0.45, -h * 0.85), Vector2(h * 0.07, h * 0.85)), HAT_BAND)
			draw_rect(Rect2(foot + Vector2(w * 0.38, -h * 0.85), Vector2(h * 0.07, h * 0.85)), HAT_BAND)
			draw_rect(Rect2(foot + Vector2(-w * 0.35, -h * 0.3), Vector2(w * 0.7, h * 0.3)), Color("#9C9890"))
			draw_rect(Rect2(foot + Vector2(-w * 0.3, -h * 0.3), Vector2(w * 0.6, h * 0.06)), P.WATER_LIGHT)
