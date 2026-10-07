class_name WorldPalette
## ゲームの世界（仮素材）の色と、時間帯・季節の色をまとめる。UI の色は UiTokens。

# --- 仮素材の色 ---
const GROUND := Color("#8DAA6E")
const GROUND_DARK := Color("#6F8C57")
const ROAD := Color("#CDB993")
## 道の暗いところ（家の前の踏み固めた土など）
const ROAD_DARK := Color("#A99470")
const HILL_FAR := Color("#A9C3B6")
const HILL_FAR_2 := Color("#97B5A6")
const NEAR_BUSH := Color("#7C9C63")
const POLE := Color("#6B5A48")
const HOUSE_WALL := Color("#C9B79C")
const HOUSE_ROOF := Color("#6E6A72")
const SIGN_BOARD := Color("#D8C3A0")
const SIGN_POST := Color("#7D6650")
const CLOUD := Color("#FBF8F1")
const CLOUD_SHADE := Color("#E2E6E8")
const PADDY := Color("#9DBB77")
const PADDY_ROW := Color("#B4CC8C")
const PADDY_PATH := Color("#C9B98E")
const POLE_FAR := Color("#7E8A80")
const WIRE := Color(0.25, 0.24, 0.22, 0.55)
# 親友ルートの場所（駄菓子屋・川原・秘密基地・夏祭り・バス停など）
const WOOD := Color("#8A6A4A")
const WOOD_DARK := Color("#6B5038")
const TIN_ROOF := Color("#8E979B")
const TIN_ROOF_LINE := Color("#77818A")
const BLUE_SHEET := Color("#5E86B0")
const CARDBOARD := Color("#C49A62")
const CARDBOARD_DARK := Color("#A87F4B")
const SOIL := Color("#7A5E44")
const WATER := Color("#7FA9B8")
## 川の向こうの遠くの橋（木の色を遠くの山の色へ少し寄せて、かすませる）
const FAR_BRIDGE := Color("#97836A")
const FAR_BRIDGE_DARK := Color("#7A6A57")
const WATER_DEEP := Color("#4F7C92")
const WATER_LIGHT := Color("#B7D3DA")
const ROCK := Color("#9A968C")
const ROCK_DARK := Color("#7C786F")
const STONE_LIGHT := Color("#C2BDB2")
const CHALK := Color(0.95, 0.95, 0.9, 0.8)
const MARBLE_BLUE := Color("#7FB6C9")
const MARBLE_GREEN := Color("#9CCB9A")
const SHOP_WALL := Color("#B8A07E")
const SHOP_DARK := Color("#5B4C3E")
const NOREN := Color("#4F6E8C")
const FREEZER := Color("#EDEDE6")
const WOODS_DARK := Color("#56734A")
const WOODS_TRUNK := Color("#5E4A3A")
const SHRINE_RED := Color("#B5563A")
const CANOPY := Color("#E9DEC6")
const CANOPY_STRIPE := Color("#B9775A")
const LANTERN := Color("#E8B86A")
const LANTERN_LINE := Color("#9C4A1F")
const BANANA := Color("#E3C75A")
const BEETLE := Color("#3E2A1E")
const FIRE := Color("#E08A3C")
## 型抜き（砂糖の板）：板、ふち、刷られた輪郭、削った溝、ひびの線、抜けたあとのくぼみ
const KATANUKI := Color("#F1E3D3")
const KATANUKI_EDGE := Color("#D8C2AA")
const KATANUKI_PRINT := Color("#C7A98E")
const KATANUKI_GROOVE := Color("#8E6E57")
const KATANUKI_CRACK := Color("#6E5444")
const KATANUKI_HOLLOW := Color("#D3BBA2")
## カブトムシとり（6日目の早朝）：暗く青い林と、つかんだあとの明けた空。環境音は夜明けのヒグラシ・遠くの鳥
const KABUTO_SKY := Color("#3E4A6E")
const KABUTO_SKY_DAWN := Color("#C9D9E6")
const KABUTO_FAR_TREE := Color("#2E3A52")
const KABUTO_GROUND := Color("#3A3A40")
const KABUTO_LEAF := Color("#6A5440")
const KABUTO_TRUNK := Color("#3D3430")
const KABUTO_AMBIENT := "higurashi_dawn"
## タイムカプセル埋め（9日目の夜）：懐中電灯の外の暗さ。環境音は秋の虫（コオロギ・スズムシ）
const CAPSULE_NIGHT := Color("#0E1220")
const CAPSULE_AMBIENT := "autumn_insects"
## 初恋ルート（なつみ）の場所：公民館の明かり・海・砂浜
const KOMINKAN_LIGHT := Color(1.0, 0.86, 0.58, 0.32)
const SCREEN_LIGHT := Color(0.78, 0.86, 1.0, 1.0)
const SEA_NEAR := Color("#86B8C8")
const SAND_WET := Color("#C9B585")
## 線香花火（9日目）：火の玉・火花・光のにじみ
const SENKO_BALL := Color("#F2783A")
const SENKO_CORE := Color("#FFF3C8")
const SENKO_SPARK := Color("#FFC56A")
const SENKO_GLOW := Color(1.0, 0.7, 0.35, 0.22)
## 金魚すくい（5日目）：水・金魚・ポイ
const KINGYO_WATER := Color("#7FB4C8")
const KINGYO_RED := Color("#E2553A")
const KINGYO_BLACK := Color("#2E2A2A")
const POI_FRAME := Color("#E9E2D0")
const POI_PAPER := Color(1.0, 1.0, 1.0, 0.55)
## かくれんぼ（8日目、ノーマルルート）：夕方の境内
const KAKURENBO_EVENING_TOP := Color("#E9B489")
const KAKURENBO_EVENING_LOW := Color("#F3D7A8")
const KAKURENBO_EVENING_HILL := Color("#9C8F8A")
const KAKURENBO_EVENING_GROUND := Color("#B9A07C")
## 洗濯物の取り込み（4日目）：晴れの空、夕立の雲、物干し、洗濯物
const SENTAKU_SKY := Color("#9FD0EA")
const SENTAKU_CLOUD := Color("#6E7680")
const SENTAKU_GROUND := Color("#8DAA6E")
const SENTAKU_POLE := Color("#8A6A4A")
const SENTAKU_LINE := Color(0.3, 0.27, 0.22, 0.8)
const SENTAKU_WET := Color(0.45, 0.55, 0.68, 0.35)
## 洗濯物の色：シャツ・タオル・くつした・てぬぐい・ズボン・まくらカバー
const SENTAKU_CLOTHES := [Color("#F4F1E8"), Color("#E7A9A0"), Color("#9DB7CF"), Color("#E9DCA8"), Color("#6F86A0"), Color("#C9DDB8")]
## 精霊馬づくり（6日目）：ちゃぶ台、きゅうり、なす、割りばし
const SHORYOUMA_TABLE := Color("#8A6447")
const SHORYOUMA_TABLE_EDGE := Color("#6B4C35")
const SHORYOUMA_TATAMI := Color("#C9C08A")
const CUCUMBER := Color("#4F7F3A")
const CUCUMBER_LIGHT := Color("#7FA85E")
const EGGPLANT := Color("#4A3352")
const EGGPLANT_LIGHT := Color("#6E5079")
const VEG_STEM := Color("#6E7F45")
const HASHI := Color("#E3CFA4")
const HASHI_EDGE := Color("#B79C6E")
## 星座さがし（9日目）：夜空と、縁側の軒・柱
const SEIZA_SKY_TOP := Color("#121733")
const SEIZA_SKY_LOW := Color("#2B3157")
const SEIZA_EAVES := Color("#17140F")
const SEIZA_LINE := Color(1.0, 0.94, 0.75, 0.75)
const SEIZA_MILKY := Color(0.85, 0.88, 1.0, 0.06)
## 縁側の場面（日の切り替わりの中の一枚絵）：夜空は星座さがしと同じ。月、庭のしげみ、板の間、座っている祖父母の影、蚊取り線香
const ENGAWA_MOON := Color("#F3E9C6")
const ENGAWA_MOON_GLOW := Color(0.95, 0.9, 0.75, 0.035)
const ENGAWA_GARDEN := Color("#1C2621")
const ENGAWA_FLOOR := Color("#3B2F25")
const ENGAWA_FLOOR_LINE := Color("#2C231B")
const ENGAWA_FLOOR_EDGE := Color("#55453A")
const ENGAWA_FIGURE := Color("#141110")
const ENGAWA_KAYARI := Color("#6F6A5E")
const ENGAWA_KAYARI_DARK := Color("#3E3A33")
const ENGAWA_EMBER := Color(1.0, 0.55, 0.3, 0.9)
const ENGAWA_SMOKE := Color(0.9, 0.9, 0.88, 0.35)
## 縁側の場面の環境音（虫の声。素材がなければ無音）
const ENGAWA_AMBIENT := "engawa_night"
## バスの窓（10日目）：うしろの窓から見える朝の道
const BUSWIN_SKY := Color("#BFDCEB")
const BUSWIN_FIELD := Color("#9DBB77")
const BUSWIN_ROAD := Color("#CDB993")
const BUSWIN_FRAME := Color("#5B4C3E")
const BUS_BODY := Color("#E6DDBF")
const BUS_STRIPE := Color("#6F9686")
const BUS_WINDOW := Color("#A9C3CE")
const BIKE := Color("#4C5A66")
# 夜の灯り（GlowLayer に描く。CanvasModulate で暗くならない）
const LANTERN_GLOW := Color(1.0, 0.82, 0.5, 0.3)
const LAMP_GLOW := Color(1.0, 0.93, 0.7, 0.28)
const FIRE_GLOW := Color(1.0, 0.6, 0.3, 0.35)
const STAR := Color(1.0, 0.98, 0.9, 0.85)
const FLASHLIGHT := Color(1.0, 0.95, 0.75, 0.1)
const PLAYER_BODY := Color("#F2F2F2")
const PLAYER_SHORTS := Color("#4C6A92")
const PLAYER_SKIN := Color("#E9C29C")
const PLAYER_HAT := Color("#E7D29A")

