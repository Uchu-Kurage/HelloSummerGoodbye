class_name KatanukiGame
extends Control
## ミニゲーム「型抜き」（5日目、親友ルート）。会話の @game katanuki で始まる。
## 夏祭りの型抜き屋台で、タケルと並んでひよこの型を抜く。押しつづけると削れ、離すと手を休める。
## 押しているあいだ型に「ひび」がたまり、離すとゆっくり落ち着く。ひびがいっぱいになると割れる。
## ひびの量はゲージで出さず、型の見た目（ひびの線・手元のふるえ）と音で伝える。
## 主人公が「しっぽ」に入ったころ、となりのタケルの型が割れる（叫び声で手元がびくっとするが、割れはしない）。
## 1回きり。結果（ぬけた／われた）は GameState.katanuki_result に入れ、フラグ katanuki_clean / katanuki_broken も立てる

signal finished

enum Phase { INTRO, CARVE, RESULT, DONE }

## 部分ごとの調整値。carve は削り終えるまでに押す秒数の合計、crack は 0 から押しつづけて割れるまでの秒数。
## ふつうの部分は 1.0 秒押せば抜け、続けて 1.5 秒押すと割れる（くちばし・足は細くて割れやすい難所）
const PARTS := [
	{"name": "あたま", "carve": 1.0, "crack": 1.5},
	{"name": "くちばし", "carve": 0.5, "crack": 0.6},
	{"name": "せなか", "carve": 1.6, "crack": 3.0},
	{"name": "しっぽ", "carve": 1.0, "crack": 1.5},
	{"name": "あし", "carve": 0.5, "crack": 0.6},
	{"name": "おなか", "carve": 1.6, "crack": 3.0},
]
## 離しているあいだ、ひびが落ち着く速さ（1 秒あたり。いっぱいのひびが約 1.7 秒で消える）
const RELAX := 0.6
## ひびの段階：これを超えると「多め」（ミシッ・細いひびの線）、「危ない」（線が伸び、手元がふるえる）
const CRACK_SOME := 0.4
const CRACK_DANGER := 0.75
## タケルの型が割れるのは、主人公がこの部分に入ったころ（しっぽ）
const TAKERU_BREAK_PART := 3
## 主人公が先に割ったとき、タケルが割るまでの間
const TAKERU_LATE_BREAK := 0.8
## 叫び声で手元がびくっとする大きさ（px）と、落ち着くまでの時間
const JOLT := 7.0
const JOLT_TIME := 0.4
## 危ないときの手元のふるえ（px）
const TREMBLE := 2.0
## 削る音（カリカリ）を鳴らす間隔
const SCRAPE_EVERY := 0.22
## 削っているあいだ、まわりの音（祭りばやし・人の声）を下げる量（dB）
const DUCK_DB := -8.0
## 割れた瞬間に音を止める時間
const SILENCE_TIME := 0.5
## 割れ目の横の位置（型の中）の、ふちからの近さの限度
const BREAK_MIN_X := 0.35
const INTRO_TIME := 0.6
## 結果を見せる時間（決定キー・タップで早送りできる）
const RESULT_TIME := 2.4
const P := preload("res://world/world_palette.gd")
## 背景の絵（夜の屋台の台。水彩）
const BG: Texture2D = preload("res://ui/minigame_bg/katanuki.jpg")
## 絵の中の台の天板（絵の 0〜1 の座標）：向こうのふち、手前のふち
const TABLE_BACK := 0.66
const TABLE_FRONT := 0.93
## タケルが立つ横の位置（絵の 0〜1。左の柱より少し内側）
const TAKERU_X := 0.27
## タケルの絵（水彩）：削っているところ／割れて両手をあげたところ。どちらも正面の上半身
const TAKERU_CARVE: Texture2D = preload("res://world/scenery/painted/takeru_mg2_1.png")
const TAKERU_BROKEN: Texture2D = preload("res://world/scenery/painted/takeru_mg2_2.png")
## 削っている絵は、下の板を台の向こうのふちで切る（絵の上からの px。手は残る）
const TAKERU_CARVE_CUT := 300.0
## 絵 1px が画面で何 px か（タケルの型の大きさに対して）。絵ごとに解像度がちがうので、頭の幅がそろうように合わせる
const TAKERU_CARVE_SCALE := 0.0042
const TAKERU_BROKEN_SCALE := 0.0049
## 型は台に寝かせてあるので、少し上から見たように縦をつめる
const MOLD_TILT := 0.86

