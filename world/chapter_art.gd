class_name ChapterArt
extends RefCounted
## 章「あの夏へ」の仮素材の絵（図形だけ）。病室・家の中・今の村・青年期の回想の小物。足もとが原点（上が -y）。
## 絵が入るまでのつなぎ。ExamineSpot と ChapterProp が、同じ描き方を使う。

enum Kind {
	BED,              ## 病室のベッド
	APPLE_TABLE,      ## りんごを置いた台
	WINDOW_SUNSET,    ## 夕焼けの窓
	ROOM_DOOR,        ## 病室の入口
	CORRIDOR_LAMP,    ## 廊下の灯り
	CLOSET,           ## 押し入れ
	BOOKSHELF,        ## 本棚
	TANSU,            ## 古いたんす（破の茶の間のたんすと同じ見た目）
	SHELTER_NEW,      ## 今のバス停の新しい待合所
	HOUSES_ROW,       ## 今の田んぼ道の住宅地（屋根ばかり）
	FENCE_SIGN,       ## 造成地のフェンスと「立入禁止」
	KOMINKAN_NEW,     ## 建て替えた公民館
	BOARD_BILL,       ## 体操教室の貼り紙の掲示板
	BENCH,            ## 青年期のバス停のベンチ
	FRAME,            ## 展覧会の絵（額）
	FRAME_KID,        ## 子どものころの宿題の絵（額。題はひらがな）
	DIG_SPOT,         ## 掘るところ（土のしるし）
	SHRINE_STEPS,     ## 神社の石段
	FIGURES_GRANDPARENTS, ## 重なる：バス停で待つ祖父母
	FIGURE_CHILD_PAINTING, ## 重なる：あぜで絵を描く子どものなつみ
	BASE_OLD,         ## 重なる：板とトタンの秘密基地
	LOOK_SKY,         ## 青年期：なつみが指さした空（見上げるところ）
}

const WALL := Color("#E6E0D2")
const WALL_DARK := Color("#CFC7B4")
const WOOD := Color("#8E6A4A")
const WOOD_DARK := Color("#6F513A")
const CLOTH := Color("#F1EEE6")
const SKY_SUNSET := Color("#F0A36B")
const ROOF := Color("#7E7A78")
const CONCRETE := Color("#B9B6AE")
const PAPER := Color("#F6EEDC")
const INK := Color("#3B3226")
const WARN := Color("#C9A23A")


static func draw(ci: CanvasItem, kind: Kind, width := 160.0) -> void:
	match kind:
		Kind.BED: _bed(ci)
		Kind.APPLE_TABLE: _apple_table(ci)
		Kind.WINDOW_SUNSET: _window(ci)
		Kind.ROOM_DOOR: _door(ci)
		Kind.CORRIDOR_LAMP: _lamp(ci)
		Kind.CLOSET: _closet(ci)
		Kind.BOOKSHELF: _bookshelf(ci)
		Kind.TANSU: _tansu(ci)
		Kind.SHELTER_NEW: _shelter(ci)
		Kind.HOUSES_ROW: _houses(ci, width)
		Kind.FENCE_SIGN: _fence(ci, width)
		Kind.KOMINKAN_NEW: _kominkan(ci)
		Kind.BOARD_BILL: _board(ci)
		Kind.BENCH: _bench(ci)
		Kind.FRAME: _frame(ci, false)
		Kind.FRAME_KID: _frame(ci, true)
		Kind.DIG_SPOT: _dig(ci)
		Kind.SHRINE_STEPS: _steps(ci, width)
		Kind.FIGURES_GRANDPARENTS: _figures(ci)
		Kind.FIGURE_CHILD_PAINTING: _child_painting(ci)
		Kind.BASE_OLD: _base_old(ci)
		Kind.LOOK_SKY: _look_sky(ci)


static func _bed(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-130, -70, 260, 16), WOOD_DARK)
	ci.draw_rect(Rect2(-130, -54, 14, 54), WOOD_DARK)
	ci.draw_rect(Rect2(116, -54, 14, 54), WOOD_DARK)
	ci.draw_rect(Rect2(-124, -92, 248, 26), CLOTH)
	ci.draw_rect(Rect2(-124, -108, 70, 20), Color("#FFFFFF"))


static func _apple_table(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-60, -74, 120, 10), WOOD)
	ci.draw_rect(Rect2(-52, -64, 8, 64), WOOD_DARK)
	ci.draw_rect(Rect2(44, -64, 8, 64), WOOD_DARK)
	ci.draw_circle(Vector2(-14, -88), 15, Color("#C8473A"))
	ci.draw_circle(Vector2(18, -86), 13, Color("#D96A4E"))
	ci.draw_rect(Rect2(-6, -78, 36, 6), Color("#EDE6D6"))


