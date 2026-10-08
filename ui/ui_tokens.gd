class_name UiTokens
## UI の色・大きさ・時間の定数。
## 値は .claude/skills/summer-game-ui/SKILL.md と一致させること（スキルが正）。
## main_theme.tres は tools/build_theme.gd がこの値から作る。

# --- 配色（スキル「2. 配色」） ---
const PAPER := Color("#F6EEDC")
const PAPER_DARK := Color("#E8DCC0")
const INK := Color("#3B3226")
## 紙の上で 4.5:1 以上になる濃さ（#7A6E5D から変更）
const INK_SOFT := Color("#655A4B")
const TIN := Color("#B9C4C9")
const TIN_DARK := Color("#9AA7AD")
const ACCENT := Color("#D9763F")
## 紙の上の文字・印・選択の枠に使う濃い夕焼け色（紙の上で 5.3:1）。ACCENT は飾りだけに使う
const ACCENT_INK := Color("#9C4A1F")
const SKY := Color("#8EC5E0")
const SHADE := Color(0, 0, 0, 0.45)
const FADE := Color("#14110D")
const SHADOW := Color(0, 0, 0, 0.2)
## 宝箱の影（拾い逃したアイテム）の輪郭の線：INK_SOFT を不透明度 50% で
const MISSED_LINE := Color(0.396, 0.353, 0.294, 0.5)

# --- 文字サイズ（スキル「3. フォント」） ---
const FONT_BODY := 24
const FONT_SMALL := 18
const FONT_HEADING := 32
const FONT_TITLE := 64
## エンディングの見出し（缶の上段に入れるのでタイトルより少し小さく。48〜64px の範囲）
const FONT_ENDING_TITLE := 48
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
## 小さい画面（スマホ横向き）では基準の大きさを小さくして、文字とボタンを実寸で大きく見せる
## 画面の高さ（CSS px 相当）がこれより低いとき 1024×576 を基準にする
const COMPACT_SCREEN_HEIGHT := 520.0
const BASE_SIZE := Vector2i(1280, 720)
const COMPACT_BASE_SIZE := Vector2i(1024, 576)
const TOUCH_MIN := 72
const TOUCH_GAP := 16

# --- 動き（スキル「5. 動き」）単位は秒 ---
const TIME_SMALL := 0.2
const TIME_SMALL_OUT := 0.14
const TIME_PANEL := 0.25
## 閉じる動きは開く動きの約 7 割（すばやく反応させる）
const TIME_PANEL_OUT := 0.18
const TIME_LID := 0.4
const TIME_LID_OUT := 0.16
const TIME_FADE := 0.4
const TIME_DAY_CHANGE := 2.0
const TIME_CARD_FLIP := 0.3
## 日付がぱらぱらとめくれる（神隠しルートの10日目）：1枚ぶんの時間
const TIME_DATE_RIFFLE := 0.1
const TIME_CHAR := 0.04
const TIME_ITEM_APPEAR := 0.3
const TIME_ITEM_INTERVAL := 0.15
const TIME_PRESS := 0.08
const TIME_MESSAGE_AUTO_CLOSE := 6.0
## 縁側の場面（スキル「5. 動き」）：夜の終わりから暗くなる・一枚絵が明ける・アイテムの出現（1つ／間隔）
const TIME_ENGAWA_FADE := 0.6
const TIME_ENGAWA_REVEAL := 0.6
const TIME_ENGAWA_ITEM := 0.2
const TIME_ENGAWA_ITEM_INTERVAL := 0.08
## 縁側の場面の返事は、全文が出てからこの秒数で次の行へ進む（場面全体を TIME_ENGAWA_TOTAL 程度に収めるため。キー／タップですぐ進む）
const TIME_ENGAWA_LINE_HOLD := 2.5
## 縁側の場面の全体の目安（これより長くしない）
const TIME_ENGAWA_TOTAL := 20.0
## 異界の日の空の縁側（煙だけ）を見せる時間
const TIME_ENGAWA_EMPTY := 2.0
## お面の子（遠くの姿・他ルートの顔出し）が近づくと消えるときのフェード（急に消さない）
const TIME_GLIMPSE_VANISH := 1.2
## タイトルの「はじめる」案内がゆっくり明滅する周期の半分
const TIME_PULSE := 1.2
const PANEL_SCALE_FROM := 0.96
const FLOAT_DISTANCE := 8.0
## 演出の早送り倍率
const SKIP_SPEED := 6.0
const TRANS := Tween.TRANS_SINE
