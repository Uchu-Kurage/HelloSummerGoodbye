class_name Hud
extends CanvasLayer
## ゲーム中の表示：日付の札（常に出す）、拾うときの吹き出し、拾ったときの一言、最初の歩き方の案内。

## 拾ったときに立ち止まる時間
const PICKUP_HOLD := 0.6
## 歩き方の案内を消すまでに歩く距離
const HINT_WALK_DISTANCE := 480.0

var player: Player

var _root: Control
var _card: PanelContainer
var _card_month: Label
var _card_day: Label
var _card_title: Label
var _bubble_holder: Control
var _bubble: Button
var _pickup: ItemPickup
var _msg: PanelContainer
var _msg_swatch: ColorRect
var _msg_icon: TextureRect
var _msg_name: Label
var _msg_text: Label
var _msg_mark: Label
var _msg_open := false
var _msg_t := 0.0
var _msg_done_t := 0.0
var _hint: Label
var _hint_start_x := NAN
var _hint_tween: Tween


func _ready() -> void:
	layer = 10
	add_to_group("pickup_listener")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_card()
	_build_bubble()
	_build_message()
	_build_hint()
	InputMode.mode_changed.connect(func(_t): _refresh_texts())
	_refresh_texts()


# --- 日付の札 ---------------------------------------------------------------

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.theme_type_variation = &"DateCard"
	_card.position = Vector2(UiTokens.SCREEN_MARGIN, UiTokens.SCREEN_MARGIN)
	_card.custom_minimum_size = Vector2(132, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_card.add_child(v)
	var top := PanelContainer.new()
	top.theme_type_variation = &"DateCardTop"
	v.add_child(top)
	_card_month = Label.new()
	_card_month.theme_type_variation = &"DateMonthLabel"
	_card_month.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_card_month)
	var body := PanelContainer.new()
	body.theme_type_variation = &"DateCardBody"
	v.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	body.add_child(bv)
	_card_day = Label.new()
	_card_day.theme_type_variation = &"DateDayLabel"
	_card_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_card_day)
	_card_title = Label.new()
	_card_title.theme_type_variation = &"SmallLabel"
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_card_title)


func set_day(d: DayData) -> void:
	_card_month.text = Strings.DATE_MONTH % d.month
	_card_day.text = Strings.DATE_DAY % d.day
	_card_title.text = d.title


## 札がめくれるように切り替える
func flip_to_day(d: DayData) -> void:
	_card.pivot_offset = Vector2(_card.size.x / 2.0, 0)
	var half := UiTokens.TIME_CARD_FLIP / 2.0
	var tw := create_tween().set_trans(UiTokens.TRANS)
	tw.tween_property(_card, "scale:y", 0.0, half).set_ease(Tween.EASE_IN)
	tw.tween_callback(set_day.bind(d))
	tw.tween_property(_card, "scale:y", 1.0, half).set_ease(Tween.EASE_OUT)


# --- 拾う吹き出し -------------------------------------------------------------

func _build_bubble() -> void:
	_bubble_holder = Control.new()
	_bubble_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bubble_holder)
	_bubble = Button.new()
	_bubble.theme_type_variation = &"Bubble"
	_bubble.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN, UiTokens.TOUCH_MIN)
	_bubble.focus_mode = Control.FOCUS_NONE
	_bubble.add_to_group("touch_ui")
	_bubble.pressed.connect(_pick_current)
	UiAnim.add_press_feedback(_bubble)
	_bubble_holder.add_child(_bubble)
	_bubble.hide()


func on_pickup_entered(p: ItemPickup) -> void:
	if not p.can_pick():
		return
	_pickup = p
	_refresh_texts()
	_bubble.reset_size()
	_place_bubble()
	UiAnim.float_in(_bubble, Vector2(-_bubble.size.x / 2.0, -_bubble.size.y))


func on_pickup_exited(p: ItemPickup) -> void:
	if _pickup != p:
		return
	_pickup = null
	if _bubble.visible:
		UiAnim.float_out(_bubble)


func _place_bubble() -> void:
	if _pickup == null or not is_instance_valid(_pickup):
		return
	var pos := _pickup.bubble_screen_position()
	var vs := _root.get_viewport_rect().size
	var m := UiTokens.SCREEN_MARGIN + _bubble.size.x / 2.0
	pos.x = clampf(pos.x, m, vs.x - m)
	pos.y = maxf(pos.y, UiTokens.SCREEN_MARGIN + _bubble.size.y)
	_bubble_holder.position = pos


func _pick_current() -> void:
	if _pickup == null or not is_instance_valid(_pickup) or not _pickup.can_pick():
		return
	if player and player.locked:
		return
	var item := _pickup.item
	_pickup.pick()
	SfxPlayer.play("pickup")
	if player:
		player.hold(PICKUP_HOLD)
	show_message(item)


# --- 拾ったときの一言 -----------------------------------------------------------

