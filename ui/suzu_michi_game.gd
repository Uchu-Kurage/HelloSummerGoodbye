class_name SuzuMichiGame
extends NatsumiScreen
## ミニゲーム「鈴の音で道探し」（6日目、神隠しルート）。会話の @game suzu_michi で始まる。
## 暗い森の分かれ道。先を行くお面の子の鈴が、ひだりか みぎで鳴る。鳴ったほうへ進む（FORKS か所）。
## 音が出せない環境でも進めるよう、鈴が鳴るたびに、鳴ったほうで小さな光がゆれる。
## ちがうほうを選ぶと、同じ分かれ道にもどる（失敗はない）。

enum Phase { LISTEN, WALK, END }

const FORKS := 4
## 鈴が鳴る間隔と、光がゆれている時間
const RING_EVERY := 2.4
const GLOW_TIME := 1.2
const WALK_TIME := 0.9
const END_TIME := 1.6
const CHOICE_SIZE := Vector2(200, 96)
const P := preload("res://world/world_palette.gd")
const DARK := Color("#0F1420")
const PATH := Color("#2E3444")
const TRUNK := Color("#1A1E28")

var phase := Phase.LISTEN
var fork := 0
var wrong := 0
## いまの分かれ道で、鈴の鳴るほう（0 ひだり／1 みぎ）
var side := 0
var rings := 0
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _ring_t := 0.0
var _glow := 0.0
var _row: HBoxContainer
var _buttons: Array[Button] = []


func _build() -> void:
	rng.randomize()
	set_ambient(WorldPalette.OTHERWORLD_AMBIENT)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP * 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_row)
	for i in Strings.SUZU_MICHI_SIDES.size():
		var b := make_choice(i, CHOICE_SIZE, _draw_arrow, _on_choice)
		var l := Label.new()
		l.text = Strings.SUZU_MICHI_SIDES[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		_row.add_child(b)
		_buttons.append(b)
	link_row(_buttons)
	say(Strings.SUZU_MICHI_START)
	show_hint(Strings.SUZU_MICHI_HINT_TOUCH, Strings.SUZU_MICHI_HINT_KEY)
	_new_fork()
	if InputMode.keyboard:
		_buttons[0].grab_focus.call_deferred()


func _new_fork() -> void:
	side = rng.randi_range(0, 1)
	_ring_t = RING_EVERY - 0.6


func _ring() -> void:
	rings += 1
	_ring_t = 0.0
	_glow = GLOW_TIME
	SfxPlayer.play("suzu_far")


func _on_choice(i: int) -> void:
	choose(i)


## 分かれ道で進むほうを選ぶ（自動の動作確認からも呼べる）
func choose(i: int) -> void:
	if phase != Phase.LISTEN:
		return
	SfxPlayer.play("leaf_step")
	if i == side:
		fork += 1
		phase = Phase.WALK
		_t = 0.0
		if fork >= FORKS:
			caption(Strings.SUZU_MICHI_OUT)
			hide_hint()
		else:
			say(Strings.SUZU_MICHI_RIGHT)
	else:
		wrong += 1
		phase = Phase.WALK
		_t = 0.0
		caption(Strings.SUZU_MICHI_WRONG)


## いま鈴が鳴っているほう（光がゆれているあいだだけ。自動の動作確認から使う）
func heard_side() -> int:
	return side if _glow > 0.0 else -1


func _process(delta: float) -> void:
	var d := delta * speed
	_glow = maxf(0.0, _glow - d)
	match phase:
		Phase.LISTEN:
			_ring_t += d
			if _ring_t >= RING_EVERY:
				_ring()
		Phase.WALK:
			_t += d
			if _t >= WALK_TIME:
				_t = 0.0
				if fork >= FORKS:
					phase = Phase.END
				else:
					phase = Phase.LISTEN
					_new_fork()
		Phase.END:
			_t += d
			if _t >= END_TIME and not done:
				finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if phase == Phase.END and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var s := size
	# 並べ終わる前（大きさ 0）は描かない
	if s.x < 1.0 or s.y < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, s), DARK)
	var c := clock()
	# 歩いているあいだは、木が手前へ流れる
	var walk := 0.0
	if phase == Phase.WALK:
		walk = _t / WALK_TIME
	# 分かれ道（Y の字）
	var base := Vector2(s.x / 2.0, s.y)
	var fork_at := Vector2(s.x / 2.0, s.y * 0.52)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-220, 0), base + Vector2(220, 0), fork_at + Vector2(40, 0), fork_at + Vector2(-40, 0)]), PATH)
	for dir in [-1, 1]:
		var end := Vector2(s.x / 2.0 + dir * s.x * 0.34, s.y * 0.32)
		draw_colored_polygon(PackedVector2Array([fork_at + Vector2(-34, 0), fork_at + Vector2(34, 0), end + Vector2(dir * 10 + 16, 0), end + Vector2(dir * 10 - 16, 0)]), PATH)
	# 木のかげ（左右）
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 17 + fork
	for i in 14:
		var x := rng2.randf_range(0, s.x)
		if absf(x - s.x / 2.0) < 140.0:
			continue
		var w := rng2.randf_range(18, 46) * (1.0 + walk * 0.3)
		draw_rect(Rect2(x - w / 2.0, 0, w, s.y * rng2.randf_range(0.55, 0.9)), TRUNK)
	# 鈴の鳴ったほうで、小さな光がゆれる（音が出せないときの印）
	if _glow > 0.0:
		var k := _glow / GLOW_TIME
		var sway := sin(c * 9.0) * 10.0 if not UiAnim.reduced() else 0.0
		var p := Vector2(s.x / 2.0 + (side * 2 - 1) * s.x * 0.3 + sway, s.y * 0.3)
		draw_circle(p, 40, Color(1.0, 0.95, 0.72, 0.12 * k))
		draw_circle(p, 14, Color(1.0, 0.95, 0.72, 0.5 * k))
		draw_circle(p, 5, Color(1.0, 1.0, 0.9, 0.9 * k))
	# 分かれ道をいくつ来たか（小さな足あとの印）
	for i in FORKS:
		var col := Color(1, 1, 1, 0.55) if i < fork else Color(1, 1, 1, 0.15)
		draw_circle(Vector2(s.x / 2.0 - (FORKS - 1) * 12 + i * 24, s.y * 0.44), 5, col)


func _draw_arrow(a: Control, i: int) -> void:
	var c := Vector2(a.size.x / 2.0 + (i * 2 - 1) * 70, a.size.y / 2.0)
	var d := float(i * 2 - 1)
	a.draw_colored_polygon(PackedVector2Array([c + Vector2(d * 14, 0), c + Vector2(-d * 6, -12), c + Vector2(-d * 6, 12)]), UiTokens.INK_SOFT)
