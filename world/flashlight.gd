extends Node2D
## 懐中電灯の明かり。プレイヤーの手もとから、向いているほうへ淡い光を伸ばす。GlowLayer の下に置く。

const REACH := 420.0
const SPREAD := 150.0
## 光を持つ手の高さ（足もとから）
const HAND_Y := -80.0

var _player: Node2D


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	queue_redraw()


func _draw() -> void:
	if _player == null or not _player.visible:
		return
	var layer := get_parent() as CanvasLayer
	var origin := _player.global_position - (layer.offset if layer else Vector2.ZERO) + Vector2(14, HAND_Y)
	var c := WorldPalette.FLASHLIGHT
	draw_colored_polygon(PackedVector2Array([origin, origin + Vector2(REACH, -SPREAD * 0.4), origin + Vector2(REACH, SPREAD * 0.9)]), c)
	draw_circle(origin + Vector2(REACH * 0.85, SPREAD * 0.3), SPREAD * 0.45, Color(c, c.a * 0.5))
