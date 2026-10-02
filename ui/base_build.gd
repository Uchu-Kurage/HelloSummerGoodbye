class_name BaseBuild
extends Control
## ミニゲーム「秘密基地づくり」（4日目、親友ルート）。会話の @game base_build で始まる。
## 基地に寄った画面に切り替わり、いろいろな形と材料のピース（ペントミノ式）を選んで、屋根と壁のすき間を埋める。
## 正解は1つではなく、失敗も時間制限もない。はめたピースは、ぜんぶ埋まるまで何度でも外せる。
## - タッチ／マウス：ピースをタップ → すき間をタップ（またはドラッグして落とす）。はめたピースをタップすると外れて手に戻る
## - キーボード：矢印でピース → 決定 → 矢印で場所 → 決定。R でまわす。Esc で選び直し
## 盤とピースは data/base_puzzle.tres（BasePuzzle）。記録は GameState.base_cells

signal finished

## 全部ふさいでから、画面がもどるまでの間
const FINISH_DELAY := 1.2
## しばらく手が止まったら、タケルがヒントを出すまでの秒数
const HINT_IDLE := 20.0
## トレーのピースのボタンの大きさと、中のマスの大きさ
const SLOT := Vector2(88, 88)
const SLOT_CELL := 15.0
## 5列×3行（ピース13こ。小さい画面でも、下の余白にかからない高さ）
const TRAY_COLUMNS := 5
const RAIN_STREAKS := 90

var hud: Hud
## 互換のため（HUD が入れる）。寄りの画面では使わない
var base: Node2D

var _pz: BasePuzzle
## ピースごとの状態：盤の上の位置（置いていなければ null）と回転
var _placed: Dictionary = {}
var _rot: Dictionary = {}
## 手に持っているピース（-1 なら持っていない）
var _held := -1
## 盤の上のカーソル（キーボード）と、マウス・指の下のマス
var _cursor := Vector2i.ZERO
var _hover := Vector2i(-1, -1)
var _kb_board := false
var _hint_piece := -1
var _hint_cells: Array[Vector2i] = []
var _idle := 0.0
var _said: Dictionary = {}
var _done := false
var _t := 0.0

var _line: Label
var _board: Control
var _tray: GridContainer
var _slots: Array[Button] = []
var _rotate: Button
var _return: Button
var _pause: Button
var _status: Label


func _ready() -> void:
	_pz = GameState.base_puzzle()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in _pz.pieces.size():
		_rot[i] = _pz.pieces[i].pre_rotation
	_build()
	# タケルが最初に1つはめて見せる（置き方の見本）
	for i in _pz.pieces.size():
		var p := _pz.pieces[i]
		if p.preplaced:
			_put(i, p.pre_origin)
			_said[p.material.id] = true
			say(p.material.takeru_line)
	_refresh()
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)
	InputMode.mode_changed.connect(func(_t):
		_kb_board = _board.has_focus() and InputMode.keyboard
		_refresh())
	if InputMode.keyboard:
		_focus_tray()


