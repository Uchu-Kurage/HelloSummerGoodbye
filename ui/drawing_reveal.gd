class_name DrawingReveal
extends NatsumiScreen
## なつみの絵を広げる（10日目、初恋ルート・好感度 高）。会話の @game drawing で始まる。ミニゲームではない。
## バスが動き出してから、丸めた絵を広げる。線香花火の明かりに照らされた、ぼくの横顔。
## 空は、あの青い色えんぴつの色（1日目に拾って、2日目に返したもの）。
## 広がる動きは決定キー／タップで早送り。広げ終わったら、タップ（Space）で閉じる。

const UNROLL_TIME := 1.4
const P := preload("res://world/world_palette.gd")
## 絵の具の色。空は 1日目の色えんぴつ（PENCIL_BLUE）
const SKIN := Color("#F0C39A")
const HAIR := Color("#3B302A")
const FIELD := Color("#4E6B48")

var _t := 0.0
var _ready_to_close := false
var _title: Label
var _name: Label


func _build() -> void:
	_title = Label.new()
	_title.text = Strings.DRAWING_TITLE
	_name = Label.new()
	_name.text = Strings.DRAWING_NAME
	_name.theme_type_variation = &"SmallLabel"
	for l in [_title, _name]:
		l.modulate.a = 0.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)


func _process(delta: float) -> void:
	_t += delta * speed
	if _t >= UNROLL_TIME and not _ready_to_close:
		_ready_to_close = true
		speed = 1.0
		UiAnim.fade(_title, 1.0, UiTokens.TIME_PANEL)
		UiAnim.fade(_name, 1.0, UiTokens.TIME_PANEL)
		show_hint(Strings.DRAWING_HINT_TOUCH, Strings.DRAWING_HINT_KEY)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_tap(event):
		return
	get_viewport().set_input_as_handled()
	if _ready_to_close:
		SfxPlayer.play("accept")
		hide_hint()
		finish()
	else:
		speed = UiTokens.SKIP_SPEED


## 広げ終わったか（自動の動作確認から使う）
func is_open() -> bool:
	return _ready_to_close


func _paper_rect() -> Rect2:
	var s := size
	var h := minf(s.y - UiTokens.SCREEN_MARGIN * 2 - 120.0, s.x * 0.5)
	var w := h * 1.3
	return Rect2((s.x - w) / 2.0, (s.y - h) / 2.0 - 20.0, w, h)


func _draw() -> void:
	var s := size
	# バスの車内（ひざの上で広げる）
	draw_rect(Rect2(Vector2.ZERO, s), P.SHOP_DARK)
	var full := _paper_rect()
	var k := clampf(_t / UNROLL_TIME, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	if UiAnim.reduced():
		k = 1.0 if _t > 0.0 else 0.0
	# 左から右へ、丸まった紙が広がる
	var r := Rect2(full.position, Vector2(maxf(full.size.x * k, 24.0), full.size.y))
	draw_rect(r.grow(4), UiTokens.PAPER_DARK)
	draw_rect(r, UiTokens.PAPER)
	draw_set_transform(Vector2.ZERO)
	_painting(full, r)
	# まだ丸まっているところ（巻き）
	if k < 1.0:
		draw_rect(Rect2(r.end.x - 12, r.position.y - 6, 24, r.size.y + 12), UiTokens.PAPER_DARK)
	# 見出しと名前（広げ終わってから、紙の下のほうに）
	_title.position = Vector2(full.position.x + 24, full.end.y - 52)
	_name.position = Vector2(full.end.x - 24 - _name.size.x, full.end.y - 44)


## 絵。visible の範囲（広がったところ）だけを描く
func _painting(full: Rect2, visible_rect: Rect2) -> void:
	var inner := Rect2(full.position + Vector2(20, 20), full.size - Vector2(40, 84))
	var clip := inner.intersection(visible_rect)
	if clip.size.x <= 0.0:
		return
	# 空：あの青。星がすこし
	var sky := Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.72))
	_rect_clip(sky, clip, P.PENCIL_BLUE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 14:
		var p := sky.position + Vector2(rng.randf() * sky.size.x, rng.randf() * sky.size.y * 0.7)
		if clip.has_point(p):
			draw_circle(p, 2.0, Color(P.STAR, 0.9))
	# 夜の田んぼ
	_rect_clip(Rect2(inner.position.x, sky.end.y, inner.size.x, inner.size.y - sky.size.y), clip, FIELD)
	# ぼくの横顔（左を向いて、手もとの花火を見ている）
	var u := inner.size.y / 170.0
	var head := inner.position + Vector2(inner.size.x * 0.4, inner.size.y * 0.62)
	var face := PackedVector2Array([
		head + Vector2(-26, 48) * u, head + Vector2(-30, 20) * u, head + Vector2(-26, -4) * u,
		head + Vector2(-12, -22) * u, head + Vector2(10, -24) * u, head + Vector2(22, -10) * u,
		head + Vector2(26, 2) * u, head + Vector2(32, 8) * u, head + Vector2(26, 12) * u,
		head + Vector2(24, 24) * u, head + Vector2(14, 32) * u, head + Vector2(12, 48) * u])
	if clip.end.x > head.x - 30 * u:
		_poly(_clip_poly(face, clip), SKIN)
		var hair := PackedVector2Array([
			head + Vector2(-30, 14) * u, head + Vector2(-30, -14) * u, head + Vector2(-12, -30) * u,
			head + Vector2(12, -30) * u, head + Vector2(26, -14) * u, head + Vector2(18, -10) * u,
			head + Vector2(0, -12) * u, head + Vector2(-16, -2) * u])
		_poly(_clip_poly(hair, clip), HAIR)
	# 線香花火のあかり
	var ball := inner.position + Vector2(inner.size.x * 0.64, inner.size.y * 0.74)
	if clip.has_point(ball):
		draw_line(ball + Vector2(0, -inner.size.y * 0.3), ball, Color("#C25B8E"), 2.0)
		draw_circle(ball, 30 * u, Color(P.SENKO_GLOW, 0.1))
		draw_circle(ball, 16 * u, Color(P.SENKO_GLOW, 0.16))
		draw_circle(ball, 4 * u, P.SENKO_BALL)
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(ball, ball + Vector2(cos(a), sin(a)) * 14 * u, P.SENKO_SPARK, 1.5)
	# 顔のふちを、花火の色でほんのり
	if clip.end.x > head.x + 20 * u:
		draw_arc(head + Vector2(10, 6) * u, 26 * u, -0.6, 0.9, 10, Color(P.SENKO_SPARK, 0.5), 3.0)


func _rect_clip(r: Rect2, clip: Rect2, c: Color) -> void:
	var x := r.intersection(clip)
	if x.size.x > 0.0 and x.size.y > 0.0:
		draw_rect(x, c)


## 多角形を、広がったところ（clip の右のふち）でけずる
func _clip_poly(pts: PackedVector2Array, clip: Rect2) -> PackedVector2Array:
	var box := PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)])
	var out := Geometry2D.intersect_polygons(pts, box)
	return out[0] if out.size() > 0 else PackedVector2Array()


func _poly(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)
