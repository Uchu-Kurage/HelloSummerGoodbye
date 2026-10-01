class_name MenuList
extends BoxContainer
## MenuItem を並べ、矢印キーで迷わず移動できるようにする（端でぐるっと回る）。
## ふだんは縦並び。vertical = false で横並びにできる。
## キーボード操作が始まったら最初の項目にフォーカスする。

signal cancelled

var active := false


func _init() -> void:
	vertical = true


func _ready() -> void:
	add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	InputMode.mode_changed.connect(func(_t): if active and InputMode.keyboard: focus_first())


func items() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		if c is Control and c.visible and (c as Control).focus_mode != Control.FOCUS_NONE:
			out.append(c)
	return out


func link_focus() -> void:
	var list := items()
	for i in list.size():
		var c := list[i]
		var prev := list[(i - 1 + list.size()) % list.size()]
		var next := list[(i + 1) % list.size()]
		# 横並び（vertical = false）のときは左右で移動する
		var a := "top" if vertical else "left"
		var b := "bottom" if vertical else "right"
		var o1 := "left" if vertical else "top"
		var o2 := "right" if vertical else "bottom"
		c.set("focus_neighbor_" + a, c.get_path_to(prev))
		c.set("focus_neighbor_" + b, c.get_path_to(next))
		c.set("focus_neighbor_" + o1, c.get_path_to(c))
		c.set("focus_neighbor_" + o2, c.get_path_to(c))
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(next)


func activate() -> void:
	active = true
	link_focus()
	if InputMode.keyboard:
		focus_first()


func deactivate() -> void:
	active = false
	var f := get_viewport().gui_get_focus_owner()
	if f and is_ancestor_of(f):
		f.release_focus()


func focus_first() -> void:
	var list := items()
	if list.size() > 0:
		list[0].grab_focus()


## フォーカスがどこにもないときに矢印キーが来たら、最初の項目へ
func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") \
			or event.is_action_pressed("ui_focus_next"):
		var f := get_viewport().gui_get_focus_owner()
		if f == null or not is_ancestor_of(f):
			focus_first()
			get_viewport().set_input_as_handled()
