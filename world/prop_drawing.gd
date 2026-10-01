@tool
extends Node2D
## 仮素材の小物（電柱・木・看板の柱など）を図形で描く。足もとが原点。

enum Kind { POLE, TREE, SIGN_POST }

@export var kind: Kind = Kind.POLE:
	set(v):
		kind = v
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.POLE:
			draw_rect(Rect2(-8, -420, 16, 420), WorldPalette.POLE)
			draw_rect(Rect2(-48, -390, 96, 10), WorldPalette.POLE)
			draw_rect(Rect2(-36, -350, 72, 8), WorldPalette.POLE)
		Kind.TREE:
			draw_rect(Rect2(-14, -260, 28, 260), WorldPalette.SIGN_POST)
			draw_circle(Vector2(0, -300), 110, WorldPalette.NEAR_BUSH)
			draw_circle(Vector2(-70, -240), 70, WorldPalette.GROUND_DARK)
			draw_circle(Vector2(70, -250), 80, WorldPalette.GROUND_DARK)
		Kind.SIGN_POST:
			draw_rect(Rect2(-6, -150, 12, 150), WorldPalette.SIGN_POST)
