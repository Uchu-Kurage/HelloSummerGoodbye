class_name MessagePanel
extends PanelContainer
## 一言パネル：ノートの罫線（PAPER_DARK）の上に文字を書く紙のパネル。
## 左に絵（なければ色の四角）、上に話し手の名前、右下に続きの印。下の段に横並びの選択肢（MenuList）。
## 拾ったときの一言・会話（HUD）と、縁側の場面で使い回す。文字送りは1文字 TIME_CHAR（type_step）。

## 絵がないときの色の四角
var swatch: ColorRect
var icon: TextureRect
var name_label: Label
var text_label: Label
## 続きの印（全文が出たら出す）
var mark: Label
## 会話の選択肢（パネルの下の段。横に並べる）
var choice_list: MenuList
var _type_t := 0.0
## 会話パネルに出す顔（立ち絵の頭のまわりを切り出したもの）。立ち絵ごとに1つ作っておく
static var _faces := {}


func _init() -> void:
	theme_type_variation = &"PaperPanel"
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTokens.SPACE_S)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTokens.SPACE_M)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(h)
	var icon_box := PanelContainer.new()
	icon_box.theme_type_variation = &"PaperInset"
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_box)
	swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(56, 56)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(swatch)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	name_label = Label.new()
	name_label.theme_type_variation = &"SmallLabel"
	v.add_child(name_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text_label.custom_minimum_size.y = UiTokens.FONT_BODY * UiTokens.LINE_HEIGHT_RATIO * 2
	text_label.draw.connect(_draw_ruled_lines)
	v.add_child(text_label)
	mark = Label.new()
	mark.text = Strings.CONTINUE_MARK
	mark.theme_type_variation = &"SmallLabel"
	mark.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(mark)
	choice_list = MenuList.new()
	choice_list.vertical = false
	choice_list.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(choice_list)
	choice_list.hide()


## ノートの罫線。文字の行にそろえて引く
func _draw_ruled_lines() -> void:
	# 実際の行の高さ（文字の高さ＋行間）にそろえ、文字のすぐ下に線を引く
	var font_h := float(text_label.get_line_height())
	var spacing := float(text_label.get_theme_constant("line_spacing"))
	var lh := font_h + spacing
	var n := maxi(1, floori((text_label.size.y + spacing) / lh))
	for i in n:
		var y := roundf(i * lh + font_h + spacing * 0.25)
		text_label.draw_line(Vector2(0, y), Vector2(text_label.size.x, y), UiTokens.PAPER_DARK, 2.0)


## 名前・文・絵を入れる（icon が null なら color の四角）。文は1文字ずつ出す（type_step）
func set_content(title: String, body: String, color: Color, tex: Texture2D) -> void:
	name_label.text = title
	set_body(body)
	swatch.visible = tex == null
	swatch.color = color
	icon.visible = tex != null
	icon.texture = tex


func set_body(body: String) -> void:
	text_label.text = body
	text_label.visible_characters = 0
	mark.modulate.a = 0.0
	_type_t = 0.0


## 文字送りの途中か
func is_typing() -> bool:
	return text_label.visible_characters >= 0


## 全文を出す
func show_all() -> void:
	text_label.visible_characters = -1


## 文字送りを delta 秒すすめる（文字送りの音も鳴らす）。全文が出たら続きの印を出す
func type_step(delta: float) -> void:
	if is_typing():
		_type_t += delta
		var n := int(_type_t / UiTokens.TIME_CHAR)
		var total := text_label.get_total_character_count()
		if n > text_label.visible_characters:
			text_label.visible_characters = mini(n, total)
			SfxPlayer.tick()
		if n >= total:
			text_label.visible_characters = -1
	elif mark.modulate.a == 0.0 and not choice_list.visible:
		UiAnim.fade(mark, 1.0, UiTokens.TIME_SMALL)


## 立ち絵から顔（頭のまわりの正方形）を切り出す。頭の位置は、絵の上のほうの不透明な部分から決める
static func face_of(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _faces.has(tex):
		return _faces[tex]
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	# 4頭身なので、頭はだいたい上から 1/4。少し広めに、首もとまで入れる
	var side := mini(int(img.get_height() * 0.3), w)
	var left := w
	var right := 0
	for y in range(0, side, 4):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.5:
				left = mini(left, x)
				right = maxi(right, x)
	var cx := int((left + right) / 2.0) if right >= left else int(w / 2.0)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(clampi(cx - int(side / 2.0), 0, w - side), 0, side, side)
	_faces[tex] = at
	return at
