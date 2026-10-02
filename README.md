# なつやすみ（叩き台）

田舎の祖父母の家で過ごす夏休みを、右へ歩きながらたどる 2D 横スクロールの散歩ゲームです。
設計は [`DESIGN.md`](DESIGN.md)、UI/UX の決まりは [`.claude/skills/summer-game-ui/SKILL.md`](.claude/skills/summer-game-ui/SKILL.md) にあります。

- エンジン：**Godot 4.4.1**（GDScript / Compatibility レンダラー）
- 絵・音は仮素材（図形・単色・無音）。仕組みと UI/UX を先に作っています

## あそびかた

| 操作 | キーボード | タッチ |
| --- | --- | --- |
| あるく | → / D（← / A で少しもどる） | 画面の右半分（左半分）を押し続ける |
| ひろう | E / Space | アイテムの上の「ひろう」をタップ |
| たからばこ | Tab | 右上の「たからばこ」 |
| ひとやすみ | Esc | 右上の「ひとやすみ」 |
| 決定 / もどる | Enter・Space / Esc | 項目をタップ / 「もどる」 |

開発用（デバッグ実行のときだけ）：F3 で FPS と読み込み中の日を表示、F4 で日の終わりの手前へ移動。

## フォルダ

```
autoload/   GameState（拾ったもの・今の日）、InputMode（タッチかキーボードか）
audio/      SfxPlayer（効果音・環境音の枠）。audio/sfx/<名前>.ogg を置くと鳴る
data/       DayData / ItemData と、その .tres。day_list.tres が日の並び順
days/       day_base.tscn（共通の土台）と day_01〜day_10.tscn
world/      main.tscn（ゲーム本体）、カメラ、日の読み込み、時間帯の色、背景
player/     主人公
ui/         テーマ、画面遷移、HUD、宝箱、タイトル、一時停止、エンディング、タッチ操作
web/        Web 書き出し用の HTML（読み込み画面）
tools/      テーマ・データの生成ツール、自動の動作確認
```

## 日やアイテムを足す

1. `days/day_base.tscn` を継承したシーンを作る（例：`days/day_11.tscn`）。境目の小物は `Boundary`、家などは `Props`、アイテムの位置は `ItemSpots` の `Marker2D` に置く
2. `data/items/` に ItemData、`data/days/` に DayData の `.tres` を作る（エディタの「新規リソース」でOK）
3. `data/day_list.tres` の `days` に DayData を差し込む

日付表示・空の色の褪せ方（夏の進み具合）・宝箱の枠は、データから自動で決まります。

## NPC（村の人）を足す

1. `data/npcs/` に NpcData の `.tres` を作る（`grandpa.tres` をコピーして、名前・せりふ・色を書きかえると早い）
2. 出したい日のシーン（例：`days/day_04.tscn`）を開き、`Props` の下に `world/npc.tscn` を置く
3. 置いた Npc の `npc_data` に、作った `.tres` を入れる

せりふは `lines`（最初に話しかけたとき）と `repeat_lines`（2回目以降）に、1つずつ短く書きます。
`auto_talk` をオンにすると、近づいただけで向こうから話しかけてきます（最初の1回だけ）。

### せりふの書き方

1行に1つ。ふつうに書くとその人のせりふ、`名前：` をつけるとほかの人のせりふ（`ぼく：` は主人公）になります。
`@` で始まる行は指示、`#` で始まる行は目印です（画面には出ません）。

| 書き方 | すること |
| --- | --- |
| `ぼく：おじいちゃんちに きたんだ` | 「：」（全角）の前の名前で話す |
| `@choice わたす:give \| わたさない:no` | 選択肢を出し、選んだほうの目印へ飛ぶ（`:目印` を省くとそのまま次へ） |
| `#give` / `@goto give` / `@end` | 目印 / 目印へ飛ぶ / 会話をおわる |
| `@if_has marble ask` / `@if_flag route_takeru given` | アイテムを持っていたら / フラグが立っていたら、目印へ飛ぶ |
| `@give river_stone` | アイテムをもらう（宝箱では「〜に もらった」） |
| `@take marble タケルに あげた` | アイテムを手ばなす（宝箱とエンディングの枠に「タケルに あげた」と出る） |
| `@bury` | 宝箱から1つ選んで手ばなす（枠に「うめた」） |
| `@show marble` | 次のせりふの左に、そのアイテムの絵を出す |
| `@flag 名前` / `@leave` / `@event 名前` | フラグを立てる / その人が立ち去る / その日の小物に知らせる（水しぶき、雨がやむ、など） |
| `@game base_build` | ミニゲームをして、終わったら続きへ（いまは秘密基地づくり） |

例は `data/npcs/takeru_river.tres`（ビー玉をわたすかどうか）と `takeru_capsule.tres`（タイムカプセル）。

## エンディングの分岐を足す

