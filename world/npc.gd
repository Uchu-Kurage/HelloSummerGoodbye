class_name Npc
extends Interactable
## 村の人（NPC）。近づくと「E」／「はなす」の吹き出しが出て、話しかけるとせりふを順に読める。
## 見た目とせりふは NpcData で決める。日のシーンの Props の下などに置いて使う。

@export var npc_data: NpcData

## 呼吸のようなごく小さな動き
const BREATH_SPEED := 1.6
const BREATH_AMOUNT := 1.5

var _t := 0.0
var _facing := -1.0
var _player: Node2D
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	super()
	if npc_data:
		bubble_height = npc_data.height + 40.0
		if npc_data.sprite:
			var s := Sprite2D.new()
			s.texture = npc_data.sprite
			s.offset = Vector2(0, -npc_data.sprite.get_height() / 2.0)
			_visual.add_child(s)
	body_entered.connect(func(b): if b is Player: _player = b)
	body_exited.connect(func(b): if b == _player: _player = null)
	_visual.draw.connect(_draw_placeholder)


func _process(delta: float) -> void:
	# 近くにプレイヤーがいたら、そちらを向く
	if _player and is_instance_valid(_player):
		_facing = signf(_player.global_position.x - global_position.x)
		if _facing == 0.0:
			_facing = 1.0
	_visual.scale.x = _facing
	if not UiAnim.reduced():
		_t += delta
	_visual.scale.y = 1.0 + sin(_t * BREATH_SPEED) * BREATH_AMOUNT / 100.0
	_visual.queue_redraw()


func can_interact() -> bool:
	return npc_data != null and not npc_data.lines.is_empty()


func bubble_text(touch: bool) -> String:
	return Strings.TALK_TOUCH if touch else Strings.TALK_KEY


func interact(hud: Node) -> void:
	if not can_interact():
		return
	var talked := GameState.has_talked(npc_data.id)
	var lines := npc_data.lines
	if talked and not npc_data.repeat_lines.is_empty():
		lines = npc_data.repeat_lines
	GameState.mark_talked(npc_data.id)
	hud.start_talk(npc_data, lines)


## 仮の姿（絵が入るまで）。足もとが原点、+x が向いている方向
func _draw_placeholder() -> void:
	if npc_data == null or npc_data.sprite:
		return
	var d := npc_data
	var v := _visual
	var h := d.height
	var leg := h * 0.3
	var body := h * 0.36
	var head_r := h * 0.12
	var lean := d.stoop
	v.draw_rect(Rect2(-12, -leg, 10, leg), d.skin_color)
	v.draw_rect(Rect2(3, -leg, 10, leg), d.skin_color)
	v.draw_rect(Rect2(-17, -leg - h * 0.12, 34, h * 0.14), d.pants_color)
	var top := -leg - h * 0.1 - body
	v.draw_colored_polygon(PackedVector2Array([
		Vector2(-19, -leg - h * 0.1), Vector2(19, -leg - h * 0.1),
		Vector2(19 + lean, top), Vector2(-19 + lean, top)]), d.shirt_color)
	var head := Vector2(lean * 1.6, top - head_r * 0.9)
	v.draw_circle(head, head_r, d.skin_color)
	# 横と後ろだけ残った髪
	v.draw_arc(head, head_r, PI * 0.55, PI * 1.25, 12, d.hair_color, head_r * 0.35)
	v.draw_circle(head + Vector2(head_r * 0.45, -head_r * 0.05), 2.5, WorldPalette.POLE)
