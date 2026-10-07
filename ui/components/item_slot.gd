class_name ItemSlot
extends Button
## 宝箱の枠1つ。拾ったもの：アイコン（仮は色付き四角）＋名前 / 拾っていないもの：空の枠。
## 拾い逃したもの（missed）：PAPER_DARK の地に、絵の輪郭だけを MISSED_LINE で薄く描く（絵がなければ点線の四角）

const SIZE := Vector2(136, 136)
const ICON := Vector2(48, 48)
## 影の絵の大きさ（名前を出さないぶん、少し大きく）
const GHOST := Vector2(64, 64)
const OUTLINE := preload("res://ui/shaders/silhouette_outline.gdshader")
## 影の輪郭の線の太さ（画面の px）と、点線のきざみ
const GHOST_LINE := 2.0
const GHOST_DASH := 6.0

var item: ItemData
## 手もとにある（拾った・もらった）
var collected := false
## 手ばなしたときのひとこと（「タケルにあげた」「うめた」）。空なら手ばなしていない
var note := ""
var selected := false
## 拾い逃した（その日を越えたのに拾っていない）。影で出す
var missed := false
var content: Control

var _swatch: ColorRect
var _icon: TextureRect
var _name: Label
var _mark: Label
var _note: Label
var _ghost: Control
var _ghost_mat: ShaderMaterial


func _ready() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	content = VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_top = UiTokens.SPACE_S
	content.offset_left = UiTokens.SPACE_XS
	content.offset_right = -UiTokens.SPACE_XS
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_center)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = ICON
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(_swatch)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(_icon)
	_name = Label.new()
	_name.theme_type_variation = &"SmallLabel"
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_name.add_theme_constant_override("line_spacing", 2)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_name)
	_note = Label.new()
	_note.theme_type_variation = &"OnTinSmallLabel"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_note.add_theme_constant_override("line_spacing", 2)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_note)
	# 拾い逃したアイテムの影（輪郭だけ）
	_ghost = Control.new()
	_ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.draw.connect(_draw_ghost)
	add_child(_ghost)
	_mark = Label.new()
	_mark.text = Strings.SELECT_MARK
	_mark.theme_type_variation = &"AccentMarkLabel"
	_mark.position = Vector2(UiTokens.SPACE_XS, 2)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mark)
	UiAnim.add_press_feedback(self)
	_refresh()


func setup(p_item: ItemData, p_collected: bool, p_note := "", p_missed := false) -> void:
	item = p_item
	collected = p_collected
	note = p_note
	# 手ばなしたものの表示（あげた・うめた）を優先する
	missed = p_missed and not p_collected and p_note == ""
	if is_node_ready():
		_refresh()


func set_selected(v: bool) -> void:
	selected = v
	_refresh()


## 枠の中に何かを出すか（手もとにあるもの、または手ばなしたひとこと）
func shows_content() -> bool:
	return collected or note != ""


func _refresh() -> void:
	var base := "SlotFilled" if collected else ("SlotMissed" if missed else "SlotEmpty")
	theme_type_variation = StringName(base + ("Selected" if selected else ""))
	_mark.visible = selected
	content.visible = shows_content()
	_note.visible = not collected and note != ""
	_ghost.visible = missed
	_ghost.queue_redraw()
	if item and collected:
		_swatch.visible = item.icon == null
		_swatch.color = item.placeholder_color
		_icon.visible = item.icon != null
		_icon.texture = item.icon
		_name.theme_type_variation = &"SmallLabel"
		_name.text = item.display_name
	elif item and note != "":
		# もう手もとにないので絵は出さず、名前とひとことだけ（缶のくぼみの上なので濃い文字）
		_swatch.visible = false
		_icon.visible = false
		_name.theme_type_variation = &"OnTinSmallLabel"
		_name.text = item.display_name
		# 「タケルに あげた」は空白のところで行を分ける（枠がせまいので、ことばの途中で折り返さない）
		_note.text = note.replace(" ", "\n")


## 影：絵の輪郭だけを薄い線で描く。絵がないもの（仮素材）は点線の四角
func _draw_ghost() -> void:
	if not missed or item == null:
		return
	var r := Rect2((_ghost.size - GHOST) / 2.0, GHOST)
	if item.icon:
		var tex := item.icon
		var k := minf(GHOST.x / tex.get_width(), GHOST.y / tex.get_height())
		var sz := tex.get_size() * k
		if _ghost_mat == null:
			_ghost_mat = ShaderMaterial.new()
			_ghost_mat.shader = OUTLINE
			_ghost.material = _ghost_mat
		_ghost_mat.set_shader_parameter("line_color", UiTokens.MISSED_LINE)
		# 線の太さを、描く大きさに合わせて絵の画素に直す
		_ghost_mat.set_shader_parameter("width", GHOST_LINE / k)
		_ghost.draw_texture_rect(tex, Rect2(r.get_center() - sz / 2.0, sz), false)
	else:
		_ghost.material = null
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			_ghost.draw_dashed_line(pts[i], pts[i + 1], UiTokens.MISSED_LINE, GHOST_LINE, GHOST_DASH)
