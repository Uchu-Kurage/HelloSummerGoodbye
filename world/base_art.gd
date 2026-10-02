class_name BaseArt
## 秘密基地の盤（BasePuzzle の layout）を描く。世界の中の基地（SecretBase）と、ミニゲームの寄りの画面の両方で使う。
## 本番の絵が入ったら、材料ごとのマスの絵（BaseMaterial.texture）と、骨組み・入口の絵に差し替える。

const P := preload("res://world/world_palette.gd")


## 盤ぜんぶを描く。origin は盤の左上、cell は1マスの大きさ
## door：入口に段ボールの戸 / grid：まだふさいでいないマスの目を描く（ミニゲーム用）
static func draw_board(ci: CanvasItem, pz: BasePuzzle, origin: Vector2, cell: float, door := false, grid := false) -> void:
	var inside := interior_color()
	for y in pz.height():
		for x in pz.width():
			var c := Vector2i(x, y)
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			var k := pz.at(c)
			if k == "#":
				ci.draw_rect(r, P.WOOD_DARK)
				ci.draw_line(r.position + Vector2(0, cell * 0.5), r.position + Vector2(cell, cell * 0.5), P.WOOD, maxf(1.0, cell * 0.06))
			elif k == "o":
				ci.draw_rect(r, inside)
			elif pz.is_hole(c):
				var m := GameState.base_cell(c)
				if m:
					draw_tile(ci, m, r, c)
				elif pz.is_roof(c):
					if grid:
						ci.draw_rect(r.grow(-1), Color(P.CLOUD, 0.12))
						ci.draw_rect(r.grow(-1), Color(P.CLOUD, 0.5), false, 1.0)
				else:
					ci.draw_rect(r, inside)
					if grid:
						ci.draw_rect(r.grow(-1), Color(P.CLOUD, 0.35), false, 1.0)
	if door:
		var d := _rect_of(pz, "o", origin, cell)
		ci.draw_rect(d, P.CARDBOARD)
		ci.draw_rect(d, P.CARDBOARD_DARK, false, 2.0)
		ci.draw_line(Vector2(d.position.x, d.get_center().y), Vector2(d.end.x, d.get_center().y), P.CARDBOARD_DARK, 4.0)
		ci.draw_line(Vector2(d.get_center().x, d.position.y), Vector2(d.get_center().x, d.position.y + cell * 0.6), P.CARDBOARD_DARK, 5.0)
	draw_outlines(ci, pz, origin, cell)


## はめたピースのふち（となりのマスが別のピースのところに線を引く）。手作りの継ぎはぎに見せる
static func draw_outlines(ci: CanvasItem, pz: BasePuzzle, origin: Vector2, cell: float) -> void:
	var w := maxf(1.5, cell * 0.08)
	for c in GameState.base_cell_piece:
		var id: int = GameState.base_cell_piece[c]
		var m := GameState.base_cell(c)
		var col := m.color_2.darkened(0.25) if m else P.WOOD_DARK
		var p := origin + Vector2(c) * cell
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if GameState.base_cell_piece.get(c + d, -1) == id:
				continue
			var a: Vector2
			var b: Vector2
			match d:
				Vector2i.LEFT: a = p; b = p + Vector2(0, cell)
				Vector2i.RIGHT: a = p + Vector2(cell, 0); b = p + Vector2(cell, cell)
				Vector2i.UP: a = p; b = p + Vector2(cell, 0)
				_: a = p + Vector2(0, cell); b = p + Vector2(cell, cell)
			ci.draw_line(a, b, col, w)


