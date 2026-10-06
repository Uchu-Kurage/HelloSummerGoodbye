class_name TimeKeys
## 時間帯のキー（DESIGN.md「7. 時間帯と季節の表現」）。
## キーは Vector2(その日の中の位置 0.0〜1.0, 時間の値)。時間の値は 早朝 -0.15／朝 0.00／昼 0.25／夕方 0.60／夜 0.85／夜の終わり 1.00。
## 前後2つのキーの間はなめらかにつなぐ。同じ x に2つ置くと、そこで時間が飛ぶ（飛ぶところには暗転などを置く）。

const DAWN := -0.15
const MORNING := 0.0
const NOON := 0.25
const EVENING := 0.60
const NIGHT := 0.85
const NIGHT_END := 1.0
## キーを指定しない日（0 → 朝、1 → 夜の終わり）
const DEFAULT: Array[Vector2] = [Vector2(0.0, MORNING), Vector2(1.0, NIGHT_END)]
## キーの x は Vector2（単精度）なので、位置とくらべるときに少しだけ幅をもたせる
const EPSILON := 0.00001


## その日の中の位置 x（0.0〜1.0）の時間の値。keys が空なら DEFAULT。
## 同じ x にキーが2つあれば、その x からうしろのキーの値になる（時間が飛ぶ）
static func sample(keys: Array[Vector2], x: float) -> float:
	var k := keys if not keys.is_empty() else DEFAULT
	if x <= k[0].x:
		return k[0].y
	# x より左（同じ位置も含む）で、いちばん右のキー
	var j := 0
	for i in k.size():
		if k[i].x <= x + EPSILON:
			j = i
	if j >= k.size() - 1:
		return k[k.size() - 1].y
	var a := k[j]
	var b := k[j + 1]
	return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))


## x の小さい順に並んでいるか（同じ x は時間が飛ぶところなので、並んでいるとみなす）
static func is_sorted(keys: Array[Vector2]) -> bool:
	for i in range(1, keys.size()):
		if keys[i].x < keys[i - 1].x:
			return false
	return true


## 並んでいなければ警告を出す（エディタで値を入れたとき・読み込んだとき）
static func warn_if_unsorted(keys: Array[Vector2], where: String) -> void:
	if not is_sorted(keys):
		push_warning("time_keys が x の小さい順に並んでいない: %s %s" % [where, str(keys)])
