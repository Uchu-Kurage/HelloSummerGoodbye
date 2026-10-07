@tool
class_name NormalProp
extends Node2D
## ノーマルルート（祖父母と過ごす夏）の場所の小物。足もと（地面）が原点。
## 絵は Google Gemini で生成した水彩の絵（背景を切り抜いたもの。res://world/scenery/painted/。プロンプトは tools/art/prompts_normal.md）。
## 物干しの柱と竿、蚊取り線香のけむり、口笛の「♪」は図形で描く。
## 会話の @event で、現れる（show_on_event）・消える（hide_on_event）・走り去る（車の drive_on_event）。

enum Kind {
	SASA,        ## 川べりの笹
	SASABUNE,    ## 帆のついた笹舟（現れると、川を右へ流れていく）
	LAUNDRY,     ## 物干しと洗濯物（hide_on_event で洗濯物だけ消える）
	MASK_STALL,  ## お面の屋台（きつね・ひょっとこ・おかめ）
	ZASHIKI,     ## 祖父母の家の座敷（開けはなした障子、たたみ、ちゃぶ台）
	RELATIVES,   ## 座敷に集まった親戚（width の幅）
	SHORYOUMA,   ## 精霊馬（きゅうりの馬・なすの牛）
	CAR,         ## 親戚の車（drive_on_event で走り去る）
	HOZUKI,      ## ほおずきの株
	KAYARI,      ## 蚊取り線香（けむりがゆれる）
	WHISTLE,     ## 口笛の「♪」（音素材が入るまでの吹き出しのかわり）
}

@export var kind: Kind = Kind.SASA:
	set(v):
		kind = v
		queue_redraw()
## 横に広がるもの（親戚）の幅
@export var width := 300.0:
	set(v):
		width = v
		queue_redraw()
## 車の絵（1 白いセダン、2 赤茶のライトバン）
@export_range(1, 2) var car := 1
## 空でなければ、はじめは隠しておき、会話の @event でこの名前が来たら現れる
@export var show_on_event := ""
## 空でなければ、会話の @event でこの名前が来たら消える
@export var hide_on_event := ""
## 車：この名前の @event で走り去る
@export var drive_on_event := ""
## 現れたときに鳴らす音（口笛など。素材がなければ無音）
@export var sfx := ""

const P := preload("res://world/world_palette.gd")
const ART := "res://world/scenery/painted/%s.png"
const SHADOW := Color(0.12, 0.16, 0.08, 0.22)
const FONT: Font = preload("res://ui/theme/fonts/ZenMaruGothic-Regular.ttf")
## 笹舟が流れる速さ（px/秒）と、流れていく距離
const SASABUNE_SPEED := 46.0
const SASABUNE_TRAVEL := 1400.0
## 車が走り去る速さ
const CAR_SPEED := 260.0

var _hidden_part := false
var _t := 0.0
var _moving := false
var _x := 0.0
var _tex_cache := {}


func _ready() -> void:
	# 絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not Engine.is_editor_hint() and show_on_event != "":
		visible = false


func on_talk_event(event_name: String) -> void:
	if show_on_event != "" and event_name == show_on_event:
		modulate.a = 0.0
		show()
		UiAnim.fade(self, 1.0, UiTokens.TIME_FADE * 2)
		if sfx != "":
			SfxPlayer.play(sfx)
		if kind == Kind.SASABUNE:
			_moving = true
	if hide_on_event != "" and event_name == hide_on_event:
		if kind == Kind.LAUNDRY:
			# 物干しは残して、洗濯物だけ取り込む
			_hidden_part = true
			queue_redraw()
		else:
			UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 2)
	if drive_on_event != "" and event_name == drive_on_event:
		_moving = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not UiAnim.reduced():
		_t += delta
	if _moving:
		match kind:
			Kind.SASABUNE:
				_x += SASABUNE_SPEED * delta
				if _x >= SASABUNE_TRAVEL:
					_moving = false
					UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 3)
			Kind.CAR:
				_x += CAR_SPEED * delta
				modulate.a = maxf(0.0, 1.0 - _x / 1600.0)
				if modulate.a <= 0.0:
					_moving = false
					hide()
	if kind in [Kind.SASABUNE, Kind.KAYARI, Kind.WHISTLE, Kind.LAUNDRY, Kind.CAR] and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.SASA: _sasa()
		Kind.SASABUNE: _sasabune()
		Kind.LAUNDRY: _laundry()
		Kind.MASK_STALL: _mask_stall()
		Kind.ZASHIKI: _zashiki()
		Kind.RELATIVES: _relatives()
		Kind.SHORYOUMA: _shoryouma()
		Kind.CAR: _car()
		Kind.HOZUKI: _hozuki()
		Kind.KAYARI: _kayari()
		Kind.WHISTLE: _whistle()


