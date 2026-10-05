class_name DrawingReveal
extends NatsumiScreen
## なつみの絵を広げる（10日目、初恋ルート・好感度 高）。会話の @game drawing で始まる。ミニゲームではない。
## バスが動き出してから、丸めた絵を広げる。線香花火の明かりに照らされた、ぼくの横顔。
## 空は、あの青い色えんぴつの色（1日目に拾って、2日目に返したもの）。
## 広がる動きは決定キー／タップで早送り。広げ終わったら、タップ（Space）で閉じる。

const UNROLL_TIME := 1.4
const P := preload("res://world/world_palette.gd")
## なつみの絵。空は、1日目に拾って2日目に返した、あの青い色えんぴつの色
const ART: Texture2D = preload("res://ui/minigame_bg/drawing.jpg")

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
	# 絵の縦横比に、下の題名の欄（64px）とふちを足した紙
	var w := minf((h - 84.0) * ART.get_width() / ART.get_height() + 40.0, s.x - UiTokens.SCREEN_MARGIN * 2)
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


## 絵（Gemini で作った、色えんぴつの絵）。広がったところ（visible_rect）だけを描く
func _painting(full: Rect2, visible_rect: Rect2) -> void:
	var inner := Rect2(full.position + Vector2(20, 20), full.size - Vector2(40, 84))
	var clip := inner.intersection(visible_rect)
	if clip.size.x <= 0.0:
		return
	# 絵を inner いっぱいに（はみ出す分は切って）敷き、広がった幅のぶんだけ見せる
	var ts := ART.get_size()
	var k := maxf(inner.size.x / ts.x, inner.size.y / ts.y)
	var src_size := inner.size / k
	var src_pos := (ts - src_size) * 0.5
	var u := (clip.position.x - inner.position.x) / inner.size.x
	var v := clip.size.x / inner.size.x
	draw_texture_rect_region(ART, clip, Rect2(src_pos + Vector2(src_size.x * u, 0), Vector2(src_size.x * v, src_size.y)))
