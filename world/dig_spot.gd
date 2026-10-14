class_name DigSpot
extends ExamineSpot
## 掘るところ（急の造成地）。スコップを借りたあとは、立っているどこでも「ほる」が出る。
## 重なっていない場所でも掘れるが、何も出てこない（青年期の空振りと同じ）。
## 鳥居と山のてっぺんが重なって見える場所（ToriiPeakView.is_overlapping）で掘ると、決定を数回押して掘り進め、スコップの先に硬いものが当たる。
## 破で秘密の場所を教わっているので、必ずたどり着ける。見つけたら @event open_can で缶の画面へ。
## 場所は主人公についてくる（足もとが常にここ）。スコップを借りる（need_flag）まで、吹き出しは出ない。

@export var view: NodePath
@export var need_flag: StringName = &"chapter_shovel"
@export var hit_lines: Array[String] = []
@export var miss_lines: Array[String] = []

var dug := false
var _active := false
var _follow: Node2D


func _ready() -> void:
	kind = ChapterArt.Kind.NONE
	super()


func can_interact() -> bool:
	return _active and not dug and not GameState.chapter_dug()


func requirements_met() -> bool:
	return true


func bubble_text(touch: bool) -> String:
	return Strings.DIG_TOUCH if touch else Strings.DIG_KEY


func interact(hud: Node) -> void:
	if not can_interact():
		return
	var v := get_node_or_null(view) as ToriiPeakView
	var hit := v != null and v.is_overlapping()
	dug = hit
	hud.start_talk(npc_data, hit_lines if hit else miss_lines, null, self)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _follow == null or not is_instance_valid(_follow):
		_follow = get_tree().get_first_node_in_group("player") as Node2D
		if _follow == null:
			return
	global_position.x = _follow.global_position.x
	# この日の中にいるあいだだけ（となりの日を読み込んだだけでは、前の日に「ほる」を出さない）
	var on := GameState.has_flag(need_flag) and not dug and _follow.global_position.x >= _day_left()
	if on == _active:
		return
	_active = on
	if on:
		# スコップを借りた瞬間に、いま重なっている主人公を数えなおす
		monitoring = false
		await get_tree().physics_frame
		monitoring = true
	else:
		notify_left()


func _day_left() -> float:
	var n := get_parent()
	while n and not n is DayBase:
		n = n.get_parent()
	return (n as Node2D).global_position.x if n else 0.0
