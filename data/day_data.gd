class_name DayData
extends Resource
## 1日分のデータ（DESIGN.md「6. データ設計」）

@export var day_number: int = 1
@export var month: int = 7
@export var day: int = 21
@export var title: String
@export_file("*.tscn") var scene_path: String
@export var items: Array[ItemData] = []
## フラグによる場面の差し替え。上から順に見て、最初に条件が合ったものを使う
@export var variants: Array[DayVariant] = []
