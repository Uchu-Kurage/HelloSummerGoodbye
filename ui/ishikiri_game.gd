class_name IshikiriGame
extends Control
## ミニゲーム「石切り」（3日目、親友ルート）。会話の @game ishikiri で始まる。
## ビー玉と川の石を交換したあと、川原でタケルと石切りで勝負する。
## 1. タケルがお手本を見せる（5回跳ねる。「いち、にー、さん、しー、ご！」）
## 2. 足もとの3つの石から1つ選ぶ（タケルの一言だけが、正解を教える）
## 3. 押しつづけて腕を引き、ちょうどいいところで離す。腕はちょうどいいところを通りすぎて、さらに引きすぎる
## 4. 跳ねるたびに水の輪が広がり、タケルが数える。0回なら「ぽちゃん！」
## これを3回。いちばんよかった回数を GameState.ishikiri_best に入れ、結果のフラグ ishikiri_win / ishikiri_draw / ishikiri_lose も立てる

signal finished

enum Phase { DEMO, PICK, AIM, FLY, SHOW, DONE }

const STONES: Array[SkipStone] = [
	preload("res://data/skip_stones/flat.tres"),
	preload("res://data/skip_stones/round.tres"),
	preload("res://data/skip_stones/big.tres"),
]
const THROWS := 3
## 押しはじめから「ちょうどいいところ」までの秒数と、その前後の幅
const SWEET_SPOT := 0.8
const SWEET_WINDOW := 0.12
## 幅の外では、この秒数ずれるごとに跳ねる回数が減り、ずれきると 0 回
const FALLOFF := 0.5
## 腕をいちばん後ろまで引ききる秒数（ちょうどいいところを通りすぎて、さらに引きすぎる）
const PULL_MAX := 1.6
## タケルのお手本の回数
const DEMO_SKIPS := 5
## 勝ち負けの境目（いちばんよかった回数がこれ以上なら かち、ちょうど DRAW_AT なら ひきわけ）
const WIN_AT := 6
const DRAW_AT := 5
## 最初に水面に着くまでの時間と、跳ねるごとの時間（だんだん短く）
const FIRST_HOP := 0.6
const HOP := 0.4
const HOP_DECAY := 0.85
## 石が沈んだあと、水の輪を眺める時間
const SHOW_TIME := 1.6
## 背景の絵（川原と、浅い川と、向こう岸の木）
const BG: Texture2D = preload("res://ui/minigame_bg/ishikiri.jpg")
## 絵の中で、石が跳ねる水面の高さ（絵の高さに対する割合。川のまん中）
const SKIM_Y := 0.655
## 絵の中の、ふたりの足もと（手前の川原。絵の幅・高さに対する割合）
const THROWER_AT := Vector2(0.15, 0.87)
const TAKERU_AT := Vector2(0.07, 0.85)
## 絵の中の川の上と下（水のきらめきを置く幅）
const WATER_TOP := 0.6
const WATER_BOTTOM := 0.68
## 跳ねていく石をカメラが追う、いちばん大きい量（画面の幅に対する割合）。絵はその分だけ横に大きく敷く
const PAN_MAX := 0.125
## 絵のどこを残すか（横長の画面では空を少し切り、川と川原を残す）
const BG_FOCUS := Vector2(0.3, 0.6)
## 水の輪が広がりきるまでと、消えるまでの秒数
const RING_GROW := 2.0
const RING_LIFE := 4.5
## ふたりの絵（手描き。どれも右の川を向く）。[絵, 絵の中の頭の高さ px]
## ポーズごとに描いた大きさがちがうので、頭の大きさでそろえる（しゃがむ姿は、そのぶん背が低くなる）
const KID_ART := {
	&"player": [preload("res://world/scenery/painted/player_1.png"), 84.0],
	&"player_windup": [preload("res://world/scenery/painted/player_mg1_4.png"), 84.0],
	&"player_throw": [preload("res://world/scenery/painted/player_mg1_5.png"), 87.0],
	&"takeru": [preload("res://world/scenery/painted/npc_takeru.png"), 213.0],
	&"takeru_windup": [preload("res://world/scenery/painted/takeru_mg1_4.png"), 108.0],
	&"takeru_throw": [preload("res://world/scenery/painted/takeru_mg1_5.png"), 110.0],
}
## 頭の高さ（背景の絵の高さに対する割合）
const KID_HEAD := 0.046
## 立っている主人公の、石を持つ手（絵の幅・高さに対する割合）
const PLAYER_HAND := Vector2(0.5, 0.66)
## 腕を引きはじめたとみなす量と、投げたあとの姿を見せる秒数
const PULL_POSE := 0.06
const THROW_POSE := 0.6
## お手本で、タケルが振りかぶっている秒数（石が手を離れるまで）
const DEMO_WINDUP := 0.5
const P := preload("res://world/world_palette.gd")
const COUNT := ["いち", "にー", "さん", "しー", "ご", "ろく", "なな", "はち", "きゅう", "じゅう"]

