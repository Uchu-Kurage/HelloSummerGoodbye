class_name MinigameBg
## ミニゲームの専用画面の背景（Google Gemini で生成した水彩の絵）。
## 絵は ui/minigame_bg/<ミニゲームの名前>.jpg。画面の縦横比が変わっても、すき間が出ないように切り取って敷く。


## 絵を rect いっぱいに敷く（はみ出す分は切る）。focus は残したいところ（0〜1。0.5 ならまん中）
## modulate で色をかける（夕立の前に暗くする、など）
static func draw_cover(ci: CanvasItem, tex: Texture2D, rect: Rect2, focus := Vector2(0.5, 0.5), modulate := Color.WHITE) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	var k := maxf(rect.size.x / ts.x, rect.size.y / ts.y)
	var src_size := rect.size / k
	var src_pos := (ts - src_size) * focus
	ci.draw_texture_rect_region(tex, rect, Rect2(src_pos, src_size), modulate)