## ひよこの輪郭（型の中の 0〜1 の座標、右向き）。部分ごとの線で、決まった順に削る：頭 → くちばし → 背中 → しっぽ → 足 → おなか
const OUTLINE := [
	[Vector2(0.48, 0.30), Vector2(0.47, 0.21), Vector2(0.53, 0.14), Vector2(0.62, 0.12), Vector2(0.70, 0.16), Vector2(0.74, 0.25)],
	[Vector2(0.74, 0.25), Vector2(0.85, 0.28), Vector2(0.74, 0.32)],
	[Vector2(0.48, 0.30), Vector2(0.40, 0.32), Vector2(0.31, 0.35), Vector2(0.24, 0.40)],
	[Vector2(0.24, 0.40), Vector2(0.12, 0.40), Vector2(0.20, 0.47), Vector2(0.13, 0.53), Vector2(0.24, 0.60), Vector2(0.33, 0.68), Vector2(0.44, 0.72)],
	[Vector2(0.44, 0.72), Vector2(0.45, 0.83), Vector2(0.40, 0.88), Vector2(0.62, 0.88), Vector2(0.57, 0.83), Vector2(0.58, 0.72)],
	[Vector2(0.58, 0.72), Vector2(0.68, 0.66), Vector2(0.75, 0.55), Vector2(0.77, 0.43), Vector2(0.74, 0.32)],
]
const EYE := Vector2(0.63, 0.21)

var hud: Hud
var phase := Phase.INTRO
## &"clean"（ぬけた）／&"broken"（われた）
var result := &""
## いま削っている部分（PARTS の番号）。ぜんぶ削れたら PARTS.size()
var part := 0
## 部分ごとの削れ具合（0〜1）
var carved: Array[float] = []
## ひび（0〜1。1 で割れる）
var crack := 0.0
var takeru_broken := false
var _t := 0.0
var _speed := 1.0
var _scrape_t := 0.0
var _jolt_t := 0.0
## 割れた場所（型の中の座標）
var _break_at := Vector2(0.5, 0.5)
var _takeru_break_at := Vector2(0.4, 0.5)
var _cracks: Array = []
var _hold: HoldInput
var _chip: PanelContainer
var _line: Label
var _hint: Label


func _ready() -> void:
	# 人物の絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in PARTS.size():
		carved.append(0.0)
	_make_cracks()
	_hold = HoldInput.new()
	_hold.pressed.connect(_on_pressed)
	_hold.released.connect(_on_released)
	add_child(_hold)
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	# タケル・屋台のおじさんのひとこと（小札）
	_chip = PanelContainer.new()
	_chip.theme_type_variation = &"PaperChip"
	_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_chip)
	_line = Label.new()
	_chip.add_child(_line)
	_chip.modulate.a = 0.0
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	# 押しつづけの案内（控えめに、下の小札）
	var hint_chip := PanelContainer.new()
	hint_chip.theme_type_variation = &"PaperChip"
	hint_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint_chip)
	_hint = Label.new()
	_hint.theme_type_variation = &"SmallLabel"
	hint_chip.add_child(_hint)
	hint_chip.modulate.a = 0.0
	_hint.set_meta("chip", hint_chip)
	InputMode.mode_changed.connect(_refresh_hint.unbind(1))
	# 画面のどこを押してもよいので、右上のボタンは隠す
	get_tree().call_group("touch_controls", "set_suppressed", true)
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)
	SfxPlayer.set_ambient_volume(0.0)


## 上の小札にひとことを出す（who が空なら、いま話している人）
func say(text: String, who := "") -> void:
	if who == "":
		who = hud.speaker_name() if hud else ""
	_line.text = Strings.SPEECH_FORMAT % [who, text]
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func _refresh_hint() -> void:
	_hint.text = Strings.KATANUKI_HINT_TOUCH if InputMode.touch else Strings.KATANUKI_HINT_KEY


func _show_hint(on: bool) -> void:
	_refresh_hint()
	UiAnim.fade(_hint.get_meta("chip"), 1.0 if on else 0.0, UiTokens.TIME_SMALL)


