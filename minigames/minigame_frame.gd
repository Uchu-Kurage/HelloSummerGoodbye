class_name MinigameFrame
extends Control
## ミニゲームの共通の枠（ルート分岐表「ミニゲームの共通の決まり」）。ミニゲームの画面のいちばん上に重ねる。
## - 始める前：1行の説明と、操作の絵（キーボードなら「Space」、タッチなら「タップ」）。決定・タップで始まる
## - 右上に「もどる」（タッチのとき。キーボードは Esc）：いつでもやめられる（やめたら「ふつう」）
## - 左右の矢印（タッチのとき、arrows を出すミニゲームだけ）：左右キーのかわり
## - おわったら：「つぎへ」「もういちど」（何度やり直してもよい。記録するのは最初の1回）
## 押し続け・スワイプは使わない。

signal start_requested
signal quit_requested
signal left_pressed
signal right_pressed
signal next_requested
signal retry_requested

## 説明が出てから、この時間（ミリ秒）は押しても始めない
const INTRO_GUARD_MS := 250

var _intro: PanelContainer
var _intro_tween: Tween
var _intro_shown_at := 0
var _intro_line: Label
var _key: Label
var _key_hint: Label
var _quit: Button
var _left: Button
var _right: Button
var _result: PanelContainer
var _result_list: MenuList
var arrows := false
## 右上の「もどる」を出すか（自分の場所に「もどる」を置くミニゲームは false）
var show_quit := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	# 始める前の説明（紙のパネル。1行の説明、操作の絵、「Space で はじめる」）
	_intro = PanelContainer.new()
	_intro.theme_type_variation = &"PaperPanel"
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_intro)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_intro.add_child(v)
	_intro_line = Label.new()
	_intro_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_intro_line)
	var keyrow := HBoxContainer.new()
	keyrow.alignment = BoxContainer.ALIGNMENT_CENTER
	keyrow.add_theme_constant_override("separation", UiTokens.SPACE_S)
	v.add_child(keyrow)
	var cap := PanelContainer.new()
	cap.theme_type_variation = &"KeyCap"
	keyrow.add_child(cap)
	_key = Label.new()
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(_key)
	_key_hint = Label.new()
	_key_hint.theme_type_variation = &"SmallLabel"
	_key_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keyrow.add_child(_key_hint)
	_intro.hide()
	# おわったら：つぎへ／もういちど
	_result = PanelContainer.new()
	_result.theme_type_variation = &"PaperChip"
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_result.offset_bottom = -UiTokens.SCREEN_MARGIN
	_result.hide()
	add_child(_result)
	_result_list = MenuList.new()
	_result_list.vertical = false
	_result.add_child(_result_list)
	_add_item(Strings.MINIGAME_NEXT, func(): next_requested.emit())
	_add_item(Strings.MINIGAME_RETRY, func(): retry_requested.emit())
	# もどる（右上）と、左右の矢印（下の左右のすみ）
	_quit = _button(Strings.BACK, Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN))
	# 大きさは、テーマ（文字）が決まってからわかるので、並べ終わってから置く（大きさがかわったら置きなおす）
	_corner.call_deferred(_quit, Control.PRESET_TOP_RIGHT)
	_quit.pressed.connect(func(): quit_requested.emit())
	_left = _button(Strings.MINIGAME_LEFT, Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN * 1.25))
	_corner.call_deferred(_left, Control.PRESET_BOTTOM_LEFT)
	_left.pressed.connect(func(): left_pressed.emit())
	_right = _button(Strings.MINIGAME_RIGHT, _left.custom_minimum_size)
	_corner.call_deferred(_right, Control.PRESET_BOTTOM_RIGHT)
	_right.pressed.connect(func(): right_pressed.emit())
	InputMode.mode_changed.connect(func(_t): _refresh())
	_refresh()


## 画面のすみに置く（余白 SCREEN_MARGIN。親の大きさが変わってもすみに付いていく）
func _corner(b: Control, preset: Control.LayoutPreset) -> void:
	var right := preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
	var bottom := preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]
	b.anchor_left = 1.0 if right else 0.0
	b.anchor_right = b.anchor_left
	b.anchor_top = 1.0 if bottom else 0.0
	b.anchor_bottom = b.anchor_top
	var place := func() -> void:
		# 文字やテーマで大きくなっても、はしから SCREEN_MARGIN の内側に収める
		var sz := b.get_combined_minimum_size().max(b.size)
		var m := float(UiTokens.SCREEN_MARGIN)
		b.offset_left = -m - sz.x if right else m
		b.offset_right = b.offset_left + sz.x
		b.offset_top = -m - sz.y if bottom else m
		b.offset_bottom = b.offset_top + sz.y
	place.call()
	b.resized.connect(func(): if b.size != Vector2(b.offset_right - b.offset_left, b.offset_bottom - b.offset_top): place.call())


func _button(text: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"TouchButton"
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	UiAnim.add_press_feedback(b)
	add_child(b)
	return b


func _add_item(text: String, cb: Callable) -> void:
	var b: MenuItem = preload("res://ui/components/menu_item.tscn").instantiate()
	b.text = text
	b.pressed.connect(cb)
	_result_list.add_child(b)


## 始める前の説明を出す
func show_intro(line: String) -> void:
	_intro_line.text = line
	_refresh()
	_stop_intro_tween()
	_intro.modulate.a = 0.0
	_intro.show()
	_intro_tween = UiAnim.panel_in(_intro)
	_intro_shown_at = Time.get_ticks_msec()


func hide_intro() -> void:
	# 出ている途中（panel_in の動き）でも、必ず消えきるように前の動きを止めてから消す
	_stop_intro_tween()
	if _intro.visible:
		_intro_tween = UiAnim.panel_out(_intro)


func _stop_intro_tween() -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null


## 説明が出てから、押して始められるまでの時間がたったか（会話を送った押しで、すぐ始まらないように）
func intro_ready() -> bool:
	return intro_visible() and Time.get_ticks_msec() - _intro_shown_at >= INTRO_GUARD_MS

func intro_visible() -> bool:
	return _intro.visible and _intro.modulate.a > 0.0


## おわったら：「つぎへ」「もういちど」
func show_result() -> void:
	_result.modulate.a = 0.0
	_result.show()
	UiAnim.fade(_result, 1.0, UiTokens.TIME_PANEL)
	_result_list.activate()
	if InputMode.keyboard:
		_result_list.focus_first()


func hide_result() -> void:
	_result_list.deactivate()
	_result.hide()


func result_visible() -> bool:
	return _result.visible


func result_items() -> Array[Control]:
	return _result_list.items()


## 左右の矢印を出すか（タッチのとき）
func set_arrows(on: bool) -> void:
	arrows = on
	_refresh()


## 押せるボタン（もどる・矢印・つぎへなど）の上か（画面のどこでもタップの操作と重ねないため）
func over_button(pos: Vector2) -> bool:
	for b in [_quit, _left, _right]:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	return _result.is_visible_in_tree() and _result.get_global_rect().has_point(pos)


func _refresh() -> void:
	var touch := InputMode.touch
	_key.text = Strings.MINIGAME_KEY_TOUCH if touch else Strings.MINIGAME_KEY_SPACE
	_key_hint.text = Strings.MINIGAME_START_TOUCH if touch else Strings.MINIGAME_START_KEY
	_quit.visible = touch and show_quit
	_left.visible = touch and arrows
	_right.visible = touch and arrows
