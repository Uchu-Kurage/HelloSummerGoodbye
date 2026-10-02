class_name Hud
extends CanvasLayer
## ゲーム中の表示：日付の札（常に出す）、拾うときの吹き出し、拾ったときの一言、最初の歩き方の案内。

## 一言パネルの左端（画面の幅に対する割合）
const MESSAGE_LEFT := 0.44
## 会話のときは、話している人を隠さないよう画面の上（空）に出す。左右の端（画面の幅に対する割合）
## 左の日付の札と、右上のタッチ用ボタンのあいだに収まる幅
const TALK_LEFT := 0.2
const TALK_RIGHT := 0.72
## 歩き方の案内を消すまでに歩く距離
const HINT_WALK_DISTANCE := 480.0

## 会話が最後まで終わったとき（run_talk の待ち合わせに使う）
signal talk_finished

## 「名前：せりふ」の名前として扱う長さ（これより後ろの「：」はせりふの一部）
const SPEAKER_MAX := 8
## 選択肢が出てすぐの決定は受けつけない（せりふを送るつもりで押しつづけて、うっかり選ばないように）
const CHOICE_GUARD := 0.3
const MENU_ITEM := preload("res://ui/components/menu_item.tscn")
## 会話の @game で始めるミニゲーム
const MINIGAMES := {
	"base_build": preload("res://ui/base_build.gd"),
}

var player: Player
## 会話の @bury で開く宝箱（main が入れる）
var box: TreasureBox

var _root: Control
var _card: PanelContainer
var _card_month: Label
var _card_day: Label
var _card_title: Label
var _bubble_holder: Control
var _bubble: Button
## 範囲に入っている、話しかけられる／拾えるもの
var _near: Array[Interactable] = []
## 吹き出しを出している相手（いちばん近いもの）
var _target: Interactable
## 会話中のせりふ
var _talk_lines: Array[String] = []
var _talk_index := 0
var _talk_data: NpcData
var _talk_npc: Npc
var _next_show: ItemData
var _choice_list: MenuList
var _choosing := false
var _choice_at := 0
var _burying := false
var _minigame: Control
var _auto_pending: Array[Npc] = []
var _msg: PanelContainer
var _msg_swatch: ColorRect
var _msg_icon: TextureRect
var _msg_name: Label
var _msg_text: Label
var _msg_mark: Label
var _msg_open := false
var _msg_t := 0.0
var _msg_done_t := 0.0
var _hint: Label
var _hint_start_x := NAN
var _hint_tween: Tween


func _ready() -> void:
	layer = 10
	add_to_group("interact_listener")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_card()
	_build_bubble()
	_build_message()
	_build_hint()
	InputMode.mode_changed.connect(func(_t): _refresh_texts())
	_refresh_texts()


# --- 日付の札 ---------------------------------------------------------------

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.theme_type_variation = &"DateCard"
	_card.position = Vector2(UiTokens.SCREEN_MARGIN, UiTokens.SCREEN_MARGIN)
	_card.custom_minimum_size = Vector2(132, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_card.add_child(v)
	var top := PanelContainer.new()
	top.theme_type_variation = &"DateCardTop"
	v.add_child(top)
	# 日めくりのとじ穴
	var holes := Control.new()
	holes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holes.draw.connect(func():
		var r := UiTokens.CARD_HOLE
		for x in [holes.size.x * 0.14, holes.size.x * 0.86]:
			holes.draw_circle(Vector2(x, r + 4), r, UiTokens.INK_SOFT))
	top.add_child(holes)
	_card_month = Label.new()
	_card_month.theme_type_variation = &"DateMonthLabel"
	_card_month.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_card_month)
	var body := PanelContainer.new()
	body.theme_type_variation = &"DateCardBody"
	v.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	body.add_child(bv)
	_card_day = Label.new()
	_card_day.theme_type_variation = &"DateDayLabel"
	_card_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_card_day)
	_card_title = Label.new()
	_card_title.theme_type_variation = &"SmallLabel"
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_card_title)


func set_day(d: DayData) -> void:
	_card_month.text = Strings.DATE_MONTH % d.month
	_card_day.text = Strings.DATE_DAY % d.day
	_card_title.text = GameState.day_title(d)


