class_name HoldInput
extends Node
## 「押しつづけて、離す」入力の部品（飛び込み、あとで作る石切りなどで使い回す）。
## キーボードは決定（Space / Enter・ui_accept）か interact、タッチ・マウスは画面のどこかを押しつづける。
## enabled のあいだだけ受けつける。押しはじめと離した瞬間を知らせる。

signal pressed
## held は押していた時間（秒。ゲームの時間）
signal released(held: float)

var enabled := false
var is_down := false
var held_time := 0.0
## 押しても「押しつづけ」に数えないボタンなど（その上のタッチ・クリックは、ボタンにまかせる）
var exclude: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT


func _process(delta: float) -> void:
	if is_down:
		held_time += delta


## 押した（自動の動作確認からも呼べる）
func press() -> void:
	if not enabled or is_down:
		return
	is_down = true
	held_time = 0.0
	pressed.emit()


func release() -> void:
	if not is_down:
		return
	is_down = false
	released.emit(held_time)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if _on_excluded(event):
		return
	var down := -1
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		down = 1
	elif event.is_action_released("ui_accept") or event.is_action_released("interact"):
		down = 0
	elif event is InputEventScreenTouch:
		down = 1 if event.pressed else 0
	# マウス（タッチから作られたマウスの入力は数えない）
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		down = 1 if event.pressed else 0
	if down == 1:
		press()
		get_viewport().set_input_as_handled()
	elif down == 0 and is_down:
		release()
		get_viewport().set_input_as_handled()


func _on_excluded(event: InputEvent) -> bool:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return false
	# 離したときは、押しはじめた場所に関係なく受けつける（押しつづけを終わらせるため）
	if not event.pressed:
		return false
	for c in exclude:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(event.position):
			return true
	return false
