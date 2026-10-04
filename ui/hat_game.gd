class_name HatGame
extends Control
## ミニゲーム「帽子を受け止める」（10日目、親友ルート。ゲーム全体の最後の操作）。会話の @game hat で始まる。
## ずっと右へ進んできたこのゲームで、この場面だけカメラが後ろ（左）を振り返り、坂道を追ってくるタケルを見る。
## 1. 窓を開ける：押しつづけると、ガタガタと少しずつ開く（離すと止まるが、閉じない）。開くほど外の音が大きくなる
## 2. 帽子を受け止める：タケルが帽子を投げる。近づいてきた帽子をタップ（キーボードは Space）すると受け止め、
##    両手でつかむ寄りのカットになる。つかめなければ顔にぽふっと当たって、ひざに乗るカットになる（どちらでも手に入る）
## 3. 手をふって、さけび返す：押すたびに「ぜったいー！」「またねー！」「タケルー！」。タケルは小さくなり、カーブで見えなくなる
## 必ず成功する。受け止めたかを GameState.hat_caught に入れ、フラグ hat_caught / hat_face も立てる

signal finished

enum Phase { LOOK, OPEN, THROW, CATCH, WAVE, CURVE, DONE }

## 後ろを振り返る時間
const LOOK_TIME := 1.4
## 窓が開くまで（押しつづけて合計）
const OPEN_TIME := 1.5
## 帽子が届くまで（風にあおられて、ふわふわと。速く飛ばさない）
const HAT_TIME := 2.6
## 帽子が近づいて、つかめるようになるところ（飛ぶ時間の割合）。ここから届くまでにタップすれば受け止める
const CATCH_FROM := 0.5
## 帽子のタップを受けつける半径（基準画面 1280×720 で。押せる範囲は 72px 以上）
const HAT_HIT_RADIUS := 80.0
## 受け止めたあとのスロー（速さと長さ）
const SLOW := 0.35
const SLOW_TIME := 0.5
## 受け止めた（ひざに乗った）寄りのカットを見せる時間。そのあと「やくそくだぞー！」
const CUT_TIME := 1.8
## タケルが自転車を止めて、小さくなっていく時間（このあいだ手をふってさけべる）
const RECEDE_TIME := 7.0
## タケルが最後の一言を足すころ（小さくなった割合）
const LAST_LINE_AT := 0.55
## カーブで景色が木にさえぎられる時間と、そのあと景色だけを見せる時間
const CURVE_TIME := 1.6
const END_TIME := 1.4
## 窓の内と外の音
const AMBIENT_INSIDE := "bus_inside"
const AMBIENT_OUTSIDE := "bus_window_open"
const AMBIENT_WIND := "bus_wind"
const P := preload("res://world/world_palette.gd")
const BG: Texture2D = preload("res://ui/minigame_bg/hat.jpg")
## 自転車のタケル（こいでいる／帽子をふりかぶる／投げたあと）。前から見た絵
const TAKERU_TEX: Array[Texture2D] = [
	preload("res://world/scenery/painted/takeru_mg2_3.png"),
	preload("res://world/scenery/painted/takeru_mg2_4.png"),
	preload("res://world/scenery/painted/takeru_mg2_5.png"),
]
## 絵の中の前輪の接地点の横の位置（絵の幅に対する割合）
const TAKERU_FOOT_X: Array[float] = [0.503, 0.573, 0.496]
## 窓の下のふちでの、タケルの高さ（タイヤの下から頭まで。基準画面で）と、そのときの絵の高さ（こいでいる絵）
const TAKERU_H := 210.0
const TAKERU_REF_H := 635.0
## 帽子を投げる手（前輪の接地点から。窓の下のふちでの大きさ）
const TAKERU_HAND := Vector2(-44, -200)
## 窓の開きがここまで来たら、タケルが帽子をふりかぶる
const WINDUP_AT := 0.75
## 主人公のうしろ姿（座って窓の外を見る／片手を上げて手をふる）
const ME_TEX: Texture2D = preload("res://world/scenery/painted/player_mg2_3.png")
const ME_WAVE_TEX: Texture2D = preload("res://world/scenery/painted/player_mg2_4.png")
## 主人公の絵の高さ（基準画面で。下は画面の外へはみ出す）、頭のまん中の高さ（絵の高さに対する割合）、
## からだのまん中の横の位置（絵の幅に対する割合）
const ME_H := 420.0
const ME_HEAD_Y := 0.2
const ME_FOOT_X := 0.5
const ME_WAVE_FOOT_X := 0.34

