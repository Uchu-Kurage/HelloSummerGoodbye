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
## 主人公の絵（Google Gemini で生成し、背景を切り抜いたもの）。0 は立ち姿、1〜4 は歩く絵（右向き。左向きは反転）
const FRAMES: Array[Texture2D] = [
	preload("res://world/scenery/painted/player_1.png"),
	preload("res://world/scenery/painted/player_2.png"),
	preload("res://world/scenery/painted/player_3.png"),
	preload("res://world/scenery/painted/player_4.png"),
	preload("res://world/scenery/painted/player_5.png"),
]
## 章「あの夏へ」：老人・青年の絵（子どもと同じく、0 が立ち姿、1〜4 が歩く絵）
const ELDER_FRAMES: Array[Texture2D] = [
	preload("res://world/scenery/painted/elder_1.png"),
	preload("res://world/scenery/painted/elder_2.png"),
	preload("res://world/scenery/painted/elder_3.png"),
	preload("res://world/scenery/painted/elder_4.png"),
	preload("res://world/scenery/painted/elder_5.png"),
]
const ELDER_HEAD_X := [58.5, 110.5, 70.5, 112.0, 68.0]
const YOUTH_FRAMES: Array[Texture2D] = [
	preload("res://world/scenery/painted/youth_1.png"),
	preload("res://world/scenery/painted/youth_2.png"),
	preload("res://world/scenery/painted/youth_3.png"),
	preload("res://world/scenery/painted/youth_4.png"),
	preload("res://world/scenery/painted/youth_5.png"),
]
const YOUTH_HEAD_X := [46.0, 100.0, 46.0, 102.0, 54.0]
## 絵ごとの頭のまん中（絵の中の x px）。ここを足もとの原点にそろえ、歩いても頭がぶれないようにする
const FRAME_HEAD_X := [47.5, 75.0, 66.5, 87.0, 65.0]
## 画面での背の高さ（帽子のてっぺんまで）
const BODY_HEIGHT := 160.0
## 歩く絵を1秒に何枚めくるか（歩きの速さで割合がかわる）
const WALK_FPS := 6.0

## 日の切り替わりの間は true
var locked := false
## 姿の大きさ（おとなの背丈にするときなどに使う。歩き方・速さは同じ）
var body_scale := 1.0
## 姿（章「あの夏へ」：子ども／青年／老人）。老人だけダッシュできない。歩く速さは同じ
var form: DayData.Form = DayData.Form.CHILD
## 姿ごとの背丈（子どもを 1.0 とした倍率）
const FORM_SCALE := {DayData.Form.CHILD: 1.0, DayData.Form.YOUTH: 1.1, DayData.Form.ELDER: 1.06}
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
	# 絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_visual.draw.connect(_draw_body)
	set_form(form)


## 少しのあいだ立ち止まる（アイテムを拾ったときなど）
func hold(seconds: float) -> void:
	_hold_left = maxf(_hold_left, seconds)


func is_walking() -> bool:
	return absf(velocity.x) > 1.0


## 主人公の姿を切り替える（章の日の姿、村の青年期の回想）
func set_form(f: DayData.Form) -> void:
	form = f
	body_scale = FORM_SCALE[f]
	if _visual:
		_visual.queue_redraw()


## 会話の顔に使う立ち絵（いまの姿の、立ち止まった絵）。主人公がいなければ少年期
static func face_frame(tree: SceneTree) -> Texture2D:
	var p := tree.get_first_node_in_group("player") as Player if tree else null
	if p:
		match p.form:
			DayData.Form.ELDER:
				return ELDER_FRAMES[0]
			DayData.Form.YOUTH:
				return YOUTH_FRAMES[0]
	return FRAMES[0]


## ダッシュできるか（老人はできない）
func can_dash() -> bool:
	return form != DayData.Form.ELDER


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
	var dash := clampf((_press_t - DASH_DELAY) / DASH_RAMP, 0.0, 1.0) if can_dash() else 0.0
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
	_visual.scale = Vector2(_facing * body_scale, body_scale)
	_visual.position.y = -absf(sin(_walk_t * 9.0)) * 1.5
	_visual.queue_redraw()


func _draw_body() -> void:
	# 立ち止まっているときは立ち姿、歩いているときは歩く絵を順にくり返す
	var frame := 0
	if _walk_t > 0.0:
		frame = 1 + int(_walk_t * WALK_FPS) % (FRAMES.size() - 1)
	var frames := FRAMES
	var heads := FRAME_HEAD_X
	match form:
		DayData.Form.ELDER:
			frames = ELDER_FRAMES
			heads = ELDER_HEAD_X
		DayData.Form.YOUTH:
			frames = YOUTH_FRAMES
			heads = YOUTH_HEAD_X
	var tex: Texture2D = frames[frame]
	var k := BODY_HEIGHT / tex.get_height()
	var head_x: float = heads[frame]
	_visual.draw_texture_rect(tex, Rect2(-head_x * k, -BODY_HEIGHT, tex.get_width() * k, BODY_HEIGHT), false)
