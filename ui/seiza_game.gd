class_name SeizaGame
extends MinigameBase
## ミニゲーム「星座さがし」（9日目、ノーマルルート）。会話の @game seiza で始まる。
## 縁側から見上げた夜空。おじいちゃんが星座の名前を言う（はくちょう座・こと座・わし座の順）。
## 星座の形がうすく見え、はじめの星には印がつく。星を左右で選び、決定で順につなぐ（タッチは星をタップ）。
## 最後に3つの一等星（ベガ・アルタイル・デネブ）をつなぐと、夏の大三角になる。
## ちがう星を選ぶと「ちがう ほし」（つなぎなおせる）。1回もまちがえずに夏の大三角まで行けたら「よくできた」
## （HUD がフラグ seiza_good／ちがえば seiza_miss を立てる）。

enum Phase { CALL, LINK, SHOW, DONE }

## 「よくできた」になる、まちがいの数（仮の値）
const GOOD_MISSES := 0
## 星：[空の中の位置（幅・高さに対する割合）, 大きさ, 色]
const STARS := [
	[Vector2(0.70, 0.14), 7.0, Color(0.95, 0.96, 1.0)],   # 0 デネブ
	[Vector2(0.63, 0.30), 4.5, Color(1.0, 0.97, 0.9)],    # 1 サドル
	[Vector2(0.52, 0.52), 4.5, Color(1.0, 0.9, 0.7)],     # 2 アルビレオ
	[Vector2(0.36, 0.20), 7.5, Color(0.85, 0.92, 1.0)],   # 3 ベガ
	[Vector2(0.30, 0.30), 4.0, Color(0.95, 0.95, 1.0)],   # 4 こと座の星
	[Vector2(0.33, 0.42), 4.0, Color(0.95, 0.95, 1.0)],   # 5 こと座の星
	[Vector2(0.25, 0.44), 4.0, Color(0.95, 0.95, 1.0)],   # 6 こと座の星
	[Vector2(0.55, 0.66), 4.5, Color(1.0, 0.85, 0.6)],    # 7 タラゼド
	[Vector2(0.60, 0.76), 7.0, Color(1.0, 0.98, 0.9)],    # 8 アルタイル
	[Vector2(0.66, 0.88), 4.0, Color(0.95, 0.95, 1.0)],   # 9 アルシャイン
	[Vector2(0.10, 0.50), 5.5, Color(1.0, 0.85, 0.6)],    # 10 アークトゥルス
	[Vector2(0.17, 0.84), 5.5, Color(1.0, 0.6, 0.45)],    # 11 アンタレス
	[Vector2(0.88, 0.48), 4.5, Color(0.95, 0.95, 1.0)],   # 12
]
## つなぐ順（STARS の番号）。はくちょう座・こと座・わし座、最後に夏の大三角（Strings.SEIZA_CALLS の順）
const FIGURES := [[0, 1, 2], [3, 4, 5, 6], [7, 8, 9], [3, 8, 0]]
## 夏の大三角の星（名前を出す）と、Strings.SEIZA_NAMES の順
const TRIANGLE := [3, 8, 0]
const CALL_TIME := 1.8
const SHOW_TIME := 1.6
const DONE_TIME := 2.8
## 押せる範囲（星の絵は小さいが、押せるのは 88px 四方）
const STAR_BOX := 88.0
const P := preload("res://world/world_palette.gd")
## 背景の絵（縁側から見上げた夜空。まわりは透明）
const BG: Texture2D = preload("res://ui/minigame_bg/seiza.png")
const BG_FOCUS := Vector2(0.5, 0.5)

var phase := Phase.CALL
## いまの星座（FIGURES の番号）と、その中で次につなぐ星の番号
var figure := 0
var step := 1
var cursor := 0
var misses := 0
## つないだ線（[星, 星] の組）
var lines: Array = []
var _t := 0.0
var _wrong_t := -1.0
var _wrong := -1


func _setup() -> void:
	intro_text = Strings.SEIZA_INTRO
	arrows = true
	set_ambient(WorldPalette.CAPSULE_AMBIENT)


func _begin() -> void:
	figure = 0
	misses = 0
	lines.clear()
	_call()


func _call() -> void:
	phase = Phase.CALL
	step = 1
	_t = 0.0
	cursor = FIGURES[figure][0]
	var line: String = Strings.SEIZA_CALLS[figure]
	if line.begins_with("（"):
		caption(line)
	else:
		say(line)
	hide_hint()


## 次につなぐ星（自動の動作確認から使う）
func next_star() -> int:
	return FIGURES[figure][step] if phase == Phase.LINK else -1


func _process_game(delta: float) -> void:
	_t += delta
	if _wrong_t >= 0.0:
		_wrong_t += delta
	match phase:
		Phase.CALL:
			if _t >= CALL_TIME:
				phase = Phase.LINK
				show_hint(Strings.SEIZA_HINT_TOUCH, Strings.SEIZA_HINT_KEY)
		Phase.SHOW:
			if _t >= SHOW_TIME:
				figure += 1
				_call()
		Phase.DONE:
			if _t >= DONE_TIME:
				end_game(misses <= GOOD_MISSES, misses)


