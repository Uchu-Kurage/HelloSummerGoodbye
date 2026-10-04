class_name Strings
## 画面に出す文言をまとめる（スキル「8. 実装の決まり」）。
## キーボードとタッチで変わるものは *_KEY / *_TOUCH の両方を置く。

const GAME_TITLE := "To The Summer"
const START_PROMPT_TOUCH := "タップして はじめる"
const START_PROMPT_KEY := "クリック または キーで はじめる"
const MENU_START := "はじめる"
const MENU_QUIT := "おわる"
## 開発用（デバッグ実行のときだけ出る）：ルートと日を選んで、その日へとぶ
const MENU_DEBUG := "デバッグ"
const DEBUG_TITLE := "ルートと ひを えらぶ"
const DEBUG_ROUTE := "ルート：%s"
const DEBUG_HINT := "ひを えらぶと、その ひの はじめから はじまるよ"
const DEBUG_DAY := "%dにちめ"

const PAUSE_TITLE := "ひとやすみ"
const PAUSE_RESUME := "つづける"
const PAUSE_BOX := "たからばこ"
const PAUSE_TITLE_SCREEN := "タイトルへ"

const BOX_TITLE := "たからばこ"
const BOX_EMPTY_NAME := "？？？"
const BOX_EMPTY_DESC := "まだ からっぽ。"
const BOX_PICKED_ON := "%dがつ%dにち に ひろった"
const BOX_RECEIVED_ON := "%dがつ%dにち に もらった"
## 会話の @bury で宝箱から選ぶとき
const BURY_TITLE := "なにを いれる？"
const BURY_HINT := "かんに いれる ものを えらんでね"
## 手ばなしたものの枠に出すひとこと（@bury）
const BURIED_NOTE := "うめた"
const BOX_HINT_SELECT := "えらぶと くわしく みられるよ"
const BACK := "もどる"
const BUTTON_BOX := "たからばこ"
const BUTTON_PAUSE := "ひとやすみ"

const PICKUP_KEY := "E"
const PICKUP_TOUCH := "ひろう"
const PICKED_FORMAT := "%s を ひろった"
const TALK_KEY := "E"
const TALK_TOUCH := "はなす"
## 会話で「ぼく：」と書いたせりふの名前（主人公）
const ME := "ぼく"
const RECEIVED_FORMAT := "%s を もらった"
const PUT_IN_FORMAT := "%s を かんに いれた"

const WALK_HINT_KEY := "→ / D で あるく"
const WALK_HINT_TOUCH := "がめんの みぎを おしつづけると あるく"

const DATE_MONTH := "%dがつ"
const DATE_DAY := "%d"
const DATE_FULL := "%dがつ %dにち"

const ENDING_TITLE := "なつやすみ おしまい"
const ENDING_COUNT := "たからもの %d / %d"
const ENDING_FOUND_TITLE := "なつの たからもの"
const ENDING_FOUND := "%dこ のうち %dこ みつけた。\nえらぶと くわしく みられるよ"
const ENDING_RETRY := "もういちど"

