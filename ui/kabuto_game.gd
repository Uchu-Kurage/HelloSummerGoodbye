class_name KabutoGame
extends Control
## ミニゲーム「カブトムシとり」（6日目の早朝、親友ルート）。会話の @game kabuto で始まる。
## 薄暗いクヌギ林で、罠の木のカブトムシにそっと近づいてつかむ。息を殺す「静かな緊張」のミニゲーム。
## 押しつづけると、そっと前へ進む。離すと止まる。手が届くところまで来たら「つかむ」。
## カブトムシは バナナを食べている → 気づきかける（ツノがぴくっ、羽が浮く。カサッ）→ 気にしている → 食べている、をくりかえす。
## 気にしているときに動くと、木から落ちる。落ちても、もぞもぞ根もとへ動いて、木をのぼって元の場所にもどる。
## 時間制限も失敗もない。落とした回数を GameState.kabuto_drops に入れ、フラグ kabuto_clean / kabuto_dropped も立てる

signal finished

enum Phase { APPROACH, GRAB, CAUGHT, DONE }
enum Bug { EAT, NOTICE, WARY, FALLEN }

## 木までの距離（押しつづけて、合計この秒数）
const APPROACH_TIME := 6.0
## 食べている長さ（この範囲でばらつく）
const EAT_MIN := 1.5
const EAT_MAX := 4.0
## 気づきかけ・気にしている長さ
const NOTICE_TIME := 0.6
const WARY_TIME := 1.2
## 落ちてから：落ちる → 根もとへ → 木をのぼって元の場所へ
const FALL_TIME := 0.35
const CRAWL_TIME := 1.4
const CLIMB_TIME := 1.6
## 心臓の音：遠いときと、手が届くところでの間隔（秒）と大きさ（dB）
const HEART_FAR := 1.1
const HEART_NEAR := 0.45
const HEART_DB_FAR := -26.0
const HEART_DB_NEAR := -4.0
## 足音の間隔（進んでいるあいだ）
const STEP_EVERY := 0.55
## つかんだあと、夜が明けて蝉が鳴き出すのを見せる時間（決定キー・タップで早送り）
const CAUGHT_TIME := 2.4
## つかんだ瞬間に鳴き出す蝉（環境音）
const DAWN_CICADA_AMBIENT := "cicada_dawn_burst"
## 背景の水彩の絵と、横長の画面で残すところ（下の地面と、右寄りの大きなクヌギ）
const BG: Texture2D = preload("res://ui/minigame_bg/kabuto.jpg")
const BG_FOCUS := Vector2(0.6, 0.75)
## 絵の中の、罠の木（クヌギ）の幹のまん中と太さ、子どもが歩く地面の高さ（絵の幅・高さに対する割合）
const BG_TREE_X := 0.632
const BG_TREE_W := 0.073
const BG_GROUND := 0.83
## カブトムシのいる高さ（絵の高さに対する割合。手をのばして届く、頭くらいの高さ）
const BEETLE_Y := 0.6
## タケルの小声が消えるまで
const WHISPER_TIME := 3.0
## 子どもの絵（右向き、足もとが下の端）。頭の高さ（あご〜帽子・髪のてっぺん、絵の画素）をそろえて、
## しのび足でも手をのばしても、同じ子の大きさに見えるようにする
const KID_ME_SNEAK: Texture2D = preload("res://world/scenery/painted/player_mg2_1.png")
const KID_ME_REACH: Texture2D = preload("res://world/scenery/painted/player_mg2_2.png")
const KID_TAKERU_SNEAK: Texture2D = preload("res://world/scenery/painted/takeru_mg1_6.png")
const KID_TAKERU_STAND: Texture2D = preload("res://world/scenery/painted/npc_takeru.png")
const KID_HEAD_PX := {
	KID_ME_SNEAK: 100.0, KID_ME_REACH: 105.0, KID_TAKERU_SNEAK: 95.0, KID_TAKERU_STAND: 205.0,
}
## 画面での頭の高さ（背景の絵の画素で。絵を拡大したぶん子どもも大きくなる）
const KID_HEAD := 36.0
## 手をのばす絵の、手のひらの位置（絵の画素。足もとのまん中から）
const KID_REACH_HAND := Vector2(103, -328)
## 夜明け前の暗さに合わせた、子どもの色（つかむと 白 = そのままの色 にもどる）
const KID_SHADE := Color(0.7, 0.75, 0.9)
const P := preload("res://world/world_palette.gd")