## ひびのいまの段階：0 少し／1 多め／2 危ない
func crack_stage() -> int:
	if crack >= CRACK_DANGER:
		return 2
	if crack >= CRACK_SOME:
		return 1
	return 0


# --- 進み ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * _speed
	_t += d
	_jolt_t = maxf(_jolt_t - d, 0.0)
	match phase:
		Phase.INTRO:
			if _t >= INTRO_TIME:
				_go(Phase.CARVE)
				_hold.enabled = true
				_show_hint(true)
		Phase.CARVE:
			if _hold.is_down:
				_carve(d)
			else:
				crack = maxf(crack - RELAX * d, 0.0)
		Phase.RESULT:
			# 主人公が先に割ったときは、少しおくれてタケルも割る（「おまえも われてんじゃん！」につながる）
			if not takeru_broken and _t >= TAKERU_LATE_BREAK:
				_break_takeru()
			if _t >= RESULT_TIME and takeru_broken:
				_finish()
	queue_redraw()


func _go(p: Phase) -> void:
	phase = p
	_t = 0.0


func _carve(d: float) -> void:
	var pr: Dictionary = PARTS[part]
	var before := crack_stage()
	carved[part] = minf(carved[part] + d / pr.carve, 1.0)
	crack += d / pr.crack
	_scrape_t -= d
	if _scrape_t <= 0.0:
		_scrape_t = SCRAPE_EVERY
		SfxPlayer.play("katanuki_scrape")
	if crack >= 1.0:
		_break_mine()
		return
	if crack_stage() > before:
		# 多め：ミシッ／危ない：もう一度ミシッ（線が伸びる）
		SfxPlayer.play("katanuki_creak")
	if carved[part] >= 1.0:
		part += 1
		SfxPlayer.play("katanuki_part")
		if part == TAKERU_BREAK_PART and not takeru_broken:
			_break_takeru()
		if part >= PARTS.size():
			_end(&"clean")


func _on_pressed() -> void:
	if phase != Phase.CARVE:
		return
	_scrape_t = 0.0
	# 削っているあいだ、まわりの音を少し小さくして手元に集中させる
	SfxPlayer.set_ambient_volume(DUCK_DB, UiTokens.TIME_SMALL)


func _on_released(_held: float) -> void:
	SfxPlayer.set_ambient_volume(0.0, UiTokens.TIME_PANEL)


func _break_takeru() -> void:
	takeru_broken = true
	_jolt_t = JOLT_TIME
	SfxPlayer.play("katanuki_break")
	say(Strings.KATANUKI_TAKERU_BREAK)


func _break_mine() -> void:
	crack = 1.0
	# 割れ目は針のところから。ひよこがまっぷたつになるよう、まん中寄りにおさめる
	_break_at = _needle_point()
	_break_at.x = clampf(_break_at.x, BREAK_MIN_X, 1.0 - BREAK_MIN_X)
	# 割れた瞬間は一瞬だけ音を止め、そのあと二人の声が戻る
	SfxPlayer.play("katanuki_break")
	SfxPlayer.set_ambient_volume(-80.0)
	get_tree().create_timer(SILENCE_TIME).timeout.connect(func(): SfxPlayer.set_ambient_volume(0.0, UiTokens.TIME_PANEL))
	_end(&"broken")


func _end(r: StringName) -> void:
	result = r
	_hold.enabled = false
	_hold.is_down = false
	_show_hint(false)
	GameState.set_katanuki_result(r)
	if r == &"clean":
		SfxPlayer.play("katanuki_clean")
		SfxPlayer.set_ambient_volume(0.0, UiTokens.TIME_PANEL)
		say(Strings.KATANUKI_CLEAN, Strings.KATANUKI_STALL_NAME)
	_go(Phase.RESULT)


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


## 結果の演出は、決定キーやタップで早送りできる
func _input(event: InputEvent) -> void:
	if phase == Phase.RESULT:
		var tap: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_speed = UiTokens.SKIP_SPEED
			get_viewport().set_input_as_handled()


# --- 型の形 -------------------------------------------------------------------

## いま針を当てている場所（型の中の座標）
func _needle_point() -> Vector2:
	if part >= PARTS.size():
		return OUTLINE[-1][-1]
	return _point_on(OUTLINE[part], carved[part])