static func _window(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-90, -270, 180, 170), WOOD_DARK)
	ci.draw_rect(Rect2(-80, -260, 160, 150), SKY_SUNSET)
	ci.draw_rect(Rect2(-80, -200, 160, 90), Color("#E58C5A"))
	ci.draw_rect(Rect2(-3, -260, 6, 150), WOOD_DARK)
	ci.draw_rect(Rect2(-80, -188, 160, 6), WOOD_DARK)


static func _door(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-60, -250, 120, 250), WOOD_DARK)
	ci.draw_rect(Rect2(-52, -242, 104, 242), Color("#B9A98C"))
	ci.draw_circle(Vector2(38, -120), 6, WARN)


static func _lamp(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-30, -330, 60, 12), WOOD_DARK)
	ci.draw_rect(Rect2(-24, -318, 48, 8), Color("#FFF4C9"))


static func _closet(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-130, -250, 260, 250), WOOD)
	ci.draw_rect(Rect2(-124, -244, 122, 238), Color("#D9CCB0"))
	ci.draw_rect(Rect2(2, -244, 122, 238), Color("#D9CCB0"))
	ci.draw_rect(Rect2(-12, -130, 6, 40), WOOD_DARK)
	ci.draw_rect(Rect2(6, -130, 6, 40), WOOD_DARK)


static func _bookshelf(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-100, -260, 200, 260), WOOD)
	for r in 4:
		var y := -250.0 + r * 62.0
		ci.draw_rect(Rect2(-92, y + 52, 184, 6), WOOD_DARK)
		var x := -88.0
		for b in 9:
			var h := 36.0 + float((b * 7 + r * 3) % 5) * 3.0
			ci.draw_rect(Rect2(x, y + 52 - h, 14, h), Color.from_hsv(0.08 + b * 0.05, 0.25, 0.7))
			x += 19.0


static func _tansu(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-85, -230, 170, 230), WOOD_DARK)
	for r in 4:
		var y := -222.0 + r * 55.0
		ci.draw_rect(Rect2(-77, y, 154, 50), WOOD)
		ci.draw_rect(Rect2(-12, y + 22, 24, 6), WARN)


static func _shelter(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-110, -200, 220, 12), CONCRETE)
	ci.draw_rect(Rect2(-104, -188, 6, 188), CONCRETE)
	ci.draw_rect(Rect2(98, -188, 6, 188), CONCRETE)
	ci.draw_rect(Rect2(-98, -150, 196, 90), Color(0.8, 0.9, 0.95, 0.55))
	ci.draw_rect(Rect2(-60, -48, 120, 10), Color("#8C8A84"))


static func _houses(ci: CanvasItem, w: float) -> void:
	var x := 0.0
	var i := 0
	while x < w:
		var hw := 120.0 + float((i * 37) % 40)
		var hh := 150.0 + float((i * 23) % 30)
		ci.draw_rect(Rect2(x, -hh, hw, hh), Color("#D8D2C4"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, -hh), Vector2(x + hw / 2.0, -hh - 46), Vector2(x + hw + 8, -hh)]), ROOF)
		ci.draw_rect(Rect2(x + hw * 0.3, -70, 30, 70), Color("#9A8E78"))
		x += hw + 24.0
		i += 1


static func _fence(ci: CanvasItem, w: float) -> void:
	var x := 0.0
	while x < w:
		ci.draw_rect(Rect2(x, -150, 6, 150), CONCRETE)
		x += 40.0
	ci.draw_rect(Rect2(0, -140, w, 5), CONCRETE)
	ci.draw_rect(Rect2(0, -70, w, 5), CONCRETE)
	ci.draw_rect(Rect2(w * 0.4, -130, 130, 56), WARN)
	ci.draw_rect(Rect2(w * 0.4 + 5, -125, 120, 46), PAPER)
	_text(ci, Vector2(w * 0.4 + 14, -92), "立入禁止", 26)


static func _kominkan(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-150, -200, 300, 200), Color("#D9D5CA"))
	ci.draw_rect(Rect2(-160, -214, 320, 16), CONCRETE)
	ci.draw_rect(Rect2(-30, -110, 60, 110), Color("#7FA0B4"))
	for i in 3:
		ci.draw_rect(Rect2(-130 + i * 8, -160, 0, 0), WALL)
	ci.draw_rect(Rect2(60, -150, 70, 56), Color(0.8, 0.9, 0.95, 0.7))
	ci.draw_rect(Rect2(-130, -150, 70, 56), Color(0.8, 0.9, 0.95, 0.7))


