class_name CapsuleGame
extends Control
## ミニゲーム「タイムカプセル埋め」（9日目の夜、親友ルート）。会話の @game capsule と @game capsule_stars で始まる。
## capsule：基地の床で埋める場所を選ぶ → ひとすくい掘るごとにタケルの話が1つ進む → 缶を置く → 土を寄せる → ならす
## capsule_stars：約束のあと、タケルが懐中電灯を消す。目が慣れると、4日目に選んだ材料のすき間から星が見える
## 選んだ場所は GameState.capsule_spot に入れる。タケルの地図のバツじるしは、選んだ場所のとなりにずれている

signal finished

enum Phase { PICK, DIG, PLACE, COVER, PAT, END, STARS, DONE }

## 掘れそうな場所（左・まんなか・右）。床の幅に対する位置
const SPOTS := [0.28, 0.5, 0.72]
## 土を寄せる時間（押しつづけて合計）
const COVER_TIME := 2.0
## タケルが「ぽん、ぽん」とたたく間と、主人公がたたく回数
const PAT_GAP := 0.45
const PATS := 2
## 埋め終わってから画面を閉じるまで
const END_TIME := 1.0
## 懐中電灯を消してから、目が慣れて星が見えるまで（決定キー・タップで早送り）
const STARS_TIME := 4.5
## 懐中電灯の光の半径（画面の高さに対する割合）
const LIGHT_RADIUS := 0.3
## さみしい一言のとき、光がゆれる大きさ（px）
const LIGHT_SHAKE := 6.0
## 穴に寄った絵の、床の絵の拡大率
const HOLE_ZOOM := 1.5
## 床の絵に重ねる、夜の暖かい暗さ（光の中でも絵ははっきり見えるくらい）
const FLOOR_NIGHT := Color(0.12, 0.08, 0.05, 0.3)
const P := preload("res://world/world_palette.gd")
## 基地の床を真上から見た水彩の絵（板きれ、小石、枯れ葉）
const BG: Texture2D = preload("res://ui/minigame_bg/capsule.jpg")

var hud: Hud
## 会話の @game の名前（capsule / capsule_stars）
var game_name := "capsule"
var phase := Phase.PICK
## 選んだ場所（SPOTS の番号）
var spot := -1
## 掘ったすくいの数（= 進んだ話の数）
var scoops := 0
var cover := 0.0
var pats := 0
var _t := 0.0
var _speed := 1.0
var _takeru_pats := 0
var _sad_t := 0.0
var _prev_ambient := ""
var _hold: HoldInput
var _chip: PanelContainer
var _line: Label
var _hint: Label
var _spots: HBoxContainer
var _spot_buttons: Array[Button] = []
## 懐中電灯の光が向いている場所（PICK のとき、選んでいる場所へゆっくり動く）
var _light_x := 0.5
var _light_target := 1


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
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	safe.add_child(v)
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
	# 埋める場所（左・まんなか・右）
	_spots = HBoxContainer.new()
	_spots.alignment = BoxContainer.ALIGNMENT_CENTER
	_spots.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	_spots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_spots)
	for i in SPOTS.size():
		var b := Button.new()
		b.text = Strings.CAPSULE_SPOTS[i]
		b.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 2, UiTokens.TOUCH_MIN)
		b.theme_type_variation = &"ChoiceItem"
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(choose_spot.bind(i))
		b.focus_entered.connect(_on_spot_focus)
		b.focus_exited.connect(_on_spot_focus)
		b.mouse_entered.connect(func(): _light_target = i)
		UiAnim.add_press_feedback(b)
		var mark := Label.new()
		mark.name = "Mark"
		mark.text = Strings.SELECT_MARK
		mark.theme_type_variation = &"AccentMarkLabel"
		mark.position = Vector2(UiTokens.SPACE_XS, 2)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.visible = false
		b.add_child(mark)
		_spots.add_child(b)
		_spot_buttons.append(b)
	for i in _spot_buttons.size():
		var b := _spot_buttons[i]
		b.focus_neighbor_left = b.get_path_to(_spot_buttons[maxi(i - 1, 0)])
		b.focus_neighbor_right = b.get_path_to(_spot_buttons[mini(i + 1, _spot_buttons.size() - 1)])
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = b.get_path()
	# 案内（控えめに、下の小札）
	var hint_chip := PanelContainer.new()
	hint_chip.theme_type_variation = &"PaperChip"
	hint_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint_chip)
	_hint = Label.new()
	_hint.theme_type_variation = &"SmallLabel"
	hint_chip.add_child(_hint)
	_hint.set_meta("chip", hint_chip)
	InputMode.mode_changed.connect(_refresh_hint.unbind(1))
	# 画面のどこを押してもよいので、右上のボタンは隠す
	get_tree().call_group("touch_controls", "set_suppressed", true)
	# 8月の終わりの夜：秋の虫と、スコップの音だけ
	_prev_ambient = SfxPlayer._ambient_name
	SfxPlayer.set_ambient(WorldPalette.CAPSULE_AMBIENT)
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)
	if game_name == "capsule_stars":
		_start_stars()
	else:
		say(Strings.CAPSULE_ANYWHERE)
		if InputMode.keyboard:
			_spot_buttons[1].grab_focus()
	_refresh_hint()


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)
	SfxPlayer.set_ambient(_prev_ambient)