func _shadow(center: Vector2, radius: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tex(art_name: String) -> Texture2D:
	if not _tex_cache.has(art_name):
		_tex_cache[art_name] = load(ART % art_name)
	return _tex_cache[art_name]


## 絵を高さ h で描く。foot は足もと（絵の下のふちのまん中）。flip で左右を反転する
func _art(art_name: String, foot: Vector2, h: float, flip := false) -> void:
	var tex := _tex(art_name)
	var w := tex.get_width() * h / tex.get_height()
	if flip:
		draw_set_transform(foot, 0.0, Vector2(-1, 1))
		draw_texture_rect(tex, Rect2(-w / 2.0, -h, w, h), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false)


func _sasa() -> void:
	_art("prop_sasa", Vector2(0, 8), 200.0)


func _sasabune() -> void:
	# 川の上（道の向こう）を、ゆらゆら流れる。帆が立っている
	var bob := sin(_t * 2.4) * 2.0
	_art("prop_sasabune", Vector2(_x, -30 + bob), 32.0)


func _laundry() -> void:
	# 物干しの柱2本と竿（図形）。洗濯物は絵（取り込んだら消える）
	_shadow(Vector2(0, -1), Vector2(160, 6))
	for x in [-150.0, 150.0]:
		draw_rect(Rect2(x - 5, -190, 10, 194), P.SENTAKU_POLE)
		draw_line(Vector2(x - 22, -186), Vector2(x + 22, -186), P.SENTAKU_POLE, 6.0)
	draw_line(Vector2(-170, -184), Vector2(170, -184), P.SENTAKU_LINE, 4.0)
	if _hidden_part:
		return
	# 絵のひもの高さ（上から 1 割ほど）を竿にそろえる。風で少しゆれる
	var h := 112.0
	var sway := sin(_t * 1.8) * 0.02
	draw_set_transform(Vector2(0, -184 - h * 0.08), sway, Vector2.ONE)
	_art("laundry_line", Vector2(0, h), h)
	draw_set_transform(Vector2.ZERO)


func _mask_stall() -> void:
	# 屋台の絵の前に、お面をかけた板（脚つき）
	_shadow(Vector2(0, -2), Vector2(170, 10))
	_art("prop_stall", Vector2(0, 0), 290.0)
	_art("prop_mask_board", Vector2(0, 8), 190.0)


func _zashiki() -> void:
	# 座敷（開けはなした障子、仏だんと盆ちょうちん、縁側の板）
	_art("prop_zashiki", Vector2(0, 6), 270.0)


func _relatives() -> void:
	# たたみにすわった親戚4人
	var tex := _tex("prop_relatives")
	_art("prop_relatives", Vector2(0, 2), width * tex.get_height() / tex.get_width())


func _shoryouma() -> void:
	# おぼんの上に、きゅうりの馬と、なすの牛
	_art("prop_shoryouma", Vector2(0, 4), 62.0)


func _car() -> void:
	# 絵は左向きなので、反転して右へ走らせる
	var x := _x
	_shadow(Vector2(x, -2), Vector2(120, 8))
	_art("car_%d" % car, Vector2(x, 4), 92.0 if car == 1 else 104.0, true)


func _hozuki() -> void:
	_shadow(Vector2(0, -1), Vector2(50, 5))
	_art("prop_hozuki", Vector2(0, 6), 130.0)


func _kayari() -> void:
	# ブタの蚊やり（板つき）と、口からのぼる細いけむり
	var h := 72.0
	_art("prop_kayari", Vector2(0, 4), h)
	var tex := _tex("prop_kayari")
	var w := tex.get_width() * h / tex.get_height()
	var mouth := Vector2(w * 0.22, -h * 0.42)
	var pts := PackedVector2Array()
	for k in 16:
		pts.append(mouth + Vector2(sin(_t * 1.5 + k * 0.5) * k * 0.9, -k * 9.0))
	draw_polyline(pts, Color(0.92, 0.92, 0.9, 0.45), 2.0)


func _whistle() -> void:
	# 口笛の「♪」が、ふわりと上がる
	for k in 3:
		var f := fposmod(_t * 0.35 + k / 3.0, 1.0)
		var p := Vector2(20 + k * 18 + sin(_t * 2.0 + k) * 8.0, -20 - f * 90.0)
		draw_string(FONT, p, Strings.WHISTLE_NOTE, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(UiTokens.PAPER, 1.0 - f))
