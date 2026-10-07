class_name SentakuGame
extends NatsumiScreen
## ミニゲーム「洗濯物の取り込み」（4日目、ノーマルルート）。会話の @game sentaku で始まる。
## 祖父母の家の庭。物干しの洗濯物を、夕立が来る前に1つずつタップして取り込む。
## 左から夕立の雲が近づいてきて、RAIN_TIME 秒で降りだす。降りだしたら、残りは少しぬれて、おばあちゃんが取り込んでくれる。
## 失敗で止まらない。全部取り込めたら、フラグ sentaku_good（ちがえば sentaku_miss）。

enum Phase { PICK, RAIN, END }

## 降りだすまでの時間（秒）
const RAIN_TIME := 10.0
## 降りだしてから（全部取り込んでから）おわるまで
const END_TIME := 1.8
const CHOICE_SIZE := Vector2(120, 132)
const P := preload("res://world/world_palette.gd")
## 背景の絵（夏の昼の庭。空は透明なので、うしろに空と夕立の雲を描く）と、残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/sentaku.png")
const BG_FOCUS := Vector2(0.4, 0.6)
## 洗濯物の絵（Strings.SENTAKU_CLOTHES の順）
const CLOTHES: Array[Texture2D] = [
	preload("res://world/scenery/painted/sentaku_cloth_1.png"),
	preload("res://world/scenery/painted/sentaku_cloth_2.png"),
	preload("res://world/scenery/painted/sentaku_cloth_3.png"),
	preload("res://world/scenery/painted/sentaku_cloth_4.png"),
	preload("res://world/scenery/painted/sentaku_cloth_5.png"),
	preload("res://world/scenery/painted/sentaku_cloth_6.png"),
]
const STREAKS := 60

var phase := Phase.PICK
var taken: Array[bool] = []
var wet: Array[bool] = []
var _t := 0.0
var _end_t := 0.0
var _row: HBoxContainer
var _buttons: Array[Button] = []


func _build() -> void:
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_row)
	for i in Strings.SENTAKU_CLOTHES.size():
		taken.append(false)
		wet.append(false)
		var b := make_choice(i, CHOICE_SIZE, _draw_cloth, _on_choice)
		var l := Label.new()
		l.text = Strings.SENTAKU_CLOTHES[i]
		l.theme_type_variation = &"SmallLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -30
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		_row.add_child(b)
		_buttons.append(b)
	link_row(_buttons)
	say(Strings.SENTAKU_START)
	show_hint(Strings.SENTAKU_HINT_TOUCH, Strings.SENTAKU_HINT_KEY)
	if InputMode.keyboard:
		_buttons[0].grab_focus.call_deferred()


func _on_choice(i: int) -> void:
	take(i)


## 洗濯物を1つ取り込む（自動の動作確認からも呼べる）
func take(i: int) -> void:
	if phase != Phase.PICK or i < 0 or i >= taken.size() or taken[i]:
		return
	taken[i] = true
	_buttons[i].disabled = true
	SfxPlayer.play("accept")
	var n := taken.count(true)
	if n == taken.size():
		_end(true)
	else:
		say(Strings.SENTAKU_GOT[mini(n - 1, Strings.SENTAKU_GOT.size() - 1)])
		if InputMode.keyboard:
			for b in _buttons:
				if not b.disabled:
					b.grab_focus()
					break
	_redraw_choices()


func taken_count() -> int:
	return taken.count(true)


func _end(all_dry: bool) -> void:
	phase = Phase.END if all_dry else Phase.RAIN
	_end_t = 0.0
	hide_hint()
	for b in _buttons:
		b.disabled = true
	if all_dry:
		say(Strings.SENTAKU_ALL, Strings.ME)
	else:
		for i in taken.size():
			wet[i] = not taken[i]
		caption(Strings.SENTAKU_RAIN)
		set_ambient(WorldPalette.RAIN_AMBIENT)
	GameState.set_game_result(&"sentaku", all_dry)
	_redraw_choices()


func _redraw_choices() -> void:
	for b in _buttons:
		for c in b.get_children():
			if c is Control:
				(c as Control).queue_redraw()