## 上の小札にひとことを出す。会話と同じく「ぼく：……」のように「：」の前があれば、その人のせりふ
func say(text: String) -> void:
	var who := hud.speaker_name() if hud else ""
	var colon := text.find("：")
	if colon > 0 and colon <= Hud.SPEAKER_MAX:
		who = text.substr(0, colon)
		text = text.substr(colon + 1)
	_line.text = Strings.SPEECH_FORMAT % [who, text]
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func _refresh_hint() -> void:
	var touch := InputMode.touch
	var text := ""
	match phase:
		Phase.PICK:
			text = Strings.CAPSULE_PICK_TOUCH if touch else Strings.CAPSULE_PICK_KEY
		Phase.DIG:
			text = Strings.CAPSULE_DIG_TOUCH if touch else Strings.CAPSULE_DIG_KEY
		Phase.PLACE:
			text = Strings.CAPSULE_PLACE_TOUCH if touch else Strings.CAPSULE_PLACE_KEY
		Phase.COVER:
			text = Strings.CAPSULE_COVER_TOUCH if touch else Strings.CAPSULE_COVER_KEY
		Phase.PAT:
			text = Strings.CAPSULE_PAT_TOUCH if touch else Strings.CAPSULE_PAT_KEY
	_hint.text = text
	var chip: Control = _hint.get_meta("chip")
	var on := text != "" and not (phase == Phase.PAT and _takeru_pats < PATS)
	UiAnim.fade(chip, 1.0 if on else 0.0, UiTokens.TIME_SMALL)


func _on_spot_focus() -> void:
	for i in _spot_buttons.size():
		var b := _spot_buttons[i]
		var sel := b.has_focus() and InputMode.keyboard
		b.theme_type_variation = &"ChoiceItemSelected" if sel else &"ChoiceItem"
		b.get_node("Mark").visible = sel
		if b.has_focus():
			_light_target = i
			if InputMode.keyboard:
				SfxPlayer.play("cursor")


