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
## 宝箱の枠に数えないアイテム（道には置かず、会話の @drop で落ちる。人に返すものなど）。
## 持っているあいだだけ宝箱に出る（例：1日目になつみが落とす色えんぴつ）
@export var extra_items: Array[ItemData] = []
@export_group("時間帯")
## ふつうの場面（差し替えがないとき）の時間帯の範囲。DayVariant の time_from / time_to と同じ（朝 0.00／昼 0.25／夕方 0.60／夜 0.85）。
## 例：夕方〜夜だけの日は from 0.5、夜だけの日は from 0.86
@export_range(0.0, 1.0) var time_from := 0.0
@export_range(0.0, 1.0) var time_to := 1.0
