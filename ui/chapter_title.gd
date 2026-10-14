class_name ChapterTitle
extends Control
## 章題「あの夏へ」。黒い画面の真ん中に、序の日付の札と同じ紙の質感の札で、ゆっくり浮かぶ（約3秒）。
## 決定キー・タップで早送り。消えたら章の最初の場面（病室）へ。
## スタッフロールのあと、予告なしにここへ来る。

const MAIN_SCENE := "res://world/main.tscn"

var done := false
var _tween: Tween
var _chip: PanelContainer


func _ready() -> void:
	# 夏の音は止めて、画面は暗いまま（蝉の声も止んでいる）
	SfxPlayer.set_ambient("")
	SfxPlayer.stop_music()
	var bg := ColorRect.new()
	bg.color = UiTokens.FADE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_chip = PanelContainer.new()
	_chip.theme_type_variation = &"PaperChip"
	center.add_child(_chip)
	var label := Label.new()
	label.text = Strings.CHAPTER_TITLE
	label.theme_type_variation = &"TitleLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip.add_child(label)
	_chip.modulate.a = 0.0
	# 動きを減らす設定でも、出入りはフェード（もともとフェードだけ）
	_tween = create_tween().set_trans(UiTokens.TRANS)
	_tween.tween_property(_chip, "modulate:a", 1.0, UiTokens.TIME_CHAPTER_IN).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(UiTokens.TIME_CHAPTER_HOLD)
	_tween.tween_property(_chip, "modulate:a", 0.0, UiTokens.TIME_CHAPTER_OUT).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish)


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if go and not done and _tween:
		# 決定で早送り
		_tween.set_speed_scale(UiTokens.SKIP_SPEED)
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if done:
		return
	done = true
	GameState.start_chapter()
	Transition.change_scene(MAIN_SCENE)
