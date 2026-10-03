extends Node2D
## タイトル画面。背景は1日目の景色をゆっくり横に流す。
## ブラウザは最初の操作まで音を鳴らせないので「タップして はじめる」を挟み、そのあとで音を有効にする。

const SCROLL_SPEED := 36.0
const MAIN_SCENE := "res://world/main.tscn"
const TITLE_MUSIC := "title"

@onready var _camera: Camera2D = $Camera2D
@onready var _modulate: CanvasModulate = $CanvasModulate
@onready var _background: Background = $Background
@onready var _ui: Control = $UI/Root

var _prompt: Label
var _menu_panel: PanelContainer
var _list: MenuList
var _started := false
var _pulse: Tween
var _debug: DebugJump


func _ready() -> void:
	var day0 := GameState.get_day(0)
	var day: DayBase = load(day0.scene_path).instantiate()
	day.day_data = day0
	day.preview = true
	$Days.add_child(day)
	_build_ui()
	_camera.position = Vector2(640, 360)
	# 本編の一時停止メニューから戻ったときは、もう音を出してよいので曲から始める
	if SfxPlayer.enabled:
		SfxPlayer.play_music(TITLE_MUSIC)


## 景色を主役にする：パネルは置かず、右上に縦書きのタイトル、下の道の上に案内とメニュー
func _build_ui() -> void:
	var titles := HBoxContainer.new()
	titles.anchor_left = 1.0
	titles.anchor_right = 1.0
	titles.offset_right = -UiTokens.SCREEN_MARGIN - UiTokens.SPACE_L * 2
	titles.offset_top = UiTokens.SCREEN_MARGIN + UiTokens.SPACE_M
	titles.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	titles.add_theme_constant_override("separation", UiTokens.SPACE_M)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(titles)
	# 縦書きは右から左へ読むので、添え書きを左、タイトルを右に置く
	var sub := Label.new()
	sub.text = _vertical(Strings.GAME_SUBTITLE.replace(" ", ""))
	sub.theme_type_variation = &"SubVerticalLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	titles.add_child(sub)
	var title := Label.new()
	title.text = _vertical(Strings.GAME_TITLE)
	title.theme_type_variation = &"TitleVerticalLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(title)

	# 道の帯（画面の下から 40px の高さ）に案内とメニューを置く
	var band := Control.new()
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -UiTokens.SCREEN_MARGIN - UiTokens.TOUCH_MIN
	band.offset_bottom = -UiTokens.SCREEN_MARGIN
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(band)

	_prompt = Label.new()
	_prompt.theme_type_variation = &"HeadingLabel"
	_prompt.text = Strings.START_PROMPT_TOUCH if DisplayServer.is_touchscreen_available() else Strings.START_PROMPT_KEY
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(_prompt)
	_prompt.modulate.a = 0.0
	_pulse = create_tween().set_trans(UiTokens.TRANS)
	if UiAnim.reduced():
		# 動きを減らす設定のときは明滅させずに出したままにする
		_pulse.tween_property(_prompt, "modulate:a", 1.0, UiTokens.TIME_FADE)
	else:
		_pulse.set_loops()
		_pulse.tween_property(_prompt, "modulate:a", 1.0, UiTokens.TIME_PULSE).set_ease(Tween.EASE_OUT)
		_pulse.tween_property(_prompt, "modulate:a", 0.45, UiTokens.TIME_PULSE).set_ease(Tween.EASE_IN)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(center)
	_menu_panel = PanelContainer.new()
	# 景色（道）の上でも文字が読めるよう、紙の小札を敷く
	_menu_panel.theme_type_variation = &"PaperChip"
	center.add_child(_menu_panel)
	_list = MenuList.new()
	_list.vertical = false
	_menu_panel.add_child(_list)
	_add_item(Strings.MENU_START, _on_start)
	# 開発用：ルートと日を選んでとぶ（デバッグ実行のときだけ）
	if DebugJump.available():
		_add_item(Strings.MENU_DEBUG, _on_debug)
		_debug = DebugJump.new()
		_debug.closed.connect(_list.activate)
		add_child(_debug)
	# ブラウザではタブを閉じられないので「おわる」は出さない
	if not OS.has_feature("web"):
		_add_item(Strings.MENU_QUIT, func(): get_tree().quit())
	_menu_panel.hide()


static func _vertical(text: String) -> String:
	var chars := PackedStringArray()
	for c in text:
		chars.append(c)
	return "\n".join(chars)


func _add_item(text: String, cb: Callable) -> void:
	var b: MenuItem = preload("res://ui/components/menu_item.tscn").instantiate()
	b.text = text
	b.pressed.connect(cb)
	_list.add_child(b)


func _process(delta: float) -> void:
	_camera.position.x += SCROLL_SPEED * delta
	_camera.position.y = CameraController.VIEW_BOTTOM_Y - get_viewport_rect().size.y / 2.0
	var L := GameState.DAY_LENGTH_PX
	var half := get_viewport_rect().size.x / 2.0
	if _camera.position.x > L - half:
		_camera.position.x = half
	var progress := clampf((_camera.position.x - half) / L, 0.0, 0.5)
	_modulate.color = TimeOfDay.sample_light(progress)
	_background.set_sky_color(TimeOfDay.sky_color(progress, 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not go:
		return
	_started = true
	get_viewport().set_input_as_handled()
	SfxPlayer.unlock()
	SfxPlayer.play("accept")
	SfxPlayer.play_music(TITLE_MUSIC)
	_pulse.kill()
	UiAnim.fade(_prompt, 0.0, UiTokens.TIME_SMALL)
	UiAnim.panel_in(_menu_panel)
	_list.activate()


func _on_start() -> void:
	if Transition.is_busy():
		return
	GameState.reset()
	SfxPlayer.stop_music()
	Transition.change_scene(MAIN_SCENE)


func _on_debug() -> void:
	if Transition.is_busy():
		return
	_list.deactivate()
	_debug.open()
