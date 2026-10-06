# クレジット（素材の出典とライセンス）

このゲームで使っている音は **CC0（パブリックドメイン）** の素材、景色の絵は **生成AI（Google Gemini）で作った絵**です。
CC0 では出典の表示は義務ではありませんが、作者への感謝として残します。
効果音・環境音は、ゲームに合わせて切り出し、音量の調整、重ね合わせ、くり返し用のつなぎ目の加工をしています。

声（「せーの」「おーい」など）の音は入れていません（無音で進みます）。

## 素材集

### 絵

| 素材 | 作者 | ライセンス | 使っている場所 |
|---|---|---|---|
| 背景（山並み・入道雲・田んぼ・木立ち・手前の木の枝）、小物（道ばたの木・電柱・立て札・石・しげみ・クヌギ・鳥居・提灯・屋台・街灯・段ボール箱・バス停）、建物と場所（祖父母の家・駄菓子屋・タケルの家・縁側・川・飛び込み岩・送り火・坂道・バス）、道、主人公、村の人（タケル・なつみ・おじいちゃん・おばあちゃん・駄菓子屋のおばちゃん） | Google Gemini で生成 | ― | `world/scenery/painted/`（背景のマゼンタを切り抜き、帯の絵は横にくり返せるよう左右をなじませています。`tools/art/process_painted.py`） |
| ミニゲームの背景（秘密基地づくり・飛び込み・型抜き・石切り・カブトムシとり・タイムカプセル・帽子）、秘密基地の材料（板・トタン・ブルーシート・すだれ・角材）、ミニゲームの主人公とタケルのポーズ | Google Gemini で生成 | ― | `ui/minigame_bg/`、`data/base_materials/` |
| 初恋ルート（なつみ）の絵：浴衣のなつみ、なつみのポーズ（描く・手をふる・走る・絵を差し出す）、線香花火をするふたり、公民館、ラジオ体操の台と子どもたち、画板、社、遊泳禁止の旗、貝がら、バケツ、水たまり、海の帯、砂浜の道の帯、6日目の背景（水平線の空・太陽・灯台の手前の海・灯台） | Google Gemini で生成 | ― | `world/scenery/painted/`（`tools/art/process_painted.py` で切り抜き。海の帯は白い紙の上の絵なので、紙の部分を透明にしています） |
| 初恋ルートのミニゲームの背景（スケッチ・金魚すくい・貝がら拾い・線香花火・映画会）、なつみの絵（10日目） | Google Gemini で生成 | ― | `ui/minigame_bg/`（紙のふちを切り落としています） |
| アイテムの絵（ビー玉・ラムネのびん・ほおずき・さびた鈴・きつねのお面 など） | このゲームのために SVG で描いたもの | ― | `data/items/icons/`（あとで差し替えるかもしれない仮の絵） |
| 神隠しルート（お面の子）の絵：お面の子（お面あり・なし・遠くの田んぼ・ポーズ4つ）、祠、石灯籠、狛犬、しめ縄の大木、さい銭箱、夜市の屋台、顔の見えない店の人、青い提灯、ひまわり、送り火の煙 | Google Gemini で生成 | ― | `world/scenery/painted/`（`tools/art/process_painted.py` で切り抜き。プロンプトは `tools/art/prompts_kamikakushi.md`） |
| 神隠しルートのミニゲームの背景（かくれんぼ・夜市の物々交換・鈴の音で道探し・鬼ごっこ・鈴を振る） | Google Gemini で生成 | ― | `ui/minigame_bg/` |

### 音

