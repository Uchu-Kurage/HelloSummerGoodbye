extends CanvasLayer
## 縦向きのときにゲームを止めて「よこむきにしてね」と出す（オートロード RotateNotice）。
## 判定は画面の縦横比で行う。横向きに戻すと続きから遊べる。

var _root: Control
var _showing := false
var _was_paused := false


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = PanelContainer.new()
	_root.theme_type_variation = &"PaperPanel"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UiTokens.SPACE_M)
	_root.add_child(box)
	var title := Label.new()
	title.text = Strings.ROTATE_NOTICE
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = Strings.ROTATE_SUB
	sub.theme_type_variation = &"HeadingLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	_root.hide()
	get_tree().root.size_changed.connect(_check)
	_check()


func _check() -> void:
	var s := get_tree().root.size
	var portrait := s.y > s.x
	if portrait == _showing:
		return
	_showing = portrait
	if portrait:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_root.modulate.a = 0.0
		UiAnim.fade(_root, 1.0, UiTokens.TIME_FADE)
	else:
		get_tree().paused = _was_paused
		UiAnim.fade(_root, 0.0, UiTokens.TIME_FADE)