## 折れ線の、はじめから u（0〜1）の割合の場所
func _point_on(line: Array, u: float) -> Vector2:
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var want := total * clampf(u, 0.0, 1.0)
	for i in line.size() - 1:
		var seg: float = line[i].distance_to(line[i + 1])
		if want <= seg or i == line.size() - 2:
			return line[i].lerp(line[i + 1], clampf(want / maxf(seg, 0.0001), 0.0, 1.0))
		want -= seg
	return line[-1]


## 折れ線の、はじめから u の割合までの部分
func _part_of(line: Array, u: float) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	if u <= 0.0:
		return out
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var want := total * clampf(u, 0.0, 1.0)
	for i in line.size() - 1:
		var seg: float = line[i].distance_to(line[i + 1])
		if want <= seg:
			out.append(line[i].lerp(line[i + 1], want / maxf(seg, 0.0001)))
			return out
		out.append(line[i + 1])
		want -= seg
	return out


## ひよこの形（輪郭を一周つないだもの）：頭 → くちばし → おなか → 足 → しっぽ → 背中（後ろの4つは逆向きにたどる）
func _chick_polygon() -> PackedVector2Array:
	var ring := PackedVector2Array()
	for idx in [0, 1, 5, 4, 3, 2]:
		var l: Array = OUTLINE[idx].duplicate()
		if idx >= 2:
			l.reverse()
		for p in l:
			ring.append(p)
	return _dedupe(ring)


func _dedupe(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[-1].distance_to(p) > 0.001:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[-1]) < 0.001:
		out.remove_at(out.size() - 1)
	return out


## ひびの線：輪郭の細いところから、型のふちへ向かってのびる（いつも同じ形）
func _make_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	var starts := [Vector2(0.80, 0.28), Vector2(0.50, 0.86), Vector2(0.16, 0.44), Vector2(0.60, 0.13), Vector2(0.76, 0.52)]
	for st in starts:
		var dir: Vector2 = (st - Vector2(0.5, 0.5)).normalized()
		var pts := PackedVector2Array([st])
		var p: Vector2 = st
		for i in 4:
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			p += dir * rng.randf_range(0.05, 0.09)
			pts.append(p)
		_cracks.append(pts)


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s))
	# 型は台の上のまん中に大きく（スマホでも見えるように）。手前のふちより少し奥に置く
	var side := minf(s.y * 0.6, s.x * 0.42)
	var h := side * MOLD_TILT
	var bottom := minf(_on_bg(Vector2(0.5, TABLE_FRONT)).y - side * 0.04, s.y * 0.88)
	var rect := Rect2(Vector2(s.x * 0.5 - side * 0.5, bottom - h), Vector2(side, h))
	var shake := Vector2.ZERO
	if not UiAnim.reduced():
		var c := _clock()
		if _jolt_t > 0.0:
			shake += Vector2(sin(c * 70.0), cos(c * 55.0)) * JOLT * (_jolt_t / JOLT_TIME)
		if phase == Phase.CARVE and _hold.is_down and crack_stage() == 2:
			shake += Vector2(sin(c * 90.0), cos(c * 77.0)) * TREMBLE
	# となりのタケル（小さく。型より先に描き、台の向こうに立たせる）
	_draw_takeru(side)
	_draw_mold(rect, carved, part, crack, result == &"broken", result == &"clean", _break_at, true)
	if phase == Phase.CARVE or phase == Phase.INTRO:
		_draw_needle(rect, _needle_point(), shake)


## 絵の中の場所（0〜1）が、画面のどこに来るか（MinigameBg.draw_cover と同じ切り取り方）
func _on_bg(f: Vector2) -> Vector2:
	var ts := BG.get_size()
	var k := maxf(size.x / ts.x, size.y / ts.y)
	var src_pos := (ts - size / k) * 0.5
	return (f * ts - src_pos) * k


