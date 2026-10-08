class_name KatanukiGame
extends MinigameBase
## ミニゲーム「型抜き」（5日目、夏祭りの型抜き屋台でタケルと並んで）。会話の @game katanuki で始まる。
## ひよこの型の輪郭を、針が6つの点（頭 → くちばし → 背中 → しっぽ → 足 → おなか）の順に進む。
## 点ごとに小さなゲージが左右に揺れ、緑の範囲で決定を押すと次の点へ。外すとひびが入り、ひびが MAX_CRACKS で割れる。
## 先にタケルの型が割れる（しっぽのころ。「……あーっ！ われた！」）。
## 結果は GameState.katanuki_result（&"clean"／&"broken"）とフラグ katanuki_clean / katanuki_broken。割らずに抜けば「よくできた」。

enum Phase { MOVE, CARVE, DONE }

## 部分ごとの、緑の範囲の幅（0〜1。くちばしと足は細いので狭い）と、ゲージの片道の秒数
const PARTS := [
	{"name": "あたま", "green": 0.26, "period": 0.8},
	{"name": "くちばし", "green": 0.14, "period": 0.7},
	{"name": "せなか", "green": 0.32, "period": 0.9},
	{"name": "しっぽ", "green": 0.24, "period": 0.8},
	{"name": "あし", "green": 0.14, "period": 0.7},
	{"name": "おなか", "green": 0.32, "period": 0.9},
]
## ひびがこの数で割れる（仮の値）。割らずに抜けば（GOOD_RESULT）「よくできた」
const MAX_CRACKS := 3
const GOOD_RESULT := &"clean"
## タケルの型が割れる部分（しっぽ）
const TAKERU_BREAK_PART := 3
## 針が次の点まで、輪郭にそって削っていく時間
const TRAVEL := 3.4
const BG: Texture2D = preload("res://ui/minigame_bg/katanuki.jpg")
const BG_FOCUS := Vector2(0.5, 0.6)
const P := preload("res://world/world_palette.gd")
## 型の上の6つの点（型の大きさに対する割合）
const POINTS := [Vector2(0.62, 0.22), Vector2(0.86, 0.32), Vector2(0.3, 0.3), Vector2(0.1, 0.55), Vector2(0.55, 0.92), Vector2(0.72, 0.68)]

var phase := Phase.CARVE
var part := 0
var cracks := 0
var at := 0.0
var takeru_broken := false
var result := &""
var _t := 0.0
## ゲージの緑のまん中（部分ごとにずらす）
var _green_at := 0.5


func _setup() -> void:
	intro_text = Strings.KATA_INTRO


func _begin() -> void:
	phase = Phase.CARVE
	part = 0
	cracks = 0
	takeru_broken = false
	result = &""
	_next_part()
	hush()
	show_hint(Strings.KATA_HINT_TOUCH, Strings.KATA_HINT_KEY)


func _next_part() -> void:
	_t = 0.0
	phase = Phase.MOVE if part > 0 else Phase.CARVE
	_green_at = [0.5, 0.35, 0.6, 0.45, 0.65, 0.4][part]


func green() -> Vector2:
	var w: float = PARTS[part]["green"]
	return Vector2(_green_at - w / 2.0, _green_at + w / 2.0)


func _process_game(delta: float) -> void:
	_t += delta
	if phase == Phase.MOVE:
		if _t >= TRAVEL:
			phase = Phase.CARVE
			_t = 0.0
		return
	if phase != Phase.CARVE:
		return
	at = swing(_t, PARTS[part]["period"])


func _accept(_pos: Variant = null) -> void:
	if phase != Phase.CARVE:
		return
	var g := green()
	if at >= g.x and at <= g.y:
		SfxPlayer.play("katanuki_scrape")
		part += 1
		if part == TAKERU_BREAK_PART and not takeru_broken:
			takeru_broken = true
			SfxPlayer.play("katanuki_break")
			say(Strings.KATANUKI_TAKERU_BREAK, Strings.TAKERU)
		if part >= PARTS.size():
			_end(&"clean")
			return
		_next_part()
	else:
		cracks += 1
		SfxPlayer.play("katanuki_crack")
		if cracks >= MAX_CRACKS:
			_end(&"broken")