var hud: Hud
var phase := Phase.LOOK
## 窓の開き（0〜1）
var open := 0.0
## 受け止めたか（帽子が届くまでは false）
var caught := false
## 帽子が届いたか
var landed := false
## さけび返した回数
var shouts := 0
## タケルの遠さ（0 窓のすぐ外 → 1 カーブの向こう）
var away := 0.0
var _t := 0.0
var _speed := 1.0
var _hat_u := 0.0
var _wave_t := 0.0
var _promised := false
var _last_said := false
var _flow := 0.0
## バスのゆれの時計
var _sway_t := 0.0
var _prev_ambient := ""
var _hold: HoldInput
var _chip: PanelContainer
var _line: Label
var _hint: Label


func _ready() -> void:
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
	# 案内（エンディングの直前なので、最小限に）
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
	InputMode.mode_changed.connect(_refresh_hint.unbind(1))
	get_tree().call_group("touch_controls", "set_suppressed", true)
	# 窓が開く前は、バスの中のこもった音
	_prev_ambient = SfxPlayer._ambient_name
	SfxPlayer.set_ambient(AMBIENT_INSIDE)
	SfxPlayer.play("bike_bell")
	modulate.a = 0.0
	UiAnim.fade(self, 1.0, UiTokens.TIME_FADE)


func _exit_tree() -> void:
	get_tree().call_group("touch_controls", "set_suppressed", false)
	SfxPlayer.set_ambient_volume(0.0)
	SfxPlayer.set_ambient(_prev_ambient)


## 上の小札にひとことを出す。「ぼく：……」なら主人公のせりふ
func say(text: String) -> void:
	var who := hud.speaker_name() if hud else ""
	var colon := text.find("：")
	if colon > 0 and colon <= Hud.SPEAKER_MAX:
		who = text.substr(0, colon)
		text = text.substr(colon + 1)
	_line.text = Strings.SPEECH_FORMAT % [who, text]
	if _chip.modulate.a < 1.0:
		UiAnim.fade(_chip, 1.0, UiTokens.TIME_SMALL)


func _refresh_hint() -> void:
	var touch := InputMode.touch
	var text := ""
	match phase:
		Phase.OPEN:
			text = Strings.HAT_OPEN_TOUCH if touch else Strings.HAT_OPEN_KEY
		Phase.THROW:
			text = Strings.HAT_TAP_TOUCH if touch else Strings.HAT_TAP_KEY
		Phase.WAVE:
			if _promised and shouts < Strings.HAT_SHOUTS.size():
				text = Strings.HAT_WAVE_TOUCH if touch else Strings.HAT_WAVE_KEY
	_hint.text = text
	UiAnim.fade(_hint.get_meta("chip"), 1.0 if text != "" else 0.0, UiTokens.TIME_SMALL)


