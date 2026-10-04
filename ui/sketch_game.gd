class_name SketchGame
extends NatsumiScreen
## ミニゲーム「スケッチ」（3日目、初恋ルート）。会話の @game sketch で始まる。
## 川原で、なつみと並んで絵を描く。左が見本の景色、右が自分の画用紙。
## そら（いろ）→ やま（かたち）→ かわ（いろ）→ いし（かたち）の順に、3つから選んで描いていく。
## 失敗も時間制限もない。見本との一致が GOOD_MATCHES 以上なら高得点（好感度 +1、フラグ sketch_good）。

enum Phase { CHOOSE, WAIT, SHOW }

## 高得点になる一致の数（4つのうち）
const GOOD_MATCHES := 3
## 選んでから次へ進むまで／できあがりを見せる時間
const STEP_WAIT := 0.9
const SHOW_TIME := 1.8
const CHOICE_SIZE := Vector2(144, 100)
## 描くもの：0 そら（いろ）／1 やま（かたち）／2 かわ（いろ）／3 いし（かたち）
const STEPS := 4
## 見本の値（いろの段は色、かたちの段は形の番号 0 まるい・1 とがった・2 たいら）と、ほかの選択肢
const SKY_COLORS := [Color("#8EC5E0"), Color("#E9B489"), Color("#B9B6C9")]
const RIVER_COLORS := [Color("#7FA9C8"), Color("#A88B62"), Color("#9FC48A")]
const SHAPES := [0, 1, 2]
const MOUNTAIN := Color("#8FB28A")
const GRASS := Color("#B9C98E")
const STONE := Color("#A8A296")
const PENCIL := Color(0.4, 0.36, 0.3, 0.35)
const BG := Color("#CFDDB0")

var phase := Phase.CHOOSE
var step := 0
var matches := 0
## 段ごとの選択肢の並び（見本の値の番号）と、選んだもの（-1 ならまだ）
var _order: Array = []
var picked: Array[int] = [-1, -1, -1, -1]
var rng := RandomNumberGenerator.new()
var _wait := 0.0
var _row: HBoxContainer
var _buttons: Array[Button] = []


func _build() -> void:
	rng.randomize()
	for i in STEPS:
		var o := [0, 1, 2]
		# 見本と同じものが、いつも同じ場所にならないように
		for k in range(o.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t: int = o[k]
			o[k] = o[j]
			o[j] = t
		_order.append(o)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_row)
	for i in 3:
		var b := make_choice(i, CHOICE_SIZE, _draw_choice, _on_choice)
		_row.add_child(b)
		_buttons.append(b)
	link_row(_buttons)
	say(Strings.SKETCH_STEPS[0])
	show_hint(Strings.SKETCH_HINT_TOUCH, Strings.SKETCH_HINT_KEY)
	if InputMode.keyboard:
		_buttons[0].grab_focus()


## いまの段で、見本と同じものの場所（自動の動作確認から使う）
func correct_index() -> int:
	return (_order[step] as Array).find(0) if step < STEPS else -1


func _on_choice(i: int) -> void:
	choose(i)


## 選ぶ（自動の動作確認からも呼べる）
func choose(i: int) -> void:
	if phase != Phase.CHOOSE or step >= STEPS:
		return
	var v: int = _order[step][i]
	picked[step] = v
	if v == 0:
		matches += 1
	SfxPlayer.play("accept")
	say(Strings.SKETCH_MATCH if v == 0 else Strings.SKETCH_OTHER)
	for b in _buttons:
		b.disabled = true
	phase = Phase.WAIT
	_wait = STEP_WAIT
	queue_redraw()


func _process(delta: float) -> void:
	var d := delta * speed
	match phase:
		Phase.WAIT:
			_wait -= d
			if _wait <= 0.0:
				step += 1
				if step >= STEPS:
					_show_done()
				else:
					phase = Phase.CHOOSE
					say(Strings.SKETCH_STEPS[step])
					for b in _buttons:
						b.disabled = false
						for c in b.get_children():
							if c is Control:
								(c as Control).queue_redraw()
					if InputMode.keyboard:
						_buttons[0].grab_focus()
		Phase.SHOW:
			_wait -= d
			if _wait <= 0.0 and not done:
				GameState.set_natsumi_game(&"sketch", matches >= GOOD_MATCHES)
				finish()