func _build_message() -> void:
	_msg = PanelContainer.new()
	_msg.theme_type_variation = &"PaperPanel"
	_msg.anchor_left = 0.5
	_msg.anchor_right = 0.5
	_msg.anchor_top = 1.0
	_msg.anchor_bottom = 1.0
	_msg.offset_left = -380
	_msg.offset_right = 380
	_msg.offset_bottom = -UiTokens.SCREEN_MARGIN
	_msg.offset_top = -UiTokens.SCREEN_MARGIN - 150
	_msg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_msg.mouse_filter = Control.MOUSE_FILTER_STOP
	_msg.add_to_group("touch_ui")
	_msg.gui_input.connect(_on_msg_gui_input)
	_root.add_child(_msg)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTokens.SPACE_M)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg.add_child(h)
	var icon_box := PanelContainer.new()
	icon_box.theme_type_variation = &"PaperInset"
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_box)
	_msg_swatch = ColorRect.new()
	_msg_swatch.custom_minimum_size = Vector2(56, 56)
	_msg_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_msg_swatch)
	_msg_icon = TextureRect.new()
	_msg_icon.custom_minimum_size = Vector2(56, 56)
	_msg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_msg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(_msg_icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_msg_name = Label.new()
	_msg_name.theme_type_variation = &"SmallLabel"
	v.add_child(_msg_name)
	_msg_text = Label.new()
	_msg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	v.add_child(_msg_text)
	_msg_mark = Label.new()
	_msg_mark.text = Strings.CONTINUE_MARK
	_msg_mark.theme_type_variation = &"SmallLabel"
	_msg_mark.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(_msg_mark)
	_msg.hide()


func show_message(item: ItemData) -> void:
	_msg_name.text = Strings.PICKED_FORMAT % item.display_name
	_msg_text.text = item.description
	_msg_text.visible_characters = 0
	_msg_swatch.visible = item.icon == null
	_msg_swatch.color = item.placeholder_color
	_msg_icon.visible = item.icon != null
	_msg_icon.texture = item.icon
	_msg_mark.modulate.a = 0.0
	_msg_open = true
	_msg_t = 0.0
	_msg_done_t = 0.0
	UiAnim.panel_in(_msg)


func is_message_open() -> bool:
	return _msg_open


## 1回目：全文表示 → 2回目：閉じる
func advance_message() -> void:
	if not _msg_open:
		return
	if _msg_text.visible_ratio < 1.0:
		_msg_text.visible_characters = -1
		SfxPlayer.play("accept")
	else:
		close_message()


func close_message() -> void:
	if not _msg_open:
		return
	_msg_open = false
	SfxPlayer.play("cancel")
	UiAnim.panel_out(_msg)


func _on_msg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_message()
		_msg.accept_event()


func _update_message(delta: float) -> void:
	if not _msg_open:
		return
	if _msg_text.visible_characters >= 0:
		_msg_t += delta
		var n := int(_msg_t / UiTokens.TIME_CHAR)
		var total := _msg_text.get_total_character_count()
		if n > _msg_text.visible_characters:
			_msg_text.visible_characters = mini(n, total)
			SfxPlayer.tick()
		if n >= total:
			_msg_text.visible_characters = -1
	if _msg_text.visible_characters < 0:
		if _msg_mark.modulate.a == 0.0:
			UiAnim.fade(_msg_mark, 1.0, UiTokens.TIME_SMALL)
		_msg_done_t += delta
		if _msg_done_t >= UiTokens.TIME_MESSAGE_AUTO_CLOSE:
			close_message()


# --- 最初の日の歩き方の案内 ------------------------------------------------------

func _build_hint() -> void:
	_hint = Label.new()
	_hint.theme_type_variation = &"SoftLabel"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -UiTokens.SCREEN_MARGIN - 48
	_hint.offset_bottom = -UiTokens.SCREEN_MARGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	_root.add_child(_hint)
	_hint.hide()


func show_walk_hint() -> void:
	_hint_start_x = player.global_position.x if player else 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(UiTokens.TIME_FADE * 2)
	_hint_tween.tween_callback(func(): UiAnim.fade(_hint, 1.0, UiTokens.TIME_FADE))


func _update_hint() -> void:
	if is_nan(_hint_start_x) or player == null:
		return
	if player.global_position.x - _hint_start_x > HINT_WALK_DISTANCE:
		_hint_start_x = NAN
		if _hint_tween:
			_hint_tween.kill()
		UiAnim.fade(_hint, 0.0, UiTokens.TIME_FADE)


func _refresh_texts() -> void:
	_bubble.text = Strings.PICKUP_TOUCH if InputMode.touch else Strings.PICKUP_KEY
	_hint.text = Strings.WALK_HINT_TOUCH if InputMode.touch else Strings.WALK_HINT_KEY


# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_place_bubble()
	_update_message(delta)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _msg_open and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		advance_message()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and _pickup:
		_pick_current()
		get_viewport().set_input_as_handled()
