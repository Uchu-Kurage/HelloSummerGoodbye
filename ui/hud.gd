class_name Hud
extends CanvasLayer
## ゲーム中の表示：日付の札（常に出す）、拾うときの吹き出し、拾ったときの一言、最初の歩き方の案内。

## 一言パネルの左端（画面の幅に対する割合）
const MESSAGE_LEFT := 0.44
## 会話のときは、話している人を隠さないよう画面の上（空）に出す。左右の端（画面の幅に対する割合）
## 左の日付の札と、右上のタッチ用ボタンのあいだに収まる幅
const TALK_LEFT := 0.2
const TALK_RIGHT := 0.72
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
## 範囲に入っている、話しかけられる／拾えるもの
var _near: Array[Interactable] = []
## 吹き出しを出している相手（いちばん近いもの）
var _target: Interactable
## 会話中のせりふ
var _talk_lines: Array[String] = []
var _talk_index := 0
var _talk_data: NpcData
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
	add_to_group("interact_listener")
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
	# 日めくりのとじ穴
	var holes := Control.new()
	holes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holes.draw.connect(func():
		var r := UiTokens.CARD_HOLE
		for x in [holes.size.x * 0.14, holes.size.x * 0.86]:
			holes.draw_circle(Vector2(x, r + 4), r, UiTokens.INK_SOFT))
	top.add_child(holes)
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
	_card_title.text = GameState.day_title(d)


## 札がめくれるように切り替える
func flip_to_day(d: DayData) -> void:
	_card.pivot_offset = Vector2(_card.size.x / 2.0, 0)
	var half := UiTokens.TIME_CARD_FLIP / 2.0
	# 動きを減らす設定のときはめくらずに、文字を入れかえるだけ（フェード）
	var prop := "modulate:a" if UiAnim.reduced() else "scale:y"
	var tw := create_tween().set_trans(UiTokens.TRANS)
	tw.tween_property(_card, prop, 0.0, half).set_ease(Tween.EASE_IN)
	tw.tween_callback(set_day.bind(d))
	tw.tween_property(_card, prop, 1.0, half).set_ease(Tween.EASE_OUT)


# --- 拾う／はなす吹き出し ------------------------------------------------------

func _build_bubble() -> void:
	_bubble_holder = Control.new()
	_bubble_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bubble_holder)
	_bubble = Button.new()
	_bubble.theme_type_variation = &"Bubble"
	_bubble.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN, UiTokens.TOUCH_MIN)
	_bubble.focus_mode = Control.FOCUS_NONE
	_bubble.add_to_group("touch_ui")
	_bubble.pressed.connect(_interact_current)
	UiAnim.add_press_feedback(_bubble)
	_bubble_holder.add_child(_bubble)
	_bubble.hide()


func on_interactable_entered(it: Interactable) -> void:
	if not _near.has(it):
		_near.append(it)
	_update_target()


func on_interactable_exited(it: Interactable) -> void:
	_near.erase(it)
	_update_target()


func current_target() -> Interactable:
	return _target


## 範囲に入っているもののうち、いちばん近いものに吹き出しを出す
func _update_target() -> void:
	var best: Interactable = null
	var best_d := INF
	# 一言パネルを出している間（会話中も）は吹き出しを出さない
	for it in ([] if _msg_open else _near.duplicate()):
		if not is_instance_valid(it) or not it.can_interact():
			_near.erase(it)
			continue
		var d := absf(it.global_position.x - player.global_position.x) if player else 0.0
		if d < best_d:
			best_d = d
			best = it
	if best == _target:
		return
	var had := _target != null
	_target = best
	if _target == null:
		if _bubble.visible:
			UiAnim.float_out(_bubble)
		return
	_refresh_texts()
	_bubble.reset_size()
	_place_bubble()
	if not had or not _bubble.visible:
		UiAnim.float_in(_bubble, Vector2(-_bubble.size.x / 2.0, -_bubble.size.y))
	else:
		_bubble.position = Vector2(-_bubble.size.x / 2.0, -_bubble.size.y)


func _place_bubble() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var pos := _target.bubble_screen_position()
	var vs := _root.get_viewport_rect().size
	var m := UiTokens.SCREEN_MARGIN + _bubble.size.x / 2.0
	pos.x = clampf(pos.x, m, vs.x - m)
	pos.y = maxf(pos.y, UiTokens.SCREEN_MARGIN + _bubble.size.y)
	_bubble_holder.position = pos


func _interact_current() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.can_interact():
		return
	if _msg_open or (player and (player.locked or player.talking)):
		return
	_target.interact(self)


# --- 一言パネル（拾ったときの一言・会話） -------------------------------------------

func _build_message() -> void:
	_msg = PanelContainer.new()
	_msg.theme_type_variation = &"PaperPanel"
	_place_message(false)
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
	_msg_text.custom_minimum_size.y = UiTokens.FONT_BODY * UiTokens.LINE_HEIGHT_RATIO * 2
	_msg_text.draw.connect(_draw_ruled_lines)
	v.add_child(_msg_text)
	_msg_mark = Label.new()
	_msg_mark.text = Strings.CONTINUE_MARK
	_msg_mark.theme_type_variation = &"SmallLabel"
	_msg_mark.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(_msg_mark)
	_msg.hide()


