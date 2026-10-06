class_name Engawa
extends CanvasLayer
## 縁側の場面（DESIGN.md「5. ワールドと日の構成」、スキル「6. 操作 縁側の場面」）。
## 日の切り替わりの暗転のあと、日付の前に出る。夜の縁側の一枚絵の上で、
## おばあちゃん「きょうは、なにしたの？」→ その日に拾ったアイテムを1つ見せる → 祖父母の返事。
## 返事は res://data/engawa/*.tres（EngawaReply）から読む。選んだものや返事は記録しない。
## 異界の日（と異界に入った日）は、誰もいない縁側で蚊取り線香の煙だけを TIME_ENGAWA_EMPTY 秒見せる。
## 決定キー・タップで早送り（文字送り → 全文 → 次の行）、ui_cancel／「とばす」で場面ごととばす。
## ゲームは止める（get_tree().paused）。このノードは PROCESS_MODE_ALWAYS。

signal finished

enum Phase { IDLE, REVEAL, EMPTY, ASK, PICK, REPLY, OUTRO }

## 選択肢が出てすぐの決定は受けつけない（文字送りのつもりの連打で選ばないように。会話の選択肢と同じ）
const PICK_GUARD := 0.3
## 一言パネルの幅（基準画面での幅。小さい画面でも 1024 − 余白に収まる）
const PANEL_WIDTH := 640.0
## 祖父母の影の大きさ（画面の高さに対する割合）
const FIGURE_SCALE := 0.2
## 月のにじみを重ねる数
const MOON_GLOW_STEPS := 8
const NPC_DATA := {
	Strings.GRANDMA: "res://data/npcs/grandma.tres",
	Strings.GRANDPA: "res://data/npcs/grandpa.tres",
}

var phase := Phase.IDLE
## いまの場面に誰もいないか（異界の日）
var empty := false
## 見せたアイテム（「なんにも」なら null）と、出している返事の行
var shown_item: ItemData
var lines: Array[String] = []
var line_index := 0

var _root: Control
var _art: Control
var _panel: MessagePanel
var _row: MenuList
var _hint: PanelContainer
var _hint_label: Label
var _skip: Button
var _day: DayData
var _tween: Tween
var _t := 0.0
var _phase_t := 0.0
var _hold_t := 0.0
var _ambient_before := ""
var _was_paused := false
var _npc_cache := {}


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)

	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	_root.add_child(_art)

	# 画面端から SCREEN_MARGIN あけて、上に会話、下に見せるものの枠
	var safe := UiAnim.make_safe_area()
	_root.add_child(safe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	safe.add_child(v)
	_panel = MessagePanel.new()
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# パネルを押しても、場面全体（_root）のタップとして扱う
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	v.add_child(_panel)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	_hint = PanelContainer.new()
	_hint.theme_type_variation = &"PaperChip"
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	v.add_child(_hint)
	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"SmallLabel"
	_hint.add_child(_hint_label)
	_row = MenuList.new()
	_row.vertical = false
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.custom_minimum_size.y = ItemSlot.SIZE.y
	v.add_child(_row)

	_skip = Button.new()
	_skip.text = Strings.ENGAWA_SKIP
	_skip.theme_type_variation = &"TouchButton"
	_skip.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_right = -UiTokens.SCREEN_MARGIN
	_skip.offset_top = UiTokens.SCREEN_MARGIN
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.pressed.connect(skip)
	UiAnim.add_press_feedback(_skip)
	_root.add_child(_skip)

	InputMode.mode_changed.connect(func(_touch): _refresh_hint())
	visible = false
	_hint.hide()


## index（0 始まり）の日の終わりの縁側の場面を出し、終わるまで待つ
func play(index: int) -> void:
	_day = GameState.get_day(index)
	empty = GameState.engawa_empty(index)
	shown_item = null
	lines = []
	line_index = 0
	_t = 0.0
	_was_paused = get_tree().paused
	get_tree().paused = true
	_ambient_before = SfxPlayer.ambient_name()
	SfxPlayer.set_ambient(WorldPalette.ENGAWA_AMBIENT)
	_clear_row()
	_hint.hide()
	_panel.hide()
	visible = true
	_root.modulate.a = 0.0
	_set_phase(Phase.REVEAL)
	_tween = create_tween().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "modulate:a", 1.0, UiTokens.TIME_ENGAWA_REVEAL)
	_tween.tween_callback(func():
		_tween = null
		if empty:
			_set_phase(Phase.EMPTY)
		else:
			_begin_ask())
	await finished


