class_name NatsumiScreen
extends Control
## 初恋ルート（なつみ）と神隠しルート（お面の子）の専用画面の共通の土台。会話の @game で始まり、終わったら finished で会話の続きへもどる。
## ミニゲーム（スケッチ・金魚すくい・貝がら拾い・線香花火）と、映画会・絵を広げる場面が継承する。
## - 上に、なつみのひとことの小札（PaperChip）。下に、いまの操作の案内の小札（SmallLabel）
## - 画面のどこを押してもよいので、右上のボタン（宝箱・ひとやすみ）は隠す
## - 結果の演出は、決定キー／タップで早送り（speed を UiTokens.SKIP_SPEED にする）
## 継承した画面は _build() で部品を足し、_process で進める。

signal finished

var hud: Hud
var game_name := ""
## 演出の速さ。早送りのときは UiTokens.SKIP_SPEED
var speed := 1.0
var done := false
## 案内の小札の上に置く部品（選択肢の列など）を入れる箱
var bottom: VBoxContainer
var _chip: PanelContainer
var _line: Label
var _hint_chip: PanelContainer
var _hint: Label
var _hint_touch := ""
var _hint_key := ""
var _prev_ambient := ""
var _ambient_changed := false


func _ready() -> void:
	# 人物の絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	safe.add_child(v)
	# なつみのひとこと（小札）
	_chip = PanelContainer.new()
	_chip.theme_type_variation = &"PaperChip"
	_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_chip)
	_line = Label.new()
	_chip.add_child(_line)
	_chip.modulate.a = 0.0
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	bottom = VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bottom)
	# いまの操作の案内（控えめに、下の小札）
	_hint_chip = PanelContainer.new()
	_hint_chip.theme_type_variation = &"PaperChip"
	_hint_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_hint_chip)
	_hint = Label.new()
	_hint.theme_type_variation = &"SmallLabel"
	_hint_chip.add_child(_hint)
	_hint_chip.modulate.a = 0.0
	InputMode.mode_changed.connect(_refresh_hint.unbind(1))
	get_tree().call_group("touch_controls", "set_suppressed", true)
	_prev_ambient = SfxPlayer._ambient_name
	_build()
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)


## 継承した画面の部品を作る
func _build() -> void:
	pass


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)
	if _ambient_changed:
		SfxPlayer.set_ambient(_prev_ambient)


## この画面のあいだだけ環境音をかえる（閉じたらもどす）
func set_ambient(ambient_name: String) -> void:
	_ambient_changed = true
	SfxPlayer.set_ambient(ambient_name)


## 上の小札に、ひとことを出す。speaker が空なら、いま話している人（なつみ）
func say(text: String, speaker := "") -> void:
	if speaker == "":
		speaker = hud.speaker_name() if hud else ""
	_line.text = Strings.SPEECH_FORMAT % [speaker, text]
	_show_chip()


## 上の小札に、せりふでない文（映画の音など）を出す
func caption(text: String) -> void:
	_line.text = text
	_show_chip()


func _show_chip() -> void:
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func hush() -> void:
	if _chip.modulate.a > 0.0:
		UiAnim.fade(_chip, 0.0, UiTokens.TIME_SMALL_OUT)


## 下の小札に、いまの操作の案内を出す（タッチ用とキーボード用）
func show_hint(touch_text: String, key_text: String) -> void:
	_hint_touch = touch_text
	_hint_key = key_text
	_refresh_hint()
	if _hint_chip.modulate.a < 1.0:
		UiAnim.fade(_hint_chip, 1.0, UiTokens.TIME_SMALL)


func hide_hint() -> void:
	if _hint_chip.modulate.a > 0.0:
		UiAnim.fade(_hint_chip, 0.0, UiTokens.TIME_SMALL_OUT)


func hint_text() -> String:
	return _hint.text


func _refresh_hint() -> void:
	_hint.text = _hint_touch if InputMode.touch else _hint_key


## おわる：フェードして finished
func finish() -> void:
	if done:
		return
	done = true
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


## 絵の動き（動きを減らす設定では止める）
func clock() -> float:
	return 0.0 if UiAnim.reduced() else float(Time.get_ticks_msec()) / 1000.0


## 決定キー・interact・タップ（早送りや、画面のどこでも押せる操作に使う）
static func is_tap(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION)


# --- 選択肢（紙の小札の枠。中に絵を描く） --------------------------------------

## 選択肢の枠を1つ作る。art(art_control, index) で中の絵を描く
func make_choice(index: int, box_size: Vector2, art: Callable, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = box_size
	b.theme_type_variation = &"ChoiceItem"
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_pressed.bind(index))
	UiAnim.add_press_feedback(b)
	var a := Control.new()
	a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.draw.connect(func(): art.call(a, index))
	b.add_child(a)
	var mark := Label.new()
	mark.name = "Mark"
	mark.text = Strings.SELECT_MARK
	mark.theme_type_variation = &"AccentMarkLabel"
	mark.position = Vector2(UiTokens.SPACE_XS, 2)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.visible = false
	b.add_child(mark)
	b.focus_entered.connect(func():
		if InputMode.keyboard:
			SfxPlayer.play("cursor")
		refresh_choices(b.get_parent()))
	b.focus_exited.connect(func(): refresh_choices(b.get_parent()))
	return b


## 横に並べた選択肢を、左右でぐるっと回れるようにつなぐ
static func link_row(buttons: Array) -> void:
	var n := buttons.size()
	for i in n:
		var b: Button = buttons[i]
		b.focus_neighbor_left = b.get_path_to(buttons[(i + n - 1) % n])
		b.focus_neighbor_right = b.get_path_to(buttons[(i + 1) % n])
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = b.get_path()


## キーボードで選んでいる枠だけ、ACCENT_INK の枠と「●」にする
func refresh_choices(row: Node) -> void:
	if row == null:
		return
	for c in row.get_children():
		if not c is Button:
			continue
		var b := c as Button
		var sel := b.has_focus() and InputMode.keyboard
		b.theme_type_variation = &"ChoiceItemSelected" if sel else &"ChoiceItem"
		var mark := b.get_node_or_null("Mark")
		if mark:
			mark.visible = sel
		for a in b.get_children():
			if a is Control and a.name != "Mark":
				(a as Control).queue_redraw()
