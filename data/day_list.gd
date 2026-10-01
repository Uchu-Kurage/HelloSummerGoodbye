class_name DayList
extends Resource
## 日の並び順。40日版ではここに日を差し込む

@export var days: Array[DayData] = []


func get_all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for d in days:
		for it in d.items:
			out.append(it)
	return out