func _build() -> void:
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	# タケルのひとこと（会話のパネルのかわり。盤を広く見せるため小札にする）
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"PaperChip"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(chip)
	_line = Label.new()
	chip.add_child(_line)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTokens.SPACE_M)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", UiTokens.SPACE_S)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)
	_board = Control.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.focus_mode = Control.FOCUS_ALL
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_on_board_input)
	# 盤のカーソルはキーボードのときだけ（タップやクリックで盤にフォーカスが移っても出さない）
	_board.focus_entered.connect(func(): _kb_board = InputMode.keyboard; _board.queue_redraw())
	_board.focus_exited.connect(func(): _kb_board = false; _board.queue_redraw())
	_board.set_drag_forwarding(_board_drag, _board_can_drop, _board_drop)
	left.add_child(_board)
	# 盤の下：いまできることの説明（紙の小札の上）
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"PaperChip"
	bar.custom_minimum_size.y = UiTokens.TOUCH_MIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(bar)
	_status = Label.new()
	_status.theme_type_variation = &"SmallLabel"
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_status)
	# トレー（材料の山）と、その下の まわす・もどす
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", UiTokens.SPACE_S)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(right)
	var tray_panel := PanelContainer.new()
	tray_panel.theme_type_variation = &"PaperPanel"
	tray_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tray_panel.add_to_group("touch_ui")
	right.add_child(tray_panel)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	right.add_child(row)
	_rotate = _button(Strings.BASE_ROTATE, rotate_held)
	row.add_child(_rotate)
	_return = _button(Strings.BASE_RETURN, func(): _drop_held(true))
	row.add_child(_return)
	# 右上の「たからばこ」「ひとやすみ」はトレーと重なるので隠し、ひとやすみだけここに置く（タッチのときだけ）
	_pause = _button(Strings.BUTTON_PAUSE, func(): TouchControls.fire_action(&"pause"))
	row.add_child(_pause)
	get_tree().call_group("touch_controls", "set_suppressed", true)
	_tray = GridContainer.new()
	_tray.columns = TRAY_COLUMNS
	_tray.add_theme_constant_override("h_separation", UiTokens.TOUCH_GAP)
	_tray.add_theme_constant_override("v_separation", UiTokens.TOUCH_GAP)
	tray_panel.add_child(_tray)
	for i in _pz.pieces.size():
		var b := Button.new()
		b.custom_minimum_size = SLOT
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_slot_pressed.bind(i))
		b.focus_entered.connect(func(): if InputMode.keyboard: SfxPlayer.play("cursor"))
		b.set_drag_forwarding(func(_p): return _slot_drag(i), Callable(), Callable())
		UiAnim.add_press_feedback(b)
		var art := Control.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.draw.connect(_draw_slot.bind(art, i))
		b.add_child(art)
		var mark := Label.new()
		mark.name = "Mark"
		mark.text = Strings.SELECT_MARK
		mark.theme_type_variation = &"AccentMarkLabel"
		mark.position = Vector2(UiTokens.SPACE_XS, 2)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(mark)
		_tray.add_child(b)
		_slots.append(b)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"TouchButton"
	b.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	UiAnim.add_press_feedback(b)
	return b


# --- 盤の大きさ ---------------------------------------------------------------

## 1マスの大きさ（盤のわくに収まるいちばん大きな値）
func _cell() -> float:
	return floorf(minf(_board.size.x / _pz.width(), _board.size.y / _pz.height()))


func _origin() -> Vector2:
	var c := _cell()
	var s := Vector2(_pz.width(), _pz.height()) * c
	return Vector2((_board.size.x - s.x) / 2.0, (_board.size.y - s.y) / 2.0)


func _cell_at(pos: Vector2) -> Vector2i:
	var c := _cell()
	if c <= 0.0:
		return Vector2i(-1, -1)
	var p := (pos - _origin()) / c
	return Vector2i(floori(p.x), floori(p.y))


# --- 置く・外す ---------------------------------------------------------------

## ピース i を回転 rot で、盤のマス target をふくむ形で置けるところ（置けなければ null）。
## 指でぴったりのマスを押さなくてもよいよう、target をふくむ置き方を、ピースの真ん中に近いマスから順にためす
func fit(i: int, rot: int, target: Vector2i) -> Variant:
	var cells := _pz.pieces[i].cells(rot)
	var center := Vector2.ZERO
	for c in cells:
		center += Vector2(c)
	center /= cells.size()
	var order := cells.duplicate()
	order.sort_custom(func(a, b): return Vector2(a).distance_to(center) < Vector2(b).distance_to(center))
	for anchor in order:
		var origin: Vector2i = target - anchor
		if _can_place(cells, origin):
			return origin
	return null


func _can_place(cells: Array[Vector2i], origin: Vector2i) -> bool:
	var gap := ""
	for c in cells:
		var b := origin + c
		if not _pz.is_hole(b) or GameState.base_cells.has(b):
			return false
		# 1つのピースは1つのすき間の中だけ（梁や柱をまたがない）
		if gap == "":
			gap = _pz.at(b)
		elif _pz.at(b) != gap:
			return false
	return true


