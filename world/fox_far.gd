@tool
class_name FoxFar
extends Node2D
## 遠くの田んぼに立っている、きつねのお面の子（1〜3日目。どのルートでも見える）。足もと（道）が原点。
## 道の向こう（田んぼの中）に小さく立ち、こちらを見ている。近づくと、すっと消える（その日はもう出ない）。

## 田んぼのあぜに立つ絵（水彩。正面を向き、足もとは稲にかくれている）
const TEX: Texture2D = preload("res://world/scenery/painted/fox_far.png")
## 遠くに見せるための大きさと、道からの奥行き（上へずらす）
const H := 150.0
const DEPTH := 40.0
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
		UiAnim.fade(self, 0.0, UiTokens.TIME_GLIMPSE_VANISH)


func _draw() -> void:
	var w := TEX.get_width() * H / TEX.get_height()
	# こちらを見て立つ。遠いので少しかすむ
	draw_texture_rect(TEX, Rect2(-w / 2.0, -DEPTH - H, w, H), false, Color(1, 1, 1, 0.88))