func _process(delta: float) -> void:
	_t += delta * speed
	if phase == Phase.PICK and _t >= RAIN_TIME:
		_end(false)
	elif phase != Phase.PICK:
		_end_t += delta * speed
		if phase == Phase.RAIN and _end_t >= END_TIME * 0.5 and _end_t - delta * speed < END_TIME * 0.5:
			say(Strings.SENTAKU_WET)
		if _end_t >= END_TIME and not done:
			finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if phase != Phase.PICK and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


## 雲の近づき方（0.0 晴れ → 1.0 降りだす）
func cloud_amount() -> float:
	return 1.0 if phase == Phase.RAIN else clampf(_t / RAIN_TIME, 0.0, 1.0)


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	var k := cloud_amount()
	# 空：晴れから、だんだん雨の色へ
	var sky := P.SENTAKU_SKY.lerp(P.RAIN_SKY, smoothstep(0.4, 1.0, k))
	draw_rect(Rect2(Vector2.ZERO, s), sky)
	# 左から近づいてくる夕立の雲
	var front := -s.x * 0.3 + s.x * 1.3 * k
	var c := clock()
	for i in 7:
		var r := s.y * (0.12 + 0.03 * (i % 3))
		var x := front - i * s.x * 0.16 + sin(c * 0.6 + i) * 6.0
		draw_circle(Vector2(x, s.y * 0.12 + (i % 2) * r * 0.5), r, P.SENTAKU_CLOUD)
	draw_rect(Rect2(-10, 0, maxf(0.0, front - s.x * 0.9), s.y * 0.24), P.SENTAKU_CLOUD)
	# 庭の絵（空のところは透明）。雲がかかるほど、少し暗くする
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS, Color.WHITE.lerp(P.RAIN_LIGHT, k * 0.6))
	# 両はしの物干しの柱。洗濯物のならぶ高さに、ひもを張る
	var ground := s.y * 0.88
	if _row and _row.size.x > 0.0:
		var top := _row.global_position.y - global_position.y + 14.0
		var left := _row.global_position.x - global_position.x - 40.0
		var right := left + _row.size.x + 80.0
		for x in [left, right]:
			draw_rect(Rect2(x - 6, top - 20, 12, ground - top + 20), P.SENTAKU_POLE)
		draw_line(Vector2(left, top), Vector2(right, top), P.SENTAKU_LINE, 3.0)
	# 雨のすじ
	if phase == Phase.RAIN:
		for i in STREAKS:
			var fx := fposmod(i * 0.6180339, 1.0)
			var fy := fposmod(i * 0.4142135 + c * 1.3, 1.0)
			var p := Vector2(fx * s.x, fy * s.y)
			draw_line(p, p + Vector2(-5, 22), Color(P.RAIN_STREAK, 0.45), 2.0)


## 枠の中の洗濯物（洗濯ばさみで吊るしてある）。取り込んだものは、洗濯ばさみだけ
func _draw_cloth(a: Control, i: int) -> void:
	var w := a.size.x
	var top := 14.0
	for x in [w * 0.3, w * 0.7]:
		a.draw_rect(Rect2(x - 3, top - 6, 6, 12), P.SENTAKU_POLE)
	if taken[i]:
		return
	# 洗濯物の絵。枠の上のふちに洗濯ばさみがそろうように、上から吊るす
	var tex: Texture2D = CLOTHES[i % CLOTHES.size()]
	var box := Vector2(w - 16.0, a.size.y - top - 34.0)
	var k := minf(box.x / tex.get_width(), box.y / tex.get_height())
	var sz := tex.get_size() * k
	var sway := sin(clock() * 2.0 + i) * 0.04
	var cx := w / 2.0
	a.draw_set_transform(Vector2(cx, top - 6.0), sway, Vector2.ONE)
	a.draw_texture_rect(tex, Rect2(-sz.x / 2.0, 0, sz.x, sz.y), false, Color(0.82, 0.86, 0.95) if wet[i] else Color.WHITE)
	a.draw_set_transform(Vector2.ZERO)
	if wet[i]:
		# 少しぬれた（色は上で暗くしてある。しずく）
		for d in 3:
			a.draw_circle(Vector2(cx - 16 + d * 16, top + 86 + (d % 2) * 6), 3, Color(P.RAIN_STREAK, 0.9))
