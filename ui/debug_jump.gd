class_name DebugJump
extends CanvasLayer
## 開発用（デバッグ実行か、Web 版の URL に ?debug をつけたときだけ）：ルートと日を選んで、その日のはじめへとぶ。
## タイトルの「デバッグ」と、ひとやすみの「デバッグ」から開く。
## とぶ前に、その日までにそのルートを通ったときの状態（フラグ・拾ったもの・手ばなしたもの）を作っておく。

signal closed

const MAIN_SCENE := "res://world/main.tscn"
const DAY_COLUMNS := 5
## ルートごとの、その日を終えたときに立っているフラグ（キーは日の番号 day_number）。
## dive_ で始まるものは飛び込みの結果、katanuki_ で始まるものは型抜きの結果として記録する（GameState.set_dive_result／set_katanuki_result）。
## received はルートの中で人から「もらった」アイテム、given は手ばなしたアイテム（id -> 宝箱に出すひとこと）
const ROUTES := [
	{
		"name": "ふつう",
		"flags": {},
		"received": [],
		"given": {},
	},
	{
		"name": "タケル",
		"flags": {
			3: [&"route_takeru"],
			5: [&"takeru_d5_stall", &"katanuki_broken"],
			6: [&"takeru_d6_go"],
			7: [&"takeru_d7_jump", &"dive_perfect"],
		},
		"received": [&"river_stone", &"base_plaque", &"broken_katanuki", &"bug_cage", &"ramune_bottle", &"capsule_map"],
		"given": {3: {&"marble": "タケルに あげた"}},
	},
	{
		"name": "なつみ",
		"flags": {2: [&"route_natsumi"]},
		"received": [],
		"given": {},
	},
]

var is_open := false

var _shade: ColorRect
var _panel: PanelContainer
var _route_label: Label
var _route_items: Array[MenuItem] = []
var _day_items: Array[MenuItem] = []
var _back: Button
var _route := 0


## 使えるか：デバッグ実行のとき、または Web 版で URL に ?debug をつけたとき（ふつうに遊ぶ人には出さない）
static func available() -> bool:
	return OS.is_debug_build() or _url_has_debug()


static func _url_has_debug() -> bool:
	if not OS.has_feature("web"):
		return false
	# JavaScript の true は数の 1 で返ってくるので、1 か 0 にして比べる
	return JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('debug') ? 1 : 0", true) == 1


## そのルートで day_index の日のはじめに来たときの状態を作る（GameState はいったん空にする）
static func apply(route: int, day_index: int) -> void:
	var r: Dictionary = ROUTES[clampi(route, 0, ROUTES.size() - 1)]
	GameState.reset()
	day_index = clampi(day_index, 0, GameState.day_count() - 1)
	for i in day_index:
		var d := GameState.get_day(i)
		# その日のアイテムはルートのフラグで変わるので、前の日までのフラグを立ててから拾う
		for item in GameState.day_items(d):
			if item:
				GameState.collect(item, r.received.has(item.id))
		for f in r.flags.get(d.day_number, []):
			var s := String(f)
			if s.begins_with("dive_"):
				GameState.set_dive_result(StringName(s.trim_prefix("dive_")))
			elif s.begins_with("katanuki_"):
				GameState.set_katanuki_result(StringName(s.trim_prefix("katanuki_")))
			else:
				GameState.set_flag(f)
		var given: Dictionary = r.given.get(d.day_number, {})
		for id in given:
			var item := GameState.find_item(id)
			if item:
				GameState.give_away(item, given[id])
	GameState.start_day_index = day_index


