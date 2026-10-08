class_name YomiseGame
extends MinigameBase
## ミニゲーム「夜市の物々交換」（5日目、神隠しルート）。会話の @game yomise で始まる。
## 青い提灯の夜市に、顔の見えない店の人の屋台が4つ。てもとは「夜市の品」3つ（ふうりん・かざぐるま・ほおずき。宝箱のアイテムは使わない）。
## 左右で屋台を選び、決定でほしい物を聞く（屋台の上に「ほしい物 → くれる物」が出る）。もう一度決定で、持っていれば交換する。
## 交換をつないでいく（MAX_TRADES 回まで）。あめ玉を手に入れたらおしまい：
## - あめや：ほおずき → ふつうの青いあめ玉（すぐ手に入る）
## - かざぐるま → ガラスの おはじき → 青い ちょうちん → いちばん きれいな あめ玉
## いちばん きれいな あめ玉までたどり着いたら「よくできた」。どちらのあめ玉も、会話の @give yomise_ame で宝箱に入る。

enum Phase { CHOOSE, TRADE, END }

## 品物（Strings.YOMISE_GOODS の番号）
enum Goods { FURIN, KAZAGURUMA, HOOZUKI, OHAJIKI, CHOCHIN, AME, AME_BEST }
## 「よくできた」になる品物（いちばん きれいな あめ玉）
const GOOD_GOODS := Goods.AME_BEST
const START_GOODS := [Goods.FURIN, Goods.KAZAGURUMA, Goods.HOOZUKI]
## 屋台ごとの交換（[ほしい物, くれる物]）。あめ玉をもらったら、おしまい
const STALLS := [
	[Goods.HOOZUKI, Goods.AME],
	[Goods.KAZAGURUMA, Goods.OHAJIKI],
	[Goods.OHAJIKI, Goods.CHOCHIN],
	[Goods.CHOCHIN, Goods.AME_BEST],
]
const MAX_TRADES := 5
## 交換の動きの時間と、おわってから見せる時間
const TRADE_TIME := 1.3
const END_TIME := 2.0
const P := preload("res://world/world_palette.gd")
const K := preload("res://world/kamikakushi_prop.gd")
## 背景の絵（青い提灯の夜市）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/yomise.jpg")
const BG_FOCUS := Vector2(0.5, 0.3)

var phase := Phase.CHOOSE
var cursor := 0
## てもとの品物
var held: Array[int] = []
var trades := 0
var refusals := 0
var got := -1
var rng := RandomNumberGenerator.new()
## 並んでいる屋台の順（STALLS の番号）と、聞いたか・交換したか
var order: Array[int] = []
var _asked: Array[bool] = []
var _done_stall: Array[bool] = []
var _t := 0.0


func _setup() -> void:
	intro_text = Strings.YOMISE_INTRO
	arrows = true
	set_ambient(WorldPalette.OTHERWORLD_AMBIENT)


func _begin() -> void:
	rng.seed = 55 + round_count
	phase = Phase.CHOOSE
	cursor = 0
	held.assign(START_GOODS)
	trades = 0
	refusals = 0
	got = -1
	order.assign([0, 1, 2, 3])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	_asked.assign([false, false, false, false])
	_done_stall.assign([false, false, false, false])
	_hand_caption()
	show_hint(Strings.YOMISE_HINT_TOUCH, Strings.YOMISE_HINT_KEY)


func _hand_caption() -> void:
	var names: PackedStringArray = []
	for g in held:
		names.append(Strings.YOMISE_GOODS[g])
	caption(Strings.YOMISE_HAND % ["、".join(names), MAX_TRADES - trades])


func _process_game(delta: float) -> void:
	_t += delta
	match phase:
		Phase.TRADE:
			if _t >= TRADE_TIME:
				speed = 1.0
				if got >= 0 or trades >= MAX_TRADES:
					_end()
				else:
					phase = Phase.CHOOSE
					_hand_caption()
		Phase.END:
			if _t >= END_TIME:
				end_game(got == GOOD_GOODS, got)


func _end() -> void:
	phase = Phase.END
	_t = 0.0
	hide_hint()
	if got < 0:
		# 交換しきれなかったときも、あめやは ふつうの あめ玉をくれる（会話の @give yomise_ame とそろえる）
		got = Goods.AME
	caption(Strings.YOMISE_GOT % Strings.YOMISE_GOODS[got])