func _end(r: StringName) -> void:
	phase = Phase.DONE
	result = r
	if not takeru_broken:
		takeru_broken = true
	GameState.set_katanuki_result(r)
	if r == &"clean":
		SfxPlayer.play("katanuki_clean")
		say(Strings.KATANUKI_CLEAN, Strings.KATANUKI_STALL_NAME)
	else:
		SfxPlayer.play("katanuki_break")
	end_game(r == GOOD_RESULT, cracks)


func _on_quit() -> void:
	GameState.set_katanuki_result(&"broken")


func bot(good: bool) -> Dictionary:
	if phase != Phase.CARVE:
		return {}
	var g := green()
	var c := (g.x + g.y) / 2.0
	# ふつう：2つ削ったあと、外しつづけて割る
	var hit := absf(at - c) < (g.y - g.x) * 0.25 if good or part < 2 else (at < g.x - 0.12 or at > g.y + 0.12)
	return {"key": KEY_SPACE, "tap": center_tap()} if hit else {}


func _draw() -> void:
	var s := size
	if s.x < 1.0:
		return
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	# 型（板）とひよこ。まん中に大きく
	var m := Rect2(s.x * 0.5 - s.y * 0.26, s.y * 0.22, s.y * 0.52, s.y * 0.42)
	draw_rect(m, P.KATANUKI)
	draw_rect(m, P.KATANUKI_EDGE, false, 3.0)
	var c := m.position + m.size * Vector2(0.5, 0.58)
	draw_circle(c, m.size.y * 0.3, P.KATANUKI_PRINT)
	draw_circle(m.position + m.size * Vector2(0.66, 0.3), m.size.y * 0.16, P.KATANUKI_PRINT)
	# 点：けずったところ（INK）、いま（ACCENT_INK の印）、まだ（うすい）
	for i in POINTS.size():
		var p: Vector2 = m.position + m.size * POINTS[i]
		var col := P.KATANUKI_GROOVE if i < part else Color(P.KATANUKI_GROOVE, 0.35)
		draw_circle(p, 7.0, col)
		if i == part and phase == Phase.CARVE:
			draw_arc(p, 13.0, 0, TAU, 20, UiTokens.ACCENT_INK, 3.0)
	# 削ってきた溝と、針（前の点から いまの点へ、輪郭にそって進む）
	if part > 0 and part < POINTS.size():
		var a: Vector2 = m.position + m.size * POINTS[part - 1]
		var b: Vector2 = m.position + m.size * POINTS[part]
		var k := clampf(_t / TRAVEL, 0.0, 1.0) if phase == Phase.MOVE else 1.0
		var tip := a.lerp(b, k)
		draw_line(a, tip, P.KATANUKI_GROOVE, 3.0)
		draw_line(tip, tip + Vector2(10, -34), UiTokens.INK, 2.0)
	# ひび
	for i in cracks:
		var a := m.position + m.size * Vector2(0.2 + 0.25 * i, 0.1)
		draw_polyline(PackedVector2Array([a, a + Vector2(14, 30), a + Vector2(2, 60), a + Vector2(18, 92)]), P.KATANUKI_CRACK, 3.0)
	if result == &"broken":
		draw_line(m.position + Vector2(m.size.x * 0.5, 0), m.position + Vector2(m.size.x * 0.45, m.size.y), P.KATANUKI_CRACK, 6.0)
	# タケルの型（となりに小さく。割れたら まっぷたつ）
	var tm := Rect2(m.position.x - m.size.x * 0.55, m.position.y + m.size.y * 0.45, m.size.x * 0.4, m.size.y * 0.35)
	draw_rect(tm, P.KATANUKI)
	if takeru_broken:
		draw_line(tm.position + Vector2(tm.size.x * 0.5, 0), tm.position + Vector2(tm.size.x * 0.4, tm.size.y), P.KATANUKI_CRACK, 4.0)
	# ゲージ
	if phase == Phase.CARVE:
		var g := green()
		draw_gauge(Rect2(s.x * 0.3, m.end.y + 24, s.x * 0.4, 26), at, g.x, g.y)