## 札がめくれるように切り替える
func flip_to_day(d: DayData) -> void:
	_card.pivot_offset = Vector2(_card.size.x / 2.0, 0)
	var half := UiTokens.TIME_CARD_FLIP / 2.0
	# 動きを減らす設定のときはめくらずに、文字を入れかえるだけ（フェード）
	var prop := "modulate:a" if UiAnim.reduced() else "scale:y"
	var tw := create_tween().set_trans(UiTokens.TRANS)
	tw.tween_property(_card, prop, 0.0, half).set_ease(Tween.EASE_IN)
	tw.tween_callback(set_day.bind(d))
	tw.tween_property(_card, prop, 1.0, half).set_ease(Tween.EASE_OUT)


# --- 拾う／はなす吹き出し ------------------------------------------------------

func _build_bubble() -> void:
	_bubble_holder = Control.new()
	_bubble_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bubble_holder)
	_bubble = Button.new()
	_bubble.theme_type_variation = &"Bubble"
	_bubble.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN, UiTokens.TOUCH_MIN)
	_bubble.focus_mode = Control.FOCUS_NONE
	_bubble.add_to_group("touch_ui")
	_bubble.pressed.connect(_interact_current)
	UiAnim.add_press_feedback(_bubble)
	_bubble_holder.add_child(_bubble)
	_bubble.hide()


func on_interactable_entered(it: Interactable) -> void:
	if not _near.has(it):
		_near.append(it)
	_update_target()


func on_interactable_exited(it: Interactable) -> void:
	_near.erase(it)
	_update_target()


func current_target() -> Interactable:
	return _target


## 範囲に入っているもののうち、いちばん近いものに吹き出しを出す
func _update_target() -> void:
	var best: Interactable = null
	var best_d := INF
	# 一言パネルを出している間（会話中も）は吹き出しを出さない
	for it in ([] if _msg_open else _near.duplicate()):
		if not is_instance_valid(it) or not it.can_interact():
			_near.erase(it)
			continue
		var d := absf(it.global_position.x - player.global_position.x) if player else 0.0
		if d < best_d:
			best_d = d
			best = it
	if best == _target:
		return
	var had := _target != null
	_target = best
	if _target == null:
		if _bubble.visible:
			UiAnim.float_out(_bubble)
		return
	_refresh_texts()
	_bubble.reset_size()
	_place_bubble()
	if not had or not _bubble.visible:
		UiAnim.float_in(_bubble, Vector2(-_bubble.size.x / 2.0, -_bubble.size.y))
	else:
		_bubble.position = Vector2(-_bubble.size.x / 2.0, -_bubble.size.y)


func _place_bubble() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var pos := _target.bubble_screen_position()
	var vs := _root.get_viewport_rect().size
	var m := UiTokens.SCREEN_MARGIN + _bubble.size.x / 2.0
	pos.x = clampf(pos.x, m, vs.x - m)
	pos.y = maxf(pos.y, UiTokens.SCREEN_MARGIN + _bubble.size.y)
	_bubble_holder.position = pos


func _interact_current() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.can_interact():
		return
	if _msg_open or (player and (player.talking or (player.locked and not _target.works_while_locked()))):
		return
	_target.interact(self)


# --- 一言パネル（拾ったときの一言・会話） -------------------------------------------

