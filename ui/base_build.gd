class_name BaseBuild
extends Control
## ミニゲーム「秘密基地づくり」（4日目、親友ルート）。会話の @game base_build で始まる。
## すき間（屋根3・壁2）を選び、材料（板・トタン・ブルーシート・すだれ）をはめる。正解も失敗も時間制限もない。
## - キーボード：矢印ですき間を選んで決定 → 材料を左右で選んで決定。Esc で選び直し
## - タッチ：すき間をタップ → 出てきた材料をタップ（「もどる」で選び直し）
## 5か所ぜんぶふさいだら終わる（それまでは、はめ直しもできる）

signal finished

## 5か所ふさいでから、終わるまでの間
const FINISH_DELAY := 0.8
## すき間のボタンの大きさ（屋根は横長、壁は正方形。どちらも 72px 以上）
const GAP_BUTTON := [Vector2(104, 72), Vector2(80, 80)]
## ボタンの中心の高さ（足もとから）。屋根と壁のボタン、壁のボタンと下の材料のパネルが 16px 以上はなれるように
const ROOF_BUTTON_Y := -192.0
const WALL_BUTTON_Y := -100.0
## キーボードで矢印を押したときの、すき間の移り先：[左, 右, 上, 下]
const GAP_NEIGHBORS := [
	[0, 1, 0, 3], [0, 2, 1, 3], [1, 2, 2, 4],
	[3, 4, 0, 3], [3, 4, 2, 4],
]

var hud: Hud
var base: SecretBase
var _gaps: Array[Button] = []
## 材料を選んでいるすき間（-1 ならすき間を選んでいるところ）
var _gap := -1
## キーボードで印のついているすき間
var _kb_gap := 0
var _panel: PanelContainer
var _hint: Label
var _list: MenuList
var _back: Button
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in GameState.BASE_GAPS:
		var b := Button.new()
		b.theme_type_variation = &"GapButton"
		b.custom_minimum_size = GAP_BUTTON[0 if SecretBase.is_roof(i) else 1]
		b.size = b.custom_minimum_size
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_gap_pressed.bind(i))
		UiAnim.add_press_feedback(b)
		var mark := Label.new()
		mark.text = Strings.SELECT_MARK
		mark.theme_type_variation = &"AccentMarkLabel"
		mark.position = Vector2(UiTokens.SPACE_XS, 2)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.name = "Mark"
		b.add_child(mark)
		add_child(b)
		_gaps.append(b)
	_build_panel()
	_refresh()
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_PANEL)
	InputMode.mode_changed.connect(func(_t): _refresh())


## 材料を選ぶ紙のパネル（画面の下、道の帯の上）
func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"PaperPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -UiTokens.SCREEN_MARGIN
	_panel.add_to_group("touch_ui")
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_panel.add_child(h)
	_hint = Label.new()
	_hint.theme_type_variation = &"SmallLabel"
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_hint)
	_list = MenuList.new()
	_list.vertical = false
	h.add_child(_list)
	for m in GameState.base_materials():
		var b: MenuItem = preload("res://ui/components/menu_item.tscn").instantiate()
		b.variation = &"ChoiceItem"
		b.text = m.display_name
		b.custom_minimum_size.x = UiTokens.TOUCH_MIN
		b.pressed.connect(_place.bind(m))
		_list.add_child(b)
		# 材料の見本（小さな色の帯）
		var swatch := Control.new()
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		swatch.offset_top = -12
		swatch.offset_bottom = -6
		swatch.offset_left = UiTokens.SPACE_S
		swatch.offset_right = -UiTokens.SPACE_S
		swatch.draw.connect(func(): SecretBase.draw_material(swatch, m, Rect2(Vector2.ZERO, swatch.size)))
		b.add_child(swatch)
	_back = Button.new()
	_back.text = Strings.BACK
	_back.theme_type_variation = &"TouchButton"
	_back.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 1.25, UiTokens.TOUCH_MIN)
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(_unselect)
	UiAnim.add_press_feedback(_back)
	h.add_child(_back)


