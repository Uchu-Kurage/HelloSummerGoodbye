class_name TreasureBox
extends Control
## 宝箱画面。お菓子の缶を開けたような見た目。day_list の全アイテムの枠を並べる。
## ゲーム中（ending_mode = false）：開いている間はゲームを止める。Tab / Esc / もどる で閉じる。
## エンディング（ending_mode = true）：ふたが開き、拾ったアイテムが1つずつ順に現れる。

signal closed
signal reveal_finished

const COLUMNS := 5
const VISIBLE_ROWS := 2
const DETAIL_WIDTH := 300

@export var ending_mode := false

var is_open := false
var _shade: ColorRect
var _center: CenterContainer
var _outer: VBoxContainer
var _tin: PanelContainer
var _lid: Panel
var _grid: GridContainer
var _scroll: ScrollContainer
var _slots: Array[ItemSlot] = []
var _selected: ItemSlot
var _detail_name: Label
var _detail_date: Label
var _detail_text: Label
var _back: Button
var _count: Label
var _tween: Tween
## エンディングで tin の下に置く部品（もういちど など）
var footer: VBoxContainer
var header_caption: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE if ending_mode else Control.MOUSE_FILTER_STOP
	if not ending_mode:
		_shade = UiAnim.make_shade()
		add_child(_shade)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_outer = VBoxContainer.new()
	_outer.alignment = BoxContainer.ALIGNMENT_CENTER
	_outer.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_center.add_child(_outer)
	header_caption = Label.new()
	header_caption.theme_type_variation = &"TitleLabel"
	header_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_caption.visible = ending_mode
	_outer.add_child(header_caption)
	_build_tin()
	footer = VBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.visible = ending_mode
	_outer.add_child(footer)
	_lid = Panel.new()
	_lid.theme_type_variation = &"TinLid"
	_lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lid)
	var lid_label := Label.new()
	lid_label.text = Strings.BOX_TITLE
	lid_label.theme_type_variation = &"HeadingLabel"
	lid_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	lid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lid_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lid.add_child(lid_label)
	visible = false


func _build_tin() -> void:
	_tin = PanelContainer.new()
	_tin.theme_type_variation = &"TinPanel"
	_outer.add_child(_tin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_tin.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTokens.SPACE_S)
	v.add_child(head)
	var title := Label.new()
	title.text = Strings.BOX_TITLE
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = Label.new()
	_count.theme_type_variation = &"SmallLabel"
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	_back = Button.new()
	_back.text = Strings.BACK
	_back.theme_type_variation = &"TouchButton"
	_back.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN)
	_back.focus_mode = Control.FOCUS_NONE
	_back.visible = not ending_mode
	_back.pressed.connect(close)
	UiAnim.add_press_feedback(_back)
	head.add_child(_back)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiTokens.SPACE_M)
	v.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", UiTokens.TOUCH_GAP)
	_grid.add_theme_constant_override("v_separation", UiTokens.TOUCH_GAP)
	_scroll.add_child(_grid)

	var detail := PanelContainer.new()
	detail.theme_type_variation = &"PaperPanel"
	detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	body.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	detail.add_child(dv)
	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"HeadingLabel"
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	dv.add_child(_detail_name)
	_detail_date = Label.new()
	_detail_date.theme_type_variation = &"SmallLabel"
	dv.add_child(_detail_date)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(DETAIL_WIDTH - UiTokens.PANEL_PADDING * 2, 0)
	dv.add_child(_detail_text)


func _rebuild_slots() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	_selected = null
	var items := GameState.all_items()
	var got := 0
	for it in items:
		var s := ItemSlot.new()
		var has := GameState.is_collected(it.id)
		got += 1 if has else 0
		s.setup(it, has)
		s.pressed.connect(_on_slot_pressed.bind(s))
		s.focus_entered.connect(_on_slot_focused.bind(s))
		_grid.add_child(s)
		_slots.append(s)
	_count.text = Strings.ENDING_COUNT % [got, items.size()]
	var rows := mini(ceili(items.size() / float(COLUMNS)), VISIBLE_ROWS)
	_scroll.custom_minimum_size = Vector2(
		COLUMNS * ItemSlot.SIZE.x + (COLUMNS - 1) * UiTokens.TOUCH_GAP,
		rows * ItemSlot.SIZE.y + (rows - 1) * UiTokens.TOUCH_GAP)
	await get_tree().process_frame
	_link_focus()
	_show_detail(null)


func _link_focus() -> void:
	var n := _slots.size()
	for i in n:
		var s := _slots[i]
		var col := i % COLUMNS
		var left := _slots[i - 1] if col > 0 else s
		var right := _slots[i + 1] if col < COLUMNS - 1 and i + 1 < n else s
		var up := _slots[i - COLUMNS] if i - COLUMNS >= 0 else s
		var down: Control = _slots[i + COLUMNS] if i + COLUMNS < n else s
		var below := _footer_first()
		if i + COLUMNS >= n and below:
			down = below
		s.focus_neighbor_left = s.get_path_to(left)
		s.focus_neighbor_right = s.get_path_to(right)
		s.focus_neighbor_top = s.get_path_to(up)
		s.focus_neighbor_bottom = s.get_path_to(down)


## footer の中で最初にフォーカスできる部品
func _footer_first(node: Node = null) -> Control:
	if node == null:
		node = footer
	for c in node.get_children():
		if c is Control and (c as Control).focus_mode != Control.FOCUS_NONE:
			return c
		var found := _footer_first(c)
		if found:
			return found
	return null


func first_slot() -> ItemSlot:
	return _slots[0] if _slots.size() > 0 else null


