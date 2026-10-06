@tool
class_name OtherworldZone
extends Node2D
## 異界（神隠しルート）。この日の from_x〜to_x（日の中の座標）を歩いている間は、景色の色が抜け、環境音がかわる。
## - 色：その日の小物と背景の層に、色を抜くシェーダー（desaturate.gdshader）をかける。時間帯の色（CanvasModulate）と空の色も褪せさせる（TimeOfDay.set_otherworld）。
##   主人公と、夜の灯り（GlowLayer の下。青い提灯など）は色のまま
## - 強さは strength（5日目の夜市はうすく、8・9日目はしっかり）。入るとき・出るときは ramp の幅でだんだん
## 新しい絵は描かず、ふだんの村の絵の色を抜いて使う。

const DESATURATE := preload("res://world/shaders/desaturate.gdshader")

@export var from_x := 0.0
@export var to_x := 3840.0
@export var ramp := 300.0
@export_range(0.0, 1.0) var strength := 1.0
## 異界にいる間の環境音（空なら、季節の蝉のまま）
@export var ambient := ""

var amount := 0.0
var _player: Node2D
var _mat: ShaderMaterial


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_mat = ShaderMaterial.new()
	_mat.shader = DESATURATE
	# 日のシーンの小物がそろってから（アイテムも置かれてから）かける
	_apply_material.call_deferred()


## その日のシーンの絵（Node2D）に色を抜くシェーダーをかける。文字の札（Control）・夜の灯り（GlowLayer）・
## もとからシェーダーのあるもの（川のふちのぼかしなど）はそのまま
func _apply_material() -> void:
	var day := get_parent()
	while day and not day is DayBase:
		day = day.get_parent()
	if day == null:
		day = get_parent()
	_walk(day)


func _walk(n: Node) -> void:
	if n is GlowLayer or n is Control or n is ItemPickup:
		return
	if n is CanvasItem and n != self and (n as CanvasItem).material == null:
		(n as CanvasItem).material = _mat
	for c in n.get_children():
		_walk(c)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var x := _player.global_position.x - global_position.x
	var a := minf(smoothstep(from_x, from_x + ramp, x), 1.0 - smoothstep(to_x - ramp, to_x, x)) if ramp > 0.0 \
		else (1.0 if x >= from_x and x <= to_x else 0.0)
	amount = a * strength
	if _mat:
		_mat.set_shader_parameter("amount", amount)
	# 日の中にいるときだけ知らせる（となりの日の異界と取り合わない）
	var day_x := _player.global_position.x - _day_left()
	if day_x >= 0.0 and day_x < GameState.DAY_LENGTH_PX:
		get_tree().call_group("time_of_day", "set_otherworld", amount, ambient, self)


func _day_left() -> float:
	var n := get_parent()
	while n and not n is DayBase:
		n = n.get_parent()
	return (n as Node2D).global_position.x if n else 0.0


func _exit_tree() -> void:
	if is_inside_tree():
		get_tree().call_group("time_of_day", "clear_otherworld", self)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(from_x, -700, to_x - from_x, 700), Color(0.6, 0.6, 0.7, 0.12))
