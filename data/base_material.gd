class_name BaseMaterial
extends Resource
## 秘密基地づくり（4日目のミニゲーム）の材料1つ分。すき間にはめると、8・9日目までその形のまま残る。
## 正解はない。数の制限もなく、同じ材料を何か所に使ってもよい。

enum Look { WOOD, TIN, SHEET, SUDARE }

@export var id: StringName
@export var display_name: String
## 仮素材の描き方（本番の絵が入るまで）
@export var look: Look = Look.WOOD
@export var color: Color = Color("#8A6A4A")
@export var color_2: Color = Color("#6B5038")
## 本番の絵（すき間ごとの差分）。空のときは look と色で描く
@export var texture: Texture2D
## はめたときの効果音（SfxPlayer の名前）
@export var place_sfx := ""
## 屋根をこの材料でふさいだときの雨の音（環境音の名前）
@export var roof_rain_ambient := ""
## 雨が少し入る（すだれ）。ふさいでも雨だれが細く残る
@export var leaks := false
## はめたときのタケルの一言
@export var takeru_line := ""
## 夜（9日目）の見え方のメモ。見た目は look ごとに描く
@export_multiline var night_note := ""
