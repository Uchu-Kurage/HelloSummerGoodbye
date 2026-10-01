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
