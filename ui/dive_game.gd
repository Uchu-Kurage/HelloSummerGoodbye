class_name DiveGame
extends Control
## ミニゲーム「飛び込み」（7日目、親友ルート）。会話の @game dive で始まる。
## 川の淵の高い岩から、タケルと二人で息を合わせて飛び込む。失敗も時間制限もなく、いつ離しても必ず跳べる。
## 1. 岩のふちから下の淵をのぞきこむ
## 2. 押しつづけて力をため、タケルの「せー……の！」の「の！」で離す
## 3. 空中で一瞬スローになる（ぴったりなら二人が並ぶ）
## 4. 水の中：音がこもり、上から光がゆれる
## 5. 水面に顔を出して、二人で笑う
## 結果（ぴったり／はやすぎ／おそい）は GameState.dive_result に入れ、フラグ dive_perfect / dive_early / dive_late も立てる

signal finished

enum Phase { LOOK, WAIT, CHARGE, AIR, UNDER, SURFACE, DONE }

## 押しはじめてから「の！」までの秒数
const COUNT_NO := 1.3
## 「の！」の前後、この秒数以内に離すと「ぴったり」
const PERFECT_WINDOW := 0.15
## 下をのぞきこむ時間
const LOOK_TIME := 1.2
## 空中（まん中で一瞬スローになる）
const AIR_TIME := 1.8
## はやすぎ・おそいのとき、あとから跳ぶほうが遅れる時間
const FOLLOW_DELAY := 0.5
## 水の中の静けさ
const UNDER_TIME := 2.6
const SURFACE_TIME := 1.6
## 押しているあいだ足がふるえる大きさ（px）
const SHAKE := 3.0
const P := preload("res://world/world_palette.gd")

var hud: Hud
var phase := Phase.LOOK
var result := &""
var _t := 0.0
var _speed := 1.0
## 跳んだ時刻（AIR の中の時間。負なら、まだ跳んでいない）
var _me_jump := -1.0
var _takeru_jump := -1.0
var _air_t := 0.0
var _said_no := false
var _called := false
var _prev_ambient := ""
var _hold: HoldInput
var _chip: PanelContainer
var _line: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hold = HoldInput.new()
	_hold.pressed.connect(_on_pressed)
	_hold.released.connect(_on_released)
	add_child(_hold)
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	# タケルのひとこと（小札）
	_chip = PanelContainer.new()
	_chip.theme_type_variation = &"PaperChip"
	_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_chip)
	_line = Label.new()
	_chip.add_child(_line)
	_chip.modulate.a = 0.0
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	# 押しつづけの案内（控えめに、下の道の帯の上の小札）
	var hint_chip := PanelContainer.new()
	hint_chip.theme_type_variation = &"PaperChip"
	hint_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint_chip)
	_hint = Label.new()
	_hint.theme_type_variation = &"SmallLabel"
	hint_chip.add_child(_hint)
	hint_chip.modulate.a = 0.0
	_hint.set_meta("chip", hint_chip)
	# 右上のボタンは、画面のどこを押してもよいこのミニゲームでは隠す
	get_tree().call_group("touch_controls", "set_suppressed", true)
	# 岩の上では蝉と川の音を大きめに
	_prev_ambient = SfxPlayer._ambient_name
	SfxPlayer.set_ambient(WorldPalette.DIVE_AMBIENT_ROCK)
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)
	SfxPlayer.set_ambient(_prev_ambient)


func say(text: String) -> void:
	_line.text = Strings.SPEECH_FORMAT % [hud.speaker_name() if hud else "", text]
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func _show_hint(on: bool) -> void:
	var chip: Control = _hint.get_meta("chip")
	_hint.text = Strings.DIVE_HINT_TOUCH if InputMode.touch else Strings.DIVE_HINT_KEY
	UiAnim.fade(chip, 1.0 if on else 0.0, UiTokens.TIME_SMALL)


