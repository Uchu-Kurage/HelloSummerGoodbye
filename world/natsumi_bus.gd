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

## なつみの姿（水彩の絵。どれも右向き）：走る／絵を差し出す／座って描く／顔を上げて手をふる
const RUN_TEX: Texture2D = preload("res://world/scenery/painted/natsumi_mg1_3.png")
const GIVE_TEX: Texture2D = preload("res://world/scenery/painted/natsumi_mg1_4.png")
const DRAW_TEX: Texture2D = preload("res://world/scenery/painted/natsumi_mg1_1.png")
const WAVE_TEX: Texture2D = preload("res://world/scenery/painted/natsumi_mg1_2.png")
const NATSUMI_H := 150.0
## 座っている姿の高さ（立ち絵と頭の大きさをそろえる）
const SIT_H := 135.0
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


func _ready() -> void:
	super()
	# 人物の絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


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
		var running := _run == Run.RUNNING
		_draw_natsumi(RUN_TEX if running else GIVE_TEX, Vector2(_nx, 0), NATSUMI_H, running)
	_draw_bus()
	if tier() == Tier.MID:
		# 田んぼ道で絵を描くなつみ。バスが近づくと顔を上げて、小さく手をふる
		_draw_natsumi(WAVE_TEX if _wave_t >= 0.0 else DRAW_TEX, Vector2(paddy_x, PADDY_Y), SIT_H * PADDY_SCALE, false)


## なつみを描く。foot は足もと（絵の下のふち）のまん中
func _draw_natsumi(tex: Texture2D, foot: Vector2, h: float, running: bool) -> void:
	var w := tex.get_width() * h / tex.get_height()
	var bob := absf(sin(_t * 12.0)) * 6.0 if running else 0.0
	draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h - bob, w, h), false)
