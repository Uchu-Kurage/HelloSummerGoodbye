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

## 窓（画面の中の四角）
func _window_rect() -> Rect2:
	var s := size
	return Rect2(s.x * 0.12, s.y * 0.1, s.x * 0.76, s.y * 0.62)


## タケルの位置と大きさ（遠いほど坂の上、小さく）
func _takeru_pos() -> Vector2:
	var w := _window_rect()
	var k := smoothstep(0.0, 1.0, away)
	return Vector2(lerpf(w.position.x + w.size.x * 0.55, w.position.x + w.size.x * 0.3, k),
		lerpf(w.end.y - w.size.y * 0.05, w.position.y + w.size.y * 0.55, k))


func _takeru_scale() -> float:
	return lerpf(1.0, 0.22, smoothstep(0.0, 1.0, away)) * size.y / 720.0


## 主人公の顔（窓のそば、画面の左下）
func _face_pos() -> Vector2:
	var w := _window_rect()
	return Vector2(w.position.x + w.size.x * 0.12, w.end.y + size.y * 0.06)


## 帽子の位置：投げた手から窓をくぐって主人公の顔へ、風にあおられながら
func _hat_pos() -> Vector2:
	var u := _hat_u
	var from := _takeru_pos() + Vector2(10, -150) * _takeru_scale()
	var to := _face_pos()
	var ctrl := from.lerp(to, 0.5) + Vector2(0, -size.y * 0.3)
	var p := from.lerp(ctrl, u).lerp(ctrl.lerp(to, u), u)
	if not UiAnim.reduced():
		p += Vector2(sin(u * 9.0) * 28.0, cos(u * 7.0) * 12.0) * (1.0 - u)
	return p


# --- 絵 -----------------------------------------------------------------------

func _draw() -> void:
	var s := size
	var w := _window_rect()
	# 受け止めた／ひざに乗った寄りのカット
	if phase == Phase.CATCH:
		if caught:
			_draw_catch_cut(s)
		else:
			_draw_lap_cut(s)
		return
	# 後ろを振り返る：前を向いた車内から、窓の外の景色が横に流れこんでくる
	var turn := smoothstep(0.0, 1.0, _t / LOOK_TIME) if phase == Phase.LOOK else 1.0
	var shift := (1.0 - turn) * s.x * 0.6
	# 窓の外
	_draw_outside(w, shift)
	# カーブで、景色が木にさえぎられる
	if phase in [Phase.CURVE, Phase.DONE]:
		var k := smoothstep(0.0, 1.0, minf(_t / CURVE_TIME, 1.0))
		var tx := w.end.x - k * (w.size.x + 120)
		for i in 6:
			var x := tx + i * 70.0
			draw_rect(Rect2(x, w.position.y, 26, w.size.y), P.WOODS_TRUNK)
			draw_circle(Vector2(x + 13, w.position.y + 30 + (i % 2) * 40), 70, P.WOODS_DARK if i % 2 == 0 else P.NEAR_BUSH)
	# 窓ガラス（開くほど下がる）
	var shake := 0.0
	if phase == Phase.OPEN and _hold.is_down and not UiAnim.reduced():
		shake = sin(_t * 70.0) * 2.0
	var pane_h := w.size.y * (1.0 - open)
	if pane_h > 1.0:
		draw_rect(Rect2(w.position.x, w.position.y + shake, w.size.x, pane_h), Color(P.BUS_WINDOW.darkened(0.3), 0.6))
		# ガラスの映りこみ
		for i in 3:
			var x0 := w.position.x + w.size.x * (0.15 + 0.3 * i)
			var y1 := w.position.y + shake + pane_h
			draw_line(Vector2(x0, w.position.y + shake), Vector2(x0 - pane_h * 0.4, y1), Color(1, 1, 1, 0.18), 10.0)
		draw_line(Vector2(w.position.x, w.position.y + pane_h + shake), Vector2(w.end.x, w.position.y + pane_h + shake), P.BUS_STRIPE.darkened(0.2), 4.0)
	# 車内の壁と窓わく
	var wall := P.BUS_BODY.darkened(0.35)
	draw_rect(Rect2(0, 0, s.x, w.position.y), wall)
	draw_rect(Rect2(0, w.end.y, s.x, s.y - w.end.y), wall)
	draw_rect(Rect2(0, w.position.y, w.position.x, w.size.y), wall)
	draw_rect(Rect2(w.end.x, w.position.y, s.x - w.end.x, w.size.y), wall)
	draw_rect(w, P.BUS_STRIPE.darkened(0.25), false, 8.0)
	# 座席の背もたれ
	draw_rect(Rect2(s.x * 0.05, s.y * 0.82, s.x * 0.5, s.y * 0.2), P.BUS_STRIPE.darkened(0.1))
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


