class_name StaffRoll
extends Control
## スタッフロール（汎用）。暗い画面に、文字が下から上へゆっくり流れる。決定キー・タップで早送り。
## 流れきったら次の画面へ：章を遊んでいるあい（急の最後）はタイトルへ、
## 4つ目のエンディングのあとは、章題「あの夏へ」へ（予告なし）。
## 急では、序の背景と写真の絵も流す（あとの段階で足す）。

const CHAPTER_TITLE_SCENE := "res://ui/chapter_title.tscn"
const TITLE_SCENE := "res://ui/title.tscn"

var done := false
var _scroll: Control
var _column: VBoxContainer
var _speed_scale := 1.0
var _running := false


func _ready() -> void:
	SfxPlayer.set_ambient("")
	SfxPlayer.play_music("ending")
	var bg := ColorRect.new()
	bg.color = UiTokens.FADE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_scroll = Control.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.clip_contents = true
	add_child(_scroll)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", UiTokens.STAFF_LINE_GAP)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_column)
	for line in Strings.STAFF_LINES:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if line.begins_with("# "):
			l.text = line.substr(2)
			l.theme_type_variation = &"BigDateLabel"
		else:
			l.text = line
			l.theme_type_variation = &"BigDateSubLabel"
		_column.add_child(l)
	await get_tree().process_frame
	var vs := get_viewport_rect().size
	_column.size = Vector2(vs.x, 0)
	_column.position = Vector2(0, vs.y)
	_running = true


## 動かない（動きを減らす設定のとき）：上へ流さず、全部を一度に見せて、決定で次へ進む
func _process(delta: float) -> void:
	if done or not _running:
		return
	var vs := get_viewport_rect().size
	if UiAnim.reduced():
		_column.position.y = maxf(vs.y * 0.5 - _column.size.y * 0.5, UiTokens.SCREEN_MARGIN)
		return
	_column.position.y -= UiTokens.STAFF_SPEED * _speed_scale * delta
	if _column.position.y + _column.size.y < 0.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not go:
		return
	get_viewport().set_input_as_handled()
	if UiAnim.reduced():
		_finish()
	else:
		# 決定で早送り（流れきるまで）
		_speed_scale = UiTokens.SKIP_SPEED


func _finish() -> void:
	if done:
		return
	done = true
	if GameState.chapter:
		# 章の終わり：章を終えたことを記録して、タイトルへ
		EndingRecord.mark_chapter_seen()
		GameState.reset()
		Transition.change_scene(TITLE_SCENE)
	else:
		Transition.change_scene(CHAPTER_TITLE_SCENE)
