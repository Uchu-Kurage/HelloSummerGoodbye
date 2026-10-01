class_name UiAnim
## UI の出入りの動き（スキル「5. 動き」）。時間は UiTokens の定数だけを使う。

const T := preload("res://ui/ui_tokens.gd")


## パネルを開く：フェード＋わずかな拡大（0.96→1.0）
static func panel_in(c: Control, duration: float = T.TIME_PANEL) -> Tween:
	c.show()
	c.pivot_offset = c.size / 2.0
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * T.PANEL_SCALE_FROM
	var tw := c.create_tween().set_parallel().set_trans(T.TRANS).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration)
	tw.tween_property(c, "scale", Vector2.ONE, duration)
	return tw


static func panel_out(c: Control, duration: float = T.TIME_PANEL) -> Tween:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_parallel().set_trans(T.TRANS).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, duration)
	tw.tween_property(c, "scale", Vector2.ONE * T.PANEL_SCALE_FROM, duration)
	tw.chain().tween_callback(c.hide)
	return tw


## 小さな表示：少し上へ浮きながらフェード。base はもとの位置
static func float_in(c: Control, base: Vector2) -> Tween:
	c.show()
	c.modulate.a = 0.0
	c.position = base + Vector2(0, T.FLOAT_DISTANCE)
	var tw := c.create_tween().set_parallel().set_trans(T.TRANS).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, T.TIME_SMALL)
	tw.tween_property(c, "position", base, T.TIME_SMALL)
	return tw


static func float_out(c: CanvasItem) -> Tween:
	var tw := c.create_tween().set_trans(T.TRANS).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, T.TIME_SMALL)
	tw.tween_callback(c.hide)
	return tw


static func fade(c: CanvasItem, to: float, duration: float = T.TIME_FADE) -> Tween:
	if to > 0.0:
		c.show()
	var tw := c.create_tween().set_trans(T.TRANS).set_ease(Tween.EASE_OUT if to > c.modulate.a else Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", to, duration)
	if to <= 0.0:
		tw.tween_callback(c.hide)
	return tw


## 押した瞬間に少し沈む（スキル「6. 操作 タッチ」）
static func add_press_feedback(b: BaseButton) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func():
		var tw := b.create_tween().set_trans(T.TRANS).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE * 0.95, T.TIME_PRESS))
	b.button_up.connect(func():
		var tw := b.create_tween().set_trans(T.TRANS).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, T.TIME_PRESS))


## 画面全体を SHADE で暗くする ColorRect（ぼかしは使わない）
static func make_shade() -> ColorRect:
	var r := ColorRect.new()
	r.name = "Shade"
	r.color = T.SHADE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## 画面端から SCREEN_MARGIN あけた全面の MarginContainer
static func make_safe_area() -> MarginContainer:
	var m := MarginContainer.new()
	m.name = "SafeArea"
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, T.SCREEN_MARGIN)
	return m
