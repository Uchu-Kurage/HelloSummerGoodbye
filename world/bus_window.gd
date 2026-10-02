class_name BusWindow
extends Interactable
## バスの窓。BusDeparture が「あけられる」ようにすると、吹き出し（E／まどを あける）が出る。

signal opened

var enabled := false


func can_interact() -> bool:
	return enabled


func works_while_locked() -> bool:
	return true


func bubble_text(touch: bool) -> String:
	return Strings.WINDOW_TOUCH if touch else Strings.WINDOW_KEY


## 吹き出しを出す（プレイヤーはバスの中なので、範囲の出入りではなく直接 HUD に知らせる）
func enable() -> void:
	enabled = true
	get_tree().call_group("interact_listener", "on_interactable_entered", self)


func interact(_hud: Node) -> void:
	if not enabled:
		return
	enabled = false
	SfxPlayer.play("accept")
	notify_left()
	opened.emit()