func is_open() -> bool:
	return phase != Phase.IDLE


## 場面ごととばして、日付の札へ進む（ui_cancel／「とばす」）
func skip() -> void:
	if phase in [Phase.IDLE, Phase.OUTRO]:
		return
	SfxPlayer.play("cancel")
	_outro()


## その日に見せられるもの（自動の動作確認からも使う）
func slots() -> Array[ItemSlot]:
	var out: Array[ItemSlot] = []
	for c in _row.get_children():
		if c is ItemSlot:
			out.append(c)
	return out


## 枠を選んで見せる（タップ・決定キー。自動の動作確認からも使う）
func pick(slot: ItemSlot) -> void:
	if phase != Phase.PICK or _phase_t < PICK_GUARD:
		return
	shown_item = slot.item if slot.item and slot.item.id != &"" else null
	SfxPlayer.play("item_show")
	_row.deactivate()
	for s in slots():
		s.disabled = true
		UiAnim.float_out(s)
	UiAnim.float_out(_hint)
	var reply := EngawaReply.find(shown_item.id if shown_item else &"", GameState.current_route())
	lines = []
	if reply:
		lines.append_array(reply.lines)
	lines.append_array(GameState.engawa_extra_lines(_day))
	if lines.is_empty():
		_outro()
		return
	line_index = 0
	_set_phase(Phase.REPLY)
	_show_line(lines[0], shown_item)


# --- 流れ -------------------------------------------------------------------------

func _set_phase(p: Phase) -> void:
	phase = p
	_phase_t = 0.0
	_hold_t = 0.0


func _begin_ask() -> void:
	_set_phase(Phase.ASK)
	_show_line(Strings.ENGAWA_ASK, null)
	UiAnim.panel_in(_panel)


func _begin_pick() -> void:
	_set_phase(Phase.PICK)
	# 選んでいるあいだは、続きの印を出さない（会話の選択肢と同じ）
	_panel.mark.modulate.a = 0.0
	var items := GameState.engawa_items(_day)
	if items.is_empty():
		# 拾っていなければ「なんにも」だけ
		var nothing := ItemData.new()
		nothing.display_name = Strings.ENGAWA_NOTHING
		nothing.placeholder_color = Color.TRANSPARENT
		items = [nothing]
	var i := 0
	for it in items:
		var s := ItemSlot.new()
		s.setup(it, true)
		s.modulate.a = 0.0
		s.pressed.connect(pick.bind(s))
		s.focus_entered.connect(_on_slot_focus.bind(s, true))
		s.focus_exited.connect(_on_slot_focus.bind(s, false))
		_row.add_child(s)
		# 1つずつ、少し上へ浮きながら出る
		var tw := s.create_tween()
		tw.tween_interval(UiTokens.TIME_ENGAWA_ITEM_INTERVAL * i)
		tw.tween_callback(func(): _float_in(s))
		i += 1
	_refresh_hint()
	_hint.show()
	UiAnim.fade(_hint, 1.0, UiTokens.TIME_SMALL)
	_row.activate()


func _float_in(s: Control) -> void:
	var tw := s.create_tween().set_parallel().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_OUT)
	s.modulate.a = 0.0
	tw.tween_property(s, "modulate:a", 1.0, UiTokens.TIME_ENGAWA_ITEM)
	if not UiAnim.reduced():
		# コンテナの中なので位置ではなく、中身を少し下からもどす
		s.content.position.y += UiTokens.FLOAT_DISTANCE
		tw.tween_property(s.content, "position:y", s.content.position.y - UiTokens.FLOAT_DISTANCE, UiTokens.TIME_ENGAWA_ITEM)


func _on_slot_focus(s: ItemSlot, on: bool) -> void:
	s.set_selected(on and InputMode.keyboard)
	if on and InputMode.keyboard:
		SfxPlayer.play("cursor")


func _next_line() -> void:
	line_index += 1
	if line_index >= lines.size():
		_outro()
		return
	SfxPlayer.play("cursor")
	_hold_t = 0.0
	_show_line(lines[line_index], null)


