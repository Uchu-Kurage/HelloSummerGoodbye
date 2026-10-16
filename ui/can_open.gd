class_name CanOpen
extends Control
## 缶を開ける画面（章「あの夏へ」の急。造成地で掘り当てたあと）。宝箱と同じ缶・紙・枠の見た目と操作。
## 1. ふたを開ける → ビー玉と、親友ルートで選んだ宝物が1つずつ出る（序の一言のまま）
## 2. 「缶の底をしらべる」→ ビニールに包まれた封筒 → 「ふうとうをひらく」
## 3. タケルの手紙（子どもの字なのでひらがな）が、一行ずつ出る。手紙には写真が1枚くるまれている（裏しか見られない）
## 4. 写真の束を日付順に1枚ずつめくる。下に日付と、老人の心の声。真っ黒な写真は（……何も写っていない。それでも、捨てられない）
## 終わったら病室へ。決定キー／タップで早送り。この画面は物語の途中なので「もどる」はない（縁側の場面と同じ）。

const NEXT_SCENE := "res://ui/hospital_finale.tscn"
const DETAIL_WIDTH := 300.0

enum Phase { LID, ITEMS, ENVELOPE, LETTER, PHOTO_BACK, BUNDLE, DONE }

var phase := Phase.LID
## 缶から出す宝物（ビー玉と、親友ルートで選んだもの。記録がなければビー玉だけ）
var can_items: Array[ItemData] = []
var bundle: Array[PhotoData] = []
var letter_lines: Array[String] = []
var letter_shown := 0
var bundle_index := 0

var _stage: CenterContainer
var _row: HBoxContainer
var _paper: PanelContainer
var _letter: Label
var _card_holder: CenterContainer
var _title: Label
var _count: Label
var _detail_name: Label
var _detail_date: Label
var _detail_text: Label
var _menu: MenuList
var _main_button: MenuItem
var _tween: Tween
var _slots: Array[ItemSlot] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SfxPlayer.set_ambient("")
	_prepare()
	var paper := ColorRect.new()
	paper.color = UiTokens.PAPER_DARK
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	var tin := PanelContainer.new()
	tin.theme_type_variation = &"TinPanel"
	center.add_child(tin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	tin.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = Label.new()
	_title.text = Strings.CAN_TITLE
	_title.theme_type_variation = &"HeadingLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = Label.new()
	_count.theme_type_variation = &"OnTinSmallLabel"
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiTokens.SPACE_M)
	v.add_child(body)
	_stage = CenterContainer.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(PhotoCard.CARD_SIZE.x * 2.0, PhotoCard.CARD_SIZE.y + 8.0)
	body.add_child(_stage)
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
	_menu = MenuList.new()
	_menu.vertical = false
	_menu.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_menu)
	_main_button = MenuItem.new()
	_main_button.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 4.0, UiTokens.TOUCH_MIN)
	_main_button.pressed.connect(advance)
	_menu.add_child(_main_button)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	_paper = PanelContainer.new()
	_paper.theme_type_variation = &"PaperPanel"
	_paper.custom_minimum_size = Vector2(PhotoCard.CARD_SIZE.x * 2.0 - 16.0, PhotoCard.CARD_SIZE.y)
	_letter = Label.new()
	# 7行までの手紙が、1024×576 の画面でも缶からはみ出さない大きさ
	_letter.theme_type_variation = &"SmallLabel"
	_letter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter.custom_minimum_size.x = PhotoCard.CARD_SIZE.x * 2.0 - 64.0
	_paper.add_child(_letter)
	_card_holder = CenterContainer.new()
	_set_stage(null)
	_show_detail("", "", "")
	_set_button(Strings.CAN_OPEN_LID)
	_menu.activate()
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_PANEL)


## 中身を決める（デバッグのジャンプなどで記録がなくても止まらないように）
func _prepare() -> void:
	var marble := GameState.find_main_item(&"marble")
	if marble:
		can_items.append(marble)
	var id := EndingRecord.capsule_item()
	if id != &"":
		var it := GameState.find_main_item(id)
		if it and not can_items.has(it):
			can_items.append(it)
	bundle = GameState.photo_bundle()
	letter_lines = Strings.LETTER_LINES.duplicate()
	if GameState.takeru_used_film():
		letter_lines.insert(Strings.LETTER_EXTRA_AFTER, Strings.LETTER_EXTRA)


func _set_button(text: String) -> void:
	_main_button.text = text
	_main_button.visible = text != ""
	if InputMode.keyboard and text != "":
		_main_button.grab_focus()


func _show_detail(name_text: String, date_text: String, body: String) -> void:
	_detail_name.text = name_text
	_detail_date.text = date_text
	_detail_text.text = body


## 左の舞台に出すものを入れかえる
func _set_stage(content: Control) -> void:
	for c in _stage.get_children():
		_stage.remove_child(c)
	if content:
		_stage.add_child(content)


func advance() -> void:
	match phase:
		Phase.LID:
			_open_lid()
		Phase.ITEMS:
			_look_bottom()
		Phase.ENVELOPE:
			_open_envelope()
		Phase.LETTER:
			if letter_shown < letter_lines.size():
				_next_letter_line()
			else:
				_after_letter()
		Phase.PHOTO_BACK:
			_start_bundle()
		Phase.BUNDLE:
			_next_photo()
		Phase.DONE:
			pass