# --- 進み ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var d := delta * _speed
	_t += d
	_wave_t = maxf(_wave_t - d, 0.0)
	# 窓の外を、通りすぎてきた景色が流れていく
	_flow += d * (0.6 if phase < Phase.CURVE else 0.25)
	_sway_t += d
	match phase:
		Phase.LOOK:
			if _t >= LOOK_TIME:
				say(Strings.HAT_CALL)
				_go(Phase.OPEN)
				_hold.enabled = true
		Phase.OPEN:
			if _hold.is_down:
				open = minf(open + d / OPEN_TIME, 1.0)
				# 開くにつれて、風・蝉・エンジン・タケルの声が大きくなる
				if open > 0.3 and SfxPlayer._ambient_name != AMBIENT_OUTSIDE:
					SfxPlayer.set_ambient(AMBIENT_OUTSIDE)
				SfxPlayer.set_ambient_volume(lerpf(-14.0, 0.0, open))
				if fmod(_t, 0.25) < d:
					SfxPlayer.play("window_rattle")
				if open >= 1.0:
					_throw()
		Phase.THROW:
			_hat_u = minf(_hat_u + d / HAT_TIME, 1.0)
			if _hat_u >= 1.0:
				_land()
		Phase.CATCH:
			if caught and _t >= SLOW_TIME:
				_speed = 1.0
			if _t >= CUT_TIME:
				_go(Phase.WAVE)
		Phase.WAVE:
			if not _promised:
				_promised = true
				say(Strings.HAT_PROMISE)
				_hold.enabled = true
				_refresh_hint()
			# タケルは自転車を止め、だんだん小さくなっていく
			away = minf(away + d / RECEDE_TIME, 1.0)
			if away >= LAST_LINE_AT and not _last_said:
				_last_said = true
				var last := last_line()
				if last != "":
					say(last)
			if away >= 1.0:
				_go(Phase.CURVE)
				_hold.enabled = false
				# カーブを曲がったら、風の音だけが残る
				SfxPlayer.set_ambient(AMBIENT_WIND)
		Phase.CURVE:
			if _t >= CURVE_TIME + END_TIME:
				_finish()
	queue_redraw()


func _go(p: Phase) -> void:
	phase = p
	_t = 0.0
	_refresh_hint()


## タケルが片手で帽子を投げる。帽子はタップで受け止める（押しつづけの入力はここで止める）
func _throw() -> void:
	_hold.release()
	_hold.enabled = false
	_go(Phase.THROW)
	_hat_u = 0.0
	SfxPlayer.play("hat_throw")


## 帽子がつかめるところまで来たか
func catchable() -> bool:
	return phase == Phase.THROW and _hat_u >= CATCH_FROM


## タップした場所で帽子をつかむ（帽子の近くなら受け止める。自動の動作確認からも呼べる）
func tap_at(pos: Vector2) -> void:
	if catchable() and pos.distance_to(_hat_pos()) <= HAT_HIT_RADIUS * size.y / 720.0:
		_receive(true)


## 帽子がとどいた。受け止める（両手でつかむカット）か、顔に当たってひざに乗る（ひざのカット）
func _receive(c: bool) -> void:
	if landed:
		return
	landed = true
	caught = c
	if caught:
		SfxPlayer.play("hat_catch")
		_speed = SLOW
		# 寄りのカットでは、前のかけ声を消して静かに見せる
		UiAnim.fade(_chip, 0.0, UiTokens.TIME_SMALL_OUT)
	else:
		SfxPlayer.play("hat_face")
		say(Strings.HAT_SMELLY)
	GameState.set_hat_result(caught)
	_go(Phase.CATCH)


## つかめないまま届いた：顔にぽふっと当たって、ひざに乗る
func _land() -> void:
	_receive(false)


## 石切りの記録から、小さくなっていくタケルが足す最後の一言（記録がなければ言わない）
static func last_line() -> String:
	match GameState.ishikiri_result:
		&"lose":
			return Strings.HAT_LAST_LOSE
		&"win", &"draw":
			return Strings.HAT_LAST_WIN
	return ""


