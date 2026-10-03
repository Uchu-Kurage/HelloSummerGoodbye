class_name Furin
extends Node2D
## 軒先の風鈴。原点が吊るす場所。ガラスの丸い鉢、中の舌（ぜつ）、その下の短冊。
## いつも風でかすかにゆれ、ときどき風が吹くと大きめにゆれて「チリン」と鳴る（furin）。
## 主人公が近くにいるときだけ鳴らし、遠いほど小さくする。動きを減らす設定ではゆらさない（音は鳴る）。

const GLASS := Color(0.72, 0.86, 0.95, 0.62)
const GLASS_RIM := Color(0.55, 0.72, 0.84, 0.9)
const GLASS_SHINE := Color(1.0, 1.0, 1.0, 0.85)
## 鉢に描いた金魚の赤
const PAINT := Color("#C8553D")
const STRING := Color(0.3, 0.27, 0.24, 0.9)
const TANZAKU := Color("#F1DDB0")
const TANZAKU_LINE := Color("#C9A86A")
const BOWL_R := 22.0
const STRING_LEN := 30.0
const TONGUE_LEN := 30.0
const TANZAKU_SIZE := Vector2(16.0, 58.0)
## ふだんのゆれと、風が吹いたときのゆれ（ラジアン）
const IDLE_SWAY := 0.04
const GUST_SWAY := 0.16
## 風が吹く間隔（秒）
const GUST_EVERY := Vector2(5.0, 11.0)
## 鳴らす距離（主人公との横の距離 px）と、いちばん遠いときの小ささ（dB）
const HEAR_RANGE := 900.0
const FAR_DB := -16.0

var _t := 0.0
var _gust := 0.0
var _next_gust := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_next_gust = _rng.randf_range(1.5, GUST_EVERY.x)


func _process(delta: float) -> void:
	_t += delta
	_gust = maxf(0.0, _gust - delta * 0.45)
	_next_gust -= delta
	if _next_gust <= 0.0:
		_next_gust = _rng.randf_range(GUST_EVERY.x, GUST_EVERY.y)
		_gust = 1.0
		_ring()
	if not UiAnim.reduced():
		queue_redraw()


func _ring() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_visible_in_tree():
		return
	var dist := absf(player.global_position.x - global_position.x)
	if dist > HEAR_RANGE:
		return
	SfxPlayer.play("furin", lerpf(-2.0, FAR_DB, dist / HEAR_RANGE))


func _draw() -> void:
	var still := UiAnim.reduced()
	var amp := IDLE_SWAY + GUST_SWAY * _gust
	var a := 0.0 if still else sin(_t * 2.1) * amp + sin(_t * 3.7) * amp * 0.25
	# 吊りひもと鉢（鉢は吊るす場所を中心に少しゆれる）
	draw_set_transform(Vector2.ZERO, a * 0.5, Vector2.ONE)
	draw_line(Vector2.ZERO, Vector2(0, STRING_LEN), STRING, 1.5, true)
	var c := Vector2(0, STRING_LEN + BOWL_R)
	var dome := PackedVector2Array()
	for i in 17:
		dome.append(c + Vector2.from_angle(PI + PI * i / 16.0) * BOWL_R)
	dome.append(c + Vector2(BOWL_R, 3))
	dome.append(c + Vector2(-BOWL_R, 3))
	draw_colored_polygon(dome, GLASS)
	# 金魚の模様と、ふち、光
	draw_circle(c + Vector2(-6, -7), 4.0, PAINT)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -7), c + Vector2(3, -11), c + Vector2(3, -3)]), PAINT)
	draw_line(c + Vector2(-BOWL_R, 3), c + Vector2(BOWL_R, 3), GLASS_RIM, 2.0, true)
	draw_arc(c, BOWL_R - 4.0, PI * 1.15, PI * 1.45, 6, GLASS_SHINE, 2.5, true)
	# 舌と短冊は、鉢より大きくゆれる
	var tongue_top := c + Vector2(0, -2)
	draw_set_transform(tongue_top.rotated(a * 0.5), a * 1.4, Vector2.ONE)
	draw_line(Vector2.ZERO, Vector2(0, TONGUE_LEN), STRING, 1.2, true)
	draw_rect(Rect2(-2.5, 6, 5, 6), Color(0.45, 0.4, 0.35))
	var tz := Vector2(0, TONGUE_LEN)
	draw_set_transform(tongue_top.rotated(a * 0.5) + tz.rotated(a * 1.4), a * 2.2, Vector2.ONE)
	draw_rect(Rect2(-TANZAKU_SIZE.x / 2.0, 0, TANZAKU_SIZE.x, TANZAKU_SIZE.y), TANZAKU)
	draw_line(Vector2(-2, 8), Vector2(-2, TANZAKU_SIZE.y - 10), TANZAKU_LINE, 1.5)
	draw_line(Vector2(2, 14), Vector2(2, TANZAKU_SIZE.y - 16), TANZAKU_LINE, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