var hud: Hud
var phase := Phase.APPROACH
var bug := Bug.EAT
## 近づいた割合（0〜1）
var progress := 0.0
## 落とした回数
var drops := 0
var rng := RandomNumberGenerator.new()
var _bug_t := 0.0
var _bug_len := 2.0
var _t := 0.0
var _speed := 1.0
var _heart_t := 0.0
var _step_t := 0.0
var _walk_clock := 0.0
## 夜明けの明るさ（つかむと 0 → 1）
var _dawn := 0.0
var _prev_ambient := ""
var _whisper_t := 0.0
var _hold: HoldInput
var _chip: PanelContainer
var _line: Label
var _hint: Label
var _grab: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	_hold = HoldInput.new()
	_hold.pressed.connect(_on_pressed)
	_hold.released.connect(_on_released)
	add_child(_hold)
	var safe := UiAnim.make_safe_area()
	add_child(safe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", UiTokens.SPACE_S)
	safe.add_child(v)
	# うしろでしゃがむタケルの小声（文字も小さく、薄めに）
	_chip = PanelContainer.new()
	_chip.theme_type_variation = &"PaperChip"
	_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_chip)
	_line = Label.new()
	_line.theme_type_variation = &"SmallLabel"
	_chip.add_child(_line)
	_chip.modulate.a = 0.0
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	# 「つかむ」（手が届くところまで来たら）
	_grab = Button.new()
	_grab.text = Strings.KABUTO_GRAB
	_grab.theme_type_variation = &"ChoiceItemSelected"
	_grab.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN * 2.5, UiTokens.TOUCH_MIN)
	_grab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grab.focus_mode = Control.FOCUS_NONE
	_grab.pressed.connect(grab)
	UiAnim.add_press_feedback(_grab)
	_grab.visible = false
	_grab.modulate.a = 0.0
	v.add_child(_grab)
	# 案内（控えめに、下の小札）
	var hint_chip := PanelContainer.new()
	hint_chip.theme_type_variation = &"PaperChip"
	hint_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint_chip)
	_hint = Label.new()
	_hint.theme_type_variation = &"SmallLabel"
	hint_chip.add_child(_hint)
	_hint.set_meta("chip", hint_chip)
	InputMode.mode_changed.connect(_refresh_hint.unbind(1))
	_refresh_hint()
	# 画面のどこを押してもよいので、右上のボタンは隠す
	get_tree().call_group("touch_controls", "set_suppressed", true)
	# 夜明けのヒグラシ・遠くの鳥・足音だけ
	_prev_ambient = SfxPlayer._ambient_name
	SfxPlayer.set_ambient(WorldPalette.KABUTO_AMBIENT)
	_start_eating()
	_hold.enabled = true
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)
	SfxPlayer.set_ambient(_prev_ambient)


## タケルの小声（うしろから）
func whisper(text: String) -> void:
	_line.text = Strings.SPEECH_FORMAT % [hud.speaker_name() if hud else "", text]
	_whisper_t = WHISPER_TIME
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func _refresh_hint() -> void:
	if phase == Phase.GRAB:
		_hint.text = Strings.KABUTO_GRAB_TOUCH if InputMode.touch else Strings.KABUTO_GRAB_KEY
	else:
		_hint.text = Strings.KABUTO_HINT_TOUCH if InputMode.touch else Strings.KABUTO_HINT_KEY


