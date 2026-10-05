@tool
class_name SeasideZone
extends Node2D
## 海辺。この日の from_x〜to_x（日の中の座標）を歩いている間は、背景の山並み・田んぼ・木立ちが、
## 水平線の空・太陽・灯台の手前の海・灯台に入れかわる（Background.set_seaside）。入るとき・出るときは ramp の幅でだんだん入れかわる。

@export var from_x := 900.0
@export var to_x := 4200.0
@export var ramp := 600.0

var amount := 0.0
var _player: Node2D


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var x := _player.global_position.x - global_position.x
	amount = minf(smoothstep(from_x, from_x + ramp, x), 1.0 - smoothstep(to_x - ramp, to_x, x))
	get_tree().call_group("background", "set_seaside", amount, x - from_x)


func _exit_tree() -> void:
	if amount > 0.0 and is_inside_tree():
		get_tree().call_group("background", "set_seaside", 0.0, 0.0)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(from_x, -700, to_x - from_x, 700), Color(0.4, 0.7, 0.9, 0.12))
