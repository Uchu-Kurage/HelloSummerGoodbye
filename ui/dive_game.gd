class_name DiveGame
extends Control
## ミニゲーム「飛び込み」（7日目、親友ルート）。会話の @game dive で始まる。
## 川の淵の高い岩から、タケルと二人で息を合わせて飛び込む。失敗も時間制限もなく、いつ離しても必ず跳べる。
## 1. 岩のふちから下の淵をのぞきこむ
## 2. 押しつづけて力をため、タケルの「せー……の！」の「の！」で離す
## 3. 空中で一瞬スローになる（ぴったりなら二人が並ぶ）
## 4. 水の中：音がこもり、上から光がゆれる
## 5. 水面に顔を出して、二人で笑う
## 結果（ぴったり／はやすぎ／おそい）は GameState.dive_result に入れ、フラグ dive_perfect / dive_early / dive_late も立てる

signal finished

enum Phase { LOOK, WAIT, CHARGE, AIR, UNDER, SURFACE, DONE }

## 押しはじめてから「の！」までの秒数
const COUNT_NO := 1.3
## 「の！」の前後、この秒数以内に離すと「ぴったり」
const PERFECT_WINDOW := 0.15
## 下をのぞきこむ時間
const LOOK_TIME := 1.2
## 空中（まん中で一瞬スローになる）
const AIR_TIME := 1.8
## はやすぎ・おそいのとき、あとから跳ぶほうが遅れる時間
const FOLLOW_DELAY := 0.5
## 水の中の静けさ
const UNDER_TIME := 2.6
const SURFACE_TIME := 1.6
## 押しているあいだ足がふるえる大きさ（px）
const SHAKE := 3.0
const P := preload("res://world/world_palette.gd")
## 背景の絵（左に高い岩、右に淵）と、切り取るとき残したいところ
const BG: Texture2D = preload("res://ui/minigame_bg/dive.jpg")
const BG_FOCUS := Vector2(0.45, 0.5)
## 絵の中の位置（0〜1）。岩の上の右のふち、二人の立つところ、跳んで水に入るまでのずれ
const EDGE := Vector2(0.39, 0.34)
const ME_START := Vector2(0.325, 0.345)
const TAKERU_START := Vector2(0.365, 0.34)
const JUMP := Vector2(0.17, 0.39)
## 跳んだはじめに浮く高さ（絵の px）
const HOP := 30.0
## 子どもの大きさ（絵の 1px あたり）
const KID_SCALE := 0.42
## 子どもの姿（水彩の立ち絵。どれも右向き）
const ME_STAND: Texture2D = preload("res://world/scenery/painted/player_1.png")
const ME_CROUCH: Texture2D = preload("res://world/scenery/painted/player_mg1_1.png")
const ME_AIR: Texture2D = preload("res://world/scenery/painted/player_mg1_2.png")
const ME_FACE: Texture2D = preload("res://world/scenery/painted/player_mg1_3.png")
const TK_STAND: Texture2D = preload("res://world/scenery/painted/npc_takeru.png")
const TK_CROUCH: Texture2D = preload("res://world/scenery/painted/takeru_mg1_1.png")
const TK_AIR: Texture2D = preload("res://world/scenery/painted/takeru_mg1_2.png")
const TK_FACE: Texture2D = preload("res://world/scenery/painted/takeru_mg1_3.png")
## 絵ごとに解像度がちがうので、頭（てっぺんからあごまで）の高さを絵の px で覚えておき、どの姿でも頭が同じ大きさに見えるようにそろえる
const HEAD_PX := {
	ME_STAND: 84.0, ME_CROUCH: 79.0, ME_AIR: 89.0, ME_FACE: 101.0,
	TK_STAND: 202.0, TK_CROUCH: 116.0, TK_AIR: 97.0, TK_FACE: 119.0,
}
## 頭の高さ（KID_SCALE をかける前の単位。立つと頭四つぶんほど）
const HEAD := 36.0
## 押しはじめてから、しゃがみきるまで（秒）
const CROUCH_TIME := 0.12
## のぞきこむはじめに寄っている度合い
const LOOK_ZOOM := 1.08
## 水面に顔を出すところの寄りと、顔の大きさ（岩の上の何倍か）
const SURFACE_ZOOM := 1.5
const SURFACE_HEAD := 2.0