## 動いているか（押しつづけて、前へ進んでいる）
func is_moving() -> bool:
	return phase == Phase.APPROACH and _hold.is_down and bug != Bug.FALLEN


# --- 進み ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * _speed
	_t += d
	_update_bug(d)
	if _whisper_t > 0.0:
		_whisper_t -= d
		if _whisper_t <= 0.0:
			UiAnim.fade(_chip, 0.0, UiTokens.TIME_SMALL_OUT)
	match phase:
		Phase.APPROACH:
			if is_moving():
				progress = minf(progress + d / APPROACH_TIME, 1.0)
				_walk_clock += d
				_step_t -= d
				if _step_t <= 0.0:
					_step_t = STEP_EVERY
					SfxPlayer.play("leaf_step", -10.0)
				if progress >= 1.0:
					_reach()
		Phase.CAUGHT:
			_dawn = minf(_dawn + d / (CAUGHT_TIME * 0.6), 1.0)
			if _t >= CAUGHT_TIME:
				_finish()
	# 木に近づくほど、心臓の音を大きく、はやく
	if phase in [Phase.APPROACH, Phase.GRAB]:
		_heart_t -= d
		if _heart_t <= 0.0:
			_heart_t = lerpf(HEART_FAR, HEART_NEAR, progress)
			SfxPlayer.play("heartbeat", lerpf(HEART_DB_FAR, HEART_DB_NEAR, progress))
	queue_redraw()


## カブトムシの様子：食べている → 気づきかけ → 気にしている → 食べている
func _update_bug(d: float) -> void:
	if phase in [Phase.CAUGHT, Phase.DONE]:
		return
	_bug_t += d
	match bug:
		Bug.EAT:
			if _bug_t >= _bug_len:
				_set_bug(Bug.NOTICE)
				SfxPlayer.play("kabuto_rustle")
		Bug.NOTICE:
			if _bug_t >= NOTICE_TIME:
				_set_bug(Bug.WARY)
		Bug.WARY:
			# 気にしているときに動くと、木から落ちる
			if is_moving():
				_fall()
			elif _bug_t >= WARY_TIME:
				_start_eating()
		Bug.FALLEN:
			if _bug_t >= FALL_TIME + CRAWL_TIME + CLIMB_TIME:
				_start_eating()


func _set_bug(b: Bug) -> void:
	bug = b
	_bug_t = 0.0


func _start_eating() -> void:
	_set_bug(Bug.EAT)
	_bug_len = rng.randf_range(EAT_MIN, EAT_MAX)


func _fall() -> void:
	drops += 1
	_set_bug(Bug.FALLEN)
	SfxPlayer.play("kabuto_drop")
	whisper(Strings.KABUTO_DROPPED)


## 手が届くところまで来た
func _reach() -> void:
	phase = Phase.GRAB
	_hold.enabled = false
	_grab.visible = true
	UiAnim.fade(_grab, 1.0, UiTokens.TIME_SMALL)
	_refresh_hint()


## つかむ（「つかむ」ボタン、決定キー、画面のタップ。自動の動作確認からも呼べる）
func grab() -> void:
	if phase != Phase.GRAB:
		return
	phase = Phase.CAUGHT
	_t = 0.0
	SfxPlayer.play("kabuto_grab")
	UiAnim.fade(_grab, 0.0, UiTokens.TIME_SMALL_OUT)
	UiAnim.fade(_hint.get_meta("chip"), 0.0, UiTokens.TIME_SMALL_OUT)
	UiAnim.fade(_chip, 0.0, UiTokens.TIME_SMALL_OUT)
	# つかんだ瞬間に、静かだった音が戻り、蝉が一斉に鳴き出す（夜が明ける）
	SfxPlayer.set_ambient(DAWN_CICADA_AMBIENT)
	GameState.set_kabuto_result(drops)


func _on_pressed() -> void:
	_step_t = 0.0


func _on_released(_held: float) -> void:
	pass


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	var tw := UiAnim.fade(self, 0.0, UiTokens.TIME_FADE)
	await tw.finished
	finished.emit()