static func _board(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-80, -170, 160, 120), WOOD_DARK)
	ci.draw_rect(Rect2(-72, -162, 144, 104), Color("#D7C9A5"))
	ci.draw_rect(Rect2(-60, -150, 56, 76), PAPER)
	ci.draw_rect(Rect2(6, -150, 56, 50), PAPER)
	ci.draw_rect(Rect2(-6, -50, 12, 50), WOOD_DARK)
	_text(ci, Vector2(-56, -108), "体操", 18)


static func _bench(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-80, -48, 160, 10), WOOD)
	ci.draw_rect(Rect2(-80, -96, 160, 8), WOOD)
	ci.draw_rect(Rect2(-72, -38, 8, 38), WOOD_DARK)
	ci.draw_rect(Rect2(64, -38, 8, 38), WOOD_DARK)
	ci.draw_rect(Rect2(-72, -96, 6, 50), WOOD_DARK)
	ci.draw_rect(Rect2(66, -96, 6, 50), WOOD_DARK)


static func _frame(ci: CanvasItem, kid: bool) -> void:
	ci.draw_rect(Rect2(-60, -200, 120, 130), WOOD_DARK)
	ci.draw_rect(Rect2(-52, -192, 104, 114), Color("#9DBBD9") if not kid else PAPER)
	if kid:
		ci.draw_rect(Rect2(-44, -184, 88, 56), Color("#8FB8DC"))
		_text(ci, Vector2(-48, -98), "なつやすみの おもいで", 12)
	else:
		ci.draw_rect(Rect2(-52, -150, 104, 58), Color("#78A663"))
	ci.draw_rect(Rect2(-4, -70, 8, 70), WOOD_DARK)


static func _dig(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(0, -4), 5, Color(0.45, 0.33, 0.22, 0.9))
	ci.draw_rect(Rect2(-24, -6, 48, 8), Color(0.5, 0.38, 0.26, 0.55))
	ci.draw_line(Vector2(-18, -18), Vector2(18, -18), Color(0.5, 0.38, 0.26), 3.0)
	ci.draw_line(Vector2(0, -34), Vector2(0, -6), Color(0.5, 0.38, 0.26), 3.0)


static func _steps(ci: CanvasItem, w: float) -> void:
	var n := 7
	for i in n:
		var y := -float(i + 1) * 14.0
		ci.draw_rect(Rect2(0, y, w - i * 18.0, 14), Color("#B7B1A2"))
		ci.draw_rect(Rect2(0, y, w - i * 18.0, 3), Color("#8F8A7B"))


static func _figures(ci: CanvasItem) -> void:
	var c := Color(0.95, 0.95, 0.9, 0.9)
	ci.draw_rect(Rect2(-60, -120, 26, 120), c)
	ci.draw_circle(Vector2(-47, -140), 18, c)
	ci.draw_rect(Rect2(10, -105, 26, 105), c)
	ci.draw_circle(Vector2(23, -122), 16, c)


static func _child_painting(ci: CanvasItem) -> void:
	var c := Color(0.95, 0.9, 0.95, 0.9)
	ci.draw_rect(Rect2(-14, -70, 28, 70), c)
	ci.draw_circle(Vector2(0, -86), 16, c)
	ci.draw_rect(Rect2(26, -96, 5, 96), WOOD_DARK)
	ci.draw_rect(Rect2(20, -120, 56, 44), PAPER)
	ci.draw_rect(Rect2(26, -114, 44, 22), Color("#8FB8DC"))


static func _base_old(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-90, -110, 180, 110), Color("#9A8A6E"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-100, -110), Vector2(0, -170), Vector2(100, -110)]), Color("#8E9A9C"))
	ci.draw_rect(Rect2(-20, -80, 40, 80), Color("#3D342A"))


static func _look_sky(ci: CanvasItem) -> void:
	# なつみが指さした空：上を向く小さなしるし
	ci.draw_line(Vector2(0, -10), Vector2(0, -60), Color(1.0, 0.9, 0.6, 0.8), 3.0)
	ci.draw_line(Vector2(0, -60), Vector2(-9, -48), Color(1.0, 0.9, 0.6, 0.8), 3.0)
	ci.draw_line(Vector2(0, -60), Vector2(9, -48), Color(1.0, 0.9, 0.6, 0.8), 3.0)


## 看板などの文字（仮素材。フォントはテーマの既定）
static func _text(ci: CanvasItem, pos: Vector2, text: String, size: int) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
