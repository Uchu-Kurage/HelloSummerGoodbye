class_name PhotoCard
extends Control
## 写真1枚の見た目（章「あの夏へ」の缶を開ける画面・病室・スタッフロールで使い回す）。
## 絵が入るまでは、色の四角に場所の名前を書いたカードで出す。裏は紙に子どもの字（ひらがな）。
## 真っ黒な写真は、暗い四角だけ。

const CARD_SIZE := Vector2(200, 230)
## 写真の絵の部分（カードの白いふちの内側）
const MARGIN := 12.0
const CAPTION_H := 44.0

var photo: PhotoData
var show_back := false


func setup(p: PhotoData, back := false) -> PhotoCard:
	photo = p
	show_back = back
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	return self


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var frame := Panel.new()
	frame.theme_type_variation = &"PaperPanel"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	if photo == null:
		return
	if show_back:
		var back := Label.new()
		back.text = photo.back_text
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		return
	var pic := ColorRect.new()
	pic.color = photo.placeholder_color
	pic.position = Vector2(MARGIN, MARGIN)
	pic.size = CARD_SIZE - Vector2(MARGIN * 2.0, MARGIN * 2.0 + CAPTION_H)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pic)
	if photo.picture:
		var tex := TextureRect.new()
		tex.texture = photo.picture
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(tex)
	elif not photo.black:
		# 仮のカード：場所の名前を書く
		var cap := Label.new()
		cap.text = photo.place
		cap.theme_type_variation = &"SmallLabel"
		cap.set_anchors_preset(Control.PRESET_FULL_RECT)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(cap)
