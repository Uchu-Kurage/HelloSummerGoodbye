class_name NpcData
extends Resource
## 村の人（NPC）1人分のデータ。せりふと仮の見た目をここで決める。
##
## せりふ（lines / repeat_lines）は1つずつ送って読む。ひらがな多めで短く（1つ全角20文字ほどまで）。
## 次の書き方で、話す人を変えたり、選択肢やアイテムのやりとりを入れたりできる。
##   ぼく：せりふ             「：」（全角）の前が話す人の名前になる（ぼく＝主人公）
##   #なまえ                  目印（@goto などの飛び先）
##   @goto なまえ             目印へ飛ぶ
##   @end                     ここで会話をおわる
##   @if_has アイテムID なまえ   そのアイテムを持っていたら目印へ飛ぶ
##   @if_flag フラグ なまえ      そのフラグが立っていたら目印へ飛ぶ
##   @choice ことば:なまえ | ことば:なまえ   選択肢。「:なまえ」を省くと、そのまま次へ進む
##   @give アイテムID          アイテムをもらう
##   @take アイテムID ひとこと   アイテムを手ばなす（宝箱の枠に「ひとこと」を出す）
##   @show アイテムID          次のせりふの左に、そのアイテムの絵を出す
##   @bury                    宝箱からアイテムを1つ選んで手ばなす（枠に「うめた」）
##   @flag フラグ              フラグを立てる
##   @heart                   なつみの好感度を +1 する（好みの選択肢を選んだとき）
##   @drop アイテムID          この人の足もとにアイテムを落とす（拾える）
##   @leave                   この人がそっと立ち去る
##   @event なまえ             その日のシーンの小物に知らせる（on_talk_event）

@export var id: StringName
@export var display_name: String
## 最初に話しかけたときのせりふ
@export var lines: Array[String] = []
## 2回目以降に話しかけたときのせりふ。空なら lines をくり返す
@export var repeat_lines: Array[String] = []
## この人が出てくる条件。空ならいつでも出る（条件が合わなくなったら、そっといなくなる）
@export var appear_if: FlagCondition
## 話し終えたときに立てるフラグ（エンディングの分岐、その日の中の段取りなど）
@export var set_flags: Array[StringName] = []
## 近づいただけで話しはじめる（向こうから声をかけてくる）。2回目以降は話しかけたときだけ
@export var auto_talk := false
## 本番の絵。空のときは下の色で仮の姿を描く
@export var sprite: Texture2D
@export_group("仮の見た目")
## 一言パネルの左に出す色（アイコンのかわり）
@export var placeholder_color: Color = Color("#B8A58C")
@export var height := 170.0
@export var skin_color: Color = Color("#E2B894")
@export var hair_color: Color = Color("#D8D4CC")
@export var shirt_color: Color = Color("#F2F0EA")
@export var pants_color: Color = Color("#C9B79A")
## 髪が頭の上まである（子どもなど）。false なら横と後ろだけ（おじいちゃんなど）
@export var hair_full := false
## 少し前かがみにする（お年寄りなど）
@export var stoop := 0.0