func _cells_at(i: int, origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _pz.pieces[i].cells(_rot[i]):
		out.append(origin + c)
	return out


func _put(i: int, origin: Vector2i) -> void:
	_placed[i] = origin
	GameState.base_place(i, _cells_at(i, origin), _pz.pieces[i].material)


## 手に持っているピースを、盤のマス target のあたりにはめる。はまったら true
func place_held(target: Vector2i) -> bool:
	if _held < 0 or _done:
		return false
	var origin = fit(_held, _rot[_held], target)
	if origin == null:
		SfxPlayer.play("cancel")
		return false
	return place_held_at(origin)


## 手に持っているピースを、左上が origin になるようにはめる
func place_held_at(origin: Vector2i) -> bool:
	if _held < 0 or _done or not _can_place(_pz.pieces[_held].cells(_rot[_held]), origin):
		return false
	var i := _held
	_held = -1
	_put(i, origin)
	_idle = 0.0
	_hint_piece = -1
	_hint_cells.clear()
	var m := _pz.pieces[i].material
	SfxPlayer.play(m.place_sfx)
	# はじめて使う材料のときだけ、タケルが一言
	if not _said.has(m.id):
		_said[m.id] = true
		say(m.takeru_line)
	_update_rain_sound()
	_refresh()
	if GameState.base_done():
		_finish()
	elif InputMode.keyboard:
		_focus_tray()
	return true


## はめたピースを外して手に持つ
func pick_up(i: int) -> void:
	if _done or not _placed.has(i):
		return
	_placed.erase(i)
	GameState.base_remove(i)
	_held = i
	SfxPlayer.play("cursor")
	_refresh()


func select(i: int) -> void:
	if _done or _placed.has(i):
		return
	if _held == i:
		_drop_held(false)
		return
	_held = i
	SfxPlayer.play("accept")
	_refresh()


## 手に持っているピースをトレーにもどす
func _drop_held(sound: bool) -> void:
	if _held < 0:
		return
	_held = -1
	if sound:
		SfxPlayer.play("cancel")
	_refresh()


func rotate_held() -> void:
	if _held < 0 or _done:
		return
	_rot[_held] = (_rot[_held] + 1) % 4
	SfxPlayer.play("cursor")
	_refresh()


func say(text: String) -> void:
	if text == "":
		return
	_line.text = Strings.SPEECH_FORMAT % [hud.speaker_name() if hud else "", text]


## 屋根がぜんぶふさがると、雨の音が「屋根をたたく雨」になる（屋根にいちばん多く使った材料の音）
func _update_rain_sound() -> void:
	var count := {}
	for c in _pz.holes():
		if not _pz.is_roof(c):
			continue
		var m := GameState.base_cell(c)
		if m == null:
			return
		count[m] = count.get(m, 0) + 1
	var best: BaseMaterial = null
	for m in count:
		if best == null or count[m] > count[best]:
			best = m
	get_tree().call_group("time_of_day", "set_rain_ambient", best.roof_rain_ambient)


func _finish() -> void:
	_done = true
	_held = -1
	_refresh()
	var f := get_viewport().gui_get_focus_owner()
	if f and is_ancestor_of(f):
		f.release_focus()
	await get_tree().create_timer(FINISH_DELAY).timeout
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


# --- ヒント（タケル） ------------------------------------------------------------

## いまの盤から最後まで埋められる、次の一手（ピース, 回転, 置き場所）。埋められなければ空
func next_move() -> Array:
	var free := {}
	for c in _pz.holes():
		if not GameState.base_cells.has(c):
			free[c] = true
	var avail: Array[int] = []
	for i in _pz.pieces.size():
		if not _placed.has(i):
			avail.append(i)
	var sol := _solve(free, avail)
	return sol if sol.size() > 0 else []


func _solve(free: Dictionary, avail: Array) -> Array:
	if free.is_empty():
		return [-1, 0, Vector2i.ZERO]
	# いちばん上・左の空きマスを、どれかのピースで埋める
	var tgt: Vector2i = free.keys()[0]
	for c in free:
		if c.y < tgt.y or (c.y == tgt.y and c.x < tgt.x):
			tgt = c
	for i in avail:
		for r in 4:
			var cells := _pz.pieces[i].cells(r)
			for anchor in cells:
				var origin: Vector2i = tgt - anchor
				var ok := true
				var gap := _pz.at(tgt)
				for c in cells:
					if not free.has(origin + c) or _pz.at(origin + c) != gap:
						ok = false
						break
				if not ok:
					continue
				var nf := free.duplicate()
				for c in cells:
					nf.erase(origin + c)
				var na := avail.duplicate()
				na.erase(i)
				if _solve(nf, na).size() > 0:
					return [i, r, origin]
	return []


func _show_hint() -> void:
	_idle = 0.0
	say(_pz.hint_line)
	var mv := next_move()
	if mv.is_empty() or mv[0] < 0:
		return
	_hint_piece = mv[0]
	_hint_cells.clear()
	for c in _pz.pieces[mv[0]].cells(mv[1]):
		_hint_cells.append(mv[2] + c)
	_refresh()


# --- 表示 ---------------------------------------------------------------------

func _refresh() -> void:
	for i in _slots.size():
		var b := _slots[i]
		# はめたピースの枠は、空けたまま残す（トレーの大きさがかわって盤が動かないように）
		var used := _placed.has(i)
		b.disabled = used
		b.focus_mode = Control.FOCUS_NONE if used else Control.FOCUS_ALL
		b.modulate.a = 0.35 if used else 1.0
		var sel := i == _held or (i == _hint_piece and _held < 0)
		b.theme_type_variation = &"ChoiceItemSelected" if sel else &"ChoiceItem"
		b.get_node("Mark").visible = i == _held
		(b.get_child(0) as Control).queue_redraw()
	_rotate.disabled = _held < 0
	_return.disabled = _held < 0
	_pause.visible = InputMode.touch
	if _done:
		_status.text = Strings.BASE_DONE
	elif _held >= 0:
		_status.text = Strings.BASE_PLACE_KEY if InputMode.keyboard else Strings.BASE_PLACE_TOUCH
	else:
		_status.text = Strings.BASE_PICK_KEY if InputMode.keyboard else Strings.BASE_PICK_TOUCH
	_board.queue_redraw()


func _draw() -> void:
	# 寄りの画面の背景：雨の空と、降る雨（動きを減らす設定では止まったすじ）
	var r := get_rect()
	draw_rect(r, WorldPalette.RAIN_SKY.darkened(0.25))
	draw_rect(Rect2(0, r.size.y * 0.78, r.size.x, r.size.y * 0.22), WorldPalette.GROUND_DARK.darkened(0.3))
	var c := Color(WorldPalette.RAIN_STREAK, 0.35)
	for i in RAIN_STREAKS:
		var x := fposmod(i * 0.6180339, 1.0) * r.size.x
		var y := fposmod(i * 0.4142135 + _t * 1.4, 1.0) * r.size.y
		draw_line(Vector2(x, y), Vector2(x - 5, y + 22), c, 2.0)


func _draw_board() -> void:
	var c := _cell()
	if c <= 0.0:
		return
	var o := _origin()
	BaseArt.draw_board(_board, _pz, o, c, false, true)
	# ヒント：はまるピースの場所をうすく光らせる
	for h in _hint_cells:
		_board.draw_rect(Rect2(o + Vector2(h) * c, Vector2(c, c)).grow(-2), Color(UiTokens.PAPER, 0.35 + 0.2 * sin(_t * 4.0)))
	# 持っているピースの影（置けるところだけ）
	if _held >= 0:
		var target := _cursor if _kb_board else _hover
		var origin = fit(_held, _rot[_held], target) if target.x >= 0 else null
		if origin != null:
			var m := _pz.pieces[_held].material
			for cell in _cells_at(_held, origin):
				var rr := Rect2(o + Vector2(cell) * c, Vector2(c, c))
				BaseArt.draw_tile(_board, m, rr, cell, 0.6)
				_board.draw_rect(rr, UiTokens.ACCENT_INK, false, 2.0)
	# キーボードのカーソル（色と印）
	if _kb_board and not _done:
		var rr := Rect2(o + Vector2(_cursor) * c, Vector2(c, c))
		_board.draw_rect(rr.grow(2), UiTokens.ACCENT_INK, false, 3.0)


## トレーのピースの絵（いまの回転で、ボタンの真ん中に）
func _draw_slot(art: Control, i: int) -> void:
	if _placed.has(i):
		return
	var p := _pz.pieces[i]
	var cells := p.cells(_rot[i])
	var mx := Vector2i.ZERO
	for c in cells:
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var s := minf(SLOT_CELL, (SLOT.x - UiTokens.SPACE_M) / float(maxi(mx.x, mx.y) + 1))
	var o := (art.size - Vector2(mx + Vector2i.ONE) * s) / 2.0
	for c in cells:
		BaseArt.draw_tile(art, p.material, Rect2(o + Vector2(c) * s, Vector2(s, s)), c)
		art.draw_rect(Rect2(o + Vector2(c) * s, Vector2(s, s)), p.material.color_2.darkened(0.25), false, 1.0)


func _process(delta: float) -> void:
	if not UiAnim.reduced():
		_t += delta
	queue_redraw()
	if _hint_cells.size() > 0 or _held >= 0:
		_board.queue_redraw()
	if not _done:
		_idle += delta
		if _idle >= HINT_IDLE:
			_show_hint()


# --- 入力 ---------------------------------------------------------------------

func _on_slot_pressed(i: int) -> void:
	select(i)
	if _held == i and InputMode.keyboard:
		_cursor = _first_open()
		_board.grab_focus()


func _on_board_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _cell_at(event.position)
		_board.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap_cell(_cell_at(event.position))
		_board.accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		rotate_held()
		_board.accept_event()


## 盤のマスをタップ：持っていれば置く。持っていなくて、はめたピースなら外して手に持つ
func _tap_cell(c: Vector2i) -> void:
	_hover = c
	if _held >= 0:
		place_held(c)
	elif GameState.base_cell_piece.has(c):
		pick_up(GameState.base_cell_piece[c])


func _first_open() -> Vector2i:
	for c in _pz.holes():
		if not GameState.base_cells.has(c):
			return c
	return Vector2i.ZERO


func _focus_tray() -> void:
	for b in _slots:
		if not b.disabled:
			b.grab_focus()
			return


# ドラッグ＆ドロップ（マウスと指。タップでも同じことができる）
func _slot_drag(i: int) -> Variant:
	if _done or _placed.has(i):
		return null
	_held = i
	_refresh()
	var preview := Label.new()
	preview.text = Strings.SELECT_MARK
	preview.theme_type_variation = &"AccentMarkLabel"
	set_drag_preview(preview)
	return {"piece": i}


func _board_drag(pos: Vector2) -> Variant:
	var c := _cell_at(pos)
	if _done or not GameState.base_cell_piece.has(c):
		return null
	var i: int = GameState.base_cell_piece[c]
	pick_up(i)
	return {"piece": i}


func _board_can_drop(pos: Vector2, data: Variant) -> bool:
	_hover = _cell_at(pos)
	_board.queue_redraw()
	return data is Dictionary and data.has("piece")


func _board_drop(pos: Vector2, data: Variant) -> void:
	_held = data["piece"]
	place_held(_cell_at(pos))


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)


func _notification(what: int) -> void:
	# ドラッグを盤の外で離したら、手に持ったままにする（タップで続きができる）
	if what == NOTIFICATION_DRAG_END:
		_refresh()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event.is_action_pressed("rotate_piece"):
		rotate_held()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and (_held >= 0 or _kb_board):
		_drop_held(true)
		_focus_tray()
		get_viewport().set_input_as_handled()
	elif _kb_board:
		var d := Vector2i.ZERO
		if event.is_action_pressed("ui_left"): d = Vector2i.LEFT
		elif event.is_action_pressed("ui_right"): d = Vector2i.RIGHT
		elif event.is_action_pressed("ui_up"): d = Vector2i.UP
		elif event.is_action_pressed("ui_down"): d = Vector2i.DOWN
		if d != Vector2i.ZERO:
			_cursor = Vector2i(clampi(_cursor.x + d.x, 0, _pz.width() - 1), clampi(_cursor.y + d.y, 0, _pz.height() - 1))
			SfxPlayer.play("cursor")
			_board.queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			_tap_cell(_cursor)
			get_viewport().set_input_as_handled()
