class_name ChapterArt
extends RefCounted
## 章「あの夏へ」の小物の絵。病室・家の中・今の村・青年期の回想・破・造成地の小物。足もとが原点（上が -y）。
## 水彩の絵（world/scenery/painted/chapter_*.png。プロンプトは tools/art/prompts_chapter.md）を描く。絵のないもの（回想の重なり・精霊馬・座敷）は図形のまま。
## ExamineSpot と ChapterProp が、同じ描き方を使う。

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
	SPIRIT_HORSE,     ## 縁側の精霊馬（きゅうりの馬となすの牛）
	ZASHIKI,          ## 座敷の座卓（お酒とお皿）
	EASEL,            ## なつみの描きかけの絵（青い空）
	WATERMELON,       ## 縁側のスイカ
	NONE,             ## 何も描かない（調べる・撮る範囲だけ）
	MOUND,            ## 造成地の土の山
	EXCAVATOR,        ## 造成地のショベルカー
	STAKES,           ## 造成地の、測量のくいが刺さった小さな土の山
	STUMPS,           ## 造成地の、切り株の残る地面
}

## 水彩の絵（preload。描くときに load すると、はじめの1回が白い四角になる）と置き方。anchor：足もとの中心（C）／左はし（L）。高さ（h）か幅（w）のどちらかで大きさを決める。
## width が 0 でなければ、幅（w）は width に合わせる（住宅地・フェンス・石段・土の山）。lift：足もとから絵の下までの高さ
const PAINTED := {
	Kind.BED: [preload("res://world/scenery/painted/chapter_room_1.png"), "C", 0.0, 280.0, 0.0],
	Kind.APPLE_TABLE: [preload("res://world/scenery/painted/chapter_room_2.png"), "C", 112.0, 0.0, 0.0],
	Kind.WINDOW_SUNSET: [preload("res://world/scenery/painted/chapter_room_3.png"), "C", 180.0, 0.0, 100.0],
	Kind.ROOM_DOOR: [preload("res://world/scenery/painted/chapter_room_4.png"), "C", 250.0, 0.0, 0.0],
	Kind.CORRIDOR_LAMP: [preload("res://world/scenery/painted/chapter_room_6.png"), "C", 72.0, 0.0, 290.0],
	Kind.CLOSET: [preload("res://world/scenery/painted/chapter_room_7.png"), "C", 250.0, 0.0, 0.0],
	Kind.BOOKSHELF: [preload("res://world/scenery/painted/chapter_room_8.png"), "C", 260.0, 0.0, 0.0],
	Kind.TANSU: [preload("res://world/scenery/painted/prop_tansu.png"), "C", 240.0, 0.0, 0.0],
	Kind.SHELTER_NEW: [preload("res://world/scenery/painted/chapter_now_1.png"), "C", 200.0, 0.0, 0.0],
	Kind.HOUSES_ROW: [preload("res://world/scenery/painted/chapter_now_2.png"), "L", 0.0, -1.0, 0.0],
	Kind.FENCE_SIGN: [preload("res://world/scenery/painted/chapter_now_6.png"), "L", 0.0, -1.0, 0.0],
	Kind.KOMINKAN_NEW: [preload("res://world/scenery/painted/chapter_now_4.png"), "C", 170.0, 0.0, 0.0],
	Kind.BOARD_BILL: [preload("res://world/scenery/painted/chapter_now_5.png"), "C", 190.0, 0.0, 0.0],
	Kind.BENCH: [preload("res://world/scenery/painted/chapter_memory_1.png"), "C", 0.0, 170.0, 0.0],
	Kind.FRAME: [preload("res://world/scenery/painted/chapter_memory_2.png"), "C", 135.0, 0.0, 70.0],
	Kind.FRAME_KID: [preload("res://world/scenery/painted/chapter_memory_3.png"), "C", 0.0, 130.0, 70.0],
	Kind.DIG_SPOT: [preload("res://world/scenery/painted/chapter_memory_5.png"), "C", 0.0, 80.0, 0.0],
	Kind.SHRINE_STEPS: [preload("res://world/scenery/painted/chapter_memory_4.png"), "L", 0.0, -1.0, 0.0],
	Kind.EASEL: [preload("res://world/scenery/painted/chapter_ha_1.png"), "C", 160.0, 0.0, 0.0],
	Kind.WATERMELON: [preload("res://world/scenery/painted/chapter_ha_2.png"), "C", 0.0, 170.0, 0.0],
	Kind.MOUND: [preload("res://world/scenery/painted/chapter_site_1.png"), "C", 0.0, -0.55, 0.0],
	Kind.EXCAVATOR: [preload("res://world/scenery/painted/chapter_site_3.png"), "C", 130.0, 0.0, 0.0],
	Kind.STAKES: [preload("res://world/scenery/painted/chapter_site_2.png"), "C", 0.0, 220.0, 0.0],
	Kind.STUMPS: [preload("res://world/scenery/painted/chapter_site_4.png"), "C", 0.0, 300.0, 0.0],
}
## 窓の外（夕焼け）を見せる範囲（窓の絵の中の割合。ガラスは透明にしてあり、カーテンは手前にかかる）
const WINDOW_GLASS := Rect2(0.04, 0.08, 0.82, 0.84)

