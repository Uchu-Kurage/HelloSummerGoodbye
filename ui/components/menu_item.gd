class_name MenuItem
extends Button
## メニューの項目。キーボードで選んでいるときだけ ACCENT の色と「●」の印を出す。
## タッチでは押した瞬間に決定する（Button の pressed）。

var _mark: Label


func _ready() -> void:
	theme_type_variation = &"MenuItem"
	custom_minimum_size.y = UiTokens.TOUCH_MIN
	focus_mode = Control.FOCUS_ALL
	_mark = Label.new()
	_mark.text = Strings.SELECT_MARK
	_mark.theme_type_variation = &"AccentMarkLabel"
	_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_mark.position.x = UiTokens.SPACE_XS
	_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mark)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_refresh)
	InputMode.mode_changed.connect(func(_t): _refresh())
	pressed.connect(func(): SfxPlayer.play("accept"))
	UiAnim.add_press_feedback(self)
	_refresh()


func _on_focus_entered() -> void:
	if InputMode.keyboard:
		SfxPlayer.play("cursor")
	_refresh()


func _refresh() -> void:
	var marked := has_focus() and InputMode.keyboard
	theme_type_variation = &"MenuItemSelected" if marked else &"MenuItem"
	_mark.visible = marked
