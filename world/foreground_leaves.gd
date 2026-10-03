class_name ForegroundLeaves
extends Node2D
## 手前の木の枝。画面の上から葉の茂った枝がときどき垂れ下がり、主人公より手前をゆっくり通りすぎる（木漏れ日の縁どり）。
## Parallax2D（scroll_scale 1 より大きい）の子に置き、width で一周する。
## 葉は奥から「かげの濃い緑 → 中くらい → 日の当たる明るい緑」の順に重ね、左上から光が当たるようにする。
## 風でゆっくりゆれる。動きを減らす設定ではゆらさない。

const LEAF_DARK := Color("#2E4F33")
const LEAF_MID := Color("#4C7A41")
const LEAF_LIGHT := Color("#86B05A")
const LEAF_SUN := Color("#B9D47A")
const BRANCH := Color("#3A2F28")
## 1枚の葉の大きさ（長さ・幅）
const LEAF_LEN := Vector2(18.0, 32.0)
const LEAF_WIDTH := 0.45
## ゆれ（ラジアン）と速さ
const SWAY := 0.022
const SWAY_SPEED := 0.8

## 枝：[x（割合）, 枝の向き（-1 左へ / 1 右へ）, 枝の長さ, 垂れ下がる深さ, 葉の数]
@export var branches: Array = [[0.1, 1.0, 380.0, 150.0, 260], [0.58, -1.0, 320.0, 120.0, 220]]
@export var width := 3400.0
## 枝の付け根の高さ（画面の上端より少し上）
@export var top_y := -30.0

## 枝ごとの葉：[位置, 向き, 長さ, 色の段]
var _leaves: Array = []
var _t := 0.0


func _ready() -> void:
	z_index = 10
	_build()


func _build() -> void:
	_leaves.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2408
	for b in branches:
		var list: Array = []
		var dir: float = b[1]
		var length: float = b[2]
		var droop: float = b[3]
		# 葉はかたまり（房）ごとに茂らせる。房は枝にそって、先へ行くほど垂れ下がる位置に置く
		var clumps := 7
		for ci in clumps:
			var u := (ci + 0.5) / clumps + rng.randf_range(-0.05, 0.05)
			var center := Vector2(dir * length * u, droop * u * u + 10.0) + Vector2(rng.randf_range(-20, 20), rng.randf_range(-10, 30))
			var radius := rng.randf_range(42.0, 62.0) * (1.15 - u * 0.35)
			for i in int(b[4]) / clumps:
				var off := Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
				off.y *= 0.8
				var p := center + off
				# 房の左上ほど日が当たる。下・右（奥）ほど濃い
				var lit := clampf(0.5 - off.y / radius * 0.55 - off.x / radius * 0.3 + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
				var tier := 0 if lit < 0.4 else (1 if lit < 0.7 else (2 if lit < 0.92 else 3))
				var ang := Vector2(off.x, off.y + radius * 0.6).angle() + rng.randf_range(-0.6, 0.6)
				list.append([p, ang, rng.randf_range(LEAF_LEN.x, LEAF_LEN.y), tier])
		# 濃い葉から描く
		list.sort_custom(func(a, c): return a[3] < c[3])
		_leaves.append(list)


func _process(delta: float) -> void:
	if UiAnim.reduced():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var colors := [LEAF_DARK, LEAF_MID, LEAF_LIGHT, LEAF_SUN]
	for bi in branches.size():
		var b: Array = branches[bi]
		var root := Vector2(width * float(b[0]), top_y)
		var sway := sin(_t * SWAY_SPEED + bi * 1.7) * SWAY + sin(_t * SWAY_SPEED * 2.3 + bi) * SWAY * 0.3
		draw_set_transform(root, sway, Vector2.ONE)
		# 枝（付け根から先へ細くなる線）
		var dir: float = b[1]
		var length: float = b[2]
		var droop: float = b[3]
		var prev := Vector2.ZERO
		for s in range(1, 9):
			var u := s / 8.0
			var q := Vector2(dir * length * u * 0.85, droop * u * u * 0.9 + 10.0 * u)
			draw_line(prev, q, BRANCH, lerpf(9.0, 2.0, u), true)
			prev = q
		for lf in _leaves[bi]:
			_leaf(lf[0], lf[1] + sway * 3.0, lf[2], colors[lf[3]])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 1枚の葉（先のとがった楕円）
func _leaf(p: Vector2, ang: float, length: float, c: Color) -> void:
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal() * length * LEAF_WIDTH * 0.5
	var tip := p + d * length * 0.5
	var base := p - d * length * 0.5
	draw_colored_polygon(PackedVector2Array([base, p + n - d * length * 0.1, tip, p - n - d * length * 0.1]), c)