# --- 進み ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * _speed
	_t += d
	match phase:
		Phase.LOOK:
			if _t >= LOOK_TIME:
				_go(Phase.WAIT)
				_hold.enabled = true
				_show_hint(true)
		Phase.CHARGE:
			# 「の！」
			if _t >= COUNT_NO and not _said_no:
				_said_no = true
				say(Strings.DIVE_COUNT_NO)
				SfxPlayer.play("count_no")
			# 離さないまま「の！」を過ぎたら、タケルだけ先に跳ぶ（いつ離しても跳べる）
			if _t > COUNT_NO + PERFECT_WINDOW and _takeru_jump < 0.0:
				result = &"late"
				_takeru_jump = 0.0
				_air_t = 0.0
				SfxPlayer.play("jump")
			# 先に水に入ったタケルが、下から呼ぶ
			if result == &"late" and not _called and _air_t >= AIR_TIME:
				_called = true
				SfxPlayer.play("splash")
				say(Strings.DIVE_LATE_CALL)
		Phase.AIR:
			_air_t += d
			var last := maxf(_me_jump, _takeru_jump)
			if _air_t >= last + AIR_TIME:
				SfxPlayer.play("splash")
				# 水に入った瞬間、すべての音がこもる
				SfxPlayer.set_ambient(WorldPalette.DIVE_AMBIENT_UNDER)
				_go(Phase.UNDER)
		Phase.UNDER:
			if _t >= UNDER_TIME:
				SfxPlayer.set_ambient(_prev_ambient)
				SfxPlayer.play("surface")
				_go(Phase.SURFACE)
		Phase.SURFACE:
			if _t >= SURFACE_TIME:
				_finish()
	# おそいとき、タケルは先に空中へ
	if phase == Phase.CHARGE and _takeru_jump >= 0.0:
		_air_t += d
	queue_redraw()


func _go(p: Phase) -> void:
	phase = p
	_t = 0.0


func _on_pressed() -> void:
	if phase != Phase.WAIT:
		return
	_go(Phase.CHARGE)
	SfxPlayer.play("breath")
	say(Strings.DIVE_COUNT_SE)


func _on_released(_held: float) -> void:
	if phase != Phase.CHARGE:
		return
	_hold.enabled = false
	_show_hint(false)
	var off := _t - COUNT_NO
	if result == &"late":
		# タケルはもう跳んでいる。下から呼んでいた声のまま
		_me_jump = _air_t
	elif off < -PERFECT_WINDOW:
		result = &"early"
		_me_jump = 0.0
		_takeru_jump = FOLLOW_DELAY
		_air_t = 0.0
	else:
		result = &"perfect"
		_me_jump = 0.0
		_takeru_jump = 0.0
		_air_t = 0.0
	GameState.set_dive_result(result)
	SfxPlayer.play("jump")
	_chip.modulate.a = 0.0
	phase = Phase.AIR


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


## 跳んだあとの演出は、決定キーやタップで早送りできる
func _input(event: InputEvent) -> void:
	if phase in [Phase.AIR, Phase.UNDER, Phase.SURFACE]:
		var tap: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_speed = UiTokens.SKIP_SPEED
			get_viewport().set_input_as_handled()


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	match phase:
		Phase.UNDER:
			_draw_under(s)
		Phase.SURFACE, Phase.DONE:
			_draw_surface(s)
		_:
			_draw_cliff(s)