func _process(_delta: float) -> void:
	_place_gap_buttons()


## すき間のボタンを、基地の絵のすき間の上に重ねる
func _place_gap_buttons() -> void:
	if base == null or not is_instance_valid(base):
		return
	var xf := base.get_global_transform_with_canvas()
	for i in _gaps.size():
		var b := _gaps[i]
		var c := SecretBase.gap_rect(i).get_center()
		c.y = ROOF_BUTTON_Y if SecretBase.is_roof(i) else WALL_BUTTON_Y
		var center := xf * c
		b.position = center - b.size / 2.0


func _refresh() -> void:
	for i in _gaps.size():
		# 選んだすき間（キーボードでは、いま印のあるすき間も）を色と印で示す
		var selected := i == _gap or (_gap < 0 and InputMode.keyboard and i == _kb_gap)
		var filled := GameState.base_slot(i) != null
		_gaps[i].theme_type_variation = &"GapButtonSelected" if selected else (&"GapButtonFilled" if filled else &"GapButton")
		_gaps[i].get_node("Mark").visible = selected
	var choosing := _gap >= 0
	_hint.text = Strings.BASE_PICK_MATERIAL if choosing else Strings.BASE_PICK_GAP
	_list.visible = choosing
	_back.visible = choosing and InputMode.touch
	if choosing:
		_list.activate()
	else:
		_list.deactivate()


func _on_gap_pressed(i: int) -> void:
	if _done:
		return
	SfxPlayer.play("accept")
	_select_gap(i)


func _select_gap(i: int) -> void:
	_gap = i
	_kb_gap = i
	_refresh()


## すき間の選び直し（Esc／もどる）
func _unselect() -> void:
	if _gap < 0:
		return
	SfxPlayer.play("cancel")
	_gap = -1
	_refresh()



## はめる。その材料の音が鳴り、そのすき間の雨だれが止まる。タケルが一言いう
func place(gap: int, m: BaseMaterial) -> void:
	if _done:
		return
	GameState.set_base_slot(gap, m)
	SfxPlayer.play(m.place_sfx)
	_update_rain_sound()
	if hud:
		hud.say(m.takeru_line)
	_kb_gap = _next_open(gap)
	_gap = -1
	_refresh()
	if GameState.base_slots.size() >= GameState.BASE_GAPS:
		_finish()


func _place(m: BaseMaterial) -> void:
	if _gap >= 0:
		place(_gap, m)


## 次にふさぐすき間（キーボードの印を進める）
func _next_open(from: int) -> int:
	for k in GameState.BASE_GAPS:
		var i := (from + 1 + k) % GameState.BASE_GAPS
		if GameState.base_slot(i) == null:
			return i
	return from


## 屋根3か所がふさがると、雨音が「外の雨」から「屋根をたたく雨」になる（いちばん多い材料の音）
func _update_rain_sound() -> void:
	var count := {}
	for i in SecretBase.ROOF_GAPS:
		var m := GameState.base_slot(i)
		if m == null:
			return
		count[m] = count.get(m, 0) + 1
	var best: BaseMaterial = null
	for m in count:
		if best == null or count[m] > count[best]:
			best = m
	get_tree().call_group("time_of_day", "set_rain_ambient", best.roof_rain_ambient)


func _finish() -> void:
	_done = true
	_list.deactivate()
	await get_tree().create_timer(FINISH_DELAY).timeout
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_PANEL_OUT)
	await tw.finished
	finished.emit()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") and _gap >= 0:
		_unselect()
		get_viewport().set_input_as_handled()
		return
	if _gap >= 0:
		return  # 材料の選択は MenuList（左右と決定）にまかせる
	var dir := -1
	for k in 4:
		if event.is_action_pressed(["ui_left", "ui_right", "ui_up", "ui_down"][k]):
			dir = k
	if dir >= 0:
		_kb_gap = GAP_NEIGHBORS[_kb_gap][dir]
		SfxPlayer.play("cursor")
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_gap_pressed(_kb_gap)
		get_viewport().set_input_as_handled()
