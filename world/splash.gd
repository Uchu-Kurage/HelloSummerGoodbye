extends Node2D
## 飛び込んだときの水しぶき。会話の @event splash で上がる。

var _t := -1.0

const DURATION := 1.2


func on_talk_event(event_name: String) -> void:
	if event_name == "splash":
		_t = 0.0
		SfxPlayer.play("splash")


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t > DURATION:
		_t = -1.0
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var k := _t / DURATION
	var c := Color(WorldPalette.WATER_LIGHT, 1.0 - k)
	for i in 9:
		var ang := PI + PI * (i + 0.5) / 9.0
		var d := 30.0 + 140.0 * k
		var p := Vector2(cos(ang) * d * 0.8, sin(ang) * d * (1.2 - k))
		draw_circle(p, 10.0 * (1.0 - k) + 3.0, c)
	draw_arc(Vector2.ZERO, 40.0 + 120.0 * k, PI, TAU, 24, c, 4.0)
