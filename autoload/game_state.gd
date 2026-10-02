extends Node
## ゲーム全体の状態（拾ったアイテム、現在の日など）。セーブはしない。

signal item_collected(item: ItemData)
signal day_changed(index: int)
## フラグが立ったとき（日の場面の差し替え、NPC の出入りに使う）
signal flags_changed

## 1日の横幅（px）。あとで調整する
const DAY_LENGTH_PX := 3840.0
## 夏休みの期間（仮）
const SUMMER_START := Vector2i(7, 20)
const SUMMER_END := Vector2i(8, 31)
const DAY_LIST_PATH := "res://data/day_list.tres"
const _MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var day_list: DayList
var current_day_index := 0
## id -> 拾った順の番号
var collected: Dictionary = {}
## 話しかけたことのある NPC の id
var talked: Dictionary = {}
## 立っているフラグ（エンディングの分岐など）。セーブはしない
var flags: Dictionary = {}


func _ready() -> void:
	day_list = load(DAY_LIST_PATH)


func reset() -> void:
	collected.clear()
	talked.clear()
	flags.clear()
	current_day_index = 0


func day_count() -> int:
	return day_list.days.size()


func get_day(index: int) -> DayData:
	return day_list.days[clampi(index, 0, day_count() - 1)]


func current_day() -> DayData:
	return get_day(current_day_index)


func world_length() -> float:
	return DAY_LENGTH_PX * day_count()


func set_current_day(index: int) -> void:
	if index == current_day_index:
		return
	current_day_index = index
	day_changed.emit(index)


func collect(item: ItemData) -> void:
	if is_collected(item.id):
		return
	collected[item.id] = collected.size()
	item_collected.emit(item)


func is_collected(id: StringName) -> bool:
	return collected.has(id)


func has_talked(id: StringName) -> bool:
	return talked.has(id)


func mark_talked(id: StringName) -> void:
	talked[id] = true


func has_flag(f: StringName) -> bool:
	return flags.has(f)


func set_flag(f: StringName) -> void:
	if flags.has(f):
		return
	flags[f] = true
	flags_changed.emit()


## その日に使う差し替え（なければ null）
func day_variant(d: DayData) -> DayVariant:
	for v in d.variants:
		if v and FlagCondition.met(v.condition):
			return v
	return null


func day_scene_path(d: DayData) -> String:
	var v := day_variant(d)
	return v.scene_path if v and v.scene_path != "" else d.scene_path


func day_title(d: DayData) -> String:
	var v := day_variant(d)
	return v.title if v and v.title != "" else d.title


## いまのフラグで迎えるエンディング（条件に合う最初のもの）
func current_ending() -> EndingData:
	for e in day_list.endings:
		if e and FlagCondition.met(e.condition):
			return e
	return null


func all_items() -> Array[ItemData]:
	return day_list.get_all_items()


func day_for_item(item: ItemData) -> DayData:
	for d in day_list.days:
		if d.day_number == item.day_number:
			return d
	return null


## 夏の進み具合（0.0〜1.0）。空の色・環境音などはこの値から決める
func summer_progress(month: int, day: int) -> float:
	var start := _day_of_year(SUMMER_START.x, SUMMER_START.y)
	var end := _day_of_year(SUMMER_END.x, SUMMER_END.y)
	return clampf(float(_day_of_year(month, day) - start) / float(end - start), 0.0, 1.0)


func summer_progress_of(d: DayData) -> float:
	return summer_progress(d.month, d.day)


static func _day_of_year(month: int, day: int) -> int:
	var n := day
	for m in range(month - 1):
		n += _MONTH_DAYS[m]
	return n
