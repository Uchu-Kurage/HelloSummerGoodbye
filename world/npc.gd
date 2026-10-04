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
var _present := true
## @leave で立ち去ったあと（フラグが変わっても戻ってこない）
var _left := false
var _player: Node2D
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	super()
	# 絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if npc_data:
		bubble_height = npc_data.height + 40.0
	# 出てくる条件に合わないときは、いないことにする（フラグが変わったら見直す）
	_present = FlagCondition.met(npc_data.appear_if) if npc_data else true
	visible = _present
	monitoring = _present
	GameState.flags_changed.connect(_on_flags_changed)
	body_entered.connect(_on_player_near)
	body_exited.connect(func(b): if b == _player: _player = null)
	_visual.draw.connect(_draw_body)


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
	return _present and npc_data != null and not npc_data.lines.is_empty()


func _on_player_near(b: Node) -> void:
	if not b is Player:
		return
	_player = b
	# 向こうから声をかけてくる人は、はじめて近づいたときに話しはじめる
	if npc_data and npc_data.auto_talk and can_interact() and not GameState.has_talked(npc_data.id):
		get_tree().call_group("interact_listener", "request_auto_talk", self)


## 近づいたら話しはじめるのを待っているか
func wants_auto_talk() -> bool:
	return npc_data != null and npc_data.auto_talk and can_interact() and not GameState.has_talked(npc_data.id)


## そっと立ち去る（会話の @leave）。右へ少し歩きながら消える
func leave() -> void:
	if _left:
		return
	_left = true
	_present = false
	_player = null
	_facing = 1.0
	set_deferred("monitoring", false)
	notify_left()
	var tw := create_tween().set_parallel().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_IN)
	if not UiAnim.reduced():
		tw.tween_property(self, "position:x", position.x + 160.0, UiTokens.TIME_FADE * 3)
	tw.tween_property(self, "modulate:a", 0.0, UiTokens.TIME_FADE * 3)
	tw.chain().tween_callback(hide)


func _on_flags_changed() -> void:
	var want := FlagCondition.met(npc_data.appear_if) if npc_data else true
	if _left or want == _present:
		return
	_present = want
	set_deferred("monitoring", want)
	if want:
		if not visible:
			modulate.a = 0.0
		UiAnim.fade(self, 1.0, UiTokens.TIME_FADE * 2)
	else:
		# そっといなくなる
		notify_left()
		UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 2)


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
	hud.start_talk(npc_data, lines, self)


## 姿。足もとが原点、+x が向いている方向（絵は右向きに描いてある）。
## 絵（sprite）があれば、高さ height にそろえて足もとに立たせる。なければ仮の姿を描く
func _draw_body() -> void:
	if npc_data == null:
		return
	if npc_data.sprite:
		var tex := npc_data.sprite
		var k := npc_data.height / tex.get_height()
		_visual.draw_texture_rect(tex, Rect2(-tex.get_width() * k / 2.0, -npc_data.height, tex.get_width() * k, npc_data.height), false)
		return
	_draw_placeholder()


## 仮の姿（絵が入るまで）
func _draw_placeholder() -> void:
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
	if d.hair_full:
		# 頭の上から後ろまでの髪
		v.draw_arc(head, head_r * 0.85, PI * 0.9, PI * 2.05, 16, d.hair_color, head_r * 0.45)
	else:
		# 横と後ろだけ残った髪
		v.draw_arc(head, head_r, PI * 0.55, PI * 1.25, 12, d.hair_color, head_r * 0.35)
	v.draw_circle(head + Vector2(head_r * 0.45, -head_r * 0.05), 2.5, WorldPalette.POLE)