# --- 1日の中の時間帯（DESIGN.md「7. 時間帯と季節の表現」） ---
## [時間の値, CanvasModulate の色, 空の色]。時間の値は TimeKeys（日ごとの time_keys）で決まる。
## 早朝 -0.15 / 朝 0.00 / 昼 0.25 / 夕方 0.60 / 夜 0.85 / 夜の終わり 1.00（キーのあいだは補間する）
const TIME_KEYS := [
	# 早朝（夜明け前の暗く青い色。親友ルートの6日目のカブトムシとり）
	[-0.15, Color(0.52, 0.56, 0.80), Color("#5B6C9A")],
	[0.00, Color(1.00, 0.95, 0.90), Color("#BFDCEB")],
	[0.18, Color(1.00, 0.99, 0.97), Color("#9FD0EA")],
	[0.25, Color(1.00, 1.00, 1.00), Color("#8EC5E0")],
	[0.48, Color(1.00, 1.00, 0.98), Color("#86BFDD")],
	[0.60, Color(1.00, 0.88, 0.76), Color("#E9B489")],
	[0.73, Color(0.92, 0.70, 0.62), Color("#D98A6A")],
	[0.85, Color(0.55, 0.52, 0.66), Color("#5D5A80")],
	[1.00, Color(0.36, 0.38, 0.55), Color("#262B4A")],
]

