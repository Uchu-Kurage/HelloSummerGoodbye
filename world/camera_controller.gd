class_name CameraController
extends Camera2D
## カメラは右方向にしか進まない（これまでの最大Xを記録する）。
## 画面の左端に見えない壁（LeftWall）を置き、プレイヤーはそれより左へ行けない。

## プレイヤーより少し先を見せる
const LOOK_AHEAD := 160.0
## 画面の下端をここにそろえる（地面と道がいつも見えるように。縦が狭い画面では空のほうが切れる）
const VIEW_BOTTOM_Y := 720.0

@export var player: Player
@export var left_wall: StaticBody2D

## true のあいだは、左へ戻ってもカメラがついてくる（急の造成地：鳥居と山のてっぺんの重なりを探して行き来する）
var free_look := false
## 主人公が動ける範囲の左右（free_look の日だけ使う。ふだんは無制限）
var bound_left := -INF
var bound_right := INF

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
	_max_x = target if free_look else maxf(_max_x, target)
	var x := clampf(_max_x, hw, maxf(hw, GameState.world_length() - hw))
	if is_finite(bound_left):
		x = maxf(x, bound_left + hw - 24.0)
	position = Vector2(x, VIEW_BOTTOM_Y - get_viewport_rect().size.y / 2.0 / zoom.y)
	player.left_limit = maxf(left_edge() + 24.0, bound_left)
	player.right_limit = minf(GameState.world_length() - 40.0, bound_right)
	if left_wall:
		left_wall.global_position.x = left_edge()