var hud: Hud
var phase := Phase.LOOK
var result := &""
var _t := 0.0
var _speed := 1.0
## 跳んだ時刻（AIR の中の時間。負なら、まだ跳んでいない）
var _me_jump := -1.0
var _takeru_jump := -1.0
var _air_t := 0.0
var _said_no := false
var _called := false
var _prev_ambient := ""
var _hold: HoldInput
var _chip: PanelContainer
var _line: Label
var _hint: Label
## いま絵を敷いている場所（画面座標）
var _bg_rect := Rect2()


func _ready() -> void:
	# 人物の絵は大きく描いたものを小さくして使うので、ミップマップでなめらかにする
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hold = HoldInput.new()
	_hold.pressed.connect(_on_pressed)
	_hold.released.connect(_on_released)
	add_child(_hold)
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	# タケルのひとこと（小札）
	_chip = PanelContainer.new()
	_chip.theme_type_variation = &"PaperChip"
	_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_chip)
	_line = Label.new()
	_chip.add_child(_line)
	_chip.modulate.a = 0.0
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	# 押しつづけの案内（控えめに、下の道の帯の上の小札）
	var hint_chip := PanelContainer.new()
	hint_chip.theme_type_variation = &"PaperChip"
	hint_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint_chip)
	_hint = Label.new()
	_hint.theme_type_variation = &"SmallLabel"
	hint_chip.add_child(_hint)
	hint_chip.modulate.a = 0.0
	_hint.set_meta("chip", hint_chip)
	# 右上のボタンは、画面のどこを押してもよいこのミニゲームでは隠す
	get_tree().call_group("touch_controls", "set_suppressed", true)
	# 岩の上では蝉と川の音を大きめに
	_prev_ambient = SfxPlayer._ambient_name
	SfxPlayer.set_ambient(WorldPalette.DIVE_AMBIENT_ROCK)
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)
	SfxPlayer.set_ambient(_prev_ambient)


func say(text: String) -> void:
	_line.text = Strings.SPEECH_FORMAT % [hud.speaker_name() if hud else "", text]
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func _show_hint(on: bool) -> void:
	var chip: Control = _hint.get_meta("chip")
	_hint.text = Strings.DIVE_HINT_TOUCH if InputMode.touch else Strings.DIVE_HINT_KEY
	UiAnim.fade(chip, 1.0 if on else 0.0, UiTokens.TIME_SMALL)


# --- 進み ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * _speed
	_t += d
	match phase:
		Phase.LOOK:
			if _t >= LOOK_TIME:
				_go(Phase.WAIT)
				_hold.enabled = true
				_show_hint(true)
		Phase.CHARGE:
			# 「の！」
			if _t >= COUNT_NO and not _said_no:
				_said_no = true
				say(Strings.DIVE_COUNT_NO)
				SfxPlayer.play("count_no")
			# 離さないまま「の！」を過ぎたら、タケルだけ先に跳ぶ（いつ離しても跳べる）
			if _t > COUNT_NO + PERFECT_WINDOW and _takeru_jump < 0.0:
				result = &"late"
				_takeru_jump = 0.0
				_air_t = 0.0
				SfxPlayer.play("jump")
			# 先に水に入ったタケルが、下から呼ぶ
			if result == &"late" and not _called and _air_t >= AIR_TIME:
				_called = true
				SfxPlayer.play("splash")
				say(Strings.DIVE_LATE_CALL)
		Phase.AIR:
			_air_t += d
			var last := maxf(_me_jump, _takeru_jump)
			if _air_t >= last + AIR_TIME:
				SfxPlayer.play("splash")
				# 水に入った瞬間、すべての音がこもる
				SfxPlayer.set_ambient(WorldPalette.DIVE_AMBIENT_UNDER)
				_go(Phase.UNDER)
		Phase.UNDER:
			if _t >= UNDER_TIME:
				SfxPlayer.set_ambient(_prev_ambient)
				SfxPlayer.play("surface")
				_go(Phase.SURFACE)
		Phase.SURFACE:
			if _t >= SURFACE_TIME:
				_finish()
	# おそいとき、タケルは先に空中へ
	if phase == Phase.CHARGE and _takeru_jump >= 0.0:
		_air_t += d
	queue_redraw()


