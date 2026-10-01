class_name DayData
extends Resource
## 1日分のデータ（DESIGN.md「6. データ設計」）

@export var day_number: int = 1
@export var month: int = 7
@export var day: int = 21
@export var title: String
@export_file("*.tscn") var scene_path: String
@export var items: Array[ItemData] = []
