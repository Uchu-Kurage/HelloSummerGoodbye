class_name Player
extends CharacterBody2D
## 主人公。右へ歩く（画面内でのみ少し左へ戻れる）。ジャンプはない。
## 同じ向きに押しつづける（キーの長押し・画面の押しつづけ）と、少しして走りだす（ダッシュ）。離すと歩きにもどる。

const WALK_SPEED := 240.0
const DASH_SPEED := 480.0
## 押しはじめてから走りだすまで（秒）
const DASH_DELAY := 0.8
## 歩きから走りまで、だんだん速くなる時間（秒）
const DASH_RAMP := 0.4
## 足もとの高さ（地面）
const GROUND_Y := 604.0

## 日の切り替わりの間は true
var locked := false
## 会話の間は true（会話を閉じると歩ける）
var talking := false
## カメラ画面の左端（見えない壁）。これより左へは行けない
var left_limit := 0.0
var right_limit := INF

var _hold_left := 0.0
var _walk_t := 0.0
var _facing := 1.0
## 同じ向きに押しつづけている時間
var _press_t := 0.0
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("player")
	_visual.draw.connect(_draw_body)


## 少しのあいだ立ち止まる（アイテムを拾ったときなど）
func hold(seconds: float) -> void:
	_hold_left = maxf(_hold_left, seconds)


func is_walking() -> bool:
	return absf(velocity.x) > 1.0


func is_dashing() -> bool:
	return absf(velocity.x) > WALK_SPEED + 1.0


func _physics_process(delta: float) -> void:
	_hold_left = maxf(0.0, _hold_left - delta)
	var dir := 0.0
	if not locked and not talking and _hold_left <= 0.0:
		dir = Input.get_axis("move_left", "move_right")
	# 同じ向きに押しつづけると走りだす。止まる・向きを変える・話す・拾うで、歩きにもどる
	if dir != 0.0 and signf(dir) == _facing:
		_press_t += delta
	else:
		_press_t = 0.0
	var dash := clampf((_press_t - DASH_DELAY) / DASH_RAMP, 0.0, 1.0)
	velocity = Vector2(dir * lerpf(WALK_SPEED, DASH_SPEED, dash), 0)
	move_and_slide()
	position.x = clampf(position.x, left_limit, right_limit)
	position.y = GROUND_Y
	if dir != 0.0:
		_facing = signf(dir)
		# 走っているときは足の運びも速く
		_walk_t += delta * absf(velocity.x) / WALK_SPEED
	else:
		_walk_t = 0.0
	_visual.scale.x = _facing
	_visual.position.y = -absf(sin(_walk_t * 9.0)) * 4.0
	_visual.queue_redraw()


func _draw_body() -> void:
	var v := _visual
	var leg := sin(_walk_t * 9.0) * 8.0
	v.draw_rect(Rect2(-14 + leg * 0.5, -36, 10, 36), WorldPalette.PLAYER_SKIN)
	v.draw_rect(Rect2(4 - leg * 0.5, -36, 10, 36), WorldPalette.PLAYER_SKIN)
	v.draw_rect(Rect2(-18, -58, 36, 26), WorldPalette.PLAYER_SHORTS)
	v.draw_rect(Rect2(-20, -100, 40, 46), WorldPalette.PLAYER_BODY)
	v.draw_circle(Vector2(0, -122), 22, WorldPalette.PLAYER_SKIN)
	v.draw_rect(Rect2(-30, -142, 60, 8), WorldPalette.PLAYER_HAT)
	v.draw_rect(Rect2(-20, -158, 40, 18), WorldPalette.PLAYER_HAT)
	v.draw_circle(Vector2(10, -124), 3, WorldPalette.POLE)