func last_row_slot() -> ItemSlot:
	if _slots.is_empty():
		return null
	return _slots[(_slots.size() - 1) / COLUMNS * COLUMNS]


func _on_slot_pressed(s: ItemSlot) -> void:
	SfxPlayer.play("accept")
	_select(s)


func _on_slot_focused(s: ItemSlot) -> void:
	if InputMode.keyboard:
		SfxPlayer.play("cursor")
		_select(s)


func _select(s: ItemSlot) -> void:
	if _selected and is_instance_valid(_selected):
		_selected.set_selected(false)
	_selected = s
	s.set_selected(true)
	_show_detail(s)


func _show_detail(s: ItemSlot) -> void:
	if s == null:
		_detail_name.text = Strings.BOX_TITLE
		_detail_date.text = ""
		_detail_text.text = Strings.BOX_HINT_SELECT
	elif s.collected:
		var d := GameState.day_for_item(s.item)
		_detail_name.text = s.item.display_name
		_detail_date.text = Strings.BOX_PICKED_ON % [d.month, d.day] if d else ""
		_detail_text.text = s.item.description
	else:
		_detail_name.text = Strings.BOX_EMPTY_NAME
		_detail_date.text = ""
		_detail_text.text = Strings.BOX_EMPTY_DESC


# --- 開く・閉じる ----------------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	if not ending_mode:
		get_tree().paused = true
	show()
	await _rebuild_slots()
	_place_lid()
	SfxPlayer.play("box_open")
	_tween = create_tween().set_parallel().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_OUT)
	if _shade:
		_shade.modulate.a = 0.0
		_tween.tween_property(_shade, "modulate:a", 1.0, UiTokens.TIME_PANEL)
	_outer.modulate.a = 0.0
	_tween.tween_property(_outer, "modulate:a", 1.0, UiTokens.TIME_PANEL)
	# ふたが持ち上がって、すこし傾きながら消える
	_lid.modulate.a = 1.0
	_lid.rotation = 0.0
	_tween.tween_property(_lid, "position:y", _lid.position.y - 48.0, UiTokens.TIME_LID).set_delay(UiTokens.TIME_PANEL * 0.5)
	_tween.tween_property(_lid, "rotation", -0.05, UiTokens.TIME_LID).set_delay(UiTokens.TIME_PANEL * 0.5)
	_tween.tween_property(_lid, "modulate:a", 0.0, UiTokens.TIME_LID).set_delay(UiTokens.TIME_PANEL * 0.5)
	if ending_mode:
		for s in _slots:
			if s.collected:
				s.content.modulate.a = 0.0
		var t := UiTokens.TIME_PANEL * 0.5 + UiTokens.TIME_LID
		for s in _slots:
			if not s.collected:
				continue
			s.content.pivot_offset = s.content.size / 2.0
			s.content.scale = Vector2.ONE * UiTokens.PANEL_SCALE_FROM
			_tween.tween_property(s.content, "modulate:a", 1.0, UiTokens.TIME_ITEM_APPEAR).set_delay(t)
			_tween.tween_property(s.content, "scale", Vector2.ONE, UiTokens.TIME_ITEM_APPEAR).set_delay(t)
			_tween.tween_callback(SfxPlayer.play.bind("pickup")).set_delay(t)
			t += UiTokens.TIME_ITEM_APPEAR + UiTokens.TIME_ITEM_INTERVAL
	await _tween.finished
	_tween = null
	_lid.hide()
	if InputMode.keyboard and not ending_mode and first_slot():
		first_slot().grab_focus()
	reveal_finished.emit()


func close() -> void:
	if not is_open or ending_mode:
		return
	is_open = false
	if _tween:
		_tween.kill()
		_tween = null
	SfxPlayer.play("box_close")
	var f := get_viewport().gui_get_focus_owner()
	if f and is_ancestor_of(f):
		f.release_focus()
	get_tree().paused = false
	closed.emit()
	_place_lid()
	_lid.position.y -= 48.0
	_lid.modulate.a = 0.0
	_lid.show()
	var tw := create_tween().set_parallel().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_IN)
	tw.tween_property(_lid, "position:y", _lid.position.y + 48.0, UiTokens.TIME_LID * 0.6)
	tw.tween_property(_lid, "modulate:a", 1.0, UiTokens.TIME_LID * 0.6)
	tw.tween_property(_outer, "modulate:a", 0.0, UiTokens.TIME_PANEL).set_delay(UiTokens.TIME_LID * 0.6)
	tw.tween_property(_lid, "modulate:a", 0.0, UiTokens.TIME_PANEL).set_delay(UiTokens.TIME_LID * 0.6)
	tw.tween_property(_shade, "modulate:a", 0.0, UiTokens.TIME_PANEL).set_delay(UiTokens.TIME_LID * 0.6)
	await tw.finished
	if not is_open:
		hide()


func _place_lid() -> void:
	_lid.show()
	_lid.position = _tin.global_position - global_position
	_lid.size = _tin.size
	_lid.pivot_offset = Vector2(_lid.size.x / 2.0, _lid.size.y)


func _input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree():
		return
	# 演出中は決定キー／タップで早送り
	if _tween and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
			or (event is InputEventScreenTouch and event.pressed)):
		_tween.set_speed_scale(UiTokens.SKIP_SPEED)
		get_viewport().set_input_as_handled()
		return
	if ending_mode:
		return
	# Tab は GUI のフォーカス移動に取られないよう _input で受ける
	if event.is_action_pressed("open_box") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		SfxPlayer.play("cancel")
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var f := get_viewport().gui_get_focus_owner()
		if (f == null or not is_ancestor_of(f)) and first_slot():
			(_selected if _selected else first_slot()).grab_focus()
			get_viewport().set_input_as_handled()
