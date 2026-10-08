class_name TreasureBox
extends Control
## 宝箱画面。お菓子の缶を開けたような見た目。day_list の全アイテムの枠を並べる。
## ゲーム中（ending_mode = false）：開いている間はゲームを止める。Tab / Esc / もどる で閉じる。
## エンディング（ending_mode = true）：ふたが開き、拾ったアイテムが1つずつ順に現れる。
## えらぶとき（pick）：手もとにあるものを1つ選ぶ。会話の @bury（タイムカプセルに入れる）で使う。
## ぜんぶ見せるとき（show_all。エピローグ「それから」の最後）：渡したアイテムを、そろった状態で並べる（影・「うめた」などは出さない）。
## 1画面に入らなければページ送りにする（「まえ」「つぎ」のボタン。キーボードは、行のはしで左右を押すと となりのページへ）。

signal closed
signal reveal_finished
## pick で選んだもの（もどったときは null）
signal picked(item: ItemData)

## 列の数は画面の幅に合わせて MIN_COLUMNS〜MAX_COLUMNS で決める
const MAX_COLUMNS := 5
const MIN_COLUMNS := 3
const VISIBLE_ROWS := 2
const DETAIL_WIDTH := 300
## ページ送りのときの、1ページの行の数のいちばん多いとき
const MAX_PAGE_ROWS := 3

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
var _cols := MAX_COLUMNS
var _title: Label
var _found := [0, 0]
## エンディングで右の欄に出す、しめくくりの一言
var ending_message := ""
var _selected: ItemSlot
var _detail_name: Label
var _detail_date: Label
var _detail_text: Label
var _back: Button
var _count: Label
var _tween: Tween
## エンディングで見出しの右に置く部品（もういちど など）
var footer: HBoxContainer
var header_caption: Label
var _pick_mode := false
var _pick_hint := ""
var _pick_result: ItemData
## show_all で並べるもの（空ならいまのルートの宝箱）
var _all: Array[ItemData] = []
var _paged := false
var page := 0
var _per_page := 0
var _pager: HBoxContainer
var _prev: Button
var _next: Button
var _page_label: Label


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
	_build_tin()
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
	# エンディングでは見出しを「なつやすみ おしまい」にし、「もういちど」を見出しの右に置く
	# （缶の外に見出しやボタンを足すと、小さい画面で縦にはみ出すため）
	_title = Label.new()
	_title.text = Strings.BOX_TITLE
	_title.theme_type_variation = &"HeadingLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_title)
	header_caption = _title
	_count = Label.new()
	_count.theme_type_variation = &"OnTinSmallLabel"
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# エンディングでは数を説明欄に出す（見出しの横幅を空けるため）
	_count.visible = not ending_mode
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
	footer = HBoxContainer.new()
	footer.visible = ending_mode
	head.add_child(footer)

	# ページ送り（show_all で、1画面に入らないとき）
	_pager = HBoxContainer.new()
	_pager.alignment = BoxContainer.ALIGNMENT_CENTER
	_pager.add_theme_constant_override("separation", UiTokens.SPACE_M)
	_pager.visible = false
	_prev = _page_button(Strings.BOX_PAGE_PREV, -1)
	_pager.add_child(_prev)
	_page_label = Label.new()
	_page_label.theme_type_variation = &"OnTinSmallLabel"
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pager.add_child(_page_label)
	_next = _page_button(Strings.BOX_PAGE_NEXT, 1)
	_pager.add_child(_next)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiTokens.SPACE_M)
	v.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", UiTokens.SPACE_S)
	body.add_child(left)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	left.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = _cols
	_grid.add_theme_constant_override("h_separation", UiTokens.TOUCH_GAP)
	_grid.add_theme_constant_override("v_separation", UiTokens.TOUCH_GAP)
	_scroll.add_child(_grid)
	left.add_child(_pager)

	var detail := PanelContainer.new()
	detail.theme_type_variation = &"TinLiner"
	detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	body.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	detail.add_child(dv)
	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"HeadingLabel"
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_detail_name)
	_detail_date = Label.new()
	_detail_date.theme_type_variation = &"SmallLabel"
	dv.add_child(_detail_date)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(DETAIL_WIDTH - UiTokens.PANEL_PADDING * 2, 0)
	dv.add_child(_detail_text)