## 岩のふちと、ずっと下の淵（のぞきこむと、思ったより高い）
func _draw_cliff(s: Vector2) -> void:
	var look := 1.0
	if phase == Phase.LOOK:
		look = smoothstep(0.0, 1.0, _t / LOOK_TIME)
	# 画面は「上から下をのぞきこむ」。look が進むほど岩のふちが上へ、淵が見えてくる
	var pan := lerpf(0.0, s.y * 0.25, look)
	draw_rect(Rect2(Vector2.ZERO, s), P.HILL_FAR.lerp(Color("#9FD0EA"), 0.4))
	var water_y := s.y * 1.05 - pan
	draw_rect(Rect2(0, water_y, s.x, s.y), P.WATER_DEEP)
	for i in 6:
		var y := water_y + 20 + i * 26
		var x := fposmod(i * 173.0 + _clock() * 18.0, s.x)
		draw_line(Vector2(x, y), Vector2(x + 70, y), P.WATER, 3.0)
	# 岩（左から張り出す）
	var top := s.y * 0.55 - pan
	draw_colored_polygon(PackedVector2Array([Vector2(0, top), Vector2(s.x * 0.42, top), Vector2(s.x * 0.46, top + 30),
		Vector2(s.x * 0.36, s.y * 1.4), Vector2(0, s.y * 1.4)]), P.ROCK)
	draw_rect(Rect2(0, top - 6, s.x * 0.42, 8), P.STONE_LIGHT)
	# ふたり（跳ぶ前は岩のふち。押しているあいだ、主人公の足がふるえる）
	var edge := s.x * 0.4
	var shake := 0.0
	if phase == Phase.CHARGE:
		shake = 0.0 if UiAnim.reduced() else sin(_clock() * 60.0) * SHAKE * clampf(_t / COUNT_NO, 0.0, 1.0)
	var crouch := 8.0 if phase == Phase.CHARGE else 0.0
	var me_pos := _fall_pos(_me_jump, Vector2(edge - 90, top), water_y, s)
	var tk_pos := _fall_pos(_takeru_jump, Vector2(edge - 30, top), water_y, s)
	_draw_kid(tk_pos, true, crouch if _takeru_jump < 0.0 else 0.0, 0.0)
	_draw_kid(me_pos, false, crouch if _me_jump < 0.0 else 0.0, shake)
	# 水しぶき（ぴったりなら重なる）
	for j in [_me_jump, _takeru_jump]:
		if j >= 0.0 and _air_t > j + AIR_TIME * 0.92:
			var k := clampf((_air_t - j - AIR_TIME * 0.92) / (AIR_TIME * 0.2), 0.0, 1.0)
			var cx := (me_pos.x if j == _me_jump else tk_pos.x)
			draw_arc(Vector2(cx, water_y), 30 + 70 * k, PI, TAU, 20, Color(P.WATER_LIGHT, 1.0 - k), 5.0)


## 跳んだあとの位置。まん中あたりで一瞬スローになる
func _fall_pos(jump: float, start: Vector2, water_y: float, s: Vector2) -> Vector2:
	if jump < 0.0 or _air_t < jump:
		return start
	var u := clampf((_air_t - jump) / AIR_TIME, 0.0, 1.0)
	# スロー：0.35〜0.6 のあいだ、時間の進みをゆっくりにする
	var w := u + 0.12 * sin(u * TAU)
	w = clampf(w, 0.0, 1.0)
	var x := start.x + s.x * 0.28 * w
	var y := start.y - 80.0 * 4.0 * w * (1.0 - w) * 0.6 + (water_y - start.y) * w * w
	return Vector2(x, y)


## 水の中：上から光がゆれ、泡がのぼる。二人が並んでしずむ
func _draw_under(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), P.WATER_DEEP.darkened(0.2))
	# 水面に近いほど明るい（段を重ねて、ゆるやかに）
	for i in 6:
		draw_rect(Rect2(0, 0, s.x, s.y * (0.08 + 0.07 * i)), Color(P.WATER, 0.09))
	var c := _clock()
	for i in 5:
		var x := s.x * (0.15 + 0.18 * i) + sin(c * 0.8 + i) * 30.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 0), Vector2(x + 20, 0), Vector2(x + 90, s.y), Vector2(x + 30, s.y)]),
			Color(P.WATER_LIGHT, 0.12 + 0.06 * sin(c * 1.3 + i * 2.0)))
	for i in 14:
		var bx := fposmod(i * 0.618, 1.0) * s.x
		var by := s.y - fposmod(c * 40.0 + i * 70.0, s.y)
		draw_arc(Vector2(bx, by), 3 + (i % 3) * 2, 0, TAU, 10, Color(P.WATER_LIGHT, 0.6), 1.5)
	var sink := minf(_t / UNDER_TIME, 1.0) * 40.0
	var gap := 50.0 if result == &"perfect" else 110.0
	_draw_kid(Vector2(s.x * 0.5 - gap, s.y * 0.55 + sink), false, 0.0, 0.0, 0.8)
	_draw_kid(Vector2(s.x * 0.5 + gap, s.y * 0.55 + sink + (0.0 if result == &"perfect" else -30.0)), true, 0.0, 0.0, 0.8)