var hud: Hud
var phase := Phase.DEMO
## 投げた回数と、それぞれ跳ねた回数
var throws: Array[int] = []
var best := 0
var result := &""
var stone: SkipStone
## いまの投げ：跳ねる回数、引きすぎ（高く上がる）／はやすぎ（弱い）
var _skips := 0
var _high := false
var _weak := false
var _t := 0.0
var _speed := 1.0
var _counted := 0
var _sweet_played := false
var _demo := true
## 水の輪：[x, 生まれた時刻]
var _rings: Array = []
var _clock_t := 0.0
var _hold: HoldInput
var _chip: PanelContainer
var _line: Label
var _hint: Label
var _picks: HBoxContainer
var _pick_buttons: Array[Button] = []
var _repick: Button


func _ready() -> void:
	# 人物の絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	safe.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	# タケルのひとこと（小札）
	_chip = PanelContainer.new()
	_chip.theme_type_variation = &"PaperChip"
	_chip.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_BEGIN
	_chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_chip)
	_line = Label.new()
	_chip.add_child(_line)
	_chip.modulate.a = 0.0
	# かまえているあいだ、石を選びなおす（タッチ用。キーボードは Esc）
	_repick = Button.new()
	_repick.text = Strings.ISHI_REPICK
	_repick.theme_type_variation = &"TouchButton"
	_repick.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 2, UiTokens.TOUCH_MIN)
	_repick.focus_mode = Control.FOCUS_NONE
	_repick.pressed.connect(_back_to_pick)
	UiAnim.add_press_feedback(_repick)
	_repick.visible = false
	top.add_child(_repick)
	_hold.exclude.append(_repick)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	# 足もとの石（3つ）
	_picks = HBoxContainer.new()
	_picks.alignment = BoxContainer.ALIGNMENT_CENTER
	_picks.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	_picks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_picks)
	for i in STONES.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 2, UiTokens.TOUCH_MIN * 1.4)
		b.theme_type_variation = &"ChoiceItem"
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_pick_pressed.bind(b))
		b.focus_entered.connect(_on_pick_focus.bind(b))
		b.focus_exited.connect(_on_pick_focus.bind(b))
		UiAnim.add_press_feedback(b)
		var art := Control.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.draw.connect(_draw_pick.bind(art, b))
		b.add_child(art)
		var mark := Label.new()
		mark.name = "Mark"
		mark.text = Strings.SELECT_MARK
		mark.theme_type_variation = &"AccentMarkLabel"
		mark.position = Vector2(UiTokens.SPACE_XS, 2)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.visible = false
		b.add_child(mark)
		_picks.add_child(b)
		_pick_buttons.append(b)
	for i in _pick_buttons.size():
		var b := _pick_buttons[i]
		b.focus_neighbor_left = b.get_path_to(_pick_buttons[(i + _pick_buttons.size() - 1) % _pick_buttons.size()])
		b.focus_neighbor_right = b.get_path_to(_pick_buttons[(i + 1) % _pick_buttons.size()])
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = b.get_path()
	_picks.modulate.a = 0.0
	_picks.visible = false
	# 案内（控えめに、下の小札）
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
	InputMode.mode_changed.connect(_refresh_hint.unbind(1))
	# 画面のどこを押してもよいので、右上のボタンは隠す
	get_tree().call_group("touch_controls", "set_suppressed", true)
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)
	# タケルのお手本
	_start_throw(DEMO_SKIPS, false, false)


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)


