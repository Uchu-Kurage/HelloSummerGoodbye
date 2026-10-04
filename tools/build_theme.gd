extends SceneTree
## UiTokens の値から res://ui/theme/main_theme.tres を作り直すツール。
## 使い方: godot --headless --script res://tools/build_theme.gd
## 色や大きさを変えるときは、スキル → ui_tokens.gd → このツールの実行 の順で行う。

const OUT_PATH := "res://ui/theme/main_theme.tres"
const FONT_PATH := "res://ui/theme/fonts/ZenMaruGothic-Regular.ttf"
const T := preload("res://ui/ui_tokens.gd")


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font = load(FONT_PATH)
	theme.default_font_size = T.FONT_BODY

	_labels(theme)
	_panels(theme)
	_buttons(theme)

	var err := ResourceSaver.save(theme, OUT_PATH)
	print("saved theme: ", OUT_PATH, " err=", err)
	quit()


static func line_spacing(size: int) -> int:
	return roundi(size * (T.LINE_HEIGHT_RATIO - 1.0))


func _label(theme: Theme, name: String, size: int, color: Color) -> void:
	if name != "Label":
		theme.set_type_variation(name, "Label")
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)
	theme.set_constant("line_spacing", name, line_spacing(size))


func _labels(theme: Theme) -> void:
	_label(theme, "Label", T.FONT_BODY, T.INK)
	_label(theme, "HeadingLabel", T.FONT_HEADING, T.INK)
	_label(theme, "TitleLabel", T.FONT_TITLE, T.INK)
	_label(theme, "EndingTitleLabel", T.FONT_ENDING_TITLE, T.INK)
	_label(theme, "SmallLabel", T.FONT_SMALL, T.INK_SOFT)
	_label(theme, "SoftLabel", T.FONT_BODY, T.INK_SOFT)
	_label(theme, "AccentMarkLabel", T.FONT_SMALL, T.ACCENT_INK)
	_label(theme, "DateMonthLabel", T.FONT_SMALL, T.INK)
	_label(theme, "DateDayLabel", T.FONT_CARD_DAY, T.INK)
	theme.set_constant("line_spacing", "DateDayLabel", 0)
	_label(theme, "BigDateLabel", T.FONT_BIG_DATE, T.PAPER)
	_label(theme, "BigDateSubLabel", T.FONT_BODY, T.PAPER_DARK)
	_label(theme, "WorldSignLabel", T.FONT_BODY, T.INK)
	# 縦書きのタイトル（1文字ずつ改行して並べる。字間は詰める）
	# 空・缶・道の上の文字は INK_SOFT だとコントラストが足りないので INK を使う
	_label(theme, "OnTinSmallLabel", T.FONT_SMALL, T.INK)
	theme.set_constant("line_spacing", "RichTextLabel", line_spacing(T.FONT_BODY))


static func flat(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0,
		radius: int = T.PANEL_RADIUS, pad: int = T.PANEL_PADDING, shadow := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = T.SHADOW
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(0, T.SHADOW_OFFSET)
	return sb


func _panel(theme: Theme, name: String, base: String, sb: StyleBox) -> void:
	theme.set_type_variation(name, base)
	theme.set_stylebox("panel", name, sb)


func _panels(theme: Theme) -> void:
	_panel(theme, "PaperPanel", "PanelContainer",
		flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, T.PANEL_RADIUS, T.PANEL_PADDING, true))
	_panel(theme, "PaperInset", "PanelContainer",
		flat(T.PAPER_DARK, Color.TRANSPARENT, 0, T.PANEL_RADIUS, T.SPACE_S))
	_panel(theme, "TinPanel", "PanelContainer",
		flat(T.TIN, T.TIN_DARK, T.TIN_RIM, T.PANEL_RADIUS + T.TIN_RIM / 2, T.PANEL_PADDING, true))
	# 缶の中の紙の敷き紙（詳細の欄）
	_panel(theme, "TinLiner", "PanelContainer",
		flat(T.PAPER, Color.TRANSPARENT, 0, T.SMALL_RADIUS, T.PANEL_PADDING))
	# 世界の中の看板：影のない板
	_panel(theme, "SignBoard", "PanelContainer",
		flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, T.SMALL_RADIUS, T.SPACE_S))
	_panel(theme, "TinLid", "Panel",
		flat(T.TIN_DARK, T.TIN, T.TIN_RIM, T.PANEL_RADIUS + T.TIN_RIM / 2, 0, true))
	# 日めくりの札：上は SKY の帯、下は紙
	_panel(theme, "DateCard", "PanelContainer",
		flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, T.PANEL_RADIUS, 0, true))
	# とじ側の帯は紙の濃い色。下に SKY の細い線（夏の差し色）
	var top := flat(T.PAPER_DARK, T.SKY, 0, 0, T.SPACE_XS)
	top.border_width_bottom = 4
	top.corner_radius_top_left = T.PANEL_RADIUS - T.PANEL_BORDER
	top.corner_radius_top_right = T.PANEL_RADIUS - T.PANEL_BORDER
	top.content_margin_top = T.SPACE_S
	top.content_margin_bottom = 2
	_panel(theme, "DateCardTop", "PanelContainer", top)
	var body := StyleBoxEmpty.new()
	body.content_margin_left = T.SPACE_M
	body.content_margin_right = T.SPACE_M
	body.content_margin_top = T.SPACE_XS
	body.content_margin_bottom = T.SPACE_S
	_panel(theme, "DateCardBody", "PanelContainer", body)
	_panel(theme, "PlainPanel", "PanelContainer", StyleBoxEmpty.new())
	# 景色の上に置くメニューの小札（文字のコントラストを確保する。影なし）
	var chip := flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, T.SMALL_RADIUS, 0)
	chip.content_margin_left = T.SPACE_S
	chip.content_margin_right = T.SPACE_S
	_panel(theme, "PaperChip", "PanelContainer", chip)


