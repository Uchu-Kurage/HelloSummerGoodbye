@tool
class_name TimeSkip
extends Node2D
## 時間が飛ぶところ（神隠しルートの10日目）。プレイヤーがここ（足もとが原点）まで来ると暗転し、
## 大きな日付が from_date から本当の日付（その日の DayData）まで、ぱらぱらとめくれる。
## 暗いあいだにプレイヤーを push だけ右へ送る。その先は、その日の time_keys で時間が飛んだあとで、時間帯が朝になる
## （同じ x に2つ置いたキーの x を、ここ〜ここ＋push のあいだ（その日の中の位置）に入れる）。
## 明けると日付の札も本当の日付にめくれる。

## めくりはじめる日付（目覚めたときの日付。送り火の夜）
@export var from_date := Vector2i(8, 16)
## めくれたあとのタイトル。空なら、その日のもとのタイトル（DayData.title）
@export var title := ""
## 暗いあいだにプレイヤーを右へ送る距離
@export var push := 240.0

var done := false
var _player: Player


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or done:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var hud := get_tree().get_first_node_in_group("interact_listener") as Hud
	var free := not _player.talking and not _player.locked and not (hud and hud.is_message_open())
	if _player.global_position.x >= global_position.x and free and not Transition.is_busy():
		_skip(hud)


func _day() -> DayData:
	var n := get_parent()
	while n and not n is DayBase:
		n = n.get_parent()
	return (n as DayBase).day_data if n else GameState.current_day()


## めくる日付の文字（from_date の次の日から、その日の本当の日付まで）
static func dates_between(from: Vector2i, to: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var m := from.x
	var d := from.y
	var guard := 0
	while guard < 400:
		guard += 1
		out.append(Strings.DATE_FULL % [str(m), str(d)])
		if m == to.x and d == to.y:
			break
		d += 1
		if d > GameState._MONTH_DAYS[m - 1]:
			d = 1
			m = m % 12 + 1
	return out


func _skip(hud: Hud) -> void:
	done = true
	_player.locked = true
	var dd := _day()
	var real := Vector2i(dd.month, dd.day)
	var t := title if title != "" else dd.title
	var on_dark := func():
		_player.position.x = global_position.x + push
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("snap"):
			cam.snap()
	var on_reveal := func():
		if hud:
			hud.flip_to_date(str(real.x), str(real.y), t)
	await Transition.play_date_riffle(dates_between(from_date, real), t, on_dark, on_reveal)
	_player.locked = false


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(0, -700), Vector2(0, 0), Color(0.9, 0.5, 0.3, 0.6), 4.0)
		draw_line(Vector2(push, -700), Vector2(push, 0), Color(0.9, 0.5, 0.3, 0.3), 2.0)
