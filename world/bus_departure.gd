extends Node2D
## 帰る日のバス（親友ルート）。足もと（バス停の前の道）が原点。
## 1. バスに乗ると走り出し、窓の外を村の景色が流れる
## 2. 自転車のベルが鳴り、タケルが後ろの坂道から立ちこぎで追いかけてくる
## 3. タケルが追いつくと、ミニゲーム「帽子を受け止める」（後ろを振り返って、窓を開け、帽子を受け止め、さけび返す）
## 4. バスがカーブを曲がり、タケルが見えなくなる。そのまま日の終わり（エンディング）まで走る

enum State { WAIT, BOARD, RIDE, CHASE, CATCH, AWAY }

## 自転車のタケルのせりふ（話す人の名前と色もここから）
@export var takeru: NpcData
## 追いついたら：ミニゲームで帽子を受け止め、帽子をもらう
@export var catch_lines: Array[String] = ["@game hat", "@give takeru_hat"]
## 止まっているバスの位置（この場面の原点＝バス停からの距離）
@export var bus_offset := 400.0
## 帽子を受け取るまで、バスはこの位置（バス停からの距離）より先へは行かない
@export var hold_x := 2000.0

const P := preload("res://world/world_palette.gd")
const BUS_W := 560.0
const BUS_H := 210.0
## 乗り口（バスの左寄り）とプレイヤーの席（後ろの窓）の位置（バスの中心から）
const DOOR_X := -170.0
const SEAT_X := -190.0
const SPEED_RIDE := 220.0
const SPEED_SLOW := 40.0
const SPEED_AWAY := 340.0
const ACCEL := 140.0
## 走り出してから、ベルが鳴るまでの距離
const BELL_AFTER := 420.0
const BIKE_CATCH := 190.0

var state := State.WAIT
var _bus_x := 260.0
var _speed := 0.0
var _start_x := 0.0
var _bike_x := -INF
var _bike_alpha := 1.0
var _bike_t := 0.0
var _wheel := 0.0
var _window_open := false
var _player: Player
var _hud: Hud


func _ready() -> void:
	_bus_x = bus_offset


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		_hud = get_tree().get_first_node_in_group("interact_listener") as Hud
		if _player == null:
			return
	match state:
		State.WAIT:
			var x := _player.global_position.x - global_position.x
			if x >= _bus_x + DOOR_X and not _player.talking and not _player.locked and not (_hud and _hud.is_message_open()):
				_board()
		State.RIDE, State.CHASE, State.CATCH, State.AWAY:
			_drive(delta)
	queue_redraw()


func _board() -> void:
	state = State.BOARD
	_player.locked = true
	SfxPlayer.play("accept")
	var tw := create_tween().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_IN)
	tw.tween_property(_player, "position:x", global_position.x + _bus_x + SEAT_X, UiTokens.TIME_FADE)
	tw.parallel().tween_property(_player, "modulate:a", 0.0, UiTokens.TIME_FADE)
	tw.tween_interval(UiTokens.TIME_FADE)
	tw.tween_callback(func():
		state = State.RIDE
		_start_x = _bus_x)


func _drive(delta: float) -> void:
	var target := SPEED_RIDE
	if state == State.CATCH:
		target = SPEED_SLOW
	elif state == State.AWAY:
		target = SPEED_AWAY
	_speed = move_toward(_speed, target, ACCEL * delta)
	if state != State.AWAY and _bus_x >= hold_x:
		_speed = 0.0
	_bus_x += _speed * delta
	_wheel += _speed * delta / 30.0
	_player.position.x = global_position.x + _bus_x + SEAT_X
	if state == State.RIDE and _bus_x - _start_x >= BELL_AFTER:
		_start_chase()
	if _bike_x > -INF:
		_drive_bike(delta)


func _start_chase() -> void:
	state = State.CHASE
	SfxPlayer.play("bike_bell")
	# 画面の左の外（後ろの坂道のほう）から来る
	var view_left := get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO
	_bike_x = minf(view_left.x - global_position.x - 120.0, _bus_x - 700.0)


func _drive_bike(delta: float) -> void:
	_bike_t += delta
	var want := _bus_x + SEAT_X - BIKE_CATCH
	match state:
		State.CHASE:
			_bike_x = minf(_bike_x + (_speed + 260.0) * delta, want)
			if _bike_x >= want:
				_catch()
		State.CATCH:
			_bike_x = want
		State.AWAY:
			# カーブを曲がって見えなくなる
			_bike_x += (_speed - 160.0) * delta
			_bike_alpha = maxf(0.0, _bike_alpha - delta * 0.8)


