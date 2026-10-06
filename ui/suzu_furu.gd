class_name SuzuFuru
extends NatsumiScreen
## 鈴を振る（10日目のバス、神隠しルート）。会話の @game suzu_furu で始まる。ミニゲームではない。
## バスの車内で、手のひらの鈴を振る。いちどめだけ「ちりん」と鳴る。そのあとは、いくら振っても鳴らない。
## 鳴ったあと、少しして「タップで とじる」。

const SHAKE_TIME := 0.5
const CLOSE_AFTER := 1.2
const RING_TIME := 1.6
const BELL: Texture2D = preload("res://data/items/icons/rusty_bell.png")
const P := preload("res://world/world_palette.gd")
## 背景の絵（朝のバスの車内）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/suzu_furu.jpg")
const BG_FOCUS := Vector2(0.5, 0.6)

var shakes := 0
var rang := false
var _shake_t := 0.0
var _since_ring := -1.0
var _can_close := false


func _build() -> void:
	show_hint(Strings.SUZU_FURU_HINT_TOUCH, Strings.SUZU_FURU_HINT_KEY)


## 振る（自動の動作確認からも呼べる）
func shake() -> void:
	if done:
		return
	if _can_close:
		SfxPlayer.play("accept")
		hide_hint()
		finish()
		return
	shakes += 1
	_shake_t = SHAKE_TIME
	if not rang:
		rang = true
		_since_ring = 0.0
		SfxPlayer.play("suzu")
		caption(Strings.SUZU_FURU_RING)
		hide_hint()
	else:
		caption(Strings.SUZU_FURU_SILENT)


func can_close() -> bool:
	return _can_close


func _process(delta: float) -> void:
	_shake_t = maxf(0.0, _shake_t - delta)
	if _since_ring >= 0.0:
		_since_ring += delta
		if _since_ring >= CLOSE_AFTER and not _can_close:
			_can_close = true
			show_hint(Strings.SUZU_FURU_CLOSE_TOUCH, Strings.SUZU_FURU_CLOSE_KEY)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if is_tap(event):
		get_viewport().set_input_as_handled()
		shake()


func _draw() -> void:
	var s := size
	# 並べ終わる前（大きさ 0）は描かない
	if s.x < 1.0 or s.y < 1.0:
		return
	# 朝のバスの車内（水彩の絵）
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	# ひざの上で振る鈴（振ると左右にゆれる）
	var c := Vector2(s.x / 2.0, s.y * 0.6)
	var rot := 0.0
	if _shake_t > 0.0 and not UiAnim.reduced():
		rot = sin(_shake_t * 40.0) * 0.35 * (_shake_t / SHAKE_TIME)
	var sz := 170.0
	draw_set_transform(c, rot)
	draw_texture_rect(BELL, Rect2(-sz / 2.0, -sz / 2.0, sz, sz), false)
	draw_set_transform(Vector2.ZERO)
	# 鳴ったときだけ、音の輪が広がる
	if _since_ring >= 0.0 and _since_ring < RING_TIME:
		var k := _since_ring / RING_TIME
		for j in 3:
			var r := 100.0 + (k + j * 0.2) * 160.0
			draw_arc(c, r, -PI * 0.9, -PI * 0.1, 24, Color(1, 1, 0.92, 0.6 * (1.0 - k)), 3.0)