func _go(p: Phase) -> void:
	phase = p
	_t = 0.0


func _on_pressed() -> void:
	if phase != Phase.WAIT:
		return
	_go(Phase.CHARGE)
	SfxPlayer.play("breath")
	say(Strings.DIVE_COUNT_SE)


func _on_released(_held: float) -> void:
	if phase != Phase.CHARGE:
		return
	_hold.enabled = false
	_show_hint(false)
	var off := _t - COUNT_NO
	if result == &"late":
		# タケルはもう跳んでいる。下から呼んでいた声のまま
		_me_jump = _air_t
	elif off < -PERFECT_WINDOW:
		result = &"early"
		_me_jump = 0.0
		_takeru_jump = FOLLOW_DELAY
		_air_t = 0.0
	else:
		result = &"perfect"
		_me_jump = 0.0
		_takeru_jump = 0.0
		_air_t = 0.0
	GameState.set_dive_result(result)
	SfxPlayer.play("jump")
	_chip.modulate.a = 0.0
	phase = Phase.AIR


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


## 跳んだあとの演出は、決定キーやタップで早送りできる
func _input(event: InputEvent) -> void:
	if phase in [Phase.AIR, Phase.UNDER, Phase.SURFACE]:
		var tap: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_speed = UiTokens.SKIP_SPEED
			get_viewport().set_input_as_handled()


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	match phase:
		Phase.UNDER:
			_draw_under(s)
		Phase.SURFACE, Phase.DONE:
			_draw_surface(s)
		_:
			_draw_cliff(s)


## 岩のふちと、ずっと下の淵（水彩の絵）。のぞきこむあいだ、絵が少し寄ったところから引いていく
func _draw_cliff(s: Vector2) -> void:
	var zoom := 1.0
	if phase == Phase.LOOK and not UiAnim.reduced():
		zoom = lerpf(LOOK_ZOOM, 1.0, smoothstep(0.0, 1.0, _t / LOOK_TIME))
	_bg_rect = _cover_rect(s, zoom, _img(EDGE, Rect2(Vector2.ZERO, s)))
	MinigameBg.draw_cover(self, BG, _bg_rect, BG_FOCUS)
	var k := _img_scale()
	# 淵の水面にゆれる光（ごく控えめに）
	for i in 6:
		var f := Vector2(0.5 + fposmod(i * 0.317 + _clock() * 0.012, 0.42), 0.68 + i * 0.045)
		var p := _img(f, _bg_rect)
		draw_line(p, p + Vector2(40 * k, 0), Color(P.WATER_LIGHT, 0.35), 2.0)
	# ふたり（跳ぶ前は岩のふち。押しているあいだはしゃがみ、主人公の足がふるえる）
	var shake := 0.0
	var crouch := 0.0
	if phase == Phase.CHARGE:
		shake = 0.0 if UiAnim.reduced() else sin(_clock() * 60.0) * SHAKE * clampf(_t / COUNT_NO, 0.0, 1.0)
		crouch = 1.0 if UiAnim.reduced() else clampf(_t / CROUCH_TIME, 0.0, 1.0)
	elif phase == Phase.AIR:
		# 遅れて跳ぶほうは、しゃがんだまま待つ
		crouch = 1.0
	var kk := KID_SCALE * k
	var me_land := _img(ME_START + JUMP, _bg_rect)
	var tk_land := _img(TAKERU_START + JUMP, _bg_rect)
	var me_pos := _fall_pos(_me_jump, _img(ME_START, _bg_rect), me_land, k)
	var tk_pos := _fall_pos(_takeru_jump, _img(TAKERU_START, _bg_rect), tk_land, k)
	# 水に入ったら姿は消え、しぶきだけ残る
	if not _landed(_takeru_jump):
		_draw_kid(_pose(true, _takeru_jump, crouch), tk_pos, kk)
	if not _landed(_me_jump):
		_draw_kid(_pose(false, _me_jump, crouch), me_pos + Vector2(shake if _me_jump < 0.0 else 0.0, 0), kk)
	# 水しぶき（ぴったりなら重なる）
	for j in [_me_jump, _takeru_jump]:
		if j >= 0.0 and _air_t > j + AIR_TIME * 0.92:
			var t := clampf((_air_t - j - AIR_TIME * 0.92) / (AIR_TIME * 0.2), 0.0, 1.0)
			var land := me_land if j == _me_jump else tk_land
			draw_arc(land, (14 + 34 * t) * k, PI, TAU, 20, Color(P.WATER_LIGHT, 1.0 - t), 3.0)