func _button_colors(theme: Theme, name: String, color: Color, disabled: Color = T.INK_SOFT) -> void:
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(c, name, color)
	theme.set_color("font_disabled_color", name, disabled)


func _button(theme: Theme, name: String, normal: StyleBox, pressed: StyleBox, size: int, color: Color) -> void:
	if name != "Button":
		theme.set_type_variation(name, "Button")
	theme.set_stylebox("normal", name, normal)
	theme.set_stylebox("hover", name, normal)
	theme.set_stylebox("pressed", name, pressed)
	theme.set_stylebox("hover_pressed", name, pressed)
	theme.set_stylebox("disabled", name, normal)
	# フォーカスの印は MenuItem などのスクリプトが出す（タッチ中は出さない）
	theme.set_stylebox("focus", name, StyleBoxEmpty.new())
	theme.set_font_size("font_size", name, size)
	_button_colors(theme, name, color)


func _buttons(theme: Theme) -> void:
	var normal := flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, T.PANEL_RADIUS, T.SPACE_S)
	var pressed := flat(T.PAPER_DARK, T.PAPER_DARK, T.PANEL_BORDER, T.PANEL_RADIUS, T.SPACE_S)
	_button(theme, "Button", normal, pressed, T.FONT_BODY, T.INK)

	# メニュー項目：地なし、押した瞬間だけ紙の濃い色
	var mi := flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, T.PANEL_RADIUS, T.SPACE_S)
	mi.content_margin_left = T.SPACE_L
	mi.content_margin_right = T.SPACE_L
	var mi_p := mi.duplicate()
	mi_p.bg_color = T.PAPER_DARK
	_button(theme, "MenuItem", mi, mi_p, T.FONT_BODY, T.INK)
	_button(theme, "MenuItemSelected", mi, mi_p, T.FONT_BODY, T.ACCENT_INK)

	# 会話の選択肢：紙の上で押せると分かるよう、うすい枠のある小札にする
	var ch := flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, T.SMALL_RADIUS, T.SPACE_XS)
	ch.content_margin_left = T.SPACE_L
	ch.content_margin_right = T.SPACE_L
	var ch_p := ch.duplicate()
	ch_p.bg_color = T.PAPER_DARK
	var ch_s := ch.duplicate()
	ch_s.border_color = T.ACCENT_INK
	_button(theme, "ChoiceItem", ch, ch_p, T.FONT_BODY, T.INK)
	_button(theme, "ChoiceItemSelected", ch_s, ch_p, T.FONT_BODY, T.ACCENT_INK)

	# タッチ用のボタン（宝箱・ひとやすみ・もどる）
	_button(theme, "TouchButton", normal, pressed, T.FONT_SMALL, T.INK)

	# 拾う吹き出し
	_button(theme, "Bubble", flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, T.PANEL_RADIUS, T.SPACE_XS, true),
		flat(T.PAPER_DARK, T.PAPER_DARK, T.PANEL_BORDER, T.PANEL_RADIUS, T.SPACE_XS), T.FONT_BODY, T.INK)

	# 宝箱の枠：空はくぼみ（缶の地より少し暗い）、拾ったものは敷き紙の上
	var R := T.SMALL_RADIUS
	var empty := flat(T.TIN_DARK.lerp(T.TIN, 0.35), Color.TRANSPARENT, 0, R, T.SPACE_XS)
	empty.border_color = T.TIN_DARK
	empty.border_width_top = 3
	var empty_p := empty.duplicate()
	empty_p.bg_color = T.TIN_DARK
	var filled := flat(T.PAPER, T.PAPER_DARK, T.PANEL_BORDER, R, T.SPACE_XS)
	var filled_p := flat(T.PAPER_DARK, T.PAPER_DARK, T.PANEL_BORDER, R, T.SPACE_XS)
	_button(theme, "SlotEmpty", empty, empty_p, T.FONT_SMALL, T.INK_SOFT)
	_button(theme, "SlotFilled", filled, filled_p, T.FONT_SMALL, T.INK)
	var empty_s := empty.duplicate()
	empty_s.border_color = T.ACCENT_INK
	empty_s.set_border_width_all(3)
	var filled_s := flat(T.PAPER, T.ACCENT_INK, 3, R, T.SPACE_XS)
	_button(theme, "SlotEmptySelected", empty_s, empty_p, T.FONT_SMALL, T.INK_SOFT)
	_button(theme, "SlotFilledSelected", filled_s, filled_p, T.FONT_SMALL, T.INK)