const WALL := Color("#E6E0D2")
const WALL_DARK := Color("#CFC7B4")
const WOOD := Color("#8E6A4A")
const WOOD_DARK := Color("#6F513A")
const CLOTH := Color("#F1EEE6")
const SKY_SUNSET := Color("#F0A36B")
const PAPER := Color("#F6EEDC")
const INK := Color("#3B3226")


static func draw(ci: CanvasItem, kind: Kind, width := 160.0) -> void:
	if PAINTED.has(kind):
		_painted(ci, kind, width)
		return
	match kind:
		Kind.FIGURES_GRANDPARENTS: _figures(ci)
		Kind.FIGURE_CHILD_PAINTING: _child_painting(ci)
		Kind.BASE_OLD: _base_old(ci)
		Kind.LOOK_SKY: _look_sky(ci)
		Kind.SPIRIT_HORSE: _spirit_horse(ci)
		Kind.ZASHIKI: _zashiki(ci)
		Kind.NONE: pass


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


static func _spirit_horse(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-70, -40, 140, 8), WOOD)
	ci.draw_rect(Rect2(-60, -32, 6, 32), WOOD_DARK)
	ci.draw_rect(Rect2(54, -32, 6, 32), WOOD_DARK)
	# きゅうりの馬（細長い緑）となすの牛（丸い紫）
	ci.draw_rect(Rect2(-56, -66, 56, 22), Color("#6E9A4E"))
	ci.draw_rect(Rect2(-50, -44, 4, 14), Color("#C9B58A"))
	ci.draw_rect(Rect2(-14, -44, 4, 14), Color("#C9B58A"))
	ci.draw_circle(Vector2(36, -58), 20, Color("#5B3F6B"))
	ci.draw_rect(Rect2(24, -40, 4, 10), Color("#C9B58A"))
	ci.draw_rect(Rect2(46, -40, 4, 10), Color("#C9B58A"))


static func _zashiki(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-110, -50, 220, 12), WOOD)
	ci.draw_rect(Rect2(-100, -38, 8, 38), WOOD_DARK)
	ci.draw_rect(Rect2(92, -38, 8, 38), WOOD_DARK)
	ci.draw_rect(Rect2(-70, -78, 22, 28), Color("#C9D6D2"))
	ci.draw_rect(Rect2(-20, -64, 48, 14), Color("#E6D8B8"))
	ci.draw_rect(Rect2(50, -72, 22, 22), Color("#C9D6D2"))


## 水彩の絵を1つ描く（PAINTED の置き方で）
static func _painted(ci: CanvasItem, kind: Kind, width: float) -> void:
	var spec: Array = PAINTED[kind]
	var tex: Texture2D = spec[0]
	var h: float = spec[2]
	var w: float = spec[3]
	if w < 0.0:
		# 幅を width に合わせる（-1 なら width そのまま、-0.55 なら width の 0.55 倍。土の山）
		w = absf(width) * absf(w if w != -1.0 else 1.0)
	elif w == 0.0:
		w = h * tex.get_width() / tex.get_height()
	if h == 0.0:
		h = w * tex.get_height() / tex.get_width()
	var bottom: float = spec[4]
	var left := 0.0 if spec[1] == "L" else -w / 2.0
	if kind == Kind.WINDOW_SUNSET:
		# 窓の外は夕焼け。ガラスは透明なので、うしろに空の色を敷く
		var g := WINDOW_GLASS
		ci.draw_rect(Rect2(left + g.position.x * w, -bottom - h + g.position.y * h, g.size.x * w, g.size.y * h), SKY_SUNSET)
	ci.draw_texture_rect(tex, Rect2(left, -bottom - h, w, h), false)


## 部屋の壁と床（x0〜x1。ふつうの日では DayBase が、屋外の日の中の一部の部屋では IndoorZone が使う）
static func draw_room(ci: CanvasItem, x0: float, x1: float, road_top: float, top := -300.0) -> void:
	var w := x1 - x0
	ci.draw_rect(Rect2(x0, top, w, -top + road_top + 8.0), Color("#E4DCC9"))
	ci.draw_rect(Rect2(x0, road_top - 90.0, w, 98.0), Color("#CDBFA3"))
	ci.draw_rect(Rect2(x0, road_top + 8.0, w, 900), Color("#A98862"))
	var x := x0
	while x < x1:
		ci.draw_line(Vector2(x, road_top + 8.0), Vector2(x, road_top + 140.0), Color("#8C6E4D"), 2.0)
		x += 160.0
	ci.draw_line(Vector2(x0, road_top + 8.0), Vector2(x1, road_top + 8.0), Color("#8C6E4D"), 4.0)