static func jump(route: int, day_index: int) -> void:
	if Transition.is_busy():
		return
	apply(route, day_index)
	Transition.change_scene(MAIN_SCENE)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_shade = UiAnim.make_shade()
	root.add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"PaperPanel"
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_panel.add_child(v)

	var title := Label.new()
	title.text = Strings.DEBUG_TITLE
	title.theme_type_variation = &"HeadingLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_route_label = Label.new()
	_route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_route_label)
	var routes := HBoxContainer.new()
	routes.alignment = BoxContainer.ALIGNMENT_CENTER
	routes.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	v.add_child(routes)
	for i in ROUTES.size():
		var b := _make_item(ROUTES[i].name, _select_route.bind(i))
		routes.add_child(b)
		_route_items.append(b)

	var days := GridContainer.new()
	days.columns = DAY_COLUMNS
	days.add_theme_constant_override("h_separation", UiTokens.TOUCH_GAP)
	days.add_theme_constant_override("v_separation", UiTokens.TOUCH_GAP)
	v.add_child(days)
	for i in GameState.day_count():
		var b := _make_item(Strings.DEBUG_DAY % GameState.get_day(i).day_number, _on_day.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		days.add_child(b)
		_day_items.append(b)

	var hint := Label.new()
	hint.text = Strings.DEBUG_HINT
	hint.theme_type_variation = &"SmallLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	_back = Button.new()
	_back.text = Strings.BACK
	_back.theme_type_variation = &"TouchButton"
	_back.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN)
	_back.focus_mode = Control.FOCUS_NONE
	_back.anchor_left = 1.0
	_back.anchor_right = 1.0
	_back.offset_right = -UiTokens.SCREEN_MARGIN
	_back.offset_top = UiTokens.SCREEN_MARGIN
	_back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_back.pressed.connect(func(): SfxPlayer.play("cancel"); close())
	UiAnim.add_press_feedback(_back)
	root.add_child(_back)

	_link_focus()
	_select_route(0)
	InputMode.mode_changed.connect(func(_t): if is_open and InputMode.keyboard: _focus_first())
	_shade.hide()
	_panel.hide()
	_back.hide()


func _make_item(text: String, cb: Callable) -> MenuItem:
	var b: MenuItem = preload("res://ui/components/menu_item.tscn").instantiate()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size.x = UiTokens.TOUCH_MIN * 1.5
	b.pressed.connect(cb)
	return b


## 矢印キーの移動：ルートの段は左右でぐるっと回り、下で日の1段目へ。日は5列×2段
func _link_focus() -> void:
	var nr := _route_items.size()
	for i in nr:
		var b := _route_items[i]
		_link(b, "left", _route_items[(i - 1 + nr) % nr])
		_link(b, "right", _route_items[(i + 1) % nr])
		_link(b, "top", b)
		_link(b, "bottom", _day_items[mini(i, _day_items.size() - 1)])
	var n := _day_items.size()
	var rows := ceili(float(n) / DAY_COLUMNS)
	for i in n:
		var b := _day_items[i]
		var row := i / DAY_COLUMNS
		var first := row * DAY_COLUMNS
		var count := mini(DAY_COLUMNS, n - first)
		var col := i - first
		_link(b, "left", _day_items[first + (col - 1 + count) % count])
		_link(b, "right", _day_items[first + (col + 1) % count])
		var up: Control = _route_items[mini(col, nr - 1)] if row == 0 else _day_items[i - DAY_COLUMNS]
		_link(b, "top", up)
		var down := i + DAY_COLUMNS
		_link(b, "bottom", _day_items[down] if row < rows - 1 and down < n else b)
	var all: Array[Control] = []
	all.append_array(_route_items)
	all.append_array(_day_items)
	for i in all.size():
		all[i].focus_next = all[i].get_path_to(all[(i + 1) % all.size()])
		all[i].focus_previous = all[i].get_path_to(all[(i - 1 + all.size()) % all.size()])


func _link(from: Control, side: String, to: Control) -> void:
	from.set("focus_neighbor_" + side, from.get_path_to(to))


func _select_route(i: int) -> void:
	_route = i
	_route_label.text = Strings.DEBUG_ROUTE % ROUTES[i].name
	# 選んでいるルートは紙の小札にして、ほかと見分ける
	for j in _route_items.size():
		var b := _route_items[j]
		b.variation = &"ChoiceItem" if j == i else &"MenuItem"
		if b.is_node_ready():
			b._refresh()


func _on_day(i: int) -> void:
	if not is_open:
		return
	is_open = false
	jump(_route, i)


func _focus_first() -> void:
	_route_items[_route].grab_focus()


func open() -> void:
	if is_open:
		return
	is_open = true
	UiAnim.fade(_shade, 1.0, UiTokens.TIME_PANEL)
	UiAnim.fade(_back, 1.0, UiTokens.TIME_PANEL)
	UiAnim.panel_in(_panel)
	if InputMode.keyboard:
		_focus_first()


func close() -> void:
	if not is_open:
		return
	is_open = false
	var f := get_viewport().gui_get_focus_owner()
	if f and _panel.is_ancestor_of(f):
		f.release_focus()
	UiAnim.fade(_shade, 0.0, UiTokens.TIME_PANEL)
	UiAnim.fade(_back, 0.0, UiTokens.TIME_PANEL)
	UiAnim.panel_out(_panel)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		SfxPlayer.play("cancel")
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		# フォーカスがどこにもないときに矢印キーが来たら、選んでいるルートへ
		var f := get_viewport().gui_get_focus_owner()
		if f == null or not _panel.is_ancestor_of(f):
			_focus_first()
			get_viewport().set_input_as_handled()