func _input(event: InputEvent) -> void:
	if phase == Phase.GRAB:
		var tap: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
				and event.device != InputEvent.DEVICE_ID_EMULATION)
		if tap:
			grab()
			get_viewport().set_input_as_handled()
	elif phase == Phase.CAUGHT:
		# 夜が明けるところは、決定キーやタップで早送りできる
		var skip: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed)
		if skip:
			_speed = UiTokens.SKIP_SPEED
			get_viewport().set_input_as_handled()


# --- 絵 -----------------------------------------------------------------------

## 絵の中の点（0〜1の割合）を、画面の位置に直す（MinigameBg.draw_cover と同じ切り取り方）
func _bg_point(f: Vector2) -> Vector2:
	var ts := BG.get_size()
	var k := _bg_scale()
	var src_pos := (ts - size / k) * BG_FOCUS
	return (f * ts - src_pos) * k


## 背景の絵を、画面でどれだけ拡大しているか
func _bg_scale() -> float:
	var ts := BG.get_size()
	return maxf(size.x / ts.x, size.y / ts.y)


func _draw() -> void:
	var s := size
	# 早朝の、暗く青いクヌギ林（水彩の絵）。横長の画面では上を切って、足もとを残す
	MinigameBg.draw_cover(self, BG, Rect2(Vector2.ZERO, s), BG_FOCUS)
	var ground := _bg_point(Vector2(0.0, BG_GROUND)).y
	# 罠の木（絵のまん中より右の、大きなクヌギ）とバナナ
	var tree_x := _bg_point(Vector2(BG_TREE_X, 0.0)).x
	var trunk_w := _bg_point(Vector2(BG_TREE_X + BG_TREE_W, 0.0)).x - tree_x
	# バナナとカブトムシは、幹の左の縁より少し内側（からだが空にはみ出さないように）
	var spot := Vector2(tree_x - trunk_w * 0.22, _bg_point(Vector2(0.0, BEETLE_Y)).y)
	draw_rect(Rect2(spot.x - 4, spot.y - 34, 10, 52), P.BANANA.darkened(0.25))
	draw_rect(Rect2(spot.x - 2, spot.y - 30, 6, 44), P.BANANA)
	# カブトムシ
	_draw_beetle(s, spot, tree_x, trunk_w, ground)
	var bgk := _bg_scale()
	# うしろでしゃがんで「しーっ」とするタケル（つかんだら、立ち上がる）
	var caught := phase in [Phase.CAUGHT, Phase.DONE]
	_draw_kid(KID_TAKERU_STAND if caught else KID_TAKERU_SNEAK, Vector2(s.x * 0.1, ground + 4), bgk)
	# しのび足の主人公（近づくほど木の近くへ）。木の前では、のばした手がカブトムシのすぐ手前に来る
	var reach_k := KID_HEAD * bgk / KID_HEAD_PX[KID_ME_REACH]
	var reach_x := spot.x - 36.0 * bgk - KID_REACH_HAND.x * reach_k
	var me_x := lerpf(s.x * 0.22, reach_x, progress)
	var bob := 0.0 if UiAnim.reduced() else absf(sin(_walk_clock * 5.0)) * 3.0
	if phase in [Phase.GRAB, Phase.CAUGHT, Phase.DONE]:
		var feet := Vector2(reach_x, ground + 4)
		_draw_kid(KID_ME_REACH, feet, bgk)
		if caught:
			# つかんだカブトムシを、朝の光のほうへかかげる
			var hand := feet + KID_REACH_HAND * reach_k
			var k := maxf(s.y / 720.0, 0.6)
			_ellipse(hand + Vector2(0, -6 * k), 10 * k, 14 * k, P.BEETLE)
			draw_line(hand + Vector2(0, -18 * k), hand + Vector2(0, -34 * k), P.BEETLE, 4.0 * k)
	else:
		_draw_kid(KID_ME_SNEAK, Vector2(me_x, ground + 4 - bob), bgk)
	# 暗い林の、うっすらとした暗がり（つかむと晴れて、朝の光がさす）
	draw_rect(Rect2(Vector2.ZERO, s), Color(P.KABUTO_SKY.darkened(0.6), 0.25 * (1.0 - _dawn)))
	draw_rect(Rect2(Vector2.ZERO, s), Color(P.KABUTO_SKY_DAWN, 0.18 * _dawn))


