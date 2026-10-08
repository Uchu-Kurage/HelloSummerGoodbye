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
## 4つのエンディングをすべて見ると、タイトルに出るエピローグ
const MENU_EPILOGUE := "それから"
## タイトルの、見たエンディングの数の印（読み上げ・説明用。どれが足りないかは出さない）
const TITLE_SEEN_MARK := "●"
const TITLE_UNSEEN_MARK := "○"
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
const BOX_PICKED_ON := "%sがつ%sにち に ひろった"
const BOX_RECEIVED_ON := "%sがつ%sにち に もらった"
## 会話の @bury で宝箱から選ぶとき
const BURY_TITLE := "なにを いれる？"
const BURY_HINT := "かんに いれる ものを えらんでね"
## 手ばなしたものの枠に出すひとこと（@bury）
const BURIED_NOTE := "うめた"
## 拾い逃したアイテムの影（宝箱）：名前は BOX_EMPTY_NAME（？？？）のまま、日付と場所のヒントだけ出す（「7/27　かわらの どこか」）
const BOX_MISSED_DATE := "%s/%s"
const BOX_MISSED_PLACE := "%sの どこか"
const BOX_MISSED_HINT := "%s　%s"
const BOX_HINT_SELECT := "えらぶと くわしく みられるよ"
const BACK := "もどる"
## ミニゲームの共通の枠（始める前の操作の絵、矢印、おわったあと）
const MINIGAME_KEY_SPACE := "Space"
const MINIGAME_KEY_TOUCH := "タップ"
const MINIGAME_START_KEY := "で はじめる（←→ で えらぶ／Esc で やめる）"
const MINIGAME_START_TOUCH := "で はじめる（「もどる」で やめる）"
const MINIGAME_LEFT := "←"
const MINIGAME_RIGHT := "→"
const MINIGAME_NEXT := "つぎへ"
const MINIGAME_RETRY := "もういちど"
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

## 日付は文字で入れる（異界の日は DATE_UNKNOWN。GameState.day_date）
const DATE_MONTH := "%sがつ"
const DATE_DAY := "%s"
const DATE_FULL := "%sがつ %sにち"
const DATE_UNKNOWN := "？？"

## 縁側の場面（日の切り替わりの中）。返事の文面は res://data/engawa/*.tres（EngawaReply）
const ENGAWA_ASK := "おばあちゃん：きょうは、なにしたの？"
## その日に拾ったものがないとき（と、見せるものの枠の名前）
const ENGAWA_NOTHING := "なんにも"
## 縁側の場面は戻る先がないので「もどる」ではなく「とばす」
const ENGAWA_SKIP := "とばす"
const ENGAWA_PICK_KEY := "やじるしで えらんで、けっていで みせる"
const ENGAWA_PICK_TOUCH := "みせる ものを タップ"
## 見せたものの名前と一言（返事のあいだ、下の小札に出す）
const ENGAWA_ITEM_NOTE := "%s「%s」"
## 会話の話し手の名前（顔の絵と色を選ぶため）
const GRANDMA := "おばあちゃん"
const GRANDPA := "おじいちゃん"

const ENDING_TITLE := "なつやすみ おしまい"
const ENDING_COUNT := "たからもの %d / %d"
const ENDING_FOUND_TITLE := "なつの たからもの"
const ENDING_FOUND := "%dこ のうち %dこ みつけた。\nえらぶと くわしく みられるよ"
const ENDING_RETRY := "もういちど"
## エピローグ「それから」の最後の宝箱
const EPILOGUE_TITLE := "それから"
const EPILOGUE_FOUND := "ぜんぶで %dこ。\nえらぶと くわしく みられるよ"
const EPILOGUE_TO_TITLE := "タイトルへ"
## 宝箱のページ送り（1画面に入らないとき）
const BOX_PAGE_PREV := "まえ"
const BOX_PAGE_NEXT := "つぎ"
const BOX_PAGE := "%d / %d"