## 水面に顔を出して、二人で笑う
func _draw_surface(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color("#9FD0EA"))
	var wy := s.y * 0.62
	var bob := sin(_clock() * 3.0) * 4.0
	for side in [-1.0, 1.0]:
		var hx: float = s.x * 0.5 + side * 60.0
		var is_takeru: bool = side > 0.0
		var skin := Color("#C68E62") if is_takeru else P.PLAYER_SKIN
		var head := Vector2(hx, wy - 30 + bob * side)
		draw_circle(head, 26, skin)
		if is_takeru:
			draw_arc(head, 22, PI * 0.9, PI * 2.1, 12, Color("#211D1A"), 11.0)
		else:
			# 帽子は岩の上に置いてきた。ぬれた髪
			draw_arc(head, 22, PI * 1.0, PI * 2.0, 12, Color("#3B3226"), 9.0)
		# 笑っている口
		draw_arc(head + Vector2(0, 6), 9, 0.2, PI - 0.2, 8, Color("#3B3226"), 2.5)
	# 水は顔のあとに描いて、あごから下を沈める
	draw_rect(Rect2(0, wy, s.x, s.y), P.WATER_DEEP)
	for i in 6:
		var y := wy + 14 + i * 22
		var x := fposmod(i * 211.0 + _clock() * 26.0, s.x)
		draw_line(Vector2(x, y), Vector2(x + 60, y), P.WATER, 3.0)
	draw_line(Vector2(0, wy), Vector2(s.x, wy), P.WATER_LIGHT, 3.0)


## 子ども（仮の姿）。pos は足もと、takeru なら日焼け・黒髪、主人公は麦わら帽子
func _draw_kid(pos: Vector2, takeru: bool, crouch: float, shake: float, scale_k := 1.0) -> void:
	var k := scale_k
	var skin := Color("#C68E62") if takeru else P.PLAYER_SKIN
	var shirt := Color("#E9E3D3") if takeru else P.PLAYER_BODY
	var pants := Color("#3E5A7A") if takeru else P.PLAYER_SHORTS
	var p := pos + Vector2(0, crouch)
	draw_rect(Rect2(p.x - 13 * k + shake, p.y - 36 * k, 10 * k, 36 * k - crouch), skin)
	draw_rect(Rect2(p.x + 3 * k - shake, p.y - 36 * k, 10 * k, 36 * k - crouch), skin)
	draw_rect(Rect2(p.x - 17 * k, p.y - 58 * k, 34 * k, 24 * k), pants)
	draw_rect(Rect2(p.x - 19 * k, p.y - 100 * k, 38 * k, 44 * k), shirt)
	var head := Vector2(p.x, p.y - 120 * k)
	draw_circle(head, 21 * k, skin)
	if takeru:
		draw_arc(head, 18 * k, PI * 0.9, PI * 2.1, 12, Color("#211D1A"), 9 * k)
	else:
		draw_rect(Rect2(head.x - 28 * k, head.y - 20 * k, 56 * k, 7 * k), P.PLAYER_HAT)
		draw_rect(Rect2(head.x - 18 * k, head.y - 35 * k, 36 * k, 16 * k), P.PLAYER_HAT)


## 絵の動き（動きを減らす設定では止める）
func _clock() -> float:
	return 0.0 if UiAnim.reduced() else float(Time.get_ticks_msec()) / 1000.0
