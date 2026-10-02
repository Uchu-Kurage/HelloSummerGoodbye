class_name BasePuzzle
extends Resource
## 秘密基地づくり（ペントミノ式の型はめ）の盤とピース。基地の絵（SecretBase）もこの盤から描く。
## layout は盤を文字で書いたもの。行は「/」で区切る（ピースの形と同じ書き方）。
## ※ PackedStringArray にすると、書き出し（Web など）でテキストのリソースを変換したときに中身が消えるので、1つの文字列にしている
## layout の文字：
##   A B C … 屋根のすき間（左・中・右）　D E … 壁のすき間（左・右）。同じ文字のマスが1つのすき間
##   #      … 骨組み（柱・梁）　o … 入口（4日目は空いたまま、8日目から段ボールの戸）　. … 何もない

## 屋根のすき間の文字（3か所ふさぐと、雨の音が「屋根をたたく雨」になる）
const ROOF := "ABC"
const GAPS := "ABCDE"

@export var layout := ""
@export var pieces: Array[BasePiece] = []
## しばらく手が止まったときの、タケルのひとこと（はまるピースと場所をそっと光らせる）
@export var hint_line := ""


var _rows := PackedStringArray()


func rows() -> PackedStringArray:
	if _rows.is_empty() and layout != "":
		_rows = layout.split("/")
	return _rows


func width() -> int:
	return rows()[0].length() if rows().size() > 0 else 0


func height() -> int:
	return rows().size()


func at(c: Vector2i) -> String:
	var r := rows()
	if c.y < 0 or c.y >= r.size() or c.x < 0 or c.x >= r[c.y].length():
		return "."
	return r[c.y][c.x]


func is_hole(c: Vector2i) -> bool:
	return GAPS.contains(at(c))


func is_roof(c: Vector2i) -> bool:
	return ROOF.contains(at(c))


func holes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height():
		for x in width():
			if is_hole(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out
