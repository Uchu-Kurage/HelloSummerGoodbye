class_name KakurenboGame
extends NatsumiScreen
## ミニゲーム「かくれんぼ」（4日目、神隠しルート）。会話の @game kakurenbo で始まる。
## 夕立の境内。お面の子は、灯籠・大きな木・狛犬・さいせん箱のどれかのうしろに隠れている。
## 隠れていそうなところを調べる。いなければ「……いない」。MISS_HINT 回はずすと、隠れているところで鈴がかすかに鳴り、光る。
## 見つけたらおしまい。失敗はない。

enum Phase { SEEK, FOUND, END }

const MISS_HINT := 2
const END_TIME := 1.6
const CHOICE_SIZE := Vector2(176, 168)
const P := preload("res://world/world_palette.gd")
const K := preload("res://world/kamikakushi_prop.gd")
const FOX_TEX: Texture2D = preload("res://world/scenery/painted/npc_fox_child.png")
## 背景の絵（夕立の境内）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/kakurenbo.jpg")
const BG_FOCUS := Vector2(0.5, 0.4)
## 絵の上に重ねる、動く雨のすじの数
const STREAKS := 50

var phase := Phase.SEEK
var hiding := 0
var tries := 0
var rng := RandomNumberGenerator.new()
var _checked: Array[bool] = []
var _t := 0.0
var _hint_t := -1.0
var _row: HBoxContainer
var _buttons: Array[Button] = []


func _build() -> void:
	rng.randomize()
	hiding = rng.randi_range(0, Strings.KAKURENBO_SPOTS.size() - 1)
	set_ambient(WorldPalette.RAIN_AMBIENT)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTokens.TOUCH_GAP * 2)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_row)
	for i in Strings.KAKURENBO_SPOTS.size():
		_checked.append(false)
		var b := make_choice(i, CHOICE_SIZE, _draw_spot, _on_choice)
		var l := Label.new()
		l.text = Strings.KAKURENBO_SPOTS[i]
		l.theme_type_variation = &"SmallLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -30
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		_row.add_child(b)
		_buttons.append(b)
	link_row(_buttons)
	say(Strings.KAKURENBO_READY)
	show_hint(Strings.KAKURENBO_HINT_TOUCH, Strings.KAKURENBO_HINT_KEY)
	if InputMode.keyboard:
		_buttons[0].grab_focus.call_deferred()


func _on_choice(i: int) -> void:
	check_spot(i)


## そこを調べる（自動の動作確認からも呼べる）
func check_spot(i: int) -> void:
	if phase != Phase.SEEK or i < 0 or i >= _checked.size():
		return
	tries += 1
	_checked[i] = true
	if i == hiding:
		phase = Phase.FOUND
		_t = 0.0
		SfxPlayer.play("suzu")
		caption(Strings.KAKURENBO_FOUND)
		hide_hint()
		for b in _buttons:
			b.disabled = true
	else:
		SfxPlayer.play("cursor")
		caption(Strings.KAKURENBO_MISS)
		_buttons[i].disabled = true
		if tries >= MISS_HINT and _hint_t < 0.0:
			_hint_t = 0.0
			SfxPlayer.play("suzu_far")
			caption(Strings.KAKURENBO_BELL)
		if InputMode.keyboard:
			for b in _buttons:
				if not b.disabled:
					b.grab_focus()
					break
	_redraw_choices()


func _redraw_choices() -> void:
	for b in _buttons:
		for c in b.get_children():
			if c is Control:
				(c as Control).queue_redraw()


func _process(delta: float) -> void:
	_t += delta * speed
	if _hint_t >= 0.0:
		_hint_t += delta
		_redraw_choices()
	if phase == Phase.FOUND and _t >= END_TIME:
		phase = Phase.END
		finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if phase == Phase.FOUND and is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var s := size
	# 並べ終わる前（大きさ 0）は描かない
	if s.x < 1.0 or s.y < 1.0:
		return
	# 夕立の境内（水彩の絵）。雨は絵にも描いてあるので、動く雨のすじは少しだけ重ねる
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var c := clock()
	for i in STREAKS:
		var fx := fposmod(i * 0.6180339, 1.0)
		var fy := fposmod(i * 0.4142135 + c * 1.3, 1.0)
		var p := Vector2(fx * s.x, fy * s.y)
		draw_line(p, p + Vector2(-5, 22), Color(P.RAIN_STREAK, 0.35), 2.0)

func _draw_spot(a: Control, i: int) -> void:
	var foot := Vector2(a.size.x / 2.0, a.size.y - 34)
	if _hint_t >= 0.0 and i == hiding and phase == Phase.SEEK:
		var k := 0.5 + 0.5 * sin(_hint_t * 4.0) if not UiAnim.reduced() else 1.0
		a.draw_circle(foot + Vector2(0, -60), 52, Color(1.0, 0.95, 0.7, 0.18 + 0.12 * k))
	if phase != Phase.SEEK and i == hiding:
		# のぞいているお面の子（絵の上半分）
		var h := 120.0
		var w := FOX_TEX.get_width() * h / FOX_TEX.get_height()
		a.draw_texture_rect_region(FOX_TEX, Rect2(foot.x + 6, foot.y - h + 4, w, h * 0.5), Rect2(0, 0, FOX_TEX.get_width(), FOX_TEX.get_height() * 0.5))
	match i:
		0: K.draw_stone_lantern(a, foot, 110.0)
		1: K.draw_big_tree(a, foot, 130.0)
		2: K.draw_komainu(a, foot, 92.0)
		3: K.draw_saisen(a, foot, 96.0)
	if _checked[i] and i != hiding:
		# 調べたところは、うすく暗くする（色だけにたよらず、「いない」の小札でも伝える）
		a.draw_rect(Rect2(Vector2.ZERO, a.size), Color(UiTokens.INK_SOFT, 0.3))
