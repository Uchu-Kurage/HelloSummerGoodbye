class_name PauseMenu
extends CanvasLayer
## 一時停止メニュー：「つづける」「たからばこ」「タイトルへ」。

signal box_requested
signal title_requested

var is_open := false
## 宝箱を上に重ねている間 true（Esc は宝箱が受け取る）
var covered := false

var _shade: ColorRect
var _panel: PanelContainer
var _list: MenuList
var _back: Button


func _ready() -> void:
	layer = 30
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
	_panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTokens.SPACE_M)
	_panel.add_child(v)
	var title := Label.new()
	title.text = Strings.PAUSE_TITLE
	title.theme_type_variation = &"HeadingLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_list = MenuList.new()
	v.add_child(_list)
	_add_item(Strings.PAUSE_RESUME, close)
	_add_item(Strings.PAUSE_BOX, func(): box_requested.emit())
	_add_item(Strings.PAUSE_TITLE_SCREEN, func(): title_requested.emit())

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

	_shade.hide()
	_panel.hide()
	_back.hide()


func _add_item(text: String, cb: Callable) -> void:
	var b: MenuItem = preload("res://ui/components/menu_item.tscn").instantiate()
	b.text = text
	b.pressed.connect(cb)
	_list.add_child(b)


func open() -> void:
	if is_open:
		return
	is_open = true
	covered = false
	get_tree().paused = true
	UiAnim.fade(_shade, 1.0, UiTokens.TIME_PANEL)
	UiAnim.fade(_back, 1.0, UiTokens.TIME_PANEL)
	UiAnim.panel_in(_panel)
	_list.activate()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_list.deactivate()
	get_tree().paused = false
	UiAnim.fade(_shade, 0.0, UiTokens.TIME_PANEL)
	UiAnim.fade(_back, 0.0, UiTokens.TIME_PANEL)
	UiAnim.panel_out(_panel)


## 宝箱を上に開くとき：パネルだけ隠す（ゲームは止めたまま）
func cover() -> void:
	covered = true
	_list.deactivate()
	UiAnim.panel_out(_panel)
	UiAnim.fade(_back, 0.0, UiTokens.TIME_SMALL)
	UiAnim.fade(_shade, 0.0, UiTokens.TIME_PANEL)


func uncover() -> void:
	covered = false
	get_tree().paused = true
	UiAnim.fade(_shade, 1.0, UiTokens.TIME_PANEL)
	UiAnim.fade(_back, 1.0, UiTokens.TIME_PANEL)
	UiAnim.panel_in(_panel)
	_list.activate()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or covered:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		SfxPlayer.play("cancel")
		close()
		get_viewport().set_input_as_handled()
