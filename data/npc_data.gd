class_name NpcData
extends Resource
## 村の人（NPC）1人分のデータ。せりふと仮の見た目をここで決める。

@export var id: StringName
@export var display_name: String
## 最初に話しかけたときのせりふ。1つずつ送って読む。ひらがな多めで短く（1つ全角20文字ほどまで）
@export var lines: Array[String] = []
## 2回目以降に話しかけたときのせりふ。空なら lines をくり返す
@export var repeat_lines: Array[String] = []
## 本番の絵。空のときは下の色で仮の姿を描く
@export var sprite: Texture2D
@export_group("仮の見た目")
## 一言パネルの左に出す色（アイコンのかわり）
@export var placeholder_color: Color = Color("#B8A58C")
@export var height := 170.0
@export var skin_color: Color = Color("#E2B894")
@export var hair_color: Color = Color("#D8D4CC")
@export var shirt_color: Color = Color("#F2F0EA")
@export var pants_color: Color = Color("#C9B79A")
## 少し前かがみにする（お年寄りなど）
@export var stoop := 0.0
