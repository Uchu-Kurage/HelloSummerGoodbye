extends Node
## ゲーム全体の状態（拾ったアイテム、現在の日など）。セーブはしない。

signal item_collected(item: ItemData)
## アイテムを手ばなしたとき（人にあげた・うめた）
signal item_gone(item: ItemData)
signal day_changed(index: int)
## フラグが立ったとき（日の場面の差し替え、NPC の出入りに使う）
signal flags_changed
## 秘密基地のすき間に材料をはめたとき
signal base_changed

## 1日の横幅（px）。あとで調整する
const DAY_LENGTH_PX := 3840.0
## 夏休みの期間（仮）
const SUMMER_START := Vector2i(7, 20)
const SUMMER_END := Vector2i(8, 31)
const DAY_LIST_PATH := "res://data/day_list.tres"
## 秘密基地づくりの材料（ミニゲームに並べる順）
const BASE_MATERIAL_PATHS := [
	"res://data/base_materials/wood.tres",
	"res://data/base_materials/tin.tres",
	"res://data/base_materials/blue_sheet.tres",
	"res://data/base_materials/sudare.tres",
]
## 秘密基地のすき間の数（屋根3か所：左・中・右、壁2か所：左・右）
const BASE_GAPS := 5
const _MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var day_list: DayList
var current_day_index := 0
## id -> 拾った順の番号
var collected: Dictionary = {}
## 人から「もらった」アイテムの id（宝箱の「〜に もらった」の表示用）
var received: Dictionary = {}
## 手ばなしたアイテム：id -> 宝箱の枠に出すひとこと（「タケルにあげた」「うめた」など）
var gone: Dictionary = {}
## 話しかけたことのある NPC の id
var talked: Dictionary = {}
## 立っているフラグ（エンディングの分岐など）。セーブはしない
var flags: Dictionary = {}
## 秘密基地のすき間（0〜4）-> はめた材料の id。4日目に作り、8・9日目はこれで見た目を組み立てる
var base_slots: Dictionary = {}
var _base_materials: Array[BaseMaterial] = []


func _ready() -> void:
	day_list = load(DAY_LIST_PATH)
	for path in BASE_MATERIAL_PATHS:
		_base_materials.append(load(path))


func reset() -> void:
	collected.clear()
	received.clear()
	gone.clear()
	talked.clear()
	flags.clear()
	base_slots.clear()
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


func collect(item: ItemData, from_someone := false) -> void:
	if is_collected(item.id):
		return
	collected[item.id] = collected.size()
	if from_someone:
		received[item.id] = true
	item_collected.emit(item)


func is_collected(id: StringName) -> bool:
	return collected.has(id)


## いま手もとにあるか（拾って、まだ手ばなしていない）
func holds(id: StringName) -> bool:
	return collected.has(id) and not gone.has(id)


func was_received(id: StringName) -> bool:
	return received.has(id)


## アイテムを手ばなす。宝箱の枠には note を出す
func give_away(item: ItemData, note: String) -> void:
	if not holds(item.id):
		return
	gone[item.id] = note
	item_gone.emit(item)


func gone_note(id: StringName) -> String:
	return gone.get(id, "")


## id からアイテムを探す（ルートの差し替えのアイテムも含む）
func find_item(id: StringName) -> ItemData:
	for d in day_list.days:
		for it in d.items:
			if it and it.id == id:
				return it
		for v in d.variants:
			if v == null:
				continue
			for it in v.items:
				if it and it.id == id:
					return it
	return null


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


func base_materials() -> Array[BaseMaterial]:
	return _base_materials


func base_material(id: StringName) -> BaseMaterial:
	for m in _base_materials:
		if m.id == id:
			return m
	return null


## そのすき間にはめた材料（まだなら null）
func base_slot(gap: int) -> BaseMaterial:
	return base_material(base_slots.get(gap, &""))


func set_base_slot(gap: int, material: BaseMaterial) -> void:
	base_slots[gap] = material.id
	base_changed.emit()


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


## その日に拾える／もらえるアイテム（ルートの差し替えがあればそちら）
func day_items(d: DayData) -> Array[ItemData]:
	var v := day_variant(d)
	return v.items if v and not v.items.is_empty() else d.items


## その日の進み具合（0.0〜1.0）を時間帯（朝 0.00〜夜 1.00）に直す
func day_time(d: DayData, progress: float) -> float:
	var v := day_variant(d)
	if v == null:
		return progress
	return lerpf(v.time_from, v.time_to, progress)


## 朝の色の上書き（なければ白）。dawn_until に向けて少しずつ消える
func day_tint(d: DayData, progress: float) -> Color:
	var v := day_variant(d)
	if v == null or v.dawn_tint == Color.WHITE:
		return Color.WHITE
	var k := 1.0 - smoothstep(0.0, maxf(v.dawn_until, 0.001), progress)
	return Color.WHITE.lerp(v.dawn_tint, k)


## いまのフラグで迎えるエンディング（条件に合う最初のもの）
func current_ending() -> EndingData:
	for e in day_list.endings:
		if e and FlagCondition.met(e.condition):
			return e
	return null


## 宝箱に並べる全アイテム（いまのフラグで決まるルートのもの）
func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for d in day_list.days:
		out.append_array(day_items(d))
	return out


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
