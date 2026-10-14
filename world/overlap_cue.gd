class_name OverlapCue
extends Node2D
## 鳥居と山のてっぺんが重なって見えたとき（ToriiPeakView.is_overlapping）に、せりふを自動で読ませる。1回だけ。
## require_flags が立っていないあいだは何も起きない（タケルに手まねきされるまでは、重なっても気づかない）。

@export var view: NodePath
@export var require_flags: Array[StringName] = []
@export var lines: Array[String] = []
@export var done_flag: StringName

var done := false
var _player: Player


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or done:
		return
	var v := get_node_or_null(view) as ToriiPeakView
	if v == null:
		return
	for f in require_flags:
		if not GameState.has_flag(f):
			return
	if not v.is_overlapping():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var hud := get_tree().get_first_node_in_group("interact_listener") as Hud
	if hud == null or _player.talking or _player.locked or hud.is_message_open() or Transition.is_busy() or get_tree().paused:
		return
	done = true
	if done_flag != &"":
		GameState.set_flag(done_flag)
	var me := NpcData.new()
	me.id = StringName("overlap_" + name)
	me.display_name = ""
	me.placeholder_color = WorldPalette.PLAYER_HAT
	hud.start_talk(me, lines, null, self)