## いまの姿。跳んだら空中の絵、跳ぶ前はしゃがみ具合で立ち絵としゃがみ絵を切りかえる
func _pose(takeru: bool, jump: float, crouch: float) -> Texture2D:
	if jump >= 0.0 and _air_t >= jump:
		return TK_AIR if takeru else ME_AIR
	if crouch >= 0.5:
		return TK_CROUCH if takeru else ME_CROUCH
	return TK_STAND if takeru else ME_STAND


func _landed(jump: float) -> bool:
	return jump >= 0.0 and _air_t >= jump + AIR_TIME


## 跳んだあとの位置。まん中あたりで一瞬スローになる
func _fall_pos(jump: float, start: Vector2, land: Vector2, k: float) -> Vector2:
	if jump < 0.0 or _air_t < jump:
		return start
	var u := clampf((_air_t - jump) / AIR_TIME, 0.0, 1.0)
	# スロー：0.35〜0.6 のあいだ、時間の進みをゆっくりにする
	var w := u + 0.12 * sin(u * TAU)
	w = clampf(w, 0.0, 1.0)
	var x := lerpf(start.x, land.x, w)
	# はじめに少し浮いてから、淵へ落ちていく
	var y := start.y - HOP * k * 4.0 * w * (1.0 - w) + (land.y - start.y) * w * w
	return Vector2(x, y)


## 水の中：上から光がゆれ、泡がのぼる。二人が並んでしずむ
func _draw_under(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), P.WATER_DEEP.darkened(0.2))
	# 水面に近いほど明るい（段を重ねて、ゆるやかに）
	for i in 6:
		draw_rect(Rect2(0, 0, s.x, s.y * (0.08 + 0.07 * i)), Color(P.WATER, 0.09))
	var c := _clock()
	for i in 5:
		var x := s.x * (0.15 + 0.18 * i) + sin(c * 0.8 + i) * 30.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 0), Vector2(x + 20, 0), Vector2(x + 90, s.y), Vector2(x + 30, s.y)]),
			Color(P.WATER_LIGHT, 0.12 + 0.06 * sin(c * 1.3 + i * 2.0)))
	for i in 14:
		var bx := fposmod(i * 0.618, 1.0) * s.x
		var by := s.y - fposmod(c * 40.0 + i * 70.0, s.y)
		draw_arc(Vector2(bx, by), 3 + (i % 3) * 2, 0, TAU, 10, Color(P.WATER_LIGHT, 0.6), 1.5)
	# 跳んだときの姿のまま、水の色にそまって並んでしずむ
	var sink := minf(_t / UNDER_TIME, 1.0) * 40.0
	var gap := 50.0 if result == &"perfect" else 110.0
	var tint := Color(P.WATER_LIGHT.lerp(P.WATER, 0.4), 0.8)
	_draw_kid(ME_AIR, Vector2(s.x * 0.5 - gap, s.y * 0.7 + sink), 0.8, tint)
	_draw_kid(TK_AIR, Vector2(s.x * 0.5 + gap, s.y * 0.7 + sink + (0.0 if result == &"perfect" else -30.0)), 0.8, tint)