func say(text: String) -> void:
	_line.text = Strings.SPEECH_FORMAT % [hud.speaker_name() if hud else "", text]
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func _refresh_hint() -> void:
	var n := mini(throws.size() + 1, THROWS)
	if phase == Phase.PICK:
		_hint.text = (Strings.ISHI_PICK_KEY if InputMode.keyboard else Strings.ISHI_PICK_TOUCH) % [n, THROWS]
	else:
		_hint.text = Strings.ISHI_AIM_TOUCH if InputMode.touch else Strings.ISHI_AIM_KEY
	_repick.visible = phase == Phase.AIM and InputMode.touch and not _hold.is_down


func _show_hint(on: bool) -> void:
	_refresh_hint()
	UiAnim.fade(_hint.get_meta("chip"), 1.0 if on else 0.0, UiTokens.TIME_SMALL)


## 跳ねる回数（石のいちばんうまいときの回数 ×「ちょうどいいところ」にどれだけ近かったか）
static func skips_for(s: SkipStone, held: float) -> int:
	var off := absf(held - SWEET_SPOT)
	var k := 1.0 if off <= SWEET_WINDOW else clampf(1.0 - (off - SWEET_WINDOW) / FALLOFF, 0.0, 1.0)
	return roundi(s.max_skips * k)


## 3回のうち、いちばんよかった回数で決まる
static func result_for(n: int) -> StringName:
	if n >= WIN_AT:
		return &"win"
	if n == DRAW_AT:
		return &"draw"
	return &"lose"


# --- 進み ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * _speed
	_t += d
	_clock_t += d
	match phase:
		Phase.DEMO, Phase.FLY:
			if phase == Phase.DEMO and _t >= 0.0 and _t - d < 0.0:
				SfxPlayer.play("throw")
			# 跳ねるたびに水の輪が広がり、タケルが数える
			var hops := _hop_times()
			while _counted < _skips and _t >= hops[_counted]:
				_rings.append([_stone_x_at(_counted), _clock_t])
				_counted += 1
				SfxPlayer.play("skip")
				var words: Array = COUNT.slice(0, _counted)
				say("、".join(words) + ("！" if _counted == _skips else ""))
			if _t >= hops[-1]:
				_sink()
		Phase.SHOW:
			if _t >= SHOW_TIME:
				_after_show()
		Phase.AIM:
			if _hold.is_down and not _sweet_played and _hold.held_time >= SWEET_SPOT:
				# ちょうどいいところで、小さく「きゅっ」
				_sweet_played = true
				SfxPlayer.play("skip_sweet")
	queue_redraw()


func _go(p: Phase) -> void:
	phase = p
	_t = 0.0


func _start_throw(n: int, high: bool, weak: bool) -> void:
	_skips = n
	_high = high
	_weak = weak
	_counted = 0
	_rings.clear()
	_speed = 1.0
	_go(Phase.DEMO if _demo else Phase.FLY)
	if _demo:
		# お手本は、タケルが振りかぶるところから（手を離れたときに音）
		_t = -DEMO_WINDUP
	else:
		SfxPlayer.play("throw")


## 石が水に沈んだ（最後の着水）
func _sink() -> void:
	_rings.append([_stone_x_at(_skips), _clock_t])
	SfxPlayer.play("plop")
	if _skips == 0 and not _demo:
		say(Strings.ISHI_PLOP)
	_go(Phase.SHOW)


func _after_show() -> void:
	_speed = 1.0
	if _demo:
		_demo = false
		_open_pick()
		return
	if throws.size() >= THROWS:
		_finish()
	else:
		_open_pick()


func _open_pick() -> void:
	_go(Phase.PICK)
	stone = null
	# 投げた石は川に消え、足もとに新しい3つが並ぶ（並びは投げるたびに変わる）
	for i in _pick_buttons.size():
		_pick_buttons[i].set_meta("stone", STONES[(i + throws.size()) % STONES.size()])
		_pick_buttons[i].disabled = false
		(_pick_buttons[i].get_child(0) as Control).queue_redraw()
	_picks.visible = true
	UiAnim.fade(_picks, 1.0, UiTokens.TIME_SMALL)
	_show_hint(true)
	if InputMode.keyboard:
		_pick_buttons[0].grab_focus()


