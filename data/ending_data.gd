class_name EndingData
extends Resource
## エンディング1つ分。DayList.endings の上から順に条件を見て、最初に合ったものになる。
## 条件が空のものはいつでも合うので、ふつうのエンディングとしていちばん下に置く

@export var id: StringName
@export var condition: FlagCondition
## エンディング画面の見出し
@export var title: String
## 宝箱の右の欄に出す、しめくくりの一言
@export_multiline var message: String
