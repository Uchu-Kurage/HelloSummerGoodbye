class_name SeizaGame
extends NatsumiScreen
## ミニゲーム「星座さがし」（9日目、ノーマルルート）。会話の @game seiza で始まる。
## 縁側から見上げた夜空。あかるい星のうち、夏の大三角（ベガ・アルタイル・デネブ）の3つをタップして線でつなぐ。
## ちがう星を選ぶと、おじいちゃんが「ちがうな」。MISS_HINT 回はずすと、大三角の星がゆっくり光る。
## 3つつなぐと三角が閉じて、星の名前が出る。失敗で止まらない。はずしが GOOD_MISSES 回以下なら、よくできた（grade。HUD がフラグ seiza_good／ちがえば seiza_miss を立てる）。

enum Phase { FIND, DONE }

const MISS_HINT := 2
## ちがう星を選んだのがこれ以下なら「よくできた」（仮の値）
const GOOD_MISSES := 0
const END_TIME := 2.6
## 押せる範囲（星の絵は小さいが、押せるのは 88px 四方）
const STAR_BOX := 88.0
const P := preload("res://world/world_palette.gd")
## 背景の絵（縁側から見上げた夜空。軒・柱・縁側の板と、天の川・小さな星まで描いてある。まわりは透明）
const BG: Texture2D = preload("res://ui/minigame_bg/seiza.png")
const BG_FOCUS := Vector2(0.5, 0.5)
## あかるい星：[空の中の位置（幅・高さに対する割合）, 大きさ, 大三角か, 色]
const STARS := [
	[Vector2(0.40, 0.20), 7.0, true, Color(0.85, 0.92, 1.0)],   # ベガ
	[Vector2(0.56, 0.66), 6.5, true, Color(1.0, 0.98, 0.9)],    # アルタイル
	[Vector2(0.66, 0.16), 6.0, true, Color(0.95, 0.96, 1.0)],   # デネブ
	[Vector2(0.14, 0.50), 5.5, false, Color(1.0, 0.85, 0.6)],   # アークトゥルス
	[Vector2(0.26, 0.78), 5.5, false, Color(1.0, 0.6, 0.45)],   # アンタレス
	[Vector2(0.86, 0.48), 4.5, false, Color(0.95, 0.95, 1.0)],
]
## 大三角の星の番号（STARS の中）と、Strings.SEIZA_NAMES の順
const TRIANGLE := [0, 1, 2]

var phase := Phase.FIND
## つないだ星の番号（つないだ順）
var linked: Array[int] = []
var misses := 0
var _checked: Array[bool] = []
var _t := 0.0
var _hint_t := -1.0
var _layer: Control
var _buttons: Array[Button] = []


func _build() -> void:
	set_ambient(WorldPalette.CAPSULE_AMBIENT)
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	for i in STARS.size():
		_checked.append(false)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(STAR_BOX, STAR_BOX)
		b.size = Vector2(STAR_BOX, STAR_BOX)
		# 星の上には、ボタンの地や枠を出さない（選んでいる印は _draw で描く）
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(_on_star.bind(i))
		b.focus_entered.connect(func():
			if InputMode.keyboard:
				SfxPlayer.play("cursor")
			queue_redraw())
		UiAnim.add_press_feedback(b)
		_layer.add_child(b)
		_buttons.append(b)
	_link_focus()
	say(Strings.SEIZA_START)
	show_hint(Strings.SEIZA_HINT_TOUCH, Strings.SEIZA_HINT_KEY)
	if InputMode.keyboard:
		_buttons[0].grab_focus.call_deferred()


## 矢印キー：左右は横の並び、上下は縦の並びで、となりの星へ（はしは反対側へ回る）
func _link_focus() -> void:
	var by_x := range(STARS.size())
	by_x.sort_custom(func(a, b): return STARS[a][0].x < STARS[b][0].x)
	var by_y := range(STARS.size())
	by_y.sort_custom(func(a, b): return STARS[a][0].y < STARS[b][0].y)
	var n := STARS.size()
	for k in n:
		var b := _buttons[by_x[k]]
		b.focus_neighbor_left = b.get_path_to(_buttons[by_x[(k + n - 1) % n]])
		b.focus_neighbor_right = b.get_path_to(_buttons[by_x[(k + 1) % n]])
		var c := _buttons[by_y[k]]
		c.focus_neighbor_top = c.get_path_to(_buttons[by_y[(k + n - 1) % n]])
		c.focus_neighbor_bottom = c.get_path_to(_buttons[by_y[(k + 1) % n]])