func _left() -> void:
	if phase == Phase.CHOOSE and cursor > 0:
		cursor -= 1
		SfxPlayer.play("cursor")


func _right() -> void:
	if phase == Phase.CHOOSE and cursor < order.size() - 1:
		cursor += 1
		SfxPlayer.play("cursor")


func _accept(pos: Variant = null) -> void:
	if phase != Phase.CHOOSE:
		speed = UiTokens.SKIP_SPEED
		return
	if pos is Vector2:
		var hit := _stall_at(pos)
		if hit < 0:
			return
		# タッチ：タップした屋台に、そのまま聞く（聞いたあとなら交換する）
		cursor = hit
	act(cursor)


## 屋台に、聞く（はじめて）／交換する（自動の動作確認からも呼べる）
func act(slot: int) -> void:
	if phase != Phase.CHOOSE or slot < 0 or slot >= order.size() or _done_stall[slot]:
		return
	cursor = slot
	var st: Array = STALLS[order[slot]]
	if not _asked[slot]:
		_asked[slot] = true
		SfxPlayer.play("accept")
		caption(Strings.YOMISE_WANTS % [Strings.YOMISE_GOODS[st[0]], Strings.YOMISE_GOODS[st[1]]])
		return
	if not held.has(st[0]):
		refusals += 1
		SfxPlayer.play("cancel")
		caption(Strings.YOMISE_NO % Strings.YOMISE_GOODS[st[0]])
		return
	held.erase(st[0])
	held.append(st[1])
	trades += 1
	_done_stall[slot] = true
	SfxPlayer.play("pickup")
	caption(Strings.YOMISE_TRADED % Strings.YOMISE_GOODS[st[1]])
	if st[1] in [Goods.AME, Goods.AME_BEST]:
		got = st[1]
	phase = Phase.TRADE
	_t = 0.0


func bot(good: bool) -> Dictionary:
	if phase != Phase.CHOOSE:
		return {}
	# よくできた：かざぐるま → おはじき → ちょうちん → いちばん きれいな あめ玉。ふつう：あめやで ほおずき
	var want_stall := 0
	if good:
		for s in [1, 2, 3]:
			if held.has(STALLS[s][0]):
				want_stall = s
				break
	var want := order.find(want_stall)
	if want < cursor:
		return {"key": KEY_LEFT, "tap": _stall_tap(want)}
	if want > cursor:
		return {"key": KEY_RIGHT, "tap": _stall_tap(want)}
	return {"key": KEY_SPACE, "tap": _stall_tap(want)}


# --- 絵 -----------------------------------------------------------------------

func _stall_foot(slot: int) -> Vector2:
	return Vector2(size.x * (0.17 + 0.22 * slot), size.y * 0.66)


func _stall_tap(slot: int) -> Vector2:
	return global_position + _stall_foot(slot) + Vector2(0, -60)


func _stall_at(pos: Vector2) -> int:
	var local: Vector2 = pos - global_position
	for i in order.size():
		var f := _stall_foot(i)
		if Rect2(f + Vector2(-size.x * 0.1, -size.y * 0.42), Vector2(size.x * 0.2, size.y * 0.46)).has_point(local):
			return i
	return -1


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.04, 0.1, 0.25))
	if order.is_empty():
		return
	var h := s.y * 0.22
	for i in order.size():
		var f := _stall_foot(i)
		# 屋台の台と、顔の見えない店の人
		draw_rect(Rect2(f + Vector2(-h * 0.55, -h * 0.35), Vector2(h * 1.1, h * 0.35)), P.WOOD_DARK)
		draw_rect(Rect2(f + Vector2(-h * 0.6, -h * 0.4), Vector2(h * 1.2, h * 0.08)), P.WOOD)
		K.draw_vendor(self, f + Vector2(0, -h * 0.3), h * 0.9)
		var st: Array = STALLS[order[i]]
		var sign_c := f + Vector2(0, -h * 1.45)
		if _done_stall[i]:
			draw_goods(self, st[0], sign_c, 0.9)
		elif _asked[i]:
			# ほしい物 → くれる物
			draw_rect(Rect2(sign_c + Vector2(-h * 0.62, -h * 0.22), Vector2(h * 1.24, h * 0.44)), Color(UiTokens.PAPER, 0.92))
			draw_goods(self, st[0], sign_c + Vector2(-h * 0.36, 0), 0.75)
			draw_line(sign_c + Vector2(-h * 0.1, 0), sign_c + Vector2(h * 0.08, 0), UiTokens.INK_SOFT, 3.0)
			draw_colored_polygon(PackedVector2Array([sign_c + Vector2(h * 0.14, 0), sign_c + Vector2(h * 0.06, -7), sign_c + Vector2(h * 0.06, 7)]), UiTokens.INK_SOFT)
			draw_goods(self, st[1], sign_c + Vector2(h * 0.36, 0), 0.75)
		else:
			draw_string(get_theme_default_font(), sign_c + Vector2(-8, 10), "？", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_HEADING, Color(1, 1, 1, 0.8))
		if i == cursor and phase == Phase.CHOOSE:
			draw_arc(f + Vector2(0, 8), h * 0.5, 0.15 * PI, 0.85 * PI, 18, UiTokens.ACCENT, 4.0)
	# てもと（下に並べる）
	var x := s.x * 0.5 - held.size() * 34.0
	for g in held:
		draw_circle(Vector2(x + 34, s.y * 0.84), 30, Color(UiTokens.PAPER, 0.9))
		draw_goods(self, g, Vector2(x + 34, s.y * 0.84), 0.8)
		x += 68.0