func _on_pick_focus(b: Button) -> void:
	if b.has_focus() and InputMode.keyboard:
		SfxPlayer.play("cursor")
	_refresh_picks()


func _refresh_picks() -> void:
	for b in _pick_buttons:
		var sel := b.has_focus() and InputMode.keyboard
		b.theme_type_variation = &"ChoiceItemSelected" if sel else &"ChoiceItem"
		b.get_node("Mark").visible = sel


func _on_pick_pressed(b: Button) -> void:
	choose(b.get_meta("stone"))


## 石を選んで、かまえる（自動の動作確認からも呼べる）
func choose(s: SkipStone) -> void:
	if phase != Phase.PICK:
		return
	stone = s
	SfxPlayer.play("accept")
	say(s.takeru_line)
	var f := get_viewport().gui_get_focus_owner()
	if f:
		f.release_focus()
	for b in _pick_buttons:
		b.disabled = true
	UiAnim.fade(_picks, 0.0, UiTokens.TIME_SMALL_OUT).finished.connect(func():
		if phase != Phase.PICK:
			_picks.visible = false)
	_go(Phase.AIM)
	_sweet_played = false
	_hold.enabled = true
	_show_hint(true)


func choose_id(id: StringName) -> void:
	for s in STONES:
		if s.id == id:
			choose(s)


## 石を選びなおす（Esc／「えらびなおす」）
func _back_to_pick() -> void:
	if phase != Phase.AIM or _hold.is_down:
		return
	SfxPlayer.play("cancel")
	_hold.enabled = false
	_open_pick()


func _on_pressed() -> void:
	if phase != Phase.AIM:
		return
	_sweet_played = false
	_refresh_hint()


func _on_released(held: float) -> void:
	if phase != Phase.AIM:
		return
	_hold.enabled = false
	_show_hint(false)
	_repick.visible = false
	var n := skips_for(stone, held)
	throws.append(n)
	best = maxi(best, n)
	_start_throw(n, held > SWEET_SPOT + SWEET_WINDOW, held < SWEET_SPOT - SWEET_WINDOW)


func _finish() -> void:
	if phase == Phase.DONE:
		return
	result = result_for(best)
	GameState.set_ishikiri_best(best, result)
	phase = Phase.DONE
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


func _input(event: InputEvent) -> void:
	if phase == Phase.AIM and event.is_action_pressed("ui_cancel"):
		_back_to_pick()
		get_viewport().set_input_as_handled()
	elif phase in [Phase.DEMO, Phase.FLY, Phase.SHOW]:
		# 跳ねている石と水の輪は、決定キーやタップで早送りできる
		var tap: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_speed = UiTokens.SKIP_SPEED
			get_viewport().set_input_as_handled()
	elif phase == Phase.PICK and InputMode.keyboard and get_viewport().gui_get_focus_owner() == null \
			and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_pick_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()


# --- 石の飛び方 ---------------------------------------------------------------

## 水面に着く時刻（跳ねるごと。最後は沈む着水）
func _hop_times() -> Array[float]:
	var out: Array[float] = []
	var t := FIRST_HOP * (1.4 if _high else (0.7 if _weak else 1.0))
	out.append(t)
	var h := HOP
	for i in _skips:
		t += h
		h *= HOP_DECAY
		out.append(t)
	return out


## 着水する場所（画面の幅に対する割合で、投げる人からの距離）
func _stone_x_at(i: int) -> float:
	var first := 0.16 * (0.6 if _weak else 1.0) * (0.7 if _high else 1.0)
	var x := first
	var step := 0.1
	for k in i:
		x += step
		step *= 0.82
	return x