func _draw_beetle(s: Vector2, spot: Vector2, tree_x: float, trunk_w: float, ground: float) -> void:
	var pos := spot + Vector2(-6, 4)
	var head_up := 0.0
	var wings := 0.0
	var upside := false
	match bug:
		Bug.NOTICE:
			# ツノがぴくっと上がり、羽が少し浮く
			head_up = 1.0
			wings = 1.0
		Bug.WARY:
			head_up = 1.0
		Bug.FALLEN:
			var t := _bug_t
			var root := Vector2(tree_x - trunk_w * 0.5 - 8, ground - 4)
			var landed := Vector2(root.x - s.x * 0.08, ground - 4)
			if t < FALL_TIME:
				pos = pos.lerp(landed, t / FALL_TIME)
				upside = true
			elif t < FALL_TIME + CRAWL_TIME:
				pos = landed.lerp(root, (t - FALL_TIME) / CRAWL_TIME)
			else:
				pos = root.lerp(spot + Vector2(-6, 4), (t - FALL_TIME - CRAWL_TIME) / CLIMB_TIME)
	if phase in [Phase.CAUGHT, Phase.DONE]:
		return
	var k := maxf(s.y / 720.0, 0.6)
	# からだ
	_ellipse(pos, 16 * k, 24 * k, P.BEETLE)
	draw_line(pos + Vector2(0, -20 * k), pos + Vector2(0, 22 * k), P.BEETLE.lightened(0.25), 1.5)
	if wings > 0.0:
		_ellipse(pos + Vector2(-10 * k, 4 * k), 7 * k, 18 * k, Color(P.BEETLE.lightened(0.35), 0.8))
		_ellipse(pos + Vector2(10 * k, 4 * k), 7 * k, 18 * k, Color(P.BEETLE.lightened(0.35), 0.8))
	# 頭とツノ（食べているあいだはバナナに頭をつける。気づくとツノが上がる）
	var head := pos + Vector2(0, -26 * k) + Vector2(0, -6 * k * head_up)
	if upside:
		head = pos + Vector2(0, 26 * k)
	draw_circle(head, 8 * k, P.BEETLE)
	var tip := head + Vector2(lerpf(8.0, 0.0, head_up) * k, -26 * k - 8 * k * head_up)
	draw_line(head, tip, P.BEETLE, 5 * k)
	draw_line(tip, tip + Vector2(-6 * k, -6 * k), P.BEETLE, 4 * k)
	draw_line(tip, tip + Vector2(6 * k, -6 * k), P.BEETLE, 4 * k)
	# 気づきかけの「カサッ」：小さな線（音が聞こえなくても見て分かるように）
	if bug == Bug.NOTICE:
		for a in [-0.7, 0.0, 0.7]:
			var dir := Vector2.UP.rotated(a)
			draw_line(head + dir * 34 * k, head + dir * 46 * k, Color(P.KABUTO_SKY_DAWN, 0.9), 3.0)


## 子ども（手描きの絵）。pos は足もと。夜明け前は暗く青っぽく、夜が明けると元の色へ
func _draw_kid(tex: Texture2D, pos: Vector2, bgk: float) -> void:
	var k: float = KID_HEAD * bgk / KID_HEAD_PX[tex]
	var sz := tex.get_size() * k
	draw_texture_rect(tex, Rect2(pos - Vector2(sz.x * 0.5, sz.y), sz), false, KID_SHADE.lerp(Color.WHITE, _dawn))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