## 左右：横に並んだ順で、となりの星へ（はしは反対側へ回る）
func _move(d: int) -> void:
	if phase != Phase.LINK:
		return
	var by_x := range(STARS.size())
	by_x.sort_custom(func(a, b): return STARS[a][0].x < STARS[b][0].x)
	var k := by_x.find(cursor)
	cursor = by_x[(k + d + by_x.size()) % by_x.size()]
	SfxPlayer.play("cursor")


func _left() -> void:
	_move(-1)


func _right() -> void:
	_move(1)


func _accept(pos: Variant = null) -> void:
	if phase != Phase.LINK:
		speed = UiTokens.SKIP_SPEED
		return
	if pos is Vector2:
		var hit := _star_at(pos)
		if hit < 0:
			return
		cursor = hit
	pick(cursor)


## 星を選ぶ（自動の動作確認からも呼べる）
func pick(i: int) -> void:
	if phase != Phase.LINK:
		return
	var fig: Array = FIGURES[figure]
	if i != fig[step]:
		misses += 1
		_wrong = i
		_wrong_t = 0.0
		SfxPlayer.play("cancel")
		caption(Strings.SEIZA_WRONG)
		return
	lines.append([fig[step - 1], i])
	SfxPlayer.play("accept")
	hush()
	step += 1
	if step < fig.size():
		return
	speed = 1.0
	if figure == FIGURES.size() - 1:
		# 夏の大三角：三角を閉じて、星の名前を出す
		lines.append([fig[-1], fig[0]])
		phase = Phase.DONE
		_t = 0.0
		hide_hint()
		caption(Strings.SEIZA_DONE)
	else:
		phase = Phase.SHOW
		_t = 0.0
		hide_hint()


func bot(good: bool) -> Dictionary:
	if phase != Phase.LINK:
		return {}
	# ふつう：はじめに1回だけ、ちがう星を選ぶ
	var want := next_star() if good or misses > 0 else 12
	if want == cursor:
		return {"key": KEY_SPACE, "tap": global_position + _star_pos(want)}
	var by_x := range(STARS.size())
	by_x.sort_custom(func(a, b): return STARS[a][0].x < STARS[b][0].x)
	var right := by_x.find(want) > by_x.find(cursor)
	return {"key": KEY_RIGHT if right else KEY_LEFT, "tap": global_position + _star_pos(want), "tap_only": true}


# --- 絵 -----------------------------------------------------------------------

## 星の空（上の小札の下から、軒の上まで）
func _sky_rect() -> Rect2:
	var s := size
	return Rect2(s.x * 0.1, s.y * 0.16, s.x * 0.8, s.y * 0.58)


func _star_pos(i: int) -> Vector2:
	var r := _sky_rect()
	return r.position + r.size * (STARS[i][0] as Vector2)


func _star_at(pos: Vector2) -> int:
	var local: Vector2 = pos - global_position
	var best := -1
	var best_d := STAR_BOX * 0.5
	for i in STARS.size():
		var d := _star_pos(i).distance_to(local)
		if d < best_d:
			best_d = d
			best = i
	return best


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, s), P.SEIZA_EAVES)
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	# いまの星座の形（うすい点線）
	if phase in [Phase.CALL, Phase.LINK] and state == State.PLAY:
		var fig: Array = FIGURES[figure]
		for k in range(1, fig.size()):
			draw_dashed_line(_star_pos(fig[k - 1]), _star_pos(fig[k]), Color(1, 1, 1, 0.22), 2.0, 8.0)
		if figure == FIGURES.size() - 1:
			draw_dashed_line(_star_pos(fig[-1]), _star_pos(fig[0]), Color(1, 1, 1, 0.22), 2.0, 8.0)
	# つないだ線
	for l in lines:
		draw_line(_star_pos(l[0]), _star_pos(l[1]), P.SEIZA_LINE, 3.0)
	var font := get_theme_default_font()
	for i in STARS.size():
		var p := _star_pos(i)
		var r: float = STARS[i][1]
		var col: Color = STARS[i][2]
		draw_circle(p, r * 2.4, Color(col, col.a * 0.18))
		draw_circle(p, r, col)
		# ちがう星を選んだ：少しのあいだ、暗い輪
		if i == _wrong and _wrong_t >= 0.0 and _wrong_t < 1.0:
			draw_arc(p, r * 3.0, 0, TAU, 20, Color(UiTokens.ACCENT, 1.0 - _wrong_t), 2.0)
	if phase == Phase.LINK:
		# いまつないでいるところの星（はじめの星・ひとつ前の星）に印
		var from: int = FIGURES[figure][step - 1]
		draw_arc(_star_pos(from), STARS[from][1] * 3.2, 0, TAU, 24, P.SEIZA_LINE, 2.0)
		# 選んでいる星：紙の色の輪
		var cp := _star_pos(cursor)
		draw_arc(cp, STAR_BOX * 0.4, 0, TAU, 32, UiTokens.PAPER, 3.0)
	if phase == Phase.DONE:
		for k in TRIANGLE.size():
			draw_string(font, _star_pos(TRIANGLE[k]) + Vector2(16, -14), Strings.SEIZA_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_SMALL, UiTokens.PAPER)