## 材料のマス1つ。c（盤のマス）で模様を少しずらし、続けて並べたときに自然に見せる
static func draw_tile(ci: CanvasItem, m: BaseMaterial, r: Rect2, c := Vector2i.ZERO, alpha := 1.0) -> void:
	if m.texture:
		ci.draw_texture_rect(m.texture, r, false, Color(1, 1, 1, alpha))
		return
	var c1 := Color(m.color, alpha)
	var c2 := Color(m.color_2, alpha)
	var s := r.size.x
	ci.draw_rect(r, c1)
	match m.look:
		BaseMaterial.Look.WOOD:
			# 板の継ぎ目と木目
			ci.draw_line(r.position, r.position + Vector2(0, s), c2, maxf(1.0, s * 0.06))
			var y := r.position.y + s * (0.3 + 0.4 * ((c.x + c.y) % 2))
			ci.draw_line(Vector2(r.position.x + s * 0.2, y), Vector2(r.position.x + s * 0.8, y), c2, 1.0)
		BaseMaterial.Look.TIN:
			for i in 4:
				var x := r.position.x + s * (i + 0.5) / 4.0
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), c2, maxf(1.0, s * 0.05))
		BaseMaterial.Look.SHEET:
			if (c.x + c.y * 2) % 3 == 0:
				ci.draw_line(r.position + Vector2(s * 0.1, 0), r.position + Vector2(s * 0.7, s), c2, maxf(1.0, s * 0.06))
		BaseMaterial.Look.SUDARE:
			for i in 5:
				var y := r.position.y + s * (i + 0.5) / 5.0
				ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), c2, 1.0)


## 夜（9日目）の見え方。懐中電灯が近いほど k が大きい（0〜1）。GlowLayer の中で、加算で描く
static func draw_night(ci: CanvasItem, pz: BasePuzzle, origin: Vector2, cell: float, k: float) -> void:
	for c in GameState.base_cells:
		var m := GameState.base_cell(c)
		if m == null:
			continue
		var r := Rect2(origin + Vector2(c) * cell, Vector2(cell, cell))
		match m.look:
			BaseMaterial.Look.WOOD:
				# 木目が照らされ、板のすき間から細い光が漏れる
				ci.draw_line(r.position + Vector2(1, 2), r.position + Vector2(1, cell - 2), Color(P.LAMP_GLOW, 0.5 * k), 1.0)
			BaseMaterial.Look.TIN:
				if pz.is_roof(c):
					# くぎの穴から星が見える
					ci.draw_circle(r.get_center() + Vector2(0, cell * 0.15 * (1 - (c.x % 2) * 2)), 1.6, Color(P.STAR, k))
			BaseMaterial.Look.SHEET:
				# 光が外まで青く透ける
				ci.draw_rect(r.grow(3), Color(0.42, 0.62, 1.0, 0.1 * k))
			BaseMaterial.Look.SUDARE:
				# 編み目のむこうに星空が透ける
				ci.draw_circle(r.position + Vector2(cell * fposmod(c.x * 0.618, 1.0), cell * fposmod(c.y * 0.414 + 0.3, 1.0)), 1.4, Color(P.STAR, 0.9 * k))


## ブルーシートを使うと、基地の中が少し青くなる
static func interior_color() -> Color:
	for c in GameState.base_cells:
		var m := GameState.base_cell(c)
		if m and m.look == BaseMaterial.Look.SHEET:
			return P.SHOP_DARK.lerp(P.BLUE_SHEET, 0.35)
	return P.SHOP_DARK


## その文字のマス全体を囲む四角
static func _rect_of(pz: BasePuzzle, ch: String, origin: Vector2, cell: float) -> Rect2:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-1, -1)
	for y in pz.height():
		for x in pz.width():
			if pz.at(Vector2i(x, y)) == ch:
				mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
				mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
	return Rect2(origin + Vector2(mn) * cell, Vector2(mx - mn + Vector2i.ONE) * cell)


## 入口の左の柱のマス（「かいいん」の札を下げる場所）
static func plaque_cell(pz: BasePuzzle) -> Vector2i:
	for y in pz.height():
		for x in pz.width():
			if pz.at(Vector2i(x, y)) == "o":
				return Vector2i(x - 1, y + 1)
	return Vector2i.ZERO