## 渡したアイテムを、ぜんぶそろった状態で並べる（エピローグ「それから」の最後の宝箱）。1画面に入らなければページ送り
func show_all(items: Array[ItemData]) -> void:
	_all = items
	_paged = true


func _rebuild_slots() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	_selected = null
	var items := _all if not _all.is_empty() else GameState.all_items()
	var got := 0
	var total := 0
	for it in items:
		var s := ItemSlot.new()
		if not _all.is_empty():
			# ぜんぶ見せるとき：影・「うめた」「タケルにあげた」は出さない
			total += 1
			got += 1
			s.setup(it, true, "", false)
		else:
			# 人に返すもの（色えんぴつなど）は、たからものの数に入れない
			if not GameState.is_extra(it):
				total += 1
				got += 1 if GameState.is_collected(it.id) else 0
			# 手ばなしたもの（あげた・うめた）は、枠にそのひとことを出す。拾い逃したもの（その日を越えた）は影で出す
			s.setup(it, GameState.holds(it.id), GameState.gone_note(it.id), GameState.is_missed(it))
		s.pressed.connect(_on_slot_pressed.bind(s))
		s.focus_entered.connect(_on_slot_focused.bind(s))
		_grid.add_child(s)
		_slots.append(s)
	_count.text = Strings.ENDING_COUNT % [got, total]
	_found = [got, total]
	_fit_grid(items.size())
	page = 0
	_show_page()
	await get_tree().process_frame
	_link_focus()
	_show_detail(null)


## 画面の幅・高さに収まる列と行の数を決める（はみ出したぶんは縦にスクロール）
func _fit_grid(count: int) -> void:
	var vs := get_viewport_rect().size
	var cell := ItemSlot.SIZE + Vector2(UiTokens.TOUCH_GAP, UiTokens.TOUCH_GAP)
	var chrome := 2 * (UiTokens.SCREEN_MARGIN + UiTokens.PANEL_PADDING + UiTokens.TIN_RIM)
	var avail_w := vs.x - chrome - DETAIL_WIDTH - UiTokens.SPACE_M + UiTokens.TOUCH_GAP
	_cols = clampi(floori(avail_w / cell.x), MIN_COLUMNS, MAX_COLUMNS)
	_grid.columns = _cols
	var head_h := UiTokens.FONT_ENDING_TITLE * UiTokens.LINE_HEIGHT_RATIO if ending_mode else float(UiTokens.TOUCH_MIN)
	var avail_h := vs.y - chrome - head_h - UiTokens.SPACE_S + UiTokens.TOUCH_GAP
	var rows := clampi(floori(avail_h / cell.y), 1, VISIBLE_ROWS)
	if _paged:
		# ページ送りのときは、ページの数とボタンのぶんの高さをあけて、入るだけの行を見せる
		rows = clampi(floori((avail_h - UiTokens.TOUCH_MIN - UiTokens.SPACE_S) / cell.y), 1, MAX_PAGE_ROWS)
		_per_page = _cols * rows
		_pager.visible = count > _per_page
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows = mini(rows, ceili(count / float(_cols)))
	_scroll.custom_minimum_size = Vector2(_cols * cell.x - UiTokens.TOUCH_GAP, rows * cell.y - UiTokens.TOUCH_GAP)


# --- ページ送り -----------------------------------------------------------------

func _page_button(text: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"TouchButton"
	b.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN)
	# キーボードは、行のはしで左右を押してページをめくる（ボタンにはフォーカスを渡さない）
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): turn_page(step))
	UiAnim.add_press_feedback(b)
	return b


func page_count() -> int:
	if not _paged or _per_page <= 0:
		return 1
	return maxi(1, ceili(_slots.size() / float(_per_page)))


## ページをめくる（step は +1 / -1）。めくれたら true
func turn_page(step: int) -> bool:
	var p := clampi(page + step, 0, page_count() - 1)
	if p == page:
		return false
	page = p
	SfxPlayer.play("cursor")
	_show_page()
	_link_focus()
	if _selected and is_instance_valid(_selected) and not _selected.visible:
		_selected.set_selected(false)
		_selected = null
		_show_detail(null)
	return true


