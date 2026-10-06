class_name TimeOfDay
extends Node
## 1日の中の時間帯（早朝→朝→昼→夕方→夜）と、夏の進み具合による空の褪せ方を決める。
## 色の値は WorldPalette にまとめてある。
## 時間の値は、プレイヤーのその日の中の位置から、その日の time_keys で決める（GameState.day_time）。
## 異界の日（is_otherworld）は、日の全体で色を褪せさせる。
## 夕立（RainZone）の間は暗くして、環境音を雨にする。

@export var canvas_modulate: CanvasModulate
@export var background: Background
@export var player: Node2D

var _last_ambient := ""
## 雨の強さ（0.0〜1.0）。RainZone が set_rain で入れる
var rain := 0.0
## 雨の間の環境音。秘密基地の屋根をふさぐと「屋根をたたく雨」にかわる（set_rain_ambient）
var rain_ambient := WorldPalette.RAIN_AMBIENT
## 異界の強さ（0.0〜1.0）。OtherworldZone が set_otherworld で入れる。色が抜けて、環境音がかわる
var otherworld := 0.0
## 異界の日（is_otherworld）の強さ。その日にいるあいだは 1.0
var day_otherworld := 0.0
var _ow_ambient := ""
var _ow_source: Node
## 異界の場所がさいごに知らせてきたフレーム（知らせが止まったら、もとにもどす）
var _ow_frame := -1
## 昼の光の強さ（0.0〜1.0）。夕方から夜にかけて、また雨で弱まる。SummerAir（光の粒・光の筋）が読む
var daylight := 1.0


func _ready() -> void:
	add_to_group("time_of_day")


func set_rain(amount: float) -> void:
	rain = clampf(amount, 0.0, 1.0)
	if rain <= 0.0:
		rain_ambient = WorldPalette.RAIN_AMBIENT


func set_rain_ambient(ambient_name: String) -> void:
	rain_ambient = ambient_name if ambient_name != "" else WorldPalette.RAIN_AMBIENT


func set_otherworld(amount: float, ambient: String, source: Node) -> void:
	otherworld = clampf(amount, 0.0, 1.0)
	_ow_ambient = ambient
	_ow_source = source
	_ow_frame = Engine.get_process_frames()


## 異界の場所がなくなったら（日が解放されたら）もとにもどす。ほかの日の場所が入れていたら、そのまま
func clear_otherworld(source: Node) -> void:
	if source == _ow_source:
		otherworld = 0.0
		_ow_ambient = ""
		_ow_source = null


func _process(_delta: float) -> void:
	if player == null:
		return
	var L := GameState.DAY_LENGTH_PX
	var index := clampi(int(player.global_position.x / L), 0, GameState.day_count() - 1)
	var progress := clampf((player.global_position.x - index * L) / L, 0.0, 1.0)
	var d := GameState.get_day(index)
	var season := GameState.summer_progress_of(d)
	day_otherworld = 1.0 if GameState.is_otherworld(d) else 0.0
	apply(GameState.day_time(d, progress), season)


## time は時間の値（早朝 -0.15〜夜の終わり 1.00）
func apply(time: float, season: float) -> void:
	var light := sample_light(time)
	var sky := sky_color(time, season)
	if rain > 0.0:
		light = light.lerp(light * WorldPalette.RAIN_LIGHT, rain)
		sky = sky.lerp(WorldPalette.RAIN_SKY, rain)
	# 異界の日を出たら（どの場所も知らせてこなくなったら）、もとの色と音にもどす
	if otherworld > 0.0 and Engine.get_process_frames() - _ow_frame > 1:
		otherworld = 0.0
		_ow_ambient = ""
		_ow_source = null
	var ow := maxf(otherworld, day_otherworld)
	if ow > 0.0:
		light = light.lerp(_gray(light) * WorldPalette.OTHERWORLD_LIGHT, ow)
		sky = sky.lerp(_gray(sky) * WorldPalette.OTHERWORLD_SKY, ow)
	daylight = smoothstep(WorldPalette.DAYLIGHT_DAWN.x, WorldPalette.DAYLIGHT_DAWN.y, time) \
		* (1.0 - smoothstep(WorldPalette.DAYLIGHT_FADE.x, WorldPalette.DAYLIGHT_FADE.y, time)) * (1.0 - rain)
	if canvas_modulate:
		canvas_modulate.color = light
	if background:
		background.set_sky_color(sky)
		background.set_desaturate(ow)
	var amb := ambient_for(season)
	if rain > 0.5:
		amb = rain_ambient
	elif otherworld > 0.5 and _ow_ambient != "":
		amb = _ow_ambient
	elif day_otherworld > 0.5:
		amb = WorldPalette.OTHERWORLD_AMBIENT
	if amb != _last_ambient:
		_last_ambient = amb
		SfxPlayer.set_ambient(amb)


static func _gray(c: Color) -> Color:
	var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return Color(l, l, l, c.a)


static func _sample(time: float, column: int) -> Color:
	var keys := WorldPalette.TIME_KEYS
	if time <= keys[0][0]:
		return keys[0][column]
	for i in range(1, keys.size()):
		if time <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var t := smoothstep(a[0], b[0], time)
			return (a[column] as Color).lerp(b[column], t)
	return keys[keys.size() - 1][column]


## 画面全体（CanvasModulate）の色。急に切り替えず、キーの間をなめらかに補間する
static func sample_light(time: float) -> Color:
	return _sample(time, 1)


## 空の色。夏が進むほど褪せる
static func sky_color(time: float, season: float) -> Color:
	var c := _sample(time, 2)
	return c.lerp(WorldPalette.SKY_FADE_TOWARD, WorldPalette.SKY_FADE_AMOUNT * season)


static func ambient_for(season: float) -> String:
	var result := ""
	for k in WorldPalette.AMBIENT_KEYS:
		if season >= k[0]:
			result = k[1]
	return result
