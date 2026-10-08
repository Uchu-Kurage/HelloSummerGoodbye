class_name EndingMarks
extends Control
## タイトル画面の、見たエンディングの数の印（4つの丸。見た数だけ塗る）。どれが足りないかは出さない。
## 紙の小札（PaperChip）の中に置く。

const DOT_R := 7.0
const GAP := 10.0
const LINE := 2.0

var seen := 0:
	set(v):
		seen = v
		queue_redraw()
var total := 4


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(total * DOT_R * 2.0 + (total - 1) * GAP, DOT_R * 2.0 + LINE * 2.0)


func _draw() -> void:
	for i in total:
		var c := Vector2(DOT_R + i * (DOT_R * 2.0 + GAP), size.y / 2.0)
		if i < seen:
			draw_circle(c, DOT_R, UiTokens.ACCENT_INK)
		else:
			draw_arc(c, DOT_R - LINE / 2.0, 0, TAU, 24, UiTokens.INK_SOFT, LINE, true)
