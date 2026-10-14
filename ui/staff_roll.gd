class_name StaffRoll
extends Control
## スタッフロール（汎用）。暗い画面に、文字が下から上へゆっくり流れる。決定キー・タップで早送り。
## 流れきったら次の画面へ：章を遊んでいるあい（急の最後）はタイトルへ、
## 4つ目のエンディングのあとは、章題「あの夏へ」へ（予告なし）。
## 章の最後（急）では、文字の後ろに、序の子どもの夏の思い出（背景の絵）と、破・急の写真の絵（撮らなかったポイントのぶんも）を、
## 重ねるように入れかえて流す。絵は新しく描かず、序の背景と写真の絵を使い回す。

const CHAPTER_TITLE_SCENE := "res://ui/chapter_title.tscn"
const TITLE_SCENE := "res://ui/title.tscn"
## 章の最後に後ろで流す、序の背景（秘密基地・夏祭り・川・線香花火・かくれんぼ・金魚すくい・映画会・絵）
const MEMORY_BACKGROUNDS: Array[String] = [
	"res://ui/minigame_bg/base_build.jpg", "res://ui/minigame_bg/yomise.jpg", "res://ui/minigame_bg/dive.jpg",
	"res://ui/minigame_bg/senko.jpg", "res://ui/minigame_bg/kakurenbo.jpg", "res://ui/minigame_bg/kingyo.jpg",
	"res://ui/minigame_bg/movie.jpg", "res://ui/minigame_bg/sketch.jpg",
]
## 後ろの絵の暗さ（文字が読めるように）
const SLIDE_DIM := 0.45
const SLIDE_DIM_CARD := 0.55
## 1枚の絵が出ている最短の秒数
const SLIDE_MIN_TIME := 1.6

var done := false
var _scroll: Control
var _column: VBoxContainer
var _speed_scale := 1.0
var _running := false
## 章の最後：後ろで流す絵の入れものと、今何枚目か
var slides: Array[Control] = []
var _slide_box: Control
var _slide_index := -1
var _slide_t := 0.0
var _slide_interval := 3.0


func _ready() -> void:
	SfxPlayer.set_ambient("")
	SfxPlayer.play_music("ending")
	var bg := ColorRect.new()
	bg.color = UiTokens.FADE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if GameState.chapter:
		_build_slides()
	_scroll = Control.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.clip_contents = true
	add_child(_scroll)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", UiTokens.STAFF_LINE_GAP)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_column)
	for line in Strings.STAFF_LINES:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if line.begins_with("# "):
			l.text = line.substr(2)
			l.theme_type_variation = &"BigDateLabel"
		else:
			l.text = line
			l.theme_type_variation = &"BigDateSubLabel"
		_column.add_child(l)
	await get_tree().process_frame
	var vs := get_viewport_rect().size
	_column.size = Vector2(vs.x, 0)
	_column.position = Vector2(0, vs.y)
	_running = true
	if not slides.is_empty():
		# 流れている間に、ぜんぶの絵が一度は出るように間を決める
		var roll := (vs.y + _column.size.y) / UiTokens.STAFF_SPEED
		_slide_interval = maxf(SLIDE_MIN_TIME, roll / float(slides.size()))
		_next_slide()


## 章の最後：序の思い出の背景と、写真の絵（ポイント15・破のタケル3・残りのタケル5）を、交ぜて並べる
func _build_slides() -> void:
	_slide_box = Control.new()
	_slide_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slide_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slide_box)
	var bgs: Array[Control] = []
	for path in MEMORY_BACKGROUNDS:
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var r := TextureRect.new()
		r.texture = tex
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bgs.append(r)
	var cards: Array[Control] = []
	for id in GameState.ALL_PHOTO_IDS:
		var p := GameState.photo_data(id)
		if p == null:
			continue
		var c := CenterContainer.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card := PhotoCard.new().setup(p)
		card.pivot_offset = PhotoCard.CARD_SIZE / 2.0
		card.scale = Vector2.ONE * 1.5
		c.add_child(card)
		cards.append(c)
	# 背景のあいだに写真を3枚ずつはさむ
	var bi := 0
	var ci := 0
	while ci < cards.size() or bi < bgs.size():
		if bi < bgs.size():
			slides.append(bgs[bi])
			bi += 1
		for k in 3:
			if ci < cards.size():
				slides.append(cards[ci])
				ci += 1
	for sl in slides:
		sl.modulate.a = 0.0
		_slide_box.add_child(sl)


func _next_slide() -> void:
	_slide_index += 1
	if _slide_index >= slides.size():
		return
	var cur := slides[_slide_index]
	var target := SLIDE_DIM if cur is TextureRect else SLIDE_DIM_CARD
	if UiAnim.reduced():
		cur.modulate.a = target
		if _slide_index > 0:
			slides[_slide_index - 1].modulate.a = 0.0
	else:
		UiAnim.fade(cur, target, UiTokens.TIME_FADE * 2.0)
		if _slide_index > 0:
			UiAnim.fade(slides[_slide_index - 1], 0.0, UiTokens.TIME_FADE * 2.0)


## 動かない（動きを減らす設定のとき）：上へ流さず、全部を一度に見せて、決定で次へ進む
func _process(delta: float) -> void:
	if done or not _running:
		return
	var vs := get_viewport_rect().size
	if not slides.is_empty():
		_slide_t += delta * _speed_scale
		if _slide_t >= _slide_interval:
			_slide_t = 0.0
			_next_slide()
	if UiAnim.reduced():
		_column.position.y = maxf(vs.y * 0.5 - _column.size.y * 0.5, UiTokens.SCREEN_MARGIN)
		return
	_column.position.y -= UiTokens.STAFF_SPEED * _speed_scale * delta
	if _column.position.y + _column.size.y < 0.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not go:
		return
	get_viewport().set_input_as_handled()
	if UiAnim.reduced():
		_finish()
	else:
		# 決定で早送り（流れきるまで）
		_speed_scale = UiTokens.SKIP_SPEED


func _finish() -> void:
	if done:
		return
	done = true
	if GameState.chapter:
		# 章の終わり：章を終えたことを記録して、タイトルへ
		EndingRecord.mark_chapter_seen()
		GameState.reset()
		Transition.change_scene(TITLE_SCENE)
	else:
		Transition.change_scene(CHAPTER_TITLE_SCENE)
