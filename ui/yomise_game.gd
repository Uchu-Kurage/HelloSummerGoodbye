class_name YomiseGame
extends NatsumiScreen
## ミニゲーム「夜市の物々交換」（5日目、神隠しルート）。会話の @game yomise で始まる。
## 青い提灯の夜市。顔の見えない店の人たちが、ほしいものと、自分の品物をとりかえてくれる。
## てもとの物（はじめは どんぐり）を、それをほしがる店で交換していく：どんぐり → かざぐるま → あおい りんごあめ → あおい あめだま。
## ちがう店を選ぶと、首を横にふられるだけ（失敗はない）。食べ物は交換できても、食べてはいけない。
## あめだまを手に入れたらおしまい（会話の @give yomise_ame で、宝箱に入る）。

enum Phase { TRADE, END }

## 交換のならび（Strings.YOMISE_GOODS の番号）。店 i は品物 i をほしがり、品物 i+1 をくれる
const FOOD := 2
const GOAL := 3
## 首を横にふられたのがこれ以下なら「よくできた」（仮の値）
const GOOD_REFUSALS := 0
const END_TIME := 1.8
const CHOICE_SIZE := Vector2(208, 150)
const P := preload("res://world/world_palette.gd")
const K := preload("res://world/kamikakushi_prop.gd")
## 背景の絵（青い提灯の夜市）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/yomise.jpg")
const BG_FOCUS := Vector2(0.5, 0.3)

var phase := Phase.TRADE
## てもとの品物（Strings.YOMISE_GOODS の番号）
var held := 0
var trades := 0
var refusals := 0
var rng := RandomNumberGenerator.new()
## 並んでいる店の順（店の番号）
var order: Array[int] = []
var _sold: Array[bool] = []
var _t := 0.0
var _row: HBoxContainer
var _buttons: Array[Button] = []
var _hand: Label


func _build() -> void:
	rng.randomize()
	set_ambient(WorldPalette.OTHERWORLD_AMBIENT)
	order = [0, 1, 2]
	# 並びは毎回かえる（ほしいものを見て選ぶ）
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	_hand = Label.new()
	_hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"PaperChip"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_hand)
	bottom.add_child(chip)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP * 2)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_row)
	for i in order.size():
		_sold.append(false)
		var b := make_choice(i, CHOICE_SIZE, _draw_stall, _on_choice)
		_row.add_child(b)
		_buttons.append(b)
	link_row(_buttons)
	_refresh_hand()
	say(Strings.YOMISE_START)
	show_hint(Strings.YOMISE_HINT_TOUCH, Strings.YOMISE_HINT_KEY)
	if InputMode.keyboard:
		_buttons[0].grab_focus.call_deferred()


func _refresh_hand() -> void:
	_hand.text = Strings.YOMISE_HAND % Strings.YOMISE_GOODS[held]


func _on_choice(i: int) -> void:
	trade(i)


## いま交換できる店の場所（並びの番号。自動の動作確認から使う）
func good_slot() -> int:
	return order.find(held)


## その店と交換する（並びの番号。自動の動作確認からも呼べる）
func trade(slot: int) -> void:
	if phase != Phase.TRADE or slot < 0 or slot >= order.size() or _sold[slot]:
		return
	var stall := order[slot]
	if stall != held:
		refusals += 1
		SfxPlayer.play("cancel")
		caption(Strings.YOMISE_NO)
		return
	held = stall + 1
	trades += 1
	_sold[slot] = true
	_buttons[slot].disabled = true
	SfxPlayer.play("pickup")
	_refresh_hand()
	if held == GOAL:
		phase = Phase.END
		_t = 0.0
		grade = GameState.Grade.GOOD if refusals <= GOOD_REFUSALS else GameState.Grade.NORMAL
		say(Strings.YOMISE_DONE)
		hide_hint()
	elif held == FOOD:
		say(Strings.YOMISE_FOOD)
	else:
		caption(Strings.YOMISE_TRADED)
	if InputMode.keyboard and phase == Phase.TRADE:
		for b in _buttons:
			if not b.disabled:
				b.grab_focus()
				break
	for b in _buttons:
		for c in b.get_children():
			if c is Control:
				(c as Control).queue_redraw()


func _process(delta: float) -> void:
	_t += delta * speed
	if phase == Phase.END and _t >= END_TIME and not done:
		finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if phase == Phase.END and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var s := size
	# 並べ終わる前（大きさ 0）は描かない
	if s.x < 1.0 or s.y < 1.0:
		return
	# 青い提灯の夜市（水彩の絵）
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)

func _draw_stall(a: Control, slot: int) -> void:
	var stall := order[slot]
	var mid := a.size / 2.0 + Vector2(0, 14)
	K.draw_vendor(a, Vector2(a.size.x / 2.0, 52), 46.0)
	if _sold[slot]:
		draw_goods(a, stall, mid, 1.0)
		return
	draw_goods(a, stall, mid + Vector2(-54, 0), 0.8)
	a.draw_line(mid + Vector2(-20, 0), mid + Vector2(16, 0), UiTokens.INK_SOFT, 3.0)
	a.draw_colored_polygon(PackedVector2Array([mid + Vector2(24, 0), mid + Vector2(12, -8), mid + Vector2(12, 8)]), UiTokens.INK_SOFT)
	draw_goods(a, stall + 1, mid + Vector2(58, 0), 0.8)


## 品物の小さな絵（Strings.YOMISE_GOODS の番号）
static func draw_goods(ci: CanvasItem, i: int, c: Vector2, k: float) -> void:
	match i:
		0:
			ci.draw_circle(c + Vector2(0, 6) * k, 14 * k, P.WOOD)
			ci.draw_rect(Rect2(c + Vector2(-14, -12) * k, Vector2(28, 12) * k), P.WOOD_DARK)
			ci.draw_line(c + Vector2(0, -12) * k, c + Vector2(0, -20) * k, P.WOOD_DARK, 3.0 * k)
		1:
			ci.draw_line(c + Vector2(0, 0), c + Vector2(0, 34) * k, P.WOOD, 3.0 * k)
			for j in 4:
				var a := TAU * j / 4.0 + 0.4
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * 24 * k, c + Vector2(cos(a + 0.7), sin(a + 0.7)) * 16 * k]),
					[Color("#C8462E"), Color("#E8B83A"), Color("#4F78A8"), Color("#6F8A4E")][j])
		2:
			ci.draw_line(c + Vector2(0, 8) * k, c + Vector2(0, 34) * k, P.WOOD, 3.0 * k)
			ci.draw_circle(c, 17 * k, P.BLUE_LANTERN)
			ci.draw_circle(c + Vector2(-5, -6) * k, 5 * k, Color(1, 1, 1, 0.6))
		3:
			ci.draw_circle(c, 15 * k, Color("#8FC0EA"))
			ci.draw_circle(c, 7 * k, Color("#E4F2FF"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 0) * k, c + Vector2(-28, -10) * k, c + Vector2(-28, 10) * k]), Color("#E9F0F4"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(14, 0) * k, c + Vector2(28, -10) * k, c + Vector2(28, 10) * k]), Color("#E9F0F4"))
