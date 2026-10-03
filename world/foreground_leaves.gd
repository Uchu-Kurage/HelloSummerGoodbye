class_name ForegroundLeaves
extends Node2D
## 手前の木の枝。画面の上から葉の茂った枝がときどき垂れ下がり、主人公より手前をゆっくり通りすぎる（木漏れ日の縁どり）。
## Parallax2D（scroll_scale 1 より大きい）の子に置き、width で一周する。
## 絵は手描き風の枝（Google Gemini で生成し、背景を切り抜いたもの）。左上から日が当たる。
## 付け根（絵の上のまん中）を軸に、風でゆっくりゆれる。動きを減らす設定ではゆらさない。

const BRANCH_TEX: Texture2D = preload("res://world/scenery/painted/branch.png")
## ゆれ（ラジアン）と速さ
const SWAY := 0.012
const SWAY_SPEED := 0.8

## 枝：[x（割合）, 大きさ]
@export var branches: Array = [[0.12, 0.62], [0.62, 0.5]]
@export var width := 3400.0
## 絵の上端の高さ（画面の上端より少し上）
@export var top_y := -8.0

var _t := 0.0


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	if UiAnim.reduced():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var size := BRANCH_TEX.get_size()
	for i in branches.size():
		var b: Array = branches[i]
		var sz := size * float(b[1])
		var root := Vector2(width * float(b[0]), top_y)
		var sway := sin(_t * SWAY_SPEED + i * 1.7) * SWAY + sin(_t * SWAY_SPEED * 2.3 + i) * SWAY * 0.3
		draw_set_transform(root, sway, Vector2.ONE)
		draw_texture_rect(BRANCH_TEX, Rect2(Vector2(-sz.x * 0.5, 0), sz), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
