class_name TitleCall
extends Control
## タイトルコール「To The Summer」（章「あの夏へ」）。老年期の神社で鈴が鳴り、景色が白くなったあと、
## 白い画面に蝉の声が戻り、ゲームのタイトルロゴが大きく浮かぶ。少し止まって、夜の迎え火の森へ溶けていく（合計 約5秒）。
## 決定キー・タップで早送り。ロゴは仮素材（文字）。破の最初の場面は、あとの段階で続ける。

const MAIN_SCENE := "res://world/main.tscn"
## 戻ってきた蝉の声（音素材のある名前）
const CICADA := "semi_minmin"

var done := false
var _tween: Tween
var _logo: Label
var _dark: ColorRect


func _ready() -> void:
	SfxPlayer.stop_music()
	SfxPlayer.set_ambient("")
	var white := ColorRect.new()
	white.color = UiTokens.WHITE_OUT
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white)
	# 夜の迎え火の森へ溶けていく暗さ
	_dark = ColorRect.new()
	_dark.color = Color(UiTokens.FADE, 0.0)
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_logo = Label.new()
	_logo.text = Strings.GAME_TITLE
	_logo.theme_type_variation = &"TitleLabel"
	_logo.add_theme_font_size_override("font_size", UiTokens.FONT_LOGO)
	_logo.add_theme_color_override("font_color", UiTokens.INK)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.modulate.a = 0.0
	center.add_child(_logo)
	add_child(_dark)
	# 鈴の余韻のあと、遠くから蝉の声が戻ってくる
	SfxPlayer.set_ambient(CICADA)
	_tween = create_tween().set_trans(UiTokens.TRANS)
	_tween.tween_property(_logo, "modulate:a", 1.0, UiTokens.TIME_CALL_IN).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(UiTokens.TIME_CALL_HOLD)
	_tween.tween_property(_dark, "color:a", 1.0, UiTokens.TIME_CALL_OUT).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish)


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if go and not done and _tween:
		_tween.set_speed_scale(UiTokens.SKIP_SPEED)
		get_viewport().set_input_as_handled()


## 夜の迎え火の森へ溶けていき、破の最初の場面（8/13 の夜、迎え火の森の入口で目を覚ます）へ続く
func _finish() -> void:
	if done:
		return
	done = true
	SfxPlayer.set_ambient("")
	GameState.start_day_index = GameState.CHAPTER_HA_START
	Transition.change_scene(MAIN_SCENE)