## ノートの罫線。文字の行にそろえて引く
func _draw_ruled_lines() -> void:
	# 実際の行の高さ（文字の高さ＋行間）にそろえ、文字のすぐ下に線を引く
	var font_h := float(_msg_text.get_line_height())
	var spacing := float(_msg_text.get_theme_constant("line_spacing"))
	var lh := font_h + spacing
	var n := maxi(1, floori((_msg_text.size.y + spacing) / lh))
	for i in n:
		var y := roundf(i * lh + font_h + spacing * 0.25)
		_msg_text.draw_line(Vector2(0, y), Vector2(_msg_text.size.x, y), UiTokens.PAPER_DARK, 2.0)


## アイテムを拾ったときの一言
func show_item_message(item: ItemData) -> void:
	_talk_data = null
	_open_message(Strings.PICKED_FORMAT % item.display_name, item.description, item.placeholder_color, item.icon)


## NPC との会話を始める。せりふを1つずつ送り、最後まで読むと閉じる。会話の間は立ち止まる
func start_talk(data: NpcData, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_talk_data = data
	_talk_lines = lines
	_talk_index = 0
	if player:
		player.talking = true
	SfxPlayer.play("accept")
	_open_message(data.display_name, lines[0], data.placeholder_color, null)


func is_talking() -> bool:
	return _talk_data != null


## 一言パネルの位置。拾ったときは右下（左寄りのプレイヤーを隠さない）、
## 会話のときは画面の上（話している人を隠さない）
func _place_message(talk: bool) -> void:
	if talk:
		_msg.anchor_left = TALK_LEFT
		_msg.anchor_right = TALK_RIGHT
		_msg.anchor_top = 0.0
		_msg.anchor_bottom = 0.0
		_msg.offset_top = UiTokens.SCREEN_MARGIN
		_msg.offset_bottom = UiTokens.SCREEN_MARGIN + 150
		_msg.offset_right = 0
		_msg.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_msg.anchor_left = MESSAGE_LEFT
		_msg.anchor_right = 1.0
		_msg.anchor_top = 1.0
		_msg.anchor_bottom = 1.0
		_msg.offset_top = -UiTokens.SCREEN_MARGIN - 150
		_msg.offset_bottom = -UiTokens.SCREEN_MARGIN
		_msg.offset_right = -UiTokens.SCREEN_MARGIN
		_msg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_msg.offset_left = 0


func _open_message(title: String, body: String, swatch: Color, icon: Texture2D) -> void:
	var was_open := _msg_open
	if not was_open:
		_place_message(is_talking())
	_msg_name.text = title
	_set_body(body)
	_msg_swatch.visible = icon == null
	_msg_swatch.color = swatch
	_msg_icon.visible = icon != null
	_msg_icon.texture = icon
	_msg_open = true
	if not was_open:
		UiAnim.panel_in(_msg)


func _set_body(body: String) -> void:
	_msg_text.text = body
	_msg_text.visible_characters = 0
	_msg_mark.modulate.a = 0.0
	_msg_t = 0.0
	_msg_done_t = 0.0


func is_message_open() -> bool:
	return _msg_open


## 1回目：全文表示 → 2回目：次のせりふ（なければ閉じる）
func advance_message() -> void:
	if not _msg_open:
		return
	if _msg_text.visible_characters >= 0:
		_msg_text.visible_characters = -1
		SfxPlayer.play("accept")
	elif is_talking() and _talk_index + 1 < _talk_lines.size():
		_talk_index += 1
		SfxPlayer.play("cursor")
		_set_body(_talk_lines[_talk_index])
	else:
		close_message()


func close_message() -> void:
	if not _msg_open:
		return
	_msg_open = false
	if is_talking():
		# 話し終えたらフラグを立てる（エンディングの分岐など）
		for f in _talk_data.set_flags:
			GameState.set_flag(f)
		_talk_data = null
		_talk_lines = []
		if player:
			player.talking = false
	SfxPlayer.play("cancel")
	UiAnim.panel_out(_msg)
	_update_target()


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
		# 会話は読み終えるまで待つ（自動で閉じるのは拾ったときの一言だけ）
		if not is_talking() and _msg_done_t >= UiTokens.TIME_MESSAGE_AUTO_CLOSE:
			close_message()


# --- 最初の日の歩き方の案内 ------------------------------------------------------

func _build_hint() -> void:
	_hint = Label.new()
	# 道の上に出るので INK_SOFT ではなく本文の色（コントラスト確保）
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
	if _target and is_instance_valid(_target):
		_bubble.text = _target.bubble_text(InputMode.touch)
	_hint.text = Strings.WALK_HINT_TOUCH if InputMode.touch else Strings.WALK_HINT_KEY


# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_target()
	_place_bubble()
	_update_message(delta)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _msg_open and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		advance_message()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and _target:
		_interact_current()
		get_viewport().set_input_as_handled()
