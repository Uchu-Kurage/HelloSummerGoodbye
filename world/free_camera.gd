class_name FreeCamera
extends Node
## 急の造成地：この日のあいだだけ、カメラが左へ戻ってもついてくる。主人公が動ける範囲は、この日の中だけ。
## （鳥居と山のてっぺんが重なる場所を、行き過ぎたら戻って探せる。日の左はし・右はしの外へは出られない）
## 主人公がこの日に入ってから有効にする（となりの日を読み込んだだけでは、前の日のカメラを縛らない）。

@export var left_margin := 100.0
@export var right_margin := 300.0

var _cam: CameraController
var _player: Node2D
var _active := false


func _day_left() -> float:
	var n := get_parent()
	while n and not n is DayBase:
		n = n.get_parent()
	return (n as Node2D).global_position.x if n else 0.0


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_2d() as CameraController
		if _cam == null:
			return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var left := _day_left()
	var inside := _player.global_position.x >= left
	if inside == _active:
		return
	_active = inside
	_apply(inside)


func _apply(on: bool) -> void:
	var left := _day_left()
	_cam.free_look = on
	_cam.bound_left = left + left_margin if on else -INF
	_cam.bound_right = left + GameState.DAY_LENGTH_PX - right_margin if on else INF


func _exit_tree() -> void:
	if _active and _cam and is_instance_valid(_cam):
		_apply(false)