func _on_pressed() -> void:
	if phase == Phase.WAVE and shouts < Strings.HAT_SHOUTS.size():
		# 窓から手をふって、さけび返す
		say(Strings.HAT_SHOUTS[shouts])
		shouts += 1
		_wave_t = 0.6
		SfxPlayer.play("shout")
		if shouts >= Strings.HAT_SHOUTS.size():
			_refresh_hint()


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
	if phase == Phase.THROW:
		# 帽子を直接タップ（クリック）するか、近づいたら決定キーで受け止める
		if event is InputEventScreenTouch and event.pressed:
			tap_at(event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
				and event.device != InputEvent.DEVICE_ID_EMULATION:
			tap_at(event.position)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			if catchable():
				_receive(true)
			get_viewport().set_input_as_handled()
		return
	# 振り返るところと、カーブのあとは早送りできる
	if phase in [Phase.LOOK, Phase.CURVE]:
		var tap: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_speed = UiTokens.SKIP_SPEED
			get_viewport().set_input_as_handled()


# --- 場所 ---------------------------------------------------------------------
# 背景は水彩の絵（いちばん後ろの席から見た、バスの大きな後ろの窓）。窓や道の場所は、絵の中の割合（0〜1）で持つ

## 絵の中の窓のあき（内がわ。わくの内のふち）と、角の丸み（絵の px）
const WIN_A := Vector2(0.119, 0.121)
const WIN_B := Vector2(0.877, 0.748)
const WIN_ROUND := 26.0
## 絵の中の道：窓の下のふちでの道のまん中と、消えていく点
const ROAD_NEAR := Vector2(0.516, 0.748)
const ROAD_FAR := Vector2(0.505, 0.566)
## 窓の下のふちでの、道の半分の幅（絵の px）
const ROAD_HALF := 118.0
## 絵をひと回り大きく敷く割合（バスのゆれで、はしが見えないように）
const VIEW_MARGIN := 0.03
## 振り返るときの、横に流れこむ分（画面の幅に対して）
const LOOK_PAN := 0.06


## 絵を敷く四角。振り返るときは横から流れこみ、走っているあいだはバスといっしょに小さくゆれる
func _view_rect() -> Rect2:
	var s := size
	if UiAnim.reduced():
		return Rect2(Vector2.ZERO, s)
	var turn := smoothstep(0.0, 1.0, _t / LOOK_TIME) if phase == Phase.LOOK else 1.0
	var z := 1.0 + VIEW_MARGIN + (1.0 - turn) * LOOK_PAN * 2.0
	var r := Rect2(-s * (z - 1.0) * 0.5, s * z)
	r.position.x += (1.0 - turn) * s.x * LOOK_PAN
	# 止まりかけ（カーブのあと）は、ゆれも小さく
	var amp := 0.4 if phase >= Phase.CURVE else 1.0
	r.position += Vector2(sin(_sway_t * 0.9) * 1.5, sin(_sway_t * 2.3) * 2.2 + sin(_sway_t * 5.1) * 0.6) * amp * s.y / 720.0
	return r


## 絵の 1px が画面で何 px になるか
func _img_scale() -> float:
	var r := _view_rect()
	var ts := BG.get_size()
	return maxf(r.size.x / ts.x, r.size.y / ts.y)


## 絵の中の割合の点を、画面の位置にする（MinigameBg.draw_cover と同じ切り取り方）
func _img(f: Vector2) -> Vector2:
	var r := _view_rect()
	var ts := BG.get_size()
	var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
	var src_pos := (ts - r.size / k) * 0.5
	return r.position + (f * ts - src_pos) * k


## 窓（画面の中の四角。絵の窓のあきに重なる）
func _window_rect() -> Rect2:
	var a := _img(WIN_A)
	return Rect2(a, _img(WIN_B) - a)


## 窓のあきの形（角の丸い四角）。窓の外に描くものは、これで切り取る
func _window_poly() -> PackedVector2Array:
	var w := _window_rect()
	var r := WIN_ROUND * _img_scale()
	var pts := PackedVector2Array()
	var corners := [w.position + Vector2(r, r), Vector2(w.end.x - r, w.position.y + r), w.end - Vector2(r, r), Vector2(w.position.x + r, w.end.y - r)]
	for i in 4:
		for j in 5:
			var ang := PI + i * PI * 0.5 + j * PI * 0.125
			pts.append(corners[i] + Vector2(cos(ang), sin(ang)) * r)
	return pts


## 窓のあきの中だけに、多角形をぬる
func _fill_in_window(poly: PackedVector2Array, c: Color) -> void:
	for piece in Geometry2D.intersect_polygons(poly, _window_poly()):
		if piece.size() >= 3:
			draw_colored_polygon(piece, c)


## 道の上の点。depth は 1 で窓の下のふち、0 に近づくほど消えていく点へ。side は道の幅に対する横の位置（-1〜1）
func _road_at(depth: float, side := 0.0) -> Vector2:
	var near := _img(ROAD_NEAR)
	var far := _img(ROAD_FAR)
	return far.lerp(near, depth) + Vector2(side * ROAD_HALF * _img_scale() * depth, 0)


## タケルの道の上の深さ（遠いほど消えていく点の近く）
func _takeru_depth() -> float:
	return lerpf(0.97, 0.08, smoothstep(0.0, 1.0, away))


## タケルの位置と大きさ（遠いほど消えていく点の近く、小さく）。道の、こちらから見て右よりを走ってくる
func _takeru_pos() -> Vector2:
	return _road_at(_takeru_depth(), 0.3)


func _takeru_scale() -> float:
	# 窓の下のふちでの大きさは、基準画面（1280×720）で 1
	return _takeru_depth() * _img_scale() * 528.0 / 720.0


## 主人公の顔（窓のそば、画面の左下）
func _face_pos() -> Vector2:
	var w := _window_rect()
	return Vector2(w.position.x + w.size.x * 0.12, w.end.y + size.y * 0.06)


## 帽子の位置：投げた手から窓をくぐって主人公の顔へ、風にあおられながら
func _hat_pos() -> Vector2:
	var u := _hat_u
	var from := _takeru_pos() + TAKERU_HAND * _takeru_scale()
	var to := _face_pos()
	var ctrl := from.lerp(to, 0.5) + Vector2(0, -size.y * 0.3)
	var p := from.lerp(ctrl, u).lerp(ctrl.lerp(to, u), u)
	if not UiAnim.reduced():
		p += Vector2(sin(u * 9.0) * 28.0, cos(u * 7.0) * 12.0) * (1.0 - u)
	return p


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	# 受け止めた／ひざに乗った寄りのカット
	if phase == Phase.CATCH:
		if caught:
			_draw_catch_cut(s)
		else:
			_draw_lap_cut(s)
		return
	# バスの後ろの窓と、その向こうの道（水彩の絵）
	MinigameBg.draw_cover(self, BG, _view_rect())
	var w := _window_rect()
	# 窓の外：遠ざかっていく道と、追いかけてくるタケル
	_draw_outside()
	# カーブで、景色が木にさえぎられる（窓のあきの中だけ）
	if phase in [Phase.CURVE, Phase.DONE]:
		var k := smoothstep(0.0, 1.0, minf(_t / CURVE_TIME, 1.0))
		var tx := w.end.x - k * (w.size.x + w.size.y * 0.9)
		var u := w.size.y / 450.0
		# 水彩の絵に合わせて、すこし透けた緑を重ねる
		var greens := [Color("#3F6B45"), Color("#5E8B4E"), Color("#7FA65A")]
		for i in 8:
			var x := tx + i * 70.0 * u
			var top := w.position.y + (50 + (i % 3) * 40) * u
			_fill_in_window(_rect_poly(Rect2(x + 8 * u, top, 12 * u, w.size.y)), Color("#6B5A48", 0.85))
			for j in 3:
				var c: Vector2 = Vector2(x + 14 * u + (j - 1) * 34 * u, top + (j % 2) * 40 * u - 10 * u)
				_fill_in_window(_circle_poly(c, (68 + j * 10) * u), Color(greens[(i + j) % 3], 0.72))
	# 窓ガラス（開くほど下がる）
	var shake := 0.0
	if phase == Phase.OPEN and _hold.is_down and not UiAnim.reduced():
		shake = sin(_t * 70.0) * 2.0
	var pane_h := w.size.y * (1.0 - open)
	if pane_h > 1.0:
		var top := w.end.y - pane_h + shake
		_fill_in_window(_rect_poly(Rect2(w.position.x, top, w.size.x, pane_h + 4.0)), Color(P.BUS_WINDOW.darkened(0.35), 0.32))
		# ガラスの映りこみ
		for i in 3:
			var x0 := w.position.x + w.size.x * (0.15 + 0.3 * i)
			var y1 := w.end.y
			var band := w.size.x * 0.035
			_fill_in_window(PackedVector2Array([Vector2(x0, top), Vector2(x0 + band, top),
				Vector2(x0 + band - (y1 - top) * 0.4, y1), Vector2(x0 - (y1 - top) * 0.4, y1)]), Color(1, 1, 1, 0.13))
		# ガラスの上のふち（金具）
		draw_line(Vector2(w.position.x + 6, top), Vector2(w.end.x - 6, top), Color(P.BUS_STRIPE.darkened(0.45), 0.85), 4.0 * s.y / 720.0)
	# 主人公（窓のそば）
	_draw_me(s)
	# 飛んでくる帽子
	if phase == Phase.THROW:
		var rot := 0.0 if UiAnim.reduced() else _hat_u * TAU * 1.5
		var hp := _hat_pos()
		# 近づいてきたら、つかめる合図のうすい輪（押せる範囲）
		if catchable():
			draw_arc(hp, HAT_HIT_RADIUS * s.y / 720.0 * 0.6, 0, TAU, 32, Color(UiTokens.ACCENT_INK, 0.7), 3.0)
		_draw_hat(hp, rot, 1.0)


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _circle_poly(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(c + Vector2.from_angle(i * TAU / 20.0) * r)
	return pts


## 窓の外：道のまん中のうすい白線が、消えていく点へ流れていく（走っている感じ）。そして追いかけてくるタケル
func _draw_outside() -> void:
	var f := 0.0 if UiAnim.reduced() else _flow
	var k := _img_scale()
	for i in 9:
		# z は遠さ（0 が窓の下のふち）。間かくは道の上で同じ
		var z := (float(i) + fposmod(f * 1.2, 1.0)) * 0.9
		var d0 := 1.0 / (1.0 + z)
		var d1 := 1.0 / (1.0 + z + 0.4)
		var a := _road_at(d0)
		var b := _road_at(d1)
		var hw0 := 3.0 * k * d0
		var hw1 := 3.0 * k * d1
		_fill_in_window(PackedVector2Array([a + Vector2(-hw0, 0), a + Vector2(hw0, 0), b + Vector2(hw1, 0), b + Vector2(-hw1, 0)]),
			Color(1.0, 0.99, 0.95, 0.75 * sqrt(d0)))
	if phase == Phase.LOOK and _t < LOOK_TIME * 0.5:
		return
	# カーブの木が通りすぎたら、もうタケルは見えない
	if phase == Phase.DONE or (phase == Phase.CURVE and _t > CURVE_TIME * 0.5):
		return
	_draw_bike(_takeru_pos(), _takeru_scale())


## 自転車のタケル（ちかいときは大きく、遠ざかると小さく）。こいで追いかける→帽子をふりかぶる→投げたあと
func _draw_bike(pos: Vector2, k: float) -> void:
	var i := _takeru_pose()
	var tex: Texture2D = TAKERU_TEX[i]
	# 絵の px をそろえて、どのポーズでも頭の大きさが同じになるように
	var f := TAKERU_H / TAKERU_REF_H * k
	var sz := tex.get_size() * f
	var rot := 0.0
	if phase < Phase.WAVE and not UiAnim.reduced():
		# 立ちこぎで、左右に小さくゆれる
		pos.y -= absf(sin(_t * 10.0)) * 2.0 * k
		rot = sin(_t * 10.0) * 0.03
	var xf := Transform2D(rot, pos)
	_draw_tex_in_window(tex, xf, Rect2(-sz.x * TAKERU_FOOT_X[i], -sz.y, sz.x, sz.y))


## タケルのポーズ（0 こいでいる、1 帽子をふりかぶる、2 投げたあと）
func _takeru_pose() -> int:
	if phase >= Phase.THROW:
		return 2
	if phase == Phase.OPEN and open >= WINDUP_AT:
		return 1
	return 0


## 絵（テクスチャ）を、窓のあきの中だけに描く。xf は画面への置き方、r はその中での絵の四角
func _draw_tex_in_window(tex: Texture2D, xf: Transform2D, r: Rect2) -> void:
	var inv := xf.affine_inverse()
	for piece in Geometry2D.intersect_polygons(xf * _rect_poly(r), _window_poly()):
		if piece.size() < 3:
			continue
		var uvs := PackedVector2Array()
		for q in piece:
			uvs.append(((inv * q) - r.position) / r.size)
		draw_colored_polygon(piece, Color.WHITE, uvs, tex)


## 窓のそばの主人公（うしろ姿）。ふだんは座って窓の外を見ている。手をふる場面では片手を上げる
func _draw_me(s: Vector2) -> void:
	var waving := phase == Phase.WAVE
	var tex: Texture2D = ME_WAVE_TEX if waving else ME_TEX
	var h := ME_H * s.y / 720.0
	var sz := tex.get_size() * h / tex.get_size().y
	# 頭（帽子）のまん中が _face_pos にくるように。下のはしは画面の外へ
	var foot := _face_pos() + Vector2(0, h * (1.0 - ME_HEAD_Y))
	var rot := 0.0
	if waving and _wave_t > 0.0 and not UiAnim.reduced():
		# さけぶたびに、からだごと小さくゆれる
		rot = sin(_wave_t * 20.0) * 0.03
	draw_set_transform(foot, rot)
	draw_texture_rect(tex, Rect2(-sz.x * (ME_WAVE_FOOT_X if waving else ME_FOOT_X), -sz.y, sz.x, sz.y), false)
	draw_set_transform(Vector2.ZERO)


## 受け止めたカット：窓の外の空を背に、両手で帽子をつかむ（少しずつ寄る）
func _draw_catch_cut(s: Vector2) -> void:
	var zoom := 1.0 if UiAnim.reduced() else lerpf(0.92, 1.0, minf(_t / CUT_TIME, 1.0))
	# 背は、窓の外の夏の空と田んぼ（絵の窓のあきの中を、大きく寄せて敷く）
	_draw_crop(s, Vector2(0.5, 0.4), 0.54)
	draw_rect(Rect2(0, s.y * 0.84, s.x, s.y * 0.16), Color("#4A2E2A"))
	var c := s * 0.5 + Vector2(0, s.y * 0.04)
	var k := s.y / 720.0 * zoom
	_draw_hat(c, -0.05, 4.5 * zoom)
	# 両手（左右から帽子のふちをつかむ。帽子の絵の左右のはしは、中心から 14×4.5×1.6 ≒ 100px）
	for side in [-1.0, 1.0]:
		var hand: Vector2 = c + Vector2(side * 98.0, -20.0) * k
		var wrist: Vector2 = hand + Vector2(side * 40.0, 260.0) * k
		draw_line(wrist, hand, P.PLAYER_SKIN, 40.0 * k)
		draw_circle(hand, 30 * k, P.PLAYER_SKIN)


## ひざのカット：顔に当たって落ちた帽子が、ひざの上に乗っている
func _draw_lap_cut(s: Vector2) -> void:
	# 背は、緑の座席（絵の下の背もたれを、大きく寄せて敷く）
	_draw_crop(s, Vector2(0.44, 0.9), 0.18)
	var k := s.y / 720.0
	var c := Vector2(s.x * 0.5, s.y * 0.62)
	# ひざ（半ズボン）と足
	for side in [-1.0, 1.0]:
		var knee: Vector2 = c + Vector2(side * 110.0, 0) * k
		draw_rect(Rect2(knee.x - 90 * k, knee.y - 70 * k, 180 * k, 120 * k), P.PLAYER_SHORTS)
		draw_rect(Rect2(knee.x - 60 * k, knee.y + 50 * k, 120 * k, s.y), P.PLAYER_SKIN)
	# ひざに乗った帽子（落ちてきて、少しはずむ）
	var drop := 0.0 if UiAnim.reduced() else maxf(0.0, 1.0 - _t / 0.4) * -60.0 * k
	_draw_hat(c + Vector2(10, -70 * k + drop), 0.15, 3.0)


## 寄りのカットの背：絵の一部（中心 c、高さ h。どちらも絵の中の割合）を、画面いっぱいに大きく敷く
func _draw_crop(s: Vector2, c: Vector2, h: float) -> void:
	var ts := BG.get_size()
	var src := Vector2(ts.y * h * s.x / s.y, ts.y * h)
	draw_texture_rect_region(BG, Rect2(Vector2.ZERO, s), Rect2(c * ts - src * 0.5, src))


func _draw_hat(p: Vector2, rot: float, k: float) -> void:
	var it := GameState.find_item(&"takeru_hat")
	var c := it.placeholder_color if it else P.BUS_STRIPE
	draw_set_transform(p, rot, Vector2(k, k) * maxf(size.y / 720.0, 0.6) * 1.6)
	if it and it.icon:
		draw_texture_rect(it.icon, Rect2(-20, -26, 40, 40), false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_rect(Rect2(-14, -10, 28, 12), c)
	draw_rect(Rect2(6, -2, 16, 5), c.darkened(0.2))
	draw_set_transform(Vector2.ZERO)