func _open_lid() -> void:
	phase = Phase.ITEMS
	SfxPlayer.play("box_open")
	_title.text = Strings.CAN_TITLE
	_slots.clear()
	for c in _row.get_children():
		c.queue_free()
	for it in can_items:
		var s := ItemSlot.new()
		s.setup(it, true, "", false)
		s.pressed.connect(func(): _select_slot(s))
		s.focus_entered.connect(func(): if InputMode.keyboard: _select_slot(s))
		_row.add_child(s)
		_slots.append(s)
		s.modulate.a = 0.0
	_set_stage(_row)
	_set_button("")
	_show_detail(Strings.CAN_TITLE, "", "")
	var still := UiAnim.reduced()
	_tween = create_tween().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_OUT)
	for s in _slots:
		if still:
			s.modulate.a = 1.0
		else:
			_tween.tween_property(s, "modulate:a", 1.0, UiTokens.TIME_ITEM_APPEAR)
			_tween.tween_callback(SfxPlayer.play.bind("pickup"))
			_tween.tween_interval(UiTokens.TIME_ITEM_INTERVAL)
	_tween.tween_callback(func():
		_show_detail(Strings.CAN_TITLE, "", Strings.CAN_FOUND_VOICE.trim_prefix("ぼく：") + "\n" + Strings.CAN_NO_PHOTO_VOICE.trim_prefix("ぼく："))
		_set_button(Strings.CAN_LOOK_BOTTOM)
		_link_slots()
		_tween = null)


func _link_slots() -> void:
	for i in _slots.size():
		var s := _slots[i]
		s.focus_neighbor_left = s.get_path_to(_slots[maxi(i - 1, 0)])
		s.focus_neighbor_right = s.get_path_to(_slots[mini(i + 1, _slots.size() - 1)])
		s.focus_neighbor_top = s.get_path_to(s)
		s.focus_neighbor_bottom = s.get_path_to(_main_button)
	if not _slots.is_empty():
		_main_button.focus_neighbor_top = _main_button.get_path_to(_slots[0])


func _select_slot(s: ItemSlot) -> void:
	for o in _slots:
		o.set_selected(o == s)
	_show_detail(s.item.display_name, "", s.item.text())


func _look_bottom() -> void:
	phase = Phase.ENVELOPE
	SfxPlayer.play("pickup")
	_show_detail(Strings.CAN_TITLE, "", Strings.CAN_BOTTOM_VOICE.trim_prefix("ぼく：") + "")
	# 缶の中身は片づけて、封筒だけを出す
	var env := ItemData.new()
	env.id = &"chapter_envelope"
	env.display_name = Strings.CAN_ENVELOPE_NAME
	env.description = Strings.CAN_ENVELOPE_TEXT
	env.icon = preload("res://data/items/icons/chapter_envelope.png")
	env.placeholder_color = Color("#E9E2CF")
	env.on_ground = false
	_slots.clear()
	for c in _row.get_children():
		c.queue_free()
	var s := ItemSlot.new()
	s.setup(env, true, "", false)
	s.pressed.connect(func(): _select_slot(s))
	_row.add_child(s)
	_slots.append(s)
	_link_slots()
	_set_button(Strings.CAN_OPEN_ENVELOPE)


func _open_envelope() -> void:
	phase = Phase.LETTER
	letter_shown = 0
	_title.text = Strings.CAN_TITLE
	_letter.text = ""
	_set_stage(_paper)
	_show_detail("タケルの 手紙", "", "")
	_next_letter_line()


func _next_letter_line() -> void:
	letter_shown += 1
	SfxPlayer.tick()
	_letter.text = "\n".join(letter_lines.slice(0, letter_shown))
	_set_button(Strings.CAN_NEXT)


func _after_letter() -> void:
	# 手紙のあと：くるまれていた二人の写真（裏だけ）
	phase = Phase.PHOTO_BACK
	var key := GameState.photo_data(GameState.KEY_PHOTO_ID)
	_card_holder = CenterContainer.new()
	_card_holder.add_child(PhotoCard.new().setup(key, true))
	_set_stage(_card_holder)
	_show_detail(Strings.PHOTO_BACK_NAME, "", Strings.CAN_PHOTO_FOUND.trim_prefix("ぼく：") + "\n" + Strings.CAN_PHOTO_BACK_VOICE.trim_prefix("ぼく："))
	_set_button(Strings.CAN_NEXT)


func _start_bundle() -> void:
	phase = Phase.BUNDLE
	bundle_index = -1
	_next_photo()


func _next_photo() -> void:
	bundle_index += 1
	if bundle_index >= bundle.size():
		_finish()
		return
	var p := bundle[bundle_index]
	_card_holder = CenterContainer.new()
	_card_holder.add_child(PhotoCard.new().setup(p))
	_set_stage(_card_holder)
	SfxPlayer.play("pickup")
	_count.text = Strings.BUNDLE_COUNT % [bundle_index + 1, bundle.size()]
	_show_detail("", p.date_text(), p.inner_voice)
	_set_button(Strings.CAN_NEXT_PHOTO if bundle_index < bundle.size() - 1 else Strings.CAN_DONE)


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	_menu.deactivate()
	Transition.change_scene(NEXT_SCENE)


func _input(event: InputEvent) -> void:
	if phase == Phase.DONE:
		return
	# 演出中は決定キー／タップで早送り（枠が出きるのを待たない）
	if _tween and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
			or (event is InputEventScreenTouch and event.pressed)):
		_tween.set_speed_scale(UiTokens.SKIP_SPEED)
		get_viewport().set_input_as_handled()