# --- 進み ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * _speed
	_t += d
	_sad_t = maxf(_sad_t - d, 0.0)
	_light_x = lerpf(_light_x, SPOTS[_light_target], minf(d * 6.0, 1.0))
	match phase:
		Phase.COVER:
			if _hold.is_down:
				cover = minf(cover + d / COVER_TIME, 1.0)
				if cover >= 1.0:
					_hold.release()
					# タケルがたたき終わるまで、主人公は待つ
					_hold.enabled = false
					_takeru_pats = 0
					_go(Phase.PAT)
		Phase.PAT:
			# タケルが先に「ぽん、ぽん」とたたく。そのあと主人公の番
			if _takeru_pats < PATS and _t >= PAT_GAP * (_takeru_pats + 1):
				_takeru_pats += 1
				SfxPlayer.play("pat")
				say(Strings.CAPSULE_PON if _takeru_pats == 1 else Strings.CAPSULE_PON_PON)
				if _takeru_pats == PATS:
					_hold.enabled = true
					_refresh_hint()
		Phase.END:
			if _t >= END_TIME:
				_finish()
		Phase.STARS:
			if _t >= STARS_TIME:
				_finish()
	queue_redraw()


func _go(p: Phase) -> void:
	phase = p
	_t = 0.0
	_refresh_hint()


## 埋める場所を選ぶ（ボタン。自動の動作確認からも呼べる）
func choose_spot(i: int) -> void:
	if phase != Phase.PICK:
		return
	spot = i
	_light_target = i
	SfxPlayer.play("accept")
	var f := get_viewport().gui_get_focus_owner()
	if f:
		f.release_focus()
	for b in _spot_buttons:
		b.disabled = true
	UiAnim.fade(_spots, 0.0, UiTokens.TIME_SMALL_OUT).finished.connect(func(): _spots.visible = false)
	GameState.set_capsule_spot(i)
	_go(Phase.DIG)
	_hold.enabled = true


## ひとすくい掘る。話が1つ進む
func scoop() -> void:
	if phase != Phase.DIG:
		return
	var line: String = Strings.CAPSULE_DIG_LINES[scoops]
	scoops += 1
	SfxPlayer.play("dig")
	say(line)
	if Strings.CAPSULE_SAD_LINES.has(scoops - 1):
		_sad_t = 1.4
	if scoops >= Strings.CAPSULE_DIG_LINES.size():
		_go(Phase.PLACE)


func _on_pressed() -> void:
	if phase == Phase.COVER:
		SfxPlayer.play("soil")


func _on_released(_held: float) -> void:
	match phase:
		Phase.DIG:
			scoop()
		Phase.PLACE:
			# 主人公が缶をそっと穴に置く
			SfxPlayer.play("can_place")
			_go(Phase.COVER)
		Phase.PAT:
			if _takeru_pats >= PATS:
				pats += 1
				SfxPlayer.play("pat")
				if pats >= PATS:
					_hold.enabled = false
					_go(Phase.END)


## 懐中電灯を消す。暗闇に目が慣れると、材料のすき間から星が見える
func _start_stars() -> void:
	_spots.visible = false
	SfxPlayer.play("flashlight_off")
	_go(Phase.STARS)


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


func _input(event: InputEvent) -> void:
	if phase in [Phase.STARS, Phase.END]:
		var tap: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_speed = UiTokens.SKIP_SPEED
			get_viewport().set_input_as_handled()
	elif phase == Phase.PICK and InputMode.keyboard and get_viewport().gui_get_focus_owner() == null \
			and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_spot_buttons[1].grab_focus()
		get_viewport().set_input_as_handled()


# --- 地図 ---------------------------------------------------------------------

## タケルが描いた地図の、バツじるしの場所（選んだ場所のとなり）
static func map_mark(chosen: int) -> int:
	return 1 if chosen != 1 else 2


