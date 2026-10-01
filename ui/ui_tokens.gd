class_name UiTokens
## UI の色・大きさ・時間の定数。
## 値は .claude/skills/summer-game-ui/SKILL.md と一致させること（スキルが正）。
## main_theme.tres は tools/build_theme.gd がこの値から作る。

# --- 配色（スキル「2. 配色」） ---
const PAPER := Color("#F6EEDC")
const PAPER_DARK := Color("#E8DCC0")
const INK := Color("#3B3226")
const INK_SOFT := Color("#7A6E5D")
const TIN := Color("#B9C4C9")
const TIN_DARK := Color("#9AA7AD")
const ACCENT := Color("#D9763F")
const SKY := Color("#8EC5E0")
const SHADE := Color(0, 0, 0, 0.45)
const FADE := Color("#14110D")
const SHADOW := Color(0, 0, 0, 0.2)

# --- 文字サイズ（スキル「3. フォント」） ---
const FONT_BODY := 24
const FONT_SMALL := 18
const FONT_HEADING := 32
const FONT_TITLE := 64
const FONT_BIG_DATE := 56
## 日めくりの札の日付の数字
const FONT_CARD_DAY := 48
const LINE_HEIGHT_RATIO := 1.6

# --- 形と余白（スキル「4. 形と余白」） ---
const SPACE_XS := 8
const SPACE_S := 16
const SPACE_M := 24
const SPACE_L := 32
const SCREEN_MARGIN := 40
const PANEL_RADIUS := 12
const PANEL_BORDER := 2
const PANEL_PADDING := 24
const SHADOW_OFFSET := 3
## 宝箱の枠・看板などパネルより小さい部品の角丸（パネルの 12px と差をつける）
const SMALL_RADIUS := 6
## お菓子の缶のふちの太さ
const TIN_RIM := 6
## 日めくりの札のとじ穴の半径
const CARD_HOLE := 5
const TOUCH_MIN := 72
const TOUCH_GAP := 16

# --- 動き（スキル「5. 動き」）単位は秒 ---
const TIME_SMALL := 0.2
const TIME_PANEL := 0.25
const TIME_LID := 0.4
const TIME_FADE := 0.4
const TIME_DAY_CHANGE := 2.0
const TIME_CARD_FLIP := 0.3
const TIME_CHAR := 0.04
const TIME_ITEM_APPEAR := 0.3
const TIME_ITEM_INTERVAL := 0.15
const TIME_PRESS := 0.08
const TIME_MESSAGE_AUTO_CLOSE := 6.0
## タイトルの「はじめる」案内がゆっくり明滅する周期の半分
const TIME_PULSE := 1.2
const PANEL_SCALE_FROM := 0.96
const FLOAT_DISTANCE := 8.0
## 演出の早送り倍率
const SKIP_SPEED := 6.0
const TRANS := Tween.TRANS_SINE
