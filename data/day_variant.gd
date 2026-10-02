class_name DayVariant
extends Resource
## 日の場面の差し替え。条件に合えば、DayData の scene_path / title のかわりにこちらを使う。
## 例：フラグ route_boy が立っていたら、5日目は男の子のいる夏祭りの場面にする

@export var condition: FlagCondition
@export_file("*.tscn") var scene_path: String
## 空なら DayData の title のまま
@export var title: String