## 秘密基地づくり（ミニゲーム）
const BASE_PICK_TOUCH := "ピースを えらんでね。はめた ピースは タップで はずせる"
const BASE_PICK_KEY := "やじるしで ピースを えらんで けってい"
const BASE_PLACE_TOUCH := "すきまを タップか ドラッグで はめる"
const BASE_PLACE_KEY := "やじるしと けっていで はめる。R で まわす"
const BASE_DONE := "あまもり、ぜんぶ ふさいだ！"
const BASE_ROTATE := "まわす"
const BASE_RETURN := "もどす"
const BASE_INTRO := "ピースを えらんで、やねと かべの すきまを うめよう"
## やめたとき（残りのすき間をタケルが埋める）。シナリオにないので、せりふではなく説明の書き方
const BASE_QUIT_FILL := "（のこりは タケルが ふさいだ）"
## 飛び込み（ミニゲーム）：タケルのかけ声
const DIVE_COUNT_SE := "せー……"
const DIVE_COUNT_NO := "の！"
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
## となりのタケルの型が割れたとき
const KATANUKI_TAKERU_BREAK := "……あーっ！ われた！"
## きれいに抜けたとき、屋台のおじさん
const KATANUKI_STALL_NAME := "おじさん"
const KATANUKI_CLEAN := "おっ、ぬけたね"
## 寄りの画面の上に出す、タケルのひとこと
const SPEECH_FORMAT := "%s「%s」"

## --- 初恋ルート（なつみ）のミニゲーム ---
## ゲーム中の小札は、シナリオにないせりふを足さないよう、説明の書き方（かっこ）にする
## スケッチ（3日目）：景色の4か所を、3色から選んで塗る
const SKETCH_INTRO := "けしきを みて、4かしょを おなじ いろで ぬろう"
const SKETCH_HINT_TOUCH := "いろを タップして ぬる"
const SKETCH_HINT_KEY := "←→ で いろを えらんで Space"
const SKETCH_PLACES := ["（そらを ぬる）", "（やまを ぬる）", "（かわを ぬる）", "（いわを ぬる）"]
## 金魚すくい（5日目）
const KINGYO_INTRO := "ポイを うごかして、きんぎょの まうえで すくおう"
const KINGYO_HINT_TOUCH := "← → で ポイを うごかし、まうえで タップ"
const KINGYO_HINT_KEY := "←→ で ポイを うごかし、まうえで Space"
## すくった数と、ポイがあと何回もつか
const KINGYO_COUNT := "（%dひき　ポイ：あと %dかい）"
const KINGYO_BROKE := "（ポイが やぶれた。%dひき）"
## 貝がら拾い（6日目）
const KAIGARA_INTRO := "なみが ひいている あいだに、かいがらを ひろおう"
const KAIGARA_HINT_TOUCH := "← → で あるいて、あしもとの かいがらを タップ"
const KAIGARA_HINT_KEY := "←→ で あるいて、あしもとの かいがらを Space"
const KAIGARA_COUNT := "（かいがら：%dこ）"
const KAIGARA_GOT_SAKURA := "（さくらがいを ひろった）"
## 線香花火（9日目）。押し続けは使わない（揺れる火の玉を、決定・タップで真ん中へ戻す）
const SENKO_INTRO := "ゆれる ひのたまを、はしに いく まえに まんなかへ もどそう"
const SENKO_HINT_TOUCH := "はしに よったら タップで まんなかへ"
const SENKO_HINT_KEY := "はしに よったら Space で まんなかへ"
const SENKO_HERS_FELL := "（なつみの ひのたまが おちた）"
const SENKO_MINE_FELL := "（ぼくの ひのたまが おちた）"
## 映画会（7日目）：暗転と音だけで表す（上の小札に、音を書く）
const MOVIE_SOUNDS := ["（ジジ……カタカタカタ……）", "（ギィ……）", "（ひた、ひた、ひた……）", "（……キャーッ！）", "（あかりが ついた）"]
## 絵を広げる（10日目・高）
const DRAWING_TITLE := "なつやすみの おもいで"
const DRAWING_NAME := "なつみ"
const DRAWING_HINT_TOUCH := "タップで とじる"
const DRAWING_HINT_KEY := "Space で とじる"

