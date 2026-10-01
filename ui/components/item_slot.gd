class_name ItemSlot
extends Button
## 宝箱の枠1つ。拾ったもの：アイコン（仮は色付き四角）＋名前 / 拾っていないもの：空の枠。

const SIZE := Vector2(136, 136)
const ICON := Vector2(48, 48)

var item: ItemData
var collected := false
var selected := false
var content: Control

var _swatch: ColorRect
var _icon: TextureRect
var _name: Label
var _mark: Label


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
	_mark = Label.new()
	_mark.text = Strings.SELECT_MARK
	_mark.theme_type_variation = &"AccentMarkLabel"
	_mark.position = Vector2(UiTokens.SPACE_XS, 2)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mark)
	UiAnim.add_press_feedback(self)
	_refresh()


func setup(p_item: ItemData, p_collected: bool) -> void:
	item = p_item
	collected = p_collected
	if is_node_ready():
		_refresh()


func set_selected(v: bool) -> void:
	selected = v
	_refresh()


func _refresh() -> void:
	var base := "SlotFilled" if collected else "SlotEmpty"
	theme_type_variation = StringName(base + ("Selected" if selected else ""))
	_mark.visible = selected
	content.visible = collected
	if item and collected:
		_swatch.visible = item.icon == null
		_swatch.color = item.placeholder_color
		_icon.visible = item.icon != null
		_icon.texture = item.icon
		_name.text = item.display_name
