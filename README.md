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