## 秘密基地づくり（ミニゲーム）
const BASE_PICK_TOUCH := "ピースを えらんでね。はめた ピースは タップで はずせる"
const BASE_PICK_KEY := "やじるしで ピースを えらんで けってい"
const BASE_PLACE_TOUCH := "すきまを タップか ドラッグで はめる"
const BASE_PLACE_KEY := "やじるしと けっていで はめる。R で まわす"
const BASE_DONE := "あまもり、ぜんぶ ふさいだ！"
const BASE_ROTATE := "まわす"
const BASE_RETURN := "もどす"
## 飛び込み（ミニゲーム）
const DIVE_HINT_TOUCH := "がめんを おしつづけて、「の！」で はなす"
const DIVE_HINT_KEY := "Space を おしつづけて、「の！」で はなす"
## タケルのかけ声と、おそいときに下から呼ぶ声
const DIVE_COUNT_SE := "せー……"
const DIVE_COUNT_NO := "の！"
const DIVE_LATE_CALL := "はやく こいよー！"
## 帽子を受け止める（ミニゲーム）
const HAT_CALL := "おーい！ まどー！ まど あけろー！"
const HAT_PROMISE := "やくそくだぞー！"
const HAT_SMELLY := "ぼく：……くさい"
## 手をふって、さけび返す言葉（押すたびに順に）
const HAT_SHOUTS := ["ぼく：ぜったいー！", "ぼく：またねー！", "ぼく：タケルー！"]
## 小さくなっていくタケルの最後の一言（石切りの記録から）
const HAT_LAST_LOSE := "いし、れんしゅう しとけよー！"
const HAT_LAST_WIN := "つぎは まけねーぞー！"
const HAT_OPEN_TOUCH := "おしつづけて まどを あける"
const HAT_OPEN_KEY := "Space を おしつづけて まどを あける"
const HAT_TAP_TOUCH := "とんでくる ぼうしを タップ"
const HAT_TAP_KEY := "ぼうしが ちかづいたら Space"
const HAT_WAVE_TOUCH := "タップで てを ふる"
const HAT_WAVE_KEY := "Space で てを ふる"
## タイムカプセル埋め（ミニゲーム）
const CAPSULE_SPOTS := ["ひだり", "まんなか", "みぎ"]
const CAPSULE_ANYWHERE := "どこでも いいぞ。"
const CAPSULE_PICK_TOUCH := "うめる ばしょを タップ"
const CAPSULE_PICK_KEY := "やじるしで ばしょを えらんで けってい"
const CAPSULE_DIG_TOUCH := "タップで ひとすくい ほる"
const CAPSULE_DIG_KEY := "Space で ひとすくい ほる"
const CAPSULE_PLACE_TOUCH := "タップで かんを そっと おく"
const CAPSULE_PLACE_KEY := "Space で かんを そっと おく"
const CAPSULE_COVER_TOUCH := "おしつづけて つちを よせる"
const CAPSULE_COVER_KEY := "Space を おしつづけて つちを よせる"
const CAPSULE_PAT_TOUCH := "タップで ぽん"
const CAPSULE_PAT_KEY := "Space で ぽん"
const CAPSULE_PON := "ぽん、"
const CAPSULE_PON_PON := "ぽん、ぽん。"
## 掘りながらの会話。ひとすくいごとに1行すすむ（行を増やすと、すくう回数も増える）
const CAPSULE_DIG_LINES := [
	"まちの がっこうって でかいのかな。",
	"ぼく：たぶん",
	"おれ、とかいもんに なっちゃうな。",
	"ぼく：タケルは タケルだよ",
	"……なんだ それ。",
	"おまえ、らいねんも きち つかえよ。",
	"やね、ちゃんと なおせよ。",
	"……よし。こんくらいで いいだろ。",
]
## さみしい一言（CAPSULE_DIG_LINES の番号）。このときだけ懐中電灯の光が少しゆれる
const CAPSULE_SAD_LINES := [2, 5]
## カブトムシとり（ミニゲーム）
const KABUTO_HINT_TOUCH := "がめんを おしつづけて そーっと すすむ。はなすと とまる"
const KABUTO_HINT_KEY := "Space を おしつづけて そーっと すすむ。はなすと とまる"
const KABUTO_GRAB := "つかむ"
const KABUTO_GRAB_TOUCH := "「つかむ」を タップ"
const KABUTO_GRAB_KEY := "Space で つかむ"
## 落ちてしまったとき、うしろのタケルの小声
const KABUTO_DROPPED := "あ！ ……まだ いる。あそこ。"
## 石切り（ミニゲーム）
const ISHI_PICK_TOUCH := "なげる いしを タップ（%d／%d かいめ）"
const ISHI_PICK_KEY := "やじるしで いしを えらんで けってい（%d／%d かいめ）"
const ISHI_AIM_TOUCH := "がめんを おしつづけて うでを ひき、はなして なげる"
const ISHI_AIM_KEY := "Space を おしつづけて うでを ひき、はなして なげる。Esc で えらびなおす"
const ISHI_REPICK := "えらびなおす"
## 1回も跳ねずに沈んだとき、タケルが笑う
const ISHI_PLOP := "ぽちゃん！"
## 型抜き（ミニゲーム）
const KATANUKI_HINT_TOUCH := "がめんを おしつづけて けずる。はなすと ひとやすみ"
const KATANUKI_HINT_KEY := "Space を おしつづけて けずる。はなすと ひとやすみ"
## となりのタケルの型が割れたとき
const KATANUKI_TAKERU_BREAK := "……あーっ！ われた！"
## きれいに抜けたとき、屋台のおじさん
const KATANUKI_STALL_NAME := "おじさん"
const KATANUKI_CLEAN := "おっ、ぬけたね"
## 寄りの画面の上に出す、タケルのひとこと
const SPEECH_FORMAT := "%s「%s」"

const ROTATE_NOTICE := "よこむきにしてね"
const ROTATE_SUB := "スマホを よこに すると あそべるよ"

const CONTINUE_MARK := "▼"
const SELECT_MARK := "●"
