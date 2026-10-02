class_name DayStreamer
extends Node
## プレイヤーのいる日と次の日を読み込んでおき、画面の外に出た前の日を解放する。
## 日数が増えても、メモリに載るのは常に2〜3日分。

signal loaded_changed(count: int)

@export var container: Node2D
@export var player: Player
@export var camera: CameraController

## index -> DayBase
var _loaded: Dictionary = {}


func loaded_count() -> int:
	return _loaded.size()


func loaded_indices() -> Array:
	var keys := _loaded.keys()
	keys.sort()
	return keys


func player_day_index() -> int:
	return clampi(int(player.global_position.x / GameState.DAY_LENGTH_PX), 0, GameState.day_count() - 1)


func _ready() -> void:
	GameState.flags_changed.connect(_on_flags_changed)


func _process(_delta: float) -> void:
	update_now()


## フラグが立ったら、先の日（まだ入っていない日）の場面を差し替える。
## いまいる日と、通りすぎた日はそのまま
func _on_flags_changed() -> void:
	var cur := player_day_index()
	for i in _loaded.keys():
		if i <= cur:
			continue
		var path := GameState.day_scene_path(GameState.get_day(i))
		if (_loaded[i] as Node).scene_file_path != path:
			_loaded[i].queue_free()
			_loaded.erase(i)
			_load(i)


func update_now() -> void:
	if player == null:
		return
	var L := GameState.DAY_LENGTH_PX
	var cur := player_day_index()
	var changed := false
	for i in [cur, cur + 1]:
		if i < GameState.day_count() and not _loaded.has(i):
			_load(i)
			changed = true
	var cam_left := camera.left_edge() if camera else player.global_position.x
	for i in _loaded.keys():
		var gone_left: bool = i < cur and (i + 1) * L < cam_left
		if gone_left or i > cur + 1:
			_loaded[i].queue_free()
			_loaded.erase(i)
			changed = true
	if changed:
		loaded_changed.emit(_loaded.size())


func _load(i: int) -> void:
	var data := GameState.get_day(i)
	var packed: PackedScene = load(GameState.day_scene_path(data))
	var day: DayBase = packed.instantiate()
	day.day_data = data
	day.position = Vector2(i * GameState.DAY_LENGTH_PX, 0)
	container.add_child(day)
	_loaded[i] = day