## --- 神隠しルート（お面の子）の画面 ---
## かくれんぼ（神隠し4日目・ノーマル8日目で同じ仕組み）：境内の隠れ場所6つから、相手を探す
const KAKURENBO_INTRO := "すずの おとが する ほうを さがそう"
const KAKURENBO_JIJI_INTRO := "むぎわらぼうしの はしが みえる ほうを さがそう"
const KAKURENBO_SPOTS := ["とうろう", "おおきな き", "こまいぬ", "さいせんばこ", "とりいの かげ", "ちょうずや"]
const KAKURENBO_HINT_TOUCH := "しらべる ところを タップ"
const KAKURENBO_HINT_KEY := "←→ で えらんで Space で しらべる"
const KAKURENBO_COUNT := "（じゅう かぞえる……）"
const KAKURENBO_READY := "……もう いいよ。"
const KAKURENBO_LOOK := "（%sを しらべる）"
const KAKURENBO_MISS := "（……いない）"
## お面の子の近くを選ぶと出る、鈴の音の印（音が出なくても分かるように）
const KAKURENBO_BELL_MARK := "♪ ちりん"
const KAKURENBO_FOUND := "（いた！）"
## 見つけられなかったとき、自分から出てくる
const KAKURENBO_CAME_OUT := "（こまいぬの うしろから、でてきた）"
const KAKURENBO_JIJI_READY := "……もう いいぞ。"
const KAKURENBO_JIJI_CAME_OUT := "（こまいぬの うしろから、でてきた）"
## 夜市の物々交換（5日目）：屋台4つと、てもとの「夜市の品」3つ（YomiseGame.Goods の順）
const YOMISE_INTRO := "やたいの ほしい ものを きいて、とりかえっこを つなごう"
const YOMISE_GOODS := ["ふうりん", "かざぐるま", "ほおずき", "ガラスの おはじき", "あおい ちょうちん", "あおい あめだま", "いちばん きれいな あめだま"]
const YOMISE_HINT_TOUCH := "やたいを タップで きく。もう いちど タップで とりかえる"
const YOMISE_HINT_KEY := "←→ で やたいを えらび、Space で きく・とりかえる"
## てもとと、あと何回とりかえられるか
const YOMISE_HAND := "（てもと：%s　あと %dかい）"
const YOMISE_WANTS := "（%sが ほしい。%sと とりかえて くれる）"
const YOMISE_NO := "（%sを もっていない）"
const YOMISE_TRADED := "（%sと とりかえた）"
const YOMISE_GOT := "（%sを もらった）"
## 鈴の音で道探し（6日目）：暗い森の分かれ道で、鈴の鳴るほうへ（同じ側で光もゆれる）
const SUZU_MICHI_INTRO := "すずの なる ほう（ひかりの ゆれる ほう）へ すすもう"
const SUZU_MICHI_HINT_TOUCH := "← → か、がめんの ひだり・みぎを タップで すすむ"
const SUZU_MICHI_HINT_KEY := "←→ で すすむ。Space で もう いちど きく"
const SUZU_MICHI_FORK := "（わかれみち %d／%d）"
const SUZU_MICHI_WRONG := "（……ちがう みち みたい。もどろう）"
const SUZU_MICHI_OUT := "（もりを ぬけた）"
## 鬼ごっこ（8日目）：色の抜けた村で、前を走るお面の子を追いかける（走るのは自動。決定で飛び越える）
const ONI_INTRO := "へいや みずたまりの まえで とびこえて、おめんの こを おいかけよう"
const ONI_HINT_TOUCH := "へいや みずたまりの まえで タップ（とびこえる）"
const ONI_HINT_KEY := "へいや みずたまりの まえで Space（とびこえる）"
const ONI_TURN := "（おめんの こが とまって、ふりかえった）"
const ONI_CAUGHT := "（つかまえた）"
## 鈴を振る（10日目のバス）：一度だけ鳴る
const SUZU_FURU_HINT_TOUCH := "タップで すずを ふる"
const SUZU_FURU_HINT_KEY := "Space で すずを ふる"
const SUZU_FURU_RING := "（ちりん――）"
const SUZU_FURU_SILENT := "（……）"
const SUZU_FURU_CLOSE_TOUCH := "タップで とじる"
const SUZU_FURU_CLOSE_KEY := "Space で とじる"

