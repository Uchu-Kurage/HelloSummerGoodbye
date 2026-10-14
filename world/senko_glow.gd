class_name SenkoGlow
extends Node2D
## 神社の石段の線香花火（演出。ミニゲームではない）。足もとが原点。火の玉は最後まで落ちない
## （子どものころは自分のが先に落ちた）。動きを減らす設定では、火花は動かさず、火の玉だけをうっすら脈打たせる。

var _t := 0.0


func _process(delta: float) -> void:
	if not UiAnim.reduced():
		_t += delta
	queue_redraw()


func _draw() -> void:
	var tip := Vector2(0, -70)
	draw_line(Vector2(0, 0), tip, Color("#C9B98F"), 3.0)
	var pulse := 1.0 + sin(_t * 5.0) * 0.06
	draw_circle(tip, 14.0 * pulse, Color(1.0, 0.65, 0.25, 0.35))
	draw_circle(tip, 8.0 * pulse, Color(1.0, 0.82, 0.45, 0.9))
	# 火花：ふくらんで消えるのをくり返す
	for i in 14:
		var ph := fposmod(_t * 1.3 + float(i) * 0.137, 1.0)
		var ang := float(i) * 0.9 + _t * 0.4
		var r := ph * 46.0
		var p := tip + Vector2(cos(ang), sin(ang)) * r
		draw_line(p, p + Vector2(cos(ang), sin(ang)) * 7.0, Color(1.0, 0.85, 0.5, 1.0 - ph), 2.0)
