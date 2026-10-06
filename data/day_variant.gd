@tool
class_name DayVariant
extends Resource
## 日の場面の差し替え。条件に合えば、DayData の scene_path / title のかわりにこちらを使う。
## 例：フラグ route_takeru が立っていたら、4日目からはタケルのいる場面にする。
## 時間帯・異界・縁側の値は、差し替えが選ばれた日は DayData ではなくこちらを使う（空なら「指定なし」。DayData の値は見ない）

@export var condition: FlagCondition
@export_file("*.tscn") var scene_path: String
## 空なら DayData の title のまま
@export var title: String
## 空でなければ、DayData の items のかわりにこちらを使う（ルート用のアイテム）
@export var items: Array[ItemData] = []
@export_group("時間帯")
## 時間帯のキー（DayData.time_keys と同じ）。空なら [(0, 0.00), (1, 1.00)]。
## 例：神隠しルートの10日目は [(0, 0.90), (0.36, 0.90), (0.36, 0.00), (1, 0.15)]。飛ぶ x は TimeSkip の暗転の中に入れる
@export var time_keys: Array[Vector2] = []:
	set(v):
		time_keys = v
		TimeKeys.warn_if_unsorted(v, resource_path)
@export_group("異界と日付")
## 異界の日（DayData.is_otherworld と同じ）
@export var is_otherworld := false
## 日付の札に出す日付の上書き（DayData.date_label_override と同じ。例：神隠しルートの10日目は「8/16」。
## そのあと TimeSkip で本当の日付までめくれる）
@export var date_label_override := ""
@export_group("縁側の場面")
## DayData.engawa_extra_lines と同じ（例：神隠しのフラグが立った4日目の祖父のひとこと）
@export var engawa_extra_lines: Array[String] = []
@export var engawa_extra_flag: StringName
