class_name SketchGame
extends MinigameBase
## ミニゲーム「スケッチ」（3日目、初恋ルート）。会話の @game sketch で始まる。
## 川原で、なつみと並んで絵を描く。背景の景色が見本で、右の岩の上に自分の画用紙。
## 景色の4か所（そら → やま → かわ → いわ）を順に塗る。各所で3色から選ぶ（左右で選んで決定。タッチは色をタップ）。
## 4か所中 GOOD_MATCHES か所以上が景色の色と合えば「よくできた」（好感度 +1、フラグ sketch_good）。失敗はない。

enum Phase { CHOOSE, PAINT, SHOW }

## 「よくできた」になる、景色と色が合った数（4か所のうち。仮の値）
const GOOD_MATCHES := 3
## 塗る場所（PLACES の順）と、場所ごとの3色（0 番が景色と同じ色）
const PLACES := 4
const COLORS := [
	[Color("#8EC5E0"), Color("#E9B489"), Color("#B9B6C9")],
	[Color("#7FA27A"), Color("#8E87B5"), Color("#B48A62")],
	[Color("#7FA9C8"), Color("#A88B62"), Color("#9FC48A")],
	[Color("#A8A296"), Color("#C9786A"), Color("#D9C27A")],
]
## 筆で塗っていく時間と、できあがりを見せる時間
const PAINT_TIME := 3.4
const SHOW_TIME := 3.0
const SWATCH := Vector2(104, UiTokens.TOUCH_MIN)
const GRASS := Color("#B9C98E")
const PENCIL := Color(0.4, 0.36, 0.3, 0.35)
## 背景の絵（川原の景色。これが見本になる）と、切り取るとき残したいところ
const BG_TEX: Texture2D = preload("res://ui/minigame_bg/sketch.jpg")
const BG_FOCUS := Vector2(0.4, 0.3)
const NATSUMI_TEX: Texture2D = preload("res://world/scenery/painted/natsumi_mg1_1.png")

var phase := Phase.CHOOSE
var place := 0
var cursor := 0
var matches := 0
## 場所ごとの3色の並び（COLORS の番号）と、塗った色（-1 ならまだ）
var _order: Array = []
var picked: Array[int] = [-1, -1, -1, -1]
var rng := RandomNumberGenerator.new()
var _t := 0.0


func _setup() -> void:
	intro_text = Strings.SKETCH_INTRO
	arrows = true
	rng.randomize()