## タイムカプセルの地図の絵（宝箱に出す）。基地の床と3つの場所、ずれたバツじるし
static func map_texture(chosen: int) -> Texture2D:
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(6, 10, n - 12, n - 20), Color("#EADCB8"))
	# 基地（四角）と、床の3つの場所（小さな丸）
	var ink := Color("#6B5038")
	for x in range(18, n - 18):
		img.set_pixel(x, 30, ink)
		img.set_pixel(x, 66, ink)
	for y in range(30, 67):
		img.set_pixel(18, y, ink)
		img.set_pixel(n - 19, y, ink)
	var xs := [30, 48, 66]
	for i in 3:
		for a in 16:
			var ang := TAU * a / 16.0
			img.set_pixel(int(xs[i] + cos(ang) * 4), int(56 + sin(ang) * 2), ink)
	# バツじるし（ずれている）
	var mx: int = xs[map_mark(chosen)]
	var red := Color("#9C4A1F")
	for k in range(-6, 7):
		for w in 2:
			img.set_pixel(mx + k + w, 48 + k, red)
			img.set_pixel(mx + k + w, 48 - k, red)
	return ImageTexture.create_from_image(img)


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	if phase in [Phase.STARS, Phase.DONE] and game_name == "capsule_stars":
		_draw_stars(s)
		return
	if phase == Phase.PICK:
		_draw_floor(s)
	else:
		_draw_hole(s)
	_draw_flashlight(s)


## 基地の床（真上から見た水彩の絵）。夜なので、暗い色を少し重ねる
## zoom が 1 より大きいと、選んだ場所のまわりに寄る（その場所が画面の center に来る）
func _draw_paint(s: Vector2, zoom: float, center: Vector2) -> void:
	var size2 := s * zoom
	var pos := center - Vector2(s.x * SPOTS[maxi(spot, 0)], s.y * 0.7) * zoom
	# 寄っても画面のはしにすき間が出ないように
	pos = pos.clamp(s - size2, Vector2.ZERO)
	MinigameBg.draw_cover(self, BG, Rect2(pos, size2))
	draw_rect(Rect2(Vector2.ZERO, s), FLOOR_NIGHT)


## 基地の床（3つの場所）。懐中電灯が選んでいる場所を照らす
func _draw_floor(s: Vector2) -> void:
	_draw_paint(s, 1.0, Vector2.ZERO)  # 寄らない（画面いっぱいに敷くだけ）
	# 掘れそうな場所（土がやわらかいところ。うっすら）
	for i in SPOTS.size():
		var c := Vector2(s.x * SPOTS[i], s.y * 0.7)
		_ellipse(c, s.x * 0.06, s.y * 0.03, Color(P.SOIL.darkened(0.2), 0.35))
	# タケルの持つ懐中電灯の、床に落ちる光（重ね絵の暗さは _draw_flashlight）


## 穴に寄った絵：掘るほど深くなる。缶、土、ならした跡
func _draw_hole(s: Vector2) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.55)
	_draw_paint(s, HOLE_ZOOM, c)
	var depth := float(scoops) / float(Strings.CAPSULE_DIG_LINES.size())
	var rx := s.y * 0.22
	var ry := s.y * 0.1
	# 掘った土の山（穴の右上。懐中電灯の光の中）。水彩の床になじむよう、うすい色を重ねる
	var heap := c + Vector2(rx * 0.75, -ry * 1.5)
	for k in 3:
		var o := Vector2((k - 1) * rx * 0.12 * depth, k * ry * 0.08)
		_ellipse(heap + o, rx * (0.35 - k * 0.07) * depth + 4, ry * (0.5 - k * 0.1) * depth + 2,
			Color(P.SOIL.lightened(0.04 + k * 0.06), 0.75))
	# 穴（深くなるほど暗い）。まわりにほぐれた土、内側は上のふちが影になる
	if depth > 0.0:
		var hr := 0.4 + 0.6 * depth
		_ellipse(c, rx * hr * 1.18, ry * hr * 1.3, Color(P.SOIL, 0.55))
		_ellipse(c, rx * hr, ry * hr, P.SOIL.darkened(0.2 + 0.3 * depth))
		_ellipse(c + Vector2(0, ry * hr * 0.15), rx * hr * 0.82, ry * hr * 0.75, P.SOIL.darkened(0.3 + 0.45 * depth))
	var can_in := phase in [Phase.COVER, Phase.PAT, Phase.END]
	if can_in:
		# 缶（ふたが見える）
		_ellipse(c, rx * 0.42, ry * 0.42, UiTokens.TIN_DARK)
		_ellipse(c, rx * 0.36, ry * 0.34, UiTokens.TIN)
		# 土をかぶせる（寄せるほど缶が隠れる）
		if cover > 0.0:
			_ellipse(c, rx * (0.4 + 0.6 * cover), ry * (0.4 + 0.6 * cover), Color(P.SOIL.lightened(0.05), cover))
	if phase in [Phase.PAT, Phase.END]:
		# ならした跡（たたいた手のあと）
		for k in _takeru_pats + pats:
			_ellipse(c + Vector2((k - 1.5) * rx * 0.35, 0), rx * 0.14, ry * 0.12, P.SOIL.darkened(0.08))
	if phase == Phase.PLACE:
		# 置く前の缶（手もと）
		var hand := c + Vector2(-rx * 0.6, -s.y * 0.17)
		draw_rect(Rect2(hand - Vector2(rx * 0.36, ry * 0.5), Vector2(rx * 0.72, ry * 1.4)), UiTokens.TIN)
		_ellipse(hand - Vector2(0, ry * 0.5), rx * 0.36, ry * 0.3, UiTokens.TIN_DARK)


