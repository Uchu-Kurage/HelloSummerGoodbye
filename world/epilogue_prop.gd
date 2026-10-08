@tool
extends Node2D
## エピローグ「それから」の、年月がたった差分（仮の図形。本番の絵が入るまで）。足もと（地面）が原点。
## 使い回す背景（バス停・駄菓子屋・公民館・鳥居・狛犬・祖父母の家）の上や横に重ねて置く。

enum Kind {
	BUS_RUST,    ## バス停の時刻表の看板のさび（バス停の絵の左の看板に重ねる）
	SHUTTER,     ## 駄菓子屋のシャッター（駄菓子屋の絵に重ねる。雨ざらしのくすみは、駄菓子屋の絵の modulate で）
	POSTER,      ## 公民館の前の掲示板と、展覧会のポスター「なつやすみの おもいで」
	STEPS,       ## 神社の石段（右へのぼる）
	BASE_RUINS,  ## 崩れた秘密基地（板とトタンだけが残る）
	MAN_BACK,    ## しゃがんで土を掘る、おとなの男（背中だけ）
	HUNG_HAT,    ## 縁側の柱に掛けた麦わら帽子
}

const P := preload("res://world/world_palette.gd")

@export var kind: Kind = Kind.BUS_RUST:
	set(v):
		kind = v
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.BUS_RUST: _bus_rust()
		Kind.SHUTTER: _shutter()
		Kind.POSTER: _poster()
		Kind.STEPS: _steps()
		Kind.BASE_RUINS: _base_ruins()
		Kind.MAN_BACK: _man_back()
		Kind.HUNG_HAT: _hung_hat()


func _bus_rust() -> void:
	# 丸い時刻表の看板（足もとから 190px ほど上）と柱に、さびのしみ
	for p in [Vector2(-12, -200), Vector2(10, -182), Vector2(4, -208), Vector2(-14, -178), Vector2(0, -120), Vector2(-1, -70)]:
		draw_circle(p, 8.0, P.RUST)
	draw_rect(Rect2(-3, -165, 6, 145), Color(P.RUST, 0.35))


func _shutter() -> void:
	# 店先（品物の棚のところ）をおおうシャッター。横の筋と、下のさび
	var r := Rect2(-120, -205, 230, 140)
	draw_rect(r, P.SHUTTER)
	var y := r.position.y + 10.0
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), P.SHUTTER_LINE, 2.0)
		y += 12.0
	draw_rect(Rect2(r.position.x, r.end.y - 18, r.size.x, 18), Color(P.RUST, 0.35))


func _poster() -> void:
	# 掲示板の脚と板
	draw_rect(Rect2(-56, -150, 8, 150), P.RUIN_BOARD)
	draw_rect(Rect2(48, -150, 8, 150), P.RUIN_BOARD)
	draw_rect(Rect2(-70, -230, 140, 96), P.RUIN_BOARD)
	# ポスター：青い空と田んぼの絵（題の文字は、上に置いた札で出す）
	var r := Rect2(-58, -222, 116, 80)
	draw_rect(r, P.POSTER_PAPER)
	draw_rect(Rect2(r.position + Vector2(8, 22), Vector2(r.size.x - 16, 30)), P.POSTER_SKY)
	draw_rect(Rect2(r.position + Vector2(8, 52), Vector2(r.size.x - 16, 18)), P.POSTER_FIELD)


func _steps() -> void:
	# 手前から右奥の鳥居へのぼる石段（7段）
	var n := 7
	for i in n:
		var x := i * 26.0
		var y := -i * 10.0
		var w := 150.0 - i * 6.0
		draw_rect(Rect2(x - w / 2.0, y - 12, w, 12), P.STEP_STONE)
		draw_line(Vector2(x - w / 2.0, y - 12), Vector2(x + w / 2.0, y - 12), P.STEP_EDGE, 2.0)


func _base_ruins() -> void:
	# 倒れた柱と、ななめに残った板、地面に落ちたトタン
	draw_set_transform(Vector2(-60, -6), -0.25, Vector2.ONE)
	draw_rect(Rect2(-60, -10, 150, 12), P.RUIN_BOARD)
	draw_set_transform(Vector2(40, -40), 0.5, Vector2.ONE)
	draw_rect(Rect2(-8, -70, 12, 110), P.RUIN_BOARD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-120, -20, 90, 12), P.RUIN_BOARD)
	var tin := PackedVector2Array([Vector2(60, -2), Vector2(170, -10), Vector2(176, -30), Vector2(66, -24)])
	draw_colored_polygon(tin, P.RUIN_TIN)
	for i in 5:
		var t := (i + 0.5) / 5.0
		draw_line(Vector2(60, -2).lerp(Vector2(170, -10), t), Vector2(66, -24).lerp(Vector2(176, -30), t), Color(P.STEP_EDGE, 0.6), 2.0)


func _man_back() -> void:
	# しゃがんだ背中（顔は見せない）。左向きに、基地の土を掘っている
	draw_rect(Rect2(-26, -46, 52, 40), P.MAN_PANTS)
	draw_circle(Vector2(-18, -8), 12, P.MAN_PANTS)
	draw_circle(Vector2(18, -8), 12, P.MAN_PANTS)
	var back := PackedVector2Array([Vector2(-34, -40), Vector2(30, -40), Vector2(22, -112), Vector2(-24, -116)])
	draw_colored_polygon(back, P.MAN_SHIRT)
	draw_circle(Vector2(-2, -128), 17, P.MAN_HAIR)
	draw_circle(Vector2(-14, -124), 6, P.MAN_SKIN)
	# 土を掘る手（左の地面）
	draw_line(Vector2(-26, -90), Vector2(-56, -18), P.MAN_SHIRT, 9.0)
	draw_circle(Vector2(-58, -14), 6, P.MAN_SKIN)


func _hung_hat() -> void:
	# 柱のくぎに掛けた麦わら帽子
	draw_line(Vector2(0, -260), Vector2(0, -244), P.STEP_EDGE, 3.0)
	draw_set_transform(Vector2(0, -230), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 34, P.STRAW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, -238), 18, P.STRAW)
	draw_rect(Rect2(-18, -236, 36, 6), P.STRAW_BAND)