## いまの石の位置（投げる人の手元からの、画面の割合の距離 x と、水面からの高さ px）
func _stone_now() -> Vector2:
	var hops := _hop_times()
	var prev_t := 0.0
	var prev_x := 0.0
	for i in hops.size():
		var x := _stone_x_at(i)
		if _t < hops[i]:
			var u := clampf((_t - prev_t) / maxf(hops[i] - prev_t, 0.001), 0.0, 1.0)
			var hgt: float
			if i == 0:
				# 手元から、低く速く（引きすぎは高く上がる）
				var peak := 220.0 if _high else 50.0
				hgt = lerpf(10.0, 0.0, u) + peak * 4.0 * u * (1.0 - u)
			else:
				hgt = 40.0 * pow(HOP_DECAY, i) * 4.0 * u * (1.0 - u)
			return Vector2(lerpf(prev_x, x, u), hgt)
		prev_t = hops[i]
		prev_x = x
	return Vector2(prev_x, -20.0)


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	# 石が跳ねる水面の高さ（絵の川のまん中）
	var skim_y := _bg_point(Vector2(0.0, SKIM_Y)).y
	var thrower := _bg_point(THROWER_AT)
	var tk_pos := _bg_point(TAKERU_AT)
	var from := tk_pos if _demo else thrower
	# 跳ねていく石を、カメラが少しだけ追う（絵も、ふたりも、いっしょに動く）
	var pan := 0.0
	if phase in [Phase.DEMO, Phase.FLY, Phase.SHOW] and not UiAnim.reduced():
		pan = clampf(_stone_now().x - 0.3, 0.0, 0.25) * 2.0 * PAN_MAX * s.x
	draw_set_transform(Vector2(-pan, 0))
	MinigameBg.draw_cover(self, BG, _bg_rect(), BG_FOCUS)
	_draw_glints()
	# 水の輪（いくつも残る）
	for r in _rings:
		var age: float = _clock_t - r[1]
		var cx: float = from.x + r[0] * s.x
		for j in 2:
			var a := age - j * 0.25
			if a <= 0.0:
				continue
			var rad := 10.0 + minf(a, RING_GROW) * 36.0
			var alpha := clampf(1.0 - a / RING_LIFE, 0.0, 0.9)
			if alpha > 0.0:
				_draw_ring(Vector2(cx, skim_y + 4), rad, rad * 0.22, Color(P.WATER_LIGHT, alpha))
	# 石
	if (phase in [Phase.DEMO, Phase.FLY] and _t >= 0.0) or (phase == Phase.SHOW and _t < 0.1):
		var sp := _stone_now()
		if sp.y >= 0.0:
			var at := Vector2(from.x + sp.x * s.x, skim_y - sp.y)
			draw_circle(at + Vector2(0, sp.y + 6), 6, Color(0, 0, 0, 0.12))
			_draw_stone(at, 1.0, stone if not _demo else STONES[0])
	# 川原のふたり
	# タケル：お手本で振りかぶる → 投げた姿 → 立つ
	var tk_pose := &"takeru"
	if _demo and phase == Phase.DEMO:
		tk_pose = &"takeru_windup" if _t < 0.0 else (&"takeru_throw" if _t < THROW_POSE else &"takeru")
	_draw_kid(tk_pos, tk_pose, 0.0)
	# 主人公：押しているあいだ腕を引く → 投げた姿 → 立つ
	var pull := 0.0
	if phase == Phase.AIM and _hold.is_down:
		pull = clampf(_hold.held_time / PULL_MAX, 0.0, 1.0)
	var pose := &"player"
	if pull > PULL_POSE:
		pose = &"player_windup"
	elif not _demo and phase == Phase.FLY and _t < THROW_POSE:
		pose = &"player_throw"
	_draw_kid(thrower, pose, pull)
	draw_set_transform(Vector2.ZERO)


## 絵を敷く場所（カメラが追う分だけ、画面より横に大きい）
func _bg_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x * (1.0 + PAN_MAX), size.y))


## 絵の中の点（絵の幅・高さに対する割合）が、画面のどこに来るか（MinigameBg.draw_cover と同じ計算）
func _bg_point(f: Vector2) -> Vector2:
	var r := _bg_rect()
	var ts := BG.get_size()
	var k := _bg_scale()
	var src_pos := (ts - r.size / k) * BG_FOCUS
	return r.position + (f * ts - src_pos) * k


## 絵の 1px が、画面の何 px になるか
func _bg_scale() -> float:
	var r := _bg_rect()
	var ts := BG.get_size()
	return maxf(r.size.x / ts.x, r.size.y / ts.y)


