@tool
class_name SmokeGate
extends Node2D
## 送り火の煙のむこう（神隠しルートの7日目）。足もとのまん中が原点。
## 送り火の煙が道に流れている。会話の @event（thick_on_event）で煙が濃くなり、くぐりぬけると、
## 日付の札が「？？」にめくれる（異界に入った）。くぐる前は、鈴がかすかに鳴る。

## 煙の幅（原点を中心に）
@export var width := 520.0
## この @event で煙が濃くなる（お面の子が煙のむこうへ歩いていく）
@export var thick_on_event := "smoke"
## くぐったあと、日付の札に出すタイトル
@export var title := ""

const PUFFS := 26
const SMOKE := Color(0.86, 0.86, 0.84, 1.0)

var crossed := false
var _thick := 0.35
var _t := 0.0
var _player: Node2D


func on_talk_event(event_name: String) -> void:
	if event_name == thick_on_event:
		var tw := create_tween().set_trans(UiTokens.TRANS)
		tw.tween_property(self, "_thick", 1.0, UiTokens.TIME_FADE * 3)
		SfxPlayer.play("suzu_far")


func _process(delta: float) -> void:
	if not UiAnim.reduced():
		_t += delta
	queue_redraw()
	if Engine.is_editor_hint() or crossed:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if _player.global_position.x >= global_position.x:
		crossed = true
		SfxPlayer.play("suzu")
		var hud := get_tree().get_first_node_in_group("interact_listener") as Hud
		if hud:
			hud.flip_to_date(Strings.DATE_UNKNOWN, Strings.DATE_UNKNOWN, title)


func _draw() -> void:
	# 下から上へ、ゆっくりのぼって横に流れる煙のかたまり
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in PUFFS:
		var bx := rng.randf_range(-width / 2.0, width / 2.0)
		var speed := rng.randf_range(14.0, 28.0)
		var ph := rng.randf()
		var k := fposmod(ph + _t * speed / 420.0, 1.0)
		var p := Vector2(bx + sin(_t * 0.4 + i) * 30.0 + k * 60.0, -k * 420.0)
		var r := rng.randf_range(40, 80) * (0.6 + k)
		var a := 0.22 * _thick * sin(k * PI)
		draw_circle(p, r, Color(SMOKE, a))
