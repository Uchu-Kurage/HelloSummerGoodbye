extends Node2D
## タイトル画面。背景は1日目の景色をゆっくり横に流す。
## ブラウザは最初の操作まで音を鳴らせないので「タップして はじめる」を挟み、そのあとで音を有効にする。

const SCROLL_SPEED := 36.0
const MAIN_SCENE := "res://world/main.tscn"

@onready var _camera: Camera2D = $Camera2D
@onready var _modulate: CanvasModulate = $CanvasModulate
@onready var _background: Background = $Background
@onready var _ui: Control = $UI/Root

var _prompt: Label
var _menu_panel: PanelContainer
var _list: MenuList
var _started := false
var _pulse: Tween


func _ready() -> void:
	var day0 := GameState.get_day(0)
	var day: DayBase = load(day0.scene_path).instantiate()
	day.day_data = day0
	day.preview = true
	$Days.add_child(day)
	_build_ui()
	_camera.position = Vector2(640, 360)


func _build_ui() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", UiTokens.SPACE_L)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(v)

	var title_panel := PanelContainer.new()
	title_panel.theme_type_variation = &"PaperPanel"
	title_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title_panel)
	var title := Label.new()
	title.text = Strings.GAME_TITLE
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = 420
	title_panel.add_child(title)

	var below := Control.new()
	below.custom_minimum_size = Vector2(0, 220)
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(below)

	_prompt = Label.new()
	_prompt.theme_type_variation = &"HeadingLabel"
	_prompt.text = Strings.START_PROMPT_TOUCH if DisplayServer.is_touchscreen_available() else Strings.START_PROMPT_KEY
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	below.add_child(_prompt)
	_prompt.modulate.a = 0.0
	_pulse = create_tween().set_loops().set_trans(UiTokens.TRANS)
	_pulse.tween_property(_prompt, "modulate:a", 1.0, UiTokens.TIME_PULSE).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(_prompt, "modulate:a", 0.45, UiTokens.TIME_PULSE).set_ease(Tween.EASE_IN)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	below.add_child(center)
	_menu_panel = PanelContainer.new()
	_menu_panel.theme_type_variation = &"PaperPanel"
	_menu_panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(_menu_panel)
	_list = MenuList.new()
	_menu_panel.add_child(_list)
	_add_item(Strings.MENU_START, _on_start)
	# ブラウザではタブを閉じられないので「おわる」は出さない
	if not OS.has_feature("web"):
		_add_item(Strings.MENU_QUIT, func(): get_tree().quit())
	_menu_panel.hide()


func _add_item(text: String, cb: Callable) -> void:
	var b: MenuItem = preload("res://ui/components/menu_item.tscn").instantiate()
	b.text = text
	b.pressed.connect(cb)
	_list.add_child(b)


func _process(delta: float) -> void:
	_camera.position.x += SCROLL_SPEED * delta
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
	_pulse.kill()
	UiAnim.fade(_prompt, 0.0, UiTokens.TIME_SMALL)
	UiAnim.panel_in(_menu_panel)
	_list.activate()


func _on_start() -> void:
	if Transition.is_busy():
		return
	GameState.reset()
	Transition.change_scene(MAIN_SCENE)
