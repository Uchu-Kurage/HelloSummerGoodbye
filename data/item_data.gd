class_name ItemData
extends Resource
## 夏の宝物 1つ分のデータ（DESIGN.md「6. データ設計」）

@export var id: StringName
@export var display_name: String
## 拾ったときの一言。ひらがな多めで短く
@export_multiline var description: String
## 画像。空のときは placeholder_color の四角で表示する
@export var icon: Texture2D
@export var day_number: int = 1
## 仮素材の色（icon が空のとき用）
@export var placeholder_color: Color = Color("#C9A66B")
## 道に置くか。false なら人から「もらう」だけのもの（会話の @give で手に入る）
@export var on_ground := true
## 拾ったとき、一言の前に読ませる文（置き手紙の中身など）。空なら出さない
@export_multiline var read_text: String
## 空でなければ、手に入れたときにこのフラグを立てる（日の場面の差し替えの条件に使う。例：さびた鈴 → 4日目の神社）
@export var collect_flag: StringName
## 拾い逃したときに宝箱の影で出す、だいたいの場所（「かわら」→「かわらの どこか」）。10日目のものは空でよい
@export var place_hint: String
@export_group("ルートで一言を変える")
## この条件が合うときは description のかわりに alt_description を出す
@export var alt_if: FlagCondition
@export_multiline var alt_description: String
## この条件が合うときは place_hint のかわりに出す場所（空なら place_hint のまま）
@export var alt_place_hint: String


## いまのフラグで出す一言
func text() -> String:
	if alt_description != "" and alt_if and alt_if.is_met():
		return alt_description
	return description


## いまのフラグで出す場所のヒント
func place_hint_text() -> String:
	if alt_place_hint != "" and alt_if and alt_if.is_met():
		return alt_place_hint
	return place_hint
