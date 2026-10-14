class_name HospitalFinale
extends Control
## 病室（急。8/17・夕方）。缶から出した写真の束を、日付順に1枚ずつなつみに見せていく（決定／タップで次の写真）。
## なつみは写真に合わせて短く反応する。撮らなかったポイントの写真は出ない。
## 束を見終えたあと、最後に、手紙にくるまれていた二人の写真（キー）。どんな撮り方でも、この1枚で必ずクライマックスにたどり着く。
## なつみが空を見上げ、主人公も隣で見上げる。画面がゆっくり白くなって、スタッフロールへ。
## 決定キー／タップで文字送りの早送り → 次の行。動きを減らす設定では、白くなる動きも一息で。

const STAFF_ROLL_SCENE := "res://ui/staff_roll.tscn"
const PANEL_WIDTH := 640.0
## 写真を出す高さ（画面の高さに対する割合：中心）
const CARD_Y := 0.34
const NATSUMI_LOOK := preload("res://data/npcs/chapter_natsumi_old.tres")

enum Phase { IDLE, SHOW, KEY, SKY, FADE, DONE }

var phase := Phase.IDLE
## 見せる写真（束の日付順。二人の写真は入らない）
var bundle: Array[PhotoData] = []
var index := -1
var key_photo: PhotoData
var key_line := -1
## 見せた写真の枚数（スモークテスト用）
var shown_count := 0

var _art: Control
var _panel: MessagePanel
var _card_box: CenterContainer
var _card: PhotoCard
var _white: ColorRect
var _sky_t := 0.0
var _t := 0.0
var _tween: Tween


func _ready() -> void:
	SfxPlayer.set_ambient("")
	bundle = GameState.photo_bundle()
	key_photo = GameState.photo_data(GameState.KEY_PHOTO_ID)
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	add_child(_art)
	_card_box = CenterContainer.new()
	_card_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.anchor_bottom = 0.5
	_card_box.offset_top = UiTokens.SCREEN_MARGIN
	add_child(_card_box)
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	_panel = MessagePanel.new()
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_panel)
	_white = ColorRect.new()
	_white.color = UiTokens.WHITE_OUT
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.modulate.a = 0.0
	add_child(_white)
	gui_input.connect(_on_gui_input)
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_PANEL)
	phase = Phase.SHOW
	_say("ぼく", Strings.HOSPITAL_START_VOICE.trim_prefix("ぼく："))
	index = -1


func _process(delta: float) -> void:
	_t += delta
	if phase == Phase.IDLE or phase == Phase.DONE:
		return
	_panel.type_step(delta)
	_art.queue_redraw()


func _say(who: String, text: String) -> void:
	var col := WorldPalette.PLAYER_HAT
	if who == "なつみ":
		col = NATSUMI_LOOK.placeholder_color
	_panel.set_content("" if who == "ぼく" else who, text, col, null)


func _show_card(p: PhotoData) -> void:
	if _card and is_instance_valid(_card):
		_card.queue_free()
	_card = PhotoCard.new().setup(p)
	_card_box.add_child(_card)
	SfxPlayer.play("pickup")
	if not UiAnim.reduced():
		_card.modulate.a = 0.0
		UiAnim.fade(_card, 1.0, UiTokens.TIME_PANEL)


## 決定／タップ：文字送りの途中なら全文、全文が出ていれば次へ
func advance() -> void:
	if phase == Phase.DONE or phase == Phase.FADE or phase == Phase.IDLE:
		return
	if _panel.is_typing():
		_panel.show_all()
		return
	match phase:
		Phase.SHOW:
			_next_photo()
		Phase.KEY:
			_next_key_line()
		Phase.SKY:
			_start_fade()


func _next_photo() -> void:
	index += 1
	if index >= bundle.size():
		phase = Phase.KEY
		key_line = -1
		_show_card(key_photo)
		_say("ぼく", Strings.HOSPITAL_KEY_VOICE.trim_prefix("ぼく："))
		return
	var p := bundle[index]
	shown_count += 1
	_show_card(p)
	var r: String = Strings.NATSUMI_REACTIONS.get(int(p.reaction), "")
	if p.reaction == PhotoData.Reaction.BLACK:
		_say("", r)
	else:
		_say("なつみ", r)