## いまのページの枠だけを出す
func _show_page() -> void:
	for i in _slots.size():
		_slots[i].visible = not _paged or _per_page <= 0 or i / _per_page == page
	_page_label.text = Strings.BOX_PAGE % [page + 1, page_count()]
	_prev.disabled = page <= 0
	_next.disabled = page >= page_count() - 1


## いまのページの枠
func page_slots() -> Array[ItemSlot]:
	var out: Array[ItemSlot] = []
	for s in _slots:
		if s.visible:
			out.append(s)
	return out


func _link_focus() -> void:
	var page_list := page_slots()
	var n := page_list.size()
	for i in n:
		var s := page_list[i]
		var col := i % _cols
		var left := page_list[i - 1] if col > 0 else s
		var right := page_list[i + 1] if col < _cols - 1 and i + 1 < n else s
		var up: Control = page_list[i - _cols] if i - _cols >= 0 else s
		var down := page_list[i + _cols] if i + _cols < n else s
		# 「もういちど」は見出しの右（上）にあるので、いちばん上の行から上へ移動すると届く
		var above := _footer_first()
		if i - _cols < 0 and above:
			up = above
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
	var list := page_slots()
	return list[0] if list.size() > 0 else null


func last_row_slot() -> ItemSlot:
	var list := page_slots()
	if list.is_empty():
		return null
	return list[(list.size() - 1) / _cols * _cols]


func _on_slot_pressed(s: ItemSlot) -> void:
	if _pick_mode and s.collected:
		# えらぶときは、手もとにあるものを押したらそれに決める
		SfxPlayer.play("accept")
		_pick_result = s.item
		close()
		return
	SfxPlayer.play("accept" if not _pick_mode else "cursor")
	_select(s)


## 手もとにあるものから1つ選ぶ。もどったら null
func pick(title: String, hint: String) -> ItemData:
	if is_open:
		return null
	_pick_mode = true
	_pick_hint = hint
	_pick_result = null
	_title.text = title
	open()
	return await picked


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
	if s == null and ending_mode and not _all.is_empty():
		_detail_name.text = Strings.ENDING_FOUND_TITLE
		_detail_date.text = ""
		_detail_text.text = Strings.EPILOGUE_FOUND % _found[1]
	elif s == null and ending_mode:
		_detail_name.text = Strings.ENDING_FOUND_TITLE
		if ending_message != "":
			# しめくくりの一言を本文に、集めた数は見出しの下の小さい行に
			_detail_date.text = Strings.ENDING_COUNT % [_found[0], _found[1]]
			_detail_text.text = ending_message
		else:
			_detail_date.text = ""
			_detail_text.text = Strings.ENDING_FOUND % [_found[1], _found[0]]
	elif s == null:
		_detail_name.text = _title.text
		_detail_date.text = ""
		_detail_text.text = _pick_hint if _pick_mode else Strings.BOX_HINT_SELECT
	elif not _all.is_empty():
		# ぜんぶ見せるとき：日付だけ（「7/27」。異界の日は「？？/？？」）
		_detail_name.text = s.item.display_name
		_detail_date.text = Strings.BOX_MISSED_DATE % GameState.main_item_date(s.item)
		_detail_text.text = s.item.text()
	elif s.collected or s.note != "":
		var d := GameState.day_for_item(s.item)
		var fmt := Strings.BOX_RECEIVED_ON if GameState.was_received(s.item.id) else Strings.BOX_PICKED_ON
		_detail_name.text = s.item.display_name
		_detail_date.text = s.note if s.note != "" else (fmt % GameState.item_date(d) if d else "")
		_detail_text.text = s.item.text()
	elif s.missed:
		# 拾い逃したもの：名前は「？？？」のまま、日付とだいたいの場所だけ（異界の日は「？？/？？」）
		_detail_name.text = Strings.BOX_EMPTY_NAME
		_detail_date.text = missed_hint(s.item)
		_detail_text.text = ""
	else:
		_detail_name.text = Strings.BOX_EMPTY_NAME
		_detail_date.text = ""
		_detail_text.text = Strings.BOX_EMPTY_DESC