## 型（砂糖の板）。rect は板の大きさ、carv は部分ごとの削れ具合、cur はいまの部分
func _draw_mold(rect: Rect2, carv: Array, cur: int, ck: float, broken: bool, clean: bool, break_at: Vector2, mine: bool) -> void:
	var to := func(p: Vector2) -> Vector2: return rect.position + p * rect.size
	var lw := maxf(rect.size.x / 70.0, 2.0)
	var board := _board_polygon(rect)
	if broken:
		_draw_broken(rect, board, carv, break_at, lw)
		return
	draw_colored_polygon(_moved(board, Vector2(4, 6)), Color(0, 0, 0, 0.25))
	draw_colored_polygon(board, P.KATANUKI)
	draw_polyline(_closed(board), P.KATANUKI_EDGE, lw * 0.6)
	var chick := PackedVector2Array()
	for p in _chick_polygon():
		chick.append(to.call(p))
	if clean:
		# ひよこが抜けたあとのくぼみと、持ち上げたひよこ
		draw_colored_polygon(chick, P.KATANUKI_HOLLOW)
		var lifted := _moved(chick, Vector2(rect.size.x * 0.06, -rect.size.y * 0.08))
		draw_colored_polygon(_moved(lifted, Vector2(3, 5)), Color(0, 0, 0, 0.2))
		draw_colored_polygon(lifted, P.KATANUKI)
		draw_polyline(_closed(lifted), P.KATANUKI_GROOVE, lw)
		draw_circle(to.call(EYE) + Vector2(rect.size.x * 0.06, -rect.size.y * 0.08), lw * 1.2, P.KATANUKI_GROOVE)
		return
	# 刷られた輪郭（うすい線）と、削ったところ（深い溝）
	for i in OUTLINE.size():
		var line: Array = OUTLINE[i]
		var pts := PackedVector2Array()
		for p in line:
			pts.append(to.call(p))
		if mine and i == cur:
			# いま削っている部分は夕焼け色でうすく縁どる（飾り）
			draw_polyline(pts, Color(UiTokens.ACCENT, 0.55), lw * 2.6)
		draw_polyline(pts, P.KATANUKI_PRINT, lw * 0.6)
		var done := PackedVector2Array()
		for p in _part_of(line, carv[i]):
			done.append(to.call(p))
		if done.size() > 1:
			draw_polyline(done, P.KATANUKI_GROOVE, lw * 1.3)
	draw_circle(to.call(EYE), lw * 1.1, P.KATANUKI_PRINT)
	# ひびの線（多めで入り、危ないで伸びる）
	var k := clampf((ck - CRACK_SOME) / (1.0 - CRACK_SOME), 0.0, 1.0)
	if k > 0.0:
		var n := 2 if ck < CRACK_DANGER else _cracks.size()
		for j in n:
			var cpts: PackedVector2Array = _cracks[j]
			var seg := PackedVector2Array()
			for p in _part_of(Array(cpts), k):
				seg.append(to.call(p))
			if seg.size() > 1:
				draw_polyline(seg, P.KATANUKI_CRACK, maxf(lw * 0.5, 1.5))
	# いま削っている場所の印（小さな ● ）
	if mine and cur < OUTLINE.size():
		draw_circle(to.call(_point_on(OUTLINE[cur], carv[cur])), lw * 1.6, UiTokens.ACCENT_INK)


## 割れた型：ぎざぎざの線で二つに割れ、少しずれる（ひよこが まっぷたつ）
func _draw_broken(rect: Rect2, board: PackedVector2Array, carv: Array, at: Vector2, lw: float) -> void:
	var to := func(p: Vector2) -> Vector2: return rect.position + p * rect.size
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var cut := PackedVector2Array()
	var steps := 7
	for i in steps + 1:
		var y := -0.1 + 1.2 * float(i) / steps
		var x := at.x + (y - at.y) * 0.25 + (0.0 if i == 0 or i == steps else rng.randf_range(-0.05, 0.05))
		cut.append(to.call(Vector2(x, y)))
	var left_half := PackedVector2Array(cut)
	left_half.append(rect.position + Vector2(-rect.size.x, rect.size.y * 1.2))
	left_half.append(rect.position + Vector2(-rect.size.x, -rect.size.y * 0.2))
	var right_half := PackedVector2Array(cut)
	right_half.append(rect.position + Vector2(rect.size.x * 2.0, rect.size.y * 1.2))
	right_half.append(rect.position + Vector2(rect.size.x * 2.0, -rect.size.y * 0.2))
	var gap := rect.size.x * 0.035
	for half in [[left_half, Vector2(-gap, gap * 0.4)], [right_half, Vector2(gap, -gap * 0.2)]]:
		var off: Vector2 = half[1]
		for piece in Geometry2D.intersect_polygons(board, half[0]):
			draw_colored_polygon(_moved(piece, off + Vector2(4, 6)), Color(0, 0, 0, 0.25))
			draw_colored_polygon(_moved(piece, off), P.KATANUKI)
			draw_polyline(_closed(_moved(piece, off)), P.KATANUKI_EDGE, lw * 0.6)
			for i in OUTLINE.size():
				var pts := PackedVector2Array()
				for p in OUTLINE[i]:
					pts.append(to.call(p))
				for clip in Geometry2D.intersect_polyline_with_polygon(pts, piece):
					draw_polyline(_moved(clip, off), P.KATANUKI_PRINT, lw * 0.6)
				var done := PackedVector2Array()
				for p in _part_of(OUTLINE[i], carv[i]):
					done.append(to.call(p))
				if done.size() > 1:
					for clip in Geometry2D.intersect_polyline_with_polygon(done, piece):
						draw_polyline(_moved(clip, off), P.KATANUKI_GROOVE, lw * 1.3)