1. **フラグを立てる**：NpcData の `set_flags` にフラグ名を書くと、その人と話し終えたときに立つ。会話の途中で立てるときは、せりふに `@flag route_takeru` のように書く
2. **選ばなかった人を消す**（必要なら）：その人の NpcData の `appear_if` に条件を作り、`forbid_any` に相手のフラグを入れる
3. **先の日の場面を変える**：もとの日のシーンを継承した差し替えシーンを `days/variants/` に作る。その日の DayData（`data/days/`）の `variants` に、条件（`require_all` にフラグ）・場面・タイトルを足す。DayVariant では、ほかに次も変えられる
   - `items`：その日のアイテム（ルート用のアイテムに差し替える。宝箱の枠もこちらになる）
   - `time_from` / `time_to`：その日の時間帯の範囲（例：夕方〜夜だけの日は `time_from = 0.5`）
   - `dawn_tint` / `dawn_until`：朝の色の上書き（早朝の暗く青い色など）
4. **エンディングを足す**：`data/endings/` に EndingData（条件・見出し・しめくくりの一言）を作り、`data/day_list.tres` の `endings` の、ふつうのエンディングより上に入れる

- 人からもらうだけのアイテムは、ItemData の `on_ground` をオフにする（道に置かれない）
- ルートで一言だけ変えるアイテムは、ItemData の `alt_if` と `alt_description` を使う（例：川のきれいな石）
- 拾ったときに中身を読ませるもの（置き手紙など）は、ItemData の `read_text` に書く

### 親友ルート（タケル）

3日目に川でタケルにビー玉をわたすと `route_takeru` が立ち、4〜10日目が `days/variants/day_XX_takeru.tscn` に差し替わります。
4日目以降のタケルは `auto_talk`（向こうから声をかけてくる）で、同じ日の中の段取り（屋台 → 帰り道など）は `takeru_d5_stall` のような小さなフラグで進めています。
場面の小物は `world/scenery_prop.gd`（駄菓子屋・川原・秘密基地・夏祭り・バス停など）、夕立は `world/rain_zone.gd`、
夜の灯り（提灯・街灯・送り火・星・懐中電灯）は `world/glow_layer.gd` の下に置くと暗くなりません。10日目のバスの場面は `world/bus_departure.gd` です。

### ミニゲーム：秘密基地づくり（4日目）

- 画面：`ui/base_build.gd`。基地の絵：`world/secret_base.gd`（4・8・9日目で使い回す。`mode` が BUILD／QUIET／NIGHT）
- 材料は `data/base_materials/*.tres`（BaseMaterial：名前・仮の色・はめたときの音・屋根の雨の音・タケルの一言・夜の見え方）。材料を足すときは `.tres` を作り、`GameState.BASE_MATERIAL_PATHS` に足す
- どのすき間に何をはめたかは `GameState.base_slots` に入り、8・9日目はそれで基地を描く
- 本番の絵は BaseMaterial の `texture` に入れると、仮の絵のかわりに使われる

## 色や文字の大きさを変える

1. スキル（`.claude/skills/summer-game-ui/SKILL.md`）の値を直す
2. `ui/ui_tokens.gd` を同じ値にする
3. テーマを作り直す：`godot --headless --script res://tools/build_theme.gd`

## 自動の動作確認

```sh
godot --headless --import                       # 初回だけ
godot --headless res://tools/smoke_test.tscn    # 最後に "SMOKE OK" と出れば成功
```

タイトル → 本編を自動で右へ歩き、10日分の日付の進み・読み込まれている日数（3以下）・アイテム取得・拾わなかった枠・宝箱と一時停止の開閉・エンディングまでを確かめます。GitHub Actions でも公開の前に実行します。

## ローカルのブラウザで確認する

書き出したファイルを直接開く（`file://`）と動かないので、簡単なサーバーを立てます。

```sh
mkdir -p build/web && touch build/.gdignore
godot --headless --export-release "Web" build/web/index.html   # エディタの「プロジェクト → エクスポート」でも可
cd build/web
python3 -m http.server 8000
```

ブラウザで <http://localhost:8000/> を開きます。

> 書き出しテンプレートが必要です。エディタの「エディター → エクスポートテンプレートの管理」から 4.4.1 のものをダウンロードしてください。

### 同じ Wi-Fi のスマホで確認する

1. 上のサーバーを `python3 -m http.server 8000 --bind 0.0.0.0` で起動する
2. PC の IP アドレスを調べる（macOS：`ipconfig getifaddr en0`、Windows：`ipconfig`、Linux：`hostname -I`）
3. スマホのブラウザで `http://<PCのIPアドレス>:8000/` を開き、横向きにして遊ぶ

うまくつながらないときは、PC のファイアウォールで 8000 番ポートを許可してください。
（スレッドなしの書き出しなので、HTTPS や特別なヘッダーは不要です）

## GitHub Pages で公開する

`main` ブランチに push すると、`.github/workflows/deploy.yml` が動いて自動で公開されます。

**最初に一度だけ、リポジトリの設定が必要です。**

1. GitHub のリポジトリを開き、**Settings → Pages** を開く
2. **Build and deployment → Source** を **GitHub Actions** にする
3. `main` に push する（または **Actions → Deploy to GitHub Pages → Run workflow**）
4. 完了すると `https://<ユーザー名>.github.io/<リポジトリ名>/` で遊べます

## ライセンス

- フォント：Zen Maru Gothic（SIL Open Font License 1.1）。`ui/theme/fonts/OFL.txt` を参照