func _begin() -> void:
	phase = Phase.CHOOSE
	place = 0
	cursor = 0
	matches = 0
	picked = [-1, -1, -1, -1]
	_order.clear()
	for i in PLACES:
		var o := [0, 1, 2]
		# 景色と同じ色が、いつも同じ場所にならないように
		for k in range(o.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t: int = o[k]
			o[k] = o[j]
			o[j] = t
		_order.append(o)
	_ask()


func _ask() -> void:
	phase = Phase.CHOOSE
	# いま塗る場所は、左上の小札ではなく、画用紙のすぐ上に大きく出す（_draw）
	hush()
	show_hint(Strings.SKETCH_HINT_TOUCH, Strings.SKETCH_HINT_KEY)


## いまの場所で、景色と同じ色の位置（自動の動作確認から使う）
func correct_index() -> int:
	return (_order[place] as Array).find(0) if place < PLACES else -1


func _left() -> void:
	if phase == Phase.CHOOSE and cursor > 0:
		cursor -= 1
		SfxPlayer.play("cursor")


func _right() -> void:
	if phase == Phase.CHOOSE and cursor < 2:
		cursor += 1
		SfxPlayer.play("cursor")


func _accept(pos: Variant = null) -> void:
	if phase != Phase.CHOOSE:
		if phase == Phase.PAINT:
			speed = UiTokens.SKIP_SPEED
		return
	# タッチは、色をタップすると、その色で塗る
	if pos is Vector2:
		var hit := _swatch_at(pos)
		if hit < 0:
			return
		cursor = hit
	_paint(cursor)


func _paint(i: int) -> void:
	var v: int = _order[place][i]
	picked[place] = v
	if v == 0:
		matches += 1
	SfxPlayer.play("accept")
	hide_hint()
	phase = Phase.PAINT
	_t = 0.0


func _process_game(delta: float) -> void:
	_t += delta
	match phase:
		Phase.PAINT:
			if _t >= PAINT_TIME:
				speed = 1.0
				place += 1
				cursor = 0
				if place >= PLACES:
					phase = Phase.SHOW
					_t = 0.0
					hush()
					SfxPlayer.play("pickup")
				else:
					_ask()
		Phase.SHOW:
			if _t >= SHOW_TIME:
				end_game(matches >= GOOD_MATCHES, matches)


func bot(good: bool) -> Dictionary:
	if phase != Phase.CHOOSE:
		return {}
	var want := correct_index() if good else (correct_index() + 1) % 3
	if want < cursor:
		return {"key": KEY_LEFT, "tap": _swatch_tap(want)}
	if want > cursor:
		return {"key": KEY_RIGHT, "tap": _swatch_tap(want)}
	return {"key": KEY_SPACE, "tap": _swatch_tap(want)}


func _swatch_tap(i: int) -> Vector2:
	return global_position + _swatch_rect(i).get_center()


# --- 絵 -----------------------------------------------------------------------

func _paper() -> Rect2:
	var s := size
	var top := UiTokens.SCREEN_MARGIN + 64.0
	var bot := s.y - UiTokens.SCREEN_MARGIN - SWATCH.y - UiTokens.SPACE_L * 2 - 48.0
	var h := maxf(bot - top, 120.0)
	var w := minf(h * 1.4, s.x * 0.44)
	h = w / 1.4
	return Rect2(s.x - UiTokens.SCREEN_MARGIN - w - 40.0, top + (bot - top - h) * 0.5, w, h)


func _swatch_rect(i: int) -> Rect2:
	var p := _paper()
	var gap := UiTokens.TOUCH_GAP * 2.0
	var total := SWATCH.x * 3 + gap * 2
	var x0 := p.get_center().x - total / 2.0
	return Rect2(Vector2(x0 + (SWATCH.x + gap) * i, p.end.y + UiTokens.SPACE_L), SWATCH)


func _swatch_at(pos: Vector2) -> int:
	for i in 3:
		if _swatch_rect(i).grow(10).has_point(pos - global_position):
			return i
	return -1


func _draw() -> void:
	var s := size
	if s.x < 1.0:
		return
	# 背景の川原の景色が、そのまま見本になる。左に、となりで描いているなつみ
	MinigameBg.draw_cover(self, BG_TEX, Rect2(Vector2.ZERO, s), BG_FOCUS)
	draw_sprite(NATSUMI_TEX, Vector2(s.x * 0.16, s.y * 0.94), s.y * 0.36)
	var paper := _paper()
	draw_rect(Rect2(paper.position + Vector2(4, 6), paper.size).grow(6), UiTokens.SHADOW)
	draw_rect(paper.grow(6), UiTokens.PAPER_DARK)
	draw_rect(paper, UiTokens.PAPER)
	_landscape(paper)
	# いま塗る場所の案内（画用紙のすぐ上のまん中。目と手もとが近いところに）
	if phase == Phase.CHOOSE and place < PLACES and state == State.PLAY:
		var font := get_theme_default_font()
		var text: String = Strings.SKETCH_PLACES[place]
		var fs := UiTokens.FONT_BODY
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip := Rect2(Vector2(paper.get_center().x - tw / 2.0 - UiTokens.SPACE_M, paper.position.y - 16.0 - fs * 2.0), Vector2(tw + UiTokens.SPACE_M * 2.0, fs * 2.0))
		draw_rect(Rect2(chip.position + Vector2(2, 3), chip.size), UiTokens.SHADOW)
		draw_rect(chip, UiTokens.PAPER)
		draw_rect(chip, UiTokens.ACCENT_INK, false, 2.0)
		draw_string(font, Vector2(chip.position.x + UiTokens.SPACE_M, chip.position.y + fs * 1.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.INK)
	# 3色（いまの場所の）。えらんでいる色に印
	if phase == Phase.CHOOSE and place < mini(PLACES, _order.size()):
		for i in 3:
			var r := _swatch_rect(i)
			draw_rect(r.grow(4), UiTokens.PAPER)
			draw_rect(r, COLORS[place][_order[place][i]])
			if i == cursor:
				draw_rect(r.grow(8), UiTokens.ACCENT_INK, false, 4.0)


## 塗った場所の割合（塗っている途中は、左から筆で塗られていく）
func _fill(i: int) -> float:
	if picked[i] < 0:
		return 0.0
	if i == place and phase == Phase.PAINT:
		return clampf(_t / (PAINT_TIME * 0.8), 0.0, 1.0)
	return 1.0


func _landscape(r: Rect2) -> void:
	var horizon := r.position.y + r.size.y * 0.55
	# そら
	_fill_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55)), 0)
	draw_rect(Rect2(r.position.x, horizon, r.size.x, r.end.y - horizon), Color(GRASS, 0.35))
	# やま（丸い山がふたつ）
	for m in [[0.28, 0.42, 0.32], [0.68, 0.48, 0.26]]:
		var cx: float = r.position.x + r.size.x * m[0]
		var hw: float = r.size.x * m[1] * 0.5
		var mh: float = r.size.y * m[2]
		var pts := PackedVector2Array()
		for k in 17:
			var t := k / 16.0
			pts.append(Vector2(cx - hw + hw * 2 * t, horizon - mh * sin(PI * t)))
		_fill_poly(pts, 1, r)
	# かわ
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for k in 17:
		var t := k / 16.0
		var x := r.position.x + r.size.x * t
		top.append(Vector2(x, r.position.y + r.size.y * (0.66 + 0.03 * sin(t * TAU))))
		bot.append(Vector2(x, r.position.y + r.size.y * (0.8 + 0.03 * sin(t * TAU + 1.2))))
	var river := top.duplicate()
	var b2 := bot.duplicate()
	b2.reverse()
	river.append_array(b2)
	_fill_poly(river, 2, r)
	# いわ（手前に三つ）
	for st in [[0.2, 0.07], [0.52, 0.05], [0.8, 0.06]]:
		var p := Vector2(r.position.x + r.size.x * st[0], r.position.y + r.size.y * 0.9)
		var rad: float = r.size.x * st[1]
		var pts := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			pts.append(p + Vector2(cos(a) * rad, sin(a) * rad * 0.6))
		_fill_poly(pts, 3, r)


func _fill_rect(area: Rect2, i: int) -> void:
	var f := _fill(i)
	if f > 0.0:
		draw_rect(Rect2(area.position, Vector2(area.size.x * f, area.size.y)), COLORS[i][picked[i]])
	if f < 1.0:
		draw_rect(area, PENCIL, false, 1.5)


## 形を塗る（塗っている途中は、紙の左から f の割合まで）。まだのところは、えんぴつの下書き
func _fill_poly(pts: PackedVector2Array, i: int, paper: Rect2) -> void:
	var f := _fill(i)
	if f >= 1.0:
		draw_colored_polygon(pts, COLORS[i][picked[i]])
		return
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, PENCIL, 1.5)
	if f > 0.0:
		var clip := PackedVector2Array([paper.position, Vector2(paper.position.x + paper.size.x * f, paper.position.y),
			Vector2(paper.position.x + paper.size.x * f, paper.end.y), Vector2(paper.position.x, paper.end.y)])
		for part in Geometry2D.intersect_polygons(pts, clip):
			draw_colored_polygon(part, COLORS[i][picked[i]])