## 窓の外：後ろの坂道と、追いかけてきたタケル
func _draw_outside(w: Rect2, shift: float) -> void:
	draw_rect(w, Color("#A8D4EA"))
	var ground := w.position.y + w.size.y * 0.5
	draw_rect(Rect2(w.position.x, ground, w.size.x, w.end.y - ground), P.GROUND)
	# 坂道（窓のすぐ外から、左上の遠くへ）
	draw_colored_polygon(PackedVector2Array([
		Vector2(w.position.x + w.size.x * 0.25 + shift, w.end.y), Vector2(w.position.x + w.size.x * 0.85 + shift, w.end.y),
		Vector2(w.position.x + w.size.x * 0.34 + shift, ground), Vector2(w.position.x + w.size.x * 0.26 + shift, ground)]), P.ROAD)
	# 流れていく電柱と田んぼ（通りすぎてきた村）
	var f := 0.0 if UiAnim.reduced() else _flow
	for i in 5:
		var x := w.position.x + fposmod(i * w.size.x / 5.0 + f * 120.0 + shift, w.size.x)
		draw_line(Vector2(x, ground - w.size.y * 0.3), Vector2(x, ground + 6), P.POLE_FAR, 3.0)
	for i in 4:
		var y := ground + 12 + i * (w.end.y - ground) / 5.0
		draw_line(Vector2(w.position.x, y), Vector2(w.end.x, y), P.PADDY_ROW, 2.0)
	if phase == Phase.LOOK and _t < LOOK_TIME * 0.5:
		return
	# カーブの木が通りすぎたら、もうタケルは見えない
	if phase == Phase.DONE or (phase == Phase.CURVE and _t > CURVE_TIME * 0.5):
		return
	_draw_bike(_takeru_pos() + Vector2(shift, 0), _takeru_scale())


## 自転車のタケル（ちかいときは大きく、遠ざかると小さく）
func _draw_bike(pos: Vector2, k: float) -> void:
	var c := P.BIKE
	var skin := Color("#C68E62")
	var stopped := phase >= Phase.WAVE
	var bob := 0.0 if (stopped or UiAnim.reduced()) else absf(sin(_t * 10.0)) * 6.0 * k
	var rear := pos + Vector2(-44, -24) * k
	var front := pos + Vector2(44, -24) * k
	for wh in [rear, front]:
		draw_arc(wh, 24 * k, 0, TAU, 20, c, maxf(4.0 * k, 1.5))
	draw_line(rear, pos + Vector2(0, -40) * k, c, maxf(4.0 * k, 1.5))
	draw_line(pos + Vector2(0, -40) * k, front, c, maxf(4.0 * k, 1.5))
	var hip := pos + Vector2(-4, -88) * k + Vector2(0, -bob)
	draw_line(hip, pos + Vector2(6, -40) * k, skin, maxf(8.0 * k, 2.0))
	draw_rect(Rect2(hip.x - 14 * k, hip.y - 10 * k, 28 * k, 16 * k), Color("#3E5A7A"))
	var chest := hip + Vector2(14, -50) * k
	draw_line(hip, chest, Color("#E9E3D3"), maxf(22.0 * k, 4.0))
	var head := chest + Vector2(6, -22) * k
	draw_circle(head, 15 * k, skin)
	draw_arc(head, 13 * k, PI * 0.9, PI * 2.05, 12, Color("#211D1A"), maxf(7.0 * k, 2.0))
	# 投げるまでは帽子をかぶっている。止まったら、手をふる
	if phase in [Phase.LOOK, Phase.OPEN]:
		_draw_hat(head + Vector2(0, -12) * k, 0.0, k)
	var arm_up := stopped or phase == Phase.THROW
	var hand := chest + (Vector2(20, -46) if arm_up else Vector2(30, 0)) * k
	if stopped and not UiAnim.reduced():
		hand += Vector2(sin(_t * 8.0) * 10.0, 0) * k
	draw_line(chest, hand, skin, maxf(6.0 * k, 2.0))


## 窓のそばの主人公。帽子をかかえる／ひざに乗った帽子／手をふる
func _draw_me(s: Vector2) -> void:
	var face := _face_pos()
	var k := s.y / 720.0
	draw_rect(Rect2(face.x - 30 * k, face.y + 18 * k, 60 * k, s.y - face.y), P.PLAYER_BODY)
	draw_circle(face, 26 * k, P.PLAYER_SKIN)
	if landed and not caught:
		# ひざに乗った帽子
		_draw_hat(face + Vector2(30, 120) * k, 0.4, 1.0)
	if caught:
		# 帽子を胸にかかえる
		_draw_hat(face + Vector2(10, 70) * k, -0.1, 1.2)
	# 手をふる：顔の横で、窓のほうへ短く上げる
	if phase == Phase.WAVE and _wave_t > 0.0:
		var shoulder := face + Vector2(26, 34) * k
		var sway := 0.0 if UiAnim.reduced() else sin(_wave_t * 20.0) * 10.0
		var hand := face + Vector2(48 + sway, -36) * k
		draw_line(shoulder, hand, P.PLAYER_SKIN, 12.0 * k)
		draw_circle(hand, 11 * k, P.PLAYER_SKIN)


## 受け止めたカット：窓の外の空を背に、両手で帽子をつかむ（少しずつ寄る）
func _draw_catch_cut(s: Vector2) -> void:
	var zoom := 1.0 if UiAnim.reduced() else lerpf(0.92, 1.0, minf(_t / CUT_TIME, 1.0))
	draw_rect(Rect2(Vector2.ZERO, s), Color("#A8D4EA"))
	draw_rect(Rect2(0, s.y * 0.62, s.x, s.y * 0.38), P.GROUND)
	draw_rect(Rect2(0, s.y * 0.84, s.x, s.y * 0.16), P.BUS_BODY.darkened(0.35))
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
	draw_rect(Rect2(Vector2.ZERO, s), P.BUS_STRIPE.darkened(0.1))
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