## 1行を出す。「名前：せりふ」の名前で顔と色を選ぶ。item があれば、その絵を出す
func _show_line(line: String, item: ItemData) -> void:
	var speaker := ""
	var body := line
	var colon := line.find("：")
	if colon > 0 and colon <= Hud.SPEAKER_MAX:
		speaker = line.substr(0, colon)
		body = line.substr(colon + 1)
	var color := UiTokens.PAPER_DARK
	var tex: Texture2D = null
	if speaker == Strings.ME:
		color = WorldPalette.PLAYER_HAT
		tex = MessagePanel.face_of(Player.FRAMES[0])
	elif NPC_DATA.has(speaker):
		var npc := _npc(speaker)
		if npc:
			color = npc.placeholder_color
			tex = MessagePanel.face_of(npc.sprite)
	if item:
		color = item.placeholder_color
		tex = item.icon
	_panel.set_content(speaker, body, color, tex)


func _npc(speaker: String) -> NpcData:
	if not _npc_cache.has(speaker):
		_npc_cache[speaker] = load(NPC_DATA[speaker])
	return _npc_cache[speaker]


func _outro() -> void:
	_set_phase(Phase.OUTRO)
	_row.deactivate()
	if _tween:
		_tween.kill()
	if _panel.visible:
		UiAnim.panel_out(_panel)
	# 一枚絵を暗転（Transition の暗さ）へもどしてから、日付の札へ
	_tween = create_tween().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_IN)
	_tween.tween_property(_root, "modulate:a", 0.0, UiTokens.TIME_ENGAWA_REVEAL)
	_tween.tween_callback(_finish)
	SfxPlayer.set_ambient(_ambient_before)


func _finish() -> void:
	_tween = null
	_clear_row()
	visible = false
	get_tree().paused = _was_paused
	_set_phase(Phase.IDLE)
	finished.emit()


func _clear_row() -> void:
	_row.deactivate()
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()


func _refresh_hint() -> void:
	_hint_label.text = Strings.ENGAWA_PICK_TOUCH if InputMode.touch else Strings.ENGAWA_PICK_KEY


# --- 入力 ---------------------------------------------------------------------------

## 決定キー・タップ：文字送り → 全文 → 次の行。煙だけの縁側はすぐ次へ。一枚絵が明けるあいだは早送り
func advance() -> void:
	match phase:
		Phase.REVEAL, Phase.OUTRO:
			if _tween:
				_tween.set_speed_scale(UiTokens.SKIP_SPEED)
		Phase.EMPTY:
			_outro()
		Phase.ASK:
			if _panel.is_typing():
				_panel.show_all()
			else:
				_begin_pick()
		Phase.PICK:
			# キーボードは最初の枠へ（枠の上の決定は Button が受ける）
			if InputMode.keyboard:
				_row.focus_first()
		Phase.REPLY:
			if _panel.is_typing():
				_panel.show_all()
				SfxPlayer.play("accept")
			else:
				_next_line()


func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		_root.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.IDLE:
		return
	if event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if phase == Phase.PICK:
			var f := get_viewport().gui_get_focus_owner()
			if f is ItemSlot and _row.is_ancestor_of(f):
				pick(f as ItemSlot)
			else:
				advance()
		else:
			advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_t += delta
	_phase_t += delta
	_art.queue_redraw()
	match phase:
		Phase.EMPTY:
			if _phase_t >= UiTokens.TIME_ENGAWA_EMPTY:
				_outro()
		Phase.ASK:
			_panel.type_step(delta)
			# 問いかけを読み終えたら、見せるものを並べる
			if not _panel.is_typing():
				_hold_t += delta
				if _hold_t >= UiTokens.TIME_SMALL:
					_begin_pick()
		Phase.REPLY:
			_panel.type_step(delta)
			if not _panel.is_typing():
				_hold_t += delta
				if _hold_t >= UiTokens.TIME_ENGAWA_LINE_HOLD:
					_next_line()


# --- 一枚絵（仮素材：夜空・月・庭・軒と柱・板の間・祖父母の影・蚊取り線香の煙） -----------

