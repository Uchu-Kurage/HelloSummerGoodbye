class_name MovieScene
extends NatsumiScreen
## 映画会（7日目、初恋ルート）。会話の @game movie で始まる。ミニゲームではなく、見ているだけの場面。
## 映画は見せず、暗い公民館とスクリーンの明かりのちらつき、音（上の小札に書く）だけで表す。
## こわい場面でスクリーンが一瞬明るくなり、最後にあかりがつく。決定キー／タップで早送りできる。

## 音ひとつぶんの長さ（Strings.MOVIE_SOUNDS の順）
const SOUND_TIME := 1.7
const P := preload("res://world/world_palette.gd")

var _t := 0.0
var _shown := -1


func _build() -> void:
	set_ambient("")


func _process(delta: float) -> void:
	_t += delta * speed
	var i := int(_t / SOUND_TIME)
	if i != _shown and i < Strings.MOVIE_SOUNDS.size():
		_shown = i
		caption(Strings.MOVIE_SOUNDS[i])
		if i == Strings.MOVIE_SOUNDS.size() - 2:
			SfxPlayer.play("heartbeat")
	if _t >= SOUND_TIME * Strings.MOVIE_SOUNDS.size() and not done:
		finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if is_tap(event):
		speed = UiTokens.SKIP_SPEED
		get_viewport().set_input_as_handled()


## こわい場面（最後から2つめの音）で、スクリーンが一瞬明るくなる。最後はあかりがつく
func _brightness() -> float:
	var n := Strings.MOVIE_SOUNDS.size()
	var scare := (n - 2) * SOUND_TIME
	var lights := (n - 1) * SOUND_TIME
	if _t >= lights:
		return 1.0
	var flick := 0.5 + 0.25 * sin(clock() * 9.0) * sin(clock() * 2.7)
	if _t >= scare and _t < scare + 0.35:
		return 1.0
	return flick * 0.6


func _draw() -> void:
	var s := size
	var lit := _t >= (Strings.MOVIE_SOUNDS.size() - 1) * SOUND_TIME
	draw_rect(Rect2(Vector2.ZERO, s), P.SHOP_WALL if lit else Color("#0C0B10"))
	# 正面のスクリーン（映画の中身は見せない。白い光がちらつくだけ）
	var screen := Rect2(s.x * 0.2, s.y * 0.14, s.x * 0.6, s.y * 0.42)
	var b := _brightness()
	draw_rect(screen, Color(P.SCREEN_LIGHT, 0.15 + 0.5 * b) if not lit else Color(P.CLOUD, 0.9))
	# 前に座っている村の人たちの頭の影
	var row_y := s.y * 0.74
	for i in 9:
		var x := s.x * (0.06 + i * 0.11)
		var r := 34.0 + (i % 3) * 4.0
		draw_circle(Vector2(x, row_y), r, Color("#1A1820") if not lit else P.WOOD_DARK)
		draw_rect(Rect2(x - r * 1.2, row_y + r * 0.6, r * 2.4, s.y), Color("#1A1820") if not lit else P.WOOD_DARK)
	# いちばん手前に、なつみとぼく（並んだ頭）
	var me := Vector2(s.x * 0.58, s.y * 0.94)
	var her := Vector2(s.x * 0.44, s.y * 0.95)
	for p in [her, me]:
		draw_circle(p, 58, Color("#100F14") if not lit else P.SHOP_DARK)
	# スクリーンの光が、ふたりの頭のふちを照らす
	draw_arc(her, 58, PI * 1.15, PI * 1.85, 16, Color(P.SCREEN_LIGHT, 0.35 * b), 3.0)
	draw_arc(me, 58, PI * 1.15, PI * 1.85, 16, Color(P.SCREEN_LIGHT, 0.35 * b), 3.0)