## 水面に顔を出して、二人で笑う（同じ絵の淵に寄って）
func _draw_surface(s: Vector2) -> void:
	var mid := (ME_START + TAKERU_START) * 0.5 + JUMP
	_bg_rect = _cover_rect(s, SURFACE_ZOOM, _img(mid, Rect2(Vector2.ZERO, s)))
	MinigameBg.draw_cover(self, BG, _bg_rect, BG_FOCUS)
	var k := _img_scale()
	var c := _img(mid, _bg_rect)
	var kk := KID_SCALE * k * SURFACE_HEAD
	var r := HEAD * kk * 0.5
	var bob := sin(_clock() * 3.0) * 3.0
	for side in [-1.0, 1.0]:
		var is_takeru: bool = side > 0.0
		var wy: float = c.y + bob * side
		var at := Vector2(c.x + side * r * 2.2, wy)
		# 顔のまわりの波の輪（水面に寝かせただ円）。奥の半分は体のうしろ、手前の半分は体の前に
		var rw := r * 1.7 * (1.0 + 0.12 * sin(_clock() * 2.0 + side))
		var back := PackedVector2Array()
		var front := PackedVector2Array()
		for i in 17:
			back.append(Vector2(at.x, wy) + Vector2(cos(PI + PI * i / 16.0) * rw, sin(PI + PI * i / 16.0) * rw * 0.22))
			front.append(Vector2(at.x, wy) + Vector2(cos(PI * i / 16.0) * rw, sin(PI * i / 16.0) * rw * 0.22))
		draw_polyline(back, Color(P.WATER_LIGHT, 0.6), 2.0)
		# あごから下は水の中。絵の下のふちが水面。タケルはこちらを向いて笑う
		_draw_kid(TK_FACE if is_takeru else ME_FACE, at, kk, Color.WHITE, is_takeru)
		draw_polyline(front, Color(P.WATER_LIGHT, 0.6), 2.0)


## 絵をどこに敷くか。zoom は anchor（画面の点）を中心に寄る。1 なら画面ちょうど
func _cover_rect(s: Vector2, zoom: float, anchor: Vector2) -> Rect2:
	return Rect2(anchor * (1.0 - zoom), s * zoom)


## 絵の中の点（0〜1）が、画面のどこに来るか（MinigameBg.draw_cover と同じ切り取りかた）
func _img(f: Vector2, rect: Rect2) -> Vector2:
	var ts := BG.get_size()
	var k := maxf(rect.size.x / ts.x, rect.size.y / ts.y)
	var src_pos := (ts - rect.size / k) * BG_FOCUS
	return rect.position + (f * ts - src_pos) * k


## 絵の 1px が、いま画面で何 px か
func _img_scale() -> float:
	var ts := BG.get_size()
	return maxf(_bg_rect.size.x / ts.x, _bg_rect.size.y / ts.y)


## 子どもを描く。pos は足もと（顔だけの絵なら下のふち）のまん中。scale_k は KID_SCALE の単位 1 が画面で何 px か
func _draw_kid(tex: Texture2D, pos: Vector2, scale_k: float, tint := Color.WHITE, flip := false) -> void:
	var sz := tex.get_size() * (HEAD * scale_k / float(HEAD_PX[tex]))
	draw_set_transform(pos, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y), false, tint)
	draw_set_transform(Vector2.ZERO)


## 絵の動き（動きを減らす設定では止める）
func _clock() -> float:
	return 0.0 if UiAnim.reduced() else float(Time.get_ticks_msec()) / 1000.0