## 光の粒・光の筋（SummerAir）が消えていく時間帯（時間の値）
const DAYLIGHT_FADE := Vector2(0.55, 0.82)
## 早朝の光の粒・光の筋が出てくる時間帯（時間の値。早朝から朝にかけて出てくる）
const DAYLIGHT_DAWN := Vector2(-0.15, 0.0)

# --- 夕立（RainZone） ---
## 雨のときに画面全体へかける色（暗く、少し青く）
const RAIN_LIGHT := Color(0.72, 0.75, 0.82)
const RAIN_SKY := Color("#8C949A")
const RAIN_STREAK := Color(0.85, 0.9, 0.96, 0.55)
## 飛び込み岩の上（蝉と川の音を大きめに）と、水の中（すべての音がこもる）の環境音
const DIVE_AMBIENT_ROCK := "river_rock"
const DIVE_AMBIENT_UNDER := "underwater"
## 雨の間の環境音（雨がやむと季節の蝉の声にもどる）
const RAIN_AMBIENT := "rain"

# --- 異界（神隠しルート。OtherworldZone） ---
## 色を抜いたあとに、画面全体と空へかける色（少し青白く）
const OTHERWORLD_LIGHT := Color(0.94, 0.96, 1.0)
const OTHERWORLD_SKY := Color(0.92, 0.95, 1.02)
## 異界の灯り（青い提灯・あおいほおずき）
const BLUE_LANTERN := Color("#7FA8D8")
const BLUE_LANTERN_GLOW := Color(0.55, 0.75, 1.0, 0.2)
## 異界の環境音（蝉が鳴かず、遠い虫の声だけ）
const OTHERWORLD_AMBIENT := "autumn_insects"

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
