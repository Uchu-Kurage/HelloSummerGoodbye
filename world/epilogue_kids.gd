extends Node2D
## エピローグ「それから」の神社：きつねのお面の子と、麦わら帽子の男の子（子どものころの祖父）が、石段を駆け上がって
## 鳥居のむこうで消える。足もと（石段の下）が原点。近づくと自動で始まり（start）、決定キー・タップで早送り（speed）。
## 二人には近づけない（主人公が着くころには、もう誰もいない）。笑い声の音（kids_laugh）は素材がなければ鳴らない。

## 走る お面の子（右向き）と、男の子の絵（帽子は図形で重ねる。絵が入るまでの仮）
const FOX_TEX: Texture2D = preload("res://world/scenery/painted/fox_mg1_1.png")
const BOY_TEX: Texture2D = preload("res://world/scenery/painted/radio_kid_1.png")
const P := preload("res://world/world_palette.gd")
const KID_H := 128.0
## 鳥居までの距離（右へ・上へ）と、かけ上がる時間
const RUN_TO := Vector2(190, -70)
const RUN_TIME := 2.2

var started := false
var done := false
## 演出の速さ。早送りのときは UiTokens.SKIP_SPEED
var speed := 1.0
var _t := 0.0
var _fading := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## 駆け上がりはじめる（主人公が近づいたとき）
func start() -> void:
	if started:
		return
	started = true
	SfxPlayer.play("kids_laugh")


func _process(delta: float) -> void:
	if not started or done:
		return
	_t += delta * speed
	queue_redraw()
	if _t >= RUN_TIME and not _fading:
		# 鳥居のむこうで、ゆっくり消える（急に消さない）
		_fading = true
		var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_GLIMPSE_VANISH / speed)
		tw.finished.connect(func(): done = true)


func progress() -> float:
	return clampf(_t / RUN_TIME, 0.0, 1.0)


func _draw() -> void:
	var k := progress()
	# 奥へ行くほど小さく
	var s := lerpf(1.0, 0.7, k)
	var bob := 0.0 if UiAnim.reduced() else absf(sin(_t * 14.0)) * 6.0
	var fox_at := RUN_TO * k + Vector2(26, -bob)
	var boy_at := RUN_TO * k + Vector2(-34, -absf(sin(_t * 14.0 + 1.3)) * 6.0 * float(not UiAnim.reduced()))
	_kid(FOX_TEX, fox_at, KID_H * s)
	_kid(BOY_TEX, boy_at, KID_H * 0.98 * s)
	# 麦わら帽子
	var top := boy_at + Vector2(0, -KID_H * 0.98 * s)
	draw_set_transform(top + Vector2(0, 10 * s), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 24 * s, P.STRAW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(top + Vector2(0, 4 * s), 13 * s, P.STRAW)
	draw_rect(Rect2(top + Vector2(-13 * s, 6 * s), Vector2(26 * s, 4 * s)), P.STRAW_BAND)


func _kid(tex: Texture2D, foot: Vector2, h: float) -> void:
	var w := tex.get_width() * h / tex.get_height()
	draw_texture_rect(tex, Rect2(foot + Vector2(-w / 2.0, -h), Vector2(w, h)), false)
