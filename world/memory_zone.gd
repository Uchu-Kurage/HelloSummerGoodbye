class_name MemoryZone
extends Node2D
## 老年期の村の「今 → 子どものころが一瞬重なる → 青年期の回想 → 今」（章「あの夏へ」）。足もとが原点。
## 子ノード：Now（いまの景色の小物）、Ghost（重なる子どものころの姿。回想より前の1〜2秒だけ）、Memory（青年期の回想の小物・人）。
## 老人の主人公がここまで来ると、Ghost がゆらいで重なり、温かい色の回想へ移る（主人公は青年に）。
## 回想の中の会話の @event で終わる（memory_event。または count_event が count_needed 回）。
## 終わると今にもどり（主人公は老人）、after_lines（心の声）を読む。決定キー・会話は ふだんどおり。

enum State { IDLE, GHOST, MEMORY, DONE }

## この @event が来たら回想が終わる
@export var memory_event := ""
## この @event を count_needed 回受けても回想が終わる（雑木林で3か所掘る、など）
@export var count_event := ""
@export var count_needed := 0
## 今にもどってから読む心の声（「ぼく：（……）」の形。@event も使える）
@export var after_lines: Array[String] = []
## 回想の温かい色（画面にかぶせる）
@export var tint := Color(1.0, 0.78, 0.5, 0.2)

var state := State.IDLE
var _count := 0
var _player: Player
var _tint_rect: ColorRect
var _tint_layer: CanvasLayer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var ghost := _group("Ghost")
	if ghost:
		ghost.modulate.a = 0.0
	var memory := _group("Memory")
	if memory:
		memory.modulate.a = 0.0
		memory.visible = false
		_set_active(memory, false)


func _group(n: String) -> Node2D:
	return get_node_or_null(n) as Node2D


func _process(_delta: float) -> void:
	if state != State.IDLE:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	if _player.global_position.x < global_position.x:
		return
	var hud := get_tree().get_first_node_in_group("interact_listener") as Hud
	if hud == null or _player.talking or _player.locked or hud.is_message_open() or Transition.is_busy() or get_tree().paused:
		return
	_begin(hud)


func _begin(hud: Hud) -> void:
	state = State.GHOST
	_player.locked = true
	await _flicker()
	await _to_memory()
	state = State.MEMORY
	_player.locked = false


## 子どものころが一瞬重なる（1〜2秒）。動きを減らす設定では、ゆっくり見えて消えるだけ
func _flicker() -> void:
	var ghost := _group("Ghost")
	if ghost == null:
		return
	var tw := create_tween().set_trans(UiTokens.TRANS)
	if UiAnim.reduced():
		tw.tween_property(ghost, "modulate:a", 0.8, UiTokens.TIME_MEMORY_GHOST * 0.4)
		tw.tween_interval(UiTokens.TIME_MEMORY_GHOST * 0.2)
		tw.tween_property(ghost, "modulate:a", 0.0, UiTokens.TIME_MEMORY_GHOST * 0.4)
	else:
		var t := UiTokens.TIME_MEMORY_GHOST
		tw.tween_property(ghost, "modulate:a", 0.7, t * 0.28)
		tw.tween_property(ghost, "modulate:a", 0.2, t * 0.18)
		tw.tween_property(ghost, "modulate:a", 0.85, t * 0.22)
		tw.tween_property(ghost, "modulate:a", 0.0, t * 0.32)
	await tw.finished


func _to_memory() -> void:
	_ensure_tint()
	var memory := _group("Memory")
	var now := _group("Now")
	if memory:
		memory.visible = true
		_set_active(memory, true)
	_player.set_form(DayData.Form.YOUTH)
	var tw := create_tween().set_parallel().set_trans(UiTokens.TRANS)
	tw.tween_property(_tint_rect, "color:a", tint.a, UiTokens.TIME_MEMORY_FADE)
	if memory:
		tw.tween_property(memory, "modulate:a", 1.0, UiTokens.TIME_MEMORY_FADE)
	if now:
		tw.tween_property(now, "modulate:a", 0.0, UiTokens.TIME_MEMORY_FADE)
	await tw.finished
	if now:
		now.visible = false


func _ensure_tint() -> void:
	if _tint_layer:
		return
	_tint_layer = CanvasLayer.new()
	_tint_layer.layer = 5
	add_child(_tint_layer)
	_tint_rect = ColorRect.new()
	_tint_rect.color = Color(tint.r, tint.g, tint.b, 0.0)
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_layer.add_child(_tint_rect)


## 会話の @event（DayBase.on_talk_event から）
func on_talk_event(event_name: String) -> void:
	if state != State.MEMORY:
		return
	if memory_event != "" and event_name == memory_event:
		_end_memory.call_deferred()
	elif count_event != "" and event_name == count_event:
		_count += 1
		if _count >= count_needed:
			_end_memory.call_deferred()


func _end_memory() -> void:
	if state != State.MEMORY:
		return
	state = State.DONE
	var hud := get_tree().get_first_node_in_group("interact_listener") as Hud
	# 会話の最後まで読んでから、今へもどる
	if hud and hud.is_talking():
		await hud.talk_finished
	_player.locked = true
	var memory := _group("Memory")
	var now := _group("Now")
	if now:
		now.visible = true
	var tw := create_tween().set_parallel().set_trans(UiTokens.TRANS)
	tw.tween_property(_tint_rect, "color:a", 0.0, UiTokens.TIME_MEMORY_FADE)
	if memory:
		tw.tween_property(memory, "modulate:a", 0.0, UiTokens.TIME_MEMORY_FADE)
	if now:
		tw.tween_property(now, "modulate:a", 1.0, UiTokens.TIME_MEMORY_FADE)
	await tw.finished
	if memory:
		memory.visible = false
		_set_active(memory, false)
	_player.set_form(DayData.Form.ELDER)
	_player.locked = false
	if hud and not after_lines.is_empty():
		var me := NpcData.new()
		me.id = StringName("memory_after_" + name)
		me.display_name = ""
		me.placeholder_color = WorldPalette.PLAYER_HAT
		await hud.run_talk(me, after_lines, self)


## 回想の小物（調べるところ・人）が、出ていないあいだは反応しないようにする
func _set_active(n: Node, on: bool) -> void:
	if n is Area2D:
		(n as Area2D).set_deferred("monitoring", on)
		(n as Area2D).set_deferred("monitorable", on)
	for c in n.get_children():
		_set_active(c, on)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(0, -400), Vector2.ZERO, Color(1.0, 0.7, 0.3, 0.7), 4.0)
