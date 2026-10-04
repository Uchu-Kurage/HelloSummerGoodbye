class_name KaigaraGame
extends NatsumiScreen
## ミニゲーム「貝がら拾い」（6日目、初恋ルート）。会話の @game kaigara で始まる。
## 波打ちぎわ。波が寄せているあいだは待ち、引いたすきに、砂に残った貝がらを1つ拾う（ROUNDS 回）。
## どこかの回に、小さなさくら貝がまじっている。見つけて拾えたら高得点（好感度 +1、フラグ kaigara_good）。
## 拾わないうちに波がもどると、貝がらは持っていかれる。失敗はない。

enum Phase { IN, OUT, END }

const ROUNDS := 4
## 波が寄せている時間と、引いている（拾える）時間
const IN_TIME := 1.6
const OUT_TIME := 2.8
const END_TIME := 1.6
const SLOTS := 3
const CHOICE_SIZE := Vector2(128, 96)
const P := preload("res://world/world_palette.gd")
## 貝がらの種類：0 しろい・1 ちゃいろの巻き貝・2 さくら貝（小さくてうすい桃色）
const SHELL_COLORS := [Color("#F4EFE4"), Color("#C9A27A"), Color("#F2C6CF")]

var phase := Phase.IN
var round_i := 0
var found := false
var picks := 0
var rng := RandomNumberGenerator.new()
## いまの回の貝がら（種類の番号。-1 は拾ったあと）
var shells: Array[int] = []
var _sakura_round := 1
var _t := 0.0
var _picked_round := false
var _row: HBoxContainer
var _buttons: Array[Button] = []


func _build() -> void:
	rng.randomize()
	_sakura_round = rng.randi_range(1, ROUNDS - 1)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP * 3)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_row)
	for i in SLOTS:
		var b := make_choice(i, CHOICE_SIZE, _draw_shell_choice, _on_choice)
		b.disabled = true
		_row.add_child(b)
		_buttons.append(b)
	link_row(_buttons)
	_new_shells()
	say(Strings.KAIGARA_WAIT)
	show_hint(Strings.KAIGARA_HINT_TOUCH, Strings.KAIGARA_HINT_KEY)


func _new_shells() -> void:
	shells.clear()
	for i in SLOTS:
		shells.append(rng.randi_range(0, 1))
	if round_i == _sakura_round:
		shells[rng.randi_range(0, SLOTS - 1)] = 2
	_picked_round = false
	_redraw_choices()


## いま拾えるさくら貝の場所（なければ -1。自動の動作確認から使う）
func sakura_slot() -> int:
	return shells.find(2) if phase == Phase.OUT and not _picked_round else -1


func can_pick() -> bool:
	return phase == Phase.OUT and not _picked_round


func _on_choice(i: int) -> void:
	pick(i)


## 拾う（自動の動作確認からも呼べる）
func pick(i: int) -> void:
	if not can_pick() or i < 0 or i >= shells.size() or shells[i] < 0:
		return
	var kind := shells[i]
	shells[i] = -1
	_picked_round = true
	picks += 1
	SfxPlayer.play("pickup")
	if kind == 2:
		found = true
		say(Strings.KAIGARA_SAKURA)
	else:
		say(Strings.KAIGARA_PLAIN)
	_set_enabled(false)
	_redraw_choices()


func _set_enabled(on: bool) -> void:
	for b in _buttons:
		b.disabled = not on
	if on and InputMode.keyboard:
		_buttons[0].grab_focus()
	elif not on:
		var f := get_viewport().gui_get_focus_owner()
		if f and _row.is_ancestor_of(f):
			f.release_focus()


func _redraw_choices() -> void:
	for b in _buttons:
		for c in b.get_children():
			if c is Control:
				(c as Control).queue_redraw()


