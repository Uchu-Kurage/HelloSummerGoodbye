class_name SkipStone
extends Resource
## 石切り（3日目のミニゲーム）の石1つ分。足もとに3つ並び、選んだ石で跳ねやすさが変わる。
## 正解を教えるのは、選んだときのタケルの一言だけ。

enum Look { FLAT, ROUND, BIG }

@export var id: StringName
@export var display_name: String
## いちばんうまく投げたときに跳ねる回数
@export var max_skips := 3
## 選んだときのタケルの一言
@export var takeru_line := ""
## 仮素材の描き方（本番の絵が入るまで）
@export var look: Look = Look.FLAT
@export var color: Color = Color("#8F8B82")
## 本番の絵。空のときは look と色で描く
@export var texture: Texture2D