## 追いついた：後ろを振り返る画面で、窓を開けて帽子を受け止める（ミニゲーム）。終わったら、もうタケルは見えない
func _catch() -> void:
	state = State.CATCH
	await _hud.run_talk(takeru, catch_lines)
	_window_open = true
	_bike_alpha = 0.0
	state = State.AWAY


func _draw() -> void:
	_draw_bus()
	if _bike_x > -INF and _bike_alpha > 0.0:
		_draw_bike()


func _draw_bus() -> void:

	var l := _bus_x - BUS_W / 2.0
	var top := -BUS_H - 24
	draw_rect(Rect2(l, top, BUS_W, BUS_H), P.BUS_BODY)
	draw_rect(Rect2(l, top + BUS_H * 0.62, BUS_W, 18), P.BUS_STRIPE)
	draw_rect(Rect2(l + 6, top - 8, BUS_W - 12, 12), P.BUS_STRIPE)
	# 窓（いちばん後ろがプレイヤーの席）
	for i in 6:
		var wx := l + 24 + i * 88
		var open := i == 0 and _window_open
		draw_rect(Rect2(wx, top + 24, 72, 70), P.SHOP_DARK if open else P.BUS_WINDOW)
	# 窓からのぞくプレイヤーの顔（乗ってから）
	if state != State.WAIT and state != State.BOARD:
		var head := Vector2(_bus_x + SEAT_X, top + 70)
		draw_circle(head, 16, P.PLAYER_SKIN)
		draw_rect(Rect2(head.x - 22, head.y - 18, 44, 6), P.PLAYER_HAT)
		draw_rect(Rect2(head.x - 14, head.y - 30, 28, 13), P.PLAYER_HAT)
	# 乗り口
	draw_rect(Rect2(_bus_x + DOOR_X + 60, top + 24, 50, BUS_H - 30), P.BUS_WINDOW.darkened(0.15))
	for wx in [l + 90, l + BUS_W - 90]:
		var c := Vector2(wx, -18)
		draw_circle(c, 26, P.SHOP_DARK)
		draw_circle(c, 10, P.ROCK)
		draw_line(c, c + Vector2(cos(_wheel), sin(_wheel)) * 22, P.ROCK_DARK, 3.0)


func _draw_bike() -> void:

	var d := takeru
	var a := _bike_alpha
	var x := _bike_x
	var bob := absf(sin(_bike_t * 10.0)) * 6.0
	var rear := Vector2(x - 44, -24)
	var front := Vector2(x + 44, -24)
	for w in [rear, front]:
		draw_arc(w, 24, 0, TAU, 20, Color(P.BIKE, a), 4.0)
		draw_line(w, w + Vector2(cos(_wheel * 1.4), sin(_wheel * 1.4)) * 22, Color(P.BIKE, a), 2.0)
	draw_line(rear, Vector2(x, -40), Color(P.BIKE, a), 4.0)
	draw_line(Vector2(x, -40), front, Color(P.BIKE, a), 4.0)
	draw_line(Vector2(x + 30, -80), front, Color(P.BIKE, a), 4.0)
	# 立ちこぎのタケル（前かがみ）
	var hip := Vector2(x - 4, -88 - bob)
	draw_line(hip, Vector2(x + 6, -40 + bob * 0.5), Color(d.skin_color, a), 8.0)
	draw_line(hip, Vector2(x - 14, -46 - bob * 0.5), Color(d.skin_color, a), 8.0)
	draw_rect(Rect2(hip.x - 14, hip.y - 10, 28, 16), Color(d.pants_color, a))
	var chest := hip + Vector2(22, -50)
	draw_colored_polygon(PackedVector2Array([hip + Vector2(-12, 0), hip + Vector2(12, 0), chest + Vector2(12, 0), chest + Vector2(-12, 0)]), Color(d.shirt_color, a))
	draw_line(chest, Vector2(x + 30, -82), Color(d.skin_color, a), 6.0)
	var head := chest + Vector2(10, -20)
	draw_circle(head, 15, Color(d.skin_color, a))
	draw_arc(head, 13, PI * 0.9, PI * 2.05, 12, Color(d.hair_color, a), 7.0)
	# 投げるまでは帽子をかぶっている
	if state in [State.CHASE, State.CATCH]:
		_draw_hat(head + Vector2(0, -12), 0.0, a)


func _draw_hat(p: Vector2, rot: float, a := 1.0) -> void:
	var it := GameState.find_item(&"takeru_hat")
	var c := it.placeholder_color if it else WorldPalette.BUS_STRIPE
	draw_set_transform(p, rot)
	draw_rect(Rect2(-14, -10, 28, 12), Color(c, a))
	draw_rect(Rect2(6, -2, 16, 5), Color(c.darkened(0.2), a))
	draw_set_transform(Vector2.ZERO)
