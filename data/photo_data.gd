class_name PhotoData
extends Resource
## 章「あの夏へ」の写真 1枚分のデータ（DESIGN.md「8.69999 章『あの夏へ』」）。
## 写真のポイント（15か所）、タケルが破で撮る3枚、残りのフィルムでタケルが撮る5枚、手紙にくるまれた二人の写真。
## 撮ると、現像前の写真（to_item）が手に入る。絵が入るまでは、題名を書いたカードで出す。
## 心の声は漢字まじり、子どもが書いた字（写真の裏の「おれと おまえ」）はひらがな。

## 撮った人
enum Shooter { PLAYER, TAKERU }
## 急の病室で、なつみに見せたときの反応の種類（シナリオ「病室」の表）
enum Reaction {
	FAMILY,     ## 祖父・祖母・親戚：「……優しそうな人たちね」
	TAKERU,     ## タケル：「……元気な子」
	SKY,        ## なつみ・なつみの絵・空：「……きれいな青」
	VILLAGE,    ## 村の景色：「……いいところね」
	BLACK,      ## 真っ黒な写真：なつみは黙って、指で写真の表をなでる
	BOY_BACK,   ## 少年の主人公（後ろ姿）：「……誰かしら」
	BOY_FRIEND, ## 少年の主人公（飛び込み・映画会の帰り）：「……この子、知ってる気がする」
	KEY,        ## 手紙にくるまれた二人の写真（最後の1枚）
}

@export var id: StringName
## 写真のポイントの番号（1〜15）。ポイントでない写真は 0
@export var point_no := 0
@export var month := 8
@export var day := 13
## 場所（「迎え火を焚く祖父」など。カメラの一覧に日付と並べて出す）
@export var place: String
@export var shooter: Shooter = Shooter.PLAYER
## 少年の主人公が写っているか（なつみの反応を分ける）
@export var boy_in_frame := false
@export var reaction: Reaction = Reaction.VILLAGE
## 撮ったときの（急の缶を開けたときの）心の声。漢字まじり
@export_multiline var inner_voice: String
## 絵（仮素材は空。題名を書いたカードで出す）
@export var picture: Texture2D
## 仮のカードの色
@export var placeholder_color: Color = Color("#D8C9A8")
## 何も写っていない真っ黒な写真（残りのフィルムが5枚より多く余ったぶん。日付はない）
@export var black := false
## 写真の裏の字（子どもが書いたもの。ひらがな）。空なら裏には何もない
@export var back_text: String


## カメラの一覧に出す、日付と場所（絵は出さない）
func label() -> String:
	if black:
		return place
	return "%d/%d　%s" % [month, day, place]


## 缶を開けたあと、写真の下に出す日付（漢字。真っ黒な写真は日付なし）
func date_text() -> String:
	return "" if black else "%d月 %d日" % [month, day]


## 並べ替えの値（日付順）。真っ黒な写真はいちばん最後
func date_key() -> int:
	return 9999 if black else month * 100 + day


## 何も写っていない写真
static func make_black() -> PhotoData:
	var p := PhotoData.new()
	p.id = &"black"
	p.black = true
	p.place = "何も写っていない写真"
	p.reaction = Reaction.BLACK
	p.shooter = Shooter.TAKERU
	p.inner_voice = "（……何も写っていない。それでも、捨てられない）"
	p.placeholder_color = Color("#1E1B18")
	return p


## 撮ったときに手に入る、現像前の写真（宝物と同じ枠に並べるための ItemData）
func to_item() -> ItemData:
	var it := ItemData.new()
	it.id = id
	it.display_name = "現像前の写真"
	it.description = label()
	it.placeholder_color = placeholder_color
	it.on_ground = false
	return it
