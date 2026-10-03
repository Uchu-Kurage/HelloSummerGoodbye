class_name SummerAir
extends CanvasLayer
## 夏の空気：ふわふわ漂う光の粒と、左上からさしこむ淡い光の筋。画面に重ねる（ゲームの世界より手前、UI より奥）。
## 昼ほど強く、夕方から夜にかけて消える。雨の間も消える（TimeOfDay.daylight を読む。なければ昼あつかい）。
## 光の粒は、カメラが動くと少しだけ逆へ流れて奥行きを出す。
## 動きを減らす設定では、粒は動かさず、またたきと光の筋のゆらぎも止める。

const MOTES := 34
const MOTE_COLOR := Color(1.0, 0.98, 0.9)
## 粒の大きさ（半径 px）と、ぼんやりした外側の倍率
const MOTE_SIZE := Vector2(1.4, 3.6)
const MOTE_HALO := 2.6
const MOTE_ALPHA := Vector2(0.18, 0.5)
## 漂う速さ（px/秒）。少しずつ上と右へ
const DRIFT := Vector2(7.0, -5.0)
const WOBBLE := 10.0
## カメラが動いたとき、粒が逆へ流れる割合
const PARALLAX := 0.18
## 光の筋：[画面上端の x（割合）, 太さ, 強さ]
const RAYS := [[0.06, 130.0, 1.0], [0.2, 80.0, 0.7], [0.32, 170.0, 0.55]]
const RAY_COLOR := Color(1.0, 0.96, 0.84)
const RAY_ALPHA := 0.075
## 光の筋の傾き（下へ行くほど右へ）と長さ
const RAY_SLANT := 0.55
const RAY_LENGTH := 820.0

var _pos: PackedVector2Array = []
var _size: PackedFloat32Array = []
var _alpha: PackedFloat32Array = []
var _phase: PackedFloat32Array = []
var _t := 0.0
var _cam_x := NAN
var _daylight := 1.0
var _canvas: Node2D


func _ready() -> void:
	layer = 2
	_canvas = Node2D.new()
	add_child(_canvas)
	_canvas.draw.connect(_draw_air)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var view := _view_size()
	for i in MOTES:
		# 画面の上 2/3 に多く
		_pos.append(Vector2(rng.randf() * view.x, pow(rng.randf(), 1.4) * view.y * 0.85))
		_size.append(rng.randf_range(MOTE_SIZE.x, MOTE_SIZE.y))
		_alpha.append(rng.randf_range(MOTE_ALPHA.x, MOTE_ALPHA.y))
		_phase.append(rng.randf() * TAU)


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	var tod := get_tree().get_first_node_in_group("time_of_day")
	var target: float = tod.daylight if tod and "daylight" in tod else 1.0
	_daylight = move_toward(_daylight, target, delta * 0.5)
	visible = _daylight > 0.01
	if not visible:
		return
	var reduced := UiAnim.reduced()
	var view := _view_size()
	var cam := get_viewport().get_camera_2d()
	var dx := 0.0
	if cam:
		var x := cam.get_screen_center_position().x
		if not is_nan(_cam_x):
			dx = x - _cam_x
		_cam_x = x
	if not reduced:
		_t += delta
		for i in MOTES:
			var p := _pos[i]
			p += DRIFT * delta * (0.6 + _size[i] / MOTE_SIZE.y)
			p.x += cos(_t * 0.7 + _phase[i]) * WOBBLE * delta
			p.y += sin(_t * 0.9 + _phase[i]) * WOBBLE * 0.6 * delta
			p.x -= dx * PARALLAX * (_size[i] / MOTE_SIZE.y)
			p.x = fposmod(p.x, view.x)
			p.y = fposmod(p.y, view.y * 0.9)
			_pos[i] = p
	_canvas.queue_redraw()


func _draw_air() -> void:
	var view := _view_size()
	var reduced := UiAnim.reduced()
	# 光の筋（上は少し明るく、下へ行くほど消える）
	for r in RAYS:
		var breath := 1.0 if reduced else 0.8 + 0.2 * sin(_t * 0.35 + r[0] * 9.0)
		var a: float = RAY_ALPHA * r[2] * breath * _daylight
		var x0: float = view.x * r[0]
		var w: float = r[1]
		var dir := Vector2(RAY_SLANT, 1.0).normalized() * RAY_LENGTH
		var pts := PackedVector2Array([Vector2(x0, -10), Vector2(x0 + w, -10), Vector2(x0 + w * 1.6, -10) + dir, Vector2(x0 + w * 0.2, -10) + dir])
		var top := Color(RAY_COLOR, a)
		var bottom := Color(RAY_COLOR, 0.0)
		_canvas.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
	# 光の粒
	for i in MOTES:
		var tw := 1.0 if reduced else 0.6 + 0.4 * sin(_t * 1.7 + _phase[i] * 3.0)
		var a := _alpha[i] * tw * _daylight
		_canvas.draw_circle(_pos[i], _size[i] * MOTE_HALO, Color(MOTE_COLOR, a * 0.22))
		_canvas.draw_circle(_pos[i], _size[i], Color(MOTE_COLOR, a))
