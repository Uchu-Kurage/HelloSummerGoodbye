@tool
class_name TalkCue
extends Node2D
## 決まった場所で、ひとりごとや音を出す（神隠しルート：鈴がひとりでに鳴る、神社で目を覚ます、など）。足もとが原点。
## プレイヤーがここまで来て手があいていたら、sfx を鳴らし、lines を会話として読ませる（書き方は NpcData と同じ。
## 「ぼく：」のついた行は主人公、ついていない行は名前なしの地の文）。1回だけ。
## require_item を持っていないときは何もしない。

@export var lines: Array[String] = []
@export var sfx := ""
@export var require_item: StringName

var done := false
var _player: Player


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or done:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	if _player.global_position.x < global_position.x:
		return
	if require_item != &"" and not GameState.holds(require_item):
		done = true
		return
	var hud := get_tree().get_first_node_in_group("interact_listener") as Hud
	if hud == null or _player.talking or _player.locked or hud.is_message_open() or Transition.is_busy() or get_tree().paused:
		return
	done = true
	if sfx != "":
		SfxPlayer.play(sfx)
	var me := NpcData.new()
	me.id = StringName("cue_" + name)
	me.display_name = ""
	me.placeholder_color = WorldPalette.PLAYER_HAT
	hud.start_talk(me, lines)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(0, -400), Vector2.ZERO, Color(0.5, 0.7, 0.9, 0.6), 3.0)
