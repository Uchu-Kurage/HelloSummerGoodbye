class_name BusWindow
extends NatsumiScreen
## 場面「バスの窓」（10日目、ノーマルルート）。会話の @game bus_window で始まる。
## 走り出したバスのうしろの窓から、バス停で手をふる祖父母が、だんだん小さくなっていくのを見る。
## タップ（Space）で手をふりかえす。見えなくなったら「タップで まえを むく」で閉じる。失敗はない。

enum Phase { LOOK, GONE, END }

## 祖父母が見えなくなるまでの時間（秒）
const AWAY_TIME := 7.0
## 手をふりかえす動きの長さ
const WAVE_TIME := 0.8
const P := preload("res://world/world_palette.gd")
const GRANDPA_TEX: Texture2D = preload("res://world/scenery/painted/npc_grandpa.png")
const GRANDMA_TEX: Texture2D = preload("res://world/scenery/painted/npc_grandma.png")
const BUS_STOP_TEX: Texture2D = preload("res://world/scenery/painted/prop_busstop.png")

var phase := Phase.LOOK
## 手をふりかえした回数
var waves := 0
var _t := 0.0
var _wave_t := -1.0
var _said_small := false


func _build() -> void:
	set_ambient("bus_inside")
	caption(Strings.BUSWIN_CAPTION)
	show_hint(Strings.BUSWIN_WAVE_TOUCH, Strings.BUSWIN_WAVE_KEY)


## 手をふりかえす（自動の動作確認からも呼べる）
func wave() -> void:
	if phase != Phase.LOOK:
		return
	waves += 1
	_wave_t = 0.0


## 遠ざかりぐあい（0.0 バス停のすぐ前 → 1.0 見えなくなる）
func away() -> float:
	return clampf(_t / AWAY_TIME, 0.0, 1.0)


func can_close() -> bool:
	return phase == Phase.GONE


func _process(delta: float) -> void:
	_t += delta * speed
	if _wave_t >= 0.0:
		_wave_t += delta
		if _wave_t >= WAVE_TIME:
			_wave_t = -1.0
	if phase == Phase.LOOK:
		if not _said_small and away() >= 0.5:
			_said_small = true
			caption(Strings.BUSWIN_SMALL)
		if away() >= 1.0:
			phase = Phase.GONE
			caption(Strings.BUSWIN_GONE)
			show_hint(Strings.BUSWIN_CLOSE_TOUCH, Strings.BUSWIN_CLOSE_KEY)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_tap(event):
		return
	get_viewport().set_input_as_handled()
	match phase:
		Phase.LOOK:
			# 手をふりかえすと、景色も少し早く流れる（早送り）
			wave()
			speed = minf(speed * 1.5, UiTokens.SKIP_SPEED)
		Phase.GONE:
			close_view()


## 見えなくなったあと、まえを向いて閉じる（自動の動作確認からも呼べる）
func close_view() -> void:
	if phase != Phase.GONE:
		return
	phase = Phase.END
	hide_hint()
	finish()


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	# 車内（窓のまわり）
	draw_rect(Rect2(Vector2.ZERO, s), P.BUSWIN_FRAME)
	var win := Rect2(s.x * 0.12, s.y * 0.16, s.x * 0.76, s.y * 0.56)
	# 窓の外：朝の空、田んぼ、遠ざかる道（消える点は窓の上のほう）
	draw_rect(win, P.BUSWIN_SKY)
	var horizon := win.position.y + win.size.y * 0.42
	draw_rect(Rect2(win.position.x, horizon, win.size.x, win.end.y - horizon), P.BUSWIN_FIELD)
	var vp := Vector2(win.position.x + win.size.x * 0.5, horizon)
	draw_colored_polygon(PackedVector2Array([vp + Vector2(-6, 0), vp + Vector2(6, 0),
		Vector2(win.position.x + win.size.x * 0.82, win.end.y), Vector2(win.position.x + win.size.x * 0.18, win.end.y)]), P.BUSWIN_ROAD)
	# 田んぼのすじ（流れていく）
	var c := clock() * speed
	for i in 6:
		var f := fposmod(i / 6.0 + c * 0.15, 1.0)
		var y := lerpf(horizon, win.end.y, f * f)
		draw_line(Vector2(win.position.x, y), Vector2(win.end.x, y), P.PADDY_ROW, 1.0 + 2.0 * f)
	# バス停と、手をふる祖父母（遠ざかるほど小さく、消える点へ近づく）
	var k := 1.0 - away()
	var sc := lerpf(0.03, 1.0, k * (0.4 + 0.6 * k))
	var foot := Vector2(vp.x, lerpf(horizon, win.end.y - 10.0, sc))
	var h := win.size.y * 0.5 * sc
	if sc > 0.03:
		_art(BUS_STOP_TEX, foot + Vector2(h * 0.9, 0), h * 0.9, Color(1, 1, 1, 0.9))
		var bob := 0.0 if UiAnim.reduced() else sin(clock() * 6.0) * h * 0.03
		_art(GRANDPA_TEX, foot + Vector2(-h * 0.22, bob), h)
		_art(GRANDMA_TEX, foot + Vector2(h * 0.22, -bob), h * 0.86)
		# ふっている手（小さな丸がゆれる）
		if not UiAnim.reduced():
			for side in [-1.0, 1.0]:
				var hand := foot + Vector2(side * h * 0.22, -h * 0.95) + Vector2(sin(clock() * 7.0 + side) * h * 0.08, 0)
				draw_circle(hand, maxf(1.5, h * 0.04), P.PLAYER_SKIN)
	# 窓ガラスの反射と、窓わく
	draw_rect(win, Color(P.BUS_WINDOW, 0.18))
	draw_rect(win, P.BUSWIN_FRAME.darkened(0.2), false, 10.0)
	# 手をふりかえす、ぼくの手（窓の下から）
	if _wave_t >= 0.0:
		var a := sin(_wave_t / WAVE_TIME * PI)
		var hand := Vector2(win.position.x + win.size.x * 0.3 + sin(_wave_t * 18.0) * 14.0, win.end.y - 70.0 * a)
		draw_circle(hand, 26, P.PLAYER_SKIN)
		draw_rect(Rect2(hand.x - 16, hand.y, 32, s.y), P.PLAYER_BODY)


func _art(tex: Texture2D, foot: Vector2, h: float, tint := Color.WHITE) -> void:
	var w := tex.get_width() * h / tex.get_height()
	draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false, tint)
