extends Node
## ゲーム全体の状態（拾ったアイテム、現在の日など）。セーブはしない。

signal item_collected(item: ItemData)
signal day_changed(index: int)

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


func _ready() -> void:
	day_list = load(DAY_LIST_PATH)


func reset() -> void:
	collected.clear()
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
