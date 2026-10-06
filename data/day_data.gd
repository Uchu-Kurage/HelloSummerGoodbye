@tool
class_name DayData
extends Resource
## 1日分のデータ（DESIGN.md「6. データ設計」）。
## ここの時間帯・異界・縁側の値はノーマルルート（と、ルートが決まる前の共通の日）のもの。
## ほかのルートの日は DayVariant に同じ名前の値を持たせる（GameState が、選ばれた差し替えの値を読む）

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
## 時間帯のキー。x はその日の中の位置（0.0〜1.0）、y は時間の値（早朝 -0.15／朝 0.00／昼 0.25／夕方 0.60／夜 0.85／夜の終わり 1.00）。
## 空なら [(0, 0.00), (1, 1.00)]。x の小さい順に並べる。同じ x に2つ置くと、そこで時間が飛ぶ（暗転で隠す）
@export var time_keys: Array[Vector2] = []:
	set(v):
		time_keys = v
		TimeKeys.warn_if_unsorted(v, resource_path)
@export_group("異界と日付")
## 異界の日（神隠しルートの8・9日目）。色を褪せさせ、季節の色を止め、日付の札を「？？」にする
@export var is_otherworld := false
## 日付の札・日の切り替わりに出す日付を「月/日」の形で上書きする（例：「？？/？？」「8/16」）。空なら month/day。
## 宝箱の枠は本当の日付のまま（異界の日だけ「？？」）
@export var date_label_override := ""
@export_group("縁側の場面")
## 縁側の場面で、engawa_extra_flag が立っているときに返事のあとへ足す行（「おじいちゃん：……」のように話し手を頭に書く）
@export var engawa_extra_lines: Array[String] = []
## engawa_extra_lines を出す条件のフラグ名。空なら出さない
@export var engawa_extra_flag: StringName
