class_name DayVariant
extends Resource
## 日の場面の差し替え。条件に合えば、DayData の scene_path / title のかわりにこちらを使う。
## 例：フラグ route_takeru が立っていたら、4日目からはタケルのいる場面にする

@export var condition: FlagCondition
@export_file("*.tscn") var scene_path: String
## 空なら DayData の title のまま
@export var title: String
## 空でなければ、DayData の items のかわりにこちらを使う（ルート用のアイテム）
@export var items: Array[ItemData] = []
@export_group("時間帯")
## その日の進み具合 0.0〜1.0 を、時間帯のどこからどこまでに当てるか（朝 0.00／昼 0.25／夕方 0.60／夜 0.85）。
## 例：夕方〜夜だけの日は from 0.5、朝のうちに終わる日は to 0.3
@export_range(0.0, 1.0) var time_from := 0.0
@export_range(0.0, 1.0) var time_to := 1.0
## 朝の色をこの色で上書きする（早朝の暗く青い色など）。白なら上書きしない
@export var dawn_tint: Color = Color.WHITE
## dawn_tint が消えるまでの、その日の進み具合
@export_range(0.0, 1.0) var dawn_until := 0.25
