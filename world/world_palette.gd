class_name WorldPalette
## ゲームの世界（仮素材）の色と、時間帯・季節の色をまとめる。UI の色は UiTokens。

# --- 仮素材の色 ---
const GROUND := Color("#8DAA6E")
const GROUND_DARK := Color("#6F8C57")
const ROAD := Color("#CDB993")
const HILL_FAR := Color("#A9C3B6")
const HILL_FAR_2 := Color("#97B5A6")
const NEAR_BUSH := Color("#7C9C63")
const POLE := Color("#6B5A48")
const HOUSE_WALL := Color("#C9B79C")
const HOUSE_ROOF := Color("#6E6A72")
const SIGN_BOARD := Color("#D8C3A0")
const SIGN_POST := Color("#7D6650")
const PLAYER_BODY := Color("#F2F2F2")
const PLAYER_SHORTS := Color("#4C6A92")
const PLAYER_SKIN := Color("#E9C29C")
const PLAYER_HAT := Color("#E7D29A")

# --- 1日の中の時間帯（DESIGN.md「7. 時間帯と季節の表現」） ---
## [その日の進み具合, CanvasModulate の色, 空の色]
## 朝 0.00〜0.25 / 昼 0.25〜0.60 / 夕方 0.60〜0.85 / 夜 0.85〜1.00
const TIME_KEYS := [
	[0.00, Color(1.00, 0.95, 0.90), Color("#BFDCEB")],
	[0.18, Color(1.00, 0.99, 0.97), Color("#9FD0EA")],
	[0.25, Color(1.00, 1.00, 1.00), Color("#8EC5E0")],
	[0.55, Color(1.00, 1.00, 0.98), Color("#86BFDD")],
	[0.68, Color(1.00, 0.88, 0.76), Color("#E9B489")],
	[0.80, Color(0.92, 0.70, 0.62), Color("#D98A6A")],
	[0.88, Color(0.55, 0.52, 0.66), Color("#5D5A80")],
	[1.00, Color(0.36, 0.38, 0.55), Color("#262B4A")],
]

# --- 季節（summer_progress 0.0〜1.0） ---
## 夏の終わりに向けて空を褪せさせる量（彩度を何割落とすか）
const SKY_FADE_AMOUNT := 0.45
## 褪せたときに寄せる色（少し黄ばんだ灰色）
const SKY_FADE_TOWARD := Color("#C8C2B4")
## 環境音：[この進み具合から, 環境音の名前]
const AMBIENT_KEYS := [
	[0.0, "semi_abura"],
	[0.5, "semi_minmin"],
	[0.8, "semi_tsukutsuku"],
]
