@tool
class_name RainZone
extends Node2D
## 夕立。この日の from_x〜to_x（日の中の座標）を歩いている間は雨が降る。
## 降っている間は画面が暗くなり、環境音が雨にかわる（蝉が鳴きやむ）。やむと蝉の声がもどる。

@export var from_x := 1800.0
@export var to_x := 2900.0
## 降りはじめ・やみはじめの、だんだん強く／弱くなる幅
@export var ramp := 220.0
## 空でなければ、会話の @event でこの名前が来たときに、その場で雨がやむ（そのあとは降らない）
@export var stop_on_event := ""
## 雨がやむまでの時間（秒）
@export var stop_time := 1.6

const STREAKS := 140
const FALL_SPEED := 900.0
const STREAK_LEN := 26.0

var amount := 0.0
var _stopped := false
var _stop_k := 1.0
var _t := 0.0
var _player: Node2D


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var x := _player.global_position.x - global_position.x
	if _stopped:
		_stop_k = maxf(0.0, _stop_k - delta / stop_time)
	var a := minf(smoothstep(from_x, from_x + ramp, x), 1.0 - smoothstep(to_x - ramp, to_x, x)) * _stop_k
	if not is_equal_approx(a, amount):
		amount = a
		get_tree().call_group("time_of_day", "set_rain", amount)
	if not UiAnim.reduced():
		_t += delta
	queue_redraw()


func on_talk_event(event_name: String) -> void:
	if stop_on_event != "" and event_name == stop_on_event:
		_stopped = true


func _exit_tree() -> void:
	if amount > 0.0 and is_inside_tree():
		get_tree().call_group("time_of_day", "set_rain", 0.0)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(from_x, -700, to_x - from_x, 700), Color(WorldPalette.RAIN_STREAK, 0.15))
		return
	if amount <= 0.01:
		return
	# 見えている範囲にだけ、雨のすじを描く（動きを減らす設定では止まったすじ）
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var left := view.position.x - global_position.x
	var top := view.position.y - global_position.y
	var w := view.size.x
	var h := view.size.y
	var c := Color(WorldPalette.RAIN_STREAK, WorldPalette.RAIN_STREAK.a * amount)
	var n := int(STREAKS * amount)
	for i in n:
		var fx := fposmod(i * 0.6180339, 1.0)
		var fy := fposmod(i * 0.4142135 + _t * FALL_SPEED / h, 1.0)
		var p := Vector2(left + fx * w, top + fy * h)
		draw_line(p, p + Vector2(-6, STREAK_LEN), c, 2.0)