## 水面のきらめき（絵の川の上に、ほんの少し。動きを減らす設定では止まる）
func _draw_glints() -> void:
	var top := _bg_point(Vector2(0.0, WATER_TOP)).y
	var bottom := _bg_point(Vector2(0.0, WATER_BOTTOM)).y
	var w := _bg_rect().size.x
	var c := _clock()
	for i in 8:
		var y := lerpf(top, bottom, (i % 4 + 0.5) / 4.0)
		var x := fposmod(i * 197.0 + c * 18.0, w)
		var a := 0.25 + 0.15 * sin(c * 1.7 + i)
		draw_line(Vector2(x, y), Vector2(x + 24 + (i % 3) * 10, y), Color(P.WATER_LIGHT, a), 2.0)


## 石（仮の絵）。足もとに並べるときと、飛んでいるとき
func _draw_stone(at: Vector2, k: float, st: SkipStone) -> void:
	if st == null:
		return
	var col := st.color
	match st.look:
		SkipStone.Look.FLAT:
			_draw_ellipse(at, 13 * k, 4.5 * k, col)
			_draw_ellipse(at - Vector2(0, 1.5 * k), 10 * k, 2.5 * k, col.lightened(0.18))
		SkipStone.Look.ROUND:
			draw_circle(at, 9 * k, col)
			draw_circle(at + Vector2(-3, -3) * k, 3 * k, col.lightened(0.25))
		SkipStone.Look.BIG:
			_draw_ellipse(at, 19 * k, 8 * k, col)
			_draw_ellipse(at - Vector2(0, 3 * k), 15 * k, 4 * k, col.lightened(0.15))


func _draw_pick(art: Control, b: Button) -> void:
	var st: SkipStone = b.get_meta("stone") if b.has_meta("stone") else null
	if st == null:
		return
	var center := Vector2(art.size.x * 0.5, art.size.y * 0.38)
	art.draw_set_transform(Vector2.ZERO)
	# 足もとの石は大きめに描く
	match st.look:
		SkipStone.Look.FLAT:
			_ellipse_on(art, center, 26, 9, st.color)
			_ellipse_on(art, center - Vector2(0, 3), 20, 5, st.color.lightened(0.18))
		SkipStone.Look.ROUND:
			art.draw_circle(center, 17, st.color)
			art.draw_circle(center + Vector2(-6, -6), 6, st.color.lightened(0.25))
		SkipStone.Look.BIG:
			_ellipse_on(art, center, 36, 15, st.color)
			_ellipse_on(art, center - Vector2(0, 5), 28, 8, st.color.lightened(0.15))
	var font := art.get_theme_default_font()
	var fs := UiTokens.FONT_SMALL
	var col := UiTokens.ACCENT_INK if b.get_node("Mark").visible else UiTokens.INK
	art.draw_string(font, Vector2(0, art.size.y - UiTokens.SPACE_S), st.display_name, HORIZONTAL_ALIGNMENT_CENTER, art.size.x, fs, col)


## 子ども（手描きの絵）。pos は足もと。pull は腕を後ろへ引いた量（0〜1。引くほど腰を落とし、後ろへ）
func _draw_kid(pos: Vector2, pose: StringName, pull: float) -> void:
	var art: Array = KID_ART[pose]
	var tex: Texture2D = art[0]
	var k: float = _bg_scale() * BG.get_height() * KID_HEAD / art[1]
	var sz := tex.get_size() * k
	var p := pos + Vector2(-0.25, 0.12) * pull * sz.y * 0.2
	# 足もとの影
	_draw_ellipse(pos + Vector2(0, -2), sz.x * 0.38, sz.y * 0.03, Color(0, 0, 0, 0.12))
	var rect := Rect2(p - Vector2(sz.x * 0.5, sz.y), sz)
	draw_texture_rect(tex, rect, false)
	# かまえて、まだ引いていないあいだは、選んだ石を手に持つ
	if pose == &"player" and phase == Phase.AIM and stone:
		_draw_stone(rect.position + PLAYER_HAND * sz, 0.8, stone)


## 水の輪（だ円の線）
func _draw_ring(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, 2.5)


func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	_ellipse_on(self, c, rx, ry, col)


func _ellipse_on(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


## 絵の動き（動きを減らす設定では止める）
func _clock() -> float:
	return 0.0 if UiAnim.reduced() else float(Time.get_ticks_msec()) / 1000.0
