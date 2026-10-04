extends "res://world/bus_departure.gd"
## 帰る日のバス（初恋ルート）。足もと（バス停の前の道）が原点。祖父母の見送りまではほかのルートと同じ。
## なつみの好感度の段階（GameState.HEART_HIGH / HEART_MID）で、なつみの出かたが変わる。
## - 高：バスに乗る直前、なつみが走ってきて、丸めた宿題の絵をくれる。走り出してから絵を広げる（@game drawing）
## - 中：窓の外の田んぼ道で、なつみが絵を描いている。顔を上げて、小さく手をふる
## - 低：田んぼ道には、誰もいない
## なつみは別れの言葉を言わない。

enum Tier { LOW, MID, HIGH }
enum Run { NONE, RUNNING, TALK, DONE }

## なつみ（会話の名前と顔もここから）
@export var natsumi: NpcData
## 高：走ってきて、絵をくれる
@export var farewell_lines: Array[String] = ["……はあ、はあ。", "これ、あげる。", "ぼく：しゅくだいは？", "……もう いっかい かくから。", "@give natsumi_drawing"]
## 高：バスが動き出してから、絵を広げる
@export var unroll_lines: Array[String] = ["@game drawing", "ぼく：……"]
## 中・低：田んぼ道で絵を描くなつみの場所（この場面の原点から）
@export var paddy_x := 1500.0

const NATSUMI_TEX: Texture2D = preload("res://world/scenery/painted/npc_natsumi.png")
const NATSUMI_H := 148.0
## 田んぼ道のなつみは、少し小さく（遠く）見せる
const PADDY_SCALE := 0.8
const PADDY_Y := 46.0
## 乗り口のこのくらい手前まで来たら、なつみが走ってくる
const RUN_TRIGGER := 260.0
const RUN_SPEED := 420.0
const RUN_STOP := 90.0
## 走り出してから、絵を広げるまでの距離
const UNROLL_AFTER := 320.0
## 田んぼ道の前では、ゆっくり走る（この距離のあいだ）
const PASS_RANGE := 320.0
const SPEED_PASS := 90.0
## 手をふりはじめる距離（なつみが顔を上げる）
const WAVE_RANGE := 220.0

var _run := Run.NONE
var _nx := -INF
var _unroll_state := 0
var _wave_t := -1.0
var _t := 0.0


func tier() -> Tier:
	if GameState.has_flag(&"natsumi_heart_high"):
		return Tier.HIGH
	if GameState.has_flag(&"natsumi_heart_mid"):
		return Tier.MID
	return Tier.LOW


func _process(delta: float) -> void:
	if not UiAnim.reduced():
		_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		_hud = get_tree().get_first_node_in_group("interact_listener") as Hud
		if _player == null:
			return
	match state:
		State.WAIT:
			var x := _player.global_position.x - global_position.x
			var free := not _player.talking and not _player.locked and not (_hud and _hud.is_message_open())
			if tier() == Tier.HIGH and _run == Run.NONE and x >= _bus_x + DOOR_X - RUN_TRIGGER and free:
				_start_run()
			elif x >= _bus_x + DOOR_X and free and (tier() != Tier.HIGH or _run == Run.DONE):
				_board()
		State.RIDE, State.AWAY:
			_drive(delta)
	if _run == Run.RUNNING:
		_run_in(delta)
	if _wave_t >= 0.0:
		_wave_t += delta
	queue_redraw()


## 高：画面の左の外から、なつみが走ってくる
func _start_run() -> void:
	_run = Run.RUNNING
	_player.locked = true
	var view_left := get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO
	_nx = view_left.x - global_position.x - 80.0


func _run_in(delta: float) -> void:
	var want := _player.global_position.x - global_position.x - RUN_STOP
	_nx = minf(_nx + RUN_SPEED * delta, want)
	if _nx >= want:
		_run = Run.TALK
		_player.locked = false
		await _hud.run_talk(natsumi, farewell_lines)
		_run = Run.DONE


func _drive(delta: float) -> void:
	var seat := _bus_x + SEAT_X
	var near := absf(seat - paddy_x) < PASS_RANGE
	var target := SPEED_RIDE
	if _unroll_state == 1:
		target = SPEED_SLOW
	elif tier() != Tier.HIGH and near:
		target = SPEED_PASS
	_speed = move_toward(_speed, target, ACCEL * delta)
	_bus_x += _speed * delta
	_wheel += _speed * delta / 30.0
	_player.position.x = global_position.x + seat
	if tier() == Tier.HIGH and _unroll_state == 0 and _bus_x - _start_x >= UNROLL_AFTER:
		_unroll()
	if tier() == Tier.MID and _wave_t < 0.0 and paddy_x - seat < WAVE_RANGE:
		_wave_t = 0.0


## 高：走り出してから、もらった絵を広げる
func _unroll() -> void:
	_unroll_state = 1
	await _hud.run_talk(natsumi, unroll_lines)
	_unroll_state = 2


func _draw() -> void:
	# 走ってきたなつみはバス停（バスの手前）に立つ
	if _run != Run.NONE:
		_draw_natsumi(Vector2(_nx, 0), 1.0, _run == Run.RUNNING)
	_draw_bus()
	if tier() == Tier.MID:
		_draw_paddy_natsumi()


func _draw_natsumi(foot: Vector2, k: float, running: bool) -> void:
	var tex := NATSUMI_TEX
	var h := NATSUMI_H * k
	var w := tex.get_width() * h / tex.get_height()
	var bob := absf(sin(_t * 12.0)) * 6.0 if running else 0.0
	draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h - bob, w, h), false)


## 中：田んぼ道で絵を描くなつみ。バスが近づくと顔を上げて、小さく手をふる
func _draw_paddy_natsumi() -> void:
	var foot := Vector2(paddy_x, PADDY_Y)
	var h := NATSUMI_H * PADDY_SCALE
	# 画板（ひざの前）
	draw_set_transform(foot + Vector2(34, -4), -0.3)
	draw_rect(Rect2(-24, -40, 48, 38), P.WOOD)
	draw_rect(Rect2(-20, -36, 40, 30), P.CLOUD)
	draw_rect(Rect2(-20, -36, 40, 10), Color(P.PENCIL_BLUE, 0.6))
	draw_set_transform(Vector2.ZERO)
	_draw_natsumi(foot, PADDY_SCALE, false)
	if _wave_t >= 0.0:
		# 小さく手をふる（肩から上へ。動きを減らす設定では止めた手）
		var sh := foot + Vector2(-6, -h * 0.6)
		var a := -1.2 + (0.0 if UiAnim.reduced() else sin(_wave_t * 6.0) * 0.25)
		var hand := sh + Vector2(cos(a), sin(a)) * h * 0.26
		draw_line(sh, hand, natsumi.skin_color if natsumi else P.PLAYER_SKIN, 5.0)
		draw_circle(hand, 4.0, natsumi.skin_color if natsumi else P.PLAYER_SKIN)
