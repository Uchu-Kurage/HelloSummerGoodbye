extends CanvasLayer
## 画面遷移（オートロード Transition）。change_scene_to_file を直接呼ばず、必ずここを通す。
## 日の切り替わりの演出（暗転 → 大きな日付 → 明ける）もここで行う。

signal finished

var _fade: ColorRect
var _date_box: VBoxContainer
var _date_label: Label
var _title_label: Label
var _busy := false
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = UiTokens.FADE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)

	_date_box = VBoxContainer.new()
	_date_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_date_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_date_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_date_box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_date_box.modulate.a = 0.0
	add_child(_date_box)
	_date_label = Label.new()
	_date_label.theme_type_variation = &"BigDateLabel"
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_box.add_child(_date_label)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"BigDateSubLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_box.add_child(_title_label)


func is_busy() -> bool:
	return _busy


## フェードして別のシーンへ
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_block(true)
	await _fade_to(1.0, UiTokens.TIME_FADE, Tween.EASE_IN)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, UiTokens.TIME_FADE, Tween.EASE_OUT)
	_block(false)
	_busy = false
	finished.emit()


## 日の切り替わり。on_dark は真っ暗な間に呼ぶ（プレイヤーを次の日へ送るなど）。
## interlude があれば、暗転のあと・日付の前に呼んで終わるまで待つ（縁側の場面。await できる処理）。
## 合計 TIME_DAY_CHANGE 秒前後（縁側の場面のぶんは別）。決定キーやタップで早送りできる。
func play_day_change(date_text: String, title: String, on_dark: Callable, on_reveal: Callable,
		interlude: Callable = Callable()) -> void:
	_busy = true
	_block(true)
	_date_label.text = date_text
	_title_label.text = title
	var total := UiTokens.TIME_DAY_CHANGE
	_tween = create_tween().set_trans(UiTokens.TRANS)
	# 縁側の場面がある日は、夜の終わりからゆっくり暗くなる
	var fade_in := UiTokens.TIME_ENGAWA_FADE if interlude.is_valid() else total * 0.3
	_tween.tween_property(_fade, "modulate:a", 1.0, fade_in).set_ease(Tween.EASE_IN)
	_tween.tween_callback(on_dark)
	if interlude.is_valid():
		await _tween.finished
		# 縁側の場面のあいだは、ここでの早送りはしない（縁側の場面が入力を受ける）
		_tween = null
		await interlude.call()
		_tween = create_tween().set_trans(UiTokens.TRANS)
	_tween.tween_property(_date_box, "modulate:a", 1.0, total * 0.15).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(total * 0.25)
	_tween.tween_property(_date_box, "modulate:a", 0.0, total * 0.1).set_ease(Tween.EASE_IN)
	_tween.tween_callback(on_reveal)
	_tween.tween_property(_fade, "modulate:a", 0.0, total * 0.2).set_ease(Tween.EASE_OUT)
	SfxPlayer.play("day_change")
	await _tween.finished
	_tween = null
	_block(false)
	_busy = false
	finished.emit()


## 日付がぱらぱらとめくれる（神隠しルートの10日目：送り火の夜から 8/31 まで時間が飛ぶ）。
## 暗転 → 大きな日付が dates の順に1枚ずつめくれる → 明ける。on_dark は真っ暗な間、on_reveal は明ける前に呼ぶ。
## 決定キーやタップで早送りできる。動きを減らす設定でも、文字の入れかえだけなので同じ
func play_date_riffle(dates: Array, title: String, on_dark: Callable, on_reveal: Callable) -> void:
	if dates.is_empty():
		return
	_busy = true
	_block(true)
	_date_label.text = dates[0]
	_title_label.text = ""
	var total := UiTokens.TIME_DAY_CHANGE
	_tween = create_tween().set_trans(UiTokens.TRANS)
	_tween.tween_property(_fade, "modulate:a", 1.0, total * 0.3).set_ease(Tween.EASE_IN)
	_tween.tween_callback(on_dark)
	_tween.tween_property(_date_box, "modulate:a", 1.0, total * 0.15).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(total * 0.15)
	for i in range(1, dates.size()):
		_tween.tween_callback(func():
			_date_label.text = dates[i]
			SfxPlayer.play("text_tick"))
		# はじめはゆっくり、だんだん速く、最後の数枚でまたゆっくり
		var k := 1.0 + 0.8 * absf(float(i) / dates.size() - 0.5)
		_tween.tween_interval(UiTokens.TIME_DATE_RIFFLE * k)
	_tween.tween_callback(func(): _title_label.text = title)
	_tween.tween_interval(total * 0.3)
	_tween.tween_property(_date_box, "modulate:a", 0.0, total * 0.1).set_ease(Tween.EASE_IN)
	_tween.tween_callback(on_reveal)
	_tween.tween_property(_fade, "modulate:a", 0.0, total * 0.3).set_ease(Tween.EASE_OUT)
	SfxPlayer.play("day_change")
	await _tween.finished
	_tween = null
	_block(false)
	_busy = false
	finished.emit()


func _fade_to(a: float, duration: float, e: Tween.EaseType) -> void:
	_tween = create_tween().set_trans(UiTokens.TRANS).set_ease(e)
	_tween.tween_property(_fade, "modulate:a", a, duration)
	await _tween.finished
	_tween = null


func _block(on: bool) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


## 演出中の決定キー／タップで早送り
func _input(event: InputEvent) -> void:
	if not _busy or _tween == null:
		return
	var skip: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION)
	if skip:
		_tween.set_speed_scale(UiTokens.SKIP_SPEED)
		get_viewport().set_input_as_handled()