## 針と手元
func _draw_needle(rect: Rect2, at: Vector2, shake: Vector2) -> void:
	var tip := rect.position + at * rect.size + shake
	var back := tip + Vector2(rect.size.x * 0.22, -rect.size.y * 0.3)
	draw_line(tip, back, Color("#C9CDD0"), maxf(rect.size.x / 120.0, 2.0))
	# 指先（押しているあいだ、少し沈む）
	var press := 3.0 if _hold.is_down else 0.0
	draw_circle(back + Vector2(-4, 4 + press), rect.size.x * 0.045, P.PLAYER_SKIN)
	draw_circle(back + Vector2(10, -4 + press), rect.size.x * 0.04, P.PLAYER_SKIN.darkened(0.05))


## となりのタケルと、タケルの型（小さく）
func _draw_takeru(side: float) -> void:
	var small := side * 0.42
	var back := _on_bg(Vector2(TAKERU_X, TABLE_BACK))
	var front := _on_bg(Vector2(TAKERU_X, TABLE_FRONT))
	var cx := back.x
	var h := small * MOLD_TILT
	# 型は台の上、手前のふちと向こうのふちのあいだ
	var cy := lerpf(back.y, front.y, 0.55)
	var rect := Rect2(Vector2(cx - small * 0.5, cy - h * 0.5), Vector2(small, h))
	# タケル（台の向こうで前かがみ。腰から下は台のふちにかくれる）
	var tex := TAKERU_BROKEN if takeru_broken else TAKERU_CARVE
	var k := small * (TAKERU_BROKEN_SCALE if takeru_broken else TAKERU_CARVE_SCALE)
	var src := Rect2(Vector2.ZERO, tex.get_size())
	if not takeru_broken:
		src.size.y = TAKERU_CARVE_CUT
	var dst := Rect2(Vector2(cx - src.size.x * k * 0.5, back.y - src.size.y * k), src.size * k)
	draw_texture_rect_region(tex, dst, src)
	# タケルの型（あたま・くちばし・せなかまで削ったところで割れる）
	var tk: Array[float] = [1.0, 1.0, 0.6, 0.0, 0.0, 0.0]
	if not takeru_broken:
		var g := clampf(float(part) / TAKERU_BREAK_PART, 0.0, 1.0)
		tk = [clampf(g * 2.0, 0.0, 1.0), clampf(g * 2.0 - 1.0, 0.0, 1.0), clampf(g * 2.0 - 1.4, 0.0, 0.6), 0.0, 0.0, 0.0]
	_draw_mold(rect, tk, -1, 0.0, takeru_broken, false, _takeru_break_at, false)


func _board_polygon(rect: Rect2) -> PackedVector2Array:
	var c := rect.size.x * 0.06
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x, b.y - c),
		Vector2(b.x - c, b.y), Vector2(a.x + c, b.y), Vector2(a.x, b.y - c), Vector2(a.x, a.y + c)])


func _moved(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + off)
	return out


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	if pts.size() > 0:
		out.append(pts[0])
	return out


## 絵の動き（動きを減らす設定では止める）
func _clock() -> float:
	return 0.0 if UiAnim.reduced() else float(Time.get_ticks_msec()) / 1000.0