## 品物の小さな絵（Goods の番号）
static func draw_goods(ci: CanvasItem, i: int, c: Vector2, k: float) -> void:
	match i:
		Goods.FURIN:
			ci.draw_arc(c + Vector2(0, -2) * k, 14 * k, PI, TAU, 12, Color("#BFE3F2"), 10.0 * k)
			ci.draw_line(c + Vector2(0, 0), c + Vector2(0, 16) * k, UiTokens.INK_SOFT, 2.0 * k)
			ci.draw_rect(Rect2(c + Vector2(-5, 16) * k, Vector2(10, 12) * k), Color("#E9DCC0"))
		Goods.KAZAGURUMA:
			ci.draw_line(c, c + Vector2(0, 24) * k, P.WOOD, 3.0 * k)
			for j in 4:
				var a := TAU * j / 4.0 + 0.4
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * 20 * k, c + Vector2(cos(a + 0.7), sin(a + 0.7)) * 13 * k]),
					[Color("#C8462E"), Color("#E8B83A"), Color("#4F78A8"), Color("#6F8A4E")][j])
		Goods.HOOZUKI:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16) * k, c + Vector2(13, 2) * k, c + Vector2(0, 16) * k, c + Vector2(-13, 2) * k]), Color("#E0703A"))
			ci.draw_line(c + Vector2(0, -16) * k, c + Vector2(0, -22) * k, P.WOOD_DARK, 2.0 * k)
		Goods.OHAJIKI:
			for j in 3:
				ci.draw_circle(c + Vector2(-10 + j * 10, (j % 2) * 6 - 3) * k, 7 * k, [Color("#9FD3C7"), Color("#F2B8C6"), Color("#B9C8F0")][j])
		Goods.CHOCHIN:
			ci.draw_rect(Rect2(c + Vector2(-8, -18) * k, Vector2(16, 4) * k), P.WOOD_DARK)
			ci.draw_circle(c, 14 * k, P.BLUE_LANTERN)
			ci.draw_rect(Rect2(c + Vector2(-8, 14) * k, Vector2(16, 4) * k), P.WOOD_DARK)
		Goods.AME, Goods.AME_BEST:
			var best := i == Goods.AME_BEST
			var col := Color("#B48DE8") if best else Color("#8FC0EA")
			ci.draw_circle(c, 13 * k, col)
			ci.draw_circle(c + Vector2(-4, -4) * k, 5 * k, Color(1, 1, 1, 0.7))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0) * k, c + Vector2(-24, -9) * k, c + Vector2(-24, 9) * k]), Color("#E9F0F4"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(12, 0) * k, c + Vector2(24, -9) * k, c + Vector2(24, 9) * k]), Color("#E9F0F4"))
			if best:
				for j in 4:
					var a := TAU * j / 4.0 + 0.8
					ci.draw_line(c + Vector2(cos(a), sin(a)) * 16 * k, c + Vector2(cos(a), sin(a)) * 22 * k, Color(1, 0.95, 0.7), 2.0 * k)