func _next_key_line() -> void:
	key_line += 1
	var lines := Strings.NATSUMI_KEY_LINES
	if key_line >= lines.size():
		return
	var l := lines[key_line]
	var who := ""
	var text := l
	for n in ["なつみ", "ぼく"]:
		if l.begins_with(n + "："):
			who = n
			text = l.trim_prefix(n + "：")
	_say(who, text)
	if key_line == lines.size() - 1:
		phase = Phase.SKY
		_look_up()


## 窓の外の空が、写真の青空と同じ青になる
func _look_up() -> void:
	if _tween:
		_tween.kill()
	if UiAnim.reduced():
		_sky_t = 1.0
		return
	_tween = create_tween().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_sky_t", 1.0, UiTokens.TIME_FADE * 5.0)


## 最後の行を読み終えたら、ゆっくり白くなる
func _start_fade() -> void:
	phase = Phase.FADE
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_IN)
	_sky_t = 1.0
	_tween.tween_property(_white, "modulate:a", 1.0, UiTokens.TIME_WHITE_OUT * (0.2 if UiAnim.reduced() else 2.5))
	_tween.tween_callback(_to_staff_roll)


func _to_staff_roll() -> void:
	phase = Phase.DONE
	Transition.change_scene(STAFF_ROLL_SCENE)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()


# --- 病室の絵（仮素材：図形だけ） ---------------------------------------------------

func _draw_art() -> void:
	var vs := size
	var s := vs.y / 720.0
	var floor_y := vs.y * 0.74
	# 壁と床
	_art.draw_rect(Rect2(0, 0, vs.x, floor_y), ChapterArt.WALL)
	_art.draw_rect(Rect2(0, floor_y - 70.0 * s, vs.x, 78.0 * s), ChapterArt.WALL_DARK)
	_art.draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), ChapterArt.WOOD)
	_art.draw_line(Vector2(0, floor_y), Vector2(vs.x, floor_y), ChapterArt.WOOD_DARK, 4.0)
	# 窓：夕焼けから、写真の青空と同じ青へ
	var win := Rect2(vs.x * 0.70, vs.y * 0.10, 190.0 * s, 250.0 * s)
	var sky := ChapterArt.SKY_SUNSET.lerp(UiTokens.SKY, _sky_t)
	_art.draw_rect(win.grow(8.0 * s), ChapterArt.WOOD_DARK)
	_art.draw_rect(win, sky)
	_art.draw_line(Vector2(win.position.x + win.size.x / 2.0, win.position.y), Vector2(win.position.x + win.size.x / 2.0, win.end.y), ChapterArt.WOOD_DARK, 4.0)
	# ベッドと、座るなつみ・隣に座る主人公（仮の姿）
	var bed := Rect2(vs.x * 0.12, floor_y - 110.0 * s, vs.x * 0.40, 110.0 * s)
	_art.draw_rect(bed, ChapterArt.CLOTH)
	_art.draw_rect(Rect2(bed.position.x, bed.position.y - 70.0 * s, 18.0 * s, 70.0 * s + bed.size.y), ChapterArt.WOOD_DARK)
	_figure(Vector2(bed.position.x + bed.size.x * 0.5, floor_y - 100.0 * s), s, NATSUMI_LOOK.shirt_color, Color("#E8E4DE"))
	var me := ChapterArt.INK.lerp(Color("#6B6258"), 0.4)
	_figure(Vector2(bed.end.x + 90.0 * s, floor_y - 6.0 * s), s * 1.1, Color("#7C8A8E"), me)


## 座っている人の仮の姿：頭と胴
func _figure(foot: Vector2, s: float, shirt: Color, hair: Color) -> void:
	_art.draw_rect(Rect2(foot.x - 28.0 * s, foot.y - 100.0 * s, 56.0 * s, 100.0 * s), shirt)
	_art.draw_circle(foot + Vector2(0, -122.0 * s), 24.0 * s, Color("#E2B894"))
	_art.draw_arc(foot + Vector2(0, -126.0 * s), 25.0 * s, PI, TAU, 16, hair, 8.0 * s)