func _process(delta: float) -> void:
	var d := delta * speed
	_t += d
	match phase:
		Phase.IN:
			if _t >= IN_TIME:
				_t = 0.0
				phase = Phase.OUT
				SfxPlayer.play("surface")
				if round_i == 0:
					say(Strings.KAIGARA_START)
				_set_enabled(true)
				_redraw_choices()
		Phase.OUT:
			if _t >= OUT_TIME:
				_t = 0.0
				if not _picked_round and shells.has(2):
					say(Strings.KAIGARA_GONE)
				_set_enabled(false)
				round_i += 1
				if round_i >= ROUNDS:
					phase = Phase.END
					hide_hint()
				else:
					phase = Phase.IN
					SfxPlayer.play("splash")
					_new_shells()
		Phase.END:
			if _t >= END_TIME and not done:
				GameState.set_natsumi_game(&"kaigara", found)
				finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if phase == Phase.END and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


# --- 絵 -----------------------------------------------------------------------

## 波の先の高さ（0 = 海のふち、1 = 砂のいちばん手前）
func _wave() -> float:
	match phase:
		Phase.IN:
			return sin(clampf(_t / IN_TIME, 0.0, 1.0) * PI * 0.5)
		Phase.OUT:
			return 1.0 - smoothstep(0.0, 0.5, _t / OUT_TIME)
	return 0.0


func _draw() -> void:
	var s := size
	var sea_top := s.y * 0.18
	var shore := s.y * 0.42
	draw_rect(Rect2(0, 0, s.x, sea_top), P.SEA_FAR.lightened(0.3))
	draw_rect(Rect2(0, sea_top, s.x, shore - sea_top), P.SEA)
	var c := clock()
	for i in 4:
		var y := sea_top + (shore - sea_top) * (0.2 + 0.2 * i)
		var x := fposmod(c * 18.0 + i * 140.0, 260.0) - 260.0
		while x < s.x:
			draw_line(Vector2(x, y), Vector2(x + 70, y), Color(P.CLOUD, 0.5), 2.0)
			x += 260.0
	draw_rect(Rect2(0, shore, s.x, s.y - shore), P.SAND)
	draw_rect(Rect2(0, shore, s.x, (s.y - shore) * 0.55), P.SAND_WET)
	# 寄せてくる波（白いふちのある、うすい水）
	var front := shore + (s.y - shore) * 0.9 * _wave()
	if front > shore + 12.0:
		var pts := PackedVector2Array([Vector2(0, shore)])
		for i in 17:
			var t := i / 16.0
			pts.append(Vector2(s.x * t, maxf(front + sin(t * TAU * 2.0 + c) * 8.0, shore + 1.0)))
		pts.append(Vector2(s.x, shore))
		draw_colored_polygon(pts, Color(P.SEA_NEAR, 0.85))
		var edge := pts.slice(1, pts.size() - 1)
		draw_polyline(edge, Color(P.CLOUD, 0.9), 5.0)


func _draw_shell_choice(a: Control, i: int) -> void:
	if phase != Phase.OUT or i >= shells.size() or shells[i] < 0:
		# 波の下か、拾ったあと：ぬれた砂だけ
		a.draw_circle(a.size / 2.0, 6, Color(P.SAND_WET, 0.8))
		return
	var kind := shells[i]
	var c := a.size / 2.0 + Vector2(0, 6)
	var r := 16.0 if kind == 2 else 28.0
	var col: Color = SHELL_COLORS[kind]
	if kind == 1:
		# 巻き貝
		a.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.4), c + Vector2(r, r * 0.4), c + Vector2(r * 0.2, -r)]), col)
		for k in 3:
			a.draw_line(c + Vector2(-r * 0.6 + k * 10, r * 0.2), c + Vector2(r * 0.1 + k * 4, -r * 0.6), col.darkened(0.3), 2.0)
		return
	var pts := PackedVector2Array()
	for k in 17:
		var t := PI + PI * k / 16.0
		pts.append(c + Vector2(cos(t) * r, sin(t) * r * 0.9))
	pts.append(c + Vector2(0, r * 0.35))
	a.draw_colored_polygon(pts, col)
	# 紙の上でも見えるよう、ふちを描く
	var edge := pts.duplicate()
	edge.append(pts[0])
	a.draw_polyline(edge, col.darkened(0.35), 2.0)
	for k in 5:
		var t := PI + PI * (k + 1) / 6.0
		a.draw_line(c + Vector2(0, r * 0.3), c + Vector2(cos(t) * r * 0.9, sin(t) * r * 0.8), col.darkened(0.18), 1.5)
