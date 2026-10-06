@tool
class_name FoxFar
extends Node2D
## 遠くの田んぼに立っている、きつねのお面の子（1〜3日目。どのルートでも見える）。足もと（道）が原点。
## 道の向こう（田んぼの中）に小さく立ち、こちらを見ている。近づくと、すっと消える（その日はもう出ない）。

const TEX: Texture2D = preload("res://world/scenery/kamikakushi/fox_child.svg")
## 遠くに見せるための大きさと、道からの奥行き（上へずらす）
const H := 92.0
const DEPTH := 64.0
## この距離まで近づくと消えはじめ、VANISH_TO で消える
const VANISH_FROM := 620.0
const VANISH_TO := 460.0

var gone := false
var _player: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or gone:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var d := global_position.x - _player.global_position.x
	if d < VANISH_FROM:
		gone = true
		UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 1.5)


func _draw() -> void:
	var w := TEX.get_width() * H / TEX.get_height()
	# 左を向いて（こちらを見て）立つ。遠いので少しかすむ
	draw_set_transform(Vector2(0, -DEPTH), 0.0, Vector2(-1, 1))
	draw_texture_rect(TEX, Rect2(-w / 2.0, -H, w, H), false, Color(1, 1, 1, 0.88))
	draw_set_transform(Vector2.ZERO)
