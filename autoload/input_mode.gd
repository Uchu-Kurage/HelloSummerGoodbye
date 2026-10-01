extends Node
## いま使われている入力が「タッチ」か「キーボード/マウス」かを覚える。
## ゲームやUIのコードは入力アクションだけを見て、表示の出し分けにだけこの値を使う。

signal mode_changed(touch: bool)

var touch := false
## キーボードで操作しているか（フォーカスの印を出すかどうか）
var keyboard := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch = DisplayServer.is_touchscreen_available() and not OS.has_feature("pc")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_apply(true, false)
	elif event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed():
			_apply(false, true)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.is_pressed():
			_apply(false, false)


func _apply(is_touch: bool, is_keyboard: bool) -> void:
	var changed := touch != is_touch or keyboard != is_keyboard
	touch = is_touch
	keyboard = is_keyboard
	if changed:
		mode_changed.emit(touch)
