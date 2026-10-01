class_name TimeOfDay
extends Node
## 1日の中の時間帯（朝→昼→夕方→夜）と、夏の進み具合による空の褪せ方を決める。
## 色の値は WorldPalette にまとめてある。

@export var canvas_modulate: CanvasModulate
@export var background: Background
@export var player: Node2D

var _last_ambient := ""


func _process(_delta: float) -> void:
	if player == null:
		return
	var L := GameState.DAY_LENGTH_PX
	var index := clampi(int(player.global_position.x / L), 0, GameState.day_count() - 1)
	var progress := clampf((player.global_position.x - index * L) / L, 0.0, 1.0)
	var season := GameState.summer_progress_of(GameState.get_day(index))
	apply(progress, season)


func apply(progress: float, season: float) -> void:
	if canvas_modulate:
		canvas_modulate.color = sample_light(progress)
	if background:
		background.set_sky_color(sky_color(progress, season))
	var amb := ambient_for(season)
	if amb != _last_ambient:
		_last_ambient = amb
		SfxPlayer.set_ambient(amb)


static func _sample(progress: float, column: int) -> Color:
	var keys := WorldPalette.TIME_KEYS
	if progress <= keys[0][0]:
		return keys[0][column]
	for i in range(1, keys.size()):
		if progress <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var t := smoothstep(a[0], b[0], progress)
			return (a[column] as Color).lerp(b[column], t)
	return keys[keys.size() - 1][column]


## 画面全体（CanvasModulate）の色。急に切り替えず、キーの間をなめらかに補間する
static func sample_light(progress: float) -> Color:
	return _sample(progress, 1)


## 空の色。夏が進むほど褪せる
static func sky_color(progress: float, season: float) -> Color:
	var c := _sample(progress, 2)
	return c.lerp(WorldPalette.SKY_FADE_TOWARD, WorldPalette.SKY_FADE_AMOUNT * season)


static func ambient_for(season: float) -> String:
	var result := ""
	for k in WorldPalette.AMBIENT_KEYS:
		if season >= k[0]:
			result = k[1]
	return result