## 影の枠に出すヒント（「7/27　かわらの どこか」）。場所のヒントがなければ日付だけ
static func missed_hint(item: ItemData) -> String:
	var d := GameState.day_for_item(item)
	var date := Strings.BOX_MISSED_DATE % GameState.item_date(d) if d else ""
	var place := item.place_hint_text()
	if place == "":
		return date
	return Strings.BOX_MISSED_HINT % [date, Strings.BOX_MISSED_PLACE % place]


# --- 開く・閉じる ----------------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	if not ending_mode:
		get_tree().paused = true
	if not _pick_mode and not ending_mode:
		_title.text = Strings.BOX_TITLE
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
	var still := UiAnim.reduced()
	if not still:
		_tween.tween_property(_lid, "position:y", _lid.position.y - 48.0, UiTokens.TIME_LID).set_delay(UiTokens.TIME_PANEL * 0.5)
		_tween.tween_property(_lid, "rotation", -0.05, UiTokens.TIME_LID).set_delay(UiTokens.TIME_PANEL * 0.5)
	_tween.tween_property(_lid, "modulate:a", 0.0, UiTokens.TIME_LID).set_delay(UiTokens.TIME_PANEL * 0.5)
	if ending_mode:
		# 1つずつ現れるのは、いま見えているページの枠だけ（ほかのページは、めくったときには並んでいる）
		for s in _slots:
			if s.shows_content() and s.visible:
				s.content.modulate.a = 0.0
		var t := UiTokens.TIME_PANEL * 0.5 + UiTokens.TIME_LID
		for s in _slots:
			if not s.shows_content() or not s.visible:
				continue
			s.content.pivot_offset = s.content.size / 2.0
			s.content.scale = Vector2.ONE if still else Vector2.ONE * UiTokens.PANEL_SCALE_FROM
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
	if _pick_mode:
		_pick_mode = false
		picked.emit(_pick_result)
	# 閉じるときは開くときより短く（ふたが下りる → 全体が消える）
	_place_lid()
	var drop := 0.0 if UiAnim.reduced() else 32.0
	_lid.position.y -= drop
	_lid.modulate.a = 0.0
	_lid.show()
	var tw := create_tween().set_parallel().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_IN)
	tw.tween_property(_lid, "position:y", _lid.position.y + drop, UiTokens.TIME_LID_OUT)
	tw.tween_property(_lid, "modulate:a", 1.0, UiTokens.TIME_LID_OUT)
	tw.tween_property(_outer, "modulate:a", 0.0, UiTokens.TIME_PANEL_OUT).set_delay(UiTokens.TIME_LID_OUT)
	tw.tween_property(_lid, "modulate:a", 0.0, UiTokens.TIME_PANEL_OUT).set_delay(UiTokens.TIME_LID_OUT)
	tw.tween_property(_shade, "modulate:a", 0.0, UiTokens.TIME_PANEL_OUT).set_delay(UiTokens.TIME_LID_OUT)
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
	# ページ送り：行のはしで左右を押すと、となりのページへ（フォーカスは同じ行のはしに）
	if _paged and page_count() > 1 and (event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left")):
		var f := get_viewport().gui_get_focus_owner()
		var list := page_slots()
		if f is ItemSlot and list.has(f):
			var i := list.find(f)
			var col := i % _cols
			var row := i / _cols
			var right := event.is_action_pressed("ui_right")
			if (right and (col == _cols - 1 or i == list.size() - 1)) or (not right and col == 0):
				if turn_page(1 if right else -1):
					var now := page_slots()
					var j := mini(row * _cols + (0 if right else _cols - 1), now.size() - 1)
					now[j].grab_focus()
					_select(now[j])
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
			# 最初の矢印キーは、InputMode がキーボードに切りかわる前にここへ届くことがあるので、ここで選んで詳細も出す
			var s: ItemSlot = _selected if _selected else first_slot()
			s.grab_focus()
			_select(s)
			get_viewport().set_input_as_handled()
