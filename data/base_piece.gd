class_name BasePiece
extends Resource
## 秘密基地づくりのピース1つ（形と材料）。形は「#」がマス、「.」が空き、行は「/」で区切る（例：L字 "###/#.."）

@export var shape := "###"
@export var material: BaseMaterial
## タケルが最初に置いておくピース（置き方の見本）。pre_origin はいちばん左上のマスの位置
@export var preplaced := false
@export var pre_origin := Vector2i.ZERO
@export_range(0, 3) var pre_rotation := 0


## 回転（右回りに rotation × 90°）したときのマス。いちばん左上が (0, 0) になるようにそろえる
func cells(rotation: int = 0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows := shape.split("/")
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				out.append(Vector2i(x, y))
	for _i in posmod(rotation, 4):
		for k in out.size():
			out[k] = Vector2i(-out[k].y, out[k].x)
	var mn := Vector2i(1 << 20, 1 << 20)
	for c in out:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
	for k in out.size():
		out[k] -= mn
	return out


func size() -> int:
	return shape.count("#")
