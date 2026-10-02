class_name DayList
extends Resource
## 日の並び順。40日版ではここに日を差し込む

@export var days: Array[DayData] = []
## エンディング。上から順に条件を見て、最初に合ったものになる（いちばん下は条件なしのふつうのエンディング）
@export var endings: Array[EndingData] = []


func get_all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for d in days:
		for it in d.items:
			out.append(it)
	return out