func _show_done() -> void:
	phase = Phase.SHOW
	_wait = SHOW_TIME
	say(Strings.SKETCH_DONE)
	hide_hint()
	var f := get_viewport().gui_get_focus_owner()
	if f:
		f.release_focus()
	UiAnim.fade(_row, 0.0, UiTokens.TIME_SMALL_OUT)
	SfxPlayer.play("pickup")


## できあがりを見せているあいだは、決定キー／タップで早送り
func _input(event: InputEvent) -> void:
	if phase == Phase.SHOW and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), BG)
	# 見本（左）と画用紙（右）。上の小札と下の選択肢のあいだに並べる
	var top := UiTokens.SCREEN_MARGIN + 64.0
	var bot := s.y - UiTokens.SCREEN_MARGIN - 48.0 - CHOICE_SIZE.y - UiTokens.SPACE_M * 2
	var h := maxf(bot - top, 120.0)
	var w := minf(h * 1.4, (s.x - UiTokens.SCREEN_MARGIN * 2 - UiTokens.SPACE_L) / 2.0)
	h = w / 1.4
	var gap := UiTokens.SPACE_L
	var left := (s.x - w * 2 - gap) / 2.0
	var sample := Rect2(left, top, w, h)
	var paper := Rect2(left + w + gap, top, w, h)
	# 見本：川原の景色そのもの（枠は木の色）
	draw_rect(sample.grow(6), WorldPalette.WOOD)
	_landscape(sample, [0, 0, 0, 0])
	# 画用紙：選んだものだけ描かれる。まだのところは、えんぴつの下書き
	draw_rect(paper.grow(6), UiTokens.PAPER_DARK)
	draw_rect(paper, UiTokens.PAPER)
	_landscape(paper, picked, true)


## 景色を描く。values はそれぞれの段で選んだ値（-1 なら描かない）
func _landscape(r: Rect2, values: Array, sketch := false) -> void:
	var horizon := r.position.y + r.size.y * 0.55
	if values[0] >= 0:
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55)), SKY_COLORS[values[0]])
	if sketch:
		draw_line(Vector2(r.position.x, horizon), Vector2(r.end.x, horizon), PENCIL, 1.5)
	if values[1] >= 0:
		_mountains(r, horizon, values[1], MOUNTAIN, -1.0)
	elif sketch:
		_mountains(r, horizon, 0, PENCIL, 1.5)
	if values[0] >= 0 or not sketch:
		draw_rect(Rect2(r.position.x, horizon, r.size.x, r.end.y - horizon), GRASS)
	if values[2] >= 0:
		_river(r, RIVER_COLORS[values[2]], -1.0)
	elif sketch:
		_river(r, PENCIL, 1.5)
	if values[3] >= 0:
		_stones(r, values[3], STONE, -1.0)
	elif sketch:
		_stones(r, 0, PENCIL, 1.5)


## 形の番号 0 まるい・1 とがった・2 たいら。line > 0 なら線だけ（下書き）
func _mountains(r: Rect2, base: float, shape: int, c: Color, line: float) -> void:
	for m in [[0.28, 0.42, 0.32], [0.68, 0.48, 0.26]]:
		var cx: float = r.position.x + r.size.x * m[0]
		var hw: float = r.size.x * m[1] * 0.5
		var mh: float = r.size.y * m[2]
		var pts := PackedVector2Array()
		match shape:
			0:
				for i in 17:
					var t := i / 16.0
					pts.append(Vector2(cx - hw + hw * 2 * t, base - mh * sin(PI * t)))
			1:
				pts.append_array([Vector2(cx - hw, base), Vector2(cx - hw * 0.4, base - mh * 0.7), Vector2(cx - hw * 0.15, base - mh * 0.5),
					Vector2(cx, base - mh * 1.1), Vector2(cx + hw * 0.3, base - mh * 0.6), Vector2(cx + hw, base)])
			_:
				pts.append_array([Vector2(cx - hw, base), Vector2(cx - hw * 0.55, base - mh * 0.7), Vector2(cx + hw * 0.55, base - mh * 0.7), Vector2(cx + hw, base)])
		if line > 0.0:
			draw_polyline(pts, c, line)
		else:
			draw_colored_polygon(pts, c)


