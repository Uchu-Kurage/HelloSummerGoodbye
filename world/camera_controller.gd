class_name CameraController
extends Camera2D
## カメラは右方向にしか進まない（これまでの最大Xを記録する）。
## 画面の左端に見えない壁（LeftWall）を置き、プレイヤーはそれより左へ行けない。

## プレイヤーより少し先を見せる
const LOOK_AHEAD := 160.0
const VIEW_CENTER_Y := 360.0

@export var player: Player
@export var left_wall: StaticBody2D

var _max_x := -INF


func _ready() -> void:
	# プレイヤーが動いたあとで追従する
	process_physics_priority = 10
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	snap()


func half_width() -> float:
	return get_viewport_rect().size.x / 2.0 / zoom.x


func left_edge() -> float:
	return position.x - half_width()


func snap() -> void:
	_max_x = -INF
	_follow()
	reset_smoothing()


func _physics_process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if player == null:
		return
	var hw := half_width()
	var target := player.global_position.x + LOOK_AHEAD
	_max_x = maxf(_max_x, target)
	var x := clampf(_max_x, hw, maxf(hw, GameState.world_length() - hw))
	position = Vector2(x, VIEW_CENTER_Y)
	player.left_limit = left_edge() + 24.0
	player.right_limit = GameState.world_length() - 40.0
	if left_wall:
		left_wall.global_position.x = left_edge()