func _build_message() -> void:
	_msg = PanelContainer.new()
	_msg.theme_type_variation = &"PaperPanel"
	_place_message(false)
	_msg.mouse_filter = Control.MOUSE_FILTER_STOP
	_msg.add_to_group("touch_ui")
	_msg.gui_input.connect(_on_msg_gui_input)
	_root.add_child(_msg)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTokens.SPACE_S)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg.add_child(outer)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTokens.SPACE_M)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(h)
	var icon_box := PanelContainer.new()
	icon_box.theme_type_variation = &"PaperInset"
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_box)
	_msg_swatch = ColorRect.new()
	_msg_swatch.custom_minimum_size = Vector2(56, 56)
	_msg_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_msg_swatch)
	_msg_icon = TextureRect.new()
	_msg_icon.custom_minimum_size = Vector2(56, 56)
	_msg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_msg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(_msg_icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_msg_name = Label.new()
	_msg_name.theme_type_variation = &"SmallLabel"
	v.add_child(_msg_name)
	_msg_text = Label.new()
	_msg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_msg_text.custom_minimum_size.y = UiTokens.FONT_BODY * UiTokens.LINE_HEIGHT_RATIO * 2
	_msg_text.draw.connect(_draw_ruled_lines)
	v.add_child(_msg_text)
	_msg_mark = Label.new()
	_msg_mark.text = Strings.CONTINUE_MARK
	_msg_mark.theme_type_variation = &"SmallLabel"
	_msg_mark.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(_msg_mark)
	# 会話の選択肢（パネルの下の段。横に並べる）
	_choice_list = MenuList.new()
	_choice_list.vertical = false
	_choice_list.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(_choice_list)
	_choice_list.hide()
	_msg.hide()


## ノートの罫線。文字の行にそろえて引く
func _draw_ruled_lines() -> void:
	# 実際の行の高さ（文字の高さ＋行間）にそろえ、文字のすぐ下に線を引く
	var font_h := float(_msg_text.get_line_height())
	var spacing := float(_msg_text.get_theme_constant("line_spacing"))
	var lh := font_h + spacing
	var n := maxi(1, floori((_msg_text.size.y + spacing) / lh))
	for i in n:
		var y := roundf(i * lh + font_h + spacing * 0.25)
		_msg_text.draw_line(Vector2(0, y), Vector2(_msg_text.size.x, y), UiTokens.PAPER_DARK, 2.0)


## アイテムを拾ったときの一言。読む文があるもの（置き手紙など）は、先にそれを読ませる
func show_item_message(item: ItemData) -> void:
	if item.read_text != "":
		var reader := NpcData.new()
		reader.id = StringName("read_" + item.id)
		reader.display_name = item.display_name
		reader.placeholder_color = item.placeholder_color
		var lines: Array[String] = [item.read_text]
		start_talk(reader, lines)
		await talk_finished
	_talk_data = null
	_open_message(Strings.PICKED_FORMAT % item.display_name, item.text(), item.placeholder_color, item.icon)


## NPC との会話を始める。せりふを1つずつ送り、最後まで読むと閉じる。会話の間は立ち止まる。
## せりふの書き方（話す人・選択肢・アイテムのやりとり）は NpcData を参照
func start_talk(data: NpcData, lines: Array[String], npc: Npc = null) -> void:
	if lines.is_empty():
		return
	_talk_data = data
	_talk_npc = npc
	_talk_lines = lines
	_talk_index = 0
	_next_show = null
	if player:
		player.talking = true
	SfxPlayer.play("accept")
	_step()


## 会話をして、終わるまで待つ（バスの場面など、シーンの演出から使う）
func run_talk(data: NpcData, lines: Array[String]) -> void:
	if is_talking():
		await talk_finished
	if _msg_open:
		close_message()
	start_talk(data, lines)
	if is_talking():
		await talk_finished


func is_talking() -> bool:
	return _talk_data != null


func is_choosing() -> bool:
	return _choosing


## 次のせりふまで進める（目印・条件・アイテムのやりとりなどの指示はその場で行う）
func _step() -> void:
	while _talk_index < _talk_lines.size():
		var e := _talk_lines[_talk_index].strip_edges()
		_talk_index += 1
		if e == "" or e.begins_with("#"):
			continue
		if e.begins_with("@"):
			var r := _run_command(e)
			if r == _Step.END:
				break
			if r == _Step.WAIT:
				return
			continue
		_show_line(e)
		return
	close_message()


enum _Step { NEXT, WAIT, END }


func _run_command(e: String) -> _Step:
	var parts := e.substr(1).split(" ", false, 2)
	var cmd := parts[0]
	var a := parts[1] if parts.size() > 1 else ""
	var b := parts[2] if parts.size() > 2 else ""
	match cmd:
		"end":
			return _Step.END
		"goto":
			_jump(a)
		"if_has":
			if GameState.holds(StringName(a)):
				_jump(b)
		"if_flag":
			if GameState.has_flag(StringName(a)):
				_jump(b)
		"flag":
			GameState.set_flag(StringName(a))
		"choice":
			_show_choices(e.substr(e.find(" ") + 1))
			return _Step.WAIT
		"give":
			var it := GameState.find_item(StringName(a))
			if it and not GameState.is_collected(it.id):
				GameState.collect(it, true)
				SfxPlayer.play("pickup")
				_open_message(Strings.RECEIVED_FORMAT % it.display_name, it.text(), it.placeholder_color, it.icon)
				return _Step.WAIT
		"take":
			var it := GameState.find_item(StringName(a))
			if it:
				GameState.give_away(it, b)
		"show":
			_next_show = GameState.find_item(StringName(a))
		"bury":
			_bury()
			return _Step.WAIT
		"game":
			_run_minigame(a)
			return _Step.WAIT
		"leave":
			if _talk_npc and is_instance_valid(_talk_npc):
				_talk_npc.leave()
		"event":
			var day := _talk_day()
			if day:
				day.on_talk_event(a)
		_:
			push_warning("せりふの指示がわからない: " + e)
	return _Step.NEXT


func _jump(label: String) -> void:
	var at := _talk_lines.find("#" + label)
	if at < 0:
		push_warning("せりふの目印がない: " + label)
		_talk_index = _talk_lines.size()
	else:
		_talk_index = at + 1


## 話している人のいる日のシーン
func _talk_day() -> DayBase:
	var n: Node = _talk_npc
	while n and not n is DayBase:
		n = n.get_parent()
	return n as DayBase


## せりふを1つ出す。「ぼく：……」のように「：」の前があれば、その人のせりふにする
func _show_line(e: String) -> void:
	var speaker := _talk_data.display_name
	var color := _talk_data.placeholder_color
	var icon: Texture2D = null
	var colon := e.find("：")
	if colon > 0 and colon <= SPEAKER_MAX:
		speaker = e.substr(0, colon)
		e = e.substr(colon + 1)
		if speaker == Strings.ME:
			color = WorldPalette.PLAYER_HAT
	if _next_show:
		color = _next_show.placeholder_color
		icon = _next_show.icon
		_next_show = null
	_open_message(speaker, e, color, icon)


## 「ことば:目印 | ことば:目印」の選択肢を出す。目印がなければ、そのまま次へ進む
func _show_choices(spec: String) -> void:
	_choosing = true
	_msg_mark.modulate.a = 0.0
	for c in _choice_list.get_children():
		_choice_list.remove_child(c)
		c.queue_free()
	for opt in spec.split("|", false):
		var o := opt.strip_edges()
		var label := ""
		var colon := o.rfind(":")
		if colon >= 0:
			label = o.substr(colon + 1).strip_edges()
			o = o.substr(0, colon).strip_edges()
		var b: MenuItem = MENU_ITEM.instantiate()
		b.variation = &"ChoiceItem"
		b.text = o
		b.pressed.connect(_on_choice.bind(label))
		_choice_list.add_child(b)
	# 文字送りが終わってから出す
	_msg_text.visible_characters = -1
	_choice_list.modulate.a = 0.0
	_choice_at = Time.get_ticks_msec()
	UiAnim.fade(_choice_list, 1.0, UiTokens.TIME_SMALL)
	_choice_list.activate()


func _on_choice(label: String) -> void:
	if not _choosing or Time.get_ticks_msec() - _choice_at < CHOICE_GUARD * 1000.0:
		return
	_choosing = false
	_choice_list.deactivate()
	_choice_list.hide()
	if label != "":
		_jump(label)
	_step()


## 選択肢を選ぶ（自動の動作確認から使う）
func choose(index: int) -> void:
	var items := _choice_list.items()
	if _choosing and index >= 0 and index < items.size():
		(items[index] as BaseButton).pressed.emit()


## 宝箱から1つ選んで手ばなす（タイムカプセルに入れる）。何も持っていなければ、そのまま次へ
func _bury() -> void:
	var held := GameState.all_items().filter(func(it: ItemData): return GameState.holds(it.id))
	if held.is_empty() or box == null:
		_step()
		return
	_burying = true
	var picked: ItemData = await box.pick(Strings.BURY_TITLE, Strings.BURY_HINT)
	_burying = false
	if picked == null:
		# もどったときは、ひとつ前のせりふから。もう一度送ると宝箱が開く
		_talk_index -= 1
		var prev := _talk_index - 1
		while prev >= 0 and (_talk_lines[prev].begins_with("@") or _talk_lines[prev].begins_with("#")):
			prev -= 1
		if prev >= 0:
			_show_line(_talk_lines[prev])
		return
	GameState.give_away(picked, Strings.BURIED_NOTE)
	_open_message(Strings.PUT_IN_FORMAT % picked.display_name, picked.text(), picked.placeholder_color, picked.icon)


## ミニゲームをして、終わったら会話の続きへ。会話のパネルは上に出したまま（タケルの一言を出す）
func _run_minigame(game_name: String) -> void:
	if not MINIGAMES.has(game_name):
		push_warning("ミニゲームがない: " + game_name)
		_step()
		return
	var g: Control = MINIGAMES[game_name].new()
	g.set("hud", self)
	g.set("base", _nearest_in_group("secret_base"))
	_minigame = g
	_msg_mark.modulate.a = 0.0
	_root.add_child(g)
	await g.finished
	g.queue_free()
	_minigame = null
	_step()


func is_in_minigame() -> bool:
	return _minigame != null


func minigame() -> Control:
	return _minigame


## ミニゲームなどから、いま話している人のせりふを1つ出す
func say(text: String) -> void:
	if is_talking() and text != "":
		_show_line(text)


func _nearest_in_group(group: String) -> Node2D:
	var best: Node2D = null
	for n in get_tree().get_nodes_in_group(group):
		if player == null or best == null or absf(n.global_position.x - player.global_position.x) < absf(best.global_position.x - player.global_position.x):
			best = n
	return best


## 一言パネルの位置。拾ったときは右下（左寄りのプレイヤーを隠さない）、
## 会話のときは画面の上（話している人を隠さない）
func _place_message(talk: bool) -> void:
	if talk:
		_msg.anchor_left = TALK_LEFT
		_msg.anchor_right = TALK_RIGHT
		_msg.anchor_top = 0.0
		_msg.anchor_bottom = 0.0
		_msg.offset_top = UiTokens.SCREEN_MARGIN
		_msg.offset_bottom = UiTokens.SCREEN_MARGIN + 150
		_msg.offset_right = 0
		_msg.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_msg.anchor_left = MESSAGE_LEFT
		_msg.anchor_right = 1.0
		_msg.anchor_top = 1.0
		_msg.anchor_bottom = 1.0
		_msg.offset_top = -UiTokens.SCREEN_MARGIN - 150
		_msg.offset_bottom = -UiTokens.SCREEN_MARGIN
		_msg.offset_right = -UiTokens.SCREEN_MARGIN
		_msg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_msg.offset_left = 0


func _open_message(title: String, body: String, swatch: Color, icon: Texture2D) -> void:
	var was_open := _msg_open
	if not was_open:
		_place_message(is_talking())
	_msg_name.text = title
	_set_body(body)
	_msg_swatch.visible = icon == null
	_msg_swatch.color = swatch
	_msg_icon.visible = icon != null
	_msg_icon.texture = icon
	_msg_open = true
	if not was_open:
		UiAnim.panel_in(_msg)


func _set_body(body: String) -> void:
	_msg_text.text = body
	_msg_text.visible_characters = 0
	_msg_mark.modulate.a = 0.0
	_msg_t = 0.0
	_msg_done_t = 0.0


func is_message_open() -> bool:
	return _msg_open


## 1回目：全文表示 → 2回目：次のせりふ（なければ閉じる）
func advance_message() -> void:
	if not _msg_open or _burying or _minigame:
		return
	if _msg_text.visible_characters >= 0:
		_msg_text.visible_characters = -1
		SfxPlayer.play("accept")
	elif _choosing:
		# 選択肢はボタンで選ぶ。キーボードなら最初の項目へ
		if InputMode.keyboard:
			_choice_list.focus_first()
	elif is_talking():
		SfxPlayer.play("cursor")
		_step()
	else:
		close_message()


func close_message() -> void:
	if not _msg_open:
		return
	_msg_open = false
	var was_talking := is_talking()
	if was_talking:
		# 話し終えたらフラグを立てる（エンディングの分岐、その日の段取りなど）
		for f in _talk_data.set_flags:
			GameState.set_flag(f)
		_talk_data = null
		_talk_npc = null
		_talk_lines = []
		_choosing = false
		_choice_list.deactivate()
		_choice_list.hide()
		if player:
			player.talking = false
	SfxPlayer.play("cancel")
	UiAnim.panel_out(_msg)
	_update_target()
	if was_talking:
		talk_finished.emit()


func _on_msg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_message()
		_msg.accept_event()


func _update_message(delta: float) -> void:
	if not _msg_open:
		return
	if _msg_text.visible_characters >= 0:
		_msg_t += delta
		var n := int(_msg_t / UiTokens.TIME_CHAR)
		var total := _msg_text.get_total_character_count()
		if n > _msg_text.visible_characters:
			_msg_text.visible_characters = mini(n, total)
			SfxPlayer.tick()
		if n >= total:
			_msg_text.visible_characters = -1
	if _msg_text.visible_characters < 0 and not _choosing and not _minigame:
		if _msg_mark.modulate.a == 0.0:
			UiAnim.fade(_msg_mark, 1.0, UiTokens.TIME_SMALL)
		_msg_done_t += delta
		# 会話は読み終えるまで待つ（自動で閉じるのは拾ったときの一言だけ）
		if not is_talking() and _msg_done_t >= UiTokens.TIME_MESSAGE_AUTO_CLOSE:
			close_message()


# --- 向こうから声をかけてくる人 -----------------------------------------------------

func request_auto_talk(npc: Npc) -> void:
	if not _auto_pending.has(npc):
		_auto_pending.append(npc)


## 手があいたら（一言パネルを閉じていて、立ち止まっていなければ）話しはじめる
func _update_auto_talk() -> void:
	if _auto_pending.is_empty() or _msg_open or player == null or player.locked or player.talking:
		return
	if get_tree().paused or Transition.is_busy():
		return
	var npc: Npc = _auto_pending.pop_front()
	if is_instance_valid(npc) and npc.wants_auto_talk() and _near.has(npc):
		npc.interact(self)


# --- 最初の日の歩き方の案内 ------------------------------------------------------

func _build_hint() -> void:
	_hint = Label.new()
	# 道の上に出るので INK_SOFT ではなく本文の色（コントラスト確保）
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -UiTokens.SCREEN_MARGIN - 48
	_hint.offset_bottom = -UiTokens.SCREEN_MARGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	_root.add_child(_hint)
	_hint.hide()


func show_walk_hint() -> void:
	_hint_start_x = player.global_position.x if player else 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(UiTokens.TIME_FADE * 2)
	_hint_tween.tween_callback(func(): UiAnim.fade(_hint, 1.0, UiTokens.TIME_FADE))


func _update_hint() -> void:
	if is_nan(_hint_start_x) or player == null:
		return
	if player.global_position.x - _hint_start_x > HINT_WALK_DISTANCE:
		_hint_start_x = NAN
		if _hint_tween:
			_hint_tween.kill()
		UiAnim.fade(_hint, 0.0, UiTokens.TIME_FADE)


func _refresh_texts() -> void:
	if _target and is_instance_valid(_target):
		_bubble.text = _target.bubble_text(InputMode.touch)
	_hint.text = Strings.WALK_HINT_TOUCH if InputMode.touch else Strings.WALK_HINT_KEY


# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_target()
	_place_bubble()
	_update_message(delta)
	_update_auto_talk()
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _minigame:
		return
	if _choosing and event.is_action_pressed("interact"):
		# E でも、選んでいる選択肢を決める
		var f := get_viewport().gui_get_focus_owner()
		if f is BaseButton and _choice_list.is_ancestor_of(f):
			(f as BaseButton).pressed.emit()
		else:
			_choice_list.focus_first()
		get_viewport().set_input_as_handled()
	elif _msg_open and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		advance_message()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and _target:
		_interact_current()
		get_viewport().set_input_as_handled()