func _river(r: Rect2, c: Color, line: float) -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		var x := r.position.x + r.size.x * t
		top.append(Vector2(x, r.position.y + r.size.y * (0.68 + 0.03 * sin(t * TAU))))
		bot.append(Vector2(x, r.position.y + r.size.y * (0.82 + 0.03 * sin(t * TAU + 1.2))))
	if line > 0.0:
		draw_polyline(top, c, line)
		draw_polyline(bot, c, line)
		return
	var poly := top.duplicate()
	bot.reverse()
	poly.append_array(bot)
	draw_colored_polygon(poly, c)
	for i in 3:
		var y := r.position.y + r.size.y * (0.72 + i * 0.035)
		var x := r.position.x + r.size.x * (0.15 + i * 0.27)
		draw_line(Vector2(x, y), Vector2(x + r.size.x * 0.12, y), Color(1, 1, 1, 0.6), 2.0)


func _stones(r: Rect2, shape: int, c: Color, line: float) -> void:
	for st in [[0.2, 0.06], [0.5, 0.045], [0.78, 0.055]]:
		var p := Vector2(r.position.x + r.size.x * st[0], r.position.y + r.size.y * 0.91)
		var rad: float = r.size.x * st[1]
		_shape(p, rad, shape, c, line)


## 小さな形（いし・選択肢の絵に使う）
func _shape(p: Vector2, rad: float, shape: int, c: Color, line: float, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = self
	var pts := PackedVector2Array()
	match shape:
		0:
			for i in 16:
				var a := TAU * i / 16.0
				pts.append(p + Vector2(cos(a) * rad, sin(a) * rad * 0.6))
		1:
			pts.append_array([p + Vector2(-rad, rad * 0.6), p + Vector2(rad, rad * 0.6), p + Vector2(rad, -rad * 0.6), p + Vector2(-rad, -rad * 0.6)])
		_:
			pts.append_array([p + Vector2(-rad, rad * 0.6), p + Vector2(rad, rad * 0.6), p + Vector2(0, -rad * 0.8)])
	if line > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, c, line)
	else:
		ci.draw_colored_polygon(pts, c)


## 選択肢の枠の中の絵（いろの段は色の見本、かたちの段は形）
func _draw_choice(a: Control, i: int) -> void:
	if step >= STEPS:
		return
	var v: int = _order[step][i]
	var c := a.size / 2.0
	match step:
		0, 2:
			var col: Color = SKY_COLORS[v] if step == 0 else RIVER_COLORS[v]
			a.draw_rect(Rect2(c - Vector2(40, 26), Vector2(80, 52)), col)
		1:
			var pts := PackedVector2Array()
			var base := c.y + 24
			match v:
				0:
					for k in 13:
						var t := k / 12.0
						pts.append(Vector2(c.x - 44 + 88 * t, base - 46 * sin(PI * t)))
				1:
					pts.append_array([Vector2(c.x - 44, base), Vector2(c.x - 18, base - 30), Vector2(c.x - 6, base - 20), Vector2(c.x + 6, base - 50), Vector2(c.x + 44, base)])
				_:
					pts.append_array([Vector2(c.x - 44, base), Vector2(c.x - 24, base - 32), Vector2(c.x + 24, base - 32), Vector2(c.x + 44, base)])
			a.draw_colored_polygon(pts, MOUNTAIN)
		3:
			_shape(c + Vector2(0, 6), 30.0, v, STONE, -1.0, a)
