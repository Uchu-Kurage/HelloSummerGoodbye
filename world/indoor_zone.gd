class_name IndoorZone
extends Node2D
## 屋外の日の中の一部の部屋（破の 8/13：玄関を上がって、茶の間・座敷・縁側）。足もとの左はしが原点。
## 幅 width のあいだ、壁と床を描く。主人公がこの中にいるあいだは、手前の枝・光の粒・夏の環境音を止める。

@export var width := 1500.0:
	set(v):
		width = v
		queue_redraw()

var _inside := false
var _player: Node2D


func _draw() -> void:
	# 日の座標の道の上端（ROAD_TOP）を、足もと（y=604）が原点の座標にして描く
	ChapterArt.draw_room(self, 0.0, width, DayBase.ROAD_TOP - 604.0, -720.0)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var x := _player.global_position.x - global_position.x
	var inside := x >= 0.0 and x <= width
	if inside == _inside:
		return
	_inside = inside
	var main := get_tree().current_scene
	for n in ["Foreground", "SummerAir"]:
		var c := main.get_node_or_null(n) as CanvasItem
		if c:
			c.visible = not inside
	get_tree().call_group("time_of_day", "set_zone_indoor", inside)


func _exit_tree() -> void:
	if _inside and is_inside_tree():
		get_tree().call_group("time_of_day", "set_zone_indoor", false)