| 素材 | 作者 | ライセンス |
|---|---|---|
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 |
| [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 |
| [Music Jingles](https://kenney.nl/assets/music-jingles) | Kenney | CC0 |
| [cicada sounds](https://opengameart.org/content/cicada-sounds) | syncopika | CC0 |
| [Park ambiences](https://opengameart.org/content/park-ambiences) | Thimras | CC0 |
| [AMB Rain Loop 1](https://opengameart.org/content/amb-rain-loop-1) | Kresiek The Furry | CC0 |
| [Rain in the Gutter Loop](https://opengameart.org/content/rain-gutter-loop) | Ogrebane | CC0 |
| [Crickets Ambient Noise - loopable](https://opengameart.org/content/crickets-ambient-noise-loopable) | Wolfgang_ | CC0 |
| [Bubble Sound Effects](https://opengameart.org/content/bubble-sound-effects) | BMacZero | CC0 |
| [Bicycle Sounds](https://opengameart.org/content/bicycle-sounds) | AntumDeluge | CC0 |
| [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | rubberduck | CC0 |
| [100 CC0 SFX](https://opengameart.org/content/100-cc0-sfx) | rubberduck | CC0 |
| [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2) | rubberduck | CC0 |
| [Another August](https://opengameart.org/content/another-august) | cynicmusic | CC0 |
| [AMB Morning Sounds (Perfect Loop)](https://opengameart.org/content/amb-morning-sounds-perfect-loop) | Kresiek The Furry | CC0 |
| [underwater or space engine rumble](https://opengameart.org/content/underwater-or-space-engine-rumble) | gmason | CC0 |
| [Bell dings/chimes](https://opengameart.org/content/bell-dingschimes) | PWL | CC0 |
| [First Light Particles – CC0 Atmospheric Piano/Ambient Track](https://opengameart.org/content/first-light-particles-%E2%80%93-cc0-atmospheric-pianoambient-track) | Yoiyami | CC0 |

## BGM（`audio/music/`）

| ファイル | もとの素材 |
|---|---|
| `title.ogg` | cynicmusic「Another August」 013_Another_August.mp3 |
| `ending.ogg` | Yoiyami「First Light Particles – CC0 Atmospheric Piano/Ambient Track」 first_light_particles_1.mp3 |

## 自分で作った音

| ファイル | 作り方 |
|---|---|
| `audio/sfx/suzu.ogg`・`suzu_far.ogg`（神隠しルートの鈴） | ffmpeg の `aevalsrc` で、減衰する正弦波を重ねて合成したもの |

## 環境音（`audio/ambient/`）

| ファイル | もとの素材 |
|---|---|
| `semi_abura.ogg` | syncopika「cicada sounds」 082526-cicadasounds2.ogg ＋ Thimras「Park ambiences」 park_ambience_wind.wav |
| `semi_minmin.ogg` | syncopika「cicada sounds」 082526-cicadasounds.ogg ＋ Thimras「Park ambiences」 park_ambience_birds.wav |
| `semi_tsukutsuku.ogg` | syncopika「cicada sounds」 082526-cicadasounds.ogg ＋ syncopika「cicada sounds」 082526-cicadasounds2.ogg ＋ Wolfgang_「Crickets Ambient Noise - loopable」 crickets_1.mp3 |
| `higurashi_dawn.ogg` | Kresiek The Furry「AMB Morning Sounds (Perfect Loop)」 amb_morning.ogg ＋ syncopika「cicada sounds」 082526-cicadasounds.ogg |
| `cicada_dawn_burst.ogg` | syncopika「cicada sounds」 082526-cicadasounds2.ogg ＋ syncopika「cicada sounds」 082526-cicadasounds.ogg ＋ Kresiek The Furry「AMB Morning Sounds (Perfect Loop)」 amb_morning.ogg |
| `river_rock.ogg` | Thimras「Park ambiences」 park_ambience_river.wav ＋ syncopika「cicada sounds」 082526-cicadasounds2.ogg |
| `underwater.ogg` | gmason「underwater or space engine rumble」 underwater_or_space_engine.ogg ＋ BMacZero「Bubble Sound Effects」 bubbles-loop1-amp.wav |
| `rain.ogg` | Kresiek The Furry「AMB Rain Loop 1」 amb_rain_loop_1.ogg |
| `rain_roof_wood.ogg` | Kresiek The Furry「AMB Rain Loop 1」 amb_rain_loop_1.ogg |
| `rain_roof_tin.ogg` | Ogrebane「Rain in the Gutter Loop」 rain-gutter-loop_0.mp3 ＋ Kresiek The Furry「AMB Rain Loop 1」 amb_rain_loop_1.ogg |
| `rain_roof_sheet.ogg` | Kresiek The Furry「AMB Rain Loop 1」 amb_rain_loop_1.ogg |
| `rain_roof_sudare.ogg` | Kresiek The Furry「AMB Rain Loop 1」 amb_rain_loop_1.ogg |
| `autumn_insects.ogg` | Wolfgang_「Crickets Ambient Noise - loopable」 crickets_1.mp3 ＋ Thimras「Park ambiences」 park_ambience_wind.wav |
| `bus_inside.ogg` | rubberduck「100 CC0 SFX #2」 sfx100v2_loop_highway.ogg |
| `bus_window_open.ogg` | rubberduck「100 CC0 SFX #2」 sfx100v2_loop_highway.ogg ＋ Thimras「Park ambiences」 park_ambience_wind.wav ＋ syncopika「cicada sounds」 082526-cicadasounds2.ogg |
| `bus_wind.ogg` | Thimras「Park ambiences」 park_ambience_wind.wav |

## 効果音（`audio/sfx/`）

| ファイル | もとの素材 |
|---|---|
| `cursor.ogg` | Kenney「Interface Sounds」 tick_002.ogg |
| `accept.ogg` | Kenney「Interface Sounds」 confirmation_001.ogg |
| `cancel.ogg` | Kenney「Interface Sounds」 back_002.ogg |
| `text_tick.ogg` | Kenney「Interface Sounds」 tick_001.ogg |
| `pickup.ogg` | Kenney「Interface Sounds」 pluck_001.ogg |
| `box_open.ogg` | Kenney「Interface Sounds」 open_002.ogg |
| `box_close.ogg` | Kenney「Impact Sounds」 impactTin_medium_001.ogg |
| `day_change.ogg` | rubberduck「100 CC0 SFX」 bell_01.ogg |
| `splash.ogg` | rubberduck「40 CC0 water / splash / slime SFX」 splash_03.ogg |
| `surface.ogg` | rubberduck「40 CC0 water / splash / slime SFX」 splash_10.ogg |
| `jump.ogg` | Kenney「RPG Audio」 cloth2.ogg |
| `breath.ogg` | rubberduck「100 CC0 SFX #2」 sfx100v2_air_01.ogg |
| `pat.ogg` | Kenney「Impact Sounds」 impactSoft_medium_000.ogg |
| `soil.ogg` | Kenney「Impact Sounds」 footstep_grass_003.ogg |
| `dig.ogg` | Kenney「Impact Sounds」 footstep_snow_001.ogg |
| `can_place.ogg` | Kenney「Impact Sounds」 impactTin_medium_002.ogg |
| `flashlight_off.ogg` | Kenney「Interface Sounds」 toggle_002.ogg |
| `katanuki_scrape.ogg` | Kenney「Interface Sounds」 scratch_001.ogg |
| `katanuki_creak.ogg` | Kenney「RPG Audio」 creak1.ogg |
| `katanuki_part.ogg` | Kenney「Interface Sounds」 tick_004.ogg |
| `katanuki_break.ogg` | Kenney「Impact Sounds」 impactPlate_light_000.ogg |
| `katanuki_clean.ogg` | Kenney「Interface Sounds」 confirmation_003.ogg |
| `kabuto_rustle.ogg` | Kenney「Impact Sounds」 footstep_grass_000.ogg |
| `kabuto_drop.ogg` | Kenney「Impact Sounds」 impactGeneric_light_001.ogg |
| `kabuto_grab.ogg` | Kenney「RPG Audio」 cloth4.ogg |
| `heartbeat.ogg` | Kenney「Impact Sounds」 impactSoft_heavy_000.ogg |
| `leaf_step.ogg` | Kenney「Impact Sounds」 footstep_grass_001.ogg |
| `throw.ogg` | rubberduck「100 CC0 SFX #2」 sfx100v2_air_02.ogg |
| `skip.ogg` | rubberduck「40 CC0 water / splash / slime SFX」 splash_12.ogg |
| `skip_sweet.ogg` | Kenney「Interface Sounds」 glass_002.ogg |
| `plop.ogg` | rubberduck「100 CC0 SFX」 plop_01.ogg |
| `bike_bell.ogg` | AntumDeluge「Bicycle Sounds」 rotating_bicycle_bell-1.ogg |
| `window_rattle.ogg` | Kenney「Impact Sounds」 impactGlass_light_002.ogg |
| `hat_throw.ogg` | Kenney「RPG Audio」 cloth3.ogg |
| `hat_catch.ogg` | Kenney「RPG Audio」 cloth4.ogg |
| `hat_face.ogg` | Kenney「Impact Sounds」 impactSoft_medium_001.ogg |
| `place_wood.ogg` | Kenney「Impact Sounds」 impactWood_medium_000.ogg |
| `place_tin.ogg` | Kenney「Impact Sounds」 impactMetal_medium_001.ogg |
| `place_sheet.ogg` | Kenney「RPG Audio」 cloth1.ogg |
| `place_sudare.ogg` | Kenney「Impact Sounds」 impactWood_light_002.ogg |
| `fanfare.ogg` | Kenney「Music Jingles」 jingles_STEEL10.ogg |
| `furin.ogg` | PWL「Bell dings/chimes」 bell_ding2.wav（音を約3倍の高さにして、3回重ねて風鈴の音にしています） |

## 補足

- 蝉の声は、日本の蝉（アブラゼミ・ミンミンゼミ・ツクツクボウシ・ヒグラシ）の録音ではありません。手に入る CC0 の蝉の録音に、風・鳥・虫の声を重ねて季節の感じを出しています。日本の蝉の録音に差しかえるときは、同じファイル名で `audio/ambient/` に置けば鳴ります。
- 音を差しかえるときは、`audio/sfx/<名前>.ogg` を置きかえるだけで反映されます（ファイルがない名前は無音のまま進みます）。新しい素材を足したら、この表にも出典を書いてください。
