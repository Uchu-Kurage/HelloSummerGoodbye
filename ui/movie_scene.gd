class_name MovieScene
extends NatsumiScreen
## 映画会（7日目、初恋ルート）。会話の @game movie で始まる。ミニゲームではなく、見ているだけの場面。
## 映画は見せず、うしろの席から見た暗い公民館とスクリーンの明かりのちらつき、音（上の小札に書く）だけで表す。
## こわい場面でスクリーンが一瞬明るくなり、最後にあかりがつく。決定キー／タップで早送りできる。

## 音ひとつぶんの長さ（Strings.MOVIE_SOUNDS の順）
const SOUND_TIME := 1.7
const P := preload("res://world/world_palette.gd")
## 背景の絵と、切り取るとき残したいところ（スクリーン）
const BG: Texture2D = preload("res://ui/minigame_bg/movie.jpg")
const BG_FOCUS := Vector2(0.5, 0.4)

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
	# 夜の公民館の映画会を、うしろの席から（Gemini の水彩）。スクリーンの明かりに合わせて部屋の暗さがちらつく
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var lit := _t >= (Strings.MOVIE_SOUNDS.size() - 1) * SOUND_TIME
	var b := _brightness()
	if lit:
		# あかりがついた：部屋があたたかく明るくなる
		draw_rect(Rect2(Vector2.ZERO, s), Color(P.KOMINKAN_LIGHT, 0.35))
	else:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55 * (1.0 - b)))
		# こわい場面：スクリーンが一瞬まっ白に光る
		if b >= 1.0:
			draw_rect(Rect2(Vector2.ZERO, s), Color(P.SCREEN_LIGHT, 0.25))