func _on_star(i: int) -> void:
	pick(i)


## 星を選ぶ（自動の動作確認からも呼べる）
func pick(i: int) -> void:
	if phase != Phase.FIND or i < 0 or i >= STARS.size() or linked.has(i) or _checked[i]:
		return
	if STARS[i][2]:
		linked.append(i)
		SfxPlayer.play("accept")
		if linked.size() >= TRIANGLE.size():
			phase = Phase.DONE
			_t = 0.0
			hide_hint()
			say(Strings.SEIZA_DONE)
			grade = GameState.Grade.GOOD if misses <= GOOD_MISSES else GameState.Grade.NORMAL
			for b in _buttons:
				b.disabled = true
		else:
			say(Strings.SEIZA_RIGHT[linked.size() - 1])
	else:
		_checked[i] = true
		_buttons[i].disabled = true
		misses += 1
		SfxPlayer.play("cursor")
		say(Strings.SEIZA_WRONG)
		if misses >= MISS_HINT and _hint_t < 0.0:
			_hint_t = 0.0
			caption(Strings.SEIZA_HINT_GLOW)
		if InputMode.keyboard:
			for k in STARS.size():
				if not _buttons[k].disabled and not linked.has(k):
					_buttons[k].grab_focus()
					break
	queue_redraw()


## 大三角の星の番号（自動の動作確認から使う）
static func triangle() -> Array:
	return TRIANGLE


func _process(delta: float) -> void:
	_t += delta * speed
	if _hint_t >= 0.0:
		_hint_t += delta
	if phase == Phase.DONE and _t >= END_TIME and not done:
		finish()
	_place_buttons()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if phase == Phase.DONE and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


## 星の空（上の小札の下から、軒の上まで）
func _sky_rect() -> Rect2:
	var s := size
	return Rect2(s.x * 0.08, s.y * 0.2, s.x * 0.84, s.y * 0.5)


func _star_pos(i: int) -> Vector2:
	var r := _sky_rect()
	return r.position + r.size * (STARS[i][0] as Vector2)


func _place_buttons() -> void:
	for i in _buttons.size():
		_buttons[i].position = _star_pos(i) - Vector2(STAR_BOX, STAR_BOX) / 2.0


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	# 縁側から見上げた夜空の絵（あかるい星は、選べるように上に描く）
	draw_rect(Rect2(Vector2.ZERO, s), P.SEIZA_EAVES)
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	# つないだ線（3つそろったら三角を閉じる）
	for k in range(1, linked.size()):
		draw_line(_star_pos(linked[k - 1]), _star_pos(linked[k]), P.SEIZA_LINE, 3.0)
	if phase == Phase.DONE:
		draw_line(_star_pos(linked[-1]), _star_pos(linked[0]), P.SEIZA_LINE, 3.0)
	var font := get_theme_default_font()
	for i in STARS.size():
		var p := _star_pos(i)
		var r: float = STARS[i][1]
		var col: Color = STARS[i][3]
		if _checked[i]:
			col = Color(col, 0.35)
		if _hint_t >= 0.0 and STARS[i][2] and not linked.has(i) and phase == Phase.FIND:
			var k := 1.0 if UiAnim.reduced() else 0.5 + 0.5 * sin(_hint_t * 3.0)
			draw_circle(p, r * 4.0, Color(1.0, 0.95, 0.7, 0.12 + 0.12 * k))
		draw_circle(p, r * 2.4, Color(col, col.a * 0.18))
		draw_circle(p, r, col)
		if linked.has(i):
			draw_arc(p, r * 2.6, 0, TAU, 24, P.SEIZA_LINE, 2.0)
		# キーボードで選んでいる星：紙の色の輪と「●」（夜空の上なので、紙の色で見えるようにする）
		if _buttons[i].has_focus() and InputMode.keyboard and phase == Phase.FIND:
			draw_arc(p, STAR_BOX * 0.42, 0, TAU, 32, UiTokens.PAPER, 3.0)
			draw_string(font, p + Vector2(-STAR_BOX * 0.42 - 4, -STAR_BOX * 0.3), Strings.SELECT_MARK, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_SMALL, UiTokens.PAPER)
	if phase == Phase.DONE:
		for k in TRIANGLE.size():
			var p := _star_pos(TRIANGLE[k]) + Vector2(16, -14)
			draw_string(font, p, Strings.SEIZA_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_SMALL, UiTokens.PAPER)