func _draw_art() -> void:
	var w := _art.size.x
	var h := _art.size.y
	var c := _art
	# 夜空（上から下へ少し明るく）
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([WorldPalette.SEIZA_SKY_TOP, WorldPalette.SEIZA_SKY_TOP, WorldPalette.SEIZA_SKY_LOW, WorldPalette.SEIZA_SKY_LOW]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 40:
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.55)
		var tw := 1.0 if UiAnim.reduced() else 0.75 + 0.25 * sin(_t * 1.3 + i)
		c.draw_circle(p, rng.randf_range(1.0, 2.2), Color(WorldPalette.STAR, WorldPalette.STAR.a * tw))
	# 月
	var moon := Vector2(w * 0.74, h * 0.24)
	var mr := h * 0.055
	# 月のまわりのにじみ（うすい円を少しずつ重ねて、ふちが目立たないように）
	for k in MOON_GLOW_STEPS:
		c.draw_circle(moon, mr * (1.0 + 1.6 * (1.0 - float(k) / MOON_GLOW_STEPS)), WorldPalette.ENGAWA_MOON_GLOW)
	c.draw_circle(moon, mr, WorldPalette.ENGAWA_MOON)
	# 庭のしげみ（なだらかな影）
	var floor_y := h * 0.7
	var garden := PackedVector2Array([Vector2(0, floor_y)])
	for k in 13:
		var x := w * k / 12.0
		garden.append(Vector2(x, floor_y - h * (0.1 + 0.05 * sin(k * 1.7))))
	garden.append(Vector2(w, floor_y))
	c.draw_colored_polygon(garden, WorldPalette.ENGAWA_GARDEN)
	# 板の間（縁側）と板の目
	c.draw_rect(Rect2(0, floor_y, w, h - floor_y), WorldPalette.ENGAWA_FLOOR)
	c.draw_line(Vector2(0, floor_y), Vector2(w, floor_y), WorldPalette.ENGAWA_FLOOR_EDGE, 4.0)
	for k in 5:
		var y := floor_y + (h - floor_y) * (k + 1) / 6.0
		c.draw_line(Vector2(0, y), Vector2(w, y), WorldPalette.ENGAWA_FLOOR_LINE, 2.0)
	# 軒と柱
	c.draw_rect(Rect2(0, 0, w, h * 0.08), WorldPalette.SEIZA_EAVES)
	c.draw_rect(Rect2(0, h * 0.08, w, h * 0.015), WorldPalette.ENGAWA_FLOOR_LINE)
	for x in [w * 0.04, w * 0.96]:
		c.draw_rect(Rect2(x - w * 0.015, 0, w * 0.03, floor_y), WorldPalette.SEIZA_EAVES)
	# 座っている祖父母の影（異界の日は誰もいない）
	if not empty:
		_draw_figure(Vector2(w * 0.3, floor_y + h * 0.02), h * FIGURE_SCALE, false)
		_draw_figure(Vector2(w * 0.42, floor_y + h * 0.02), h * FIGURE_SCALE * 1.06, true)
	# 蚊取り線香と、ゆれる細い煙
	var kp := Vector2(w * 0.74, floor_y + h * 0.05)
	var kr := h * 0.03
	c.draw_circle(kp, kr, WorldPalette.ENGAWA_KAYARI)
	c.draw_circle(kp + Vector2(kr * 0.9, 0), kr * 0.45, WorldPalette.ENGAWA_KAYARI)
	c.draw_circle(kp + Vector2(-kr * 0.3, -kr * 0.25), kr * 0.4, WorldPalette.ENGAWA_KAYARI_DARK)
	c.draw_circle(kp + Vector2(-kr * 0.3, -kr * 0.6), 2.5, WorldPalette.ENGAWA_EMBER)
	var still := UiAnim.reduced()
	for strand in 2:
		var pts := PackedVector2Array()
		for k in 18:
			var y := kp.y - kr * 0.6 - k * h * 0.018
			var sway := 0.0 if still else sin(_t * 1.2 + k * 0.45 + strand * 1.4) * k * 1.1
			pts.append(Vector2(kp.x - kr * 0.3 + sway + strand * 6.0, y))
		c.draw_polyline(pts, WorldPalette.ENGAWA_SMOKE, 2.0, true)


## 座っている人の影（頭と、まるい背中）。grandpa は少し大きく、頭がまるい
func _draw_figure(foot: Vector2, height: float, grandpa: bool) -> void:
	var col := WorldPalette.ENGAWA_FIGURE
	var bw := height * 0.55
	var body := Rect2(foot.x - bw / 2.0, foot.y - height * 0.62, bw, height * 0.62)
	_art.draw_rect(Rect2(body.position + Vector2(0, bw * 0.3), body.size - Vector2(0, bw * 0.3)), col)
	_art.draw_circle(body.position + Vector2(bw / 2.0, bw * 0.32), bw / 2.0, col)
	var head_r := height * (0.15 if grandpa else 0.14)
	var head := Vector2(foot.x, body.position.y - head_r * 0.8)
	_art.draw_circle(head, head_r, col)
	if not grandpa:
		# おばあちゃんのおだんご
		_art.draw_circle(head + Vector2(-head_r * 0.7, -head_r * 0.6), head_r * 0.45, col)
