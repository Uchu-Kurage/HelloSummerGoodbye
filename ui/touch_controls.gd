class_name TouchControls
extends CanvasLayer
## タッチ入力。画面の左右半分の押し続けを move_left / move_right に変え、
## 右上のボタンは open_box / pause の入力アクションを発生させる。
## ゲームのコードはタッチかどうかを気にしなくて良い。

var _fingers: Array[int] = []
var _positions: Dictionary = {}
var _pressed_action := &""
var _buttons: HBoxContainer
var _shown := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	_buttons.anchor_left = 1.0
	_buttons.anchor_right = 1.0
	_buttons.offset_right = -UiTokens.SCREEN_MARGIN
	_buttons.offset_top = UiTokens.SCREEN_MARGIN
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(_buttons)
	_buttons.add_child(_make_button(Strings.BUTTON_BOX, &"open_box"))
	_buttons.add_child(_make_button(Strings.BUTTON_PAUSE, &"pause"))
	_buttons.modulate.a = 0.0
	_buttons.hide()
	InputMode.mode_changed.connect(func(_t): _refresh_buttons())
	_refresh_buttons()


func _make_button(text: String, action: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"TouchButton"
	b.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 1.5, UiTokens.TOUCH_MIN)
	b.focus_mode = Control.FOCUS_NONE
	b.add_to_group("touch_ui")
	UiAnim.add_press_feedback(b)
	b.pressed.connect(func(): fire_action(action))
	return b


## 入力アクションを1回発生させる（押して離す）
static func fire_action(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## タッチ操作のときだけ出す。ゲームが止まっている間は隠す
func _refresh_buttons() -> void:
	var want := InputMode.touch and not get_tree().paused
	if want == _shown:
		return
	_shown = want
	UiAnim.fade(_buttons, 1.0 if want else 0.0, UiTokens.TIME_SMALL)


func _is_over_ui(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("touch_ui"):
		var c := n as Control
		if c and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if get_tree().paused or _is_over_ui(event.position):
				return
			_fingers.erase(event.index)
			_fingers.append(event.index)
			_positions[event.index] = event.position
		else:
			_fingers.erase(event.index)
			_positions.erase(event.index)
		_update_walk()
	elif event is InputEventScreenDrag and _positions.has(event.index):
		_positions[event.index] = event.position
		_update_walk()


func _process(_delta: float) -> void:
	_refresh_buttons()
	if get_tree().paused and not _fingers.is_empty():
		_fingers.clear()
		_positions.clear()
		_update_walk()


## 最後に触れた指の位置で判定する
func _update_walk() -> void:
	var want := &""
	if not _fingers.is_empty():
		var pos: Vector2 = _positions[_fingers.back()]
		var w := get_viewport().get_visible_rect().size.x
		want = &"move_right" if pos.x >= w / 2.0 else &"move_left"
	if want == _pressed_action:
		return
	if _pressed_action != &"":
		Input.action_release(_pressed_action)
	_pressed_action = want
	if want != &"":
		Input.action_press(want)


func _exit_tree() -> void:
	if _pressed_action != &"":
		Input.action_release(_pressed_action)