## 懐中電灯：画面を暗くする重ね絵に、丸い穴をあける（Light2D は使わない）
func _draw_flashlight(s: Vector2) -> void:
	var r := s.y * LIGHT_RADIUS
	var center := Vector2(s.x * (_light_x if phase == Phase.PICK else 0.5), s.y * (0.7 if phase == Phase.PICK else 0.55))
	if _sad_t > 0.0 and not UiAnim.reduced():
		# さみしい一言のときだけ、光が少しゆれる
		var c := float(Time.get_ticks_msec()) / 1000.0
		center += Vector2(sin(c * 9.0), cos(c * 7.0)) * LIGHT_SHAKE * (_sad_t / 1.4)
	var far := s.length()
	var dark := Color(P.CAPSULE_NIGHT, 0.92)
	draw_arc(center, r + far * 0.5, 0, TAU, 64, dark, far)
	# ふちを少しぼかす
	for k in 4:
		draw_arc(center, r - k * 6.0, 0, TAU, 64, Color(P.CAPSULE_NIGHT, 0.18), 6.0)
	draw_circle(center, r, Color(P.LAMP_GLOW, 0.08))


## 懐中電灯を消したあと：目が慣れると、基地のすき間から星が見える
func _draw_stars(s: Vector2) -> void:
	var k := smoothstep(0.0, 1.0, clampf((_t - 0.6) / (STARS_TIME * 0.6), 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, s), P.CAPSULE_NIGHT)
	var pz := GameState.base_puzzle()
	var cell := floorf(minf(s.x * 0.7 / pz.width(), s.y * 0.6 / pz.height()))
	var origin := Vector2((s.x - pz.width() * cell) / 2.0, s.y * 0.12)
	# 基地は暗闇の中に、うっすら見えてくる
	BaseArt.draw_board(self, pz, origin, cell, true)
	draw_rect(Rect2(Vector2.ZERO, s), Color(P.CAPSULE_NIGHT, 0.9 - 0.25 * k))
	# 材料ごとのすき間から見える星（秘密基地の「夜」と同じ）
	BaseArt.draw_night(self, pz, origin, cell, k)
	# すき間のむこうの星空（少しずつ見えてくる）
	for i in 18:
		var p := Vector2(fposmod(i * 0.618, 1.0) * s.x, fposmod(i * 0.371, 1.0) * s.y * 0.1 + s.y * 0.02)
		draw_circle(p, 1.4, Color(P.STAR, 0.8 * k))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
