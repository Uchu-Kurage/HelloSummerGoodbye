@tool
extends Node2D
## 毎日の道ばたの小物（電柱・木・立て札）。足もとが原点。
## 絵は手描き風（Google Gemini で生成し、背景を切り抜いたもの。res://world/scenery/painted/prop_*.png）。
## 足もとにはうすい影を描く（絵には地面の影を描いていないため）。

enum Kind { POLE, TREE, SIGN_POST }

## 絵：[テクスチャ, 足もとの x（絵の中の px）, 横の倍率, 縦の倍率]
const ART := {
	Kind.POLE: [preload("res://world/scenery/painted/prop_pole.png"), 127.0, 0.46, 0.46],
	Kind.TREE: [preload("res://world/scenery/painted/prop_tree.png"), 281.0, 0.55, 0.55],
	# 立て札は板に日付の文字を2行のせるので、縦に少しのばす（Sign/Board の位置はこの大きさに合わせてある）
	Kind.SIGN_POST: [preload("res://world/scenery/painted/prop_sign.png"), 428.0, 0.4, 0.6],
}
## 足もとの影：[横の半径, 縦の半径]
const SHADOWS := {
	Kind.POLE: Vector2(26, 6),
	Kind.TREE: Vector2(150, 16),
	Kind.SIGN_POST: Vector2(190, 9),
}
const SHADOW := Color(0.12, 0.16, 0.08, 0.22)

@export var kind: Kind = Kind.POLE:
	set(v):
		kind = v
		queue_redraw()


func _draw() -> void:
	var r: Vector2 = SHADOWS[kind]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, r.y / r.x))
	draw_circle(Vector2.ZERO, r.x, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var art: Array = ART[kind]
	var tex: Texture2D = art[0]
	var sz := tex.get_size() * Vector2(art[2], art[3])
	draw_texture_rect(tex, Rect2(Vector2(-float(art[1]) * art[2], -sz.y), sz), false)