## --- ノーマルルート（祖父母）の画面 ---
## 洗濯物の取り込み（4日目）：夕立が来る前に、物干しの洗濯物を取り込む（布団は2回）
const SENTAKU_INTRO := "あめが ふる まえに、せんたくものを ぜんぶ とりこもう"
const SENTAKU_CLOTHES := ["シャツ", "タオル", "くつした", "てぬぐい", "ズボン", "ふとん"]
const SENTAKU_HINT_TOUCH := "せんたくものを タップで とりこむ（ふとんは 2かい）"
const SENTAKU_HINT_KEY := "←→ で うごいて Space で とりこむ（ふとんは 2かい）"
const SENTAKU_COUNT := "（とりこんだ：%d／%d）"
const SENTAKU_FUTON := "（ふとんは おもい。もう いちど）"
const SENTAKU_RAIN := "（ぽつ、ぽつ……）"
const SENTAKU_ALL := "（ぜんぶ とりこんだ）"
## 精霊馬づくり（6日目）：きゅうりとなすに、割りばしの足をさす
const SHORYOUMA_INTRO := "わりばしが ●の うえに きたら さして、あしを 4ほん たてよう"
const SHORYOUMA_HINT_TOUCH := "はしが ●の うえに きたら タップで さす"
const SHORYOUMA_HINT_KEY := "はしが ●の うえに きたら Space で さす"
## [どの野菜か, おばあちゃんの一言]
const SHORYOUMA_VEG := [["きゅうり", "きゅうりは うま。はやく かえって こられるように。"], ["なす", "なすは うし。ゆっくり かえれるように。"]]
const SHORYOUMA_GOOD := "（まっすぐ ささった）"
const SHORYOUMA_TILT := "（ちょっと ななめに ささった）"
const SHORYOUMA_DONE_UMA := "（うまが できた）"
const SHORYOUMA_DONE_USHI := "（うしが できた）"
## 星座さがし（9日目）：おじいちゃんが言う星座を順につなぎ、最後に夏の大三角
const SEIZA_INTRO := "おじいちゃんの いう せいざを、じゅんに つなごう"
## 星座の名前（SeizaGame.FIGURES の順）。かっこのものは、せりふではなく説明
const SEIZA_CALLS := ["はくちょうざ。", "ことざ。", "わしざ。", "（いちばん あかるい ほしを みっつ つなぐ）"]
const SEIZA_HINT_TOUCH := "つぎの ほしを タップで つなぐ"
const SEIZA_HINT_KEY := "←→ で ほしを えらんで Space で つなぐ"
const SEIZA_WRONG := "（ちがう ほし）"
const SEIZA_DONE := "（なつの だいさんかく）"
## 三角の星の名前（見つけたあとに、そばへ出す）
const SEIZA_NAMES := ["ベガ", "アルタイル", "デネブ"]
## バスの窓（10日目）：手をふる祖父母が小さくなっていく
const BUSWIN_CAPTION := "（おじいちゃんと おばあちゃんが、てを ふっている）"
const BUSWIN_SMALL := "（……ちいさく なっていく）"
const BUSWIN_GONE := "（みえなく なった）"
const BUSWIN_WAVE_TOUCH := "タップで てを ふりかえす"
const BUSWIN_WAVE_KEY := "Space で てを ふりかえす"
const BUSWIN_CLOSE_TOUCH := "タップで まえを むく"
const BUSWIN_CLOSE_KEY := "Space で まえを むく"
## 口笛の音素材が入るまで、口笛は「♪」の吹き出しで表す
const WHISTLE_NOTE := "♪"

const ROTATE_NOTICE := "よこむきにしてね"
const ROTATE_SUB := "スマホを よこに すると あそべるよ"

const CONTINUE_MARK := "▼"
const SELECT_MARK := "●"

## --- ミニゲームの始める前の説明（1行）と、遊んでいるあいだの案内 ---
const TAKERU := "タケル"
const ISHI_INTRO := "ゲージを 2かい とめて、いしを なげよう"
const ISHI_DEMO := "みてろよ。"
const ISHI_ANGLE_KEY := "かくど：ひくい ところで Space"
const ISHI_ANGLE_TOUCH := "かくど：ひくい ところで タップ"
const ISHI_POWER_KEY := "ちから：まんなかで Space"
const ISHI_POWER_TOUCH := "ちから：まんなかで タップ"
const KATA_INTRO := "みどりの ところで とめて、ひよこを けずろう"
const KATA_HINT_KEY := "みどりの ところで Space"
const KATA_HINT_TOUCH := "みどりの ところで タップ"
const KABUTO_INTRO := "かいちゅうでんとうで てらして、むしを つかまえよう"
const KABUTO_HINT_KEY := "←→ で てらす、Space で つかまえる（あと %d かい）"
const KABUTO_HINT_TOUCH := "むしの いる ところを タップで つかまえる（あと %d かい）"
const KABUTO_GOT := "（%sを つかまえた）"
const KABUTO_TAKE := "（%sを もってかえる）"
const DIVE_INTRO := "せーので とんで、みずの ちかくで ひざを かかえよう"
const DIVE_JUMP_KEY := "まんなかで Space（ふみきり）"
const DIVE_JUMP_TOUCH := "まんなかで タップ（ふみきり）"
const DIVE_TUCK_KEY := "みずに ちかづいたら Space（ひざを かかえる）"
const DIVE_TUCK_TOUCH := "みずに ちかづいたら タップ（ひざを かかえる）"
const DIVE_SMALL := "（しぶき：ちいさい）"
const DIVE_MID := "（しぶき：タケルと おなじくらい）"
const DIVE_LARGE := "（しぶき：タケルより おおきい）"
